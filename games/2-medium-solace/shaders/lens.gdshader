shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 center = vec2(0.5);
uniform float rs = 0.05;
uniform float strength = 1.0;
uniform float aspect = 1.78;
void fragment() {
	vec2 p = SCREEN_UV - center;
	p.x *= aspect;
	float r = length(p);
	float b = rs * 2.2;
	vec2 src = p * (1.0 - (b * b) / (r * r + 1e-6) * strength);
	vec2 uv = center + vec2(src.x / aspect, src.y);
	vec3 col = textureLod(scr, clamp(uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
	float hor = smoothstep(rs, rs * 0.96, r);
	col = mix(col, vec3(0.0), hor);
	float ring = exp(-pow((r - rs * 1.04) / (rs * 0.07), 2.0));
	float ring2 = exp(-pow((r - rs * 1.3) / (rs * 0.25), 2.0)) * 0.25;
	col += vec3(1.0, 0.8, 0.5) * (ring * 1.4 + ring2) * strength;
	COLOR = vec4(col, 1.0);
}
