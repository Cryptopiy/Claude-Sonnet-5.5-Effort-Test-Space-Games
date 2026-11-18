shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded, fog_disabled;

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float coverage = 0.5;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_r = 4000.0;
uniform float cl_seed = 3.0;
uniform float drift = 0.0;
uniform float night_floor = 0.06;
uniform float freq = 6.0;

varying vec3 v_local;
varying vec3 v_n;

void vertex() {
	v_local = VERTEX;
	v_n = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

void fragment() {
	vec3 d = normalize(v_local);
	float a = drift;
	vec3 p = vec3(d.x * cos(a) - d.z * sin(a), d.y, d.x * sin(a) + d.z * cos(a)) * freq + vec3(cl_seed * 7.1);
	float n = fbm(p, 301u, 5) * 0.5 + 0.5;
	float n2 = fbm(p * 3.1, 307u, 3) * 0.5 + 0.5;
	float dens = smoothstep(1.0 - coverage, 1.0 - coverage + 0.25, n * 0.78 + n2 * 0.22);
	float lit = clamp(dot(v_n, sun_dir) * 1.2 + 0.25, 0.0, 1.0);
	vec3 col = cloud_color * mix(night_floor, 1.0, lit);
	// brighter silhouettes toward the sun side, darker cores
	col *= 0.78 + 0.35 * n2;
	float cam_d = length(VERTEX);
	float fade = smoothstep(40.0, 240.0, cam_d);
	ALBEDO = col;
	ALPHA = dens * fade * 0.92;
}
