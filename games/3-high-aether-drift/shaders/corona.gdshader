shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 star_col : source_color = vec3(1.0, 0.9, 0.65);
uniform float intensity = 1.0;
uniform float core = 0.2; // star radius as fraction of the quad half-size
uniform float fade_near = 0.0;

varying vec2 v_uv;

void vertex() {
	v_uv = VERTEX.xy;
	// camera-facing quad, scaled by the node scale
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv[0] *= length(MODEL_MATRIX[0].xyz);
	mv[1] *= length(MODEL_MATRIX[1].xyz);
	mv[2] *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	float r = length(v_uv);
	if (r > 1.0) { discard; }
	float a = atan(v_uv.y, v_uv.x);
	float x = max(r - core, 0.0) / (1.0 - core);
	float halo = pow(clamp(1.0 - x, 0.0, 1.0), 3.2);
	float inner = exp(-x * 9.0);
	float ray_n = gnoise(vec3(cos(a) * 3.0, sin(a) * 3.0, TIME * 0.12), 801u) * 0.5 + 0.5;
	float ray_m = gnoise(vec3(cos(a) * 9.0, sin(a) * 9.0, TIME * 0.2 + 4.0), 807u) * 0.5 + 0.5;
	float rays = pow(clamp(ray_n * 0.7 + ray_m * 0.5, 0.0, 1.0), 2.2) * pow(clamp(1.0 - x, 0.0, 1.0), 1.6);
	float spikes = pow(abs(cos(a * 2.0)), 24.0) + pow(abs(sin(a * 2.0)), 24.0);
	float flare = spikes * pow(clamp(1.0 - x, 0.0, 1.0), 2.5) * 0.35;
	float v = halo * 0.55 + inner * 2.2 + rays * 0.9 + flare;
	ALBEDO = star_col * v * intensity;
}
