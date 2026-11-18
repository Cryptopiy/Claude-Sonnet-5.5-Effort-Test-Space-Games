shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 bh_center = vec2(0.5);
uniform float bh_rs = 0.0;
uniform float bh_str = 0.0;
uniform float aspect = 1.78;
uniform float warp = 0.0;
uniform float heat = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(1.0, 0.0, 0.0);
uniform float speed_lines = 0.0;
float hh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 asp = vec2(aspect, 1.0);
	vec3 col;
	if (bh_str > 0.001 && bh_rs > 0.0) {
		vec2 d = (uv - bh_center) * asp;
		float r = length(d);
		float e = bh_rs * 2.4;
		vec2 dir = d / max(r, 1e-4);
		float beta = r - e * e / max(r, 1e-4) * 0.9;
		vec2 suv = bh_center + dir * beta / asp;
		suv = mix(uv, suv, clamp(bh_str, 0.0, 1.0));
		col = texture(screen_tex, clamp(suv, vec2(0.001), vec2(0.999))).rgb;
		float ring = exp(-pow((r - bh_rs * 1.18) / (bh_rs * 0.09), 2.0));
		col += vec3(1.0, 0.8, 0.5) * ring * 1.4 * bh_str;
		if (r < bh_rs * 1.02) col = mix(col, vec3(0.0), clamp(bh_str * 4.0, 0.0, 1.0));
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	vec2 c = (uv - 0.5) * asp;
	float rd = length(c);
	float ang = atan(c.y, c.x);
	if (warp > 0.0) {
		float st = hh(vec2(floor(ang * 90.0), floor(TIME * 24.0)));
		float streak = smoothstep(0.55, 1.0, st) * smoothstep(0.05, 0.9, rd) * warp;
		vec3 wc = mix(vec3(0.3, 0.6, 1.0), vec3(1.0, 0.85, 1.0), st);
		col = mix(col, vec3(0.02, 0.03, 0.08), clamp(warp * 0.7, 0.0, 0.95));
		col += wc * streak * 1.8;
		col += vec3(0.8, 0.9, 1.0) * smoothstep(0.9, 1.0, warp) * smoothstep(0.7, 0.0, rd);
	}
	if (speed_lines > 0.0) {
		float st = hh(vec2(floor(ang * 120.0), floor(TIME * 30.0)));
		col += vec3(0.7, 0.85, 1.0) * smoothstep(0.8, 1.0, st) * smoothstep(0.35, 0.9, rd) * speed_lines * 0.5;
	}
	if (heat > 0.0) {
		float v = smoothstep(0.25, 0.85, rd);
		float fl = 0.7 + 0.3 * sin(TIME * 30.0 + ang * 6.0);
		col += vec3(1.0, 0.45, 0.1) * v * heat * fl * 1.2;
	}
	col = mix(col, flash_col, flash * smoothstep(0.2, 0.9, rd) * 0.6);
	COLOR = vec4(col, 1.0);
}
