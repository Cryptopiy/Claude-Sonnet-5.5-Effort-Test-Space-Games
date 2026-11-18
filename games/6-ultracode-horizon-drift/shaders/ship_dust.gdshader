shader_type spatial;
// Space dust: motes that are STATIC in the world (they wrap around the ship inside a cube), so you can feel speed and direction even in empty space.
// Each mote is drawn as a short streak along the (relative) velocity.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform vec3 field_origin = vec3(0.0);   // (ship position - world anchor) wrapped to [0, cell), world axes
uniform float cell = 150.0;
uniform vec3 vel_dir = vec3(0.0, 0.0, -1.0);   // world-space direction of travel
uniform float streak_len = 1.0;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float size = 0.09;
uniform float px_scale = 0.0011;
uniform vec3 color : source_color = vec3(0.75, 0.85, 1.0);

varying float v_alpha;

void vertex() {
	vec4 r = INSTANCE_CUSTOM;
	vec3 b = r.xyz;
	vec3 rel = (fract(b - field_origin / cell) - 0.5) * cell;
	vec3 wc = MODEL_MATRIX[3].xyz + rel;
	vec3 wT = normalize(-vel_dir);
	vec3 to_cam = CAMERA_POSITION_WORLD - wc;
	float dist = length(to_cam);
	vec3 side = cross(wT, to_cam);
	float sl = length(side);
	side = sl > 1e-4 ? side / sl : vec3(1.0, 0.0, 0.0);
	float v = VERTEX.y + 0.5;
	float w = max(size, dist * px_scale) * mix(0.35, 1.0, v);
	float len = streak_len * (0.5 + r.w) + w * 2.0;
	vec3 wpos = wc + wT * (VERTEX.y * len) + side * (VERTEX.x * w);
	VERTEX = (VIEW_MATRIX * vec4(wpos, 1.0)).xyz;
	float edge = 1.0 - smoothstep(0.30, 0.5, max(abs(rel.x), max(abs(rel.y), abs(rel.z))) / cell);
	float near_f = smoothstep(2.5, 14.0, dist);
	v_alpha = amount * edge * near_f * (0.35 + 0.65 * r.w) * mix(0.45, 1.0, v);
}

void fragment() {
	float e = 1.0 - abs(UV.x * 2.0 - 1.0);
	vec3 c = color * v_alpha * e;
	if (!(c.x >= 0.0 && c.y >= 0.0 && c.z >= 0.0)) { c = vec3(0.0); }   // NaN / negative guard (additive blend must never subtract)
	ALBEDO = clamp(c, vec3(0.0), vec3(4.0));
	ALPHA = 1.0;
}
