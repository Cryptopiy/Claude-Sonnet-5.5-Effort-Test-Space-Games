shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 star_col : source_color = vec3(1.0, 0.9, 0.65);
uniform float intensity = 4.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 d = normalize(v_local);
	float t = TIME * 0.05;
	float n = fbm(d * 6.0 + vec3(t, t * 0.7, -t), 701u, 5) * 0.5 + 0.5;
	float n2 = fbm(d * 22.0 + vec3(-t * 2.0, t, t), 709u, 3) * 0.5 + 0.5;
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float limb = pow(ndv, 0.55);
	vec3 hot = star_col * 1.0 + vec3(0.15);
	vec3 cool = star_col * vec3(0.85, 0.55, 0.35);
	vec3 c = mix(cool, hot, smoothstep(0.25, 0.8, n * 0.7 + n2 * 0.3));
	ALBEDO = c * intensity * mix(0.45, 1.0, limb);
}
