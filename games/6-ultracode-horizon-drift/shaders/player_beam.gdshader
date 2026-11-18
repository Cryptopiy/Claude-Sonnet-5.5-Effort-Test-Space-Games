shader_type spatial;
// Mining beam (module M4): a camera-facing additive energy RIBBON with a bright core, soft glow, travelling pulses and a gentle wobble.
// (A shaded cylinder turns invisible in first person because the camera looks almost straight down the beam; a ribbon that always
//  turns its face to the camera keeps the full width from every angle.)
// The mesh is a unit strip (x -0.5..0.5, y -0.5..0.5, many segments along y) at a node with an identity basis placed at the beam's midpoint;
// +Y runs from the muzzle (v_t = 0) to the target (v_t = 1) along `beam_dir`.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.20, 0.85, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.9, 1.0, 1.0, 1.0);
uniform vec3 beam_dir = vec3(0.0, 0.0, -1.0);   // world-space unit vector muzzle -> target
uniform float beam_width = 0.08;                  // metres, full width at the target end
uniform float intensity = 2.6;
uniform float beam_length = 10.0;
uniform float pulse_speed = 22.0;
uniform float tip_fade = 0.0;        // 0 = solid to the end (target hit), 1 = fades out toward the tip (aiming at nothing)
uniform float wobble = 0.35;
uniform float flicker = 0.0;

varying float v_t;
varying float v_s;

void vertex() {
	v_t = VERTEX.y + 0.5;
	v_s = VERTEX.x * 2.0;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 p = center + beam_dir * (VERTEX.y * beam_length);
	vec3 to_cam = CAMERA_POSITION_WORLD - p;
	vec3 side = cross(beam_dir, to_cam);
	float sl = length(side);
	if (sl > 1e-5) {
		side /= sl;
	} else {
		side = normalize(cross(beam_dir, vec3(0.0, 1.0, 0.0001)));
	}
	float w = sin(v_t * beam_length * 2.4 - TIME * 31.0) * 0.5 + sin(v_t * beam_length * 5.3 + TIME * 17.0) * 0.5;
	float taper = mix(0.5, 1.0, smoothstep(0.0, 0.14, v_t));
	float width = beam_width * taper * (1.0 + wobble * 0.30 * w);
	VERTEX = (p - center) + side * (v_s * 0.5 * width);
}

void fragment() {
	float a = abs(v_s);
	float core = exp(-a * a * 16.0);
	float glow = exp(-a * a * 3.2);
	float flow = 0.62 + 0.38 * sin(v_t * beam_length * 2.2 - TIME * pulse_speed);
	float flow2 = 0.80 + 0.20 * sin(v_t * beam_length * 7.0 - TIME * pulse_speed * 1.9 + 1.3);
	float fade = 1.0 - tip_fade * smoothstep(0.25, 1.0, v_t);
	float start = smoothstep(0.0, 0.015, v_t);
	float flick = 1.0 + flicker * (sin(TIME * 90.0) * 0.5 + 0.5);
	vec3 col = beam_color.rgb * glow * 0.75 * flow + core_color.rgb * core * flow2 * 1.25;
	ALBEDO = col * intensity * fade * start * flick;
	ALPHA = 1.0;
}
