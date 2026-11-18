shader_type spatial;
// Pulse-drive / boost star streaks. A MultiMesh of quads (INSTANCE_CUSTOM = 4 random numbers) arranged in a cylinder around the ship's flow axis;
// every streak slides "backwards" along the flow axis (scroll) and wraps. Lives under the Ship node (ship space), so frame shifts never disturb it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float scroll = 0.0;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float streak_len = 40.0;
uniform float width = 0.22;
uniform float px_scale = 0.0016;
uniform float radius_min = 13.0;
uniform float radius_max = 120.0;
uniform float depth = 900.0;
uniform vec3 flow_dir = vec3(0.0, 0.0, -1.0);
uniform vec3 color_a : source_color = vec3(0.35, 0.65, 1.0);
uniform vec3 color_b : source_color = vec3(1.0, 1.0, 1.0);
uniform float brightness = 1.7;

varying float v_alpha;
varying vec3 v_col;

void vertex() {
	vec4 r = INSTANCE_CUSTOM;
	vec3 T = normalize(-flow_dir);
	vec3 helper = abs(T.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 N1 = normalize(cross(helper, T));
	vec3 N2 = cross(T, N1);
	float ang = r.x * 6.2831853;
	float rad = mix(radius_min, radius_max, r.y * r.y);
	float zz = mod(r.z * depth + scroll, depth);
	float z = zz - depth * 0.8;
	vec3 P = T * z + (N1 * cos(ang) + N2 * sin(ang)) * rad;
	float len = streak_len * (0.45 + 0.9 * r.w);
	vec3 wc = (MODEL_MATRIX * vec4(P, 1.0)).xyz;
	vec3 wT = normalize((MODEL_MATRIX * vec4(T, 0.0)).xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - wc;
	float dist = length(to_cam);
	vec3 side = cross(wT, to_cam);
	float sl = length(side);
	side = sl > 1e-4 ? side / sl : vec3(1.0, 0.0, 0.0);
	float v = VERTEX.y + 0.5;
	float w = max(width, dist * px_scale) * mix(0.2, 1.0, v);
	vec3 wpos = wc + wT * (VERTEX.y * len) + side * (VERTEX.x * w);
	VERTEX = (VIEW_MATRIX * vec4(wpos, 1.0)).xyz;
	float fade_in = smoothstep(0.0, depth * 0.15, zz);
	float fade_out = 1.0 - smoothstep(depth * 0.86, depth, zz);
	float near_f = smoothstep(3.0, 20.0, dist);
	v_alpha = amount * brightness * fade_in * fade_out * near_f * pow(max(v, 0.0001), 1.5) * (0.4 + 0.6 * r.w);
	v_col = mix(color_a, color_b, r.w * r.w);
}

void fragment() {
	float e = 1.0 - abs(UV.x * 2.0 - 1.0);
	vec3 c = v_col * v_alpha * e * e;
	if (!(c.x >= 0.0 && c.y >= 0.0 && c.z >= 0.0)) { c = vec3(0.0); }
	ALBEDO = clamp(c, vec3(0.0), vec3(6.0));
	ALPHA = 1.0;
}
