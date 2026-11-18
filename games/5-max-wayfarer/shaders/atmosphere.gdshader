shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

// Single-scattering ray-marched atmosphere on a sphere shell (works from space and from inside).
// Applied over the already-rendered scene, clipped by the scene depth (terrain, objects) so it also gives aerial perspective.

uniform float planet_radius = 3000.0;
uniform float atmo_radius = 3800.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);      // world space, from planet towards the sun
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_intensity = 22.0;
uniform vec3 beta_r = vec3(0.0010, 0.0024, 0.0060);   // rayleigh scattering per metre
uniform float beta_m = 0.0003;
uniform float h_r = 180.0;
uniform float h_m = 90.0;
uniform float mie_g = 0.78;
uniform vec3 haze_tint : source_color = vec3(1.0);
uniform float strength = 1.0;
uniform float night_glow = 0.0;
uniform float inside_k = 7.0;
uniform float inside_cap = 0.62;
uniform float inside_sat = 1.35;
uniform vec3 inside_tint = vec3(1.0);   // saturating exposure used for views from inside the atmosphere (brings the sky up to a daylight level)
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float phase_r(float mu) {
	return 0.0596831 * (1.0 + mu * mu);
}

float phase_m(float mu, float g) {
	float g2 = g * g;
	return 0.0795775 * (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * mu, 1.5) * 1.0;
}

void fragment() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 dir = normalize(v_world - cam);
	vec3 oc = cam - center;

	float t_in;
	float t_out;
	if (!ray_sphere(oc, dir, atmo_radius, t_in, t_out)) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		t_in = max(t_in, 0.0);
		float depth = texture(depth_tex, SCREEN_UV).r;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float scene_dist = length(vp.xyz / vp.w);
		t_out = min(t_out, scene_dist);
		if (t_out <= t_in) {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
		} else {
			const int STEPS = 14;
			const int LSTEPS = 4;
			float seg = t_out - t_in;
			float ds = seg / float(STEPS);
			// jitter start to hide banding
			float jit = hash13(vec3(FRAGCOORD.xy, TIME * 0.0)) * 0.5;
			vec3 sum_r = vec3(0.0);
			vec3 sum_m = vec3(0.0);
			float od_r = 0.0;
			float od_m = 0.0;
			for (int i = 0; i < STEPS; i++) {
				float t = t_in + (float(i) + 0.5 + jit - 0.25) * ds;
				vec3 p = oc + dir * t;
				float hgt = max(length(p) - planet_radius, 0.0);
				float dr = exp(-hgt / h_r) * ds;
				float dm = exp(-hgt / h_m) * ds;
				od_r += dr;
				od_m += dm;
				float lt0;
				float lt1;
				float lit = 1.0;
				if (ray_sphere(p, sun_dir, atmo_radius, lt0, lt1)) {
					// planet shadow (soft)
					float tca = -dot(p, sun_dir);
					float cdist = 1e9;
					if (tca > 0.0) cdist = length(p + sun_dir * tca);
					lit = smoothstep(planet_radius * 0.985, planet_radius * 1.02, cdist);
					float od_lr = 0.0;
					float od_lm = 0.0;
					float lds = lt1 / float(LSTEPS);
					for (int j = 0; j < LSTEPS; j++) {
						vec3 pl = p + sun_dir * ((float(j) + 0.5) * lds);
						float hl = max(length(pl) - planet_radius, 0.0);
						od_lr += exp(-hl / h_r) * lds;
						od_lm += exp(-hl / h_m) * lds;
					}
					vec3 tau = beta_r * (od_r + od_lr) + vec3(beta_m * 1.1) * (od_m + od_lm);
					vec3 att = exp(-tau);
					sum_r += dr * att * lit;
					sum_m += dm * att * lit;
				}
			}
			float mu = dot(dir, sun_dir);
			vec3 col = sun_color * sun_intensity * (phase_r(mu) * beta_r * sum_r + phase_m(mu, mie_g) * vec3(beta_m) * sum_m);
			col *= haze_tint * strength;
			// inside the atmosphere: a saturating curve lifts the dim zenith sky while the bright horizon / sun glow cannot blow out
			float cam_h = max(length(oc) - planet_radius, 0.0);
			float inside = 1.0 - smoothstep(0.0, (atmo_radius - planet_radius) * 0.9, cam_h);
			if (inside > 0.001) {
				// luminance-preserving roll-off: keeps the hue (blue sky, red sunset) while lifting dim light
				float lum = dot(col, vec3(0.30, 0.55, 0.15));
				float k = (depth < 0.000001) ? inside_k : 1.0 + (inside_k - 1.0) * 0.25;
				float lum2 = (1.0 - exp(-lum * k)) * inside_cap;
				vec3 mapped = col * (lum2 / max(lum, 1e-5));
				float lm = dot(mapped, vec3(0.30, 0.55, 0.15));
				mapped = max(vec3(lm) + (mapped - vec3(lm)) * inside_sat, vec3(0.0)) * inside_tint;
				col = mix(col, mapped, inside);
			}
			// faint ambient glow so night-side limbs are not perfectly black
			col += haze_tint * night_glow * (1.0 - exp(-od_r * 0.002)) * 0.02;
			vec3 trans = exp(-(beta_r * od_r + vec3(beta_m * 1.1 * od_m)));
			float tavg = dot(trans, vec3(0.3333));
			float a = 1.0 - tavg;
			// a bright daytime sky drowns the stars behind it (only for empty-sky pixels, objects keep physical blending)
			if (depth < 0.000001) {
				a = clamp(a + dot(col, vec3(0.3333)) * 3.0, 0.0, 1.0);
			}
			ALBEDO = col;
			ALPHA = clamp(a, 0.0, 1.0) * strength;
		}
	}
}
