class_name FloraTables
extends RefCounted
## Per-biome scatter tables (keys = BiomeDB ids). Module M7a.  Static data + helpers, thread-safe (read-only after first build).
##
## species entry keys:
##   id      ModelLib id                 layer  0 detail (32 m cells) | 1 mid (80 m cells) | 2 far (200 m cells)
##   g       group name for the planet variant multipliers: tree | bush | ground | flower | rock | special
##   d       density per 1000 m2 where the mask is 1 (spacing ~ sqrt(1000/d))
##   s       [min,max] uniform scale          slope  max ground slope in degrees       hmin/hmax  height above sea level range (m) (ignored without sea)
##   align   0 = grow along the planet up, 1 = along the terrain normal     sink  metres the model sinks into the ground (x scale)
##   mask    [noise, lo, hi]  noise = "big" (1/700 m) | "mid" (1/160 m) | "fine" (1/35 m); density *= smoothstep(lo, hi, noise01)  (optional)
##   range   visibility range override (m)   far_beyond  only visible when the cell is farther than this (far duplicates of mid species)
##   shadow  cast shadows (default true)     lift  hover height range [lo,hi] (floating rocks)     col  per-instance colour variation 0..1
##   thin    fraction of instances still drawn at the end of the range (default depends on the layer)   tilt  extra random lean (degrees)
##   cluster  >0 : place around random cluster centres (flower patches) -- reserved
## variants: density multipliers per group chosen from palette_seed (so two lush planets feel different)
## palettes: hue/sat/val applied to the model's tintable materials, picked from palette_seed:
##   leaf [dh, ds, dv] (foliage), glow [dh, ds, dv] (emissive things), rock [dh, ds, dv] (stone / sand)  (dh in colour-wheel cycles, ds/dv multipliers)

const LAYERS := [
	{"name": "detail", "cell": 40.0, "range": 110.0},
	{"name": "mid", "cell": 96.0, "range": 440.0},
	{"name": "far", "cell": 300.0, "range": 1600.0},
]

## keyword -> tint class used by the palettes
const GLOW_WORDS := ["glow", "core", "crystal", "petal", "flower", "bulb", "sac", "tip", "hot", "acid", "edge", "facet", "pod", "cap", "body", "ice", "deep", "coral", "horn", "sheath", "bell", "flesh", "blossom"]
const ROCK_WORDS := ["rock", "dust", "rust", "orange", "ochre", "cream", "sand", "lichen", "ash"]

static var _profiles: Dictionary = {}
static var _mutex: Mutex = Mutex.new()

static func tint_class(keyword: String) -> int:
	if keyword in ROCK_WORDS:
		return 2
	if keyword in GLOW_WORDS:
		return 1
	return 0

static func _s(id: String, layer: int, g: String, d: float, s: Array, extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"id": id, "layer": layer, "g": g, "d": d, "s": s, "slope": 30.0, "hmin": 1.2, "hmax": 1.0e9, "align": 0.5, "sink": 0.1}
	for k in extra:
		e[k] = extra[k]
	return e

static func profile(biome: String) -> Dictionary:
	_mutex.lock()
	if not _profiles.has(biome):
		_profiles[biome] = _build(biome)
	var p: Dictionary = _profiles[biome]
	_mutex.unlock()
	return p

static func _build(biome: String) -> Dictionary:
	match biome:
		"lush": return _lush()
		"ocean": return _ocean()
		"swamp": return _swamp()
		"desert": return _desert()
		"frozen": return _frozen()
		"volcanic": return _volcanic()
		"toxic": return _toxic()
		"barren": return _barren()
		"exotic": return _exotic()
		"radioactive": return _radioactive()
	return _generic(biome)

# ---------------------------------------------------------------------------------------------------------------------
static func _lush() -> Dictionary:
	return {
		"variants": [
			{"name": "forest", "mult": {"tree": 1.45, "bush": 1.2, "ground": 1.0, "flower": 0.8, "rock": 0.6}},
			{"name": "meadow", "mult": {"tree": 0.45, "bush": 0.8, "ground": 1.4, "flower": 2.4, "rock": 0.8}},
			{"name": "woodland", "hero": true, "mult": {"tree": 1.0, "bush": 1.5, "ground": 1.2, "flower": 1.3, "rock": 1.2}},
			{"name": "highland", "mult": {"tree": 0.9, "bush": 0.6, "ground": 0.9, "flower": 0.5, "rock": 2.2}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [-0.05, 1.05, 1.0], "glow": [0.10, 1.0, 1.0], "rock": [0.02, 1.0, 1.0]},
			{"leaf": [-0.13, 1.1, 1.05], "glow": [0.35, 1.0, 1.0], "rock": [0.0, 0.9, 1.05]},
			{"leaf": [0.11, 0.95, 1.0], "glow": [0.55, 1.0, 1.05], "rock": [-0.02, 0.9, 1.0]},
			{"leaf": [0.24, 1.0, 1.05], "glow": [-0.2, 1.0, 1.1], "rock": [0.04, 1.0, 1.0]},
		],
		"species": [
			_s("grass_tuft_a", 0, "ground", 190.0, [0.9, 1.7], {"slope": 40.0, "hmin": 0.8, "align": 0.7, "sink": 0.02, "mask": ["mid", 0.22, 0.46], "range": 95.0, "shadow": false, "col": 0.35}),
			_s("flower_cluster_a", 0, "flower", 16.0, [0.9, 1.7], {"slope": 32.0, "hmin": 1.0, "align": 0.6, "sink": 0.02, "mask": ["fine", 0.52, 0.68], "range": 70.0, "shadow": false, "col": 0.5}),
			_s("fern_a", 0, "ground", 6.0, [0.8, 1.6], {"slope": 34.0, "align": 0.55, "sink": 0.03, "mask": ["mid", 0.42, 0.62], "range": 80.0, "shadow": false, "col": 0.3}),
			_s("bush_lush_a", 1, "bush", 4.5, [0.8, 1.7], {"slope": 32.0, "mask": ["mid", 0.3, 0.52], "col": 0.3, "range": 200.0, "thin": 0.15}),
			_s("rock_moon_b", 1, "rock", 2.4, [0.6, 1.5], {"slope": 45.0, "align": 0.85, "sink": 0.18, "range": 200.0}),
			_s("tree_broadleaf_a", 1, "tree", 3.8, [0.8, 1.45], {"slope": 24.0, "hmin": 2.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.3, 0.46], "col": 0.3, "thin": 0.1}),
			_s("tree_broadleaf_b", 1, "tree", 0.8, [0.8, 1.4], {"slope": 24.0, "hmin": 2.0, "align": 0.3, "sink": 0.2, "mask": ["mid", 0.34, 0.56], "col": 0.3, "thin": 0.12}),
			_s("tree_conifer_a", 1, "tree", 2.6, [0.7, 1.35], {"slope": 30.0, "hmin": 4.0, "align": 0.35, "sink": 0.25, "mask": ["big", 0.42, 0.6], "col": 0.25, "thin": 0.2}),
			_s("tree_conifer_a", 2, "tree", 0.5, [0.75, 1.35], {"slope": 30.0, "hmin": 4.0, "align": 0.35, "sink": 0.25, "mask": ["big", 0.42, 0.6], "far_beyond": 340.0, "col": 0.25, "thin": 0.35, "range": 1200.0}),
			_s("boulder_big_a", 2, "rock", 0.028, [0.7, 1.5], {"slope": 40.0, "align": 0.9, "sink": 0.9, "hmin": 0.5}),
		],
	}

static func _ocean() -> Dictionary:
	return {
		"variants": [
			{"name": "palm islands", "hero": true, "mult": {"tree": 1.3, "bush": 1.0, "ground": 1.0, "special": 1.0, "rock": 0.8}},
			{"name": "coral atolls", "mult": {"tree": 0.6, "bush": 0.7, "ground": 0.8, "special": 2.0, "rock": 1.2}},
			{"name": "green isles", "mult": {"tree": 1.0, "bush": 1.7, "ground": 1.5, "special": 0.8, "rock": 0.8}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.05, 1.0, 1.05], "glow": [-0.15, 1.0, 1.0], "rock": [0.04, 1.0, 1.1]},
			{"leaf": [-0.07, 0.95, 1.0], "glow": [0.3, 1.0, 1.1], "rock": [0.0, 0.8, 1.1]},
		],
		"species": [
			_s("grass_tuft_a", 0, "ground", 110.0, [0.8, 1.5], {"slope": 30.0, "hmin": 0.9, "hmax": 14.0, "align": 0.7, "sink": 0.02, "mask": ["mid", 0.25, 0.5], "range": 90.0, "shadow": false, "col": 0.35}),
			_s("reed_cluster_a", 0, "ground", 22.0, [0.8, 1.5], {"slope": 20.0, "hmin": 0.0, "hmax": 2.5, "align": 0.7, "sink": 0.05, "range": 95.0, "shadow": false}),
			_s("fern_a", 0, "ground", 8.0, [0.8, 1.5], {"slope": 30.0, "hmin": 1.5, "mask": ["mid", 0.4, 0.6], "range": 80.0, "shadow": false}),
			_s("coral_rock_a", 1, "special", 5.0, [0.7, 1.6], {"slope": 35.0, "hmin": -9.0, "hmax": 0.7, "align": 0.8, "sink": 0.1, "mask": ["mid", 0.25, 0.5], "range": 330.0, "col": 0.3}),
			_s("palm_tree_a", 1, "tree", 3.0, [0.8, 1.4], {"slope": 22.0, "hmin": 1.2, "hmax": 16.0, "align": 0.2, "sink": 0.2, "mask": ["mid", 0.3, 0.52], "col": 0.3, "thin": 0.22}),
			_s("bush_lush_a", 1, "bush", 3.5, [0.7, 1.4], {"slope": 26.0, "hmin": 1.8, "mask": ["mid", 0.35, 0.55]}),
			_s("rock_moon_b", 1, "rock", 1.6, [0.7, 1.7], {"slope": 45.0, "hmin": -1.0, "align": 0.85, "sink": 0.2, "range": 300.0}),
			_s("palm_tree_a", 2, "tree", 0.5, [0.85, 1.4], {"slope": 22.0, "hmin": 1.2, "hmax": 16.0, "align": 0.2, "sink": 0.2, "mask": ["mid", 0.3, 0.52], "far_beyond": 330.0, "thin": 0.5}),
			_s("coral_rock_a", 2, "special", 0.4, [0.9, 1.7], {"slope": 35.0, "hmin": -9.0, "hmax": 0.7, "align": 0.8, "sink": 0.1, "mask": ["mid", 0.25, 0.5], "far_beyond": 330.0, "thin": 0.6}),
		],
	}

static func _swamp() -> Dictionary:
	return {
		"variants": [
			{"name": "bog forest", "hero": true, "mult": {"tree": 1.4, "bush": 1.0, "ground": 1.0, "special": 1.0, "rock": 0.6}},
			{"name": "reed marsh", "mult": {"tree": 0.5, "bush": 1.0, "ground": 1.8, "special": 0.8, "rock": 0.8}},
			{"name": "fungal fen", "mult": {"tree": 0.8, "bush": 1.0, "ground": 1.0, "special": 2.2, "rock": 0.8}},
		],
		"palettes": [
			{"leaf": [-0.05, 0.85, 0.85], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 0.8, 0.9]},
			{"leaf": [-0.1, 0.8, 0.9], "glow": [0.12, 1.0, 1.0], "rock": [0.02, 0.7, 0.95]},
			{"leaf": [0.02, 0.8, 0.8], "glow": [-0.1, 1.0, 1.1], "rock": [0.0, 0.8, 0.85]},
		],
		"species": [
			_s("grass_tuft_a", 0, "ground", 130.0, [0.9, 1.6], {"slope": 30.0, "hmin": 0.4, "align": 0.7, "sink": 0.02, "mask": ["mid", 0.2, 0.45], "range": 90.0, "shadow": false, "col": 0.4}),
			_s("reed_cluster_a", 0, "ground", 40.0, [0.9, 1.8], {"slope": 20.0, "hmin": -0.4, "hmax": 2.5, "align": 0.7, "sink": 0.05, "range": 100.0, "shadow": false}),
			_s("fern_a", 0, "ground", 14.0, [0.8, 1.6], {"slope": 34.0, "hmin": 0.5, "mask": ["mid", 0.35, 0.55], "range": 85.0, "shadow": false}),
			_s("bulb_plant_a", 0, "special", 6.0, [0.9, 1.6], {"slope": 30.0, "hmin": 0.5, "mask": ["mid", 0.5, 0.7], "range": 85.0, "shadow": false}),
			_s("fungus_cap_a", 1, "special", 3.5, [0.7, 1.5], {"slope": 40.0, "hmin": 0.4, "align": 0.7, "mask": ["mid", 0.4, 0.6], "range": 280.0}),
			_s("mushroom_toxic_b", 1, "special", 1.6, [0.7, 1.4], {"slope": 35.0, "hmin": 0.5, "mask": ["mid", 0.5, 0.7], "range": 300.0}),
			_s("tree_swamp_a", 1, "tree", 2.0, [0.8, 1.4], {"slope": 20.0, "hmin": 0.4, "align": 0.25, "sink": 0.25, "mask": ["mid", 0.3, 0.5], "col": 0.3, "thin": 0.25}),
			_s("tree_swamp_a", 2, "tree", 0.22, [0.85, 1.4], {"slope": 20.0, "hmin": 0.4, "align": 0.25, "sink": 0.25, "mask": ["mid", 0.3, 0.5], "far_beyond": 330.0, "thin": 0.5}),
			_s("rock_moon_b", 1, "rock", 1.2, [0.6, 1.4], {"slope": 45.0, "align": 0.85, "sink": 0.2, "range": 260.0}),
		],
	}

static func _desert() -> Dictionary:
	return {
		"variants": [
			{"name": "scrubland", "hero": true, "mult": {"tree": 1.3, "bush": 1.5, "ground": 1.0, "rock": 0.8, "special": 1.0}},
			{"name": "dune sea", "mult": {"tree": 0.3, "bush": 0.5, "ground": 0.8, "rock": 0.6, "special": 1.0}},
			{"name": "rocky badlands", "mult": {"tree": 0.5, "bush": 0.7, "ground": 0.7, "rock": 2.0, "special": 1.6}},
			{"name": "cactus flats", "mult": {"tree": 2.2, "bush": 1.0, "ground": 1.0, "rock": 0.7, "special": 1.0}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.05, 0.9, 1.0], "glow": [0.2, 1.0, 1.0], "rock": [-0.02, 1.1, 0.95]},
			{"leaf": [-0.04, 1.0, 1.05], "glow": [-0.25, 1.0, 1.0], "rock": [0.03, 0.8, 1.1]},
			{"leaf": [0.1, 0.8, 0.95], "glow": [0.4, 1.0, 1.0], "rock": [-0.04, 1.0, 0.85]},
		],
		"species": [
			_s("dune_grass_a", 0, "ground", 36.0, [0.9, 1.8], {"slope": 35.0, "hmin": 0.8, "align": 0.6, "sink": 0.02, "mask": ["mid", 0.35, 0.6], "range": 90.0, "shadow": false, "col": 0.4}),
			_s("dune_grass_b", 0, "ground", 28.0, [0.9, 1.9], {"slope": 35.0, "hmin": 0.8, "align": 0.6, "sink": 0.02, "mask": ["mid", 0.3, 0.55], "range": 90.0, "shadow": false, "col": 0.4}),
			_s("shrub_dry_a", 1, "bush", 3.2, [0.8, 1.7], {"slope": 32.0, "mask": ["mid", 0.3, 0.5], "col": 0.3}),
			_s("shrub_dry_b", 1, "bush", 3.0, [0.9, 1.9], {"slope": 32.0, "mask": ["mid", 0.28, 0.5], "col": 0.3, "range": 180.0}),
			_s("cactus_b", 1, "tree", 1.3, [0.8, 1.6], {"slope": 30.0, "mask": ["mid", 0.35, 0.55], "col": 0.3, "thin": 0.3}),
			_s("cactus_a", 1, "tree", 0.5, [0.8, 1.5], {"slope": 26.0, "mask": ["big", 0.4, 0.6], "col": 0.3, "thin": 0.3}),
			_s("cactus_c", 1, "tree", 0.6, [0.8, 1.6], {"slope": 26.0, "mask": ["mid", 0.38, 0.6], "col": 0.3, "thin": 0.3}),
			_s("dead_tree_a", 1, "tree", 0.22, [0.8, 1.5], {"slope": 26.0, "mask": ["big", 0.45, 0.65], "col": 0.2, "thin": 0.3}),
			_s("dead_tree_b", 1, "tree", 0.22, [0.8, 1.5], {"slope": 26.0, "mask": ["big", 0.45, 0.65], "col": 0.2, "thin": 0.3}),
			_s("rock_sandstone_a", 1, "rock", 0.8, [0.6, 1.5], {"slope": 45.0, "align": 0.8, "sink": 0.25, "range": 380.0, "thin": 0.3}),
			_s("rock_sandstone_b", 1, "rock", 0.8, [0.6, 1.6], {"slope": 45.0, "align": 0.8, "sink": 0.25, "range": 380.0, "thin": 0.3}),
			_s("rock_sandstone_c", 1, "rock", 0.7, [0.6, 1.7], {"slope": 45.0, "align": 0.8, "sink": 0.25, "range": 320.0, "thin": 0.3}),
			_s("bones_a", 1, "special", 0.06, [0.7, 1.2], {"slope": 20.0, "align": 0.8, "sink": 0.15, "range": 400.0}),
			_s("cactus_a", 2, "tree", 0.15, [0.9, 1.6], {"slope": 26.0, "mask": ["big", 0.4, 0.6], "far_beyond": 330.0, "thin": 0.5}),
			_s("rock_sandstone_b", 2, "rock", 0.3, [0.9, 2.0], {"slope": 45.0, "align": 0.8, "sink": 0.3, "far_beyond": 330.0, "thin": 0.6}),
			_s("mesa_rock_a", 2, "special", 0.005, [0.7, 1.5], {"slope": 20.0, "hmin": 1.0, "align": 0.95, "sink": 1.5, "mask": ["big", 0.42, 0.68], "range": 1700.0}),
			_s("boulder_big_a", 2, "rock", 0.022, [0.8, 1.6], {"slope": 40.0, "align": 0.9, "sink": 0.9}),
		],
	}

static func _frozen() -> Dictionary:
	return {
		"variants": [
			{"name": "frost forest", "hero": true, "mult": {"tree": 1.7, "ground": 1.0, "rock": 0.8, "special": 0.8}},
			{"name": "glacial waste", "mult": {"tree": 0.25, "ground": 1.0, "rock": 1.2, "special": 1.5}},
			{"name": "crystal fields", "mult": {"tree": 0.6, "ground": 1.0, "rock": 0.8, "special": 2.4}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.04, 0.9, 1.05], "glow": [0.12, 1.0, 1.0], "rock": [0.03, 1.0, 1.0]},
			{"leaf": [-0.05, 1.0, 0.95], "glow": [-0.18, 1.0, 1.05], "rock": [-0.02, 0.9, 1.05]},
			{"leaf": [0.0, 0.8, 1.1], "glow": [0.3, 1.0, 1.0], "rock": [0.05, 1.0, 0.95]},
		],
		"species": [
			_s("rock_snow_b", 0, "rock", 6.0, [0.3, 0.8], {"slope": 50.0, "align": 0.9, "sink": 0.1, "range": 90.0, "shadow": false}),
			_s("rock_snow_a", 1, "rock", 1.6, [0.6, 1.6], {"slope": 50.0, "align": 0.85, "sink": 0.25, "range": 340.0}),
			_s("rock_snow_b", 1, "rock", 1.2, [0.7, 1.8], {"slope": 50.0, "align": 0.85, "sink": 0.2, "range": 280.0}),
			_s("ice_crystal_a", 1, "special", 0.8, [0.6, 1.6], {"slope": 40.0, "align": 0.7, "sink": 0.1, "mask": ["mid", 0.35, 0.6], "col": 0.3}),
			_s("ice_crystal_b", 1, "special", 1.3, [0.7, 1.7], {"slope": 40.0, "align": 0.7, "sink": 0.1, "mask": ["mid", 0.32, 0.58], "col": 0.3, "range": 260.0}),
			_s("ice_spike_a", 1, "special", 0.4, [0.7, 1.7], {"slope": 40.0, "align": 0.8, "sink": 0.2, "mask": ["mid", 0.4, 0.65], "col": 0.3}),
			_s("ice_spike_b", 1, "special", 0.6, [0.8, 1.8], {"slope": 40.0, "align": 0.8, "sink": 0.2, "mask": ["mid", 0.38, 0.62], "col": 0.3, "range": 300.0}),
			_s("tree_frost_a", 1, "tree", 0.7, [0.8, 1.5], {"slope": 26.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.38, 0.58], "col": 0.25, "thin": 0.25}),
			_s("tree_frost_b", 1, "tree", 0.8, [0.8, 1.5], {"slope": 26.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.36, 0.56], "col": 0.25, "thin": 0.25}),
			_s("tree_frost_c", 1, "tree", 0.7, [0.8, 1.6], {"slope": 26.0, "align": 0.3, "sink": 0.2, "mask": ["mid", 0.36, 0.56], "col": 0.25, "thin": 0.25, "range": 300.0}),
			_s("tree_frost_a", 2, "tree", 0.3, [0.85, 1.5], {"slope": 26.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.38, 0.58], "far_beyond": 330.0, "thin": 0.5}),
			_s("ice_spike_a", 2, "special", 0.1, [1.0, 2.6], {"slope": 40.0, "align": 0.85, "sink": 0.3, "mask": ["mid", 0.4, 0.65], "far_beyond": 330.0, "thin": 0.6}),
			_s("icicle_arch_a", 2, "special", 0.0035, [0.9, 1.5], {"slope": 14.0, "align": 0.95, "sink": 0.3, "mask": ["big", 0.45, 0.7], "range": 1700.0}),
			_s("boulder_big_a", 2, "rock", 0.02, [0.8, 1.6], {"slope": 40.0, "align": 0.9, "sink": 0.9}),
		],
	}

static func _volcanic() -> Dictionary:
	return {
		"variants": [
			{"name": "ember fields", "hero": true, "mult": {"tree": 1.4, "rock": 1.0, "special": 1.0, "ground": 1.0}},
			{"name": "spire lands", "mult": {"tree": 0.5, "rock": 1.2, "special": 1.8, "ground": 1.0}},
			{"name": "magma flats", "mult": {"tree": 0.7, "rock": 1.6, "special": 1.2, "ground": 1.0}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.04, 1.0, 1.05], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.0, 1.0, 1.0], "glow": [-0.03, 1.1, 1.0], "rock": [0.02, 1.0, 1.1]},
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.015, 0.85, 1.1], "rock": [0.0, 0.7, 1.15]},
		],
		"species": [
			_s("rock_lava_a", 1, "rock", 0.8, [0.6, 1.5], {"slope": 45.0, "align": 0.85, "sink": 0.3, "range": 380.0, "thin": 0.3}),
			_s("magma_crystal_a", 1, "special", 0.65, [0.6, 1.6], {"slope": 40.0, "align": 0.7, "sink": 0.15, "mask": ["mid", 0.35, 0.6], "range": 380.0}),
			_s("obsidian_spire_a", 1, "special", 0.6, [0.7, 1.6], {"slope": 40.0, "align": 0.8, "sink": 0.2, "mask": ["mid", 0.3, 0.55], "col": 0.2}),
			_s("rock_basalt_a", 1, "rock", 0.55, [0.7, 1.4], {"slope": 40.0, "align": 0.85, "sink": 0.35, "range": 400.0, "thin": 0.3}),
			_s("tree_charred_a", 1, "tree", 1.5, [0.8, 1.5], {"slope": 28.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.35, 0.55], "col": 0.2, "thin": 0.3}),
			_s("ash_tree_a", 1, "tree", 0.8, [0.8, 1.4], {"slope": 28.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.45, 0.65], "col": 0.2, "thin": 0.3}),
			_s("vent_stack_a", 1, "special", 0.2, [0.7, 1.3], {"slope": 30.0, "align": 0.9, "sink": 0.4, "mask": ["big", 0.4, 0.65], "range": 440.0}),
			_s("tree_charred_a", 2, "tree", 0.5, [0.85, 1.5], {"slope": 28.0, "align": 0.3, "sink": 0.2, "mask": ["big", 0.35, 0.55], "far_beyond": 330.0, "thin": 0.5}),
			_s("obsidian_spire_a", 2, "special", 0.11, [1.0, 2.5], {"slope": 40.0, "align": 0.85, "sink": 0.4, "mask": ["mid", 0.3, 0.55], "far_beyond": 330.0, "thin": 0.6}),
			_s("vent_stack_a", 2, "special", 0.03, [1.0, 2.2], {"slope": 30.0, "align": 0.9, "sink": 0.6, "mask": ["big", 0.4, 0.65], "far_beyond": 330.0, "thin": 0.7}),
		],
	}

static func _toxic() -> Dictionary:
	return {
		"variants": [
			{"name": "spore forest", "hero": true, "mult": {"tree": 1.5, "bush": 1.0, "ground": 1.0, "special": 1.0, "rock": 0.6}},
			{"name": "tentacle fen", "mult": {"tree": 0.7, "bush": 1.4, "ground": 1.0, "special": 1.5, "rock": 0.8}},
			{"name": "fungal plains", "mult": {"tree": 1.0, "bush": 1.0, "ground": 1.6, "special": 1.0, "rock": 1.0}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.1, 1.0, 1.0], "glow": [0.12, 1.0, 1.0], "rock": [0.04, 1.0, 1.0]},
			{"leaf": [-0.12, 1.0, 1.05], "glow": [-0.2, 1.0, 1.05], "rock": [-0.03, 1.0, 1.0]},
			{"leaf": [0.28, 0.95, 1.0], "glow": [0.4, 1.0, 1.0], "rock": [0.06, 0.9, 1.0]},
		],
		"species": [
			_s("bulb_plant_a", 0, "ground", 16.0, [0.9, 1.8], {"slope": 38.0, "align": 0.7, "sink": 0.03, "mask": ["mid", 0.3, 0.5], "range": 90.0, "shadow": false}),
			_s("fungus_cap_a", 0, "ground", 8.0, [0.5, 1.1], {"slope": 45.0, "align": 0.7, "sink": 0.06, "mask": ["mid", 0.35, 0.55], "range": 90.0, "shadow": false}),
			_s("spore_pod_a", 1, "bush", 2.6, [0.8, 1.7], {"slope": 35.0, "mask": ["mid", 0.3, 0.5], "col": 0.3, "range": 200.0}),
			_s("tentacle_plant_a", 1, "special", 1.6, [0.8, 1.6], {"slope": 30.0, "mask": ["mid", 0.4, 0.6], "col": 0.3}),
			_s("fungus_cap_a", 1, "special", 1.8, [0.9, 1.8], {"slope": 45.0, "align": 0.7, "range": 230.0, "col": 0.3}),
			_s("mushroom_toxic_b", 1, "tree", 1.8, [0.8, 1.5], {"slope": 32.0, "mask": ["mid", 0.3, 0.55], "col": 0.3, "thin": 0.3}),
			_s("mushroom_toxic_a", 1, "tree", 1.4, [0.8, 1.5], {"slope": 28.0, "align": 0.3, "mask": ["big", 0.35, 0.55], "col": 0.3, "thin": 0.3}),
			_s("acid_pool_rim_a", 1, "rock", 0.08, [0.8, 1.6], {"slope": 8.0, "align": 1.0, "sink": 0.1, "hmin": 1.0, "range": 380.0}),
			_s("mushroom_toxic_a", 2, "tree", 0.25, [0.9, 1.6], {"slope": 28.0, "align": 0.3, "mask": ["big", 0.35, 0.55], "far_beyond": 330.0, "thin": 0.6}),
			_s("mushroom_toxic_b", 2, "tree", 0.2, [0.9, 1.6], {"slope": 28.0, "mask": ["mid", 0.3, 0.55], "far_beyond": 330.0, "thin": 0.6}),
		],
	}

static func _barren() -> Dictionary:
	return {
		"variants": [
			{"name": "boulder field", "hero": true, "mult": {"rock": 1.8, "special": 0.8, "ground": 1.0}},
			{"name": "smooth regolith", "mult": {"rock": 0.7, "special": 1.0, "ground": 1.0}},
			{"name": "spire land", "mult": {"rock": 1.0, "special": 2.2, "ground": 1.0}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.06, 1.3, 0.95]},
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [-0.04, 1.6, 1.0]},
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.55, 0.8, 1.0]},
		],
		"species": [
			_s("rock_moon_b", 0, "rock", 12.0, [0.12, 0.38], {"slope": 55.0, "hmin": -1.0e9, "align": 0.9, "sink": 0.05, "range": 80.0, "shadow": false, "col": 0.3}),
			_s("rock_moon_d", 0, "rock", 10.0, [0.3, 0.9], {"slope": 55.0, "hmin": -1.0e9, "align": 0.9, "sink": 0.08, "range": 85.0, "shadow": false, "col": 0.3}),
			_s("rock_moon_a", 1, "rock", 2.2, [0.5, 1.5], {"mask": ["mid", 0.2, 0.45], "slope": 55.0, "hmin": -1.0e9, "align": 0.85, "sink": 0.2, "range": 380.0, "col": 0.25}),
			_s("rock_moon_b", 1, "rock", 3.4, [0.6, 1.6], {"mask": ["mid", 0.15, 0.4], "slope": 55.0, "hmin": -1.0e9, "align": 0.85, "sink": 0.2, "range": 330.0, "col": 0.25}),
			_s("rock_moon_c", 1, "rock", 1.2, [0.6, 1.4], {"mask": ["big", 0.3, 0.55], "slope": 50.0, "hmin": -1.0e9, "align": 0.85, "sink": 0.25, "range": 400.0, "col": 0.25}),
			_s("rock_moon_e", 1, "rock", 1.4, [0.7, 1.7], {"mask": ["mid", 0.2, 0.45], "slope": 55.0, "hmin": -1.0e9, "align": 0.85, "sink": 0.2, "range": 300.0, "col": 0.25}),
			_s("spire_regolith_a", 1, "special", 0.09, [0.7, 1.5], {"slope": 40.0, "hmin": -1.0e9, "align": 0.9, "sink": 0.35, "mask": ["mid", 0.4, 0.65]}),
			_s("spire_regolith_b", 1, "special", 0.12, [0.8, 1.7], {"slope": 40.0, "hmin": -1.0e9, "align": 0.9, "sink": 0.3, "mask": ["mid", 0.38, 0.62], "range": 330.0}),
			_s("rock_moon_c", 2, "rock", 0.3, [1.0, 2.4], {"slope": 50.0, "hmin": -1.0e9, "align": 0.85, "sink": 0.3, "far_beyond": 330.0, "thin": 0.6}),
			_s("spire_regolith_a", 2, "special", 0.05, [1.0, 2.8], {"slope": 40.0, "hmin": -1.0e9, "align": 0.9, "sink": 0.5, "mask": ["big", 0.4, 0.65], "far_beyond": 330.0, "thin": 0.7}),
			_s("boulder_big_a", 2, "rock", 0.03, [0.8, 1.8], {"slope": 45.0, "hmin": -1.0e9, "align": 0.9, "sink": 0.9}),
		],
	}

static func _exotic() -> Dictionary:
	return {
		"variants": [
			{"name": "crystal grove", "hero": true, "mult": {"tree": 1.5, "bush": 1.0, "ground": 1.0, "special": 1.0, "flower": 1.0}},
			{"name": "fan jungle", "mult": {"tree": 1.1, "bush": 1.4, "ground": 1.2, "special": 0.8, "flower": 1.6}},
			{"name": "horn forest", "mult": {"tree": 1.0, "bush": 1.0, "ground": 1.0, "special": 1.8, "flower": 0.8}},
		],
		"palettes": [
			{"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]},
			{"leaf": [0.15, 1.0, 1.0], "glow": [0.15, 1.0, 1.0], "rock": [0.1, 1.0, 1.0]},
			{"leaf": [-0.2, 1.0, 1.05], "glow": [-0.15, 1.0, 1.05], "rock": [-0.1, 1.0, 1.0]},
			{"leaf": [0.38, 1.0, 1.0], "glow": [0.4, 1.0, 1.0], "rock": [0.2, 1.0, 1.0]},
			{"leaf": [-0.35, 1.0, 1.1], "glow": [-0.3, 1.0, 1.1], "rock": [-0.2, 1.0, 1.0]},
		],
		"species": [
			_s("flower_cluster_a", 0, "flower", 24.0, [1.0, 2.2], {"slope": 35.0, "align": 0.6, "sink": 0.02, "mask": ["fine", 0.45, 0.65], "range": 85.0, "shadow": false, "col": 0.6}),
			_s("bulb_plant_a", 0, "ground", 12.0, [0.9, 1.8], {"slope": 35.0, "align": 0.7, "sink": 0.03, "mask": ["mid", 0.35, 0.55], "range": 85.0, "shadow": false, "col": 0.4}),
			_s("spore_pod_a", 1, "bush", 2.0, [0.8, 1.6], {"slope": 35.0, "mask": ["mid", 0.35, 0.55], "col": 0.4, "range": 200.0}),
			_s("tentacle_plant_a", 1, "ground", 1.0, [0.7, 1.4], {"slope": 30.0, "mask": ["mid", 0.45, 0.65], "col": 0.4, "range": 340.0}),
			_s("exotic_fan_plant_a", 1, "tree", 1.0, [0.8, 1.5], {"slope": 26.0, "mask": ["mid", 0.3, 0.5], "col": 0.45, "thin": 0.3}),
			_s("exotic_spiral_horn_a", 1, "special", 0.8, [0.8, 1.5], {"slope": 30.0, "mask": ["big", 0.35, 0.55], "col": 0.45, "thin": 0.3}),
			_s("exotic_crystal_tree_a", 1, "tree", 1.2, [0.8, 1.5], {"slope": 28.0, "mask": ["big", 0.3, 0.5], "col": 0.45, "thin": 0.3}),
			_s("exotic_crystal_tree_a", 2, "tree", 0.2, [0.9, 1.6], {"slope": 28.0, "mask": ["big", 0.3, 0.5], "far_beyond": 330.0, "thin": 0.6}),
			_s("exotic_spiral_horn_a", 2, "special", 0.15, [0.9, 1.7], {"slope": 30.0, "mask": ["big", 0.35, 0.55], "far_beyond": 330.0, "thin": 0.6}),
			_s("floating_rock_a", 2, "special", 0.012, [0.8, 2.0], {"slope": 90.0, "lift": [6.0, 28.0], "hmin": -1.0e9, "align": 0.1, "sink": 0.0, "mask": ["big", 0.35, 0.6], "range": 1700.0, "col": 0.3}),
		],
	}

static func _radioactive() -> Dictionary:
	return {
		"variants": [
			{"name": "dead forest", "hero": true, "mult": {"tree": 1.6, "bush": 1.0, "ground": 1.0, "special": 1.0, "rock": 0.8}},
			{"name": "isotope fields", "mult": {"tree": 0.6, "bush": 1.0, "ground": 1.2, "special": 2.0, "rock": 1.0}},
		],
		"palettes": [
			{"leaf": [0.1, 0.8, 0.9], "glow": [0.15, 1.0, 1.0], "rock": [0.1, 0.9, 1.0]},
			{"leaf": [0.05, 0.7, 0.85], "glow": [0.1, 1.0, 1.1], "rock": [0.06, 0.8, 1.0]},
		],
		"species": [
			_s("dune_grass_a", 0, "ground", 50.0, [0.9, 1.7], {"slope": 35.0, "hmin": 0.5, "align": 0.6, "sink": 0.02, "mask": ["mid", 0.3, 0.55], "range": 90.0, "shadow": false}),
			_s("bulb_plant_a", 0, "special", 9.0, [0.9, 1.8], {"slope": 35.0, "mask": ["mid", 0.4, 0.6], "range": 85.0, "shadow": false}),
			_s("shrub_dry_a", 1, "bush", 4.0, [0.8, 1.6], {"slope": 32.0, "mask": ["mid", 0.3, 0.5]}),
			_s("dead_tree_a", 1, "tree", 1.6, [0.8, 1.5], {"slope": 26.0, "mask": ["big", 0.35, 0.55], "col": 0.2, "thin": 0.3}),
			_s("tree_charred_a", 1, "tree", 1.2, [0.8, 1.4], {"slope": 26.0, "mask": ["big", 0.4, 0.6], "col": 0.2, "thin": 0.3}),
			_s("mushroom_toxic_b", 1, "special", 1.4, [0.7, 1.4], {"slope": 30.0, "mask": ["mid", 0.4, 0.6], "range": 330.0}),
			_s("magma_crystal_a", 1, "special", 0.9, [0.6, 1.5], {"slope": 40.0, "align": 0.7, "sink": 0.15, "mask": ["mid", 0.4, 0.65], "range": 380.0}),
			_s("spire_regolith_a", 1, "rock", 0.18, [0.7, 1.4], {"slope": 40.0, "align": 0.9, "sink": 0.3, "mask": ["mid", 0.4, 0.65]}),
			_s("dead_tree_a", 2, "tree", 0.45, [0.9, 1.5], {"slope": 26.0, "mask": ["big", 0.35, 0.55], "far_beyond": 330.0, "thin": 0.5}),
			_s("boulder_big_a", 2, "rock", 0.025, [0.8, 1.6], {"slope": 40.0, "align": 0.9, "sink": 0.9}),
		],
	}

## fallback for unknown biome ids: uses whatever the manifests say for that biome
static func _generic(biome: String) -> Dictionary:
	var sp: Array = []
	for id in ModelLib.ids_for_biome(biome, "flora"):
		var mf := ModelLib.manifest(id)
		var sz: Array = mf.get("size", [1, 1, 1])
		var h := float(sz[1])
		sp.append(_s(id, 1 if h > 1.5 else 0, "tree" if h > 3.0 else "bush", 1.5 if h > 3.0 else 8.0, [0.8, 1.4], {"range": 330.0 if h > 1.5 else 90.0}))
	for id in ModelLib.ids_for_biome(biome, "rock"):
		sp.append(_s(id, 1, "rock", 1.0, [0.7, 1.4], {"range": 330.0, "align": 0.85, "sink": 0.2}))
	return {"variants": [{"name": "default", "mult": {}}], "palettes": [{"leaf": [0, 1, 1], "glow": [0, 1, 1], "rock": [0, 1, 1]}], "species": sp}

# ---------------------------------------------------------------------------------------------------------------------
## relative weight of each resource per biome (ferrite, zyrite, sodium, voidstone) and how many nodes per 1000 m2 overall
static func resource_weights(biome: String) -> Dictionary:
	match biome:
		"lush": return {"ferrite": 0.8, "zyrite": 0.5, "sodium": 1.2, "voidstone": 0.06}
		"ocean": return {"ferrite": 0.7, "zyrite": 0.6, "sodium": 1.0, "voidstone": 0.07}
		"swamp": return {"ferrite": 0.7, "zyrite": 0.6, "sodium": 1.4, "voidstone": 0.07}
		"desert": return {"ferrite": 1.4, "zyrite": 0.6, "sodium": 0.6, "voidstone": 0.07}
		"frozen": return {"ferrite": 0.9, "zyrite": 1.4, "sodium": 0.4, "voidstone": 0.08}
		"volcanic": return {"ferrite": 1.5, "zyrite": 0.7, "sodium": 0.3, "voidstone": 0.09}
		"toxic": return {"ferrite": 0.6, "zyrite": 0.8, "sodium": 1.5, "voidstone": 0.08}
		"barren": return {"ferrite": 1.6, "zyrite": 1.1, "sodium": 0.15, "voidstone": 0.1}
		"exotic": return {"ferrite": 0.6, "zyrite": 1.4, "sodium": 0.8, "voidstone": 0.22}
		"radioactive": return {"ferrite": 0.9, "zyrite": 1.2, "sodium": 0.6, "voidstone": 0.14}
	return {"ferrite": 1.0, "zyrite": 0.8, "sodium": 0.8, "voidstone": 0.08}
