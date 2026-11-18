shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// Liquid sphere: kind 1 = water, 2 = lava, 3 = acid.

uniform float planet_r = 5000.0;
uniform float sea_level = 0.0;
uniform int kind = 1;
uniform vec3 col_shallow : source_color = vec3(0.1, 0.45, 0.5);
uniform vec3 col_deep : source_color = vec3(0.0, 0.07, 0.14);
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

instance uniform vec4 chunk_a;
instance uniform vec4 chunk_b;
instance uniform vec4 chunk_c;

varying vec3 v_pos;
varying vec3 v_dir;

vec3 tn_cube_to_sphere(vec3 c) {
	vec3 c2 = c * c;
	return vec3(
		c.x * sqrt(1.0 - 0.5 * (c2.y + c2.z) + c2.y * c2.z / 3.0),
		c.y * sqrt(1.0 - 0.5 * (c2.z + c2.x) + c2.z * c2.x / 3.0),
		c.z * sqrt(1.0 - 0.5 * (c2.x + c2.y) + c2.x * c2.y / 3.0));
}

void vertex() {
	float ds = chunk_a.w;
	float s = chunk_b.w + UV.x * ds;
	float t = chunk_c.w + UV.y * ds;
	vec3 cube = chunk_a.xyz + s * chunk_b.xyz + t * chunk_c.xyz;
	vec3 dir = tn_cube_to_sphere(cube);
	float r = planet_r + sea_level - COLOR.r * 3.0;
	VERTEX = dir * r;
	NORMAL = dir;
	v_dir = dir;
	v_pos = VERTEX;
}

vec3 wave_normal(vec3 pos, vec3 n, float t) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 o1 = vec2(t * 0.012, t * 0.007);
	vec2 o2 = vec2(-t * 0.009, t * 0.011);
	vec3 a = vec3(0.0);
	float k1 = 0.045;
	float k2 = 0.17;
	vec3 x1 = texture(detail_tex, pos.zy * k1 + o1).xyz * 2.0 - 1.0;
	vec3 y1 = texture(detail_tex, pos.xz * k1 + o1).xyz * 2.0 - 1.0;
	vec3 z1 = texture(detail_tex, pos.xy * k1 + o1).xyz * 2.0 - 1.0;
	vec3 x2 = texture(detail_tex, pos.zy * k2 + o2).xyz * 2.0 - 1.0;
	vec3 y2 = texture(detail_tex, pos.xz * k2 + o2).xyz * 2.0 - 1.0;
	vec3 z2 = texture(detail_tex, pos.xy * k2 + o2).xyz * 2.0 - 1.0;
	vec3 g = (vec3(0.0, x1.y + x2.y, x1.x + x2.x) * w.x + vec3(y1.x + y2.x, 0.0, y1.y + y2.y) * w.y + vec3(z1.x + z2.x, z1.y + z2.y, 0.0) * w.z);
	return normalize(n + g * 0.35);
}

float tri_h(vec3 pos, vec3 w, float k, vec2 o) {
	return texture(detail_tex, pos.zy * k + o).a * w.x + texture(detail_tex, pos.xz * k + o).a * w.y + texture(detail_tex, pos.xy * k + o).a * w.z;
}

void fragment() {
	vec3 n = normalize(v_dir);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// scene depth -> water column
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	float scene_z = -(ndc.xyz / ndc.w).z;
	float col_len = max(scene_z + VERTEX.z, 0.0);   // VERTEX.z is negative in view space
	if (kind == 1) {
		vec3 nw = wave_normal(v_pos, n, TIME);
		NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nw, 0.0))).xyz);
		float k = 1.0 - exp(-col_len * 0.09);
		vec3 base = mix(col_shallow, col_deep, clamp(k, 0.0, 1.0));
		// refraction
		vec2 off = NORMAL.xy * 0.02 * clamp(col_len * 0.3, 0.0, 1.0);
		vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
		float clarity = exp(-col_len * 0.16);
		ALBEDO = base;
		float foam = smoothstep(2.2, 0.0, col_len) * smoothstep(0.35, 0.8, tri_h(v_pos, w, 0.3, vec2(TIME * 0.03, 0.0)));
		ALBEDO = mix(ALBEDO, vec3(0.95), foam * 0.8);
		ROUGHNESS = mix(0.04, 0.5, foam);
		SPECULAR = 0.8;
		METALLIC = 0.0;
		EMISSION = behind * clarity * 0.85 * (1.0 - foam);
		ALPHA = clamp(0.55 + k * 0.4 + foam * 0.4, 0.0, 0.97);
		if (col_len < 0.05) {
			ALPHA = 0.0;
		}
	} else if (kind == 2) {
		// lava: dark crust + glowing flow
		float h1 = tri_h(v_pos, w, 0.02, vec2(TIME * 0.004, 0.0));
		float h2 = tri_h(v_pos, w, 0.08, vec2(0.0, TIME * 0.006));
		float h3 = tri_h(v_pos, w, 0.31, vec2(TIME * 0.01, TIME * 0.01));
		float f = h1 * 0.55 + h2 * 0.3 + h3 * 0.15;
		float glow = smoothstep(0.43, 0.56, f);
		vec3 hot = mix(vec3(1.0, 0.18, 0.0), vec3(1.0, 0.75, 0.2), smoothstep(0.55, 0.72, f));
		ALBEDO = mix(vec3(0.03, 0.02, 0.02), col_shallow * 0.2, glow);
		EMISSION = hot * (0.25 + glow * 3.2);
		ROUGHNESS = 0.7;
		ALPHA = 1.0;
	} else {
		// acid
		vec3 nw = wave_normal(v_pos, n, TIME * 0.4);
		NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nw, 0.0))).xyz);
		float h1 = tri_h(v_pos, w, 0.05, vec2(TIME * 0.006, 0.0));
		float k = 1.0 - exp(-col_len * 0.12);
		ALBEDO = mix(col_shallow, col_deep, k);
		float bubbles = smoothstep(0.66, 0.74, tri_h(v_pos, w, 0.4, vec2(TIME * 0.02, TIME * 0.015)));
		EMISSION = col_shallow * (0.35 + h1 * 0.6 + bubbles * 1.2);
		ROUGHNESS = 0.12;
		SPECULAR = 0.7;
		ALPHA = clamp(0.78 + k * 0.2, 0.0, 0.98);
		if (col_len < 0.05) {
			ALPHA = 0.0;
		}
	}
}
