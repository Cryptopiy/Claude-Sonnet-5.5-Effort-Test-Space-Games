shader_type canvas_item;
render_mode blend_disabled;
// HORIZON DRIFT - black hole near-field post effect (module M5): chromatic aberration, vignette, FOV stretch while falling in,
// radial "spaghettification" streaking toward the singularity.  Sits in a CanvasLayer BELOW the HUD, so UI is never distorted.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 bh_uv = vec2(0.5, 0.5);
uniform float near_k = 0.0;     // 0..1 : proximity (aberration, vignette, slight FOV stretch)
uniform float fall_k = 0.0;     // 0..1 : final plunge (radial stretch, red tint)
uniform float tint_k = 0.0;     // 0..1 : red-shift tint
uniform float time_s = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (uv - c) * vec2(aspect, 1.0);
	float rr = length(p);

	// FOV stretch: the picture is pulled outward at the edges (looks like the lens widening as gravity bends space)
	float fov_k = near_k * 0.55 + fall_k * 0.45;
	vec2 uv2 = c + (uv - c) * (1.0 + fov_k * (0.045 + 0.20 * rr * rr));

	// radial stretch towards the singularity (taps along the line pixel -> bh)
	vec2 dirv = uv2 - bh_uv;
	float chroma = (near_k * 0.006 + fall_k * 0.020);
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	float jitter = hash12(FRAGCOORD.xy + fract(time_s) * 13.0);
	const int N = 14;
	float reach = fall_k * 0.62;
	for (int i = 0; i < N; i++) {
		float t = (float(i) + jitter) / float(N);
		vec2 s = bh_uv + dirv * (1.0 - reach * t);
		vec2 off = (s - c) * chroma;
		float w = 1.0 - 0.55 * t;
		acc.r += texture(screen_tex, s + off).r * w;
		acc.g += texture(screen_tex, s).g * w;
		acc.b += texture(screen_tex, s - off).b * w;
		wsum += w;
	}
	vec3 col = acc / wsum;

	// vignette + red-shift
	float vig = smoothstep(0.30, 0.95, rr * 1.25) * (near_k * 0.55 + fall_k * 0.65);
	col *= 1.0 - vig;
	vec3 rs_tint = vec3(1.0, 0.62, 0.40);
	col *= mix(vec3(1.0), rs_tint, tint_k * 0.8);
	COLOR = vec4(col, 1.0);
}
