shader_type spatial;
// HORIZON DRIFT terrain shader (module M1).
// Vertex colour = macro albedo (sRGB, alpha = emission mask). Slope rock + exposed-earth band, triplanar detail (colour + normal), a high-frequency
// grain layer for the 0-45 m range (what makes the ground read as ground at 1-3 m), shoreline wetness and crisp emissive veins are done per pixel.
// Vertices geomorph towards the parent LOD (CUSTOM0.xyz, range in CUSTOM0.w) to hide LOD popping.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D grain_tex : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec3 planet_center = vec3(0.0);     // world position of the planet centre (updated every frame)
uniform vec3 cam_pos = vec3(0.0);           // world position of the viewing camera (updated every frame)
uniform float planet_radius = 6000.0;
uniform float water_level = -1.0e9;         // metres above planet_radius
uniform vec3 rock_color : source_color = vec3(0.35, 0.33, 0.30);
uniform vec3 rock_color2 : source_color = vec3(0.5, 0.46, 0.4);
uniform vec3 dirt_color : source_color = vec3(0.3, 0.22, 0.12);
uniform float rock_lo = 0.22;
uniform float rock_hi = 0.45;
uniform float rough_base = 0.9;
uniform float spec_base = 0.2;
uniform float grain_amt = 0.5;
uniform vec3 beach_color : source_color = vec3(0.8, 0.75, 0.55);
uniform float beach_h = 0.0;                      // >0: per-pixel beach band (thickness in m above the water line) - crisp, smooth shorelines on every LOD
uniform vec3 ripple_dir = vec3(1.0, 0.0, 0.0);   // wind direction (planet space) for sand / snow ripples
uniform float ripple_amt = 0.0;                   // 0 = none
uniform vec3 emit_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float emit_energy = 0.0;
uniform float scale_fine = 0.43;
uniform float scale_mid = 0.066;
uniform float scale_far = 0.0036;
uniform float nrm_fine = 0.5;
uniform float nrm_mid = 0.45;
uniform float color_var = 0.3;
uniform float morph_start = 1.3;
uniform float morph_len = 0.6;
uniform int debug_mode = 0;                  // 1 = unlit albedo (palette check), 2 = unlit normals

varying vec3 v_col;
varying float v_emit;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wp, cam_pos);
	float m = clamp((d / max(CUSTOM0.w, 1.0) - morph_start) / morph_len, 0.0, 1.0);
	VERTEX += CUSTOM0.xyz * m;
	v_col = pow(COLOR.rgb, vec3(2.2));
	v_emit = COLOR.a;
}

// triplanar fetch of the packed detail texture: rg = normal xy, b = colour variation, a = cavity/pebbles
vec4 tri(vec3 wp, vec3 w, float sc, vec3 off, out vec3 pert) {
	vec3 p = wp * sc + off;
	vec4 sx = texture(detail_tex, p.yz);
	vec4 sy = texture(detail_tex, p.zx + vec2(0.37, 0.61));
	vec4 sz = texture(detail_tex, p.xy + vec2(0.71, 0.13));
	vec2 nx = sx.rg * 2.0 - 1.0;
	vec2 ny = sy.rg * 2.0 - 1.0;
	vec2 nz = sz.rg * 2.0 - 1.0;
	pert = vec3(0.0, nx.x, nx.y) * w.x + vec3(ny.y, 0.0, ny.x) * w.y + vec3(nz.x, nz.y, 0.0) * w.z;
	return sx * w.x + sy * w.y + sz * w.z;
}

vec3 tri_grain(vec3 wp, vec3 w, float sc, vec3 off) {
	vec3 p = wp * sc + off;
	return texture(grain_tex, p.yz).rgb * w.x + texture(grain_tex, p.zx + vec2(0.37, 0.61)).rgb * w.y + texture(grain_tex, p.xy + vec2(0.71, 0.13)).rgb * w.z;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 up = normalize(wp - planet_center);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz);
	float dist = length(VERTEX);
	float h_abs = length(wp - planet_center) - planet_radius;

	// sharp triplanar weights: a pixel is dominated by ONE projection (no 3-way mush on diagonal normals)
	vec3 bw = pow(abs(wn), vec3(7.0));
	bw /= (bw.x + bw.y + bw.z);

	float w_fine = 1.0 - smoothstep(35.0, 220.0, dist);
	float w_mid = 1.0 - smoothstep(250.0, 2200.0, dist);
	float w_far = smoothstep(120.0, 1500.0, dist) * (1.0 - smoothstep(30000.0, 120000.0, dist));

	// micro layer: ~0.4 m tile, only within ~40 m of the camera (this is what makes the ground read as ground at 1-3 m)
	float w_micro = 1.0 - smoothstep(7.0, 45.0, dist);

	vec3 p_far, p_mid, p_fine, p_micro;
	vec4 t_far = tri(wp, bw, scale_far, vec3(0.13, 0.57, 0.31), p_far);
	vec4 t_mid = tri(wp, bw, scale_mid, vec3(0.51, 0.27, 0.83), p_mid);
	vec4 t_fine = vec4(0.5);
	vec4 t_micro = vec4(0.5);
	p_fine = vec3(0.0);
	p_micro = vec3(0.0);
	if (w_fine > 0.01) {
		t_fine = tri(wp, bw, scale_fine, vec3(0.0), p_fine);
	}
	if (w_micro > 0.01) {
		t_micro = tri(wp, bw, scale_fine * 6.3, vec3(0.29, 0.83, 0.47), p_micro);
	}
	// grain: r = fine speckle (~cm), g = medium speckle, b = crack / pebble network
	vec3 gr = vec3(0.5, 0.5, 1.0);
	vec3 gm = vec3(0.5, 0.5, 1.0);
	if (w_micro > 0.01) {
		gr = tri_grain(wp, bw, 1.55, vec3(0.41, 0.19, 0.77));
		gm = tri_grain(wp, bw, 0.37, vec3(0.83, 0.52, 0.11));
	}
	float grain = ((gr.r - 0.5) * 1.1 + (gr.g - 0.5) * 0.8 + (gm.g - 0.5) * 0.9) * w_micro;

	// perturbed normal (world space)
	vec3 dn = p_fine * nrm_fine * w_fine + p_mid * nrm_mid * w_mid + p_far * 0.22 * w_far + p_micro * nrm_fine * 0.9 * w_micro;
	dn += (vec3(gr.r - 0.5, 0.0, gr.g - 0.5) * 0.30 * w_micro);

	// wind ripples (desert sand / snow sastrugi): purely per-pixel, so they cost no geometry and never alias on coarse LODs
	float rip_sh = 0.0;
	if (ripple_amt > 0.0 && w_fine > 0.01) {
		vec3 rd = normalize(ripple_dir - up * dot(ripple_dir, up));
		float ph = dot(wp, rd) * 0.36 + (t_mid.b - 0.5) * 6.0 + (t_far.b - 0.5) * 9.0;
		float ph2 = dot(wp, rd) * 1.05 + (t_fine.b - 0.5) * 5.0;
		float sl = cos(ph) * 0.8 + cos(ph2) * 0.35;
		dn += rd * sl * ripple_amt * w_fine;
		rip_sh = (sin(ph) * 0.8 + sin(ph2) * 0.3) * ripple_amt * w_fine;
	}

	// colour variation
	float var_all = (t_fine.b - 0.5) * w_fine + (t_mid.b - 0.5) * w_mid * 1.2 + (t_far.b - 0.5) * (0.4 + w_far) + (t_micro.b - 0.5) * w_micro * 0.7;
	float cav = mix(1.0, 0.80 + 0.34 * t_fine.a, w_fine) * mix(1.0, 0.88 + 0.24 * t_mid.a, w_mid) * mix(1.0, 0.78 + 0.4 * t_micro.a, w_micro * 0.8);

	// slope: exposed earth first, rock on the steepest parts
	float slope = 1.0 - dot(wn, up);
	float jitter = (t_mid.b - 0.5) * 0.14 * (0.3 + w_mid) + (t_fine.b - 0.5) * 0.04 * w_fine + (t_far.b - 0.5) * 0.14 + grain * 0.03;
	float rock_w = smoothstep(rock_lo, rock_hi, slope + jitter);
	float dirt_w = smoothstep(rock_lo * 0.42, rock_lo * 0.95, slope + jitter * 1.4) * (1.0 - rock_w);
	// rock strata / crack look: darker crevices + lighter ridges from the cavity channel, stronger normals on rock
	float rock_var = clamp(t_mid.b * 1.2 + (t_far.b - 0.5) * 0.8 + (t_fine.b - 0.5) * 0.5 * w_fine, 0.0, 1.0);
	vec3 rcol = mix(rock_color, rock_color2, rock_var);
	rcol *= 0.72 + 0.55 * mix(1.0, t_fine.a, w_fine) * mix(1.0, t_mid.a, w_mid);
	rcol *= clamp(1.0 + grain * 0.9, 0.5, 1.7);
	rcol *= mix(1.0, 0.55 + 0.45 * smoothstep(0.0, 0.3, gm.b), w_micro * 0.8);      // dark cracks between rock plates
	vec3 wn2 = normalize(wn + dn * (1.0 + 1.1 * rock_w));

	vec3 soil = v_col * (1.0 + var_all * color_var * 2.0);
	soil *= clamp(1.0 + grain * grain_amt * 1.5, 0.55, 1.65);
	float beach = 0.0;
	if (beach_h > 0.0 && water_level > -1.0e8) {
		float hw2 = h_abs - water_level;
		float bj = (t_far.b - 0.5) * beach_h * 0.9 + (t_mid.b - 0.5) * beach_h * 0.55 * w_mid + (t_fine.b - 0.5) * beach_h * 0.4 * w_fine + grain * beach_h * 0.12;
		beach = (1.0 - smoothstep(beach_h * 0.3, beach_h, hw2 + bj)) * smoothstep(-0.9, 0.25, hw2);
		beach *= (1.0 - rock_w);
	}
	vec3 dcol = dirt_color * clamp(1.0 + var_all * 0.9 + grain * 0.8, 0.5, 1.7);
	soil = mix(soil, dcol, dirt_w * 0.85);
	soil = mix(soil, beach_color * clamp(1.0 + var_all * 0.5 + grain * 0.45, 0.6, 1.4), beach);
	vec3 albedo = mix(soil, rcol * (1.0 + var_all * 0.5), rock_w);
	albedo *= cav * (1.0 + rip_sh * 0.10 * (1.0 - rock_w));

	// shoreline wetness
	float wet = 0.0;
	if (water_level > -1.0e8) {
		float hw = h_abs - water_level;
		wet = (1.0 - smoothstep(0.0, 2.2, hw)) * step(-6.0, hw);
		albedo *= mix(1.0, 0.62, wet);
	}

	ALBEDO = albedo;
	ROUGHNESS = clamp(mix(rough_base, 0.92, rock_w) - wet * 0.35 - var_all * 0.15, 0.2, 1.0);
	SPECULAR = spec_base;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn2, 0.0)).xyz);
	if (debug_mode == 1) {
		EMISSION = albedo;
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
	} else if (debug_mode == 2) {
		EMISSION = wn2 * 0.5 + 0.5;
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
	}

	if (emit_energy > 0.0 && v_emit > 0.01) {
		float flow = texture(detail_tex, wp.xz * 0.05 + vec2(TIME * 0.006, TIME * 0.004)).b;
		float e = smoothstep(0.30, 0.62, v_emit + (t_fine.b - 0.5) * 0.45 * w_fine + (t_mid.b - 0.5) * 0.35);
		EMISSION = emit_color * emit_energy * e * (0.65 + 0.7 * flow);
		ALBEDO = mix(ALBEDO, ALBEDO * 0.3 + emit_color * 0.1, e);
	}
}
