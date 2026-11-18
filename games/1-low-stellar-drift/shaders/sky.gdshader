shader_type sky;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform float atmo = 0.0;
uniform vec3 horizon_col = vec3(0.6, 0.75, 0.95);
uniform vec3 zenith_col = vec3(0.1, 0.3, 0.8);
uniform vec3 neb_col = vec3(0.5, 0.2, 0.8);
uniform vec3 galaxy_axis = vec3(0.3, 0.9, 0.3);
uniform float seed = 1.0;

float h31(vec3 p){ p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 p){
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y);
	float b = mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm(vec3 p){ float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++){ s += a * vnoise(p); p *= 2.03; a *= 0.5; } return s; }
float stars(vec3 d, float scale, float thr){
	vec3 p = d * scale; vec3 i = floor(p); vec3 f = fract(p);
	float h = h31(i + seed);
	if (h < thr) return 0.0;
	vec3 o = vec3(h31(i + 1.3), h31(i + 2.7), h31(i + 4.1)) * 0.6 + 0.2;
	float r = length(f - o);
	return smoothstep(0.10, 0.0, r) * (h - thr) / (1.0 - thr);
}
void sky() {
	vec3 d = EYEDIR;
	float lat = dot(d, normalize(galaxy_axis));
	float band = exp(-lat * lat * 14.0);
	float dust = fbm(d * 4.0 + seed);
	float lanes = smoothstep(0.35, 0.7, fbm(d * 9.0 + 7.0));
	vec3 col = vec3(0.004, 0.005, 0.012);
	vec3 core = vec3(1.0, 0.85, 0.6);
	float coreb = pow(max(dot(d, normalize(cross(galaxy_axis, vec3(0.0, 1.0, 0.3)))), 0.0), 3.0);
	col += mix(vec3(0.5, 0.55, 0.8), core, coreb) * band * (0.10 + 0.28 * dust) * (1.0 - 0.7 * lanes);
	col += neb_col * pow(fbm(d * 2.2 + seed * 3.0), 3.0) * 0.5 * (0.3 + band);
	float st = stars(d, 60.0, 0.86) + stars(d, 130.0, 0.9) * 0.8 + stars(d, 28.0, 0.9) * 1.4;
	st += band * stars(d, 220.0, 0.8) * 0.7;
	col += vec3(1.0, 0.95, 0.9) * st * 1.6;

	float sunlit = smoothstep(-0.18, 0.3, dot(up_dir, sun_dir));
	float elev = dot(d, up_dir);
	vec3 day = mix(horizon_col, zenith_col, smoothstep(-0.05, 0.75, elev));
	float sd = max(dot(d, sun_dir), 0.0);
	vec3 sunset = vec3(1.0, 0.45, 0.2) * pow(sd, 6.0) * (1.0 - abs(dot(up_dir, sun_dir))) * 1.2;
	vec3 skycol = day * sunlit + sunset * smoothstep(-0.3, 0.2, dot(up_dir, sun_dir)) * (1.0 - sunlit * 0.6);
	skycol += horizon_col * 0.02;
	float below = smoothstep(0.0, -0.3, elev);
	skycol = mix(skycol, horizon_col * 0.25 * sunlit + 0.01, below);
	float starvis = 1.0 - clamp(sunlit * 1.1, 0.0, 1.0);
	col = col * mix(1.0, starvis, atmo);
	COLOR = mix(col, skycol + col * 0.3, atmo * 0.97);
}
