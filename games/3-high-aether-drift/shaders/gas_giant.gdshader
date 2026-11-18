shader_type spatial;
render_mode cull_back;

#include "res://shaders/include/noise.gdshaderinc"

uniform vec3 c0 : source_color = vec3(0.9, 0.75, 0.5);
uniform vec3 c1 : source_color = vec3(0.7, 0.45, 0.3);
uniform vec3 c2 : source_color = vec3(0.95, 0.9, 0.8);
uniform vec3 c3 : source_color = vec3(0.5, 0.3, 0.25);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float g_seed = 1.0;
uniform float bands = 9.0;

varying vec3 v_local;
varying vec3 sun_v;

void vertex() {
	v_local = VERTEX;
	sun_v = (VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz;
}

void fragment() {
	vec3 d = normalize(v_local);
	float lat = d.y;
	float warp = fbm(d * 3.0 + vec3(g_seed * 5.0), 401u, 4);
	float turb = fbm(vec3(d.x * 6.0, d.y * 18.0, d.z * 6.0) + vec3(g_seed), 409u, 4);
	float b = lat * bands + warp * 1.8 + turb * 0.5 + 0.15 * sin(lat * 40.0);
	float f = fract(b * 0.5 + 0.5);
	vec3 col = mix(c0, c1, smoothstep(0.0, 0.35, f));
	col = mix(col, c2, smoothstep(0.35, 0.6, f) * (1.0 - smoothstep(0.6, 0.8, f)));
	col = mix(col, c3, smoothstep(0.8, 1.0, f));
	col *= 0.85 + 0.3 * turb;
	// great storm
	vec3 sc = normalize(vec3(0.7, -0.25, 0.65));
	float sd = distance(d, sc);
	float storm = 1.0 - smoothstep(0.08, 0.2, sd * (1.0 + 0.4 * sin(atan(d.y + 0.25, d.x - 0.7) * 2.0)));
	col = mix(col, c3 * 1.3 + vec3(0.2, 0.05, 0.0), storm * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, normalize(sun_v)), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
}
