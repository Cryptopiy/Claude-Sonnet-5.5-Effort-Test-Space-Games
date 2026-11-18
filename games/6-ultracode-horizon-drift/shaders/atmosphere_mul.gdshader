shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mul, fog_disabled;
// Atmosphere pass 1/2: multiplies everything behind the atmosphere by its per-channel transmittance (reddened sun, aerial perspective).
#include "res://shaders/atmosphere_common.gdshaderinc"

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 ro;
	vec3 rd;
	float t0;
	float t1;
	float geo;
	if (!atmo_setup(SCREEN_UV, NODE_POSITION_WORLD, CAMERA_POSITION_WORLD, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, ro, rd, t0, t1, geo)) {
		discard;
	}
	vec3 trans;
	vec3 L;
	atmo_integrate(ro, rd, t0, t1, geo, false, trans, L);
	ALBEDO = trans;
	ALPHA = 1.0;
}
