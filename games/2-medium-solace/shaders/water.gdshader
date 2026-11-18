shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;
uniform vec3 water_color : source_color = vec3(0.05, 0.28, 0.45);
uniform float alpha = 0.78;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float t = TIME;
	vec3 w = vec3(sin(lp.x * 0.35 + t * 1.3) + sin(lp.z * 0.5 - t * 1.1), sin(lp.y * 0.4 + t), cos(lp.z * 0.3 + lp.x * 0.2 + t * 0.9) + sin(lp.y * 0.6 - t * 1.4));
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(w * 0.05, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = water_color;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	ALPHA = clamp(alpha + fres * 0.3, 0.0, 1.0);
}
