shader_type spatial;
uniform vec3 sink_center = vec3(1e9);
uniform float sink_r1 = 80.0;
void vertex(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wp, sink_center);
	float s = 1.0 - smoothstep(sink_r1, sink_r1 + 14.0, d);
	VERTEX -= normalize(VERTEX) * 6.0 * s;
}
void fragment(){
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
