shader_type canvas_item;

// Full-screen post effects drawn over the 3D view (below the HUD):
// atmospheric heat, damage flash, black-hole distortion, hyperdrive warp tunnel, fades, underwater tint.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float heat = 0.0;
uniform float damage = 0.0;
uniform float bh = 0.0;                 // 0..1 black hole proximity effect
uniform float bh_swirl = 0.0;
uniform float warp = 0.0;               // 0..1 hyperdrive tunnel
uniform float fade = 0.0;               // 0 = clear, 1 = black
uniform float flash = 0.0;              // white flash
uniform float under = 0.0;              // underwater amount
uniform vec3 under_color : source_color = vec3(0.05, 0.28, 0.4);
uniform float aberration = 0.0;
uniform float speed_lines = 0.0;        // 0..1 pulse-drive radial blur

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float r = length(c);
	vec2 dir = r > 0.0001 ? c / r : vec2(0.0);
	vec2 duv = uv;
	// heat shimmer
	if (heat > 0.001) {
		duv += vec2(sin(uv.y * 60.0 + TIME * 9.0), cos(uv.x * 50.0 + TIME * 7.0)) * 0.0025 * heat * smoothstep(0.1, 0.7, r + 0.2);
	}
	// black hole: pull the image towards the centre + swirl
	if (bh > 0.001) {
		float k = bh * (0.04 + 0.12 * smoothstep(0.0, 0.7, r));
		float ang = bh_swirl * bh * 0.5 * smoothstep(0.7, 0.0, r);
		float cs = cos(ang);
		float sn = sin(ang);
		vec2 cc = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs);
		duv = vec2(0.5) + cc * (1.0 - k);
	}
	// warp tunnel: radial stretch
	float wk = max(warp, speed_lines * 0.5);
	vec3 col;
	if (wk > 0.001) {
		vec3 acc = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 14; i++) {
			float t = float(i) / 13.0;
			vec2 suv = vec2(0.5) + c * (1.0 - t * 0.34 * wk);
			float w = 1.0 - t * 0.7;
			acc += texture(screen_tex, suv).rgb * w;
			total += w;
		}
		col = acc / total;
		float streak = pow(hash(floor(dir * 90.0 + vec2(floor(TIME * 24.0) * 0.3))), 6.0);
		col += vec3(0.55, 0.75, 1.0) * streak * smoothstep(0.08, 0.55, r) * warp * 1.8;
		col = mix(col, vec3(0.55, 0.78, 1.0) * (0.35 + 0.65 * smoothstep(0.0, 0.7, r)), warp * 0.55);
	} else {
		float ab = aberration + bh * 0.012;
		if (ab > 0.0005) {
			float rr = texture(screen_tex, duv + dir * ab * (0.4 + r)).r;
			float gg = texture(screen_tex, duv).g;
			float bb = texture(screen_tex, duv - dir * ab * (0.4 + r)).b;
			col = vec3(rr, gg, bb);
		} else {
			col = texture(screen_tex, duv).rgb;
		}
	}
	// heat vignette
	if (heat > 0.001) {
		float v = smoothstep(0.25, 0.85, r) * heat;
		col = mix(col, vec3(1.0, 0.45, 0.12) * 1.3, v * 0.55);
		col += vec3(1.0, 0.4, 0.1) * v * 0.25;
	}
	// damage flash
	if (damage > 0.001) {
		col = mix(col, vec3(1.0, 0.1, 0.05), damage * (0.25 + 0.5 * smoothstep(0.2, 0.9, r)));
	}
	// black hole darkening / reddening
	if (bh > 0.001) {
		float v2 = smoothstep(0.15, 0.8, r);
		col *= 1.0 - bh * 0.55 * v2;
		col = mix(col, col * vec3(1.15, 0.8, 0.7), bh * 0.5);
	}
	// underwater
	if (under > 0.001) {
		float d = clamp(0.35 + r, 0.0, 1.0);
		col = mix(col, under_color * (0.55 + 0.45 * (1.0 - r)), under * 0.62);
		col *= 1.0 - under * 0.25 * smoothstep(0.3, 0.9, r);
	}
	col = mix(col, vec3(1.0), flash);
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
