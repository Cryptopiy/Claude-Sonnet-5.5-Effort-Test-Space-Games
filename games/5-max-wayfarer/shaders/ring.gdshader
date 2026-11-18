shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;

#include "res://shaders/common.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform vec3 ring_color : source_color = vec3(0.8, 0.72, 0.6);
uniform float inner = 21000.0;
uniform float outer = 36000.0;
uniform float planet_radius = 15000.0;
uniform float seed = 1.0;

varying vec3 v_local;
varying vec3 v_world;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(v_local.xz);
	float u = (r - inner) / (outer - inner);
	if (u < 0.0 || u > 1.0) {
		ALPHA = 0.0;
	} else {
		float bands = vnoise(vec3(u * 38.0, seed, 0.0)) * 0.55 + vnoise(vec3(u * 110.0, seed + 3.0, 1.0)) * 0.3 + vnoise(vec3(u * 310.0, seed + 7.0, 2.0)) * 0.15;
		float gaps = smoothstep(0.30, 0.45, vnoise(vec3(u * 14.0, seed + 11.0, 4.0)));
		float edge = smoothstep(0.0, 0.04, u) * (1.0 - smoothstep(0.93, 1.0, u));
		float dens = clamp(bands * 1.25 - 0.18, 0.0, 1.0) * mix(0.25, 1.0, gaps) * edge;
		// planet shadow on the ring
		vec3 centre = MODEL_MATRIX[3].xyz;
		vec3 oc = v_world - centre;
		float t0;
		float t1;
		float sh = 1.0;
		if (ray_sphere(oc, sun_dir, planet_radius, t0, t1)) {
			if (t1 > 0.0) sh = 0.12;
		}
		vec3 wn = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		float ndl = abs(dot(wn, sun_dir));
		vec3 col = ring_color * (0.30 + 1.0 * ndl) * sun_color * sh * (0.75 + 0.5 * bands);
		ALBEDO = col;
		ALPHA = dens * 0.88;
	}
}
