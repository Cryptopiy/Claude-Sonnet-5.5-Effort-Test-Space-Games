shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix, skip_vertex_transform;
// HORIZON DRIFT - black hole: gravitational lensing + accretion disc + event horizon (full-screen quad, module M5).
// The quad is a child of the BlackHole node, so MODEL_MATRIX[3] is the singularity and everything is derived from the
// built-in matrices at draw time (no stale uniforms when Frame re-bases the world).
//
// Light paths are integrated in BH-local space, units of the Schwarzschild radius (rs = 1), with the Binet acceleration
//     a = -1.5 * h^2 * pos / |pos|^5          (h = |pos x vel| is conserved)
// which reproduces the null geodesics of Schwarzschild space (photon sphere at 1.5 rs, shadow radius 2.6 rs).
// Far from the hole the deflection is analytic (2 rs / b); the two are blended so there is no visible boundary.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform float rs = 2000.0;
uniform float disc_in = 6000.0;
uniform float disc_out = 34000.0;
uniform float influence = 420000.0;
uniform vec3 disc_n = vec3(0.0, 1.0, 0.0);
uniform vec3 disc_e1 = vec3(1.0, 0.0, 0.0);
uniform vec3 disc_e2 = vec3(0.0, 0.0, -1.0);
uniform float disc_time = 0.0;
uniform float disc_seed = 0.0;
uniform float brightness = 1.0;
uniform float doppler_k = 1.0;
uniform float haze_k = 0.0;
uniform float halo_k = 1.0;
uniform float ring_k = 1.0;
uniform float shock_t = -1.0;          // >= 0 while the "white hole" arrival shock ring expands
uniform float max_steps_u = 224.0;     // quality knob (also used by perf experiments): ray-march step budget
uniform float aa_k = 1.0;              // 0 disables the extra jittered rays on the shadow edge
uniform float fall_k = 0.0;            // 0..1 final plunge: the sky behind collapses into the ring
uniform vec3 shock_color : source_color = vec3(1.0, 0.82, 0.55);

const int MAX_STEPS = 224;

// ------------------------------------------------------------------------------------------------------------------------
// noise
// ------------------------------------------------------------------------------------------------------------------------
float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float f1 = hash13(i + vec3(1.0, 0.0, 1.0));
	float g = hash13(i + vec3(0.0, 1.0, 1.0));
	float h = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, f1, f.x), mix(g, h, f.x), f.y), f.z);
}

// fbm with octave fade-out by pixel footprint (foot = world size of a pixel in noise-space units)
float fbm(vec3 p, float foot) {
	float s = 0.0;
	float a = 0.5;
	float tot = 0.0;
	float fr = 1.0;
	for (int o = 0; o < 5; o++) {
		float fade = 1.0 - smoothstep(0.35, 0.9, foot * fr);
		s += a * fade * vnoise(p * fr);
		tot += a * fade;
		a *= 0.56;
		fr *= 2.03;
		p += vec3(17.3, 9.1, 3.7);
	}
	return s / max(tot, 0.0001) ;
}

// ------------------------------------------------------------------------------------------------------------------------
// accretion disc
// ------------------------------------------------------------------------------------------------------------------------
vec3 blackbody(float t) {
	// t ~ relative temperature: 0 = cold deep red ... 1 = inner-edge white-yellow ... >1.2 blue-white (beamed / blue-shifted side)
	vec3 c0 = vec3(0.20, 0.010, 0.004);
	vec3 c1 = vec3(0.90, 0.16, 0.025);
	vec3 c2 = vec3(1.00, 0.45, 0.090);
	vec3 c3 = vec3(1.00, 0.72, 0.300);
	vec3 c4 = vec3(1.00, 0.92, 0.760);
	vec3 c5 = vec3(0.82, 0.90, 1.000);
	vec3 c = c0;
	c = mix(c, c1, smoothstep(0.10, 0.30, t));
	c = mix(c, c2, smoothstep(0.28, 0.50, t));
	c = mix(c, c3, smoothstep(0.48, 0.72, t));
	c = mix(c, c4, smoothstep(0.70, 1.00, t));
	c = mix(c, c5, smoothstep(1.00, 1.60, t));
	return c;
}

float disc_pattern(float r, float x, float y, float tt, float foot) {
	float om = 0.50 * pow(3.0 / r, 1.5);                 // Keplerian angular speed (rad/s), r in rs
	float a = om * tt;
	float ca = cos(a);
	float sa = sin(a);
	vec2 q = vec2(ca * x + sa * y, -sa * x + ca * y);
	vec2 dir = q / r;
	// large clumps / spiral wisps (features ~ 1 rs)
	float n2 = fbm(vec3(dir * (0.9 + 0.06 * r), r * 0.85 + disc_seed * 2.7), foot * 0.85);
	// azimuthally stretched streaks (radial frequency ~3 / rs), fine octaves appear only when the pixel footprint allows it
	float n1 = fbm(vec3(dir * (1.1 + 0.42 * r), r * 3.1 + disc_seed), foot * 3.1);
	// thin concentric lanes
	float lf = 1.0 - smoothstep(0.12, 0.42, foot * 8.0);
	float lanes = sin(r * 8.0 + n2 * 5.0 + disc_seed * 5.0) * 0.5 + 0.5;
	n1 = clamp((n1 - 0.5) * 2.1 + 0.5, 0.0, 1.0);
	n2 = clamp((n2 - 0.5) * 1.8 + 0.5, 0.0, 1.0);
	float d = 0.06 + 0.62 * n1 + 0.50 * n2 + 0.34 * lf * (lanes - 0.5);
	// sparse bright hot spots
	float hs = smoothstep(0.66, 0.9, fbm(vec3(dir * (2.2 + 0.30 * r), r * 1.6 + 31.0 + disc_seed), foot * 1.6));
	return clamp(d + hs * 0.50, 0.0, 1.5);
}

// returns vec4(emission rgb, absorption alpha) for light crossing the disc plane at cp (units rs) travelling along dirv
vec4 disc_shade(vec3 cp, vec3 dirv, float foot) {
	float rin = disc_in / rs;
	float rout = disc_out / rs;
	float r = length(cp);
	float env_in = smoothstep(rin * 0.94, rin * 1.12, r);
	float env_out = 1.0 - smoothstep(rout * 0.55, rout, r);
	float env = env_in * env_out;
	if (env <= 0.002) {
		return vec4(0.0);
	}
	float x = dot(cp, disc_e1);
	float y = dot(cp, disc_e2);
	float cyc = 26.0;
	float ph = disc_time / cyc;
	float f1 = fract(ph);
	float f2 = fract(ph + 0.5);
	float w = abs(2.0 * f1 - 1.0);
	float dd = mix(disc_pattern(r, x, y, f1 * cyc, foot), disc_pattern(r, x, y, f2 * cyc, foot), w);

	// relativistic beaming + gravitational redshift
	vec3 vdir = normalize(cross(disc_n, cp));
	float beta = clamp(sqrt(0.5 / max(r - 1.0, 0.08)), 0.0, 0.72);
	float cosv = dot(vdir, -dirv);
	float gam = inversesqrt(1.0 - beta * beta);
	float dop = 1.0 / (gam * (1.0 - beta * cosv));
	float grav = sqrt(max(1.0 - 1.0 / r, 0.02));
	float g = mix(grav, dop * grav, doppler_k);

	float tn = pow(rin / r, 0.72);
	float tobs = tn * mix(1.0, clamp(g, 0.5, 1.45), 0.7);
	vec3 col = blackbody(tobs);
	float radial = pow(rin / max(r, rin), 2.1);
	float beam = pow(clamp(g, 0.3, 1.8), 2.0 * doppler_k + 0.0001);
	float amp = 1.9 * radial * beam * (0.20 + 1.00 * dd) * env;

	float graze = clamp(1.0 / max(abs(dot(dirv, disc_n)), 0.1), 1.0, 5.0);
	float thick = smoothstep(rout * 0.7, rin * 1.25, r);                 // 1 near the inner edge, ~0 in the outer disc
	float alpha = clamp((0.04 + 0.95 * dd) * env * (0.10 + 0.90 * thick), 0.0, 0.97);
	alpha = 1.0 - pow(1.0 - alpha, graze * 0.7);
	return vec4(col * amp * brightness, alpha);
}

// ------------------------------------------------------------------------------------------------------------------------
// light-path integration (units of rs).  Returns accumulated light (disc + photon ring), transmittance of whatever lies
// behind (0 if the ray fell in), and the asymptotic direction of escaping rays.
// ------------------------------------------------------------------------------------------------------------------------
vec3 residual_deflect(vec3 pos, vec3 vel) {
	vec3 vn = normalize(vel);
	float s = dot(pos, vn);
	vec3 q = pos - s * vn;
	float b = max(length(q), 0.02);
	float sh = 1.0 - s / sqrt(s * s + b * b);
	float alpha = sh / b + 1.47 * sh / (b * b);
	return normalize(vn - (q / b) * alpha);
}

void trace(vec3 p0, vec3 d0, float pix_ang, out vec3 col, out float T, out vec3 dout, out float rmin, out float orbit) {
	vec3 pos = p0;
	vec3 vel = d0;
	float rin = disc_in / rs;
	float rout = disc_out / rs;
	vec3 L = cross(pos, vel);
	float h2 = dot(L, L);
	col = vec3(0.0);
	vec3 glow = vec3(0.0);
	T = 1.0;
	rmin = 1.0e9;
	orbit = 0.0;
	float path = 0.0;
	float hprev = dot(pos, disc_n);
	bool done = false;
	float ring_amp = 0.55 * brightness * ring_k;
	for (int i = 0; i < MAX_STEPS; i++) {
		if (float(i) >= max_steps_u) {
			break;
		}
		float r2 = dot(pos, pos);
		float r = sqrt(r2);
		rmin = min(rmin, r);
		if (r < 1.0) {
			T = 0.0;
			done = true;
			break;
		}
		float sp = length(vel);
		float stp = clamp(0.065 * r, 0.015, 60.0);
		float dt = stp / sp;
		vec3 acc = -1.5 * h2 * pos / (r2 * r2 * r);
		vel += acc * dt;
		vec3 np = pos + vel * dt;
		float ds = stp;
		path += ds;

		// photon-ring glow (rays that linger near the photon sphere r = 1.5)
		float gw = exp(-pow((r - 1.5) / 0.20, 2.0));
		float cr = dot(pos, vel) / (r * sp);
		float tang = pow(max(1.0 - cr * cr, 0.0), 3.0);
		gw *= tang;
		glow += T * vec3(1.0, 0.80, 0.55) * (gw * ds * ring_amp);
		orbit += gw * ds;

		// optically thin gas haze around the disc plane
		float hn = dot(np, disc_n);
		if (haze_k > 0.0 && r > rin * 0.85 && r < rout * 1.05) {
			float hh = 0.035 * r + 0.04;
			float dens = exp(-0.5 * hn * hn / (hh * hh));
			float prof = pow(rin / max(r, rin), 1.7) * (1.0 - smoothstep(rout * 0.6, rout, r)) * smoothstep(rin * 0.9, rin * 1.15, r);
			col += T * blackbody(pow(rin / r, 0.7) * 0.85) * (dens * prof * ds * 0.30 * haze_k * brightness);
		}

		// disc plane crossing
		if (hprev * hn < 0.0) {
			float f = hprev / (hprev - hn);
			vec3 cp = mix(pos, np, f);
			float cr = length(cp);
			if (cr > rin * 0.9 && cr < rout) {
				vec4 dc = disc_shade(cp, normalize(vel), pix_ang * max(path - ds * (1.0 - f), 0.0));
				col += T * dc.rgb;
				T *= (1.0 - dc.a);
			}
		}
		hprev = hn;
		pos = np;
		if (T < 0.004) {
			done = true;
			break;
		}
		float rn2 = dot(pos, pos);
		if (rn2 > (rout * 1.1) * (rout * 1.1) && dot(pos, vel) > 0.0) {
			break;
		}
	}
	if (T > 0.0 && !done) {
		if (dot(pos, vel) > 0.0 || dot(pos, pos) > 25.0) {
			dout = residual_deflect(pos, vel);
			col += glow;                          // the photon ring is only seen on escaping rays (outside the shadow edge)
		} else {
			T = 0.0;                              // orbited too long: counts as captured
			dout = normalize(vel);
		}
	} else {
		dout = normalize(vel);
		if (T > 0.0) {
			col += glow;
		}
	}
}

vec3 weak_deflect(vec3 P0, vec3 rd, float window) {
	float a = dot(P0, rd);
	vec3 q = P0 - a * rd;
	float b = max(length(q), 0.02);
	float sh = 1.0 - a / sqrt(a * a + b * b);
	float alpha = (sh / b + 1.47 * sh / (b * b)) * window;
	return normalize(rd - (q / b) * alpha);
}

// ------------------------------------------------------------------------------------------------------------------------
// procedural fallback sky (for deflected rays that point outside the screen)
// ------------------------------------------------------------------------------------------------------------------------
vec3 fallback_stars(vec3 d) {
	vec3 c = vec3(0.0);
	for (int l = 0; l < 3; l++) {
		float sc = 60.0 * pow(2.2, float(l));
		vec3 p = d * sc;
		vec3 id = floor(p);
		vec3 f = fract(p) - 0.5;
		float h = hash13(id + float(l) * 17.0);
		if (h > 0.84) {
			vec3 jt = (hash33(id + 3.1) - 0.5) * 0.6;
			float dist = length(f - jt);
			float s = smoothstep(0.16, 0.0, dist) * (0.35 + 1.4 * hash13(id + 9.0));
			vec3 sc2 = mix(vec3(1.0, 0.85, 0.7), vec3(0.7, 0.8, 1.0), hash13(id + 5.0));
			c += sc2 * s * 0.8;
		}
	}
	return c;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 vp = VIEWPORT_SIZE;
	float dep = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, dep);
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_z = (dep < 0.0000001) ? 1.0e30 : (-vw.z / vw.w);

	vec3 bh_w = MODEL_MATRIX[3].xyz;
	vec3 cam_w = INV_VIEW_MATRIX[3].xyz;
	vec3 bh_v = (VIEW_MATRIX * vec4(bh_w, 1.0)).xyz;
	bool fg = scene_z < (-bh_v.z - 1.5 * rs);        // opaque geometry clearly in front of the hole: leave untouched

	vec4 pr = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize((INV_VIEW_MATRIX * vec4(normalize(pr.xyz / pr.w), 0.0)).xyz);

	vec3 to_bh = bh_w - cam_w;
	float Dm = length(to_bh);
	vec3 dirc = to_bh / max(Dm, 0.001);
	float ang = acos(clamp(dot(rd, dirc), -1.0, 1.0));

	vec3 P0 = -to_bh / rs;                     // camera position relative to the hole, units rs
	float pix_ang = 2.0 / (PROJECTION_MATRIX[1][1] * vp.y);

	float a0 = dot(P0, rd);
	vec3 q0 = P0 - a0 * rd;
	float b0 = length(q0);                       // impact parameter of the straight ray (rs)
	float b0m = b0 * rs;

	float rout = disc_out / rs;
	float B_LO = rout * 1.6;
	float B_HI = rout * 2.8;
	float win = 1.0 - smoothstep(0.45 * influence, influence, b0m);

	bool near_field = (b0m < influence) && (a0 < 0.0 || Dm < influence);
	bool active = !fg && near_field;
	vec3 add_col = vec3(0.0);
	float Tbg = 1.0;
	vec3 dout = rd;
	float rmin = 1e9;
	float orbit = 0.0;
	bool inside = Dm < rs;

	// distant "ember" halo: keeps the hole findable from far away
	// a tight bright core (the disc seen from afar) + a wide faint corona so that a player scanning the sky from the home planet notices a glowing smudge
	float halo_ang = max(0.85 * disc_out / max(Dm, 1.0), 0.0045);
	float halo_w = 0.0;
	if (!fg) {
		float far_k = halo_k * smoothstep(260000.0, 1000000.0, Dm) * step(0.0, dot(rd, dirc));
		halo_w = far_k * (exp(-pow(ang / halo_ang, 2.0)) + 0.20 * exp(-pow(ang / (halo_ang * 3.6), 2.0)));
	}

	if (active) {
		float mw = 1.0 - smoothstep(B_LO, B_HI, b0);
		vec3 d_weak = weak_deflect(P0, rd, win);
		dout = d_weak;
		if (inside) {
			Tbg = 0.0;
		} else if (mw > 0.0) {
			vec3 c1;
			float T1;
			vec3 d1;
			float rm1;
			float orb1;
			trace(P0, rd, pix_ang, c1, T1, d1, rm1, orb1);
			// edge anti-aliasing: extra jittered rays only for pixels hugging the photon sphere (shadow edge / photon ring)
			if (aa_k > 0.5 && orb1 > 0.2 && Dm < 9.0e5) {
				vec3 right = normalize(cross(rd, vec3(0.0, 1.0, 0.0001)));
				vec3 up = cross(right, rd);
				float acc_w = 1.0;
				for (int k = 0; k < 3; k++) {
					float fk = float(k);
					vec2 jt = vec2(fract(0.7548776 * (fk + 1.0)) - 0.5, fract(0.5698403 * (fk + 1.0)) - 0.5) * 1.1 * pix_ang;
					vec3 dj = normalize(rd + right * jt.x + up * jt.y);
					vec3 cj;
					float Tj;
					vec3 dj_out;
					float rmj;
					float orbj;
					trace(P0, dj, pix_ang, cj, Tj, dj_out, rmj, orbj);
					c1 += cj;
					T1 += Tj;
					d1 += dj_out * step(0.001, Tj);
					acc_w += 1.0;
				}
				c1 /= acc_w;
				T1 /= acc_w;
				d1 = normalize(d1 + vec3(1e-6));
			}
			add_col = c1 * mw;
			Tbg = mix(1.0, T1, mw);
			dout = normalize(mix(d_weak, d1, mw));
			rmin = rm1;
			orbit = orb1;
		}
	}

	// ---- background (lensed sky) ------------------------------------------------------------------------------------------
	vec2 uvs = SCREEN_UV;
	bool have_uv = false;
	if (active) {
		vec3 dv = (VIEW_MATRIX * vec4(dout, 0.0)).xyz;
		if (dv.z < -0.0001) {
			vec4 cl = PROJECTION_MATRIX * vec4(dv, 1.0);
			uvs = cl.xy / cl.w * 0.5 + 0.5;
			have_uv = true;
		}
	}
	vec2 dux = dFdx(uvs) * vp;
	vec2 duy = dFdy(uvs) * vp;
	float lod = clamp(log2(max(max(length(dux), length(duy)), 1.0)), 0.0, 5.0);
	vec3 bg = vec3(0.0);
	vec3 scn = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (active && Tbg > 0.001) {
		float edge = 1.0;
		vec2 uvc = uvs;
		if (have_uv) {
			vec2 out_amt = max(-uvs, uvs - 1.0);
			edge = 1.0 - smoothstep(0.0, 0.05, max(out_amt.x, out_amt.y));
			uvc = clamp(uvs, vec2(0.001), vec2(0.999));
		} else {
			edge = 0.0;
		}
		vec3 sc = textureLod(screen_tex, uvc, lod).rgb;
		// a foreground object (ship) at the sampled location must not be smeared into the lensed image: use the pixel's own colour
		float d2 = textureLod(depth_tex, uvc, 0.0).x;
		vec4 v2 = INV_PROJECTION_MATRIX * vec4(uvc * 2.0 - 1.0, d2, 1.0);
		float z2 = (d2 < 0.0000001) ? 1.0e30 : (-v2.z / v2.w);
		if (z2 < (-bh_v.z - 1.5 * rs)) {
			sc = scn;
		}
		vec3 fs = fallback_stars(dout);
		bg = mix(fs, sc, edge);
	}

	vec3 halo_col = vec3(1.0, 0.55, 0.20) * (halo_w * 2.2 * brightness);
	vec3 outc = vec3(0.0);
	float alpha_o = 0.0;
	if (!fg) {
		if (active) {
			outc = add_col + bg * Tbg + halo_col;
			alpha_o = 1.0;
		} else if (halo_w > 0.002) {
			outc = scn + halo_col;
			alpha_o = 1.0;
		}
		// white-hole arrival shock ring
		if (shock_t >= 0.0) {
			float ring_r = shock_t * 0.22;
			float dist = abs(ang - ring_r);
			float w = exp(-pow(dist / (0.012 + 0.02 * shock_t), 2.0)) * exp(-shock_t * 0.55);
			if (w > 0.002) {
				vec3 base = (alpha_o > 0.5) ? outc : scn;
				outc = base + shock_color * w * 3.0;
				alpha_o = 1.0;
			}
		}
	}

	ALBEDO = max(outc, vec3(0.0));
	ALPHA = alpha_o;
}
