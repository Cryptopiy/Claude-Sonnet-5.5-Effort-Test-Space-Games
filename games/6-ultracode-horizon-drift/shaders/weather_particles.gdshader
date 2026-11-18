shader_type spatial;
// WEATHER PARTICLES (module m7b_life).  One MultiMesh of camera-facing streak quads, fully animated in the vertex shader:
//  * every drop is a WORLD-FIXED point of a periodic lattice (box_size) that is wrapped around the camera -> infinite weather, zero spawn cost, no frame-shift problems
//  * orientation/length of each quad follows the velocity RELATIVE to the camera (rain streaks lengthen when you fly fast, snow hangs when you stand still)
//  * the MultiMesh stores per-instance randoms: INSTANCE_CUSTOM = (x, y, z, visibility threshold), COLOR = (size jitter, colour mix, phase, speed jitter)
// BLEND_MODE marker below is replaced from script (blend_mix / blend_add).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, skip_vertex_transform, fog_disabled; // BLEND_MODE

uniform vec3 box_size = vec3(60.0, 40.0, 60.0);       // weather-space lattice period (x = east, y = up, z = north)
uniform mat3 axes = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0)); // columns: east, up, north (world)
uniform vec3 velocity = vec3(0.0, -10.0, 0.0);        // particle velocity in weather space (m/s)
uniform vec3 cam_vel = vec3(0.0);                     // camera velocity, world space (m/s)
uniform float flutter = 0.0;                          // metres of lazy wobble
uniform float flutter_freq = 1.5;
uniform float intensity = 1.0;                        // fraction of the instances that are visible
uniform float size = 0.02;                            // base width (m)
uniform float streak_time = 0.03;                     // seconds of motion drawn as a streak
uniform float max_len = 6.0;
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(1.0);
uniform float glow = 0.0;                             // > 0 : self-lit (HDR multiplier); 0 : lit by `light`
uniform float light = 1.0;                            // sun/ambient scale for non-glowing layers
uniform float soft = 1.0;
uniform float near_fade_a = 1.5;
uniform float near_fade_b = 4.5;
uniform float pixel_angle = 0.0013;                   // minimum on-screen width (radians) so far streaks never alias away
uniform float twinkle = 0.0;                          // glow pulsing amount (spores / motes)

varying vec4 v_col;
varying vec2 v_uv;
varying float v_head;

void vertex() {
	vec4 rnd = INSTANCE_CUSTOM;
	vec4 rn2 = COLOR;
	if (rnd.w > intensity) {
		VERTEX = vec3(0.0, 0.0, 1000.0);
		v_col = vec4(0.0);
		v_uv = vec2(0.5);
		v_head = 0.0;
	} else {
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		vec3 cw = cam * axes;                               // camera in weather space
		float spd = 0.8 + 0.4 * rn2.w;
		vec3 p = rnd.xyz * box_size + velocity * (TIME * spd);
		float ph = rn2.z * 40.0;
		p += vec3(sin(TIME * flutter_freq + ph), sin(TIME * flutter_freq * 0.77 + ph * 0.7) * 0.6, cos(TIME * flutter_freq * 1.13 + ph * 1.3)) * flutter;
		vec3 rel = p - cw;
		rel = (fract(rel / box_size + 0.5) - 0.5) * box_size;  // wrapped into [-box/2, box/2) around the camera
		vec3 pv = mat3(VIEW_MATRIX) * (axes * rel);           // view-space centre of the particle
		float dist = length(pv);
		vec3 vv = mat3(VIEW_MATRIX) * (axes * velocity * spd - cam_vel);
		float sp = length(vv);
		vec3 dir = sp > 0.001 ? vv / sp : vec3(0.0, -1.0, 0.0);
		vec3 side = cross(dir, pv / max(dist, 0.001));
		float sl = length(side);
		side = sl > 0.05 ? side / sl : vec3(1.0, 0.0, 0.0);
		float w0 = size * (0.7 + 0.6 * rn2.x);
		float w = max(w0, dist * pixel_angle);
		float len = clamp(sp * streak_time, 0.0, max_len);
		len = max(len, w);
		float t = VERTEX.y + 0.5;                            // 0 tail .. 1 head
		VERTEX = pv + dir * ((t - 0.5) * len) + side * (VERTEX.x * w);
		vec3 q = abs(rel) / (0.5 * box_size);
		float edge = 1.0 - smoothstep(0.7, 1.0, max(max(q.x, q.y), q.z));
		float nf = smoothstep(near_fade_a, near_fade_b, dist);
		vec4 c = mix(color_a, color_b, rn2.y);
		float tw = 1.0 - twinkle * (0.5 + 0.5 * sin(TIME * (1.5 + 2.0 * rn2.x) + ph));
		c.a *= edge * nf * (w0 / w) * tw;
		v_col = c;
		v_uv = UV;
		v_head = t;
	}
}

void fragment() {
	vec2 c = v_uv * 2.0 - 1.0;
	float shape = clamp(1.0 - dot(c, c), 0.0, 1.0);
	shape = pow(shape, soft);
	float headfade = mix(0.4, 1.0, v_head);
	ALPHA = clamp(v_col.a * shape * headfade, 0.0, 1.0);
	ALBEDO = v_col.rgb * (glow > 0.0 ? glow : light);
}
