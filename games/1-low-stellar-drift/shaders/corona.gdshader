shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 col : source_color = vec3(1.0, 0.8, 0.4);
uniform float inner = 0.2;
void vertex(){
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment(){
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float g = exp(-max(r - inner, 0.0) * 5.0) * smoothstep(1.0, 0.7, r);
	float rays = 0.5 + 0.5 * sin(a * 11.0 + TIME * 0.2) * sin(a * 5.0 - TIME * 0.13);
	float flare = pow(max(1.0 - r, 0.0), 3.0) * (0.3 + rays) * 0.8;
	float spikes = pow(max(1.0 - abs(p.x) * 14.0, 0.0), 2.0) * (1.0 - r) + pow(max(1.0 - abs(p.y) * 14.0, 0.0), 2.0) * (1.0 - r);
	ALBEDO = col * (g * 1.6 + flare + spikes * 0.6);
	ALPHA = 1.0;
}
