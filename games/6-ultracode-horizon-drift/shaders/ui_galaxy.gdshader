shader_type canvas_item;
// Volumetric spiral galaxy for the galaxy map + main menu backdrop (module M6).
// The density follows the same two-armed logarithmic spiral that Universe uses to place the 720 stars
// (angle = 2.35 * ln(r / 2800) + arm * PI), so the glowing arms line up with the actual stars.
// Coordinates are in light years; the camera is described by uniforms (see galaxy_map.gd).

uniform vec3 cam_pos = vec3(0.0, 30000.0, 90000.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform vec3 cam_back = vec3(0.0, 0.0, 1.0);
uniform float tan_half_fov = 0.4663;
uniform float aspect = 1.7778;
uniform float rot = 0.0;
uniform float brightness = 1.0;
uniform float dust_amount = 1.0;
uniform int steps = 40;
uniform float bg_stars = 1.0;

const float R_MAX = 52000.0;
const float H_MAX = 5200.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec3(11.7, 3.1, 7.3);
		a *= 0.5;
	}
	return s;
}

// returns emission (rgb) and extinction (a)
vec4 sample_galaxy(vec3 p) {
	float cs = cos(rot);
	float sn = sin(rot);
	vec3 q = vec3(cs * p.x - sn * p.z, p.y, sn * p.x + cs * p.z);
	float r = length(q.xz);
	float th = atan(q.z, q.x);
	float lr = log(max(r, 2000.0) / 2800.0);
	float ph = th - 2.35 * lr;
	float a = abs(mod(ph + 1.5707963, 3.1415926) - 1.5707963);
	float arm = exp(-pow(a / 0.40, 2.0));
	float rim = smoothstep(51000.0, 26000.0, r);
	float disc = exp(-r / 15500.0) * rim * smoothstep(900.0, 6500.0, r);
	float hgt = 720.0 * (1.25 - 0.65 * r / 50000.0);
	float vert = exp(-0.5 * pow(q.y / hgt, 2.0));
	float bulge = exp(-pow(r / 4200.0, 2.0) - pow(q.y / 1700.0, 2.0));
	float n = fbm(q * 0.00052);
	float n2 = vnoise(q * 0.0016 + 3.0);
	float clump = 0.30 + 1.35 * n;
	float dens = disc * (0.16 + 1.75 * arm * clump) * vert + bulge * 2.0;
	// colours: warm bulge, blue-white arms, pink star-forming knots on the outer arms
	vec3 warm = vec3(1.0, 0.70, 0.38);
	vec3 blue = vec3(0.50, 0.68, 1.0);
	vec3 pink = vec3(1.0, 0.38, 0.62);
	float kn = smoothstep(0.55, 0.85, n2) * arm * smoothstep(9000.0, 22000.0, r);
	vec3 col = mix(blue, warm, clamp(bulge * 1.4 + exp(-r / 7000.0) * 0.6, 0.0, 1.0));
	col = mix(col, pink, kn * 0.8);
	float dust_arm = exp(-pow((a - 0.46) / 0.16, 2.0));
	float dust = disc * vert * dust_arm * (0.25 + 1.1 * fbm(q * 0.0011 + 9.0)) * dust_amount;
	float ext = 0.00038 * dens + 0.00055 * dust;
	return vec4(col * dens * 0.0004 * brightness * (0.75 + 0.5 * n2), ext);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.y = -uv.y;
	vec3 rd = normalize(cam_right * (uv.x * aspect * tan_half_fov) + cam_up * (uv.y * tan_half_fov) - cam_back);
	vec3 ro = cam_pos;
	float t0 = 0.0;
	float t1 = 1.0e9;
	bool hit = true;
	if (abs(rd.y) < 1.0e-5) {
		if (abs(ro.y) > H_MAX) {
			hit = false;
		}
	} else {
		float ta = (-H_MAX - ro.y) / rd.y;
		float tb = (H_MAX - ro.y) / rd.y;
		t0 = max(t0, min(ta, tb));
		t1 = min(t1, max(ta, tb));
	}
	float a2 = dot(rd.xz, rd.xz);
	if (a2 > 1.0e-8) {
		float b2 = dot(ro.xz, rd.xz);
		float c2 = dot(ro.xz, ro.xz) - R_MAX * R_MAX;
		float dd = b2 * b2 - a2 * c2;
		if (dd > 0.0) {
			float s = sqrt(dd);
			t0 = max(t0, (-b2 - s) / a2);
			t1 = min(t1, (-b2 + s) / a2);
		} else {
			hit = false;
		}
	} else if (dot(ro.xz, ro.xz) > R_MAX * R_MAX) {
		hit = false;
	}
	vec3 acc = vec3(0.0);
	float trans = 1.0;
	if (hit && t1 > t0) {
		float len = t1 - t0;
		float dt = len / float(steps);
		float jit = hash12(FRAGCOORD.xy);
		for (int i = 0; i < 64; i++) {
			if (i >= steps || trans < 0.02) {
				break;
			}
			float t = t0 + (float(i) + jit) * dt;
			vec3 p = ro + rd * t;
			vec4 g = sample_galaxy(p);
			float att = exp(-g.a * dt);
			// emission integrated over the step (emission per unit length * step length), attenuated by what is in front
			acc += trans * g.rgb * dt * (1.0 + att) * 0.5;
			trans *= att;
		}
	}
	// deep space background: tiny stars
	vec3 bg = vec3(0.004, 0.007, 0.016);
	float star_h = hash12(floor(FRAGCOORD.xy * 0.5));
	float star = step(0.9965, star_h) * (0.25 + 0.75 * hash12(FRAGCOORD.xy + 7.0));
	bg += vec3(0.8, 0.9, 1.0) * star * 0.55 * bg_stars;
	vec3 col = acc * 1.15 + bg * trans;
	// filmic-ish tone map
	col = 1.0 - exp(-col * 1.35);
	col = pow(col, vec3(0.92));
	COLOR = vec4(col, 1.0);
}
