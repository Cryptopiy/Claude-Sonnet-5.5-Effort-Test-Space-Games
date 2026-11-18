shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;
// Water / lava / toxic sludge sphere at the planet's sea level.

#include "res://shaders/include/noise.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_col : source_color = vec3(0.1, 0.5, 0.6);
uniform vec3 deep_col : source_color = vec3(0.02, 0.12, 0.28);
uniform vec3 foam_col : source_color = vec3(1.0);
uniform float clarity = 0.05;
uniform float emit_amt = 0.0;
uniform float wave_amt = 0.35;
uniform float flow_speed = 0.1;
uniform float roughness_v = 0.06;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 nl = normalize(v_local);
	vec3 p = v_local * 0.9;
	float t = TIME * flow_speed;
	vec3 wp = p + vec3(t * 3.0, 0.0, t * 2.0);
	float n0 = gnoise(wp, 61u);
	vec3 g = vec3(gnoise(wp + vec3(0.2, 0.0, 0.0), 61u) - n0, gnoise(wp + vec3(0.0, 0.2, 0.0), 61u) - n0, gnoise(wp + vec3(0.0, 0.0, 0.2), 61u) - n0) / 0.2;
	vec3 wp2 = p * 2.7 - vec3(t * 2.0, 0.0, -t * 3.0);
	float m0 = gnoise(wp2, 67u);
	vec3 g2 = vec3(gnoise(wp2 + vec3(0.2, 0.0, 0.0), 67u) - m0, gnoise(wp2 + vec3(0.0, 0.2, 0.0), 67u) - m0, gnoise(wp2 + vec3(0.0, 0.0, 0.2), 67u) - m0) / 0.2;
	vec3 gg = g + g2 * 0.6;
	vec3 nb = normalize(nl - (gg - dot(gg, nl) * nl) * wave_amt * 0.18);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nb, 0.0)).xyz);

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vw.xyz /= vw.w;
	float water_depth = max(-vw.z + VERTEX.z, 0.0);

	float k = 1.0 - exp(-water_depth * clarity);
	vec3 col = mix(shallow_col, deep_col, clamp(k * 1.4, 0.0, 1.0));
	float foam = (1.0 - smoothstep(0.0, 1.4, water_depth)) * (0.6 + 0.4 * m0);
	col = mix(col, foam_col, clamp(foam, 0.0, 1.0) * (1.0 - emit_amt));
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = clamp(0.35 + k * 0.7 + foam * 0.6, 0.0, 0.97);
	if (emit_amt > 0.0) {
		float flow = fbm(p * 0.6 + vec3(t * 0.7, 0.0, 0.0), 71u, 4) * 0.5 + 0.5;
		float crust = smoothstep(0.52, 0.72, flow);
		vec3 lava = mix(vec3(1.0, 0.5, 0.08), vec3(1.0, 0.9, 0.4), flow);
		EMISSION = mix(lava * 3.0, vec3(0.05, 0.02, 0.02), crust) * emit_amt;
		ALBEDO = mix(vec3(0.5, 0.15, 0.03), vec3(0.04, 0.03, 0.03), crust);
		ALPHA = 1.0;
	}
}
