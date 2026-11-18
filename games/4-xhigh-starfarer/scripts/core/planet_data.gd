class_name PlanetData
extends RefCounted
## Everything that defines a planet/moon. Fully derived from (biome, seed) so a planet is identical on every visit.

enum Biome { LUSH, DESERT, FROZEN, VOLCANIC, TOXIC, BARREN, EXOTIC, GAS }
const BIOME_NAMES := ["Lush", "Arid", "Frozen", "Volcanic", "Toxic", "Barren", "Exotic", "Gas Giant"]
enum Liquid { NONE, WATER, LAVA, ACID }

var name := ""
var seed := 0
var biome: int = Biome.LUSH
var radius := 5000.0
var gravity := 9.0
var spin_period := 1500.0
var axial_tilt := 0.3
var orbit_radius := 0.0
var orbit_period := 3600.0
var orbit_phase := 0.0
var orbit_incl := 0.0
var parent_idx := -1
var landable := true
var index := 0

# atmosphere
var atmo_height := 0.0          # 0 = vacuum
var atmo_beta := Vector3(6.0e-5, 1.4e-4, 3.6e-4)
var atmo_mie := 3.0e-5
var atmo_haze := Color(0.7, 0.8, 1.0)
var atmo_density := 1.0
var fog_density := 0.0004
var sky_night_boost := 1.0

# liquids
var liquid: int = Liquid.NONE
var sea_level := -1.0e9
var liquid_color := Color(0.05, 0.25, 0.35)
var liquid_deep := Color(0.01, 0.06, 0.12)

# terrain params (names mirror the shader uniforms)
var t_freq := 2.0
var t_seed_off := Vector3.ZERO
var t_a_cont := 100.0
var t_a_hill := 150.0
var t_hill_oct := 8
var t_hill_gain := 0.5
var t_a_ridge := 0.0
var t_ridge_freq := 1.0
var t_ridge_lo := 0.05
var t_ridge_hi := 0.45
var t_ridge_oct := 5
var t_a_dune := 0.0
var t_dune_freq := 16.0
var t_a_crater := 0.0
var t_crater_freq := 2.5
var t_a_detail := 2.0
var t_detail_cell := 24.0
var t_terrace := 0.0
var t_terrace_step := 30.0

# palette
var pal: Dictionary = {}
var h_ref := 300.0               # nominal terrain amplitude used for colour bands
var snow_line := 1e9
var patch_strength := 0.5
var grain := 0.25

# life / props
var flora: Array = []
var resources: Array = []
var weather := "none"
var weather_color := Color(1, 1, 1)
var storm_chance := 0.0
var cloud_cover := 0.0
var cloud_color := Color(1, 1, 1)
var hazard := ""                  # "", "heat", "cold", "toxic", "radiation"
var hazard_level := 0.0           # 0..1 drain multiplier
var temperature := 15.0
var fauna: Array = []
var has_rings := false
var ring_inner := 1.4
var ring_outer := 2.4
var ring_color := Color(0.8, 0.7, 0.55)
var gas_colors: Array = []
var landing_site_dir := Vector3.UP
var poi_count := 6


func is_gas() -> bool:
	return biome == Biome.GAS


## --- terrain height. Twin of terrain_height() in shaders/inc/tnoise.gdshaderinc ---
func height_at(dir: Vector3, spacing: float = 0.0) -> float:
	var px := dir.x * t_freq + t_seed_off.x
	var py := dir.y * t_freq + t_seed_off.y
	var pz := dir.z * t_freq + t_seed_off.z
	var cell0 := radius / (t_freq * 3.0)
	var lod_oct := int(floorf(log(maxf(cell0 / (2.0 * maxf(spacing, 0.01)), 1.0)) / log(2.0))) + 1
	var sd := seed
	var h := t_a_cont * TNoise.fbm(px * 0.5, py * 0.5, pz * 0.5, 3, 0.5, sd)
	h += t_a_hill * TNoise.fbm(px * 3.0 + 3.1, py * 3.0 + 3.1, pz * 3.0 + 3.1, mini(t_hill_oct, lod_oct), t_hill_gain, sd + 1)
	if t_a_ridge > 0.0:
		var m := TNoise.smooth(t_ridge_lo, t_ridge_hi, TNoise.fbm(px * 1.3 + 7.7, py * 1.3 + 7.7, pz * 1.3 + 7.7, 2, 0.5, sd + 2))
		if m > 0.0:
			h += t_a_ridge * m * TNoise.ridged(px * t_ridge_freq + 5.5, py * t_ridge_freq + 5.5, pz * t_ridge_freq + 5.5, mini(t_ridge_oct, lod_oct), sd + 3)
	if t_a_dune > 0.0:
		var qx := px * t_dune_freq
		var qy := py * t_dune_freq
		var qz := pz * t_dune_freq
		var w := TNoise.fbm(qx * 0.35, qy * 0.35, qz * 0.35, 2, 0.5, sd + 4)
		var d := 1.0 - absf(sin(qx + qy * 0.35 + w * 3.0))
		h += t_a_dune * d * d * (0.55 + 0.45 * TNoise.fbm(px * 0.9, py * 0.9, pz * 0.9, 2, 0.5, sd + 6))
	if t_a_crater > 0.0:
		var qx2 := px * t_crater_freq
		var qy2 := py * t_crater_freq
		var qz2 := pz * t_crater_freq
		h += t_a_crater * (TNoise.craters(qx2, qy2, qz2, sd + 7) + 0.5 * TNoise.craters(qx2 * 3.7 + 40.0, qy2 * 3.7 + 40.0, qz2 * 3.7 + 40.0, sd + 8))
	if t_a_detail > 0.0:
		var fade := clampf(1.0 - (2.0 * spacing / t_detail_cell - 0.4), 0.0, 1.0)
		if fade > 0.0:
			var k := radius / t_detail_cell
			h += t_a_detail * fade * TNoise.fbm(dir.x * k + t_seed_off.x * 2.0, dir.y * k + t_seed_off.y * 2.0, dir.z * k + t_seed_off.z * 2.0, 3, 0.5, sd + 5)
	if t_terrace > 0.0:
		var qq := h / t_terrace_step
		h = lerpf(h, (floorf(qq) + TNoise.smooth(0.35, 0.65, qq - floorf(qq))) * t_terrace_step, t_terrace)
	return h


func surface_radius_at(dir: Vector3) -> float:
	return radius + height_at(dir)


## unit normal of the terrain at `dir` (finite difference on the CPU height function)
func normal_at(dir: Vector3, eps_m: float = 1.2) -> Vector3:
	var t1 := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := dir.cross(t1)
	var e := eps_m / radius
	var d1 := (dir + t1 * e).normalized()
	var d2 := (dir + t2 * e).normalized()
	var p0 := dir * (radius + height_at(dir))
	var p1 := d1 * (radius + height_at(d1))
	var p2 := d2 * (radius + height_at(d2))
	var n := (p1 - p0).cross(p2 - p0).normalized()
	if n.dot(dir) < 0.0:
		n = -n
	return n


func liquid_radius() -> float:
	return radius + sea_level


func has_liquid() -> bool:
	return liquid != Liquid.NONE and sea_level > -1.0e8


func terrain_uniforms() -> Dictionary:
	return {
		"t_radius": radius, "t_freq": t_freq, "t_seed_off": t_seed_off, "t_seed": seed,
		"t_a_cont": t_a_cont, "t_a_hill": t_a_hill, "t_hill_oct": t_hill_oct, "t_hill_gain": t_hill_gain,
		"t_a_ridge": t_a_ridge, "t_ridge_freq": t_ridge_freq, "t_ridge_lo": t_ridge_lo, "t_ridge_hi": t_ridge_hi, "t_ridge_oct": t_ridge_oct,
		"t_a_dune": t_a_dune, "t_dune_freq": t_dune_freq, "t_a_crater": t_a_crater, "t_crater_freq": t_crater_freq,
		"t_a_detail": t_a_detail, "t_detail_cell": t_detail_cell, "t_terrace": t_terrace, "t_terrace_step": t_terrace_step,
	}


func biome_name() -> String:
	return BIOME_NAMES[biome]


func hazard_text() -> String:
	match hazard:
		"heat": return "EXTREME HEAT %d°C" % int(temperature)
		"cold": return "EXTREME COLD %d°C" % int(temperature)
		"toxic": return "TOXIC ATMOSPHERE"
		"radiation": return "RADIATION"
	return "HOSPITABLE %d°C" % int(temperature) if atmo_height > 0.0 else "VACUUM %d°C" % int(temperature)
