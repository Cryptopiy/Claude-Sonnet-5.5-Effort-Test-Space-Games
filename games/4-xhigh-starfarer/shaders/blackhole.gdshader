shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// Black hole: every pixel of a camera-facing quad integrates a light ray through Schwarzschild spacetime
// (photon acceleration a = -1.5 * h^2 * r / |r|^5, units of the Schwarzschild radius). Rays that fall inside the
// horizon are black, rays crossing the accretion-disc plane pick up emission (with Doppler beaming), escaping rays
// sample the already-rendered scene (stars, planets) at the deflected direction => gravitational lensing.

#include "res://shaders/inc/tnoise.gdshaderinc"

uniform float rs = 900.0;
uniform float disc_in = 2.7;
uniform float disc_out = 11.0;
uniform float disc_bright = 3.2;
uniform vec3 disc_hot : source_color = vec3(1.0, 0.93, 0.78);
uniform vec3 disc_cool : source_color = vec3(1.0, 0.33, 0.04);
uniform float spin = 0.7;
uniform int seed = 7;
uniform float lens_rs = 16.0;
uniform float amount = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = mv;
}

vec3 disc_emission(vec3 hit, vec3 dirv, float t_rot) {
	float rr = length(hit.xz);
	float temp = pow(disc_in / rr, 0.75);
	vec3 base = mix(disc_cool, disc_hot, clamp(temp * 1.35 - 0.12, 0.0, 1.0));
	float ang = atan(hit.z, hit.x);
	float rot = t_rot * spin * pow(rr, -1.5) * 9.0;
	float a2 = ang - rot;
	vec3 q = vec3(cos(a2) * rr * 0.55, sin(a2) * rr * 0.55, rr * 1.2);
	float n = tn_fbm(q * 1.6, 4, 0.55, seed) * 0.5 + 0.5;
	float n2 = tn_fbm(vec3(q.x * 4.0, q.y * 4.0, q.z * 0.5), 3, 0.5, seed + 1) * 0.5 + 0.5;
	float streak = smoothstep(0.22, 0.78, n) * (0.55 + 0.6 * n2);
	float edge = smoothstep(disc_in, disc_in + 0.35, rr) * (1.0 - smoothstep(disc_out * 0.55, disc_out, rr));
	// relativistic beaming: material orbits counter-clockwise seen from +Y
	vec3 radial = normalize(vec3(hit.x, 0.0, hit.z));
	vec3 vd = vec3(-radial.z, 0.0, radial.x);
	float v = clamp(sqrt(0.5 / rr), 0.0, 0.6);
	float cosang = dot(vd, -normalize(dirv));
	float D = sqrt(1.0 - v * v) / max(1.0 - v * cosang, 0.15);
	float beam = pow(D, 3.2);
	return base * streak * edge * temp * disc_bright * clamp(beam, 0.05, 6.0);
}

void fragment() {
	vec2 uvq = UV * 2.0 - 1.0;
	float qr = length(uvq);
	if (qr > 1.0) {
		discard;
	}
	vec3 rd_w = mat3(INV_VIEW_MATRIX) * normalize(VERTEX);
	vec3 bh_c = MODEL_MATRIX[3].xyz;
	mat3 R = mat3(normalize(MODEL_MATRIX[0].xyz), normalize(MODEL_MATRIX[1].xyz), normalize(MODEL_MATRIX[2].xyz));
	mat3 Rt = transpose(R);
	vec3 ro = (Rt * (CAMERA_POSITION_WORLD - bh_c)) / rs;
	vec3 rd = normalize(Rt * rd_w);
	vec3 pos = ro;
	vec3 vel = rd;
	vec3 cr = cross(pos, vel);
	float h2 = dot(cr, cr);
	float b_imp = sqrt(h2);
	vec3 col = vec3(0.0);
	float trans = 1.0;
	bool captured = false;
	bool hit_disc = false;
	for (int i = 0; i < 120; i++) {
		float r2 = dot(pos, pos);
		float r = sqrt(r2);
		if (r < 1.0) {
			captured = true;
			break;
		}
		if (r > 60.0 && dot(pos, vel) > 0.0) {
			break;
		}
		float dt = clamp(0.07 * (r - 0.6) + 0.025, 0.03, 1.4);
		vec3 acc = -1.5 * h2 * pos / (r2 * r2 * r);
		vel += acc * dt;
		vec3 npos = pos + vel * dt;
		if (pos.y * npos.y < 0.0) {
			float f = pos.y / (pos.y - npos.y);
			vec3 hp = mix(pos, npos, f);
			float hr = length(hp.xz);
			if (hr > disc_in && hr < disc_out) {
				vec3 em = disc_emission(hp, vel, TIME);
				float dens = clamp(length(em) * 0.35, 0.0, 0.9);
				col += em * trans;
				trans *= (1.0 - dens);
				hit_disc = true;
			}
		}
		pos = npos;
	}
	vec3 bg = vec3(0.0);
	float defl = 0.0;
	if (!captured) {
		vec3 dir_w = normalize(R * normalize(vel));
		defl = acos(clamp(dot(normalize(vel), rd), -1.0, 1.0));
		vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dir_w * 100000.0, 1.0);
		if (clip.w > 0.0) {
			vec2 ndc = clip.xy / clip.w;
			vec2 suv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
			float inside = smoothstep(0.0, 0.04, suv.x) * smoothstep(1.0, 0.96, suv.x) * smoothstep(0.0, 0.04, suv.y) * smoothstep(1.0, 0.96, suv.y);
			bg = textureLod(screen_tex, clamp(suv, vec2(0.001), vec2(0.999)), 0.0).rgb * inside;
		}
	}
	// photon ring (light orbiting at 1.5 rs shows up near b = 2.6 rs)
	float ring = exp(-pow((b_imp - 2.6) / 0.075, 2.0));
	vec3 ring_col = vec3(1.0, 0.82, 0.55) * ring * 1.6;
	vec3 result = col + bg * trans + ring_col * (captured ? 0.6 : 1.0) * trans;
	float mask = captured ? 1.0 : max(smoothstep(0.0015, 0.02, defl), hit_disc ? 1.0 : 0.0);
	mask = max(mask, ring);
	mask *= smoothstep(1.0, 0.82, qr);
	ALBEDO = result;
	ALPHA = clamp(mask * amount, 0.0, 1.0);
}
