shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// Star photosphere: granulation, sunspots, limb darkening. HDR output (feeds the bloom).

uniform vec3 star_color : source_color = vec3(1.0, 0.92, 0.72);
uniform float intensity = 7.0;
uniform float seed = 1.0;

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float t = TIME * 0.025;
	float n1 = fbm3(d * 5.5 + vec3(t, 0.0, t * 0.7) + seed);
	float n2 = fbm3(d * 15.0 - vec3(0.0, t * 2.0, 0.0) + seed * 2.0);
	float spots = smoothstep(0.60, 0.74, fbm3(d * 2.3 + seed * 3.0 + vec3(0.0, t * 0.3, 0.0))) * 0.6;
	float limb = pow(clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 0.55);
	vec3 col = star_color * (0.72 + 0.55 * n1 + 0.3 * n2) * (1.0 - spots);
	col = mix(col, vec3(1.0, 0.98, 0.92), 0.22 * n2);
	col *= 0.35 + 0.65 * limb;
	ALBEDO = col * intensity;
}
