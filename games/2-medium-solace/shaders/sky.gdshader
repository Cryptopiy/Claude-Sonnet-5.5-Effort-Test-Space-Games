shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 gal_n = vec3(0.3, 0.9, 0.2);
uniform vec3 sun_col : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 zenith : source_color = vec3(0.15, 0.4, 0.8);
uniform vec3 horizon : source_color = vec3(0.6, 0.78, 0.95);
uniform vec3 tint_a : source_color = vec3(0.45, 0.6, 1.0);
uniform vec3 tint_b : source_color = vec3(1.0, 0.7, 0.45);
uniform float atmo = 0.0;
uniform float star_vis = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}
vec3 starlayer(vec3 d, float scale, float thresh, float size) {
	vec3 q = d * scale;
	vec3 id = floor(q);
	vec3 f = fract(q) - 0.5;
	float h = hash13(id);
	vec3 off = vec3(hash13(id + 3.1), hash13(id + 7.7), hash13(id + 1.3)) - 0.5;
	float dd = length(f - off * 0.6);
	float s = step(thresh, h) * smoothstep(size, 0.0, dd);
	vec3 col = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.65), hash13(id + 11.0));
	return col * s * (0.5 + 1.5 * hash13(id + 5.0));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sp = starlayer(d, 60.0, 0.97, 0.2) * 1.5 + starlayer(d, 150.0, 0.965, 0.2) + starlayer(d, 320.0, 0.95, 0.22) * 0.8;
	float g = dot(d, normalize(gal_n));
	float band = exp(-g * g * 26.0);
	float cloud = fbm(d * 5.0 + 3.0);
	float dust = fbm(d * 9.0 + 20.0);
	vec3 gc = normalize(cross(normalize(gal_n), vec3(0.0, 1.0, 0.1)));
	float core = exp(-pow(length(d - gc) * 1.6, 2.0));
	vec3 gal = mix(tint_a, tint_b, smoothstep(0.35, 0.75, cloud)) * band * (0.15 + 0.9 * cloud * cloud) * (1.0 - 0.7 * smoothstep(0.45, 0.7, dust) * band);
	gal += tint_b * core * 0.35 * band;
	sp += gal * 0.9 + starlayer(d, 600.0, 0.88, 0.3) * band * 1.2;

	float sun_up = dot(normalize(up_dir), normalize(sun_dir));
	float day = smoothstep(-0.18, 0.22, sun_up);
	float elev = dot(d, normalize(up_dir));
	float twi = (1.0 - smoothstep(0.0, 0.35, abs(sun_up + 0.02))) * 0.9;
	vec3 hz = mix(horizon * 0.08, horizon, day);
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	hz += vec3(1.0, 0.45, 0.2) * twi * pow(sd, 3.0) * 1.1;
	vec3 sk = mix(hz, zenith * mix(0.04, 1.0, day), smoothstep(0.0, 0.55, elev));
	sk = mix(sk, hz * 0.5, smoothstep(0.0, -0.4, elev));
	vec3 sunc = sun_col * (pow(sd, 700.0) * 18.0 + pow(sd, 40.0) * 0.5 * day + pow(sd, 6.0) * 0.12 * day);
	float vis = clamp(atmo, 0.0, 1.0);
	float starfade = 1.0 - vis * day;
	vec3 col = sp * starfade * star_vis + sk * vis + sunc * mix(1.0, 0.6 + 0.4 * day, vis);
	COLOR = col;
}
