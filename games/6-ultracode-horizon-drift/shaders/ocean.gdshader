shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix, fog_disabled;
// Liquid surface of a planet (module M2): water / lava / acid. A full-screen quad that ray-traces the sea SPHERE analytically (exact at any distance, no
// polygon sagitta, shoreline meets the terrain precisely), writes the real surface depth and shades:
//   * 16 travelling plane waves with a decaying slope spectrum; every wave is faded out by the PIXEL FOOTPRINT (wavelength vs distance / grazing angle), and the
//     variance that was filtered away widens the sun glint instead => no moire / stripe aliasing at any distance,
//   * fresnel sky reflection, GGX sun glint, refracted + per-channel absorbed sea bed (screen texture), subsurface tint on crests, shore foam from the exact
//     vertical depth, sparse whitecaps,
//   * underwater: absorption fog, Snell's window with the sky / sun above, total internal reflection outside it.
// Lava = emissive crust with glowing flows, acid = glowing green liquid.

global uniform vec3 sun_dir;
global uniform vec3 sun_color;
global uniform float sun_energy;
global uniform float night_amount;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float sea_r = 9000.0;
uniform int kind = 0;                     // 0 water, 1 lava, 2 acid
uniform vec3 shallow_col = vec3(0.1, 0.62, 0.66);
uniform vec3 deep_col = vec3(0.01, 0.075, 0.19);
uniform vec3 foam_col = vec3(0.95, 0.98, 1.0);
uniform vec3 absorb = vec3(0.42, 0.075, 0.045);
uniform float clarity = 0.22;
uniform float wave_amp = 1.0;
uniform float glow_amt = 0.0;
uniform float spec_amt = 1.0;
uniform vec3 sky_zenith = vec3(0.2, 0.4, 0.9);
uniform vec3 sky_horizon = vec3(0.65, 0.8, 1.0);
uniform float sky_gain = 1.0;             // 0 at night .. 1 in daylight
uniform vec3 amb_color = vec3(0.3, 0.35, 0.45);
uniform float seed = 1.0;

const float PI_O = 3.14159265;
const float WAVE_SLOPE = 0.062;           // slope amplitude of a 20 m wave (rad) at wave_amp = 1

const vec3 WDIR[16] = vec3[16](
	vec3(-0.8234, 0.4545, 0.3399), vec3(0.6667, -0.7226, 0.1827), vec3(0.9900, 0.0469, 0.1332), vec3(-0.3822, -0.1417, 0.9132),
	vec3(0.6495, -0.5789, -0.4929), vec3(-0.7427, -0.3428, -0.5752), vec3(-0.8128, 0.3428, -0.4710), vec3(-0.1248, 0.2395, -0.9628),
	vec3(0.0043, -0.4545, -0.8907), vec3(0.4966, -0.0469, 0.8667), vec3(0.4206, 0.7226, 0.5486), vec3(0.4436, 0.8962, 0.0000),
	vec3(0.1672, -0.8962, 0.4108), vec3(0.7017, 0.1417, -0.6983), vec3(-0.2117, 0.5789, 0.7874), vec3(-0.9388, -0.2395, 0.2475));
const float WJIT[16] = float[16](0.984, 0.897, 0.902, 0.982, 1.078, 0.910, 0.934, 1.031, 1.107, 1.019, 0.975, 1.114, 0.891, 1.086, 0.950, 0.915);
const float WPH[16] = float[16](0.740, 1.938, 5.128, 1.136, 3.654, 4.014, 2.340, 3.441, 0.395, 0.374, 1.294, 4.275, 2.687, 1.974, 3.679, 2.847);

uint pcg_u(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash13(vec3 p3) {
	ivec3 ip = ivec3(floor(p3));
	uint h = pcg_u(uint(ip.x) + pcg_u(uint(ip.y) + pcg_u(uint(ip.z))));
	return float(h) * (1.0 / 4294967295.0);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.3, 7.1, 2.9);
		a *= 0.5;
	}
	return s;
}

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

// Sum of travelling plane waves evaluated at the sphere point P (planet-relative, world axes). N0 = sphere normal there.
//   g  : surface gradient (tangent vector), the shaded normal is normalize(N0 - g)
//   h  : wave height (m), only used for shading tints / whitecaps
//   rv : slope variance that was removed by the footprint filter (feeds the glint roughness)
// `foot` is the size of a pixel on the surface (m): waves shorter than ~2.5 pixels are gone, those shorter than ~10 pixels are attenuated.
void waves(vec3 P, vec3 N0, float t, float amp, float foot, out vec3 g, out float h, out float rv) {
	g = vec3(0.0);
	h = 0.0;
	rv = 0.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float wl = 60.0 * exp2(-0.4346 * fi) * WJIT[i];              // 60 m ... 0.6 m (ratio 0.74)
		vec3 dv = WDIR[i];
		vec3 dt = dv - N0 * dot(dv, N0);                              // tangent part: effective wavelength on the surface is wl / |dt|
		float dl = max(length(dt), 0.12);
		float kk = 6.2831853 / wl;
		float sl = amp * WAVE_SLOPE * pow(wl * 0.05, 0.16);          // slope amplitude of this wave
		float fade = 1.0 - smoothstep(0.10, 0.40, foot * dl / wl);
		float ph = kk * dot(P, dv) - sqrt(9.8 * kk) * 0.55 * t + WPH[i];
		g += dt * (sl * fade * cos(ph));
		h += (sl / kk) * fade * sin(ph);
		rv += 0.5 * sl * sl * dl * dl * (1.0 - fade * fade);
	}
}

vec3 sky_refl(vec3 dir, vec3 N0, vec3 sun, float day) {
	float el = clamp(dot(dir, N0), 0.0, 1.0);
	vec3 c = mix(sky_horizon, sky_zenith, pow(el, 0.5)) * (0.06 + 0.94 * day);
	float sd = max(dot(dir, sun), 0.0);
	c += sun_color * clamp(sun_energy, 0.0, 4.0) * (0.035 * pow(sd, 10.0));
	return c;
}

void fragment() {
	vec3 center = NODE_POSITION_WORLD;
	vec3 ro = CAMERA_POSITION_WORLD - center;
	vec4 vn = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 vdir = normalize(vn.xyz / vn.w);
	vec3 rd = normalize((INV_VIEW_MATRIX * vec4(vdir, 0.0)).xyz);
	vec2 ts = ray_sphere(ro, rd, sea_r);
	if (ts.y < 0.0) {
		discard;
	}
	float rr = length(ro);
	bool inside = rr < sea_r;
	if (!inside && ts.x < 0.0) {
		discard;
	}
	float dsc = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	float scene_t = 1e9;
	if (dsc > 1e-7) {
		vec4 vv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dsc, 1.0);
		scene_t = length(vv.xyz / vv.w);
	}
	vec3 sun = normalize(sun_dir);
	float day = clamp(sky_gain, 0.0, 1.0);
	float px_ang = 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);       // angle of one pixel (rad)
	vec3 sun_c = sun_color * clamp(sun_energy, 0.0, 4.0);

	if (inside) {
		// ======================================== UNDERWATER ========================================================================================
		vec3 up = ro / rr;
		float depth_cam = max(sea_r - rr, 0.0);
		float t_surf = ts.y;                                                     // where this ray leaves the sea sphere (the surface seen from below)
		bool sees_surface = t_surf < scene_t && t_surf < 2500.0;
		float dens = 0.020 + 0.09 * clarity;
		vec3 vol = mix(deep_col, shallow_col, exp(-depth_cam * 0.07)) * (0.07 + 0.93 * day) * (0.55 + 0.45 * exp(-depth_cam * 0.03));
		vec3 col = vol;
		float dep_out = 1.0;
		float up_k = clamp(dot(rd, up) * 0.5 + 0.5, 0.0, 1.0);
		if (kind == 1) {
			col = shallow_col * 1.5;
			float fg = 1.0 - exp(-min(scene_t, t_surf) * 0.5);
			ALBEDO = col;
			ALPHA = clamp(fg, 0.0, 1.0);
			DEPTH = 1.0;
		} else {
			if (!sees_surface) {
				if (scene_t < 1e8) {
					float te = min(scene_t, 2500.0);
					vec3 sc = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
					vec3 thr = sc * exp(-absorb * te);
					col = mix(thr, vol * (0.85 + 0.2 * up_k), 1.0 - exp(-te * dens));
					dep_out = dsc;
				}
			} else {
				vec3 hit = ro + rd * t_surf;
				vec3 Nh = normalize(hit);
				float foot = t_surf * px_ang / max(abs(dot(rd, up)), 0.1);
				vec3 g;
				float hh;
				float rv;
				waves(hit, Nh, TIME, wave_amp * 0.8, foot, g, hh, rv);
				vec3 nrm = normalize(Nh - g);
				vec3 refr = refract(rd, -nrm, 1.333);
				float win = length(refr) > 0.5 ? 1.0 : 0.0;
				win *= smoothstep(0.62, 0.78, dot(rd, Nh));
				vec3 rn = normalize(refr + vec3(1e-4));
				vec3 sky = sky_refl(rn, Nh, sun, day) * 1.15;
				float sd = max(dot(rn, sun), 0.0);
				sky += sun_c * (smoothstep(0.99985, 0.99998, sd) * 6.0 + pow(sd, 120.0) * 0.5);
				vec3 thr = sky * exp(-absorb * t_surf);
				vec3 win_col = mix(thr, vol, 1.0 - exp(-t_surf * dens));
				float rip = 0.85 + 0.3 * vnoise(hit * 0.35 + vec3(TIME * 0.2));
				vec3 tir_col = vol * (0.80 + 0.25 * max(dot(rd, up), 0.0)) * rip + shallow_col * 0.04 * day;
				col = mix(tir_col, win_col, win);
			}
			ALBEDO = col;
			ALPHA = 1.0;
			DEPTH = dep_out;
		}
	} else {
		// ======================================== ABOVE THE SURFACE =====================================================================================
		float thit = ts.x;
		if (scene_t < thit) {
			discard;                                  // terrain / props in front of the water
		}
		vec3 P = ro + rd * thit;
		vec3 N0 = normalize(P);
		vec3 V = -rd;
		float ndv0 = max(dot(N0, V), 0.0);
		float foot = thit * px_ang / max(ndv0, 0.08);
		vec3 g;
		float hgt;
		float rv;
		waves(P, N0, TIME, wave_amp, foot, g, hgt, rv);
		if (kind == 1) {
			g *= 0.15;
		}
		vec3 N = normalize(N0 - g);
		float ndv = max(dot(N, V), 0.0);
		float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
		float t_exit = min(scene_t, ts.y);
		float water_len = clamp(t_exit - thit, 0.0, 800.0);
		float vd = 1e3;                               // exact vertical depth of the sea bed behind this pixel (m)
		if (scene_t < 1e8 && scene_t < ts.y) {
			vd = max(sea_r - length(ro + rd * scene_t), 0.0);
		}
		float ndl0 = max(dot(N0, sun), 0.0);
		vec3 light = amb_color + sun_c * ndl0 * 0.5;
		vec3 col;
		float alpha = 1.0;
		if (kind == 1) {
			// lava: dark crust with glowing cracks, flowing
			vec3 q = P * 0.025;
			float flow = fbm(q + vec3(TIME * 0.02, 0.0, TIME * 0.015) + fbm(q * 2.0 - TIME * 0.01) * 0.8);
			float cracks = smoothstep(0.42, 0.55, flow);
			float hot = 1.0 - cracks;
			vec3 crust = vec3(0.045, 0.018, 0.012) * (0.4 + 0.6 * light);
			vec3 magma = mix(deep_col * 2.4, shallow_col * 2.4, hot) * (1.0 + 0.5 * vnoise(P * 0.2 + TIME * 0.1));
			col = mix(crust, magma, smoothstep(0.0, 0.7, hot * 1.2 + 0.15));
			col += foam_col * pow(hot, 6.0) * 0.7;
		} else {
			// ---- what is seen through the water: refracted + absorbed sea bed ----------------------------------------------------------------------
			vec3 nv = (VIEW_MATRIX * vec4(N, 0.0)).xyz;
			vec3 n0v = (VIEW_MATRIX * vec4(N0, 0.0)).xyz;
			vec2 off = (nv.xy - n0v.xy) * 0.05 * clamp(water_len * 0.25, 0.0, 1.0) * clamp(80.0 / thit, 0.0, 1.0);
			vec2 uv_r = clamp(SCREEN_UV + off, vec2(0.002), vec2(0.998));
			float dr = textureLod(depth_tex, uv_r, 0.0).r;
			if (dr > 1e-7) {
				vec4 vr = INV_PROJECTION_MATRIX * vec4(uv_r * 2.0 - 1.0, dr, 1.0);
				if (length(vr.xyz / vr.w) < thit) {
					uv_r = SCREEN_UV;                 // an occluder (grass, rock) is in front of the water there: do not smear it
				}
			}
			vec3 bed = textureLod(screen_tex, uv_r, 0.0).rgb;
			vec3 through = bed * exp(-absorb * water_len);
			float sc_k = 1.0 - exp(-water_len * clarity * 0.35);
			vec3 body = mix(shallow_col, deep_col, 1.0 - exp(-water_len * 0.07)) * (0.25 + 0.75 * clamp(light, vec3(0.0), vec3(2.0)));
			// subsurface glow on the sun side of wave crests
			float sss = smoothstep(-0.3, 1.4, hgt) * (1.0 - exp(-water_len * 0.25));
			body += shallow_col * sun_c * (0.10 * sss * (0.4 + 0.6 * pow(max(dot(V, -sun) * 0.5 + 0.5, 0.0), 3.0)));
			if (kind == 2) {
				body += shallow_col * glow_amt * (0.6 + 0.4 * vnoise(P * 0.3 + TIME * 0.05));
			}
			vec3 refracted = mix(through, body, sc_k);
			// ---- reflection: sky + sun glint (GGX, roughness grows with the filtered wave variance) --------------------------------------------------
			vec3 rdir = reflect(rd, N);
			vec3 sky = sky_refl(rdir, N0, sun, day);
			vec3 Hh = normalize(V + sun);
			float ndh = max(dot(N, Hh), 0.0);
			float a2 = max(0.0016 + rv * 0.6, 0.0009);
			float dd = ndh * ndh * (a2 - 1.0) + 1.0;
			float D = a2 / (PI_O * dd * dd);
			float vh = max(dot(V, Hh), 0.0);
			float F = 0.02 + 0.98 * pow(1.0 - vh, 5.0);
			float horizon_ok = smoothstep(-0.01, 0.06, dot(N0, sun)) * smoothstep(0.0, 0.05, dot(rdir, N0));
			vec3 spec = sun_c * min(D * F * 0.25 / max(ndv, 0.06), 40.0) * spec_amt * horizon_ok;
			// ---- foam: shore (exact depth) + sparse whitecaps ------------------------------------------------------------------------------------------
			float foam_det = 1.0 - smoothstep(0.8, 4.0, foot);
			float foam_w = 1.0 + 0.9 * wave_amp + foot * 0.6;
			float fn = vnoise(P * 0.5 + vec3(TIME * 0.25, 0.0, -TIME * 0.15)) * 0.6 + vnoise(P * 1.8 - TIME * 0.45) * 0.4;
			fn = mix(0.55, fn, foam_det);                  // far away the foam texture is averaged out (no speckle)
			float wash = mix(0.6, 0.5 + 0.5 * sin(vd * 4.5 - TIME * 0.9 + fn * 5.0), foam_det);
			float line = 1.0 - smoothstep(0.0, 0.22 + foot * 0.25, vd);
			float shore = (1.0 - smoothstep(0.0, foam_w, vd)) * smoothstep(0.28, 0.78, fn * 0.65 + wash * 0.5) * 0.85;
			float caps = smoothstep(0.0, 0.5, hgt - 1.3 + (fn - 0.5) * 1.1) * 0.55 * foam_det * smoothstep(0.7, 1.4, wave_amp + 0.3);
			float foam = clamp(max(line * 0.9, shore) + caps, 0.0, 1.0);
			vec3 foam_c = foam_col * (0.35 + 0.65 * clamp(light.r * 0.5 + 0.5, 0.0, 1.5));
			col = refracted * (1.0 - fres) + sky * fres + spec;
			col = mix(col, foam_c, foam);
			alpha = smoothstep(0.0, 0.25, water_len);
			alpha = max(alpha, foam * 0.9);
			if (kind == 2) {
				alpha = max(alpha, 0.9);
			}
		}
		ALBEDO = col;
		ALPHA = clamp(alpha, 0.0, 1.0);
		vec3 vpos = vdir * thit;
		vec4 clip = PROJECTION_MATRIX * vec4(vpos, 1.0);
		DEPTH = clip.z / clip.w;
	}
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
