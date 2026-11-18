shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Space dust / speed streaks. Lattice lives in universe coordinates (origin offset passed in), so floating-origin
// rebases never make it jump.

uniform vec3 origin_mod = vec3(0.0);   // universe origin modulo L
uniform vec3 vel = vec3(0.0);          // velocity (m/s) in the render frame
uniform float L = 240.0;
uniform float intensity = 1.0;

varying float v_alpha;

float h11(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 base = vec3(h11(id + 1.0), h11(id + 2.0), h11(id + 3.0)) * L;
	vec3 cam_u = origin_mod + (INV_VIEW_MATRIX[3].xyz);
	vec3 rel = mod(base - cam_u + L * 0.5, vec3(L)) - L * 0.5;
	vec3 world = INV_VIEW_MATRIX[3].xyz + rel;
	float sp = length(vel);
	vec3 dir = sp > 0.5 ? vel / sp : vec3(0.0, 0.0, -1.0);
	float len = clamp(sp * 0.02, 0.25, 90.0);
	// stretch the quad along the velocity direction, face the camera across the other axis
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - world);
	vec3 side = normalize(cross(dir, to_cam) + vec3(0.00001));
	vec3 p = world + side * VERTEX.x * 0.06 + dir * VERTEX.y * len;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	float d = length(rel);
	v_alpha = (1.0 - smoothstep(L * 0.25, L * 0.5, d)) * smoothstep(3.0, 14.0, d) * clamp(0.2 + sp * 0.002, 0.2, 1.0);
}

void fragment() {
	ALBEDO = vec3(0.7, 0.85, 1.0) * intensity;
	ALPHA = v_alpha * (1.0 - abs(UV.x * 2.0 - 1.0));
}
