shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// Atmospheric-entry plasma sheath around the ship: a stretched shell seen from the inside.
// Mostly a fresnel rim (bow shock) with streaks flowing backwards (+Z), brightest at the nose.
uniform float heat = 0.0;
uniform vec3 hot_color : source_color = vec3(1.0, 0.42, 0.12);
uniform vec3 core_color : source_color = vec3(1.0, 0.88, 0.62);

varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(abs(dot(n, v)), 0.0, 1.0), 2.4);
	float nose = clamp(-normalize(v_obj).z * 0.5 + 0.5, 0.0, 1.0);
	float streak = fbm3_lo(vec3(v_obj.x * 0.9, v_obj.y * 1.1, v_obj.z * 0.16 + TIME * 9.0));
	float s = fres * (0.35 + 1.1 * nose * nose) * (0.45 + 1.3 * streak) + 0.03 * nose;
	vec3 col = mix(hot_color, core_color, nose * nose) * s;
	ALBEDO = col * heat * heat * 3.2;
}
