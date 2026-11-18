shader_type spatial;
render_mode cull_back;

#include "res://shaders/common.gdshaderinc"

// Planet terrain: vertex colour = biome albedo (linear), COLOR.a = emission mask (lava / glowing veins),
// UV.x = sheen/wet mask, UV.y = vegetation mask. Detail is added with triplanar procedural normal maps.

uniform sampler2D detail_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_h : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness_base = 0.92;
uniform float sheen_rough = 0.22;
uniform float detail_scale = 0.42;
uniform float detail_strength = 1.0;
uniform vec3 emis_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float emis_strength = 0.0;
uniform float emis_flow = 1.0;
uniform float ground_spec = 0.35;
uniform float veg_blades = 0.0;

instance uniform vec3 chunk_center = vec3(0.0);

varying vec3 v_plocal;
varying vec3 v_nlocal;

void vertex() {
	v_plocal = chunk_center + VERTEX;
	v_nlocal = NORMAL;
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(5.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

vec3 tri_normal(sampler2D tex, vec3 p, vec3 n, vec3 w, float sc) {
	vec3 tx = texture(tex, p.zy * sc).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, p.xz * sc).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, p.xy * sc).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

float tri_h(sampler2D tex, vec3 p, vec3 w, float sc) {
	return texture(tex, p.zy * sc).r * w.x + texture(tex, p.xz * sc).r * w.y + texture(tex, p.xy * sc).r * w.z;
}

void fragment() {
	vec3 nl = normalize(v_nlocal);
	vec3 pl = v_plocal;
	float dist = length(VERTEX);
	vec3 w = tri_weights(nl);
	float fade = 1.0 - smoothstep(120.0, 420.0, dist);
	float fade2 = 1.0 - smoothstep(25.0, 90.0, dist);

	vec3 base = COLOR.rgb;
	float hv = tri_h(detail_h, pl, w, detail_scale * 0.35);
	float hv2 = tri_h(detail_h, pl, w, detail_scale * 2.7);
	float var_ = (hv - 0.5) * 0.75 + (hv2 - 0.5) * 0.5 * fade;
	vec3 albedo = base * (1.0 + var_ * detail_strength);

	vec3 n_det = nl;
	if (fade > 0.01) {
		vec3 nA = tri_normal(detail_nrm, pl, nl, w, detail_scale * 0.35);
		vec3 nB = tri_normal(detail_nrm, pl, nl, w, detail_scale * 2.7);
		vec3 nn = normalize(mix(nl, nA, 0.95 * fade * detail_strength));
		nn = normalize(mix(nn, nB, 0.9 * fade2 * detail_strength));
		n_det = nn;
	}
	float sheen = UV.x;
	float veg = UV.y;
	// patchiness: broad light/dark patches and finer clumps break up the flat vertex-colour ground
	float far_f = 1.0 - smoothstep(1500.0, 9000.0, dist);
	float mid_f = 1.0 - smoothstep(250.0, 1400.0, dist);
	if (far_f > 0.01) {
		float q1 = fbm3_lo(pl * 0.028 + 3.0);
		float patch_b = 0.84 + 0.30 * smoothstep(0.25, 0.65, q1);
		float clump = 1.0;
		if (mid_f > 0.01) {
			float q2 = fbm3_lo(pl * 0.33 + 9.0);
			clump = mix(1.0, 0.86 + 0.28 * q2 / 0.875, mid_f);
		}
		float pb = mix(1.0, patch_b * clump, far_f * 0.85 * detail_strength);
		albedo *= pb;
		if (veg_blades > 0.0) {
			float vm = clamp(veg * 1.8, 0.0, 1.0);
			vec3 hue_t = mix(vec3(0.78, 0.98, 0.72), vec3(1.14, 1.02, 0.80), smoothstep(0.30, 0.62, fbm3_lo(pl * 0.021 + 41.0)));
			albedo *= mix(vec3(1.0), hue_t, vm * far_f * detail_strength);
		}
	}
	// blade-ish micro pattern on vegetated ground
	if (veg_blades > 0.0 && fade2 > 0.01) {
		float blades = texture(detail_h, pl.xz * 5.1 + pl.zy * 3.7).r;
		albedo *= 1.0 + veg * fade2 * (blades - 0.5) * 0.5;
	}
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_det, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = mix(roughness_base, sheen_rough, sheen);
	SPECULAR = mix(ground_spec, 0.8, sheen);
	METALLIC = 0.0;

	float em = COLOR.a * emis_strength;
	if (em > 0.001) {
		float flow = fbm3_lo(pl * 0.045 + vec3(0.0, TIME * 0.02 * emis_flow, 0.0));
		float crack = smoothstep(0.35, 0.8, flow);
		float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + pl.x * 0.02 + pl.z * 0.03);
		vec3 ec = emis_color * (0.45 + crack * 1.6) * pulse;
		EMISSION = ec * em * 2.0;
		ROUGHNESS = mix(ROUGHNESS, 0.35, clamp(em, 0.0, 1.0));
	}
}
