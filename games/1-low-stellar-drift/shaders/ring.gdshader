shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec3 col : source_color = vec3(0.8, 0.7, 0.55);
uniform float inner = 0.55;
varying vec3 lp;
void vertex(){ lp = VERTEX; }
void fragment(){
	float r = length(lp.xz) / 0.5;
	float x = (r - inner) / (1.0 - inner);
	float bands = 0.5 + 0.5 * sin(x * 70.0) * sin(x * 23.0 + 1.0);
	ALBEDO = col * (0.6 + 0.5 * bands);
	ALPHA = smoothstep(0.0, 0.08, x) * smoothstep(1.0, 0.9, x) * (0.25 + 0.65 * bands);
	ROUGHNESS = 1.0;
}
