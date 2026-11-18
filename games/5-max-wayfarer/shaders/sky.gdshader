shader_type sky;

#include "res://shaders/common.gdshaderinc"
#include "res://shaders/starfield.gdshaderinc"

// Procedural galaxy backdrop: multi-layer star field, Milky-Way band with dust lanes, nebula patches.
// Used as the background for every system; the atmosphere shells draw the daytime sky on top.

uniform vec3 galaxy_normal = vec3(0.22, 0.94, 0.26);
uniform vec3 galaxy_center_dir = vec3(0.72, 0.12, -0.68);
uniform vec3 nebula_a : source_color = vec3(0.30, 0.38, 0.85);
uniform vec3 nebula_b : source_color = vec3(0.80, 0.30, 0.55);
uniform float star_density = 1.0;
uniform float sky_seed = 3.0;
uniform float exposure = 1.0;
uniform float band_strength = 1.0;

void sky() {
	vec3 dir = normalize(EYEDIR);
	COLOR = starfield(dir, galaxy_normal, galaxy_center_dir, nebula_a, nebula_b, sky_seed, star_density, band_strength) * exposure;
}
