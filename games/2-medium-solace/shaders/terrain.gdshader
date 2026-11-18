shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec3 emit_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float emit_strength = 3.0;
instance uniform vec3 tile_origin = vec3(0.0);
varying vec3 lpos;
varying vec3 lnrm;

vec3 tri(vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(detail, p.yz * s).rgb * w.x + texture(detail, p.xz * s).rgb * w.y + texture(detail, p.xy * s).rgb * w.z;
}

void vertex() {
	lpos = VERTEX + tile_origin;
	lnrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(lnrm);
	float d1 = tri(lpos, n, 0.045).r;
	float d2 = tri(lpos, n, 0.45).r;
	float d3 = tri(lpos, n, 2.2).r;
	float k = (0.45 + 0.8 * d1) * (0.8 + 0.4 * d2) * (0.9 + 0.2 * d3);
	ALBEDO = COLOR.rgb * k;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
	float lava = 1.0 - COLOR.a;
	EMISSION = emit_color * lava * emit_strength * (0.55 + 0.9 * d2);
}
