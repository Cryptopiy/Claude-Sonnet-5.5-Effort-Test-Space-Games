shader_type spatial;
// WEATHER FOG (module m7b_life): full-screen, depth-aware tinted haze that thickens during dust storms / blizzards / spore mist.
// Pure alpha blend (does not read the screen texture) so it composes with whatever other post-process quads (atmosphere) drew before it.
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.8, 0.6, 0.35, 1.0);
uniform float density = 0.01;        // 1/m
uniform float start_dist = 4.0;
uniform float max_alpha = 0.9;
uniform float sky_dist = 2500.0;     // distance assumed for sky pixels (depth = far)
uniform float light = 1.0;           // day/night multiplier of the fog colour
uniform float scatter = 0.6;         // forward scattering towards the sun
uniform vec3 sun_world = vec3(0.0, 1.0, 0.0);
uniform float height_fade = 0.0;     // fog thinning with camera-space height (0 = uniform)
uniform float amount = 1.0;

varying vec3 v_view_dir;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float dist = depth < 0.00001 ? sky_dist : min(length(view.xyz), sky_dist);
	vec3 vdir = normalize(view.xyz);
	vec3 wdir = (INV_VIEW_MATRIX * vec4(vdir, 0.0)).xyz;
	float f = 1.0 - exp(-density * max(dist - start_dist, 0.0));
	float sun = pow(max(dot(wdir, sun_world), 0.0), 6.0);
	vec3 col = fog_color.rgb * light * (1.0 + scatter * sun);
	ALBEDO = col;
	ALPHA = clamp(f * max_alpha * amount, 0.0, 1.0);
}
