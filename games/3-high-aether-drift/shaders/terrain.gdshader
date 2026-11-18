shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://shaders/include/noise.gdshaderinc"

// ---- terrain shape (mirrored by TerrainParams) ----
uniform int t_seed = 1;
uniform float t_freq = 3.0;
uniform float t_amp = 200.0;
uniform float t_ridge = 0.4;
uniform float t_mask = 0.6;
uniform float t_terr = 0.0;
uniform float t_steps = 6.0;
uniform float t_dune = 0.0;
uniform float t_crater = 0.0;
uniform float t_cden = 5.0;
uniform vec3 t_off = vec3(0.0);
uniform vec4 t_site = vec4(0.0, 1.0, 0.0, 0.0); // xyz dir, w height
uniform vec3 t_site_r = vec3(45.0, 120.0, 4000.0); // inner, outer radius (m), planet radius
uniform float t_site_on = 1.0;

// ---- look ----
uniform vec3 col_low : source_color = vec3(0.2, 0.4, 0.12);
uniform vec3 col_mid : source_color = vec3(0.3, 0.5, 0.16);
uniform vec3 col_high : source_color = vec3(0.45, 0.42, 0.3);
uniform vec3 col_rock : source_color = vec3(0.35, 0.32, 0.3);
uniform vec3 col_beach : source_color = vec3(0.8, 0.75, 0.5);
uniform vec3 col_snow : source_color = vec3(0.95, 0.97, 1.0);
uniform float snow_line = 2.0;
uniform float sea_level = -100000.0;
uniform float rock_bias = 0.0;
uniform vec3 lava_col : source_color = vec3(1.0, 0.3, 0.05);
uniform float lava_amt = 0.0;
uniform float spec_amt = 0.0;
uniform float color_var = 0.35;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0); // world space, towards the star
uniform float night_glow = 0.0;

instance uniform vec4 patch_info; // a0, b0, size, face

const int GRID = 48;

varying vec3 v_lpos;
varying vec3 v_nl;
varying vec3 v_dir;
varying float v_h;
varying vec3 sun_v;

vec3 cube_point(int face, float a, float b) {
	a = tan(a * 0.78539816);
	b = tan(b * 0.78539816);
	if (face == 0) { return vec3(1.0, b, -a); }
	if (face == 1) { return vec3(-1.0, b, a); }
	if (face == 2) { return vec3(a, 1.0, -b); }
	if (face == 3) { return vec3(a, -1.0, b); }
	if (face == 4) { return vec3(a, b, 1.0); }
	return vec3(-a, b, -1.0);
}

float terrain_h(vec3 d) {
	uint sd = uint(t_seed);
	vec3 p = d * t_freq + t_off;
	float n = fbm(p, sd, 7);
	float rn = 1.0 - abs(fbm(p * 1.35 + vec3(7.7, 1.3, 4.1), sd + 11u, 6));
	rn = rn * rn * 1.9 - 0.45;
	float mk = mix(1.0, smoothstep(-0.25, 0.25, fbm(p * 0.4 + vec3(3.1, 8.2, 1.7), sd + 23u, 3)), t_mask);
	float base = mix(n * 0.4, mix(n, rn, t_ridge), mk);
	float h = base * t_amp;
	if (t_terr > 0.0) {
		float t = h / t_amp * t_steps;
		float tq = (floor(t) + smoothstep(0.3, 0.7, t - floor(t))) / t_steps;
		h = mix(h, tq * t_amp, t_terr);
	}
	if (t_dune > 0.0) {
		float s = dot(p, vec3(0.62, 0.21, 0.75)) * 6.0 + n * 5.0;
		h += t_dune * (1.0 - abs(sin(s))) * (1.0 - mk * 0.8);
	}
	if (t_crater != 0.0) {
		h += t_crater * crater_field(d, t_cden, sd + 101u);
	}
	if (t_site_on > 0.5) {
		float w = 1.0 - smoothstep(t_site_r.x, t_site_r.y, distance(d, t_site.xyz) * t_site_r.z);
		h = mix(h, t_site.w, w);
	}
	return h;
}

vec3 surface_pos(int face, float a, float b, out float hh) {
	vec3 d = normalize(cube_point(face, a, b));
	hh = terrain_h(d);
	return d * (t_site_r.z + hh);
}

void vertex() {
	float a0 = patch_info.x;
	float b0 = patch_info.y;
	float s = patch_info.z;
	int face = int(patch_info.w + 0.5);
	float a = a0 + VERTEX.x * s;
	float b = b0 + VERTEX.y * s;
	float step_ab = s / float(GRID);
	float h0, h1, h2;
	vec3 p0 = surface_pos(face, a, b, h0);
	vec3 p1 = surface_pos(face, a + step_ab, b, h1);
	vec3 p2 = surface_pos(face, a, b + step_ab, h2);
	vec3 n = normalize(cross(p1 - p0, p2 - p0));
	vec3 d = normalize(p0);
	if (dot(n, d) < 0.0) { n = -n; }
	float skirt = VERTEX.z * (s * t_site_r.z * 0.045 + 2.0);
	vec3 pos = p0 - d * skirt;
	v_lpos = pos;
	v_nl = n;
	v_dir = d;
	v_h = h0;
	VERTEX = pos;
	NORMAL = n;
	sun_v = (VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz;
}

void fragment() {
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(40.0, 350.0, dist);
	vec3 nl = normalize(v_nl);
	float upd = dot(nl, v_dir);
	float slope = 1.0 - upd;

	vec3 pc = v_lpos;
	float n1 = gnoise(pc * 0.045, 31u);
	float n2 = gnoise(pc * 0.31, 37u) * fade;
	float n3 = gnoise(pc * 1.7, 41u) * fade;
	float detail = n1 * 0.6 + n2 * 0.3 + n3 * 0.15;

	float hn = v_h / max(t_amp, 1.0);
	vec3 base = mix(col_low, col_mid, smoothstep(-0.25, 0.15, hn + n1 * 0.2));
	base = mix(base, col_high, smoothstep(0.2, 0.7, hn + n1 * 0.15));
	base *= 1.0 + detail * color_var;

	float rockf = smoothstep(0.055 - rock_bias, 0.16 - rock_bias, slope + n2 * 0.03);
	vec3 albedo = mix(base, col_rock * (1.0 + detail * 0.5), rockf);

	if (sea_level > -50000.0) {
		float bf = 1.0 - smoothstep(sea_level + 1.0, sea_level + 9.0, v_h + n2 * 3.0);
		albedo = mix(albedo, col_beach * (1.0 + detail * 0.25), bf * (1.0 - rockf * 0.6));
		albedo = mix(albedo, albedo * vec3(0.45, 0.6, 0.65), 1.0 - smoothstep(sea_level - 14.0, sea_level, v_h));
	}
	if (snow_line < 1.5) {
		float sf = smoothstep(snow_line, snow_line + 0.12, hn + n1 * 0.1 + n2 * 0.05) * (1.0 - rockf * 0.55);
		albedo = mix(albedo, col_snow * (0.95 + detail * 0.1), sf);
	}

	// micro-bump from noise gradient
	vec3 np = pc * 1.4;
	float e = 0.12;
	float b0 = gnoise(np, 53u);
	vec3 g = vec3(gnoise(np + vec3(e, 0.0, 0.0), 53u) - b0, gnoise(np + vec3(0.0, e, 0.0), 53u) - b0, gnoise(np + vec3(0.0, 0.0, e), 53u) - b0) / e;
	vec3 nb = normalize(nl - (g - dot(g, nl) * nl) * 0.12 * fade);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nb, 0.0)).xyz);

	ALBEDO = albedo;
	ROUGHNESS = mix(0.95, 0.55, spec_amt);
	SPECULAR = 0.15 + spec_amt * 0.5;

	if (lava_amt > 0.0) {
		float cr = fbm(pc * 0.0032 + vec3(3.0), 77u, 4);
		float veins = 1.0 - smoothstep(0.0, 0.05, abs(cr));
		float low = 1.0 - smoothstep(sea_level, sea_level + 6.0, v_h);
		float heat = clamp(veins * lava_amt * (1.0 - rockf * 0.2) + low, 0.0, 1.0);
		float pulse = 0.8 + 0.2 * sin(TIME * 1.5 + n1 * 12.0);
		EMISSION = lava_col * heat * 3.5 * pulse;
		ALBEDO = mix(ALBEDO, ALBEDO * 0.3, heat);
	}
}

void light() {
	vec3 L = normalize(sun_v);
	float ndl = clamp(dot(NORMAL, L), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
	if (spec_amt > 0.0) {
		vec3 hv = normalize(L + VIEW);
		SPECULAR_LIGHT += pow(max(dot(NORMAL, hv), 0.0), 48.0) * ndl * ATTENUATION * LIGHT_COLOR * spec_amt;
	}
}
