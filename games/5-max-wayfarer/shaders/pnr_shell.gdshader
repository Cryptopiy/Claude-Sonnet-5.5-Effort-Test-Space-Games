shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// Holographic "point of no return" shell around a black hole: faint red grid with a pulsing fresnel rim.
uniform vec3 color : source_color = vec3(1.0, 0.18, 0.12);
uniform float fade = 1.0;
uniform float pulse = 0.0;

varying vec3 v_obj;

void vertex() {
	v_obj = normalize(VERTEX);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.2);
	float lat = asin(clamp(v_obj.y, -1.0, 1.0));
	float lon = atan(v_obj.z, v_obj.x);
	float grid = max(smoothstep(0.93, 1.0, abs(sin(lat * 18.0))), smoothstep(0.93, 1.0, abs(sin(lon * 18.0))));
	float scan = smoothstep(0.9, 1.0, sin(lat * 6.0 - TIME * 2.2) * 0.5 + 0.5);
	float a = (0.008 + fres * 0.15 + grid * 0.07 + scan * 0.03) * fade * (0.6 + 0.4 * sin(TIME * 5.0 * (1.0 + pulse)));
	ALBEDO = color * a * 1.1;
}
