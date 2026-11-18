class_name Biomes
extends RefCounted
## Biome definitions and the seeded planet factory.

const BIOME_NAMES := {
	"lush": "Lush", "desert": "Scorched Desert", "frozen": "Frozen", "volcanic": "Volcanic",
	"toxic": "Toxic", "barren": "Barren", "gas": "Gas Giant",
}

const BASE := {
	"lush": {
		"gravity": [8.0, 11.0], "temp": [16.0, 27.0], "hazard": 0.0, "atmo": true,
		"t": {"freq": [2.3, 3.0], "amp": [170.0, 240.0], "ridge": [0.3, 0.5], "mask": [0.7, 0.9], "terr": 0.0, "dune": 0.0, "crater": 0.0, "sea": -0.11},
		"low": Color(0.11, 0.27, 0.08), "mid": Color(0.2, 0.38, 0.1), "high": Color(0.42, 0.38, 0.27), "rock": Color(0.33, 0.3, 0.26), "beach": Color(0.82, 0.76, 0.52),
		"snow": 0.9, "zenith": Color(0.1, 0.32, 0.85), "horizon": Color(0.62, 0.8, 0.96), "twilight": Color(1.0, 0.5, 0.28), "fog": Color(0.66, 0.8, 0.95), "fog_d": 0.00055,
		"liquid": "water", "clouds": 0.36, "cloud_col": Color(1, 1, 1), "weather": "rain", "res": ["Vesperite", Color(0.5, 1.0, 0.7)], "ore": "Carbon",
		"fauna": ["floater", "hopper"], "atm_col": Color(0.35, 0.6, 1.0), "grass": Color(0.32, 0.62, 0.2),
		"desc": "A temperate world of rolling hills, oceans and dense forests.",
	},
	"desert": {
		"gravity": [8.5, 12.0], "temp": [46.0, 62.0], "hazard": 0.9, "atmo": true,
		"t": {"freq": [2.2, 2.8], "amp": [120.0, 190.0], "ridge": [0.45, 0.65], "mask": [0.8, 1.0], "terr": 0.55, "dune": 26.0, "crater": 0.0, "sea": 0.0},
		"low": Color(0.82, 0.55, 0.27), "mid": Color(0.9, 0.64, 0.34), "high": Color(0.74, 0.42, 0.24), "rock": Color(0.5, 0.3, 0.2), "beach": Color(0.9, 0.7, 0.4),
		"snow": 2.0, "zenith": Color(0.42, 0.36, 0.55), "horizon": Color(0.98, 0.72, 0.42), "twilight": Color(1.0, 0.38, 0.2), "fog": Color(0.92, 0.68, 0.42), "fog_d": 0.0009,
		"liquid": "", "clouds": 0.12, "cloud_col": Color(1.0, 0.85, 0.7), "weather": "dust", "res": ["Pyrite", Color(1.0, 0.75, 0.2)], "ore": "Sodium",
		"fauna": ["hopper"], "atm_col": Color(1.0, 0.65, 0.35), "grass": Color(0.7, 0.58, 0.28),
		"desc": "Endless dunes and wind-carved mesas under a blazing sun.",
	},
	"frozen": {
		"gravity": [7.0, 10.0], "temp": [-70.0, -45.0], "hazard": 1.0, "atmo": true,
		"t": {"freq": [2.4, 3.2], "amp": [160.0, 230.0], "ridge": [0.5, 0.75], "mask": [0.65, 0.9], "terr": 0.0, "dune": 0.0, "crater": 0.0, "sea": 0.0},
		"low": Color(0.58, 0.72, 0.86), "mid": Color(0.68, 0.8, 0.92), "high": Color(0.84, 0.9, 0.96), "rock": Color(0.36, 0.44, 0.56), "beach": Color(0.8, 0.9, 1.0),
		"snow": 0.15, "zenith": Color(0.12, 0.3, 0.58), "horizon": Color(0.8, 0.92, 1.0), "twilight": Color(0.9, 0.55, 0.75), "fog": Color(0.8, 0.9, 1.0), "fog_d": 0.0011,
		"liquid": "", "clouds": 0.4, "cloud_col": Color(0.92, 0.96, 1.0), "weather": "snow", "res": ["Cryolite", Color(0.5, 0.85, 1.0)], "ore": "Oxygen",
		"fauna": ["floater"], "atm_col": Color(0.55, 0.8, 1.0), "grass": Color(0.8, 0.9, 0.95),
		"desc": "A glittering world locked in ice, swept by freezing blizzards.",
	},
	"volcanic": {
		"gravity": [9.0, 13.0], "temp": [78.0, 110.0], "hazard": 1.4, "atmo": true,
		"t": {"freq": [2.6, 3.4], "amp": [220.0, 300.0], "ridge": [0.75, 0.95], "mask": [0.4, 0.7], "terr": 0.0, "dune": 0.0, "crater": 26.0, "sea": -0.12},
		"low": Color(0.09, 0.07, 0.07), "mid": Color(0.17, 0.11, 0.09), "high": Color(0.3, 0.19, 0.15), "rock": Color(0.06, 0.05, 0.06), "beach": Color(0.12, 0.09, 0.08),
		"snow": 2.0, "zenith": Color(0.1, 0.04, 0.05), "horizon": Color(0.8, 0.28, 0.1), "twilight": Color(1.0, 0.3, 0.1), "fog": Color(0.38, 0.15, 0.1), "fog_d": 0.0014,
		"liquid": "lava", "clouds": 0.35, "cloud_col": Color(0.22, 0.12, 0.1), "weather": "ash", "res": ["Magmite", Color(1.0, 0.45, 0.15)], "ore": "Sulphur",
		"fauna": [], "atm_col": Color(1.0, 0.35, 0.15), "grass": Color(0.2, 0.12, 0.1),
		"desc": "Rivers of lava and black basalt spires beneath an ash-choked sky.",
	},
	"toxic": {
		"gravity": [7.5, 10.5], "temp": [22.0, 40.0], "hazard": 1.2, "atmo": true,
		"t": {"freq": [2.5, 3.2], "amp": [110.0, 170.0], "ridge": [0.25, 0.45], "mask": [0.6, 0.85], "terr": 0.15, "dune": 0.0, "crater": 0.0, "sea": -0.13},
		"low": Color(0.36, 0.2, 0.46), "mid": Color(0.26, 0.4, 0.2), "high": Color(0.52, 0.4, 0.58), "rock": Color(0.26, 0.2, 0.32), "beach": Color(0.5, 0.55, 0.25),
		"snow": 2.0, "zenith": Color(0.26, 0.1, 0.36), "horizon": Color(0.55, 0.88, 0.32), "twilight": Color(0.95, 0.4, 0.8), "fog": Color(0.42, 0.62, 0.28), "fog_d": 0.0013,
		"liquid": "toxic", "clouds": 0.6, "cloud_col": Color(0.6, 0.9, 0.4), "weather": "spores", "res": ["Toxinite", Color(0.6, 1.0, 0.25)], "ore": "Nitrogen",
		"fauna": ["floater"], "atm_col": Color(0.5, 0.95, 0.3), "grass": Color(0.5, 0.2, 0.62),
		"desc": "Bioluminescent fungal forests drifting in a caustic green haze.",
	},
	"barren": {
		"gravity": [3.0, 6.0], "temp": [-90.0, -60.0], "hazard": 0.6, "atmo": false,
		"t": {"freq": [2.0, 2.8], "amp": [70.0, 110.0], "ridge": [0.2, 0.4], "mask": [0.5, 0.8], "terr": 0.0, "dune": 0.0, "crater": 42.0, "sea": 0.0},
		"low": Color(0.42, 0.41, 0.4), "mid": Color(0.54, 0.52, 0.49), "high": Color(0.68, 0.66, 0.62), "rock": Color(0.33, 0.32, 0.32), "beach": Color(0.5, 0.5, 0.5),
		"snow": 2.0, "zenith": Color(0, 0, 0), "horizon": Color(0, 0, 0), "twilight": Color(0, 0, 0), "fog": Color(0.1, 0.1, 0.12), "fog_d": 0.0,
		"liquid": "", "clouds": 0.0, "cloud_col": Color.WHITE, "weather": "none", "res": ["Lunarite", Color(0.75, 0.8, 1.0)], "ore": "Silicate",
		"fauna": [], "atm_col": Color(0.2, 0.2, 0.25), "grass": Color(0.4, 0.4, 0.4),
		"desc": "An airless, cratered rock under a hard black sky.",
	},
}

# prop tables: mesh, density (per m2), scale range, max slope (1-cos), collide radius (m at scale 1), shadow, tint, y offset, kind
const PROPS := {
	"lush": [
		{"mesh": "tree_broad", "dens": 0.00085, "s": [0.8, 1.5], "slope": 0.2, "col": 0.75, "shadow": true, "alt": [10.0, 99999.0]},
		{"mesh": "tree_blossom", "dens": 0.00035, "s": [0.8, 1.4], "slope": 0.2, "col": 0.75, "shadow": true, "alt": [10.0, 99999.0]},
		{"mesh": "tree_conifer", "dens": 0.0005, "s": [0.8, 1.6], "slope": 0.28, "col": 0.6, "shadow": true, "alt": [30.0, 99999.0]},
		{"mesh": "bush", "dens": 0.0022, "s": [0.7, 1.6], "slope": 0.3, "col": 0.0, "shadow": true, "alt": [8.0, 99999.0]},
		{"mesh": "grass_tuft", "dens": 0.017, "s": [0.8, 1.6], "slope": 0.3, "col": 0.0, "shadow": false, "tint": "grass", "alt": [6.0, 99999.0]},
		{"mesh": "flowers", "dens": 0.0035, "s": [0.8, 1.5], "slope": 0.25, "col": 0.0, "shadow": false, "alt": [6.0, 99999.0]},
		{"mesh": "rock_a", "dens": 0.0005, "s": [0.6, 1.6], "slope": 0.6, "col": 1.1, "shadow": true, "tint": "rock", "y": -0.15, "alt": [3.0, 99999.0]},
		{"mesh": "rock_b", "dens": 0.0003, "s": [0.6, 1.8], "slope": 0.6, "col": 1.0, "shadow": true, "tint": "rock", "y": -0.2, "alt": [3.0, 99999.0]},
	],
	"desert": [
		{"mesh": "cactus", "dens": 0.0005, "s": [0.8, 1.6], "slope": 0.2, "col": 0.55, "shadow": true},
		{"mesh": "dead_tree", "dens": 0.0003, "s": [0.8, 1.5], "slope": 0.2, "col": 0.45, "shadow": true},
		{"mesh": "rock_a", "dens": 0.0012, "s": [0.6, 2.0], "slope": 0.7, "col": 1.1, "shadow": true, "tint": "rock", "y": -0.2},
		{"mesh": "rock_b", "dens": 0.0008, "s": [0.7, 2.2], "slope": 0.7, "col": 1.0, "shadow": true, "tint": "rock", "y": -0.25},
		{"mesh": "rock_c", "dens": 0.0003, "s": [0.8, 2.0], "slope": 0.7, "col": 1.6, "shadow": true, "tint": "rock", "y": -0.3},
		{"mesh": "rock_spire", "dens": 0.00028, "s": [0.7, 1.8], "slope": 0.5, "col": 1.3, "shadow": true, "tint": "rock", "y": -0.5},
		{"mesh": "rock_arch", "dens": 0.00002, "s": [1.0, 1.6], "slope": 0.2, "col": 0.0, "shadow": true, "tint": "rock", "y": -0.4},
		{"mesh": "grass_tuft", "dens": 0.0025, "s": [0.6, 1.2], "slope": 0.2, "col": 0.0, "shadow": false, "tint": "grass"},
	],
	"frozen": [
		{"mesh": "snow_pine", "dens": 0.0007, "s": [0.8, 1.6], "slope": 0.25, "col": 0.6, "shadow": true},
		{"mesh": "ice_crystals", "dens": 0.0008, "s": [0.8, 1.8], "slope": 0.5, "col": 0.9, "shadow": true, "y": -0.2},
		{"mesh": "rock_a", "dens": 0.0009, "s": [0.6, 1.8], "slope": 0.7, "col": 1.1, "shadow": true, "tint": "rock", "y": -0.2},
		{"mesh": "rock_b", "dens": 0.0005, "s": [0.6, 1.8], "slope": 0.7, "col": 1.0, "shadow": true, "tint": "rock", "y": -0.25},
		{"mesh": "rock_spire", "dens": 0.0002, "s": [0.7, 1.5], "slope": 0.5, "col": 1.3, "shadow": true, "tint": "ice", "y": -0.5},
	],
	"volcanic": [
		{"mesh": "obsidian_spikes", "dens": 0.0008, "s": [0.8, 1.8], "slope": 0.6, "col": 1.0, "shadow": true, "y": -0.1},
		{"mesh": "lava_vent", "dens": 0.00012, "s": [0.8, 1.6], "slope": 0.3, "col": 3.0, "shadow": true, "y": -0.3},
		{"mesh": "rock_a", "dens": 0.0016, "s": [0.6, 2.0], "slope": 0.8, "col": 1.1, "shadow": true, "tint": "rock", "y": -0.2},
		{"mesh": "rock_b", "dens": 0.001, "s": [0.7, 2.2], "slope": 0.8, "col": 1.0, "shadow": true, "tint": "rock", "y": -0.25},
		{"mesh": "rock_spire", "dens": 0.00022, "s": [0.7, 1.6], "slope": 0.6, "col": 1.3, "shadow": true, "tint": "rock", "y": -0.5},
	],
	"toxic": [
		{"mesh": "mushroom_giant", "dens": 0.0006, "s": [0.7, 1.5], "slope": 0.25, "col": 0.6, "shadow": true, "alt": [10.0, 99999.0]},
		{"mesh": "spore_bulb", "dens": 0.0012, "s": [0.7, 1.5], "slope": 0.3, "col": 0.3, "shadow": false, "alt": [8.0, 99999.0]},
		{"mesh": "tentacle_plant", "dens": 0.0014, "s": [0.7, 1.5], "slope": 0.35, "col": 0.0, "shadow": false, "alt": [8.0, 99999.0]},
		{"mesh": "grass_tuft", "dens": 0.011, "s": [0.7, 1.4], "slope": 0.3, "col": 0.0, "shadow": false, "tint": "grass", "alt": [6.0, 99999.0]},
		{"mesh": "rock_a", "dens": 0.0004, "s": [0.6, 1.6], "slope": 0.7, "col": 1.1, "shadow": true, "tint": "rock", "y": -0.2, "alt": [3.0, 99999.0]},
		{"mesh": "bush", "dens": 0.0008, "s": [0.7, 1.4], "slope": 0.3, "col": 0.0, "shadow": true, "tint": "bush", "alt": [8.0, 99999.0]},
	],
	"barren": [
		{"mesh": "rock_a", "dens": 0.0028, "s": [0.5, 1.8], "slope": 0.9, "col": 1.1, "shadow": true, "tint": "rock", "y": -0.2},
		{"mesh": "rock_b", "dens": 0.0017, "s": [0.5, 2.0], "slope": 0.9, "col": 1.0, "shadow": true, "tint": "rock", "y": -0.25},
		{"mesh": "rock_c", "dens": 0.0005, "s": [0.7, 2.0], "slope": 0.9, "col": 1.6, "shadow": true, "tint": "rock", "y": -0.3},
		{"mesh": "rock_spire", "dens": 0.00014, "s": [0.6, 1.4], "slope": 0.6, "col": 1.3, "shadow": true, "tint": "rock", "y": -0.5},
	],
}

const SYLL_A := ["Ka", "Ve", "Zo", "Ar", "Mi", "Ta", "Lu", "Ny", "Or", "Se", "Ha", "Pe", "Xi", "Du", "Eo", "Ri", "Bo", "Ca", "Fe", "Gy", "Io", "Ju", "Qu", "Wy"]
const SYLL_B := ["ra", "len", "thos", "mus", "dor", "vik", "nia", "lis", "gar", "pon", "xen", "tra", "bel", "dun", "kai", "mar", "sel", "tan", "vor", "zen"]
const SYLL_C := ["", "", "ia", "a", "is", "on", "ar", "us", "ix", "eth"]


static func gen_name(rng: RandomNumberGenerator) -> String:
	return SYLL_A[rng.randi() % SYLL_A.size()] + SYLL_B[rng.randi() % SYLL_B.size()] + SYLL_C[rng.randi() % SYLL_C.size()]


static func _rr(rng: RandomNumberGenerator, arr) -> float:
	return rng.randf_range(arr[0], arr[1])


static func _shift(c: Color, dh: float, ds: float = 1.0, dv: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(c.h + dh, 1.0), clampf(c.s * ds, 0.0, 1.0), clampf(c.v * dv, 0.0, 1.5), c.a)


static func make(biome: String, seed_: int, pname: String, radius: float, kind: String = "planet") -> PlanetData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var b: Dictionary = BASE[biome]
	var p := PlanetData.new()
	p.name = pname
	p.biome = biome
	p.seed = seed_
	p.radius = radius
	p.kind = kind
	p.landable = true
	p.gravity = _rr(rng, b["gravity"])
	p.temp_c = _rr(rng, b["temp"])
	p.has_atmo = b["atmo"]
	p.atm_scale = 0.2 if p.has_atmo else 0.0
	p.atm_color = b["atm_col"]
	p.liquid = b["liquid"]
	p.cloud_cover = b["clouds"] * rng.randf_range(0.7, 1.3)
	p.cloud_color = b["cloud_col"]
	p.weather = b["weather"]
	p.resource_name = b["res"][0]
	p.resource_color = b["res"][1]
	p.ore_name = b["ore"]
	p.fauna = b["fauna"]
	p.desc = b["desc"]
	p.spin_period = rng.randf_range(700.0, 1300.0)
	p.spin_phase = rng.randf() * TAU
	p.axis_tilt = rng.randf_range(0.05, 0.45)
	p.hazard = {"rate": b["hazard"] * rng.randf_range(0.85, 1.2), "temp": p.temp_c, "kind": biome}

	# hue variation per planet (kept small so biomes stay recognisable)
	var dh := rng.randf_range(-0.04, 0.04)
	if biome == "lush":
		dh = rng.randf_range(-0.1, 0.08)
	elif biome == "toxic":
		dh = rng.randf_range(-0.08, 0.08)
	var look := {}
	for k in ["low", "mid", "high", "rock", "beach"]:
		look[k] = _shift(b[k], dh)
	look["snow"] = b["snow"]
	look["grass"] = _shift(b["grass"], dh)
	look["bush"] = _shift(b["grass"], dh + 0.25)
	look["ice"] = Color(0.6, 0.85, 1.0)
	look["lava"] = Color(1.0, 0.3, 0.05)
	look["lava_amt"] = 1.0 if biome == "volcanic" else 0.0
	look["spec"] = 0.35 if biome == "frozen" else 0.05
	look["rock_bias"] = 0.03 if biome == "barren" else 0.0
	look["color_var"] = 0.28 if biome == "frozen" else 0.38
	p.look = look
	p.sky = {
		"zenith": _shift(b["zenith"], dh * 0.6), "horizon": _shift(b["horizon"], dh * 0.6), "twilight": b["twilight"],
		"fog": _shift(b["fog"], dh * 0.6), "fog_d": b["fog_d"], "atmo": b["atmo"],
	}

	# terrain
	var t := TerrainParams.new()
	var tb: Dictionary = b["t"]
	t.seed = seed_ & 0x7fffffff
	t.radius = radius
	t.freq = _rr(rng, tb["freq"])
	t.amp = _rr(rng, tb["amp"]) * clampf(radius / 4500.0, 0.7, 1.25)
	t.ridge = _rr(rng, tb["ridge"])
	t.mask = _rr(rng, tb["mask"])
	t.terr = tb["terr"]
	t.steps = rng.randf_range(4.0, 8.0)
	t.dune = tb["dune"] * rng.randf_range(0.8, 1.3)
	t.crater = tb["crater"] * rng.randf_range(0.8, 1.2)
	t.cden = rng.randf_range(6.0, 10.0) * clampf(radius / 4500.0, 0.6, 1.4)
	t.off = Vector3(rng.randf() * 90.0, rng.randf() * 90.0, rng.randf() * 90.0)
	t.sea_level = t.amp * tb["sea"] if b["liquid"] != "" else -100000.0
	# landing/outpost site: flattened patch
	var sd := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)).normalized()
	t.site_dir = sd
	t.has_site = true
	t.site_r_in = 60.0
	t.site_r_out = 150.0
	var raw_h := _site_height(t, sd)
	t.site_h = maxf(raw_h, t.sea_level + 14.0) if b["liquid"] != "" else raw_h
	p.terrain = t
	p.site_dir = sd
	# points of interest
	var pois := []
	for i in 3:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		pois.append({"type": ["monolith", "beacon", "supply"][i], "dir": d})
	p.poi_dirs = pois
	p.props = PROPS[biome]
	return p


static func _site_height(t: TerrainParams, sd: Vector3) -> float:
	var had := t.has_site
	t.has_site = false
	var h := t.height(sd)
	t.has_site = had
	return h


static func make_gas(seed_: int, pname: String, radius: float) -> PlanetData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var p := PlanetData.new()
	p.name = pname
	p.biome = "gas"
	p.kind = "gas"
	p.seed = seed_
	p.radius = radius
	p.landable = false
	p.gravity = rng.randf_range(18.0, 26.0)
	p.spin_period = rng.randf_range(420.0, 700.0)
	p.axis_tilt = rng.randf_range(0.0, 0.5)
	p.rings = rng.randf() < 0.75
	p.has_atmo = true
	p.atm_scale = 0.12
	var hue := rng.randf()
	p.atm_color = Color.from_hsv(hue, 0.4, 1.0)
	p.gas_colors = [Color.from_hsv(hue, 0.45, 0.95), Color.from_hsv(fposmod(hue + 0.06, 1.0), 0.7, 0.55), Color.from_hsv(fposmod(hue - 0.05, 1.0), 0.18, 1.0), Color.from_hsv(fposmod(hue + 0.12, 1.0), 0.65, 0.32)]
	p.hazard = {"rate": 0.0, "temp": -150.0, "kind": "gas"}
	p.sky = {"zenith": p.atm_color.darkened(0.45), "horizon": p.atm_color.lightened(0.3), "twilight": Color(1.0, 0.6, 0.4), "fog": p.atm_color, "fog_d": 0.0, "atmo": true}
	p.desc = "A colossal gas giant. The crushing atmosphere makes landing impossible."
	var t := TerrainParams.new()
	t.radius = radius
	p.terrain = t
	return p
