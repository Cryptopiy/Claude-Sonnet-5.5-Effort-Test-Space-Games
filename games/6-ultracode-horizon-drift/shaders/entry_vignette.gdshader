shader_type canvas_item;
// Atmospheric-entry screen heat: flickering orange-white flames licking in from the screen edges (full-screen overlay below the HUD).
// (sine-based flicker: smooth, no hash noise - a value-noise version showed hard rectangular cells)
uniform float heat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv * vec2(1.0, 0.78));
	float ang = atan(uv.y, uv.x);
	float edge = smoothstep(0.42 - 0.22 * heat, 1.3, r);
	float f1 = 0.5 + 0.5 * sin(ang * 7.0 + TIME * 5.3 + r * 4.0);
	float f2 = 0.5 + 0.5 * sin(ang * 13.0 - TIME * 8.1 - r * 7.0);
	float f3 = 0.5 + 0.5 * sin(uv.y * 9.0 - TIME * 11.0 + uv.x * 3.0 + f1 * 2.0);
	float n = f1 * 0.4 + f2 * 0.3 + f3 * 0.3;
	float a = heat * edge * (0.40 + 0.80 * n);
	vec3 col = mix(vec3(0.95, 0.22, 0.04), vec3(1.0, 0.72, 0.28), clamp(edge * n * 1.3, 0.0, 1.0));
	COLOR = vec4(col, clamp(a * 0.75, 0.0, 0.72));
}
