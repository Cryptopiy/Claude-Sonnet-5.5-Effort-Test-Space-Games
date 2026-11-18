shader_type spatial;
render_mode depth_draw_opaque, cull_back, specular_schlick_ggx;

// ---- terrain function uniforms (mirrored by PlanetData.terrain_uniforms)
uniform float t_radius = 5000.0;
uniform float t_freq = 2.0;
uniform vec3 t_seed_off = vec3(0.0);
uniform int t_seed = 0;
uniform float t_a_cont = 100.0;
uniform float t_a_hill = 150.0;
uniform int t_hill_oct = 8;
uniform float t_hill_gain = 0.5;
uniform float t_a_ridge = 0.0;
uniform float t_ridge_freq = 1.0;
uniform float t_ridge_lo = 0.05;
uniform float t_ridge_hi = 0.45;
uniform int t_ridge_oct = 5;
uniform float t_a_dune = 0.0;
uniform float t_dune_freq = 16.0;
uniform float t_a_crater = 0.0;
uniform float t_crater_freq = 2.5;
uniform float t_a_detail = 2.0;
uniform float t_detail_cell = 24.0;
uniform float t_terrace = 0.0;
uniform float t_terrace_step = 30.0;

#include "res://shaders/inc/tnoise.gdshaderinc"
#include "res://shaders/inc/terrain_fn.gdshaderinc"

// ---- look
uniform vec3 col_shore : source_color = vec3(0.7, 0.65, 0.45);
uniform vec3 col_low : source_color = vec3(0.2, 0.45, 0.15);
uniform vec3 col_mid : source_color = vec3(0.3, 0.5, 0.2);
uniform vec3 col_high : source_color = vec3(0.4, 0.37, 0.3);
uniform vec3 col_peak : source_color = vec3(0.95, 0.95, 1.0);
uniform vec3 col_slope : source_color = vec3(0.35, 0.3, 0.26);
uniform vec3 col_acc : source_color = vec3(0.5, 0.6, 0.2);
uniform vec3 col_deep : source_color = vec3(0.5, 0.5, 0.4);
uniform float h_ref = 300.0;
uniform float snow_line = 1e9;
uniform float sea_h = -1e9;
uniform float patch_strength = 0.5;
uniform float grain = 0.25;
uniform float ice_gloss = 0.0;
uniform vec3 vein_color : source_color = vec3(1.0, 0.4, 0.05);
uniform float vein_strength = 0.0;
uniform float vein_h_max = 0.0;
uniform float detail_scale = 0.35;
uniform float detail_strength = 0.8;
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap_anisotropic;

instance uniform vec4 chunk_a;   // face normal.xyz, ds (cube-units size of the chunk)
instance uniform vec4 chunk_b;   // face axis a.xyz, s0
instance uniform vec4 chunk_c;   // face axis b.xyz, t0

uniform vec3 sun_dir_world = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_light_col : source_color = vec3(1.0, 0.95, 0.88);
uniform float sun_light_energy = 1.5;
varying vec3 v_sun_view;
varying vec3 v_dir;
varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_h;

void vertex() {
	v_sun_view = normalize((VIEW_MATRIX * vec4(sun_dir_world, 0.0)).xyz);
	float ds = chunk_a.w;
	float s = chunk_b.w + UV.x * ds;
	float t = chunk_c.w + UV.y * ds;
	vec3 cube = chunk_a.xyz + s * chunk_b.xyz + t * chunk_c.xyz;
	vec3 dir = tn_cube_to_sphere(cube);
	float edge_len = ds * t_radius * 0.7854;
	float spacing = edge_len / 32.0;
	float h = terrain_height(dir, spacing);
	float skirt = COLOR.r;
	float r = t_radius + h - skirt * (spacing * 5.0 + 1.5);
	VERTEX = dir * r;
	v_dir = dir;
	v_h = h;
	v_pos = VERTEX;
	vec3 ta = chunk_b.xyz - dir * dot(chunk_b.xyz, dir);
	ta = normalize(ta);
	vec3 tb = cross(dir, ta);
	float e = spacing / t_radius;
	vec3 d1 = normalize(dir + ta * e);
	vec3 d2 = normalize(dir + tb * e);
	float h1 = terrain_height(d1, spacing);
	float h2 = terrain_height(d2, spacing);
	vec3 p0 = dir * (t_radius + h);
	vec3 p1 = d1 * (t_radius + h1);
	vec3 p2 = d2 * (t_radius + h2);
	vec3 n = normalize(cross(p1 - p0, p2 - p0));
	if (dot(n, dir) < 0.0) {
		n = -n;
	}
	v_nrm = (skirt > 0.5) ? dir : n;
	NORMAL = v_nrm;
}

vec3 tri_normal(vec3 pos, vec3 n, vec3 w, float k, float strength) {
	vec3 tx = texture(detail_tex, pos.zy * k).xyz * 2.0 - 1.0;
	vec3 ty = texture(detail_tex, pos.xz * k).xyz * 2.0 - 1.0;
	vec3 tz = texture(detail_tex, pos.xy * k).xyz * 2.0 - 1.0;
	tx.xy *= strength; ty.xy *= strength; tz.xy *= strength;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

float tri_height(vec3 pos, vec3 w, float k) {
	float a = texture(detail_tex, pos.zy * k).a;
	float b = texture(detail_tex, pos.xz * k).a;
	float c = texture(detail_tex, pos.xy * k).a;
	return a * w.x + b * w.y + c * w.z;
}

void fragment() {
	vec3 dir = normalize(v_dir);
	vec3 n = normalize(v_nrm);
	float h = v_h;
	float slope = 1.0 - clamp(dot(n, dir), 0.0, 1.0);
	float dist = length(VERTEX);
	float near_f = 1.0 - smoothstep(70.0, 260.0, dist);

	float pc = tn_perlin(dir * (t_radius / 70.0) + t_seed_off, t_seed + 11);
	float pc2 = tn_perlin(dir * (t_radius / 420.0) + t_seed_off * 1.7, t_seed + 12);
	float hb = h + (pc * 0.5 + pc2) * h_ref * 0.1;

	vec3 col = col_low;
	col = mix(col, col_mid, smoothstep(0.0, 0.35 * h_ref, hb));
	col = mix(col, col_high, smoothstep(0.45 * h_ref, 0.85 * h_ref, hb));
	col = mix(col, col_peak, smoothstep(snow_line, snow_line + 0.25 * h_ref, hb));
	float patch_m = smoothstep(-0.1, 0.45, pc2 + pc * 0.35) * patch_strength;
	col = mix(col, col_acc, patch_m);
	float shore_t = 1.0 - smoothstep(sea_h, sea_h + 12.0, hb);
	col = mix(col, col_shore, shore_t);
	col = mix(col, col_deep, smoothstep(sea_h + 1.0, sea_h - 8.0, h));
	float sl = smoothstep(0.1, 0.3, slope + pc * 0.04);
	col = mix(col, col_slope, sl);

	// triplanar detail (grain + micro normal)
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float k1 = detail_scale;
	float k2 = detail_scale * 5.3;
	float g1 = tri_height(v_pos, w, k1);
	float g2 = tri_height(v_pos, w, k2);
	float g = mix(0.5, g1 * 0.6 + g2 * 0.4, near_f * 0.8 + 0.2);
	col *= 1.0 + (g - 0.5) * grain * 2.0;
	vec3 nd = n;
	if (near_f > 0.01) {
		vec3 n1 = tri_normal(v_pos, n, w, k1, detail_strength);
		vec3 n2 = tri_normal(v_pos, n, w, k2, detail_strength * 0.7);
		nd = normalize(mix(n, normalize(n1 + n2 - n), near_f));
	}

	float rough = 0.92;
	float spec = 0.25;
	if (ice_gloss > 0.0) {
		float icy = smoothstep(0.1, 0.5, pc2 + 0.2) * (1.0 - sl);
		rough = mix(0.9, 0.18, icy * ice_gloss);
		spec = mix(0.25, 0.7, icy * ice_gloss);
	}
	vec3 emi = vec3(0.0);
	if (vein_strength > 0.0) {
		float vp = tn_perlin(dir * (t_radius / 55.0) + t_seed_off * 3.0, t_seed + 21);
		float vp2 = tn_perlin(dir * (t_radius / 14.0) + t_seed_off * 5.0, t_seed + 22);
		float vein = smoothstep(0.075, 0.0, abs(vp + vp2 * 0.18));
		float zone = smoothstep(vein_h_max, vein_h_max - 120.0, h);
		float pulse = 0.75 + 0.25 * sin(TIME * 0.8 + vp * 20.0);
		emi = vein_color * vein * zone * vein_strength * pulse * (0.4 + 0.6 * near_f + 0.5);
		col = mix(col, col * 0.4, vein * zone);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emi;
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nd, 0.0))).xyz);
}

void light() {
	vec3 L = LIGHT;
	vec3 lc = LIGHT_COLOR;
	if (LIGHT_IS_DIRECTIONAL) {
		// every planet is lit from the direction of ITS star vector (one engine light cannot be right for all planets)
		L = normalize(v_sun_view);
		lc = sun_light_col * sun_light_energy * PI;
	}
	float ndl = clamp(dot(NORMAL, L), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * lc / PI;
	vec3 H = normalize(L + VIEW);
	float ndh = clamp(dot(NORMAL, H), 0.0, 1.0);
	float shin = exp2(10.0 * (1.0 - ROUGHNESS) + 1.0);
	SPECULAR_LIGHT += ndl * ATTENUATION * lc * pow(ndh, shin) * (1.0 - ROUGHNESS) * SPECULAR_AMOUNT * 0.35;
}
