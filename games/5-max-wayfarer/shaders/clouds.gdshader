shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded, fog_disabled;

#include "res://shaders/common.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);       // world space
uniform vec3 sun_color : source_color = vec3(1.0);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 ambient_color : source_color = vec3(0.45, 0.55, 0.8);
uniform float cover = 0.45;
uniform float speed = 0.012;
uniform float freq = 6.0;
uniform float seed = 1.0;
uniform float darkness = 0.55;
uniform float intensity = 1.0;

varying vec3 v_dir;
varying vec3 v_world;
varying vec3 v_sun_local;

void vertex() {
	v_dir = normalize(VERTEX);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_sun_local = normalize((inverse(MODEL_MATRIX) * vec4(sun_dir, 0.0)).xyz);
}

float cloud_density(vec3 d, float t) {
	vec3 q = d * freq + vec3(seed * 13.7) + vec3(t, 0.0, t * 0.6);
	float base = fbm3(q);
	float det = fbm3(q * 3.1 + vec3(5.0, 1.0, 9.0)) * 0.35;
	float n = base * 0.8 + det * 0.4;
	return smoothstep(1.0 - cover, 1.0 - cover + 0.22, n);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float t = TIME * speed;
	float dens = cloud_density(d, t);
	vec3 wn = normalize((MODEL_MATRIX * vec4(d, 0.0)).xyz);
	float ndl = dot(wn, sun_dir);
	// cheap self shadow: density a bit towards the sun
	vec3 sl = v_sun_local;
	float d2 = cloud_density(normalize(d + sl * 0.012), t);
	float shade = clamp(1.0 - (d2 - dens) * 1.6 * darkness - (1.0 - darkness) * 0.3, 0.3, 1.0);
	float day = smoothstep(-0.18, 0.30, ndl);
	vec3 lit = sun_color * (0.35 + 1.15 * clamp(ndl * 0.7 + 0.3, 0.0, 1.0)) * shade * day;
	vec3 col = cloud_color * (lit + ambient_color * 0.18 + 0.01);
	// fade when the camera is close to the layer (flying through)
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float near_fade = smoothstep(20.0, 160.0, dist);
	ALBEDO = col * intensity;
	ALPHA = dens * 0.93 * near_fade;
}
