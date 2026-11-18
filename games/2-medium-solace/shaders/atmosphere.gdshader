shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, fog_disabled;

uniform vec3 atmo_color : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float intensity = 1.0;
uniform float fade = 1.0;

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float sd = dot(wn, normalize(sun_dir));
	float day = smoothstep(-0.35, 0.45, sd);
	float rim = smoothstep(0.0, 0.3, ndv) * pow(1.0 - ndv, 1.8);
	float a = rim * (0.1 + 0.9 * day) * intensity * fade;
	ALBEDO = mix(atmo_color, vec3(1.0, 0.55, 0.3), (1.0 - smoothstep(0.0, 0.4, sd)) * 0.45 * day);
	ALPHA = clamp(a * 1.6, 0.0, 1.0);
}
