shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"
#include "res://shaders/starfield.gdshaderinc"

// Gravitational lensing of a Schwarzschild black hole on a camera facing billboard.
// Every pixel traces a light ray backwards from the camera with the photon orbit equation
//     a = -1.5 * h^2 * r / |r|^5     (units: horizon radius rs = 1, |v| = 1, h = |r x v| conserved)
// which reproduces the exact photon deflection of the Schwarzschild metric. The ray can
//   * fall into the horizon (black shadow), * cross the tilted accretion disc plane (hot, Doppler beamed emission,
//   several times for the lensed arches above/below the hole), * escape and look up the sky in the bent direction
//   (galaxy backdrop, or the already rendered scene through the screen texture so planets/stars behind it are lensed too).

uniform float rs = 620.0;
uniform float disc_in = 3.0;
uniform float disc_out = 14.0;
uniform float lens_half = 43400.0;
uniform mat3 bh_basis = mat3(1.0);
uniform mat3 sky_inv = mat3(1.0);
uniform vec3 galaxy_normal = vec3(0.22, 0.94, 0.26);
uniform vec3 galaxy_center_dir = vec3(0.72, 0.12, -0.68);
uniform vec3 nebula_a : source_color = vec3(0.30, 0.38, 0.85);
uniform vec3 nebula_b : source_color = vec3(0.80, 0.30, 0.55);
uniform float sky_seed = 3.0;
uniform float disc_power = 1.0;
uniform float spin_speed = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 v_world;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(lens_half * 2.0, 0.0, 0.0, 0.0), vec4(0.0, lens_half * 2.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_world = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 dir_in = normalize(v_world - cam);
	vec3 oc = cam - center;
	float t_c = -dot(oc, dir_in);
	float b_m = length(oc + dir_in * t_c);
	if (b_m > lens_half) {
		discard;
	}
	// objects nearer than the black hole (ship, planets in front) stay untouched
	float depth = texture(depth_tex, SCREEN_UV).r;
	bool is_sky = depth < 0.000001;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_d = length(vp.xyz / vp.w);
	if (!is_sky && t_c > 0.0 && scene_d < t_c - rs * 2.0) {
		discard;
	}

	mat3 inv_basis = transpose(bh_basis);
	vec3 pos = (inv_basis * oc) / rs;
	vec3 vel = normalize(inv_basis * dir_in);
	const float R_INT = 48.0;
	vec3 col = vec3(0.0);
	float T = 1.0;
	bool captured = false;
	float rmin = 1e9;
	bool far_path = false;

	float r0 = length(pos);
	if (r0 > R_INT) {
		float t0;
		float t1;
		if (ray_sphere(pos, vel, R_INT, t0, t1) && t1 > 0.0) {
			pos += vel * max(t0, 0.0);
		} else {
			far_path = true;
		}
	}
	vec3 dir_out_local = vel;
	if (far_path) {
		// weak field: bend towards the hole by 2/b (b in units of rs)
		vec3 pc0 = pos + vel * (-dot(pos, vel));
		float b = max(length(pc0), 0.001);
		dir_out_local = normalize(vel - (pc0 / b) * (2.0 / b));
	} else {
		float h2 = dot(cross(pos, vel), cross(pos, vel));
		for (int i = 0; i < 150; i++) {
			float r = length(pos);
			rmin = min(rmin, r);
			if (r < 1.0) {
				captured = true;
				break;
			}
			if (r > R_INT * 1.02 && dot(pos, vel) > 0.0) {
				break;
			}
			float dt = clamp(0.065 * r * (r < 5.0 ? 0.55 : 1.0), 0.018, 2.0);
			vec3 acc = -1.5 * h2 * pos / pow(r, 5.0);
			vec3 vn = normalize(vel + acc * dt);
			vec3 pn = pos + vn * dt;
			if (pos.y * pn.y < 0.0 && T > 0.02) {
				float f = pos.y / (pos.y - pn.y);
				vec3 pc = mix(pos, pn, f);
				float rr = length(pc.xz);
				if (rr > disc_in * 0.98 && rr < disc_out) {
					float phi = atan(pc.z, pc.x);
					float om = 0.55 * pow(disc_in / rr, 1.5);
					float ph = phi + TIME * om * 0.6 * spin_speed;
					float n = fbm3_lo(vec3(cos(ph) * rr * 0.85, sin(ph) * rr * 0.85, rr * 1.3));
					float n2 = vnoise(vec3(ph * 6.0, rr * 4.0, 3.0));
					float pat = 0.72 + 0.28 * sin(rr * 11.0 + n * 7.0);
					float radial = pow(disc_in / rr, 2.1);
					float edge = smoothstep(disc_in * 0.98, disc_in * 1.12, rr) * (1.0 - smoothstep(disc_out - 4.0, disc_out, rr));
					float temp = clamp(pow(disc_in / rr, 0.75), 0.0, 1.0);
					vec3 rad = normalize(vec3(pc.x, 0.0, pc.z) + vec3(1e-5));
					vec3 vorb = normalize(cross(vec3(0.0, 1.0, 0.0), rad));
					float beta = 0.52 * sqrt(disc_in / rr);
					float cth = dot(vorb, -vn);
					float D = clamp(1.0 / (sqrt(1.0 - beta * beta) * (1.0 - beta * cth)), 0.5, 1.75);
					float I = radial * (0.40 + 1.0 * n) * pat * (0.75 + 0.5 * n2) * edge * pow(D, 3.0) * disc_power;
					vec3 hc = heat_color(clamp(temp * 0.9 * pow(D, 0.6) + 0.10, 0.0, 1.0));
					float op = clamp(0.5 + 0.4 * n, 0.0, 0.93) * edge;
					col += T * hc * I * 1.5 * op;
					T *= (1.0 - op);
				}
			}
			vel = vn;
			pos = pn;
		}
		dir_out_local = vel;
	}
	if (!captured && !far_path) {
		// photon ring: rays that skim the photon sphere before escaping
		float ring = exp(-pow((rmin - 1.55) / 0.22, 2.0));
		col += T * vec3(1.0, 0.82, 0.58) * ring * 0.7;
	}

	vec3 bg = vec3(0.0);
	if (!captured) {
		vec3 dir_out = bh_basis * dir_out_local;
		float w = 1.0 - smoothstep(0.45, 1.0, b_m / lens_half);
		vec3 dir_final = normalize(mix(dir_in, dir_out, w));
		vec3 scene_col = vec3(0.0);
		bool use_screen = false;
		vec3 vd = (VIEW_MATRIX * vec4(dir_final, 0.0)).xyz;
		if (vd.z < -0.01) {
			vec4 cl = PROJECTION_MATRIX * vec4(vd, 1.0);
			vec2 uvq = cl.xy / cl.w * 0.5 + 0.5;
			if (uvq.x > 0.002 && uvq.y > 0.002 && uvq.x < 0.998 && uvq.y < 0.998) {
				float d2 = texture(depth_tex, uvq).r;
				if (d2 > 0.000001) {
					vec4 vp2 = INV_PROJECTION_MATRIX * vec4(uvq * 2.0 - 1.0, d2, 1.0);
					float sd2 = length(vp2.xyz / vp2.w);
					if (sd2 > max(t_c, 0.0) + rs) {
						scene_col = texture(screen_tex, uvq).rgb;
						use_screen = true;
					}
				}
			}
		}
		if (use_screen) {
			bg = scene_col;
		} else {
			bg = starfield(normalize(sky_inv * dir_final), galaxy_normal, galaxy_center_dir, nebula_a, nebula_b, sky_seed, 1.0, 1.0);
		}
	}
	// a little blue-shift tint near the shadow edge
	ALBEDO = col + T * bg;
	ALPHA = 1.0;
}
