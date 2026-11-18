shader_type canvas_item;
render_mode blend_disabled;
// HORIZON DRIFT - hyperspace / black-hole transition overlay (module M5).
// progress 0..1 : how much the tunnel covers the scene (the scene is zoom-blurred towards the centre while it builds)
// swirl    0..1 : 0 = hyperdrive (straight radial star streaks), 1 = black hole (spiralling red/orange vortex)
// flash    0..1 : white-out / arrival flash

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float swirl = 0.0;
uniform float flash = 0.0;
uniform float streak_len = 0.5;
uniform vec3 col_a : source_color = vec3(0.75, 0.88, 1.0);   // streak colour
uniform vec3 col_b : source_color = vec3(0.10, 0.22, 0.90);  // tunnel body
uniform vec3 col_c : source_color = vec3(0.85, 0.95, 1.0);   // core glow
uniform vec3 flash_col : source_color = vec3(1.0, 1.0, 1.0);
uniform float seed = 0.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec3(11.3, 5.7, 3.1);
		a *= 0.5;
	}
	return s;
}

// radial streak layer: stars that fly outwards from the centre (or spiral out for the black-hole kind)
float streaks(float r, float ang, float cells, float speed, float layer_seed) {
	float a = ang;
	a += swirl * (1.6 * log(r + 0.03) + 0.4 * phase * 0.1);
	float u = a / 6.2831853 * cells;
	float id = floor(u);
	float f = fract(u) - 0.5;
	float h = hash11(id + layer_seed * 57.0 + seed);
	float h2 = hash11(id * 1.7 + layer_seed * 13.0 + 5.0);
	// life 0..1 of this streak
	float life = fract(h + phase * speed * (0.35 + 0.65 * h2));
	float R = pow(life, 2.3) * 1.45;                 // head position (accelerates outwards = perspective)
	float L = (0.02 + streak_len * (0.06 + 0.55 * R)) * (0.4 + h2);
	float along = (r - (R - L)) / max(L, 0.001);   // 0 tail ... 1 head
	float thick = clamp(0.0016 / (r + 0.015) * cells / 6.2831853, 0.03, 0.45);
	float across = 1.0 - smoothstep(0.0, thick, abs(f - (h2 - 0.5) * 0.5));
	float body = smoothstep(0.0, 0.85, along) * (1.0 - smoothstep(0.96, 1.0, along));
	float bright = 0.35 + 1.1 * h2;
	return across * body * bright * smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.9, 1.0, life));
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 uv = SCREEN_UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x);

	// ---- the world, zoom-blurred towards the centre ---------------------------------------------------------------------
	float reach = progress * (0.35 + 0.25 * swirl);
	vec3 scene = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float t = float(i) / 9.0;
		vec2 s = 0.5 + (uv - 0.5) * (1.0 - reach * t);
		scene += texture(screen_tex, s).rgb;
	}
	scene /= 10.0;

	// ---- tunnel walls -----------------------------------------------------------------------------------------------------
	float z = 1.0 / (r + 0.06);
	float a2 = ang + swirl * (z * 0.55) + phase * 0.12 * swirl;
	float zs = z * 0.55 - phase * (0.35 + 0.3 * (1.0 - swirl));
	vec3 np = vec3(cos(a2) * 1.7, sin(a2) * 1.7, zs);
	float n = fbm(np + vec3(0.0, 0.0, seed));
	float n2 = fbm(np * 2.3 + vec3(7.0, 3.0, -phase * 0.5));
	float body = smoothstep(0.25, 0.85, n) * 0.8 + smoothstep(0.35, 0.9, n2) * 0.5;
	vec3 tunnel = col_b * (0.10 + 1.25 * body);
	tunnel *= 0.35 + 1.15 * smoothstep(1.05, 0.05, r);
	// energy rings racing toward the viewer (hyperdrive) / spiral arms winding into the singularity (black hole): the sense of speed inside the tube
	float rf = fract(zs * 1.7);
	float ring = smoothstep(0.0, 0.05, rf) * (1.0 - smoothstep(0.05, 0.24, rf));
	float arm = pow(0.5 + 0.5 * sin(a2 * 3.0 - zs * 6.0), 5.0);
	float lanes = mix(ring, arm * 0.85, swirl) * (0.30 + 1.0 * n2);
	tunnel += mix(col_a, col_c, 0.5) * lanes * 0.85 * smoothstep(0.03, 0.30, r) * smoothstep(0.1, 0.5, progress);
	// bright vanishing point where the tunnel is far away (kept small and not clipped so the structure around it stays visible)
	float rim = exp(-r * r * 34.0);
	tunnel += col_c * rim * (0.30 + 0.55 * progress);

	// ---- star streaks (slight chromatic dispersion toward the edges) --------------------------------------------------------------------
	float disp = (0.010 + 0.020 * r) * (1.0 - 0.75 * swirl);
	vec3 st3;
	st3.r = streaks(r * (1.0 + disp), ang, 90.0, 0.55, 0.0) + streaks(r * (1.0 + disp), ang, 150.0, 0.8, 1.0) * 0.8 + streaks(r * (1.0 + disp), ang, 240.0, 1.1, 2.0) * 0.6;
	st3.g = streaks(r, ang, 90.0, 0.55, 0.0) + streaks(r, ang, 150.0, 0.8, 1.0) * 0.8 + streaks(r, ang, 240.0, 1.1, 2.0) * 0.6;
	st3.b = streaks(r * (1.0 - disp), ang, 90.0, 0.55, 0.0) + streaks(r * (1.0 - disp), ang, 150.0, 0.8, 1.0) * 0.8 + streaks(r * (1.0 - disp), ang, 240.0, 1.1, 2.0) * 0.6;
	vec3 streak_col = col_a * st3 * (1.5 + 2.5 * progress);

	float cover = smoothstep(0.28, 0.92, progress);
	vec3 outc = mix(scene, tunnel, cover);
	outc += streak_col * smoothstep(0.02, 0.45, progress);
	// dark vignette while the tunnel is closing in
	outc *= 1.0 - 0.35 * progress * smoothstep(0.35, 1.0, r * 1.3) * (1.0 - cover);
	// white-out / arrival flash
	outc = mix(outc, flash_col * (1.4 + 0.6 * rim), clamp(flash, 0.0, 1.0));
	COLOR = vec4(outc, 1.0);
}
