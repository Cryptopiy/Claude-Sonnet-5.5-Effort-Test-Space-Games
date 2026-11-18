shader_type spatial;
uniform vec3 c1 : source_color = vec3(0.8, 0.6, 0.4);
uniform vec3 c2 : source_color = vec3(0.5, 0.3, 0.2);
uniform vec3 c3 : source_color = vec3(0.9, 0.85, 0.7);
uniform float seed = 1.0;
varying vec3 lp;
float h(vec3 p){ p = fract(p * 0.3183 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 p){ vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(h(i), h(i+vec3(1,0,0)), f.x), mix(h(i+vec3(0,1,0)), h(i+vec3(1,1,0)), f.x), f.y),
	mix(mix(h(i+vec3(0,0,1)), h(i+vec3(1,0,1)), f.x), mix(h(i+vec3(0,1,1)), h(i+vec3(1,1,1)), f.x), f.y), f.z); }
void vertex(){ lp = normalize(VERTEX); }
void fragment(){
	float lat = lp.y;
	float turb = vn(vec3(lp.x * 4.0 + TIME * 0.02, lat * 3.0, lp.z * 4.0) + seed) * 0.25;
	float b = sin((lat + turb) * 18.0 + seed) * 0.5 + 0.5;
	float b2 = sin((lat + turb * 1.5) * 41.0) * 0.5 + 0.5;
	vec3 c = mix(c1, c2, b);
	c = mix(c, c3, b2 * 0.35);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
