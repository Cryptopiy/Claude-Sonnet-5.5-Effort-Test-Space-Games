// Shared noise / helper functions (pure math, usable in spatial, sky and canvas shaders)

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float f1 = hash13(i + vec3(1.0, 0.0, 1.0));
	float g = hash13(i + vec3(0.0, 1.0, 1.0));
	float h = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, f1, f.x), mix(g, h, f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(7.1, 3.7, 1.3);
		a *= 0.5;
	}
	return s;
}

float fbm3_lo(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(7.1, 3.7, 1.3);
		a *= 0.5;
	}
	return s;
}

float ridged3(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		float n = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
		s += a * n * n;
		p = p * 2.1 + vec3(3.3, 8.1, 5.7);
		a *= 0.5;
	}
	return s;
}

// Planck-ish black-body colour (rough): t in [0,1] cold->hot
vec3 heat_color(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c0 = vec3(0.6, 0.06, 0.01);
	vec3 c1 = vec3(1.0, 0.35, 0.04);
	vec3 c2 = vec3(1.0, 0.78, 0.35);
	vec3 c3 = vec3(0.85, 0.92, 1.0);
	if (t < 0.33) return mix(c0, c1, t / 0.33);
	if (t < 0.66) return mix(c1, c2, (t - 0.33) / 0.33);
	return mix(c2, c3, (t - 0.66) / 0.34);
}

// ray / sphere intersection, numerically stable for far-away spheres. oc = ray origin - sphere centre
bool ray_sphere(vec3 oc, vec3 dir, float r, out float t0, out float t1) {
	float tca = -dot(oc, dir);
	vec3 perp = oc + dir * tca;
	float d2 = dot(perp, perp);
	float r2 = r * r;
	t0 = 0.0;
	t1 = 0.0;
	if (d2 > r2) return false;
	float thc = sqrt(r2 - d2);
	t0 = tca - thc;
	t1 = tca + thc;
	return true;
}
