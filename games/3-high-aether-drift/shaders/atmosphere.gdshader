shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
// Ray-marched in-scattering through a spherical atmosphere shell. Works from space (limb glow) and from inside.

uniform vec3 atm_color : source_color = vec3(0.4, 0.6, 1.0);
uniform float planet_r = 4000.0;
uniform float atm_r = 4800.0;
uniform float scale_h = 250.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float intensity = 1.0;
uniform float inside_fade = 1.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

bool ray_sphere(vec3 ro, vec3 rd, float r, out float t0, out float t1) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float h = b * b - c;
	if (h < 0.0) { return false; }
	h = sqrt(h);
	t0 = -b - h;
	t1 = -b + h;
	return true;
}

void fragment() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 ro = CAMERA_POSITION_WORLD - center;
	vec3 rd = normalize(v_world - CAMERA_POSITION_WORLD);
	float t0; float t1;
	if (!ray_sphere(ro, rd, atm_r, t0, t1)) { discard; }
	t0 = max(t0, 0.0);
	float p0; float p1;
	if (ray_sphere(ro, rd, planet_r * 0.9995, p0, p1) && p1 > 0.0) {
		t1 = min(t1, max(p0, 0.0));
	}
	if (t1 <= t0) { discard; }
	const int N = 14;
	float stp = (t1 - t0) / float(N);
	float acc = 0.0;
	vec3 tint = vec3(0.0);
	for (int i = 0; i < N; i++) {
		float t = t0 + (float(i) + 0.5) * stp;
		vec3 p = ro + rd * t;
		float alt = max(length(p) - planet_r, 0.0);
		float dens = exp(-alt / scale_h);
		float lit = clamp(dot(normalize(p), sun_dir) * 1.1 + 0.22, 0.0, 1.0);
		float tw = clamp(1.0 - abs(dot(normalize(p), sun_dir)) * 3.0, 0.0, 1.0);
		vec3 c = mix(atm_color, vec3(1.0, 0.5, 0.25) * 0.9 + atm_color * 0.3, tw * 0.6);
		float sunward = 0.7 + 0.5 * pow(max(dot(rd, sun_dir), 0.0), 6.0);
		tint += c * dens * lit * stp * sunward;
		acc += dens * stp;
	}
	float k = 1.0 / (scale_h * 6.0);
	vec3 col = tint * k * intensity * inside_fade;
	ALBEDO = col;
	ALPHA = 1.0;
}
