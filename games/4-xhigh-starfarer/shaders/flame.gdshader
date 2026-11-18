shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// Engine exhaust cone (mesh runs from z=0 at the nozzle to z=+3.4..4.2 behind the ship).

uniform vec3 col_core : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 col_edge : source_color = vec3(0.15, 0.3, 1.0);
uniform float intensity = 1.0;
uniform float flame_len = 3.8;

varying float v_t;

void vertex() {
	v_t = clamp(length(VERTEX) / flame_len, 0.0, 1.0);
}

void fragment() {
	float core = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float flick = 0.85 + 0.15 * sin(TIME * 70.0 + v_t * 18.0);
	float fade = pow(1.0 - v_t, 1.3);
	vec3 c = mix(col_core, col_edge, smoothstep(0.0, 0.8, v_t)) * (core * 1.2 + 0.15) * fade * intensity * flick;
	ALBEDO = c * 0.9;
}
