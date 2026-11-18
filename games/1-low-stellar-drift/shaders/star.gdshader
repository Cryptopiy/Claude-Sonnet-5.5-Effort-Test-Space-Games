shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 col : source_color = vec3(1.0, 0.8, 0.4);
float h(vec3 p){ p = fract(p * 0.3183 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 p){ vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(h(i), h(i+vec3(1,0,0)), f.x), mix(h(i+vec3(0,1,0)), h(i+vec3(1,1,0)), f.x), f.y),
	mix(mix(h(i+vec3(0,0,1)), h(i+vec3(1,0,1)), f.x), mix(h(i+vec3(0,1,1)), h(i+vec3(1,1,1)), f.x), f.y), f.z); }
varying vec3 lp;
void vertex(){ lp = VERTEX; }
void fragment(){
	vec3 p = normalize(lp) * 3.0;
	float n = vn(p * 2.0 + TIME * 0.15) * 0.6 + vn(p * 5.0 - TIME * 0.2) * 0.4;
	float fres = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.0);
	vec3 c = mix(col * 1.3, vec3(1.0), 0.35 + 0.3 * n) * (0.8 + 0.5 * n);
	c = mix(c, col * 0.8, fres * 0.7);
	ALBEDO = c * 3.0;
}
