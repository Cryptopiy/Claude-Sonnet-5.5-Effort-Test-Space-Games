shader_type spatial;
// Atmospheric-entry plasma shell around the ship: a prolate shell (mesh +Y axis = direction of travel, UV.y 0 = nose .. 1 = tail)
// glowing white-yellow at the nose, orange/red along the flanks, with flame streaks racing backwards.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.75);
uniform vec3 mid_color : source_color = vec3(1.0, 0.52, 0.14);
uniform vec3 edge_color : source_color = vec3(0.85, 0.12, 0.03);
uniform float flow_speed = 3.2;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float ndv = abs(dot(n, normalize(VIEW)));
	float fres = pow(max(1.0 - ndv, 0.0001), 1.3);
	float v = UV.y;
	float wrap_u = abs(fract(UV.x) - 0.5) * 2.0;           // seamless around the axis
	float flame = fbm(vec2(wrap_u * 6.0, v * 2.4 - TIME * flow_speed));
	float streak = fbm(vec2(wrap_u * 17.0 + flame * 1.6, v * 0.9 - TIME * flow_speed * 1.8));
	float tongues = smoothstep(0.32, 0.78, streak * 1.15 + flame * 0.35);
	float nose = 1.0 - smoothstep(0.0, 0.45, v);
	float a = heat * (fres * 0.85 + tongues * (0.30 + 0.7 * fres)) * (0.22 + 0.95 * nose + 0.3 * (1.0 - v));
	a *= 1.0 - smoothstep(0.78, 1.0, v);                     // fade out at the tail end
	vec3 col = mix(edge_color, mid_color, smoothstep(0.0, 0.45, a));
	col = mix(col, core_color, smoothstep(0.4, 1.0, a) * (0.35 + 0.65 * nose));
	ALBEDO = col * (1.0 + 2.2 * nose * heat);
	ALPHA = clamp(a, 0.0, 0.9);
}
