shader_type canvas_item;
// Full-screen post effects: speed streaks, re-entry heat, black-hole distortion, hyperspace tunnel, flashes.

uniform float speed = 0.0;
uniform float heat = 0.0;
uniform float bh = 0.0;
uniform float warp = 0.0;
uniform float flash = 0.0;
uniform float damage = 0.0;
uniform vec2 bh_pos = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
	float r = length(c);
	float ang = atan(c.y, c.x);
	vec2 duv = uv;
	// black hole: pull the image toward the singularity and split colours
	vec3 col;
	if (bh > 0.001) {
		vec2 dir = (bh_pos - uv);
		float dl = length(dir * vec2(aspect, 1.0));
		float k = bh * 0.06 / (0.15 + dl);
		duv = uv + dir * k;
		float ca = bh * 0.012;
		col = vec3(textureLod(screen_tex, duv + dir * ca, 0.0).r, textureLod(screen_tex, duv, 0.0).g, textureLod(screen_tex, duv - dir * ca, 0.0).b);
		col *= 1.0 - bh * 0.35 * smoothstep(0.2, 0.9, r * 1.4);
		col = mix(col, col * vec3(1.25, 0.8, 0.7), bh * 0.5);
	} else {
		col = textureLod(screen_tex, uv, 0.0).rgb;
	}
	// speed streaks (radial, thin, dashed, moving outward)
	if (speed > 0.01) {
		float n = 170.0;
		float a = ang / 6.2831853 * n;
		float id = floor(a);
		float f = fract(a) - 0.5;
		float rnd = hash(id);
		float rnd2 = hash(id + 91.7);
		float halfw = 0.05 + 0.07 * rnd2;
		float line = smoothstep(halfw, halfw * 0.25, abs(f));
		float dash = 0.5 + 0.5 * sin(r * (28.0 + 30.0 * rnd) - TIME * (10.0 + 14.0 * rnd) + rnd * 40.0);
		dash = smoothstep(0.35, 0.9, dash);
		float zone = smoothstep(0.12 + (1.0 - speed) * 0.35, 0.95, r) * step(0.35 - speed * 0.3, rnd);
		float streak = line * dash * zone * (0.5 + 0.8 * rnd2);
		col += vec3(0.6, 0.78, 1.0) * streak * speed * 1.2;
		col = mix(col, col * (1.0 - 0.4 * smoothstep(0.3, 1.0, r)), speed);
	}
	// re-entry heat vignette
	if (heat > 0.01) {
		float v = smoothstep(0.25, 1.0, r * 1.25);
		float flick = 0.8 + 0.2 * sin(TIME * 40.0 + ang * 6.0) * hash(floor(TIME * 20.0));
		col += vec3(1.0, 0.4, 0.08) * v * heat * 1.0 * flick;
		col = mix(col, col * vec3(1.15, 0.9, 0.8), heat * 0.4);
	}
	// hyperspace tunnel
	if (warp > 0.001) {
		float w = smoothstep(0.0, 1.0, warp);
		float tun = 0.0;
		float z = 1.0 / (r + 0.05) + TIME * 3.0 * (0.5 + w * 2.5);
		float spokes = 0.5 + 0.5 * sin(ang * 14.0 + z * 0.6 + sin(z) * 0.5);
		float rings = 0.5 + 0.5 * sin(z * 6.0);
		tun = spokes * rings;
		vec3 tcol = mix(vec3(0.05, 0.2, 0.9), vec3(0.8, 0.9, 1.0), tun * tun) * (0.4 + 1.6 * tun);
		tcol *= smoothstep(0.0, 0.25, r) * 1.4;
		col = mix(col, tcol, clamp(w * 1.3, 0.0, 0.92));
		col += vec3(1.0, 1.0, 1.0) * exp(-r * 9.0) * w * 1.5;
	}
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
	col = mix(col, vec3(1.0, 0.1, 0.05), damage * 0.45 * smoothstep(0.2, 1.0, r * 1.3));
	COLOR = vec4(col, 1.0);
}
