shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

#include "res://shaders/include/noise.gdshaderinc"

// Ray-marched Schwarzschild black hole (light bending a = -1.5 h^2 x / r^5, units of the Schwarzschild radius),
// glowing accretion disc with Doppler beaming and a photon ring. The lensed background is taken from the screen.
// Outside the march volume a weak-field analytic deflection fades to zero so there is no visible seam.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float rs = 3000.0;
uniform float bound = 26.0;      // march volume radius (in rs)
uniform float r_in = 2.7;
uniform float r_out = 10.5;
uniform float disc_gain = 2.2;
uniform float lens_gain = 1.0;

void vertex() {
	vec4 c = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0));
	float z = c.w > 0.05 ? c.z / c.w : 1.0;
	float w = c.w > 0.05 ? c.w : 1.0;
	POSITION = vec4(VERTEX.xy * w, z * w, w);
}

vec3 bg_stars(vec3 d) {
	vec3 p = d * 80.0;
	vec3 ip = floor(p);
	vec3 f = p - ip;
	uint h = hash_i(ivec3(ip), 17u);
	float r0 = float(h & 255u) / 255.0;
	vec3 c = vec3(0.3 + 0.4 * float((h >> 8u) & 255u) / 255.0, 0.3 + 0.4 * float((h >> 16u) & 255u) / 255.0, 0.3 + 0.4 * float((h >> 24u) & 255u) / 255.0);
	float s = smoothstep(0.2, 0.0, length(f - c));
	return vec3(1.0) * s * s * step(r0, 0.25) * 1.6;
}

vec3 sample_bg(vec3 d_world, mat4 vm, mat4 pm) {
	vec3 v = (vm * vec4(d_world, 0.0)).xyz;
	if (v.z >= -0.001) {
		return bg_stars(d_world);
	}
	vec4 cl = pm * vec4(v * 10.0, 1.0);
	vec2 ndc = cl.xy / cl.w;
	vec2 uv = ndc * 0.5 + 0.5;
	float edge = smoothstep(0.0, 0.04, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	vec3 s = textureLod(screen_tex, clamp(uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
	return mix(bg_stars(d_world), s, edge);
}

vec4 disc_sample(vec3 hit, float rr, vec3 dir, vec3 n, vec3 e1, vec3 e2) {
	float ang = atan(dot(hit, e2), dot(hit, e1));
	float omega = 2.4 * pow(rr, -1.5);
	float ph = ang - TIME * omega;
	vec3 q = vec3(cos(ph) * rr * 0.55, sin(ph) * rr * 0.55, rr * 1.7);
	float nz = fbm(q * 1.4, 501u, 4) * 0.5 + 0.5;
	float streak = 0.5 + 0.5 * sin(rr * 16.0 + nz * 7.0);
	float prof = pow(clamp(r_in / rr, 0.0, 1.0), 1.25);
	float ein = smoothstep(r_in - 0.05, r_in + 0.35, rr);
	float eout = 1.0 - smoothstep(r_out - 3.0, r_out, rr);
	vec3 hotc = vec3(1.0, 0.93, 0.8);
	vec3 midc = vec3(1.0, 0.55, 0.14);
	vec3 coldc = vec3(0.75, 0.1, 0.02);
	vec3 c = mix(coldc, midc, smoothstep(0.1, 0.6, prof));
	c = mix(c, hotc, smoothstep(0.55, 1.0, prof));
	vec3 tang = normalize(cross(n, hit));
	float vmag = clamp(sqrt(0.5 / max(rr - 0.9, 0.25)), 0.0, 0.75);
	float beam = clamp(1.0 + 1.9 * vmag * dot(tang, -dir), 0.2, 3.6);
	float em = (0.3 + 1.15 * nz) * (0.65 + 0.35 * streak) * prof * beam * disc_gain;
	float a = clamp(0.3 + nz * 0.9, 0.0, 1.0) * ein * eout;
	return vec4(c * em * ein * eout, a);
}

void fragment() {
	vec3 bh = MODEL_MATRIX[3].xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 ndc2 = SCREEN_UV * 2.0 - 1.0;
	vec4 vd4 = INV_PROJECTION_MATRIX * vec4(ndc2, 1.0, 1.0);
	vec3 vd = normalize(vd4.xyz / vd4.w);
	vec3 D = normalize((INV_VIEW_MATRIX * vec4(vd, 0.0)).xyz);
	vec3 O = (cam - bh) / rs;
	vec3 n = normalize(MODEL_MATRIX[1].xyz);
	vec3 e1 = normalize(cross(n, vec3(0.0, 0.0, 1.0)) + vec3(0.0001));
	vec3 e2 = cross(n, e1);

	float tc = -dot(O, D);
	vec3 P = O + D * tc;
	float b = length(P);

	vec3 col = vec3(0.0);
	vec3 Dout = D;
	float T = 1.0;
	float reach = bound * 4.5;

	if (b > bound) {
		// analytic weak-field bending of the ray (towards the hole), faded out with distance
		float fade = 1.0 - smoothstep(bound, reach, b);
		float delta = (1.0 / b) * (1.0 + tc / sqrt(tc * tc + b * b)) * fade * lens_gain;
		if (delta < 0.0003) { discard; }
		Dout = normalize(D - normalize(P) * delta);
		ALBEDO = sample_bg(Dout, VIEW_MATRIX, PROJECTION_MATRIX);
		ALPHA = 1.0;
	} else {
		vec3 pos = O;
		vec3 dir = D;
		float len0 = length(O);
		if (len0 > bound) {
			float t_in = tc - sqrt(max(bound * bound - b * b, 0.0));
			pos = O + D * t_in;
		}
		vec3 L = cross(pos, dir);
		float h2 = dot(L, L);
		float min_r = 1e9;
		bool captured = false;
		for (int i = 0; i < 150; i++) {
			float r = length(pos);
			min_r = min(min_r, r);
			if (r < 1.0) { captured = true; break; }
			if (r > bound * 1.002 && dot(pos, dir) > 0.0) { break; }
			float dt = clamp(0.05 + 0.11 * (r - 1.0), 0.04, 2.6);
			vec3 acc = -1.5 * h2 * pos / pow(r, 5.0);
			vec3 ndir = normalize(dir + acc * dt);
			vec3 npos = pos + ndir * dt;
			float y0 = dot(pos, n);
			float y1 = dot(npos, n);
			if (y0 * y1 < 0.0) {
				float f = y0 / (y0 - y1);
				vec3 hit = mix(pos, npos, f);
				float rr = length(hit);
				if (rr > r_in - 0.1 && rr < r_out) {
					vec4 ds = disc_sample(hit, rr, ndir, n, e1, e2);
					col += T * ds.rgb * ds.a;
					T *= (1.0 - ds.a);
				}
			}
			pos = npos;
			dir = ndir;
			if (T < 0.02) { break; }
		}
		if (captured) {
			T = 0.0;
		} else {
			float pr = exp(-pow((min_r - 1.52) / 0.07, 2.0));
			col += vec3(1.0, 0.85, 0.6) * pr * 0.9 * T;
			// remaining weak-field deflection outside the march volume keeps the seam invisible
			float rb = length(pos);
			Dout = dir;
		}
		vec3 bgc = captured ? vec3(0.0) : sample_bg(Dout, VIEW_MATRIX, PROJECTION_MATRIX);
		ALBEDO = col + bgc * T;
		ALPHA = 1.0;
	}
}
