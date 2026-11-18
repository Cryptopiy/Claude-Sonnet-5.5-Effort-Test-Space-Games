shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, skip_vertex_transform, fog_disabled;
// Corona + rays of the star (module M2): additive camera-facing billboard, child of the star node (so it inherits the uniform scale Frame applies).
// The quad spans +-corona_scale star radii; the star sphere (opaque, in front) hides the centre, planets in front hide it by depth testing.
// Layers (x = distance from the limb in star radii): a hot thin chromosphere rim, a bright inner corona, a mid glow, a wide soft halo, and
// streamers (three octaves of periodic angular noise, each with its own length, slowly drifting). Everything is HDR so the environment glow blooms it.

uniform vec3 star_col = vec3(1.0, 0.9, 0.62);
uniform float corona_scale = 6.0;     // quad half-size in star radii
uniform float intensity = 1.0;
uniform float seed = 1.0;
uniform float star_radius_hint = 1.0;   // star radius in node-local units (metres before Frame's scale)

varying vec2 v_uv;

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

void vertex() {
	v_uv = VERTEX.xy * 2.0;           // quad is 1x1 centred: -> [-1, 1]
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 centre_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = centre_view + vec3(VERTEX.xy * 2.0 * corona_scale * sc * star_radius_hint, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 u = v_uv;
	float rq = length(u);
	float r = rq * corona_scale;              // in star radii
	if (r > corona_scale) {
		discard;
	}
	vec2 pa = u / max(rq, 1e-5);              // unit direction: periodic noise domain (no seam)
	float t = TIME * 0.025;
	float x = max(r - 1.0, 0.0);
	// hot thin rim hugging the limb, bright inner corona, mid glow, wide soft halo
	float rim = exp(-x * 26.0) * smoothstep(0.96, 1.0, r);
	float inner = exp(-x * 4.2) * smoothstep(0.96, 1.02, r);
	float mid = exp(-x * 1.15) * smoothstep(0.94, 1.1, r);
	float halo = 1.0 / (1.0 + x * x * 2.4) * smoothstep(0.94, 1.1, r);
	// streamers: three octaves of angular noise, thin and of different lengths
	float n1 = vnoise(vec3(pa * 3.6, seed + t));
	float n2 = vnoise(vec3(pa * 9.0, seed * 2.0 - t * 1.3));
	float n3 = vnoise(vec3(pa * 23.0, seed * 5.0 + t * 0.7));
	float rays = n1 * 0.45 + n2 * 0.35 + n3 * 0.20;
	rays = pow(clamp(rays * 1.45 - 0.16, 0.0, 1.0), 2.4);
	float reach = 0.30 + 1.25 * n1;                                   // each streamer has its own length
	float ray_f = rays * exp(-x / reach) * smoothstep(1.0, 1.15, r);
	float edge = 1.0 - smoothstep(corona_scale * 0.40, corona_scale * 0.98, r);
	vec3 warm = vec3(1.0, 0.55, 0.30);
	vec3 white = mix(star_col, vec3(1.0), 0.40);
	vec3 col = vec3(0.0);
	col += vec3(1.0, 0.50, 0.36) * rim * 1.3;                       // chromosphere-like hot edge (pinkish orange)
	col += white * inner * 0.85;
	col += mix(white, warm, clamp(x * 0.30, 0.0, 1.0)) * (mid * 0.20 + halo * 0.10);
	col += mix(white, warm, clamp(x * 0.22, 0.0, 1.0)) * ray_f * 1.05;
	ALBEDO = col * edge * intensity;
	ALPHA = 1.0;
}
