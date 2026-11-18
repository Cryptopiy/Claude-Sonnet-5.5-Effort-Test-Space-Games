shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Camera-facing glow quad centred on the star: soft corona, streaks and a wide halo.

uniform vec3 glow_col : source_color = vec3(1.0, 0.85, 0.6);
uniform float intensity = 1.0;
uniform float core = 0.17;     // star disc radius as a fraction of the quad half-size
uniform float spikes = 0.55;
uniform float global_fade = 1.0;

void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	if (r > 1.0) {
		discard;
	}
	float rr = max(r - core, 0.0) / (1.0 - core);
	float halo = 1.0 / (1.0 + rr * rr * 60.0);
	float wide = exp(-r * 3.2) * 0.35;
	float ang = atan(uv.y, uv.x);
	float rays = pow(abs(cos(ang * 3.0 + TIME * 0.02)), 24.0) * 0.5 + pow(abs(cos(ang * 5.0 - TIME * 0.015 + 1.0)), 40.0) * 0.4;
	rays *= exp(-rr * 4.0) * spikes;
	float edge = smoothstep(1.0, 0.7, r);
	vec3 c = glow_col * (halo * 1.2 + wide + rays) * edge;
	ALBEDO = c * intensity * global_fade;
}
