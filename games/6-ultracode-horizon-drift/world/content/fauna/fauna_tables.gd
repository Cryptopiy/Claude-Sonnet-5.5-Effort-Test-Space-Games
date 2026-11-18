class_name FaunaTables
extends RefCounted
## Species + per-biome fauna tables (module m7b_life).  Species keys map to the Blender creature models; BIOMES decide which species live where, how dense
## they are, and how the (tintable) skin / glow materials are recoloured for that biome so every planet's wildlife looks different.

const SPECIES := {
	"grazer": {"model": "creature_quadruped_a", "type": "walker", "walk": 1.3, "run": 6.5, "scale": [0.8, 1.3], "herd": [1, 4], "flee": 30.0, "leash": 45.0,
		"stride": 1.55, "turn": 2.2, "title": "Grazer", "amp": 0.55, "radius": 1.0},
	"crawler": {"model": "creature_crawler_a", "type": "crawler", "walk": 1.1, "run": 5.5, "scale": [0.8, 1.6], "herd": [1, 3], "flee": 14.0, "leash": 38.0,
		"stride": 0.55, "turn": 4.0, "title": "Skitterer", "amp": 0.5, "radius": 0.6},
	"floater": {"model": "creature_floater_a", "type": "floater", "walk": 0.8, "scale": [0.8, 1.7], "herd": [1, 3], "hover": [3.8, 10.0], "flee": 11.0, "leash": 38.0,
		"title": "Drifter", "radius": 1.0},
	"flyer": {"model": "creature_flyer_a", "type": "flyer", "walk": 14.0, "scale": [0.9, 1.5], "herd": [3, 6], "alt": [24.0, 75.0], "orbit": [55.0, 140.0],
		"title": "Glider", "radius": 1.2},
}

## density p = spawn probability of a herd per ~90 m cell, mix = species weights
const BIOMES := {
	"lush": {"p": 0.50, "mix": {"grazer": 5.0, "flyer": 2.6, "floater": 0.6, "crawler": 0.8}},
	"ocean": {"p": 0.40, "mix": {"floater": 3.0, "flyer": 3.0, "grazer": 0.7, "crawler": 1.5}},
	"swamp": {"p": 0.50, "mix": {"grazer": 3.0, "floater": 2.4, "crawler": 2.4}},
	"desert": {"p": 0.36, "mix": {"crawler": 5.0, "flyer": 1.8, "grazer": 1.4}},
	"frozen": {"p": 0.38, "mix": {"grazer": 4.0, "flyer": 2.0, "floater": 0.8}},
	"volcanic": {"p": 0.30, "mix": {"crawler": 5.0, "floater": 1.4}},
	"toxic": {"p": 0.50, "mix": {"floater": 4.0, "crawler": 3.0, "grazer": 0.8}},
	"exotic": {"p": 0.55, "mix": {"floater": 3.4, "grazer": 2.6, "flyer": 2.2}},
	"radioactive": {"p": 0.32, "mix": {"crawler": 4.0, "floater": 2.0, "grazer": 0.6}},
	"barren": {"p": 0.12, "mix": {"crawler": 1.0}},
}

## recolouring per biome.  <role>_h = target hue (-1 keeps the model's hue), _s / _v = saturation / value multipliers
const TINTS := {
	"lush": {"skin_h": -1.0, "glow_h": -1.0, "skin_s": 1.0, "skin_v": 1.0},
	"ocean": {"skin_h": 0.52, "glow_h": 0.93, "skin_s": 1.0, "skin_v": 1.05},
	"swamp": {"skin_h": 0.26, "glow_h": 0.15, "skin_s": 0.85, "skin_v": 0.85},
	"desert": {"skin_h": 0.09, "glow_h": 0.03, "skin_s": 0.85, "skin_v": 1.0},
	"frozen": {"skin_h": 0.56, "glow_h": 0.50, "skin_s": 0.30, "skin_v": 1.35},
	"volcanic": {"skin_h": 0.02, "glow_h": 0.08, "skin_s": 0.9, "skin_v": 0.5},
	"toxic": {"skin_h": 0.78, "glow_h": 0.24, "skin_s": 0.9, "skin_v": 0.9},
	"exotic": {"skin_h": 0.86, "glow_h": 0.50, "skin_s": 1.0, "skin_v": 1.0},
	"radioactive": {"skin_h": 0.17, "glow_h": 0.21, "skin_s": 0.9, "skin_v": 0.85},
	"barren": {"skin_h": 0.06, "glow_h": -1.0, "skin_s": 0.12, "skin_v": 0.9},
}

static func biome_entry(biome: String) -> Dictionary:
	return BIOMES.get(biome, {"p": 0.2, "mix": {"crawler": 1.0}})

static func tint_entry(biome: String) -> Dictionary:
	return TINTS.get(biome, TINTS["lush"])

## pronounceable per-planet species name, e.g. "Karthi Grazer"
static func species_name(def: BodyDef, species: String) -> String:
	var spec: Dictionary = SPECIES[species]
	return "%s %s" % [SeedUtil.make_name(SeedUtil.hash2(def.seed, species.hash())), spec["title"]]
