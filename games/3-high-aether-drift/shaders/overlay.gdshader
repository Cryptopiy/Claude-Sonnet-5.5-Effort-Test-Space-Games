shader_type canvas_item;
// Full-screen post effects: atmospheric-entry heat, pulse/warp tunnel, black hole stretch, damage flash and fades.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float heat = 0.0;
uniform float warp = 0.0;      // 0..1 radial streak blur (pulse drive / warp)
uniform float tunnel = 0.0;    // 0..1 hyperspace tunnel lines
uniform float bh = 0.0;        // 0..1 black-hole distortion
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0, 0.1, 0.05, 1.0);
uniform float fade = 0.0;
uniform vec4 fade_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float underwater = 0.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	vec3 col;
	float w = max(warp, bh * 0.8);
	if (w > 0.002) {
		col = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float t = float(i) / 11.0;
			vec2 uu = 0.5 + c * (1.0 - w * 0.28 * t);
			col += texture(screen_tex, uu).rgb;
		}
		col /= 12.0;
		float ab = w * 0.006;
		col.r = mix(col.r, texture(screen_tex, 0.5 + c * (1.0 - w * 0.28 * 0.5 + ab)).r, 0.5);
		col.b = mix(col.b, texture(screen_tex, 0.5 + c * (1.0 - w * 0.28 * 0.5 - ab)).b, 0.5);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (tunnel > 0.001) {
		float a = atan(c.y, c.x);
		float seg = floor(a * 70.0);
		float line = step(0.94, h21(vec2(seg, floor(TIME * 6.0 + r * 4.0 * h21(vec2(seg, 1.0))))));
		float moving = fract(r * 2.0 - TIME * (1.5 + 2.0 * h21(vec2(seg, 3.0))) + h21(vec2(seg, 7.0)));
		col += vec3(0.55, 0.75, 1.0) * line * moving * tunnel * smoothstep(0.05, 0.6, r) * 1.6;
		col = mix(col, col * 0.3 + vec3(0.1, 0.2, 0.5) * tunnel * (1.0 - r), tunnel * 0.6);
	}
	if (heat > 0.001) {
		float flick = 0.75 + 0.25 * sin(TIME * 28.0 + uv.y * 30.0) * sin(TIME * 17.0 + uv.x * 20.0);
		col += heat * vec3(1.0, 0.42, 0.1) * smoothstep(0.2, 0.75, r) * 1.1 * flick;
		col += heat * vec3(1.0, 0.7, 0.3) * smoothstep(0.55, 0.9, r) * 0.6 * flick;
	}
	if (bh > 0.001) {
		float v = smoothstep(0.25, 0.85, r);
		col = mix(col, col * vec3(1.0, 0.65, 0.55) * (1.0 - v * 0.75), bh);
		col += bh * vec3(0.15, 0.04, 0.02) * (0.5 + 0.5 * sin(TIME * 10.0)) * v;
	}
	if (underwater > 0.001) {
		col = mix(col, col * vec3(0.4, 0.75, 0.9) + vec3(0.0, 0.05, 0.1), underwater * 0.7);
	}
	col = mix(col, flash_col.rgb, flash);
	col = mix(col, fade_col.rgb, fade);
	COLOR = vec4(col, 1.0);
}
