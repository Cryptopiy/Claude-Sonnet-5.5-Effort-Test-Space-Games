shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// Drifting cloud shell around a planet (module M2). Sphere mesh centred on the planet (vertices are planet-space). Procedural fbm clouds, drift along
// latitude bands, cheap self-shadowing by comparing the density towards the sun, lit with the global sun colour (so sunsets turn the clouds orange),
// dark undersides when seen from below, fade-out near the camera so flying through never blocks the view.

global uniform vec3 sun_dir;
global uniform vec3 sun_color;
global uniform float sun_energy;
global uniform float night_amount;

uniform float shell_r = 10000.0;
uniform float cover : hint_range(0.0, 1.0) = 0.5;
uniform float soft = 0.22;
uniform float cloud_scale = 1.0;
uniform float speed = 1.0;
uniform float opacity = 0.9;
uniform float dark = 0.0;
uniform vec3 col_bright = vec3(1.0);
uniform vec3 col_shade = vec3(0.5, 0.58, 0.72);
uniform vec3 col_emit = vec3(0.0);
uniform vec3 amb_color = vec3(0.3, 0.35, 0.45);
uniform float fade_near = 80.0;
uniform float fade_far = 700.0;
uniform float seed = 1.0;


uint pcg_u(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash13(vec3 p3) {
	ivec3 ip = ivec3(floor(p3));
	uint h = pcg_u(uint(ip.x) + pcg_u(uint(ip.y) + pcg_u(uint(ip.z))));
	return float(h) * (1.0 / 4294967295.0);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < oct; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec3(3.1, 1.7, 5.3);
		a *= 0.5;
	}
	return s;
}

vec3 rot_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

float density(vec3 d, float t) {
	// One uniform slow drift around the spin axis (a latitude-dependent drift shears the pattern into long east-west stripes after a few minutes) while
	// the domain warp field slides through the noise at a different speed => the clouds slowly change shape instead of being rigidly translated.
	vec3 p = rot_y(d, t * 0.0012 * speed) * cloud_scale;
	vec3 q = p * 4.2 + vec3(seed * 7.0);
	float ts = t * speed;
	vec3 w = vec3(fbm(q * 0.6 + 3.0 + vec3(ts * 0.0021, 0.0, 0.0), 3), fbm(q * 0.6 + 9.0 + vec3(0.0, ts * 0.0017, 0.0), 3), fbm(q * 0.6 + 15.0 + vec3(0.0, 0.0, ts * 0.0023), 3)) - 0.5;
	float n = fbm(q + w * 1.9, 5);
	return n;
}

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	vec3 q = ro - rd * b;
	float d = r * r - dot(q, q);
	if (d < 0.0) {
		return vec2(1e30, -1e30);
	}
	float sq = sqrt(d);
	return vec2(-b - sq, -b + sq);
}

void fragment() {
	// The mesh only provides coverage: the shell sphere is intersected analytically so the pattern is independent of the tessellation.
	vec3 ro = CAMERA_POSITION_WORLD - NODE_POSITION_WORLD;
	vec3 rd = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float cam_d = length(ro);
	bool outside = cam_d > shell_r;
	vec2 ts = ray_sphere(ro, rd, shell_r);
	float th = outside ? ts.x : ts.y;
	if (th < 0.0 || th > 1e20) {
		discard;
	}
	vec3 pw = ro + rd * th;                                   // planet-relative world position on the shell
	vec3 d = normalize(pw * mat3(MODEL_MATRIX));              // planet-space direction (rotates with the planet)
	vec3 v_sun_ps = normalize(sun_dir * mat3(MODEL_MATRIX));
	vec3 v_world = NODE_POSITION_WORLD + pw;
	float n = density(d, TIME);
	float t0 = mix(0.74, 0.36, cover);
	float c = smoothstep(t0, t0 + soft, n);
	// fine erosion at the edges
	float er = fbm(d * 60.0 * cloud_scale + vec3(seed), 3);
	c *= smoothstep(0.12, 0.62, er + c * 0.55);
	if (c < 0.004) {
		discard;
	}
	// self shadow: thicker cloud towards the sun => darker
	vec3 st = v_sun_ps - d * dot(v_sun_ps, d);
	float stl = length(st);
	vec3 stn = stl > 1e-3 ? st / stl : vec3(0.0);
	float n_s = density(normalize(d + stn * 0.022), TIME);
	float thick = clamp((n_s - n) * 6.0 + 0.5, 0.0, 1.0);
	float sun_up = dot(v_sun_ps, d);                    // sun elevation over the shell (sin)
	float lit = (1.0 - thick * 0.75) * smoothstep(-0.15, 0.25, sun_up);
	vec3 sun_c = sun_color * sun_energy * 0.55;
	bool below = cam_d < shell_r;
	vec3 base = col_bright;
	vec3 col = mix(col_shade * amb_color * 1.6, base * (sun_c + amb_color * 0.9), lit);
	// silver lining when the sun is behind the cloud, seen from below
	vec3 vdir = normalize(v_world - CAMERA_POSITION_WORLD);
	float fw = pow(max(dot(vdir, normalize(sun_dir)), 0.0), 6.0);
	col += base * sun_c * fw * 0.55 * (1.0 - c * 0.5);
	if (below) {
		col *= mix(0.55, 0.9, smoothstep(0.0, 0.6, sun_up));
	}
	col = mix(col, col * vec3(0.35, 0.33, 0.33), dark);
	col += col_emit * (0.25 + 0.75 * (1.0 - lit)) * (0.4 + 0.6 * night_amount);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float fade = smoothstep(fade_near, fade_far, dist);
	ALBEDO = col;
	ALPHA = clamp(c * opacity * fade, 0.0, 1.0);
}
