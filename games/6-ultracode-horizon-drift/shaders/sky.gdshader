shader_type sky;
// Procedural deep-space background (module M2): star layers, the Milky-Way band of OUR galaxy as seen from the current star (the galaxy map's
// geometry: plane = XZ, centre direction supplied by SkyController), nebula tints per system, distant galaxies and (optionally) an aurora.
// No TIME: this sky is also rendered once into the reflection cubemap, so animation comes from a script-driven uniform (aurora_time) only.
// The atmosphere post-process (atmosphere_*.gdshader) is drawn on top of this and dims/colours it, so day skies hide the stars naturally.

global uniform mat3 sky_basis;
global uniform float night_amount;

uniform vec3 amb_color = vec3(0.05);          // radiance written into the reflection/ambient cubemap pass (isotropic)
uniform float star_gain : hint_range(0.0, 4.0) = 1.0;
uniform float star_vis : hint_range(0.0, 1.0) = 1.0;     // 0 in a bright daytime atmosphere (also hides the band), 1 in space / at night
uniform float gal_gain : hint_range(0.0, 4.0) = 1.0;
uniform vec3 gal_center = vec3(1.0, 0.0, 0.0);
uniform vec3 neb_a = vec3(0.55, 0.25, 0.85);
uniform vec3 neb_b = vec3(0.10, 0.45, 0.95);
uniform float neb_seed = 1.0;
uniform vec3 up_local = vec3(0.0, 1.0, 0.0);  // planet 'up' at the camera (local frame) for the aurora
uniform float aurora = 0.0;
uniform vec3 aurora_a = vec3(0.2, 1.0, 0.5);
uniform vec3 aurora_b = vec3(0.5, 0.3, 1.0);
uniform float aurora_time = 0.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1, 0, 0));
	float c = hash13(i + vec3(0, 1, 0));
	float d = hash13(i + vec3(1, 1, 0));
	float e = hash13(i + vec3(0, 0, 1));
	float g = hash13(i + vec3(1, 0, 1));
	float h = hash13(i + vec3(0, 1, 1));
	float k = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

vec3 star_color(float t) {
	vec3 cool = vec3(0.62, 0.74, 1.0);
	vec3 mid = vec3(1.0, 0.96, 0.88);
	vec3 warm = vec3(1.0, 0.62, 0.38);
	return t < 0.5 ? mix(cool, mid, t * 2.0) : mix(mid, warm, (t - 0.5) * 2.0);
}

// one layer of point stars on a cube-mapped grid (no seams visible: star centres stay in the inner 60 % of their cell)
vec3 star_layer(vec3 d, float n, float seed, float density, float size_ang, float gain) {
	vec3 a = abs(d);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = d.yz / a.x;
		face = d.x > 0.0 ? 0.0 : 1.0;
	} else if (a.y >= a.z) {
		uv = d.xz / a.y;
		face = d.y > 0.0 ? 2.0 : 3.0;
	} else {
		uv = d.xy / a.z;
		face = d.z > 0.0 ? 4.0 : 5.0;
	}
	vec2 g = uv * n;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	vec3 h = hash33(vec3(cell, face * 7.0 + seed));
	if (h.x > density) {
		return vec3(0.0);
	}
	vec2 c = 0.2 + 0.6 * h.yz;
	float r_cells = size_ang * (1.0 + dot(uv, uv)) * n;
	float dd = length(f - c) / max(r_cells, 1e-5);
	float core = exp(-dd * dd * 1.6);
	float mag = pow(hash13(vec3(cell, face + seed * 3.0)), 4.0) * 0.9 + 0.1;
	return star_color(hash13(vec3(cell.yx, face + seed * 5.0))) * core * mag * gain;
}

float aurora_pattern(vec3 d, vec3 up, float t) {
	float el = dot(d, up);
	if (el < 0.03) {
		return 0.0;
	}
	vec3 e1 = normalize(cross(up, abs(up.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 e2 = cross(up, e1);
	float az = atan(dot(d, e2), dot(d, e1));
	vec3 pa = vec3(cos(az), sin(az), 0.0);
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float warp = 0.10 * sin(az * (2.0 + fi) + t * (0.05 + 0.02 * fi) + fi * 1.7) + 0.06 * (fbm(pa * (2.0 + fi) + vec3(t * 0.02, fi * 3.0, 0.0)) - 0.5);
		float c = 0.30 + 0.18 * fi + warp;
		float x = (el - c) / (0.05 + 0.035 * fi);
		float rays = 0.55 + 0.45 * vnoise(vec3(az * (22.0 + 6.0 * fi), el * 3.0, t * 0.12 + fi));
		s += exp(-x * x) * rays * (0.9 - 0.2 * fi);
	}
	return s * smoothstep(0.03, 0.2, el);
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = amb_color;
	} else {
		vec3 d = normalize(EYEDIR * sky_basis);          // inertial (system-space) direction
		vec3 col = vec3(0.0);

		// --- Milky Way of our galaxy ------------------------------------------------------------------------------------------------
		float lat = d.y;                                  // galactic plane = XZ
		float band = exp(-pow(lat / 0.20, 2.0));
		float core = pow(max(dot(d, normalize(gal_center)), 0.0), 4.0);
		float dust = fbm(d * 4.0 + vec3(neb_seed, 0.0, neb_seed * 0.3));
		float dust2 = fbm(d * 9.0 + vec3(0.0, neb_seed * 2.0, 5.0));
		float lanes = 1.0 - 0.75 * smoothstep(0.50, 0.72, dust2) * band;
		vec3 band_col = mix(neb_a, neb_b, smoothstep(0.3, 0.7, dust)) * 0.55 + vec3(1.0, 0.86, 0.62) * (0.45 + 1.1 * core);
		col += band_col * band * (0.05 + 0.22 * dust) * lanes * gal_gain;
		col += vec3(1.0, 0.82, 0.55) * core * band * 0.20 * lanes * gal_gain;
		// ambient nebula tint over the whole sky (system specific), kept dim
		float neb = smoothstep(0.45, 0.85, fbm(d * 2.2 + vec3(neb_seed * 1.3, 4.0, 0.0)));
		col += mix(neb_a, neb_b, fbm(d * 1.3 + 7.0)) * neb * 0.045 * gal_gain;
		// dim star-dust glow inside the band
		float dens_boost = 1.0 + 1.6 * band;

		// --- stars ----------------------------------------------------------------------------------------------------------------------
		vec3 st = vec3(0.0);
		st += star_layer(d, 80.0, 1.0, 0.30 * dens_boost, 0.0011, 1.9);
		st += star_layer(d, 38.0, 2.0, 0.24 * dens_boost, 0.0015, 3.0);
		st += star_layer(d, 17.0, 3.0, 0.20, 0.0021, 5.5);
		st += star_layer(d, 7.0, 4.0, 0.16, 0.0032, 9.0);
		col += st * star_gain * (0.7 + 0.8 * band) ;

		// --- distant galaxies ---------------------------------------------------------------------------------------------------------
		for (int i = 0; i < 3; i++) {
			vec3 gd = normalize(vec3(hash11(neb_seed + float(i) * 3.1) - 0.5, hash11(neb_seed * 2.0 + float(i) * 7.7) - 0.5, hash11(neb_seed * 3.0 + float(i) * 1.3) - 0.5));
			float a = max(dot(d, gd), 0.0);
			float ang = acos(clamp(a, 0.0, 1.0));
			col += mix(neb_a, vec3(1.0, 0.9, 0.8), 0.5) * exp(-ang * ang * 9000.0) * 0.5 * gal_gain;
			col += vec3(1.0) * exp(-ang * ang * 90000.0) * 0.4 * gal_gain;
		}

		col *= star_vis;

		// --- aurora -----------------------------------------------------------------------------------------------------------------
		if (aurora > 0.001) {
			vec3 ul = normalize(up_local);
			float au = aurora_pattern(EYEDIR, ul, aurora_time) * aurora;
			vec3 ac = mix(aurora_a, aurora_b, smoothstep(0.2, 0.7, dot(EYEDIR, ul)));
			col += ac * au * night_amount * 2.2;
		}
		COLOR = col;
	}
}
