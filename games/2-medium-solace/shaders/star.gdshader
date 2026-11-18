shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
uniform vec3 star_color : source_color = vec3(1.0, 0.9, 0.6);
varying vec3 vp;
float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { vp = normalize(VERTEX); }
void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float t = TIME * 0.05;
	float g = vn(vp * 9.0 + vec3(t)) * 0.6 + vn(vp * 24.0 - vec3(t * 2.0)) * 0.4;
	float spots = smoothstep(0.62, 0.8, vn(vp * 4.0 + t * 0.5));
	float limb = pow(ndv, 0.55);
	vec3 c = star_color * (0.9 + 0.7 * g) * (1.0 - 0.45 * spots) * limb;
	c = mix(c, star_color * 1.4, pow(1.0 - ndv, 3.0) * 0.4);
	ALBEDO = c * 3.2;
}
