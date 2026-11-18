shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// Engine / jetpack exhaust cone. Mesh: cone along local +Z (UV.y: 0 at the nozzle -> 1 at the tip).
uniform vec3 color_core : source_color = vec3(0.75, 0.92, 1.0);
uniform vec3 color_edge : source_color = vec3(0.10, 0.45, 1.0);
uniform float power = 1.0;
uniform float flicker = 1.0;

void fragment() {
	float t = UV.y;
	float edge = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.4);
	float fl = 0.75 + 0.25 * sin(TIME * 47.0 + t * 12.0) * flicker + 0.15 * sin(TIME * 91.0 - t * 7.0);
	float n = vnoise(vec3(t * 6.0 - TIME * 9.0, UV.x * 6.28, TIME * 3.0));
	float fall = pow(1.0 - t, 1.7);
	vec3 col = mix(color_edge, color_core, edge * (1.0 - t * 0.6)) * fall * (0.7 + 0.6 * n) * fl;
	ALBEDO = col * power * 2.4;
}
