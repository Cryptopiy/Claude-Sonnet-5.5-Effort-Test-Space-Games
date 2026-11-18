shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;
// Emissive star surface with granulation and limb darkening (HDR, drives bloom).

#include "res://shaders/inc/tnoise.gdshaderinc"

uniform vec3 star_col : source_color = vec3(1.0, 0.85, 0.6);
uniform float intensity = 6.0;
uniform int seed = 1;

varying vec3 v_p;

void vertex() {
	v_p = normalize(VERTEX);
}

void fragment() {
	vec3 p = normalize(v_p);
	float g = tn_fbm(p * 7.0 + vec3(TIME * 0.04, TIME * 0.02, 0.0), 4, 0.55, seed) * 0.5 + 0.5;
	float spots = smoothstep(0.62, 0.7, tn_fbm(p * 2.2 + vec3(5.0, 1.0, 3.0), 3, 0.5, seed + 1) * 0.5 + 0.5);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float limb = 0.3 + 0.7 * pow(ndv, 0.45);
	vec3 c = star_col * (0.8 + 0.5 * g) * limb * (1.0 - 0.55 * spots);
	c = mix(c, vec3(1.0, 0.97, 0.9), pow(ndv, 3.0) * 0.35);
	ALBEDO = c * intensity;
}
