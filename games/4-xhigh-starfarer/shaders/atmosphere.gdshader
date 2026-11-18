shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Single-scattering atmosphere rendered on a shell mesh slightly larger than the atmosphere.
// Works from space (front faces) and from inside (back faces) with the same integral.

uniform float planet_r = 5000.0;
uniform float atmo_h = 2500.0;
uniform vec3 beta_r = vec3(5.5e-5, 1.3e-4, 3.4e-4);
uniform float beta_m = 2.5e-5;
uniform float density = 1.0;
uniform vec3 sun_dir_w = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.88);
uniform float sun_int = 20.0;
uniform float exposure = 1.0;
uniform float mie_g = 0.76;

varying vec3 v_cam_local;
varying vec3 v_sun_local;

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float d = b * b - c;
	if (d < 0.0) {
		return vec2(1e20, -1e20);
	}
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

void vertex() {
	mat3 inv_rot = transpose(mat3(MODEL_MATRIX));
	v_cam_local = inv_rot * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	v_sun_local = inv_rot * normalize(sun_dir_w);
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd_w = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 rd = transpose(mat3(MODEL_MATRIX)) * rd_w;
	vec3 ro = v_cam_local;
	float r_top = planet_r + atmo_h;
	bool inside = length(ro) < r_top;
	// draw front faces from outside, back faces from inside (exactly one layer per pixel)
	if (inside == FRONT_FACING) {
		discard;
	}
	vec2 ta = ray_sphere(ro, rd, r_top);
	if (ta.y < 0.0) {
		discard;
	}
	float t0 = max(ta.x, 0.0);
	float t1 = ta.y;
	// valleys / sea level lie below the nominal radius, so the 'ground' sphere used for occlusion is lowered
	float gr = planet_r - 450.0;
	vec2 tg = ray_sphere(ro, rd, gr);
	if (tg.y > 0.0) {
		float tgn = max(tg.x, 0.0);
		if (tgn >= t0 - 1.0) {
			t1 = min(t1, tgn);
		}
	}
	if (t1 <= t0) {
		discard;
	}
	float hr = atmo_h * 0.28;
	float hm = atmo_h * 0.10;
	vec3 br = beta_r * density;
	float bm = beta_m * density;
	const int NS = 14;
	const int NL = 5;
	float dt = (t1 - t0) / float(NS);
	vec3 sum_r = vec3(0.0);
	vec3 sum_m = vec3(0.0);
	float od_r = 0.0;
	float od_m = 0.0;
	vec3 sl = normalize(v_sun_local);
	float mu = dot(rd, sl);
	float pr = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	float g = mie_g;
	float pm = 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
	for (int i = 0; i < NS; i++) {
		vec3 p = ro + rd * (t0 + (float(i) + 0.5) * dt);
		float h = max(length(p) - planet_r, 0.0);
		float dr = exp(-h / hr) * dt;
		float dm = exp(-h / hm) * dt;
		od_r += dr;
		od_m += dm;
		vec2 tp = ray_sphere(p, sl, gr);
		if (tp.y > 0.0 && tp.x > 0.0) {
			continue;
		}
		vec2 tl = ray_sphere(p, sl, r_top);
		float dl = tl.y / float(NL);
		float lor = 0.0;
		float lom = 0.0;
		for (int j = 0; j < NL; j++) {
			vec3 q = p + sl * ((float(j) + 0.5) * dl);
			float hq = max(length(q) - planet_r, 0.0);
			lor += exp(-hq / hr) * dl;
			lom += exp(-hq / hm) * dl;
		}
		vec3 tau = br * (od_r + lor) + bm * 1.1 * (od_m + lom);
		vec3 att = exp(-tau);
		sum_r += att * dr;
		sum_m += att * dm;
	}
	vec3 col = sun_col * sun_int * (sum_r * br * pr + sum_m * bm * pm);
	ALBEDO = col * exposure;
}
