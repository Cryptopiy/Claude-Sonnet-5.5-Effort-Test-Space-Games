shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
// Planetary ring: radial density bands, lit by the star, shadowed by the planet.

#include "res://shaders/inc/tnoise.gdshaderinc"

uniform vec3 ring_col : source_color = vec3(0.8, 0.7, 0.55);
uniform vec3 sun_local = vec3(1.0, 0.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.9);
uniform float planet_r = 16000.0;
uniform float inner = 1.45;
uniform float outer = 2.35;
uniform int seed = 4;

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float rad = length(v_pos.xz) / planet_r;
	float u = (rad - inner) / (outer - inner);
	float bands = tn_fbm(vec3(u * 38.0, 0.5, 0.2), 4, 0.55, seed) * 0.5 + 0.5;
	float fine = tn_fbm(vec3(u * 170.0, 3.0, 1.0), 3, 0.5, seed + 1) * 0.5 + 0.5;
	float dens = smoothstep(0.25, 0.75, bands) * (0.6 + 0.4 * fine);
	// gap (Cassini-like)
	dens *= 1.0 - smoothstep(0.02, 0.0, abs(u - 0.62)) * 0.9;
	dens *= smoothstep(0.0, 0.04, u) * smoothstep(1.0, 0.94, u);
	// planet shadow
	vec3 sl = normalize(sun_local);
	float b = dot(v_pos, sl);
	float c = dot(v_pos, v_pos) - planet_r * planet_r;
	float disc = b * b - c;
	float shadow = 1.0;
	if (disc > 0.0 && (-b + sqrt(disc)) > 0.0 && (-b - sqrt(disc)) > -1e9) {
		float tn = -b - sqrt(disc);
		if (tn > 0.0) { shadow = 0.12; }
	}
	float lit = 0.35 + 0.65 * abs(sl.y) * 0.5 + 0.35;
	ALBEDO = ring_col * (0.7 + 0.5 * fine) * mix(vec3(1.0), sun_col, 0.5) * lit * shadow;
	ALPHA = dens * 0.9;
}
