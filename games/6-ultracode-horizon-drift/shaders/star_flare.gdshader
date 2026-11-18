shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_add, fog_disabled;
// Lens flare overlay (module M2): full-screen additive quad, child of the star. Draws a screen-space glare (1/r core + soft halo that stay a sensible size even for a
// far, tiny star), an anamorphic streak, diffraction spikes and ghost discs / rings along the line from the star through the screen centre.
// Strength = visibility of the star (depth-tested at its screen position with a small kernel, i.e. planets / terrain / the ship hide it softly) x how close it is to
// the screen (fades once it leaves the view) x the global sun colour/energy (so it fades at night and reddens at sunset).

global uniform vec3 sun_color;
global uniform float sun_energy;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float strength = 1.0;
uniform float star_ang = 0.03;       // angular radius of the star (rad), for the kernel size and the glare size
uniform vec3 tint = vec3(1.0, 0.9, 0.7);

varying flat vec3 v_star_view;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
	v_star_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
}

float ring(float d, float r, float w) {
	return exp(-pow((d - r) / w, 2.0));
}

void fragment() {
	vec3 sv = v_star_view;
	if (sv.z > -1.0) {
		discard;     // behind the camera
	}
	vec4 sc = PROJECTION_MATRIX * vec4(sv, 1.0);
	vec2 sndc = sc.xy / sc.w;
	vec2 suv = sndc * 0.5 + 0.5;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	// visibility: sample the depth buffer around the star's screen position (a kernel of ~ the star's angular radius)
	float star_dist = length(sv);
	float vis = 0.0;
	float pix = max(star_ang * abs(PROJECTION_MATRIX[1][1]) * 0.5, 0.004);
	for (int i = 0; i < 9; i++) {
		float a = float(i) * 0.6981317;
		float rr = i == 0 ? 0.0 : pix * (0.3 + 0.7 * fract(float(i) * 0.618));
		vec2 uv = suv + vec2(cos(a) / aspect, sin(a)) * rr;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			continue;
		}
		float d = textureLod(depth_tex, uv, 0.0).r;
		float lin = 1e12;
		if (d > 1e-9) {
			vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d, 1.0);
			lin = length(v.xyz / v.w);
		}
		// not occluded if whatever is drawn there is (about) as far as the star
		vis += (lin > star_dist * 0.8 || d <= 1e-9) ? 1.0 : 0.0;
	}
	vis /= 9.0;
	float edge = 1.0 - smoothstep(0.85, 1.25, max(abs(sndc.x), abs(sndc.y)));   // fades as the star leaves the screen
	float k = vis * edge * strength;
	if (k < 0.002) {
		discard;
	}
	vec2 p = (SCREEN_UV * 2.0 - 1.0) * vec2(aspect, 1.0);
	vec2 s = sndc * vec2(aspect, 1.0);
	vec2 axis = -s;                                // line from the star through the centre, towards the opposite side
	vec2 dp = p - s;
	float r = length(dp);
	float ka = clamp(sqrt(star_ang / 0.03), 0.85, 1.5);        // a bigger (closer) star glares more, but a far one is still a blazing point
	vec3 col = vec3(0.0);
	// glare: 1/r core + soft halo
	col += tint * (0.016 / (r + 0.04)) * ka;
	col += tint * exp(-r * 4.0) * 0.10 * ka;
	// anamorphic streak (cool blue, horizontal) + a faint vertical one
	col += vec3(0.55, 0.68, 1.0) * exp(-abs(dp.y) * 120.0) * exp(-abs(dp.x) * 2.0) * 0.12 * ka;
	col += vec3(0.60, 0.70, 1.0) * exp(-abs(dp.x) * 150.0) * exp(-abs(dp.y) * 3.5) * 0.03 * ka;
	// diffraction spikes: 4 main + 4 faint diagonal, falling off with distance from the star
	float ang = atan(dp.y, dp.x);
	float spikes = pow(abs(cos(2.0 * ang)), 260.0) + 0.30 * pow(abs(sin(2.0 * ang)), 700.0);
	col += tint * spikes * exp(-r * 1.7) * (0.075 / (r * 5.0 + 0.25)) * ka;
	col += tint * ring(r, 0.34, 0.03) * 0.010 * ka;
	// ghosts (they all collapse onto the star when it sits at the screen centre: only show them once it is off-axis)
	float ghost_k = smoothstep(0.12, 0.55, length(s));
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float t = mix(0.35, 1.9, fi / 4.0) * (i % 2 == 0 ? 1.0 : -0.55);
		vec2 gp = s + axis * t;
		float gr = mix(0.05, 0.16, fract(fi * 0.37 + 0.2));
		float dg = length(p - gp);
		vec3 gc = mix(vec3(0.4, 0.7, 1.0), vec3(1.0, 0.6, 0.3), fract(fi * 0.53));
		col += gc * (smoothstep(gr, gr * 0.6, dg) * 0.012 + ring(dg, gr * 1.05, 0.012) * 0.022) * (1.0 - length(s) * 0.35) * ghost_k;
	}
	vec3 sc_col = sun_color * clamp(sun_energy / 2.4, 0.0, 1.5);
	ALBEDO = col * k * sc_col;
	ALPHA = 1.0;
}
