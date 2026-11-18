shader_type spatial;
render_mode cull_back, unshaded;

#include "res://shaders/common.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);       // world space
uniform vec3 sun_color : source_color = vec3(1.0);
uniform vec3 col_a : source_color = vec3(0.86, 0.66, 0.42);
uniform vec3 col_b : source_color = vec3(0.95, 0.88, 0.74);
uniform vec3 col_c : source_color = vec3(0.62, 0.38, 0.22);
uniform vec3 col_d : source_color = vec3(0.80, 0.55, 0.36);
uniform float seed = 1.0;
uniform float bands = 9.0;
uniform float swirl = 1.0;
uniform float planet_radius = 15000.0;
uniform vec3 ambient : source_color = vec3(0.02, 0.02, 0.03);

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float lat = d.y;
	float t = TIME * 0.004 * swirl;
	// turbulent latitude
	float warp = fbm3(vec3(d.x * 3.0, d.y * 9.0, d.z * 3.0) + vec3(seed, t * 3.0, 0.0)) - 0.5;
	float lat2 = lat + warp * 0.12;
	float band = sin(lat2 * bands * 3.14159 + seed * 2.0) * 0.5 + 0.5;
	float band2 = sin(lat2 * bands * 1.7 * 3.14159 + seed * 5.0) * 0.5 + 0.5;
	float fine = fbm3(vec3(d.x * 6.0 + t * (3.0 + sin(lat * 7.0) * 2.0), d.y * 28.0, d.z * 6.0) + seed);
	vec3 col = mix(col_a, col_b, band);
	col = mix(col, col_c, band2 * 0.5 * fine);
	col = mix(col, col_d, smoothstep(0.55, 0.9, fine) * 0.6);
	// storm vortex
	vec3 sc = normalize(vec3(0.7, -0.25, 0.65));
	float sd = length(d - sc);
	float storm = smoothstep(0.26, 0.05, sd);
	float spiral = sin(atan(d.y - sc.y, d.x - sc.x) * 3.0 + sd * 40.0 - t * 40.0) * 0.5 + 0.5;
	col = mix(col, mix(vec3(0.75, 0.30, 0.18), vec3(0.95, 0.78, 0.6), spiral), storm * 0.85);

	vec3 wn = normalize((MODEL_MATRIX * vec4(d, 0.0)).xyz);
	float ndl = dot(wn, sun_dir);
	float lit = smoothstep(-0.08, 0.35, ndl);
	float limb = pow(clamp(dot(wn, normalize(CAMERA_POSITION_WORLD - (MODEL_MATRIX[3].xyz + wn * planet_radius))), 0.0, 1.0), 0.45);
	vec3 outc = col * (sun_color * (0.04 + 1.25 * lit) * (0.55 + 0.45 * limb)) + ambient * col;
	ALBEDO = outc;
}
