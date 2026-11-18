shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// Gas giant: latitudinal bands distorted by noise, plus a storm vortex.

#include "res://shaders/inc/tnoise.gdshaderinc"

uniform vec3 c0 : source_color = vec3(0.82, 0.62, 0.4);
uniform vec3 c1 : source_color = vec3(0.92, 0.82, 0.62);
uniform vec3 c2 : source_color = vec3(0.62, 0.4, 0.28);
uniform vec3 c3 : source_color = vec3(0.95, 0.9, 0.8);
uniform vec3 c4 : source_color = vec3(0.55, 0.36, 0.3);
uniform int seed = 3;
uniform float speed = 0.01;

uniform vec3 sun_dir_world = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_light_col : source_color = vec3(1.0, 0.95, 0.88);
uniform float sun_light_energy = 1.5;
varying vec3 v_sun_view;
varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
	v_sun_view = normalize((VIEW_MATRIX * vec4(sun_dir_world, 0.0)).xyz);
}

vec3 palette(float t) {
	t = fract(t) * 5.0;
	int i = int(floor(t));
	float f = smoothstep(0.0, 1.0, fract(t));
	vec3 a = c0; vec3 b = c1;
	if (i == 1) { a = c1; b = c2; }
	else if (i == 2) { a = c2; b = c3; }
	else if (i == 3) { a = c3; b = c4; }
	else if (i == 4) { a = c4; b = c0; }
	return mix(a, b, f);
}

void fragment() {
	vec3 dir = normalize(v_pos);
	float lat = dir.y;
	float lon = atan(dir.z, dir.x);
	// shear: each latitude drifts at its own speed
	float shear = sin(lat * 9.0) * 0.5;
	vec3 q = vec3(cos(lon + TIME * speed * (1.0 + shear)), lat * 2.3, sin(lon + TIME * speed * (1.0 + shear)));
	float w = tn_fbm(q * 3.0, 4, 0.55, seed) * 0.5;
	float fine = tn_fbm(vec3(q.x * 9.0, lat * 26.0, q.z * 9.0), 3, 0.5, seed + 1) * 0.06;
	float t = lat * 2.1 + w + fine;
	vec3 col = palette(t);
	// great storm
	vec3 spot = normalize(vec3(0.7, -0.28, 0.65));
	vec3 dd = dir - spot;
	float d = length(dd * vec3(1.0, 2.2, 1.0));
	float swirl = atan(dd.y, dd.x) * 3.0 + d * 30.0;
	float storm = smoothstep(0.32, 0.12, d);
	col = mix(col, mix(vec3(0.75, 0.3, 0.2), vec3(0.95, 0.75, 0.55), 0.5 + 0.5 * sin(swirl)), storm * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.2;
}

void light() {
	vec3 L = LIGHT;
	vec3 lc = LIGHT_COLOR;
	if (LIGHT_IS_DIRECTIONAL) {
		// every planet is lit from the direction of ITS star vector (one engine light cannot be right for all planets)
		L = normalize(v_sun_view);
		lc = sun_light_col * sun_light_energy * PI;
	}
	float ndl = clamp(dot(NORMAL, L), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * lc / PI;
	vec3 H = normalize(L + VIEW);
	float ndh = clamp(dot(NORMAL, H), 0.0, 1.0);
	float shin = exp2(10.0 * (1.0 - ROUGHNESS) + 1.0);
	SPECULAR_LIGHT += ndl * ATTENUATION * lc * pow(ndh, shin) * (1.0 - ROUGHNESS) * SPECULAR_AMOUNT * 0.35;
}
