// GPU twin of scripts/core/tnoise.gd  (keep both in sync!)
// Integer-hash gradient noise + terrain height function.
// The including shader must declare the t_* uniforms below BEFORE including this file.

uint tn_h(uint x) {
	x = ((x >> 16u) ^ x) * 73244475u;
	x = ((x >> 16u) ^ x) * 73244475u;
	return (x >> 16u) ^ x;
}

float tn_g(uint h, float dx, float dy, float dz) {
	uint k = h & 15u;
	float u = (k < 8u) ? dx : dy;
	float v = (k < 4u) ? dy : (((k == 12u) || (k == 14u)) ? dx : dz);
	return (((k & 1u) == 0u) ? u : -u) + (((k & 2u) == 0u) ? v : -v);
}

float tn_perlin(vec3 p, int seed) {
	vec3 f = floor(p);
	vec3 w = p - f;
	uint ix = uint(int(f.x));
	uint iy = uint(int(f.y));
	uint iz = uint(int(f.z));
	uint s = uint(seed) * 668265261u;
	uint hx0 = tn_h(ix + s);
	uint hx1 = tn_h(ix + 1u + s);
	uint y1 = iy + 1u;
	uint z1 = iz + 1u;
	uint h00 = tn_h(hx0 + iy);
	uint h10 = tn_h(hx1 + iy);
	uint h01 = tn_h(hx0 + y1);
	uint h11 = tn_h(hx1 + y1);
	float n000 = tn_g(tn_h(h00 + iz), w.x, w.y, w.z);
	float n100 = tn_g(tn_h(h10 + iz), w.x - 1.0, w.y, w.z);
	float n010 = tn_g(tn_h(h01 + iz), w.x, w.y - 1.0, w.z);
	float n110 = tn_g(tn_h(h11 + iz), w.x - 1.0, w.y - 1.0, w.z);
	float n001 = tn_g(tn_h(h00 + z1), w.x, w.y, w.z - 1.0);
	float n101 = tn_g(tn_h(h10 + z1), w.x - 1.0, w.y, w.z - 1.0);
	float n011 = tn_g(tn_h(h01 + z1), w.x, w.y - 1.0, w.z - 1.0);
	float n111 = tn_g(tn_h(h11 + z1), w.x - 1.0, w.y - 1.0, w.z - 1.0);
	vec3 u = w * w * w * (w * (w * 6.0 - 15.0) + 10.0);
	float a = mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y);
	float b = mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y);
	return mix(a, b, u.z);
}

float tn_fbm(vec3 p, int oct, float gain, int seed) {
	float a = 1.0;
	float s = 0.0;
	float n = 0.0;
	for (int i = 0; i < oct; i++) {
		s += a * tn_perlin(p, seed);
		n += a;
		a *= gain;
		p = p * 2.03 + vec3(17.1, 31.7, 9.3);
	}
	return (n == 0.0) ? 0.0 : s / n;
}

float tn_ridged(vec3 p, int oct, int seed) {
	float a = 0.5;
	float s = 0.0;
	float n = 0.0;
	for (int i = 0; i < oct; i++) {
		float v = 1.0 - clamp(abs(tn_perlin(p, seed)) * 1.6, 0.0, 1.0);
		s += a * v * v;
		n += a;
		a *= 0.5;
		p = p * 2.07 + vec3(11.3, 5.9, 23.1);
	}
	return (n == 0.0) ? 0.0 : s / n;
}

float tn_craters(vec3 p, int seed) {
	vec3 b = floor(p - 0.5);
	uint bx = uint(int(b.x));
	uint by = uint(int(b.y));
	uint bz = uint(int(b.z));
	uint s = uint(seed) * 668265261u;
	float h = 0.0;
	for (int k = 0; k < 8; k++) {
		uint cx = bx + uint(k & 1);
		uint cy = by + uint((k >> 1) & 1);
		uint cz = bz + uint((k >> 2) & 1);
		uint hh = tn_h(tn_h(tn_h(cx + s) + cy) + cz);
		vec3 j = vec3(float(hh & 255u), float((hh >> 8u) & 255u), float((hh >> 16u) & 255u)) * (0.6 / 255.0) + 0.2;
		float rad = 0.12 + 0.18 * float((hh >> 24u) & 255u) / 255.0;
		vec3 ctr = vec3(float(int(b.x) + (k & 1)), float(int(b.y) + ((k >> 1) & 1)), float(int(b.z) + ((k >> 2) & 1))) + j;
		float d = length(p - ctr) / rad;
		if (d < 1.6) {
			float bowl = 0.0;
			if (d < 1.0) {
				bowl = -(1.0 - d * d);
			}
			float t = (d - 1.0) / 0.22;
			float rim = exp(-t * t) * 0.30;
			h += (bowl * 0.9 + rim) * (rad / 0.3);
		}
	}
	return h;
}

float tn_smooth(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

vec3 tn_cube_to_sphere(vec3 c) {
	vec3 c2 = c * c;
	return vec3(
		c.x * sqrt(1.0 - 0.5 * (c2.y + c2.z) + c2.y * c2.z / 3.0),
		c.y * sqrt(1.0 - 0.5 * (c2.z + c2.x) + c2.z * c2.x / 3.0),
		c.z * sqrt(1.0 - 0.5 * (c2.x + c2.y) + c2.x * c2.y / 3.0));
}

