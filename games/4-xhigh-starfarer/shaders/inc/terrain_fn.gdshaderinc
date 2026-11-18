// Terrain height function. Include AFTER tnoise.gdshaderinc and after declaring the t_* uniforms.
// ---------------------------------------------------------------- terrain
// required uniforms:
//   float t_radius; float t_freq; vec3 t_seed_off; int t_seed;
//   float t_a_cont, t_a_hill; int t_hill_oct; float t_hill_gain;
//   float t_a_ridge, t_ridge_freq, t_ridge_lo, t_ridge_hi; int t_ridge_oct;
//   float t_a_dune, t_dune_freq; float t_a_crater, t_crater_freq;
//   float t_a_detail, t_detail_cell; float t_terrace, t_terrace_step;
float terrain_height(vec3 dir, float spacing) {
	vec3 p = dir * t_freq + t_seed_off;
	float cell0 = t_radius / (t_freq * 3.0);
	int lod_oct = int(floor(log(max(cell0 / (2.0 * max(spacing, 0.01)), 1.0)) / log(2.0))) + 1;
	float h = t_a_cont * tn_fbm(p * 0.5, 3, 0.5, t_seed);
	h += t_a_hill * tn_fbm(p * 3.0 + 3.1, min(t_hill_oct, lod_oct), t_hill_gain, t_seed + 1);
	if (t_a_ridge > 0.0) {
		float m = tn_smooth(t_ridge_lo, t_ridge_hi, tn_fbm(p * 1.3 + 7.7, 2, 0.5, t_seed + 2));
		if (m > 0.0) {
			h += t_a_ridge * m * tn_ridged(p * t_ridge_freq + 5.5, min(t_ridge_oct, lod_oct), t_seed + 3);
		}
	}
	if (t_a_dune > 0.0) {
		vec3 q = p * t_dune_freq;
		float w = tn_fbm(q * 0.35, 2, 0.5, t_seed + 4);
		float d = 1.0 - abs(sin(q.x + q.y * 0.35 + w * 3.0));
		h += t_a_dune * d * d * (0.55 + 0.45 * tn_fbm(p * 0.9, 2, 0.5, t_seed + 6));
	}
	if (t_a_crater > 0.0) {
		vec3 q = p * t_crater_freq;
		h += t_a_crater * (tn_craters(q, t_seed + 7) + 0.5 * tn_craters(q * 3.7 + 40.0, t_seed + 8));
	}
	if (t_a_detail > 0.0) {
		vec3 q = dir * (t_radius / t_detail_cell) + t_seed_off * 2.0;
		float fade = clamp(1.0 - (2.0 * spacing / t_detail_cell - 0.4), 0.0, 1.0);
		if (fade > 0.0) {
			h += t_a_detail * fade * tn_fbm(q, 3, 0.5, t_seed + 5);
		}
	}
	if (t_terrace > 0.0) {
		float qq = h / t_terrace_step;
		h = mix(h, (floor(qq) + tn_smooth(0.35, 0.65, fract(qq))) * t_terrace_step, t_terrace);
	}
	return h;
}
