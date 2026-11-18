shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Space dust / speed streaks. A MultiMesh of thin quads is wrapped inside a box around the camera so that the
// viewer's motion (uniform `offset`) is visible even though in the system frame the ship never moves.
uniform vec3 offset = vec3(0.0);        // viewer position (any frame), wrapped by the script
uniform vec3 velocity = vec3(0.0);      // viewer velocity, same axes
uniform float box = 160.0;
uniform float intensity = 1.0;
uniform vec3 tint : source_color = vec3(0.7, 0.85, 1.0);

varying float v_a;

float h11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 base = vec3(h11(id * 1.37 + 1.0), h11(id * 2.11 + 7.0), h11(id * 3.73 + 13.0)) * box;
	vec3 p = mod(base - offset, vec3(box)) - vec3(box * 0.5);
	// world axes -> view: p is relative to the camera position
	float speed = length(velocity);
	vec3 vdir = speed > 0.01 ? velocity / speed : vec3(0.0, 0.0, -1.0);
	float streak = clamp(speed * 0.012, 0.03, 14.0);
	// mesh: quad in XY, VERTEX.y in [-0.5,0.5]  -> along-motion extent, VERTEX.x -> width
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam_pos + p;
	vec3 to_cam = normalize(cam_pos - wp);
	vec3 side = normalize(cross(vdir, to_cam));
	float dist = length(p);
	float width = 0.012 * (1.0 + dist * 0.02);
	vec3 pos = wp + vdir * (VERTEX.y * streak * 2.0) + side * VERTEX.x * width * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	float fade_edge = 1.0 - smoothstep(box * 0.30, box * 0.5, length(p));
	float near_fade = smoothstep(2.0, 12.0, dist);
	v_a = fade_edge * near_fade * (0.35 + 0.65 * h11(id * 5.91)) * clamp(speed * 0.02, 0.0, 1.0);
}

void fragment() {
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = tint * v_a * intensity * edge * 1.8;
}
