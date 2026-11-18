shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// Planetary ring annulus (module M2), planet-space mesh in the equatorial plane. Faint C ring, bright dense B ring, a Cassini-like division, the A ring with a
// narrow gap, and faint outer wisps; ringlet noise is band-limited by the pixel footprint (fwidth) so it never aliases into moire when seen from afar or edge-on.
// Lit side: bright dust reflecting the star; unlit side: only the light that leaks through thin parts (they glow, the dense B ring is dark).
// The planet casts a soft shadow across the ring (cylinder shadow along the sun direction). Unshaded: radiance = tint * sun_color * sun_energy * light_gain
// (light_gain keeps the brightest ring near 1.0, below the environment glow threshold).

global uniform vec3 sun_dir;
global uniform vec3 sun_color;
global uniform float sun_energy;

uniform float ring_in = 50000.0;
uniform float ring_out = 80000.0;
uniform float planet_r = 36000.0;
uniform vec3 col_a = vec3(0.78, 0.68, 0.52);
uniform vec3 col_b = vec3(0.50, 0.44, 0.38);
uniform float seed = 1.0;
uniform float light_gain = 0.44;

varying vec3 v_ps;

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

// base optical depth along the ring (0..1), u = 0 at the inner edge, 1 at the outer edge. Keep in sync with gas_giant.gdshader.
float ring_profile(float u) {
	float d = 0.04;
	d += 0.20 * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.20, 0.26, u));       // C ring (faint, dusty)
	d += 0.95 * smoothstep(0.20, 0.27, u) * (1.0 - smoothstep(0.60, 0.64, u));      // B ring (dense, bright)
	d += 0.64 * smoothstep(0.69, 0.72, u) * (1.0 - smoothstep(0.93, 0.97, u));      // A ring
	d *= 1.0 - 0.9 * exp(-pow((u - 0.855) / 0.006, 2.0));                           // Encke-like gap
	d *= smoothstep(0.0, 0.02, u) * (1.0 - smoothstep(0.97, 1.0, u));
	return clamp(d, 0.0, 1.0);
}

// ringlet noise (mean ~0.5), octaves fade out when they are finer than a pixel
float ring_noise(float u, float fw) {
	float s = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	float f = 16.0;
	for (int i = 0; i < 4; i++) {
		float k = 1.0 - smoothstep(0.15, 0.6, fw * f);
		float n = vnoise(vec3(u * f, seed, float(i) * 3.1));
		s += amp * mix(0.5, n, k);
		norm += amp;
		amp *= 0.55;
		f *= 2.9;
	}
	return s / norm;
}

void vertex() {
	v_ps = VERTEX;
}

void fragment() {
	float rho = length(v_ps.xz);
	float u = (rho - ring_in) / (ring_out - ring_in);
	if (u < 0.0 || u > 1.0) {
		discard;
	}
	float fw = max(fwidth(u), 1e-5);
	float base = ring_profile(u);
	float rn = ring_noise(u, fw);
	float dens = clamp(base * (0.45 + 1.1 * rn), 0.0, 1.0);
	// the sub-pixel structure averages to the mean density
	if (dens < 0.01) {
		discard;
	}
	mat3 M = mat3(MODEL_MATRIX);
	vec3 sun_ps = normalize(sun_dir * M);
	vec3 cam_ps = (CAMERA_POSITION_WORLD - NODE_POSITION_WORLD) * M;
	// planet shadow on the ring: points behind the planet as seen from the star, inside its cylinder
	float b = dot(v_ps, sun_ps);
	float hmin = length(v_ps - sun_ps * b);
	float shadow = b < 0.0 ? smoothstep(planet_r * 0.975, planet_r * 1.035, hmin) : 1.0;
	bool lit_side = sun_ps.y * cam_ps.y > 0.0;
	float sunk = abs(sun_ps.y);
	vec3 tint = mix(col_b, col_a, clamp(0.35 + 0.8 * base * (0.6 + 0.8 * rn), 0.0, 1.0));
	tint *= 0.85 + 0.3 * ring_noise(u * 0.37 + 11.0, fw * 0.37);
	vec3 sun_c = sun_color * clamp(sun_energy, 0.0, 4.0) * light_gain;
	vec3 col;
	if (lit_side) {
		// dust reflects well even at shallow sun angles; denser = brighter
		col = tint * sun_c * (0.40 + 0.60 * smoothstep(0.0, 0.40, sunk)) * (0.70 + 0.55 * dens);
	} else {
		// seen from the unlit face: light that leaks through, thin parts glow, dense parts are dark
		col = tint * sun_c * (0.03 + 0.75 * pow(1.0 - dens, 2.2) * pow(sunk, 0.45));
	}
	col *= mix(0.025, 1.0, shadow);
	col += tint * 0.012;                                // earth-shine / starlight floor so the ring never vanishes in the planet's shadow
	ALBEDO = col;
	ALPHA = clamp(dens * (lit_side ? 0.95 : 0.85), 0.0, 1.0);
}
