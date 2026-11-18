// Shared analytic single-scattering atmosphere model (module M2). Included by atmosphere_add.gdshader (in-scatter, blend_add) and
// atmosphere_mul.gdshader (extinction, blend_mul). Both are full-screen quads drawn AFTER every other transparent object, so clouds, ocean,
// particles, the star and the stars-in-the-sky are all attenuated per colour channel and receive the in-scattered light.
// Planet-relative maths is done in float32 with the camera-relative origin (planet centre = NODE_POSITION_WORLD of the effect node).

global uniform vec3 sun_dir;
global uniform float night_amount;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform float planet_radius = 9000.0;
uniform float atmo_top = 6400.0;          // thickness of the integration shell above planet_radius
uniform float h_rayleigh = 900.0;
uniform float h_mie = 300.0;
uniform vec3 beta_r = vec3(3.3e-5, 8.4e-5, 1.9e-4);
uniform vec3 beta_m = vec3(1.0e-4);
uniform vec3 beta_m_ext = vec3(1.1e-4);
uniform float mie_g = 0.78;
uniform vec3 star_light = vec3(55.0);
uniform float sea_radius = 0.0;           // 0 = no ocean; otherwise the liquid sphere clips the view ray (consistent haze over water)
uniform float sun_ang = 0.03;             // angular radius of the star as seen from the camera (rad) -> soft planet shadow
uniform float dens_boost = 1.0;           // Mie density multiplier (dust storms, fog banks, descent into a gas giant)
uniform vec3 glow_color = vec3(0.0);
uniform float glow_amount = 0.0;
uniform float glow_h = 500.0;
uniform vec3 night_glow = vec3(0.0);
uniform float out_gain = 1.0;
uniform float sky_sat = 1.0;              // chroma of the in-scattered light (per biome, art direction; applied to sky pixels and the far haze only)
uniform vec3 sky_tint = vec3(1.0);        // per-channel gain of the in-scattered light (art direction, same rules as sky_sat)
uniform float light_boost = 1.0;          // multiplies the part of the sunlight path that exceeds a vertical path: small planets get Earth-like red sunsets
uniform float ground_haze = 0.30;         // fraction of the atmosphere density that is applied to rays ending on geometry near the camera (gentle aerial perspective)

const float PI_A = 3.14159265;
const int NH = 10;       // view samples per half ray (split at the closest approach to the planet centre)
const int NL = 6;        // light samples

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	vec3 q = ro - rd * b;
	float d = r * r - dot(q, q);
	if (d < 0.0) {
		return vec2(1e30, -1e30);
	}
	float s = sqrt(d);
	return vec2(-b - s, -b + s);
}

// Sets up the view ray and the integration interval [t0, t1] along it. Returns false if this pixel needs no atmosphere.
bool atmo_setup(vec2 uv, vec3 node_pos, vec3 cam_pos, mat4 inv_proj, mat4 inv_view, out vec3 ro, out vec3 rd, out float t0, out float t1, out float geo) {
	ro = cam_pos - node_pos;
	geo = 0.0;
	t0 = 0.0;
	t1 = 0.0;
	vec4 vn = inv_proj * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
	vec3 vdir = normalize(vn.xyz / vn.w);
	rd = normalize((inv_view * vec4(vdir, 0.0)).xyz);
	float r_top = planet_radius + atmo_top;
	vec2 ta = ray_sphere(ro, rd, r_top);
	if (ta.y <= 0.0) {
		return false;
	}
	float rr = length(ro);
	if (sea_radius > 0.0 && rr < sea_radius) {
		return false;     // camera is under the liquid surface: the ocean shader renders the underwater view
	}
	t0 = max(ta.x, 0.0);
	t1 = ta.y;
	float d = textureLod(depth_tex, uv, 0.0).r;
	if (d > 1e-7) {
		vec4 vv = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
		vv.xyz /= vv.w;
		float tg0 = length(vv.xyz);
		if (tg0 < t1) {
			geo = 1.0;
		}
		t1 = min(t1, tg0);
	} else {
		vec2 tg = ray_sphere(ro, rd, planet_radius - 40.0);
		if (tg.x > t0 && tg.x < t1) {
			t1 = tg.x;
			geo = 1.0;
		}
	}
	if (sea_radius > 0.0) {
		vec2 ts = ray_sphere(ro, rd, sea_radius);
		if (ts.x > t0 && ts.x < t1) {
			t1 = ts.x;
			geo = 1.0;
		}
	}
	return t1 > t0;
}

// trans = rgb transmittance of the segment, L = in-scattered radiance (only computed when full == true)
void atmo_integrate(vec3 ro, vec3 rd, float t0, float t1, float geo, bool full, out vec3 trans, out vec3 L) {
	float r_top = planet_radius + atmo_top;
	vec3 sd = normalize(sun_dir);
	float mu = dot(rd, sd);
	float g = mie_g;
	float g2 = g * g;
	float phase_r = 3.0 / (16.0 * PI_A) * (1.0 + mu * mu);
	float phase_m = 3.0 / (8.0 * PI_A) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-3), 1.5));
	float tc = clamp(-dot(ro, rd), t0, t1);
	// aerial perspective on geometry is kept gentle near the camera (terrain keeps its own colours and contrast) and ramps up to the full physical
	// density towards the horizon distance / when looking from high above (so the terrain still melts into the sky at the limit of visibility)
	float rr0 = length(ro);
	float hd = sqrt(max(rr0 * rr0 - planet_radius * planet_radius, 0.0));
	float ramp = smoothstep(0.45, 1.0, t1 / max(hd, 300.0));
	float high = smoothstep(atmo_top * 0.3, atmo_top, rr0 - planet_radius);
	float far_k = max(ramp, high);
	float dm = mix(1.0, mix(ground_haze, 1.0, far_k), geo);
	float tw = mix(1.0, far_k, geo);                                      // how much of the sky art direction applies to this pixel (sky = 1, near terrain = 0)
	tw *= 1.0 - smoothstep(atmo_top * 0.6, atmo_top * 1.6, rr0 - planet_radius);      // physical limb glow from space
	vec2 od = vec2(0.0);
	vec3 sum_r = vec3(0.0);
	vec3 sum_m = vec3(0.0);
	vec3 sum_g = vec3(0.0);
	vec3 sum_n = vec3(0.0);
	for (int half_i = 0; half_i < 2; half_i++) {
		float len = half_i == 0 ? (tc - t0) : (t1 - tc);
		if (len <= 0.0) {
			continue;
		}
		for (int i = 0; i < NH; i++) {
			float u = (float(i) + 0.5) / float(NH);
			float t;
			float ds;
			if (half_i == 0) {
				float w = 1.0 - u;
				t = t0 + len * (1.0 - w * w);
				ds = len * 2.0 * w / float(NH);
			} else {
				t = tc + len * u * u;
				ds = len * 2.0 * u / float(NH);
			}
			vec3 p = ro + rd * t;
			float h = max(length(p) - planet_radius, -400.0);
			vec2 rho = vec2(exp(-h / h_rayleigh), exp(-h / h_mie) * dens_boost) * dm;
			vec2 step_od = rho * ds;
			vec3 tau = beta_r * (od.x + 0.5 * step_od.x) + beta_m_ext * (od.y + 0.5 * step_od.y);
			od += step_od;
			if (full) {
				vec3 tv = exp(-tau);
				// optical depth towards the star
				float lt = ray_sphere(p, sd, r_top).y;
				vec2 lod = vec2(0.0);
				for (int j = 0; j < NL; j++) {
					float lu = (float(j) + 0.5) / float(NL);
					float lh = max(length(p + sd * (lt * lu * lu)) - planet_radius, -400.0);
					lod += vec2(exp(-lh / h_rayleigh), exp(-lh / h_mie) * dens_boost) * (lt * 2.0 * lu / float(NL));
				}
				vec2 vod = vec2(h_rayleigh * exp(-h / h_rayleigh), h_mie * exp(-h / h_mie) * dens_boost);   // optical depth of the straight-up path from here
				lod = vod + max(lod - vod, vec2(0.0)) * light_boost;
				vec3 tl = exp(-(beta_r * lod.x + beta_m_ext * lod.y));
				// planet shadow with a penumbra that follows the star's angular size
				float bq = dot(p, sd);
				float hmin = bq < 0.0 ? sqrt(max(dot(p, p) - bq * bq, 0.0)) : 1e9;
				float pen = max(-bq, 0.0) * sun_ang + 12.0;
				float shadow = smoothstep(planet_radius - pen, planet_radius + pen, hmin);
				vec3 s = tv * tl * shadow;
				sum_r += s * step_od.x;
				sum_m += s * step_od.y;
				sum_g += tv * exp(-h / glow_h) * ds;
				sum_n += tv * step_od.x;
			}
		}
	}
	trans = exp(-(beta_r * od.x + beta_m_ext * od.y));
	L = vec3(0.0);
	if (full) {
		L = star_light * (beta_r * sum_r * phase_r + beta_m * sum_m * phase_m);
		L += glow_color * glow_amount * (sum_g / h_mie);
		L += night_glow * (sum_n / h_rayleigh);
		L *= out_gain;
			// art direction: single scattering + filmic tonemap desaturates a Rayleigh sky; push the chroma back (the horizon stays pale because all channels saturate there)
			// by day the per-channel tint gives the biome its sky colour; towards dusk it fades to its (neutral) mean gain so the physically reddened light
			// of a low sun (orange / pink glow, blue only far from the sun) is not cancelled by the blue boost
			float sun_el = dot(sd, ro) / max(length(ro), 1.0);
			float day_k = smoothstep(-0.05, 0.45, sun_el);
			float tmean = exp((log(max(sky_tint.x, 1e-3)) + log(max(sky_tint.y, 1e-3)) + log(max(sky_tint.z, 1e-3))) / 3.0);
			L *= mix(vec3(1.0), mix(vec3(tmean), sky_tint, day_k), tw);
			float lum_l = dot(L, vec3(0.30, 0.59, 0.11));
			L = max(mix(vec3(lum_l), L, mix(1.0, sky_sat, tw * day_k)), vec3(0.0));
	}
}
