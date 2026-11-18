shader_type spatial;
// Vertical light shaft for landing pads / revealed points of interest (module M7a). Additive, unshaded, fades with height.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 beam_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float intensity = 1.6;
uniform float beam_height = 150.0;
uniform float pulse_speed = 1.6;
uniform float night_boost = 1.0;

varying float vy;

void vertex() {
	vy = clamp(VERTEX.y / beam_height + 0.5, 0.0, 1.0);
}

void fragment() {
	float fade = pow(1.0 - vy, 1.7) * smoothstep(0.0, 0.03, vy);
	float bands = 0.72 + 0.28 * sin(vy * 46.0 - TIME * pulse_speed * 3.0);
	float soft = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	ALBEDO = beam_color.rgb * intensity;
	ALPHA = clamp(fade * bands * soft * beam_color.a, 0.0, 1.0);
}
