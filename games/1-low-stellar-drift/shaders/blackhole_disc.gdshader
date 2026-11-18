shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float inner = 0.2;
uniform float outer = 3600.0;
varying vec3 lp;
void vertex(){ lp = VERTEX; }
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	vec2 p = lp.xz;
	float r = length(p) / outer;
	if (r > 1.0 || r < inner) discard;
	float a = atan(p.y, p.x);
	float rr = (r - inner) / (1.0 - inner);
	float swirl = a + 6.0 / (r + 0.1) - TIME * 1.6 / (r + 0.15);
	float n = vn(vec2(swirl * 3.0, r * 18.0)) * 0.6 + vn(vec2(swirl * 7.0, r * 40.0)) * 0.4;
	vec3 hot = vec3(1.0, 0.92, 0.75);
	vec3 cool = vec3(1.0, 0.35, 0.05);
	vec3 c = mix(hot, cool, pow(rr, 0.55));
	float fall = pow(1.0 - rr, 1.6) * smoothstep(0.0, 0.05, rr);
	float dop = 0.6 + 0.6 * sin(a - 0.8);
	ALBEDO = c * (0.4 + n * 1.4) * fall * dop * 3.2;
}
