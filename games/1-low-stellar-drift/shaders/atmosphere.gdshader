shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform vec3 col : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float intensity = 1.5;
void fragment(){
	vec3 n = normalize(NORMAL);
	float f = pow(1.0 - max(dot(n, normalize(VIEW)), 0.0), 2.6);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float lit = clamp(dot(wn, sun_dir) + 0.3, 0.0, 1.0);
	ALBEDO = col * f * lit * intensity;
}
