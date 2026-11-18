shader_type spatial;
// Scanner pulse (module M4): a full-screen pass that rebuilds the world position of every pixel from the depth buffer and lights up
// everything at distance `scan_radius` from `scan_origin` (a travelling ring) with a short trailing wake + contour grid.
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 scan_origin = vec3(0.0);
uniform float scan_radius = 0.0;
uniform float scan_max = 600.0;
uniform float scan_width = 2.5;
uniform float scan_alpha = 1.0;
uniform vec4 scan_color : source_color = vec4(0.25, 0.9, 1.0, 1.0);
uniform float grid_cell = 5.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	if (depth <= 0.0) {
		discard;
	}
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	float d = length(wp - scan_origin);
	float behind = scan_radius - d;                       // > 0 inside the ring
	float ring = exp(-pow(behind / scan_width, 2.0));      // thin bright crest
	float wake = (behind > 0.0) ? exp(-behind / (scan_width * 7.0)) : 0.0;
	// contour grid on the swept surface: lines where the world position crosses grid planes
	vec3 g = abs(fract(wp / grid_cell) - 0.5);
	float gl = smoothstep(0.455, 0.5, max(g.x, max(g.y, g.z)));
	float grid = gl * wake * 0.7;
	float far_fade = pow(clamp(1.0 - scan_radius / scan_max, 0.0, 1.0), 0.6);
	float lead = (behind < 0.0) ? exp(behind / (scan_width * 0.6)) * 0.35 : 0.0;
	float e = (ring * 1.8 + wake * 0.22 + grid * 1.3 + lead) * far_fade * scan_alpha;
	vec3 col = mix(scan_color.rgb, vec3(1.0), ring * 0.55);
	ALBEDO = col * e * 2.2;
	ALPHA = 1.0;
}
