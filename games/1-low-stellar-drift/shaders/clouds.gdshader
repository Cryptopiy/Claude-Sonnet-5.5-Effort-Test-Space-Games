shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float cover = 0.5;
varying vec3 lp;
varying float vdepth;
float h(vec3 p){ p = fract(p * 0.3183 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 p){ vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(h(i), h(i+vec3(1,0,0)), f.x), mix(h(i+vec3(0,1,0)), h(i+vec3(1,1,0)), f.x), f.y),
	mix(mix(h(i+vec3(0,0,1)), h(i+vec3(1,0,1)), f.x), mix(h(i+vec3(0,1,1)), h(i+vec3(1,1,1)), f.x), f.y), f.z); }
void vertex(){ lp = normalize(VERTEX); vdepth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment(){
	vec3 p = lp * 6.0 + vec3(TIME * 0.01);
	float n = vn(p) * 0.5 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.2;
	float a = smoothstep(1.0 - cover, 1.0 - cover + 0.15, n);
	vec3 wn = normalize((MODEL_MATRIX * vec4(lp, 0.0)).xyz);
	float lit = clamp(dot(wn, sun_dir) * 1.2 + 0.25, 0.04, 1.0);
	ALBEDO = tint * lit;
	ALPHA = a * 0.9 * smoothstep(15.0, 120.0, vdepth);
}
