shader_type canvas_item;
// Frosted, darkened backdrop for pause / inventory / controls overlays: blurs whatever is rendered behind it (module M6).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.6;
uniform vec4 tint : source_color = vec4(0.015, 0.030, 0.060, 1.0);
uniform float tint_amount = 0.55;
uniform float vignette = 0.65;
uniform float fade = 1.0;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.35);
	c = mix(c, tint.rgb, tint_amount);
	vec2 q = (UV - 0.5) * vec2(1.0, 1.15);
	float v = smoothstep(0.30, 0.95, length(q));
	c *= 1.0 - v * vignette;
	c *= 0.96 + 0.04 * sin(FRAGCOORD.y * 1.6);
	COLOR = vec4(c, fade);
}
