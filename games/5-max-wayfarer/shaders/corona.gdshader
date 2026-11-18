shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// Camera facing glow sprite for stars: soft halo + corona streamers + lens spikes. Scale the node to the sprite size.

uniform vec3 glow_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 1.0;
uniform float seed = 1.0;
uniform float core_radius = 0.07;      // star disc radius in sprite uv units (0..0.5)
uniform float spikes = 1.0;

varying vec2 v_uv;

void vertex() {
	// billboard that keeps node scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_uv = UV * 2.0 - 1.0;
}

void fragment() {
	vec2 p = v_uv;
	float r = length(p);
	float a = atan(p.y, p.x);
	// halo: steep core falloff + wide skirt
	float halo = exp(-r * 9.0) * 1.3 + exp(-r * 3.2) * 0.35 + exp(-r * 1.4) * 0.07;
	// corona streamers around the disc
	float streak = fbm3(vec3(cos(a) * 2.2, sin(a) * 2.2, seed + TIME * 0.02)) ;
	float corona = exp(-max(r - core_radius * 2.0, 0.0) * 7.0) * (0.35 + 1.1 * streak) * smoothstep(0.0, core_radius * 1.6, r);
	// diffraction spikes
	float sp = 0.0;
	if (spikes > 0.0) {
		float s1 = pow(max(0.0, 1.0 - abs(p.x) * 38.0), 2.0) * exp(-abs(p.y) * 3.2);
		float s2 = pow(max(0.0, 1.0 - abs(p.y) * 38.0), 2.0) * exp(-abs(p.x) * 3.2);
		vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
		float s3 = pow(max(0.0, 1.0 - abs(q.x) * 55.0), 2.0) * exp(-abs(q.y) * 4.5) * 0.45;
		float s4 = pow(max(0.0, 1.0 - abs(q.y) * 55.0), 2.0) * exp(-abs(q.x) * 4.5) * 0.45;
		sp = (s1 + s2 + s3 + s4) * 0.55 * spikes;
	}
	float edge = 1.0 - smoothstep(0.85, 1.0, r);
	vec3 col = glow_color * (halo + corona + sp) * edge * strength;
	ALBEDO = col;
}
