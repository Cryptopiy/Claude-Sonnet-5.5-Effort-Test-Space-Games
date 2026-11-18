shader_type sky;
#include "res://shaders/include/noise.gdshaderinc"

// Galaxy backdrop (stars, spiral band, nebula) + a per-planet atmosphere blended in by altitude.
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform float atm = 0.0;
uniform vec3 zenith : source_color = vec3(0.1, 0.3, 0.8);
uniform vec3 horizon : source_color = vec3(0.6, 0.8, 0.95);
uniform vec3 twilight : source_color = vec3(1.0, 0.5, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 galaxy_n = vec3(0.2, 0.9, 0.3);
uniform vec3 galaxy_c = vec3(0.7, 0.0, 0.7);
uniform vec3 neb_a : source_color = vec3(0.3, 0.1, 0.5);
uniform vec3 neb_b : source_color = vec3(0.1, 0.3, 0.6);
uniform float star_gain = 1.0;
uniform float warp = 0.0;

vec3 star_layer(vec3 dir, float scale, uint seed, float prob, float size) {
	vec3 p = dir * scale;
	vec3 ip = floor(p);
	vec3 f = p - ip;
	uint h = hash_i(ivec3(ip), seed);
	float r0 = float(h & 255u) / 255.0;
	if (r0 > prob) { return vec3(0.0); }
	vec3 c = vec3(0.25 + 0.5 * float((h >> 8u) & 255u) / 255.0, 0.25 + 0.5 * float((h >> 16u) & 255u) / 255.0, 0.25 + 0.5 * float((h >> 24u) & 255u) / 255.0);
	float d = length(f - c);
	float s = smoothstep(size, 0.0, d);
	float mag = pow(1.0 - r0 / max(prob, 0.0001), 2.5);
	uint h2 = hash_i(ivec3(ip), seed + 9u);
	float t = float(h2 & 255u) / 255.0;
	vec3 tint = mix(vec3(1.0, 0.65, 0.45), vec3(0.65, 0.8, 1.0), t);
	tint = mix(tint, vec3(1.0), 0.45);
	return tint * s * s * (0.35 + mag * 2.2);
}

vec3 space_color(vec3 dir) {
	vec3 col = vec3(0.0);
	col += star_layer(dir, 40.0, 11u, 0.22, 0.2);
	col += star_layer(dir, 90.0, 12u, 0.3, 0.22) * 0.8;
	col += star_layer(dir, 210.0, 13u, 0.4, 0.25) * 0.7;
	col += star_layer(dir, 420.0, 14u, 0.5, 0.28) * 0.6;
	col *= star_gain;
	// galactic band
	float g = dot(dir, galaxy_n);
	float band = exp(-g * g * 40.0);
	float cen = pow(max(dot(dir, galaxy_c), 0.0), 6.0);
	float n1 = fbm(dir * 3.0 + vec3(2.0), 601u, 5) * 0.5 + 0.5;
	float n2 = fbm(dir * 9.0 + vec3(5.0), 607u, 4) * 0.5 + 0.5;
	float dust = smoothstep(0.52, 0.72, fbm(dir * 6.0 + vec3(9.0), 613u, 4) * 0.5 + 0.5);
	vec3 gal = mix(vec3(0.55, 0.62, 0.9), vec3(1.0, 0.85, 0.6), cen) * (band * (0.25 + 0.5 * n1) + cen * 0.7 * band);
	gal *= 1.0 - dust * 0.75 * band;
	col += gal * 0.5;
	// faint dense star glow in the band
	col += star_layer(dir, 700.0, 15u, 0.55 * clamp(band + 0.1, 0.0, 1.0), 0.3) * 0.5;
	// nebula tint
	float nb = smoothstep(0.55, 0.85, fbm(dir * 2.2 + vec3(13.0), 619u, 4) * 0.5 + 0.5);
	col += mix(neb_a, neb_b, n2) * nb * 0.09 * (0.4 + band);
	return col;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 space = space_color(dir);
	float h = dot(dir, up_dir);
	float sun_h = dot(sun_dir, up_dir);
	float day = smoothstep(-0.16, 0.2, sun_h);
	vec3 col = space;
	if (atm > 0.002) {
		float hh = clamp(h, 0.0, 1.0);
		vec3 sky_day = mix(horizon, zenith, pow(hh, 0.42));
		float sd = max(dot(dir, sun_dir), 0.0);
		float tw = exp(-abs(sun_h) * 4.0);
		vec3 a = sky_day * day;
		a += twilight * tw * (0.25 + pow(sd, 3.0) * 1.1) * exp(-max(h, 0.0) * 3.2) * (1.0 - 0.6 * (1.0 - day) * 0.0);
		a += zenith * 0.02 * (1.0 - day);
		a += sun_col * (pow(sd, 90.0) * 1.4 + pow(sd, 10.0) * 0.14 * day + pow(sd, 3.0) * 0.06 * day);
		float below = smoothstep(0.0, -0.3, h);
		a = mix(a, horizon * 0.22 * day + twilight * 0.04 * tw, below);
		float vis = clamp(1.0 - atm * (day * 1.25 + 0.12), 0.0, 1.0);
		col = space * vis + a * atm;
	}
	if (warp > 0.0) {
		col = mix(col, col * 1.6 + vec3(0.1, 0.2, 0.4) * warp, warp);
	}
	COLOR = col;
}
