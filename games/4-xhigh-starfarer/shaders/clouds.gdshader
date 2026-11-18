shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
// Cloud shell: noise on the sphere direction, lit by the star, fades near the camera.

uniform int t_seed = 3;
uniform float planet_r = 5000.0;
uniform float cover = 0.5;
uniform vec3 cloud_col : source_color = vec3(1.0);
uniform vec3 sun_dir_w = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.9);
uniform float ambient = 0.25;
uniform float scale = 3.2;
uniform float speed = 0.004;
uniform float fade_near = 150.0;

#include "res://shaders/inc/tnoise.gdshaderinc"

varying vec3 v_pos;
varying vec3 v_sun_local;

void vertex() {
	v_pos = VERTEX;
	v_sun_local = transpose(mat3(MODEL_MATRIX)) * normalize(sun_dir_w);
}

float cloud_density(vec3 dir, float t) {
	vec3 p = dir * scale;
	// slow swirl
	float c, s;
	c = cos(t * speed); s = sin(t * speed);
	p = vec3(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
	float base = tn_fbm(p + vec3(7.3, 1.1, 3.9), 4, 0.5, t_seed);
	float detail = tn_fbm(p * 4.0 + vec3(11.0, 5.0, 2.0), 3, 0.5, t_seed + 3);
	return base * 0.9 + detail * 0.25;
}

void fragment() {
	vec3 dir = normalize(v_pos);
	float d = cloud_density(dir, TIME);
	float thr = mix(0.55, -0.35, clamp(cover, 0.0, 1.0));
	float a = smoothstep(thr, thr + 0.28, d);
	if (a < 0.01) {
		discard;
	}
	vec3 sl = normalize(v_sun_local);
	float ndl = dot(dir, sl);
	// thickness-based shading: darker where dense, brighter toward the sun
	float thick = smoothstep(thr, thr + 0.6, d);
	float lit = clamp(ndl * 0.8 + 0.35, 0.0, 1.0);
	vec3 col = cloud_col * (ambient + (1.0 - ambient) * lit * (1.0 - thick * 0.45));
	col *= mix(vec3(1.0), sun_col, 0.6);
	float dist = length(VERTEX);
	float f = smoothstep(fade_near, fade_near * 4.0, dist);
	ALBEDO = col;
	ALPHA = a * f * 0.92;
}
