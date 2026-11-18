shader_type sky;
// Procedural galaxy backdrop: stars, Milky Way band, nebulae. Orientation of the band depends on the
// system's position in the galaxy. In the radiance (cubemap) pass an analytic daylight sky is added
// so metal/water reflections and ambient light pick up the atmosphere colour.

#include "res://shaders/inc/tnoise.gdshaderinc"

uniform vec3 gal_normal = vec3(0.2, 0.9, 0.3);
uniform vec3 gal_center = vec3(0.5, 0.1, 0.8);
uniform float gal_bright = 1.0;
uniform vec3 neb_col1 : source_color = vec3(0.35, 0.1, 0.6);
uniform vec3 neb_col2 : source_color = vec3(0.05, 0.3, 0.5);
uniform float neb_amt = 0.5;
uniform float star_amt = 1.0;
uniform float day_dim = 0.0;
uniform int sky_seed = 1;

uniform vec3 up_vec = vec3(0.0, 1.0, 0.0);
uniform vec3 refl_zenith : source_color = vec3(0.2, 0.4, 0.8);
uniform vec3 refl_horizon : source_color = vec3(0.7, 0.8, 0.95);
uniform float refl_amt = 0.0;
uniform vec3 refl_sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 refl_sun_col : source_color = vec3(1.0, 0.9, 0.8);

uint sk_h(uint x) {
	return tn_h(x * 2654435u + 12345u);
}

vec3 star_layer(vec3 dir, float scale, float prob, float size, float bright, int seed) {
	vec3 p = dir * scale;
	vec3 c = floor(p);
	uint cx = uint(int(c.x));
	uint cy = uint(int(c.y));
	uint cz = uint(int(c.z));
	uint hh = tn_h(tn_h(tn_h(cx + uint(seed) * 7919u) + cy) + cz);
	float rnd = float(hh & 1023u) / 1023.0;
	if (rnd > prob) {
		return vec3(0.0);
	}
	uint h2 = tn_h(hh + 17u);
	vec3 jit = vec3(float(h2 & 255u), float((h2 >> 8u) & 255u), float((h2 >> 16u) & 255u)) / 255.0;
	vec3 sp = c + 0.3 + 0.4 * jit;
	float d = length(p - sp);
	float mag = float((hh >> 10u) & 1023u) / 1023.0;
	mag = mag * mag * mag;
	float r = size * (0.6 + 0.7 * mag);
	float a = smoothstep(r, 0.0, d);
	a *= a;
	float temp = float((hh >> 20u) & 255u) / 255.0;
	vec3 col = mix(vec3(0.6, 0.75, 1.0), vec3(1.0, 0.78, 0.5), temp);
	col = mix(col, vec3(1.0), 0.35);
	float tw = 0.85 + 0.15 * sin(TIME * (1.5 + temp * 3.0) + float(hh & 255u));
	return col * a * (0.25 + 2.4 * mag + 0.35) * bright * tw;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 col = vec3(0.0);
	float lat = dot(dir, normalize(gal_normal));
	float band = exp(-lat * lat / 0.02);
	float lon = max(dot(dir, normalize(gal_center)), 0.0);
	// stars (denser along the galactic band)
	float dens = 1.0 + 2.2 * band;
	col += star_layer(dir, 55.0, 0.30 * dens, 0.10, 1.8, sky_seed);
	col += star_layer(dir, 120.0, 0.32 * dens, 0.16, 1.0, sky_seed + 1);
	col += star_layer(dir, 250.0, 0.30 * dens, 0.28, 0.55, sky_seed + 2);
	col *= star_amt;
	// milky way
	float dust = tn_fbm(dir * 5.0 + vec3(3.0, 1.0, 2.0), 4, 0.55, sky_seed + 3);
	float lane = smoothstep(0.1, -0.25, dust) * band;
	float mw = band * (0.5 + 0.5 * smoothstep(-0.35, 0.3, dust));
	vec3 mwcol = mix(vec3(0.42, 0.5, 0.75), vec3(1.0, 0.8, 0.55), pow(lon, 3.0));
	col += mwcol * mw * (0.08 + 0.55 * pow(lon, 2.5)) * gal_bright;
	col *= (1.0 - lane * 0.55);
	// nebulae
	float n1 = tn_fbm(dir * 2.1 + vec3(1.3, 7.7, 4.1), 5, 0.55, sky_seed + 4);
	float n2 = tn_fbm(dir * 1.7 + vec3(9.1, 2.2, 3.3), 5, 0.55, sky_seed + 5);
	col += neb_col1 * smoothstep(0.0, 0.5, n1) * neb_amt * 0.16;
	col += neb_col2 * smoothstep(0.05, 0.55, n2) * neb_amt * 0.14;
	col *= (1.0 - day_dim);
	if (AT_CUBEMAP_PASS) {
		float e = dot(dir, normalize(up_vec));
		vec3 sky_c = mix(refl_horizon, refl_zenith, smoothstep(0.0, 0.65, e));
		float below = smoothstep(0.02, -0.15, e);
		sky_c = mix(sky_c, refl_horizon * 0.2, below);
		float sd = max(dot(dir, normalize(refl_sun_dir)), 0.0);
		sky_c += refl_sun_col * (pow(sd, 48.0) * 0.8 + pow(sd, 6.0) * 0.12);
		col += sky_c * refl_amt;
	}
	COLOR = col;
}
