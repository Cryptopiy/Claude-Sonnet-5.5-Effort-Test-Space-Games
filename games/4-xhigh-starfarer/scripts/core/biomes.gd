class_name Biomes
extends RefCounted
## Biome templates. make() fills a PlanetData from (biome, seed). Pure data + seeded randomness.

static func _c(r: float, g: float, b: float) -> Color:
	return Color(r, g, b)


static func make(biome: int, seed: int, radius: float, pname: String) -> PlanetData:
	var p := PlanetData.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + biome * 104729 + 17
	p.name = pname
	p.seed = seed & 0x7FFFFFF
	p.biome = biome
	p.radius = radius
	p.t_seed_off = Vector3(rng.randf_range(-50, 50), rng.randf_range(-50, 50), rng.randf_range(-50, 50))
	p.gravity = clampf(2.4 + radius / 720.0, 2.6, 12.5)
	p.spin_period = rng.randf_range(900.0, 1700.0)
	p.axial_tilt = rng.randf_range(0.05, 0.45)
	p.orbit_phase = rng.randf() * TAU
	p.orbit_incl = rng.randf_range(-0.05, 0.05)
	p.t_hill_oct = 8
	p.t_a_detail = 2.0
	var v := rng.randf_range(0.85, 1.2)   # per-planet variation of amplitudes
	match biome:
		PlanetData.Biome.LUSH: _lush(p, rng, v)
		PlanetData.Biome.DESERT: _desert(p, rng, v)
		PlanetData.Biome.FROZEN: _frozen(p, rng, v)
		PlanetData.Biome.VOLCANIC: _volcanic(p, rng, v)
		PlanetData.Biome.TOXIC: _toxic(p, rng, v)
		PlanetData.Biome.BARREN: _barren(p, rng, v)
		PlanetData.Biome.EXOTIC: _exotic(p, rng, v)
		PlanetData.Biome.GAS: _gas(p, rng, v)
	p.landable = biome != PlanetData.Biome.GAS
	return p


static func _F(m: String, d: float, s0: float, s1: float, o: Dictionary = {}) -> Dictionary:
	var f := {"m": m, "d": d, "s0": s0, "s1": s1, "slope": 0.82, "tier": 0, "cr": 0.0, "ch": 0.0, "clump": 0.0, "lift": -0.15, "tint": {}}
	for k in o:
		f[k] = o[k]
	return f


static func _lush(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.0
	p.t_a_cont = 120.0 * v
	p.t_a_hill = 190.0 * v
	p.t_hill_gain = 0.52
	p.t_a_ridge = 300.0 * v
	p.t_ridge_lo = 0.08
	p.t_ridge_hi = 0.5
	p.t_a_detail = 2.8
	p.h_ref = 300.0
	p.snow_line = 330.0
	p.sea_level = -42.0
	p.liquid = PlanetData.Liquid.WATER
	p.liquid_color = _c(0.04, 0.32, 0.38)
	p.liquid_deep = _c(0.0, 0.07, 0.14)
	p.pal = {"shore": _c(0.74, 0.68, 0.46), "low": _c(0.13, 0.37, 0.12), "mid": _c(0.24, 0.45, 0.15), "high": _c(0.42, 0.38, 0.30),
		"peak": _c(0.93, 0.95, 1.0), "slope": _c(0.36, 0.32, 0.27), "acc": _c(0.44, 0.48, 0.15), "deep": _c(0.55, 0.52, 0.38)}
	p.patch_strength = 0.55
	p.atmo_height = 1500.0
	p.atmo_beta = Vector3(9.35e-05, 2.21e-04, 5.78e-04)
	p.atmo_mie = 2.5e-5
	p.atmo_haze = _c(0.62, 0.78, 1.0)
	p.fog_density = 0.00028
	p.cloud_cover = 0.5
	p.cloud_color = _c(1, 1, 1)
	p.weather = "rain"
	p.storm_chance = 0.25
	p.weather_color = _c(0.7, 0.8, 1.0)
	p.hazard = ""
	p.temperature = 21.0
	var leaf := {"leaf_a": _c(0.17, 0.52, 0.2), "leaf_b": _c(0.30, 0.66, 0.26)}
	var leaf2 := {"leaf_c": _c(0.85, 0.35, 0.5), "leaf_b": _c(0.35, 0.7, 0.35)}
	p.flora = [
		_F("tree_lush", 2.4, 0.8, 1.5, {"cr": 0.9, "ch": 10.0, "clump": 1.0, "tint": leaf, "slope": 0.86}),
		_F("tree_umbrella", 0.9, 0.8, 1.3, {"cr": 0.6, "ch": 13.0, "clump": 0.7, "tint": leaf2, "slope": 0.88}),
		_F("bush", 3.5, 0.8, 1.6, {"tier": 1, "clump": 0.6, "tint": leaf}),
		_F("flower_glow", 3.0, 0.8, 1.6, {"tier": 1, "clump": 0.8}),
		_F("grass_tuft", 70.0, 0.7, 1.4, {"tier": 1, "clump": 0.5, "tint": {"leaf_a": _c(0.22, 0.55, 0.18), "leaf_b": _c(0.35, 0.68, 0.22)}, "slope": 0.7}),
		_F("rock_a", 0.8, 0.5, 1.4, {"cr": 2.0, "ch": 1.5, "tint": {"rock": _c(0.5, 0.48, 0.44), "rock_light": _c(0.62, 0.6, 0.55)}}),
		_F("rock_b", 0.4, 0.6, 1.3, {"cr": 2.6, "ch": 1.0}),
		_F("pebbles", 14.0, 0.7, 1.2, {"tier": 1}),
	]
	p.resources = [{"name": "Carbon", "color": _c(0.25, 0.9, 0.35)}, {"name": "Ferrite Dust", "color": _c(0.9, 0.55, 0.3)}, {"name": "Sodium", "color": _c(1.0, 0.9, 0.3)}]
	p.fauna = ["creature_strider", "creature_flyer", "creature_floater"]


static func _desert(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.2
	p.t_a_cont = 70.0 * v
	p.t_a_hill = 70.0 * v
	p.t_hill_gain = 0.5
	p.t_a_ridge = 260.0 * v
	p.t_ridge_lo = 0.0
	p.t_ridge_hi = 0.4
	p.t_a_dune = 42.0 * v
	p.t_dune_freq = 22.0
	p.t_a_detail = 2.0
	p.t_terrace = 0.65
	p.t_terrace_step = 34.0
	p.h_ref = 260.0
	p.snow_line = 1e9
	p.pal = {"shore": _c(0.86, 0.66, 0.40), "low": _c(0.82, 0.58, 0.34), "mid": _c(0.74, 0.46, 0.27), "high": _c(0.62, 0.34, 0.22),
		"peak": _c(0.86, 0.72, 0.52), "slope": _c(0.52, 0.30, 0.20), "acc": _c(0.92, 0.74, 0.46), "deep": _c(0.8, 0.6, 0.38)}
	p.patch_strength = 0.6
	p.atmo_height = 1400.0
	p.atmo_beta = Vector3(5.10e-04, 2.21e-04, 8.50e-05)
	p.atmo_mie = 9.0e-5
	p.atmo_haze = _c(0.95, 0.72, 0.5)
	p.fog_density = 0.00055
	p.cloud_cover = 0.1
	p.cloud_color = _c(1.0, 0.9, 0.8)
	p.weather = "dust"
	p.storm_chance = 0.4
	p.weather_color = _c(0.9, 0.65, 0.4)
	p.hazard = "heat"
	p.hazard_level = 0.55
	p.temperature = 58.0
	p.flora = [
		_F("cactus", 0.8, 0.8, 1.6, {"cr": 0.6, "ch": 7.0, "clump": 0.8, "slope": 0.85}),
		_F("tree_dead", 0.35, 0.8, 1.4, {"cr": 0.5, "ch": 6.0, "clump": 0.4}),
		_F("hoodoo", 0.18, 0.8, 1.8, {"cr": 2.4, "ch": 10.0, "clump": 0.6}),
		_F("rock_arch", 0.05, 1.2, 2.2, {"cr": 0.0, "ch": 0.0}),
		_F("rock_c", 0.5, 0.6, 1.6, {"cr": 1.3, "ch": 3.0, "tint": {"rock": _c(0.72, 0.5, 0.34), "rock_light": _c(0.82, 0.62, 0.42)}}),
		_F("rock_a", 0.7, 0.5, 1.3, {"cr": 2.0, "ch": 1.5, "tint": {"rock": _c(0.7, 0.48, 0.32), "rock_light": _c(0.8, 0.6, 0.4)}}),
		_F("bush", 1.2, 0.6, 1.1, {"tier": 1, "clump": 0.7, "tint": {"leaf_a": _c(0.45, 0.42, 0.18), "leaf_b": _c(0.58, 0.5, 0.22)}}),
		_F("pebbles", 20.0, 0.7, 1.3, {"tier": 1, "tint": {"rock": _c(0.7, 0.5, 0.34), "rock_light": _c(0.8, 0.62, 0.42)}}),
	]
	p.resources = [{"name": "Sodium Nitrate", "color": _c(1.0, 0.85, 0.35)}, {"name": "Cobalt", "color": _c(0.3, 0.5, 1.0)}, {"name": "Silicate", "color": _c(0.9, 0.75, 0.6)}]
	p.fauna = ["creature_strider", "creature_flyer"]


static func _frozen(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.0
	p.t_a_cont = 110.0 * v
	p.t_a_hill = 95.0 * v
	p.t_hill_gain = 0.46
	p.t_a_ridge = 230.0 * v
	p.t_ridge_lo = 0.1
	p.t_ridge_hi = 0.5
	p.t_ridge_oct = 5
	p.t_a_detail = 1.6
	p.h_ref = 260.0
	p.snow_line = -1000.0
	p.pal = {"shore": _c(0.78, 0.88, 0.97), "low": _c(0.90, 0.95, 1.0), "mid": _c(0.80, 0.9, 0.98), "high": _c(0.62, 0.72, 0.86),
		"peak": _c(0.97, 0.98, 1.0), "slope": _c(0.46, 0.54, 0.68), "acc": _c(0.65, 0.8, 0.95), "deep": _c(0.6, 0.78, 0.92)}
	p.patch_strength = 0.5
	p.atmo_height = 1400.0
	p.atmo_beta = Vector3(1.27e-04, 2.55e-04, 4.42e-04)
	p.atmo_mie = 6.0e-5
	p.atmo_haze = _c(0.75, 0.85, 0.95)
	p.fog_density = 0.0005
	p.cloud_cover = 0.7
	p.cloud_color = _c(0.92, 0.95, 1.0)
	p.weather = "snow"
	p.storm_chance = 0.45
	p.weather_color = _c(1, 1, 1)
	p.hazard = "cold"
	p.hazard_level = 0.6
	p.temperature = -62.0
	p.sea_level = -60.0
	p.liquid = PlanetData.Liquid.WATER
	p.liquid_color = _c(0.35, 0.6, 0.75)
	p.liquid_deep = _c(0.05, 0.2, 0.32)
	p.flora = [
		_F("tree_pine", 1.0, 0.8, 1.5, {"cr": 0.6, "ch": 10.0, "clump": 0.9, "slope": 0.85}),
		_F("ice_spire", 0.5, 0.8, 1.7, {"cr": 1.0, "ch": 7.0, "clump": 0.7}),
		_F("crystal_cluster", 0.25, 0.7, 1.4, {"cr": 1.4, "ch": 3.0, "tint": {"crystal": _c(0.55, 0.85, 1.0)}}),
		_F("rock_b", 0.5, 0.6, 1.5, {"cr": 2.6, "ch": 1.0, "tint": {"rock": _c(0.55, 0.6, 0.68), "rock_light": _c(0.7, 0.76, 0.84)}}),
		_F("rock_c", 0.35, 0.6, 1.4, {"cr": 1.3, "ch": 3.0, "tint": {"rock": _c(0.52, 0.57, 0.66), "rock_light": _c(0.7, 0.75, 0.84)}}),
		_F("pebbles", 12.0, 0.7, 1.2, {"tier": 1, "tint": {"rock": _c(0.6, 0.66, 0.74), "rock_light": _c(0.8, 0.85, 0.92)}}),
	]
	p.resources = [{"name": "Frost Crystal", "color": _c(0.5, 0.85, 1.0)}, {"name": "Platinum", "color": _c(0.8, 0.85, 0.95)}, {"name": "Dioxite", "color": _c(0.6, 0.7, 1.0)}]
	p.fauna = ["creature_strider", "creature_flyer"]


static func _volcanic(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.1
	p.t_a_cont = 110.0 * v
	p.t_a_hill = 150.0 * v
	p.t_hill_gain = 0.56
	p.t_a_ridge = 420.0 * v
	p.t_ridge_lo = -0.25
	p.t_ridge_hi = 0.3
	p.t_ridge_oct = 6
	p.t_a_crater = 30.0
	p.t_crater_freq = 3.0
	p.t_a_detail = 5.0
	p.t_detail_cell = 18.0
	p.h_ref = 360.0
	p.snow_line = 1e9
	p.sea_level = -75.0
	p.liquid = PlanetData.Liquid.LAVA
	p.liquid_color = _c(1.0, 0.32, 0.04)
	p.liquid_deep = _c(0.7, 0.1, 0.0)
	p.pal = {"shore": _c(0.05, 0.045, 0.05), "low": _c(0.08, 0.065, 0.065), "mid": _c(0.16, 0.10, 0.09), "high": _c(0.27, 0.19, 0.17),
		"peak": _c(0.36, 0.30, 0.28), "slope": _c(0.06, 0.05, 0.055), "acc": _c(0.3, 0.1, 0.06), "deep": _c(0.04, 0.03, 0.03)}
	p.patch_strength = 0.6
	p.atmo_height = 1600.0
	p.atmo_beta = Vector3(7.14e-04, 1.87e-04, 6.80e-05)
	p.atmo_mie = 2.2e-4
	p.atmo_haze = _c(0.75, 0.3, 0.15)
	p.fog_density = 0.0009
	p.cloud_cover = 0.8
	p.cloud_color = _c(0.25, 0.18, 0.16)
	p.weather = "ash"
	p.storm_chance = 0.3
	p.weather_color = _c(0.4, 0.35, 0.33)
	p.hazard = "heat"
	p.hazard_level = 1.0
	p.temperature = 96.0
	p.flora = [
		_F("lava_spike", 0.9, 0.9, 1.9, {"cr": 1.1, "ch": 6.0, "clump": 0.8}),
		_F("vent_cone", 0.18, 1.0, 2.2, {"cr": 2.6, "ch": 2.0}),
		_F("tree_dead", 0.35, 0.8, 1.3, {"cr": 0.5, "ch": 6.0, "clump": 0.5, "tint": {"bark_pale": _c(0.14, 0.11, 0.1)}}),
		_F("rock_a", 1.0, 0.5, 1.5, {"cr": 2.0, "ch": 1.5, "tint": {"rock": _c(0.12, 0.1, 0.1), "rock_light": _c(0.2, 0.15, 0.14)}}),
		_F("rock_c", 0.6, 0.6, 1.5, {"cr": 1.3, "ch": 3.0, "tint": {"rock": _c(0.1, 0.08, 0.08), "rock_light": _c(0.18, 0.13, 0.12)}}),
		_F("pebbles", 25.0, 0.7, 1.3, {"tier": 1, "tint": {"rock": _c(0.12, 0.1, 0.1), "rock_light": _c(0.2, 0.16, 0.14)}}),
	]
	p.resources = [{"name": "Pyrite", "color": _c(1.0, 0.7, 0.15)}, {"name": "Obsidian", "color": _c(0.6, 0.3, 1.0)}, {"name": "Magnetized Ferrite", "color": _c(1.0, 0.4, 0.2)}]
	p.fauna = ["creature_flyer"]


static func _toxic(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.0
	p.t_a_cont = 80.0 * v
	p.t_a_hill = 85.0 * v
	p.t_hill_gain = 0.5
	p.t_a_ridge = 90.0 * v
	p.t_ridge_lo = 0.2
	p.t_ridge_hi = 0.6
	p.t_a_detail = 3.0
	p.h_ref = 200.0
	p.snow_line = 1e9
	p.sea_level = -8.0
	p.liquid = PlanetData.Liquid.ACID
	p.liquid_color = _c(0.35, 0.8, 0.12)
	p.liquid_deep = _c(0.1, 0.35, 0.05)
	p.pal = {"shore": _c(0.38, 0.34, 0.14), "low": _c(0.25, 0.32, 0.12), "mid": _c(0.34, 0.30, 0.18), "high": _c(0.35, 0.22, 0.32),
		"peak": _c(0.5, 0.4, 0.5), "slope": _c(0.25, 0.18, 0.22), "acc": _c(0.5, 0.2, 0.55), "deep": _c(0.18, 0.2, 0.08)}
	p.patch_strength = 0.7
	p.atmo_height = 1500.0
	p.atmo_beta = Vector3(2.38e-04, 5.44e-04, 1.36e-04)
	p.atmo_mie = 1.4e-4
	p.atmo_haze = _c(0.55, 0.75, 0.25)
	p.fog_density = 0.0012
	p.cloud_cover = 0.75
	p.cloud_color = _c(0.6, 0.75, 0.35)
	p.weather = "spores"
	p.storm_chance = 0.35
	p.weather_color = _c(0.6, 1.0, 0.4)
	p.hazard = "toxic"
	p.hazard_level = 0.8
	p.temperature = 34.0
	p.flora = [
		_F("mushroom_giant", 0.5, 0.8, 1.6, {"cr": 1.0, "ch": 9.0, "clump": 0.9, "tint": {"mush_cap": _c(0.5, 0.15, 0.6)}}),
		_F("spore_pod", 0.9, 0.8, 1.5, {"cr": 1.0, "ch": 3.0, "clump": 0.8}),
		_F("coral_tower", 0.3, 0.8, 1.4, {"cr": 0.8, "ch": 5.0, "clump": 0.6, "tint": {"mush_cap": _c(0.3, 0.55, 0.3)}}),
		_F("tree_dead", 0.3, 0.8, 1.3, {"cr": 0.5, "ch": 6.0, "clump": 0.4, "tint": {"bark_pale": _c(0.3, 0.26, 0.2)}}),
		_F("mushroom_small", 4.0, 0.8, 1.6, {"tier": 1, "clump": 0.9}),
		_F("rock_a", 0.4, 0.5, 1.3, {"cr": 2.0, "ch": 1.5, "tint": {"rock": _c(0.34, 0.3, 0.26), "rock_light": _c(0.44, 0.4, 0.34)}}),
		_F("grass_tuft", 30.0, 0.7, 1.3, {"tier": 1, "clump": 0.6, "tint": {"leaf_a": _c(0.4, 0.5, 0.1), "leaf_b": _c(0.6, 0.7, 0.15)}, "slope": 0.7}),
	]
	p.resources = [{"name": "Radon", "color": _c(0.5, 1.0, 0.3)}, {"name": "Sulphurine", "color": _c(1.0, 0.95, 0.3)}, {"name": "Spore Gel", "color": _c(0.8, 0.4, 1.0)}]
	p.fauna = ["creature_floater", "creature_strider"]


static func _barren(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.4
	p.t_a_cont = 55.0 * v
	p.t_a_hill = 55.0 * v
	p.t_hill_gain = 0.5
	p.t_a_ridge = 120.0 * v
	p.t_ridge_lo = 0.1
	p.t_ridge_hi = 0.5
	p.t_a_crater = 85.0
	p.t_crater_freq = 2.4
	p.t_a_detail = 3.0
	p.h_ref = 160.0
	p.snow_line = 1e9
	p.gravity = 3.1
	p.pal = {"shore": _c(0.45, 0.45, 0.47), "low": _c(0.38, 0.38, 0.40), "mid": _c(0.5, 0.49, 0.5), "high": _c(0.62, 0.61, 0.6),
		"peak": _c(0.78, 0.78, 0.8), "slope": _c(0.3, 0.3, 0.32), "acc": _c(0.55, 0.5, 0.45), "deep": _c(0.3, 0.3, 0.32)}
	p.patch_strength = 0.5
	p.atmo_height = 0.0
	p.atmo_density = 0.0
	p.fog_density = 0.0
	p.cloud_cover = 0.0
	p.weather = "none"
	p.hazard = "cold"
	p.hazard_level = 0.35
	p.temperature = -48.0
	p.flora = [
		_F("rock_a", 1.4, 0.5, 1.8, {"cr": 2.0, "ch": 1.5, "tint": {"rock": _c(0.5, 0.5, 0.52), "rock_light": _c(0.62, 0.62, 0.64)}}),
		_F("rock_b", 0.7, 0.6, 1.6, {"cr": 2.6, "ch": 1.0, "tint": {"rock": _c(0.48, 0.48, 0.5), "rock_light": _c(0.6, 0.6, 0.62)}}),
		_F("rock_c", 0.8, 0.6, 1.7, {"cr": 1.3, "ch": 3.0, "tint": {"rock": _c(0.46, 0.46, 0.48), "rock_light": _c(0.6, 0.6, 0.62)}}),
		_F("crystal_cluster", 0.12, 0.8, 1.6, {"cr": 1.4, "ch": 3.0, "tint": {"crystal": _c(0.9, 0.7, 0.4)}}),
		_F("pebbles", 40.0, 0.6, 1.4, {"tier": 1, "tint": {"rock": _c(0.5, 0.5, 0.52), "rock_light": _c(0.62, 0.62, 0.64)}}),
	]
	p.resources = [{"name": "Helium-3", "color": _c(0.9, 0.9, 1.0)}, {"name": "Titanite", "color": _c(0.6, 0.7, 0.8)}, {"name": "Lunar Regolith", "color": _c(0.8, 0.75, 0.7)}]
	p.fauna = []


static func _exotic(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.t_freq = 2.1
	p.t_a_cont = 90.0 * v
	p.t_a_hill = 120.0 * v
	p.t_hill_gain = 0.5
	p.t_a_ridge = 340.0 * v
	p.t_ridge_lo = -0.1
	p.t_ridge_hi = 0.35
	p.t_ridge_oct = 4
	p.t_terrace = 0.35
	p.t_terrace_step = 45.0
	p.t_a_detail = 2.5
	p.h_ref = 300.0
	p.snow_line = 1e9
	p.sea_level = -55.0
	p.liquid = PlanetData.Liquid.WATER
	p.liquid_color = _c(0.55, 0.15, 0.7)
	p.liquid_deep = _c(0.12, 0.02, 0.25)
	p.pal = {"shore": _c(0.55, 0.42, 0.62), "low": _c(0.30, 0.18, 0.46), "mid": _c(0.18, 0.40, 0.52), "high": _c(0.55, 0.28, 0.58),
		"peak": _c(0.9, 0.7, 0.95), "slope": _c(0.22, 0.14, 0.32), "acc": _c(0.1, 0.6, 0.6), "deep": _c(0.25, 0.15, 0.4)}
	p.patch_strength = 0.8
	p.atmo_height = 1500.0
	p.atmo_beta = Vector3(4.76e-04, 1.36e-04, 5.78e-04)
	p.atmo_mie = 5.0e-5
	p.atmo_haze = _c(0.8, 0.5, 0.9)
	p.fog_density = 0.0005
	p.cloud_cover = 0.4
	p.cloud_color = _c(0.95, 0.75, 1.0)
	p.weather = "spores"
	p.storm_chance = 0.2
	p.weather_color = _c(0.9, 0.5, 1.0)
	p.hazard = "radiation"
	p.hazard_level = 0.45
	p.temperature = 12.0
	p.flora = [
		_F("crystal_cluster", 1.2, 0.9, 2.2, {"cr": 1.4, "ch": 4.0, "clump": 0.8, "tint": {"crystal": _c(0.85, 0.3, 0.95), "crystal_core": _c(1.0, 0.8, 1.0)}}),
		_F("coral_tower", 0.9, 0.9, 1.6, {"cr": 0.8, "ch": 5.0, "clump": 0.7, "tint": {"mush_cap": _c(0.15, 0.6, 0.65)}}),
		_F("flower_glow", 3.0, 0.8, 1.6, {"tier": 1, "clump": 0.8}),
		_F("spore_pod", 0.5, 0.8, 1.3, {"cr": 1.0, "ch": 3.0, "clump": 0.7, "tint": {"mush_cap": _c(0.45, 0.2, 0.75)}}),
		_F("tree_umbrella", 0.4, 0.8, 1.2, {"cr": 0.6, "ch": 13.0, "clump": 0.6, "tint": {"leaf_c": _c(0.2, 0.6, 0.8), "leaf_b": _c(0.5, 0.2, 0.7)}}),
		_F("rock_c", 0.5, 0.6, 1.5, {"cr": 1.3, "ch": 3.0, "tint": {"rock": _c(0.3, 0.22, 0.4), "rock_light": _c(0.4, 0.3, 0.5)}}),
		_F("pebbles", 12.0, 0.7, 1.2, {"tier": 1, "tint": {"rock": _c(0.35, 0.25, 0.45), "rock_light": _c(0.5, 0.4, 0.6)}}),
	]
	p.resources = [{"name": "Chromatic Metal", "color": _c(0.9, 0.3, 1.0)}, {"name": "Aether Shard", "color": _c(0.3, 1.0, 0.9)}, {"name": "Ionised Cobalt", "color": _c(0.4, 0.5, 1.0)}]
	p.fauna = ["creature_floater", "creature_strider", "creature_flyer"]


static func _gas(p: PlanetData, rng: RandomNumberGenerator, v: float) -> void:
	p.atmo_height = p.radius * 0.035
	p.atmo_beta = Vector3(1.70e-05, 3.40e-05, 8.50e-05)
	p.gravity = 22.0
	p.has_rings = true
	p.ring_inner = 1.45
	p.ring_outer = 2.35
	p.ring_color = _c(0.78, 0.66, 0.5)
	p.gas_colors = [_c(0.82, 0.62, 0.4), _c(0.92, 0.82, 0.62), _c(0.62, 0.4, 0.28), _c(0.95, 0.9, 0.8), _c(0.55, 0.36, 0.3)]
	p.pal = {"low": _c(0.82, 0.62, 0.4)}
	p.temperature = -140.0
	p.hazard = "toxic"
	p.hazard_level = 1.0
