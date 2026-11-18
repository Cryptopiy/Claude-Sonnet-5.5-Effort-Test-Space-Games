shader_type canvas_item;
uniform float progress = 0.0;
uniform vec3 tint : source_color = vec3(0.5, 0.7, 1.0);
uniform float mode = 0.0;
float h11(float x) { return fract(sin(x * 127.1) * 43758.5453); }
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.78, 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x);
	float inten = sin(clamp(progress, 0.0, 1.0) * 3.14159);
	float cell = floor(ang * 90.0);
	float h = h11(cell);
	float speed = 2.0 + h * 5.0;
	float streak = pow(fract(h * 7.0 - r * 1.2 * (1.0 + inten * 6.0) + TIME * speed), 8.0 + 24.0 * (1.0 - inten));
	streak *= smoothstep(0.02, 0.5, r) * step(0.35, h);
	float swirl = mode * 0.5 * sin(ang * 3.0 + r * 12.0 - TIME * 8.0);
	vec3 c = tint * (streak * 2.2 * inten) + tint * 0.25 * inten * smoothstep(0.9, 0.0, r);
	c += vec3(max(swirl, 0.0)) * inten * 0.4;
	float flash = smoothstep(0.42, 0.5, progress) * smoothstep(0.64, 0.5, progress);
	c += vec3(1.0) * flash * 1.5;
	float a = clamp(inten * 0.85 + flash, 0.0, 1.0);
	if (mode > 0.5) {
		a = clamp(smoothstep(0.0, 0.45, progress) * smoothstep(1.0, 0.65, progress) + flash, 0.0, 1.0);
	}
	COLOR = vec4(c, a);
}
