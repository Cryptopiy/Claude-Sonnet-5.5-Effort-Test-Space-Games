shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled, shadows_disabled;
// Atmospheric entry plasma sheath around the ship (fresnel glow + streaming noise).

#include "res://shaders/inc/tnoise.gdshaderinc"

uniform float heat = 0.0;

varying vec3 v_p;

void vertex() {
	v_p = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	float n = tn_fbm(vec3(v_p.x * 2.0, v_p.y * 2.0, v_p.z * 1.2 - TIME * 6.0), 3, 0.5, 5) * 0.5 + 0.5;
	vec3 hot = mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.85, 0.5), n * heat);
	ALBEDO = hot * (fres * 1.6 + 0.12) * (0.4 + n) * heat * 2.4;
}
