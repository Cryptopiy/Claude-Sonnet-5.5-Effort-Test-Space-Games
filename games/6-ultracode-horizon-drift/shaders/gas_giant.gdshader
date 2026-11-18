shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix, fog_disabled;
// Gas giant cloud tops (module M2): a full-screen quad that ray-traces the planet SPHERE analytically (perfect limb at any distance, writes real depth).
// Zonal belts / zones with wavy, curling edges, stretched turbulence streaks, white ovals, two elliptical vortex storms that twist the flow around them,
// polar caps, limb darkening + a bright forward-scattering limb halo, a soft reddened terminator, and the ring's shadow on the cloud tops.
// The shader is UNSHADED: radiance = albedo * sun_color * sun_energy * light_gain, with light_gain chosen so that the brightest lit cloud tops sit near 1.0
// (the environment glow starts at 1.1 - without this scaling the whole planet blooms into a white disc).

global uniform vec3 sun_dir;
global uniform vec3 sun_color;
global uniform float sun_energy;

uniform float planet_r = 36000.0;
uniform float ring_in = 0.0;
uniform float ring_out = 0.0;
uniform vec3 c0 = vec3(0.93, 0.85, 0.70);
uniform vec3 c1 = vec3(0.85, 0.55, 0.30);
uniform vec3 c2 = vec3(0.55, 0.38, 0.28);
uniform vec3 c3 = vec3(0.96, 0.93, 0.88);
uniform vec3 c4 = vec3(0.45, 0.55, 0.72);
uniform vec3 storm_col = vec3(0.75, 0.28, 0.18);
uniform vec3 pole_col = vec3(0.35, 0.38, 0.45);
uniform float seed = 1.0;
uniform float band_freq = 7.0;
uniform float turb = 1.0;
uniform vec3 storm0 = vec3(0.7, -0.3, 0.6);     // planet-space direction of the big storm
uniform float storm0_r = 0.16;
uniform vec3 storm1 = vec3(-0.6, 0.45, 0.5);
uniform float storm1_r = 0.08;
uniform float spin_rate = 0.0012;
uniform float light_gain = 0.44;

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

float fbm4(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.05 + vec3(2.3, 5.1, 1.9);
		a *= 0.5;
	}
	return s / 0.9375;
}

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	vec3 q = ro - rd * b;
	float d = r * r - dot(q, q);
	if (d < 0.0) {
		return vec2(1e30, -1e30);
	}
	float s = sqrt(d);
	return vec2(-b - s, -b + s);
}

vec3 rot_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

vec3 rot_axis(vec3 v, vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

// ---- ring optical depth (identical to shaders/ring.gdshader, blurred) for the ring's shadow on the cloud tops --------------------------------------------
float ring_profile(float u) {
	float d = 0.04;
	d += 0.20 * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.20, 0.26, u));
	d += 0.95 * smoothstep(0.20, 0.27, u) * (1.0 - smoothstep(0.60, 0.64, u));
	d += 0.64 * smoothstep(0.69, 0.72, u) * (1.0 - smoothstep(0.93, 0.97, u));
	d *= 1.0 - 0.9 * exp(-pow((u - 0.855) / 0.006, 2.0));
	d *= smoothstep(0.0, 0.02, u) * (1.0 - smoothstep(0.97, 1.0, u));
	return clamp(d, 0.0, 1.0);
}

float ring_shadow_density(float u) {
	float n = 0.5 * vnoise(vec3(u * 16.0, seed, 0.0)) + 0.3 * vnoise(vec3(u * 46.0, seed, 3.1)) + 0.2 * vnoise(vec3(u * 130.0, seed, 6.2));
	return clamp(ring_profile(u) * (0.55 + 0.9 * n), 0.0, 1.0);
}

// ---- cloud belts -----------------------------------------------------------------------------------------------------------------------------------------
vec3 zone_color(float id) {
	float h = hash13(vec3(id, seed, 1.0));
	float h2 = hash13(vec3(id, seed, 2.0));
	float h3 = hash13(vec3(id, seed, 3.0));
	float par = abs(mod(id, 2.0));
	vec3 c;
	if (par > 0.5) {
		c = mix(c1, c2, h * 0.9);                      // belts: darker, warmer
		c = mix(c, c0, smoothstep(0.7, 1.0, h2) * 0.5);
	} else {
		c = mix(c0, c3, h);                            // zones: pale
		c = mix(c, c1, smoothstep(0.75, 1.0, h2) * 0.45);
	}
	return mix(c, c4, step(0.86, h3) * 0.6);           // the odd cold-coloured stripe
}

vec3 band_color(vec3 p, out float streak_o) {
	float lat = asin(clamp(p.y, -1.0, 1.0));
	// wavy belt edges (large scale) + curling eddies (small scale, strongest where bands meet)
	float w1 = fbm4(vec3(p.x * 3.0, p.y * 7.0, p.z * 3.0) + vec3(seed * 1.7)) - 0.5;
	float w2 = fbm4(vec3(p.x * 14.0, p.y * 10.0, p.z * 14.0) + vec3(seed * 2.3, 4.0, 1.0)) - 0.5;
	float zz = lat * band_freq * 0.55 + seed + (w1 * 0.75 + w2 * 0.35) * turb;
	float i0 = floor(zz);
	float f = zz - i0;
	vec3 col = mix(zone_color(i0), zone_color(i0 + 1.0), smoothstep(0.68, 1.0, f));
	col *= 1.0 - 0.16 * exp(-pow((f - 0.88) / 0.07, 2.0));       // a darker line along each edge gives the bands definition
	col *= 0.94 + 0.12 * smoothstep(0.0, 0.5, f);
	// turbulent streaks stretched along the flow + smaller eddies
	float streak = fbm4(vec3(p.x * 2.4, p.y * 52.0, p.z * 2.4) + vec3(seed * 3.0));
	float eddy = fbm4(p * vec3(10.0, 30.0, 10.0) + vec3(seed, 0.0, seed * 0.5));
	col *= 1.0 + (mix(streak, eddy, 0.45) - 0.5) * 1.0 * turb;
	// white ovals / cloud puffs, elongated along the flow
	float spots = smoothstep(0.64, 0.74, fbm4(vec3(p.x * 8.0, p.y * 24.0, p.z * 8.0) + vec3(seed * 9.0)));
	col = mix(col, c3, spots * 0.55);
	streak_o = streak;
	return col;
}

// storm shape in units of the storm radius (elliptical: stretched along the flow)
float vortex_rho(vec3 n, vec3 c, float r, float stretch) {
	vec3 elon = normalize(cross(vec3(0.0, 1.0, 0.0), c) + vec3(1e-4, 0.0, 1e-4));
	vec3 elat = cross(c, elon);
	float a = dot(n, elon) / (r * stretch);
	float b = dot(n, elat) / r;
	float rho = sqrt(a * a + b * b);
	return dot(n, c) > 0.0 ? rho : 100.0;
}

vec3 surface_color(vec3 n_ps, float t) {
	// zonal winds shear the longitude per latitude band
	float wind = sin(n_ps.y * band_freq * 1.73 + seed * 1.3) + 0.5 * sin(n_ps.y * band_freq * 3.9);
	vec3 p = rot_y(n_ps, wind * t * spin_rate);
	vec3 s0 = normalize(storm0);
	vec3 s1 = normalize(storm1);
	float rho0 = vortex_rho(n_ps, s0, storm0_r, 1.7);
	float rho1 = vortex_rho(n_ps, s1, storm1_r, 1.3);
	float m0 = 1.0 - smoothstep(0.30, 1.0, rho0);
	float m1 = 1.0 - smoothstep(0.30, 1.0, rho1);
	vec3 q = rot_axis(p, s0, m0 * m0 * 4.6 + m0 * 1.0);
	q = rot_axis(q, s1, -(m1 * m1 * 3.6 + m1 * 0.8));
	float streak;
	vec3 col = band_color(q, streak);
	// storms: tinted core following the swirl + bright rim
	col = mix(col, storm_col * (0.72 + 0.55 * streak), clamp(m0 * 0.85, 0.0, 0.88));
	col += c3 * exp(-pow((rho0 - 1.04) / 0.10, 2.0)) * 0.13;
	col = mix(col, mix(storm_col, c3, 0.45) * (0.8 + 0.4 * streak), clamp(m1 * 0.7, 0.0, 0.75));
	// polar caps
	float pole = smoothstep(0.78, 0.99, abs(n_ps.y));
	col = mix(col, pole_col * (0.75 + 0.55 * streak), pole * 0.75);
	return col;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD - NODE_POSITION_WORLD;
	vec4 vn = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 vdir = normalize(vn.xyz / vn.w);
	vec3 rd = normalize((INV_VIEW_MATRIX * vec4(vdir, 0.0)).xyz);
	float rr = length(ro);
	vec3 sun = normalize(sun_dir);
	vec3 sun_c = sun_color * clamp(sun_energy, 0.0, 4.0) * light_gain;
	if (rr < planet_r) {
		// below the cloud tops: thick coloured haze, darker and redder with depth
		float depth01 = clamp((planet_r - rr) / (planet_r * 0.25), 0.0, 1.0);
		vec3 haze = mix(mix(c1, c0, 0.5), c2 * vec3(0.8, 0.5, 0.35), depth01) * (0.25 + 0.75 * clamp(sun_energy / 2.5, 0.0, 1.0)) * (1.0 - 0.7 * depth01);
		ALBEDO = haze * 0.8;
		ALPHA = 1.0;
		DEPTH = 0.0;
	} else {
		float b = dot(ro, rd);
		float dmin = length(ro - rd * b);
		float tcl = max(-b, 1.0);
		if (b > 0.0) {
			discard;
		}
		// analytic edge anti-aliasing: distance of the ray to the sphere vs the footprint of a pixel at that distance
		float foot = tcl * 2.2 / (abs(PROJECTION_MATRIX[1][1]) * float(VIEWPORT_SIZE.y));
		float cov = clamp((planet_r - dmin) / foot + 0.5, 0.0, 1.0);
		if (cov <= 0.0) {
			// forward-scattering limb halo just outside the disc, only where the limb is lit
			float h = dmin - planet_r;
			if (h > planet_r * 0.12) {
				discard;
			}
			vec3 pt = ro + rd * tcl;
			vec3 nt = normalize(pt);
			float lit_t = smoothstep(-0.25, 0.45, dot(nt, sun));
			float halo = exp(-max(h, 0.0) / (planet_r * 0.016)) * 0.55 * lit_t;
			if (halo < 0.004) {
				discard;
			}
			ALBEDO = mix(c0, c4, 0.45) * sun_c * 1.15 * mix(vec3(1.0), vec3(1.0, 0.7, 0.55), smoothstep(0.35, -0.05, dot(nt, sun)));
			ALPHA = halo;
			DEPTH = 0.0;
		} else {
			float thit = (b * b - dot(ro, ro) + planet_r * planet_r) > 0.0 ? (-b - sqrt(b * b - dot(ro, ro) + planet_r * planet_r)) : tcl;
			vec3 P = ro + rd * thit;
			vec3 n = normalize(P);
			mat3 M = mat3(MODEL_MATRIX);
			vec3 n_ps = normalize(n * M);
			vec3 albedo = surface_color(n_ps, TIME);
			float ndl = dot(n, sun);
			float day = smoothstep(-0.10, 0.55, ndl);
			float tw = exp(-pow((ndl - 0.04) / 0.16, 2.0));            // twilight band: long slant path through the haze reddens the light
			vec3 lit = albedo * mix(vec3(1.0), vec3(1.0, 0.52, 0.30), clamp(tw * 0.85, 0.0, 1.0));
			float mu = clamp(dot(n, -rd), 0.0, 1.0);
			float limb = mix(0.50, 1.0, pow(mu, 0.45));
			// ring shadow on the cloud tops
			float rshadow = 1.0;
			if (ring_out > 0.0) {
				vec3 L_ps = normalize(sun * M);
				float sy = L_ps.y;
				if (abs(sy) > 1e-3) {
					float s = -(n_ps.y * planet_r) / sy;
					if (s > 0.0) {
						vec3 qq = n_ps * planet_r + L_ps * s;
						float rho = length(qq.xz);
						float u = (rho - ring_in) / (ring_out - ring_in);
						if (u > 0.0 && u < 1.0) {
							rshadow = 1.0 - 0.85 * ring_shadow_density(u);
						}
					}
				}
			}
			vec3 col = lit * sun_c * day * rshadow * limb;
			col += albedo * vec3(0.010, 0.012, 0.020) * (1.0 - day * 0.8);             // faint ambient / ring-shine on the night side
			// thin bright haze rim on the lit limb
			float rim = pow(1.0 - mu, 3.2) * smoothstep(-0.15, 0.45, ndl);
			col += mix(c0, c4, 0.5) * sun_c * rim * 0.50;
			ALBEDO = col;
			ALPHA = cov;
			vec3 vpos = vdir * thit;
			vec4 clip = PROJECTION_MATRIX * vec4(vpos, 1.0);
			DEPTH = clip.z / clip.w;
		}
	}
}
