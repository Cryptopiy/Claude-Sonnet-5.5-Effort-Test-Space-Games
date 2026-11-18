shader_type spatial;
render_mode diffuse_burley;
uniform vec3 c1 : source_color = vec3(0.85, 0.65, 0.4);
uniform vec3 c2 : source_color = vec3(0.55, 0.35, 0.25);
uniform vec3 c3 : source_color = vec3(0.95, 0.85, 0.7);
uniform float seed = 0.3;
varying vec3 vp;
float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { vp = normalize(VERTEX); }
void fragment() {
	float lat = vp.y;
	float warp = vn(vec3(vp.x * 3.0, vp.y * 1.5, vp.z * 3.0) + seed * 20.0 + TIME * 0.01) * 0.12 + vn(vp * 9.0 + seed) * 0.03;
	float b = sin((lat + warp) * 26.0 + seed * 6.0) * 0.5 + 0.5;
	float b2 = sin((lat + warp * 1.5) * 61.0 + seed * 3.0) * 0.5 + 0.5;
	vec3 c = mix(c1, c2, b);
	c = mix(c, c3, b2 * 0.35);
	float storm = smoothstep(0.12, 0.0, length(vec2(vp.x - 0.5, (vp.y + 0.28) * 1.8)) + vn(vp * 14.0) * 0.06);
	c = mix(c, vec3(0.75, 0.3, 0.2), storm * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
