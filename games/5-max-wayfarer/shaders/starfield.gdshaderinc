// Procedural galaxy backdrop shared by the sky shader and the black hole lens shader (needs common.gdshaderinc first).

vec3 star_layer(vec3 dir, float scale, float prob, float size, float bright, float seed) {
	vec3 p = dir * scale;
	vec3 ip = floor(p);
	float r = hash13(ip + seed);
	if (r > prob) return vec3(0.0);
	vec3 h = hash33(ip + seed * 1.7);
	vec3 spos = ip + 0.25 + 0.5 * h;
	// round disc on the sphere: angular distance (in cell units) between the ray and the star direction
	float dist = length(normalize(spos) - dir) * scale;
	float rnd = hash13(ip + seed + 9.3);
	float sz = size * (0.55 + 0.9 * rnd * rnd);
	float s = smoothstep(sz, 0.0, dist);
	s *= s;
	float temp = hash13(ip + seed + 5.1);
	vec3 col = mix(vec3(1.0, 0.64, 0.42), vec3(0.64, 0.78, 1.0), temp);
	col = mix(col, vec3(1.0), 0.5);
	float b = bright * (0.25 + 1.6 * rnd * rnd * rnd);
	return col * s * b;
}

vec3 starfield(vec3 dir, vec3 gal_n, vec3 gal_c, vec3 neb_a, vec3 neb_b, float sky_seed, float star_density, float band_strength) {
	float lat = dot(dir, normalize(gal_n));
	float band = exp(-lat * lat / 0.030);
	float cdot = dot(dir, normalize(gal_c));
	float core = smoothstep(-0.2, 1.0, cdot);
	vec3 col = vec3(0.0025, 0.003, 0.0055);
	// milky way
	float d1 = fbm3(dir * 4.0 + sky_seed);
	float d2 = fbm3(dir * 9.0 + sky_seed * 2.0);
	float dens = band * (0.30 + 1.1 * d1) * band_strength;
	float lanes = smoothstep(0.42, 0.68, fbm3(dir * 6.5 + sky_seed * 3.0 + vec3(5.0)));
	vec3 mw = mix(vec3(0.20, 0.22, 0.34), vec3(1.0, 0.82, 0.60), core);
	col += mw * dens * 0.30 * (1.0 - 0.72 * lanes * band) * (0.8 + 0.4 * d2);
	// nebula patches
	float n1 = fbm3(dir * 2.3 + sky_seed * 0.7);
	float n2 = fbm3(dir * 3.1 + sky_seed * 1.9 + vec3(9.0));
	float neb = smoothstep(0.50, 0.88, n1);
	col += mix(neb_a, neb_b, smoothstep(0.3, 0.7, n2)) * neb * 0.075 * (0.45 + band);
	// stars: several layers, denser inside the band
	float bprob = 1.0 + 4.0 * band;
	vec3 st = vec3(0.0);
	st += star_layer(dir, 36.0, 0.050 * star_density * bprob, 0.13, 2.6, 1.0 + sky_seed);
	st += star_layer(dir, 80.0, 0.060 * star_density * bprob, 0.15, 1.5, 2.0 + sky_seed);
	st += star_layer(dir, 190.0, 0.080 * star_density * bprob, 0.17, 1.0, 3.0 + sky_seed);
	st += star_layer(dir, 430.0, 0.100 * star_density * bprob, 0.20, 0.7, 4.0 + sky_seed);
	st += star_layer(dir, 800.0, 0.130 * star_density * bprob, 0.22, 0.5, 5.0 + sky_seed);
	return col + st;
}
