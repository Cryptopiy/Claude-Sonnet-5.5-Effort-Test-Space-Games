shader_type canvas_item;
uniform float intensity = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.45, 0.12);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.78, 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x);
	float fl = n(vec2(ang * 6.0, r * 8.0 - TIME * 14.0)) * 0.6 + n(vec2(ang * 14.0, r * 20.0 - TIME * 25.0)) * 0.4;
	float edge = smoothstep(0.25, 0.95, r);
	float a = edge * (0.35 + 0.9 * fl) * intensity;
	COLOR = vec4(tint * (1.0 + fl), clamp(a, 0.0, 0.85));
}
