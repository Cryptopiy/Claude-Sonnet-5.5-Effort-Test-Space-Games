class_name AtmosphereProfiles
extends RefCounted
## Per-biome atmosphere / sky / cloud / ocean look tables (module M2) keyed by BiomeDB ids, plus the small amount of CPU-side atmosphere maths that
## SkyController needs (sun transmittance for sunsets). The GPU side lives in shaders/atmosphere_common.gdshaderinc and uses exactly the same model:
##   density_R(h) = exp(-h / (atmo_h * h_r)),  density_M(h) = exp(-h / (atmo_h * h_m)),  beta = vertical_optical_depth / scale_height.
##
## Colours are written as the *vertical optical depth* of the atmosphere at the ground (0.03 = 3 % of the light is scattered in a straight vertical path).
## Rayleigh tau ~ (0.03, 0.075, 0.17) gives a blue sky + orange sunsets; a tau biased to red gives a martian orange sky, etc.

const MIE_SCALE := 0.40         # global trims of the table values (kept here so every consumer uses the same ones)
const RAY_SCALE := 0.85
const TOP_MULT := 1.6          # integration shell: radius + atmo_h * TOP_MULT (density there is ~0.1 %)
const LIGHT_BOOST := 2.2       # multiplies the part of the sunlight path that is longer than a vertical one (small planets have short slant paths => weak sunsets otherwise)

## ---------------------------------------------------------------------------------------------------------------------------------------------
const BASE := {
	"rayleigh": Vector3(0.030, 0.075, 0.170), "mie": 0.040, "mie_color": Color(1.0, 0.97, 0.92), "mie_g": 0.78, "mie_abs": 0.08,
	"h_r": 0.24, "h_m": 0.075, "sun_gain": 1.0,
	"glow": Color(0, 0, 0), "glow_amount": 0.0, "glow_h": 0.12,
	"night_glow": Color(0.010, 0.018, 0.040),
	"amb_day": Color(0.40, 0.56, 0.95), "amb_dusk": Color(0.55, 0.38, 0.40), "amb_night": Color(0.050, 0.070, 0.150),
	"amb_energy": 1.0, "amb_night_energy": 0.9,
	"exposure": 1.0, "star_visibility": 1.0, "fog_far_color": Color(0.7, 0.8, 1.0),
	"cloud": {"cover": 0.52, "soft": 0.22, "bright": Color(1, 1, 1), "shade": Color(0.50, 0.58, 0.72), "alt": 0.55, "speed": 1.0, "scale": 1.0, "opacity": 0.92, "dark": 0.0, "emit": Color(0, 0, 0)},
	"aurora": 0.0, "aurora_a": Color(0.2, 1.0, 0.5), "aurora_b": Color(0.5, 0.3, 1.0),
	"zenith": Color(0.22, 0.42, 0.92), "horizon": Color(0.62, 0.78, 1.0),
	"sky_tint": Vector3(1.0, 1.0, 1.0), "sky_sat": 1.0,       # art direction of the in-scattered sky light (see atmosphere_common.gdshaderinc)
}

const PROFILES := {
	"lush": {
		"rayleigh": Vector3(0.016, 0.050, 0.200), "mie": 0.030, "mie_color": Color(1.0, 0.97, 0.92), "mie_g": 0.70,
		"sky_tint": Vector3(1.9, 2.7, 6.0), "sky_sat": 0.95,
		"amb_day": Color(0.42, 0.58, 0.96), "amb_dusk": Color(0.62, 0.38, 0.36),
		"cloud": {"cover": 0.50, "bright": Color(1, 1, 1), "shade": Color(0.52, 0.60, 0.76), "opacity": 0.92},
		"zenith": Color(0.20, 0.40, 0.90), "horizon": Color(0.65, 0.80, 1.0),
	},
	"ocean": {
		"rayleigh": Vector3(0.012, 0.050, 0.180), "mie": 0.045, "mie_color": Color(0.95, 1.0, 1.0), "mie_g": 0.74,
		"sky_tint": Vector3(3.5, 4.0, 6.5), "sky_sat": 1.15,
		"amb_day": Color(0.36, 0.66, 0.90), "amb_dusk": Color(0.60, 0.40, 0.38), "sun_gain": 1.05,
		"cloud": {"cover": 0.62, "bright": Color(1, 1, 1), "shade": Color(0.50, 0.62, 0.75), "opacity": 0.95},
		"zenith": Color(0.10, 0.50, 0.88), "horizon": Color(0.55, 0.88, 0.98),
	},
	"desert": {
		"rayleigh": Vector3(0.090, 0.085, 0.075), "mie": 0.115, "mie_color": Color(1.0, 0.78, 0.50), "mie_g": 0.55, "mie_abs": 0.30,
		"sky_tint": Vector3(3.4, 2.5, 1.7), "sky_sat": 1.6,
		"h_m": 0.16, "sun_gain": 1.25,
		"night_glow": Color(0.012, 0.012, 0.020),
		"amb_day": Color(0.86, 0.66, 0.46), "amb_dusk": Color(0.70, 0.40, 0.25), "amb_night": Color(0.06, 0.06, 0.11),
		"cloud": {"cover": 0.20, "soft": 0.30, "bright": Color(1.0, 0.92, 0.80), "shade": Color(0.78, 0.60, 0.46), "opacity": 0.55, "alt": 0.52, "scale": 1.3},
		"zenith": Color(0.50, 0.55, 0.62), "horizon": Color(0.95, 0.72, 0.45),
	},
	"frozen": {
		"rayleigh": Vector3(0.020, 0.060, 0.160), "mie": 0.060, "mie_color": Color(0.88, 0.96, 1.0), "mie_g": 0.72,
		"sky_tint": Vector3(2.0, 4.0, 8.0), "sky_sat": 0.72,
		"h_m": 0.10, "sun_gain": 1.1,
		"amb_day": Color(0.58, 0.76, 0.98), "amb_dusk": Color(0.60, 0.50, 0.62), "amb_night": Color(0.045, 0.080, 0.170),
		"night_glow": Color(0.010, 0.026, 0.040),
		"cloud": {"cover": 0.46, "soft": 0.30, "bright": Color(0.96, 0.99, 1.0), "shade": Color(0.60, 0.72, 0.86), "opacity": 0.80},
		"zenith": Color(0.30, 0.55, 0.88), "horizon": Color(0.78, 0.90, 1.0),
		"aurora": 0.55, "aurora_a": Color(0.25, 1.0, 0.65), "aurora_b": Color(0.30, 0.45, 1.0),
	},
	"volcanic": {
		"rayleigh": Vector3(0.115, 0.075, 0.050), "mie": 0.30, "mie_color": Color(0.80, 0.34, 0.16), "mie_g": 0.62, "mie_abs": 1.10,
		"sky_tint": Vector3(0.22, 0.08, 0.05), "sky_sat": 1.0,
		"h_r": 0.30, "h_m": 0.26, "sun_gain": 0.95,
		"glow": Color(1.0, 0.30, 0.06), "glow_amount": 0.55, "glow_h": 0.16,
		"night_glow": Color(0.060, 0.016, 0.006),
		"amb_day": Color(0.60, 0.30, 0.20), "amb_dusk": Color(0.55, 0.22, 0.12), "amb_night": Color(0.16, 0.06, 0.04), "amb_energy": 0.95, "amb_night_energy": 1.1,
		"cloud": {"cover": 0.78, "soft": 0.35, "bright": Color(0.46, 0.30, 0.26), "shade": Color(0.12, 0.08, 0.08), "opacity": 0.95, "dark": 0.75, "alt": 0.45,
			"emit": Color(1.0, 0.25, 0.04)},
		"zenith": Color(0.16, 0.07, 0.06), "horizon": Color(0.90, 0.34, 0.12),
	},
	"toxic": {
		"rayleigh": Vector3(0.080, 0.130, 0.050), "mie": 0.20, "mie_color": Color(0.70, 0.92, 0.28), "mie_g": 0.60, "mie_abs": 0.35,
		"sky_tint": Vector3(1.0, 1.6, 0.3), "sky_sat": 0.85,
		"h_r": 0.30, "h_m": 0.20, "sun_gain": 1.05,
		"glow": Color(0.35, 1.0, 0.10), "glow_amount": 0.10, "glow_h": 0.10,
		"night_glow": Color(0.020, 0.050, 0.012),
		"amb_day": Color(0.50, 0.70, 0.28), "amb_dusk": Color(0.45, 0.50, 0.20), "amb_night": Color(0.055, 0.100, 0.040),
		"cloud": {"cover": 0.70, "soft": 0.34, "bright": Color(0.80, 0.95, 0.45), "shade": Color(0.30, 0.42, 0.18), "opacity": 0.90, "dark": 0.2, "alt": 0.42},
		"zenith": Color(0.40, 0.62, 0.22), "horizon": Color(0.75, 0.88, 0.32),
	},
	"exotic": {
		"rayleigh": Vector3(0.095, 0.050, 0.150), "mie": 0.060, "mie_color": Color(1.0, 0.70, 0.95), "mie_g": 0.78,
		"sky_tint": Vector3(1.2, 0.8, 2.4), "sky_sat": 1.2,
		"sun_gain": 1.15,
		"night_glow": Color(0.040, 0.016, 0.070),
		"amb_day": Color(0.72, 0.45, 0.95), "amb_dusk": Color(0.85, 0.40, 0.65), "amb_night": Color(0.10, 0.060, 0.220), "amb_energy": 1.05, "amb_night_energy": 1.1,
		"cloud": {"cover": 0.42, "soft": 0.30, "bright": Color(1.0, 0.86, 1.0), "shade": Color(0.55, 0.38, 0.80), "opacity": 0.80, "emit": Color(0.35, 0.10, 0.50)},
		"zenith": Color(0.45, 0.22, 0.85), "horizon": Color(1.0, 0.55, 0.80),
		"aurora": 1.0, "aurora_a": Color(0.20, 1.0, 0.85), "aurora_b": Color(1.0, 0.25, 0.85),
	},
	"swamp": {
		"rayleigh": Vector3(0.060, 0.085, 0.080), "mie": 0.26, "mie_color": Color(0.74, 0.78, 0.45), "mie_g": 0.55, "mie_abs": 0.45,
		"sky_tint": Vector3(1.5, 1.9, 0.5), "sky_sat": 0.65,
		"h_r": 0.28, "h_m": 0.30, "sun_gain": 0.95,
		"night_glow": Color(0.012, 0.022, 0.014),
		"amb_day": Color(0.50, 0.60, 0.40), "amb_dusk": Color(0.50, 0.42, 0.28), "amb_night": Color(0.05, 0.075, 0.060),
		"cloud": {"cover": 0.72, "soft": 0.38, "bright": Color(0.80, 0.84, 0.66), "shade": Color(0.36, 0.42, 0.30), "opacity": 0.90, "dark": 0.25, "alt": 0.40},
		"zenith": Color(0.40, 0.50, 0.38), "horizon": Color(0.72, 0.76, 0.52),
	},
	"radioactive": {
		"rayleigh": Vector3(0.085, 0.115, 0.045), "mie": 0.18, "mie_color": Color(1.0, 0.92, 0.30), "mie_g": 0.66, "mie_abs": 0.40,
		"sky_tint": Vector3(3.8, 3.0, 1.5), "sky_sat": 1.05,
		"h_m": 0.20, "sun_gain": 1.1,
		"glow": Color(0.90, 1.0, 0.15), "glow_amount": 0.10, "glow_h": 0.10,
		"night_glow": Color(0.040, 0.055, 0.010),
		"amb_day": Color(0.78, 0.76, 0.34), "amb_dusk": Color(0.70, 0.48, 0.20), "amb_night": Color(0.080, 0.090, 0.030),
		"cloud": {"cover": 0.55, "soft": 0.30, "bright": Color(0.98, 0.95, 0.55), "shade": Color(0.50, 0.48, 0.22), "opacity": 0.85, "emit": Color(0.30, 0.38, 0.02)},
		"zenith": Color(0.62, 0.62, 0.28), "horizon": Color(0.95, 0.90, 0.40),
	},
	"gas": {
		"rayleigh": Vector3(0.12, 0.17, 0.30), "mie": 0.30, "mie_color": Color(1.0, 0.86, 0.66), "mie_g": 0.50, "mie_abs": 0.15,
		"h_r": 0.30, "h_m": 0.22, "sun_gain": 0.9,
		"amb_day": Color(0.95, 0.75, 0.55), "amb_night": Color(0.08, 0.06, 0.05),
		"cloud": {"cover": 0.0},
		"zenith": Color(0.90, 0.70, 0.50), "horizon": Color(0.95, 0.78, 0.55),
	},
}

## OCEAN / LIQUID looks keyed by def.ocean_kind ("water" | "lava" | "acid"), optionally refined per biome in OCEAN_BIOME.
const OCEAN_KIND := {
	"water": {"shallow": Color(0.10, 0.62, 0.66), "deep": Color(0.010, 0.075, 0.190), "foam": Color(0.95, 0.98, 1.0), "absorb": Vector3(0.42, 0.075, 0.045),
		"clarity": 0.22, "wave": 1.0, "glow": 0.0, "spec": 1.0},
	"lava": {"shallow": Color(1.0, 0.42, 0.06), "deep": Color(0.45, 0.04, 0.0), "foam": Color(1.0, 0.82, 0.30), "absorb": Vector3(4.0, 4.0, 4.0),
		"clarity": 5.0, "wave": 0.25, "glow": 1.0, "spec": 0.4},
	"acid": {"shallow": Color(0.52, 0.95, 0.12), "deep": Color(0.06, 0.28, 0.04), "foam": Color(0.85, 1.0, 0.45), "absorb": Vector3(0.9, 0.12, 0.35),
		"clarity": 0.85, "wave": 0.55, "glow": 0.55, "spec": 0.7},
}
const OCEAN_BIOME := {
	"ocean": {"shallow": Color(0.06, 0.78, 0.72), "deep": Color(0.0, 0.10, 0.26), "clarity": 0.16, "wave": 1.25},
	"lush": {"shallow": Color(0.12, 0.60, 0.58), "deep": Color(0.01, 0.08, 0.18)},
	"swamp": {"shallow": Color(0.30, 0.38, 0.17), "deep": Color(0.07, 0.10, 0.05), "clarity": 1.2, "wave": 0.45, "absorb": Vector3(0.9, 0.5, 0.9)},
	"toxic": {"shallow": Color(0.58, 1.0, 0.14), "deep": Color(0.07, 0.30, 0.05)},
	"volcanic": {"shallow": Color(1.0, 0.44, 0.05), "deep": Color(0.50, 0.05, 0.0)},
}

## ---------------------------------------------------------------------------------------------------------------------------------------------
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k in over:
		if over[k] is Dictionary and out.get(k) is Dictionary:
			var sub: Dictionary = out[k]
			for kk in over[k]:
				sub[kk] = over[k][kk]
		else:
			out[k] = over[k]
	return out

static func _hue_shift(c: Color, dh: float) -> Color:
	var h := fposmod(c.h + dh, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)

## Resolved profile for a body: biome table merged on BASE, with a small deterministic per-planet variation (hue / density) from def.palette_seed.
static func get_profile(biome: String, def: BodyDef = null) -> Dictionary:
	var id := biome if PROFILES.has(biome) else "lush"
	var p: Dictionary = _merge(BASE, PROFILES[id])
	p["biome"] = id
	if def != null:
		var s: int = def.palette_seed
		var hue_span := 0.05
		match id:
			"exotic": hue_span = 0.22
			"toxic", "radioactive": hue_span = 0.05
			"desert", "volcanic": hue_span = 0.025
			"lush", "ocean": hue_span = 0.015
			"gas": hue_span = 0.0
		var dh := (SeedUtil.rand01(s, 11) - 0.5) * 2.0 * hue_span
		var dens := 0.85 + SeedUtil.rand01(s, 12) * 0.35
		var r: Vector3 = p["rayleigh"]
		var rc := Color(r.x, r.y, r.z)
		var mx := maxf(r.x, maxf(r.y, r.z))
		var nc := _hue_shift(Color(rc.r / mx, rc.g / mx, rc.b / mx), dh)
		# keep brightness, rotate hue only
		var lum_old := rc.r / mx * 0.3 + rc.g / mx * 0.59 + rc.b / mx * 0.11
		var lum_new := nc.r * 0.3 + nc.g * 0.59 + nc.b * 0.11
		var k := lum_old / maxf(lum_new, 0.001)
		p["rayleigh"] = Vector3(nc.r, nc.g, nc.b) * k * mx * dens
		p["mie"] = float(p["mie"]) * (0.85 + SeedUtil.rand01(s, 13) * 0.3)
		for key in ["amb_day", "amb_dusk", "amb_night", "zenith", "horizon", "mie_color"]:
			p[key] = _hue_shift(p[key], dh)
		var cl: Dictionary = p["cloud"]
		cl["cover"] = clampf(float(cl["cover"]) + (SeedUtil.rand01(s, 14) - 0.5) * 0.18, 0.0, 0.95)
		p["aurora_a"] = _hue_shift(p["aurora_a"], (SeedUtil.rand01(s, 15) - 0.5) * 0.4)
		p["aurora_b"] = _hue_shift(p["aurora_b"], (SeedUtil.rand01(s, 16) - 0.5) * 0.4)
	return p

## liquid look for a body (def.ocean_kind), biome refined, with per-planet variation
static func get_ocean(def: BodyDef) -> Dictionary:
	var kind := def.ocean_kind if OCEAN_KIND.has(def.ocean_kind) else "water"
	var o: Dictionary = OCEAN_KIND[kind].duplicate(true)
	if OCEAN_BIOME.has(def.biome):
		for k in OCEAN_BIOME[def.biome]:
			o[k] = OCEAN_BIOME[def.biome][k]
	o["kind"] = kind
	var dh := (SeedUtil.rand01(def.palette_seed, 21) - 0.5) * (0.06 if kind == "water" else 0.03)
	o["shallow"] = _hue_shift(o["shallow"], dh)
	o["deep"] = _hue_shift(o["deep"], dh)
	return o

## ---------------------------------------------------------------------------------------------------------------------------------------------
## coefficients (per metre) for a body: returns {beta_r: Vector3, beta_m: Vector3, beta_m_ext: Vector3, h_r, h_m, top}
static func coefficients(prof: Dictionary, atmo_h: float) -> Dictionary:
	var hr := maxf(atmo_h * float(prof["h_r"]), 1.0)
	var hm := maxf(atmo_h * float(prof["h_m"]), 1.0)
	var r: Vector3 = prof["rayleigh"]
	var mc: Color = prof["mie_color"]
	var tm: float = float(prof["mie"]) * MIE_SCALE
	var bm := Vector3(mc.r, mc.g, mc.b) * (tm / hm)
	return {"beta_r": r * RAY_SCALE / hr, "beta_m": bm, "beta_m_ext": bm * (1.0 + float(prof["mie_abs"])), "h_r": hr, "h_m": hm, "top": atmo_h * TOP_MULT}

## Transmittance (rgb 0..1) of sunlight arriving at planet-relative position p (metres) from unit direction sd (towards the star).
## Only atmospheric extinction (no planet-body occlusion: SkyController handles that with the disc-overlap test).
static func sun_transmittance(prof: Dictionary, coef: Dictionary, radius: float, p: Vector3, sd: Vector3) -> Vector3:
	var top: float = radius + float(coef["top"])
	var b := p.dot(sd)
	var c := p.dot(p) - top * top
	var disc := b * b - c
	if disc <= 0.0:
		return Vector3.ONE
	var sq := sqrt(disc)
	var t0 := maxf(-b - sq, 0.0)
	var t1 := -b + sq
	if t1 <= t0:
		return Vector3.ONE
	var n := 14
	var dt := (t1 - t0) / float(n)
	var od_r := 0.0
	var od_m := 0.0
	var hr: float = coef["h_r"]
	var hm: float = coef["h_m"]
	var h0 := maxf(p.length() - radius, -400.0)
	for i in n:
		var t := t0 + (float(i) + 0.5) * dt
		var q := p + sd * t
		var h := maxf(q.length() - radius, 0.0)
		od_r += exp(-h / hr) * dt
		od_m += exp(-h / hm) * dt
	var br: Vector3 = coef["beta_r"]
	var bme: Vector3 = coef["beta_m_ext"]
	# slant excess over the vertical path is boosted (identical to light_boost in atmosphere_common.gdshaderinc)
	var v_r := hr * exp(-h0 / hr)
	var v_m := hm * exp(-h0 / hm)
	od_r = v_r + maxf(od_r - v_r, 0.0) * LIGHT_BOOST
	od_m = v_m + maxf(od_m - v_m, 0.0) * LIGHT_BOOST
	var tau := br * od_r + bme * od_m
	return Vector3(exp(-tau.x), exp(-tau.y), exp(-tau.z))

## visible fraction (0..1) of a disc of angular radius a_s (the star) whose centre is at angular distance `theta` from the centre of a disc of
## angular radius a_b (an occluding body). All angles in radians.
static func disc_visible(theta: float, a_s: float, a_b: float) -> float:
	if theta >= a_b + a_s:
		return 1.0
	if theta <= a_b - a_s:
		return 0.0
	var f := (theta - (a_b - a_s)) / maxf(2.0 * a_s, 1e-6)
	return f * f * (3.0 - 2.0 * f)
