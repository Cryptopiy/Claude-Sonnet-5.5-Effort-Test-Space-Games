shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D wave_nrm : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.55, 0.60);
uniform vec3 deep_color : source_color = vec3(0.01, 0.10, 0.26);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform vec3 sky_reflect : source_color = vec3(0.35, 0.55, 0.9);
uniform float clarity = 0.05;
uniform float wave_scale = 0.045;
uniform float wave_strength = 0.7;
uniform float roughness_w = 0.07;
uniform float emission_glow = 0.0;       // acid / lava glow
uniform float time_scale = 1.0;

instance uniform vec3 chunk_center = vec3(0.0);

varying vec3 v_plocal;
varying vec3 v_nlocal;

void vertex() {
	v_plocal = chunk_center + VERTEX;
	v_nlocal = NORMAL;
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

void fragment() {
	vec3 nl = normalize(v_nlocal);
	vec3 pl = v_plocal;
	vec3 w = tri_w(nl);
	float t = TIME * 0.6 * time_scale;
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(60.0, 500.0, dist);
	// two scrolling normal layers (planet-local tri-planar)
	vec2 off1 = vec2(t * 0.02, t * 0.013);
	vec2 off2 = vec2(-t * 0.017, t * 0.021);
	vec3 n1 = texture(wave_nrm, pl.zy * wave_scale + off1).xyz * w.x + texture(wave_nrm, pl.xz * wave_scale + off1).xyz * w.y + texture(wave_nrm, pl.xy * wave_scale + off1).xyz * w.z;
	vec3 n2 = texture(wave_nrm, pl.zy * wave_scale * 2.7 + off2).xyz * w.x + texture(wave_nrm, pl.xz * wave_scale * 2.7 + off2).xyz * w.y + texture(wave_nrm, pl.xy * wave_scale * 2.7 + off2).xyz * w.z;
	vec3 tn = normalize((n1 * 2.0 - 1.0) * 0.6 + (n2 * 2.0 - 1.0) * 0.4);
	// perturb the planet-local normal by the sampled (x,y) in an arbitrary tangent frame built from the normal
	vec3 up = nl;
	vec3 tx = normalize(cross(up, abs(up.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 ty = cross(up, tx);
	vec3 nperturb = normalize(up + (tx * tn.x + ty * tn.y) * wave_strength * fade);
	vec3 nview = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nperturb, 0.0)).xyz);
	if (!FRONT_FACING) {
		nview = -nview;
	}
	NORMAL = nview;

	// depth based colour
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_z = -vp.z / vp.w;
	float water_z = -VERTEX.z;
	float diff = max(scene_z - water_z, 0.0);
	float k = 1.0 - exp(-diff * clarity);
	vec3 col = mix(shallow_color, deep_color, k);
	float alpha = mix(0.35, 0.96, pow(k, 0.7));

	// shoreline foam
	float foam_band = 1.0 - smoothstep(0.0, 2.2, diff);
	float fn = vnoise(pl * 0.35 + vec3(0.0, t * 0.5, 0.0)) * 0.6 + vnoise(pl * 1.3 - vec3(t * 0.4, 0.0, 0.0)) * 0.4;
	float foam = foam_band * smoothstep(0.35, 0.7, fn + foam_band * 0.45) * fade;
	col = mix(col, foam_color, foam);
	alpha = max(alpha, foam * 0.9);

	// fresnel sky reflection (fake sky since the real sky is mostly stars)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = col;
	EMISSION = sky_reflect * fres * 0.9 + col * emission_glow;
	ROUGHNESS = mix(roughness_w, 0.5, foam);
	SPECULAR = 0.7;
	METALLIC = 0.0;
	ALPHA = clamp(alpha + fres * 0.3, 0.0, 1.0);
}
