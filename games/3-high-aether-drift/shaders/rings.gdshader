shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform vec3 ring_col : source_color = vec3(0.85, 0.78, 0.65);
uniform float r_in = 0.55;   // as fractions of the outer radius
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float body_r = 0.4;  // planet radius / outer ring radius (for the planet's shadow)

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	float r = length(v_local.xz);   // outer radius normalised to 1 in mesh space
	if (r < r_in || r > 1.0) { discard; }
	float t = (r - r_in) / (1.0 - r_in);
	float bands = 0.0;
	for (int i = 0; i < 14; i++) {
		float c = hash11(float(i) + 3.0);
		float w = 0.015 + 0.05 * hash11(float(i) * 7.3);
		bands += (0.4 + 0.6 * hash11(float(i) * 3.7)) * exp(-pow((t - c) / w, 2.0));
	}
	float fine = 0.55 + 0.45 * sin(t * 260.0 + sin(t * 31.0) * 3.0);
	float a = clamp(0.2 + bands * 0.9, 0.0, 1.0) * fine;
	a *= smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.93, 1.0, t));
	// planet shadow cast on the ring
	vec3 p = vec3(v_local.x, 0.0, v_local.z);
	float s = dot(p, sun_dir);
	float shadow = 1.0;
	if (s < 0.0) {
		float perp = length(p - sun_dir * s);
		shadow = smoothstep(body_r * 0.95, body_r * 1.05, perp);
	}
	ALBEDO = ring_col * (0.7 + 0.5 * a) * mix(0.1, 1.0, shadow);
	ALPHA = a * 0.85;
}
