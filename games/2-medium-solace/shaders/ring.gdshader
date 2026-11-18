shader_type spatial;
render_mode cull_disabled, diffuse_burley, depth_draw_opaque;
uniform vec3 col : source_color = vec3(0.8, 0.7, 0.55);
void fragment() {
	float r = UV.x;
	float bands = 0.5 + 0.5 * sin(r * 160.0) * sin(r * 47.0 + 1.0);
	float gaps = smoothstep(0.0, 0.05, abs(r - 0.62)) * smoothstep(0.0, 0.03, abs(r - 0.42));
	ALBEDO = col * (0.55 + 0.6 * bands);
	ALPHA = clamp(smoothstep(0.0, 0.08, r) * smoothstep(1.0, 0.9, r) * (0.35 + 0.6 * bands) * gaps, 0.0, 0.92);
	ROUGHNESS = 1.0;
}
