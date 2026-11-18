shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 star_color : source_color = vec3(1.0, 0.9, 0.6);
uniform float core_radius = 0.25;
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= sx;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rays = 0.7 + 0.3 * sin(ang * 9.0 + TIME * 0.15) * sin(ang * 5.0 - TIME * 0.1);
	float glow = exp(-max(r - core_radius, 0.0) * 5.5) * smoothstep(1.0, 0.75, r);
	float halo = exp(-r * 2.2) * 0.35 * smoothstep(1.0, 0.8, r);
	float i = glow * rays + halo;
	ALBEDO = star_color * i * 1.6;
}
