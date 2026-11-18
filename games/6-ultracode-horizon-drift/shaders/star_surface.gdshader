shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;
// Photosphere of the star (module M2): HDR emissive sphere with
//   * two scales of soft, slowly "boiling" granulation cells (each granule has its own brightness, dark inter-granular lanes),
//   * super-granulation + a bright faculae network that is strongest towards the limb, and a few sun spots with a penumbra,
//   * strong per-channel limb darkening (centre white-yellow -> orange -> deep red at the rim, blue is darkened most, like a real photosphere).
// Granulation fades out by itself when a granule gets smaller than a pixel (fwidth), so a distant star is a clean disc without shimmer.
// Object-space sphere (Frame applies a uniform scale to the node, which does not matter here).

uniform vec3 star_col = vec3(1.0, 0.9, 0.62);
uniform float emission = 1.9;
uniform float seed = 1.0;
uniform float spot_amount = 0.5;
uniform vec3 limb_k = vec3(0.62, 0.80, 0.95);      // limb darkening per colour channel: I(mu) = 1 - k (1 - mu)
uniform float gran_scale = 22.0;                    // granules per radian of the sphere

varying vec3 v_pos;

uint pcg_u(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash13(vec3 p3) {
	ivec3 ip = ivec3(floor(p3));
	uint h = pcg_u(uint(ip.x) + pcg_u(uint(ip.y) + pcg_u(uint(ip.z))));
	return float(h) * (1.0 / 4294967295.0);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < oct; i++) {
		s += a * vnoise(p);
		p = p * 2.1 + vec3(1.7, 9.2, 3.3);
		a *= 0.5;
	}
	return s;
}

// Worley cell field with orbiting feature points (=> the granules slowly change shape).
// x = distance to the nearest feature point, y = distance to the 2nd nearest, z = random id of the nearest cell
vec3 cells(vec3 p, float tb) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 h = vec3(hash13(i + g), hash13(i + g + 17.0), hash13(i + g + 41.0));
				vec3 o = 0.5 + 0.40 * sin(6.2831853 * h + tb * vec3(0.9, 1.1, 0.8) * (0.6 + 0.8 * h.yzx));
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = hash13(i + g + 73.0);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(d1, d2, id);
}

void vertex() {
	v_pos = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_pos);
	float t = TIME * 0.012;
	float fw = length(fwidth(d));                                       // size of a pixel on the unit sphere (radians)
	// large scale convective flow bends the cell lattice
	vec3 warp = vec3(fbm(d * 2.5 + vec3(seed, t, 0.0), 3), fbm(d * 2.5 + vec3(0.0, seed, t), 3), fbm(d * 2.5 + vec3(t, 0.0, seed), 3)) - 0.5;
	vec3 q = d * gran_scale + warp * 1.8 + vec3(seed * 5.0, 0.0, 0.0);
	float aa1 = 1.0 - smoothstep(0.22, 0.65, fw * gran_scale);
	float aa2 = 1.0 - smoothstep(0.22, 0.65, fw * gran_scale * 2.7);
	float gran = 0.86;
	if (aa1 > 0.01) {
		vec3 c1 = cells(q, TIME * 0.20);
		float lane1 = smoothstep(0.0, 0.62, c1.y - c1.x);              // 0 on the dark lanes, 1 inside a granule (soft edge)
		float b1 = (0.76 + 0.24 * lane1) * (0.88 + 0.24 * c1.z) * (1.03 - 0.22 * c1.x);
		gran = mix(0.88, b1, aa1 * 0.85);
	}
	if (aa2 > 0.01) {
		vec3 c2 = cells(q * 2.7 + 11.0, TIME * 0.30);
		float lane2 = smoothstep(0.0, 0.55, c2.y - c2.x);
		float b2 = (0.86 + 0.14 * lane2) * (0.92 + 0.16 * c2.z);
		gran *= mix(0.95, b2, aa2 * 0.8);
	}
	// soft mottling at an irregular scale: breaks the regularity of the lattice
	gran *= 0.88 + 0.24 * fbm(d * 9.0 + vec3(seed * 1.7, 5.0, t * 3.0), 3);
	// super-granulation + bright faculae network
	float sg = fbm(d * 4.0 + vec3(seed, 2.0, t), 3);
	float mu = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fac = smoothstep(0.54, 0.76, fbm(d * 7.0 + vec3(1.0, seed, 3.0), 3)) * (0.35 + 1.0 * (1.0 - mu));
	float heat = gran * (0.88 + 0.28 * sg) + 0.16 * fac;
	// sun spots (dark umbra + penumbra)
	float sp = fbm(d * 2.2 + vec3(seed * 3.0, 1.0, t * 0.2), 3);
	float spots = smoothstep(0.60, 0.70, sp) * spot_amount;
	float umbra = smoothstep(0.68, 0.74, sp) * spot_amount;
	heat *= 1.0 - 0.45 * spots - 0.35 * umbra;
	// limb darkening, per channel: the edge is seen through cooler upper layers => it gets darker AND redder
	vec3 limb = max(vec3(1.0) - limb_k * (1.0 - mu), vec3(0.0));
	vec3 hot = mix(star_col, vec3(1.0, 0.97, 0.90), 0.30 * mu);
	// hot granule tops are yellow-white, the cooler inter-granular lanes / spots are deep orange (not just darker)
	vec3 cool = hot * vec3(1.0, 0.66, 0.40);
	vec3 base = mix(cool, hot, smoothstep(0.40, 1.00, heat));
	ALBEDO = base * limb * heat * emission;
}
