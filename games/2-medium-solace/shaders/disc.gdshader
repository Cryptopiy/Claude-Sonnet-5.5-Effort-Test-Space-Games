shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
varying vec2 pv;
float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { pv = VERTEX.xz; }
void fragment() {
	float r = UV.x;
	float ang = atan(pv.y, pv.x);
	float swirl = ang + 5.0 / (r + 0.15) - TIME * (1.4 / (r + 0.2));
	float n = vn(vec3(cos(swirl), sin(swirl), r * 14.0) * 2.2 + 3.0) * 0.6 + vn(vec3(cos(swirl * 2.0), sin(swirl * 2.0), r * 40.0) * 3.0) * 0.4;
	float streak = 0.35 + 1.1 * n;
	vec3 hot = vec3(1.0, 0.95, 0.85);
	vec3 mid = vec3(1.0, 0.55, 0.15);
	vec3 cold = vec3(0.55, 0.12, 0.04);
	vec3 c = mix(hot, mid, smoothstep(0.0, 0.35, r));
	c = mix(c, cold, smoothstep(0.3, 1.0, r));
	float dop = 1.0 + 0.55 * sin(ang - 0.6);
	float a = smoothstep(0.0, 0.05, r) * smoothstep(1.0, 0.55, r) * streak * dop;
	ALBEDO = c * a * 1.5 * (1.3 - r);
}
