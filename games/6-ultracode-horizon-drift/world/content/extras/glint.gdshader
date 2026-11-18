shader_type spatial;
// Distant-object beacon (module m7b_life): a camera-facing soft glow whose on-screen size never drops below `min_angle`, so stations, freighters and satellites are
// noticeable as bright moving points long before their real geometry is more than a pixel.  Fades out when the real object is close.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform, fog_disabled;

uniform vec4 color : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform float world_size = 300.0;     // physical size of the object (m): the glint fades in beyond 3x .. 12x this distance
uniform float min_angle = 0.006;      // angular size of the glint (rad)
uniform float strength = 1.0;
uniform float blink = 0.0;            // 0 = steady, 1 = full on/off blinking
uniform float blink_rate = 1.0;
uniform float fade_near = 1.0;        // scales the fade-in distances (3x / 12x world_size)

varying float v_a;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(c);
	float sz = d * min_angle;
	VERTEX = c + vec3(VERTEX.xy * sz, 0.0);
	float bl = mix(1.0, step(0.5, fract(TIME * blink_rate + c.x * 0.001)), blink);
	v_a = strength * bl * smoothstep(world_size * 3.0 * fade_near, world_size * 12.0 * fade_near, d);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float core = pow(clamp(1.0 - r, 0.0, 1.0), 4.0);
	float halo = pow(clamp(1.0 - r, 0.0, 1.0), 1.6) * 0.25;
	ALBEDO = color.rgb;
	ALPHA = clamp((core + halo) * v_a, 0.0, 1.0);
}
