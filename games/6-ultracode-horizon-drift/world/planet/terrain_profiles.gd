class_name TerrainProfiles
extends RefCounted
## Per-biome terrain tuning (module M1). Keyed by BiomeDB ids. Everything the generator + the terrain shader need to look different per biome.
##  sea         : water level in metres relative to the base radius (applies only when the BodyDef has an ocean; lush/ocean/swamp = water, volcanic = lava, toxic = acid)
##  amp         : overall height scale
##  pal         : palette colours (sRGB) - meaning is biome specific, see TerrainGen._color_* functions
##  rock/rock2  : shader slope-rock colours      rough/spec : shader PBR      emit/emit_energy : emissive colour for the alpha mask
##  rock_lo/hi  : slope thresholds (1 - cos(angle)) where rock starts / fully covers
##  detail      : [fine scale (m), medium scale (m), normal strength fine, normal strength medium, colour variation]

const P := {
	"lush": {
		"dirt": Color(0.33, 0.25, 0.14), "grain": 0.55, "beach_h": 3.2,
		"sea": 0.0, "amp": 1.0,
		"pal": [Color(0.82, 0.76, 0.56), Color(0.15, 0.34, 0.10), Color(0.34, 0.53, 0.17), Color(0.08, 0.22, 0.07), Color(0.46, 0.44, 0.40), Color(0.94, 0.97, 1.0), Color(0.56, 0.54, 0.25)],
		"rock": Color(0.36, 0.35, 0.33), "rock2": Color(0.54, 0.52, 0.48), "rough": 0.92, "spec": 0.18,
		"emit": Color(0, 0, 0), "emit_energy": 0.0, "rock_lo": 0.24, "rock_hi": 0.46,
		"detail": [2.3, 15.0, 0.55, 0.45, 0.34],
	},
	"desert": {
		"dirt": Color(0.58, 0.34, 0.20), "grain": 0.45, "ripple": 0.42,
		"sea": 0.0, "amp": 1.0,
		"pal": [Color(0.86, 0.62, 0.32), Color(0.78, 0.40, 0.18), Color(0.93, 0.80, 0.55), Color(0.60, 0.28, 0.16), Color(0.77, 0.52, 0.30), Color(0.45, 0.25, 0.16), Color(0.95, 0.88, 0.70)],
		"rock": Color(0.47, 0.27, 0.17), "rock2": Color(0.64, 0.38, 0.22), "rough": 0.96, "spec": 0.12,
		"emit": Color(0, 0, 0), "emit_energy": 0.0, "rock_lo": 0.30, "rock_hi": 0.55,
		"detail": [1.6, 11.0, 0.42, 0.40, 0.22],
	},
	"frozen": {
		"dirt": Color(0.42, 0.55, 0.72), "grain": 0.30, "ripple": 0.16,
		"sea": 0.0, "amp": 1.0,
		"pal": [Color(0.93, 0.96, 1.0), Color(0.62, 0.80, 0.95), Color(0.30, 0.55, 0.78), Color(0.22, 0.24, 0.30), Color(0.80, 0.90, 0.98), Color(0.55, 0.70, 0.86), Color(1, 1, 1)],
		"rock": Color(0.26, 0.28, 0.33), "rock2": Color(0.42, 0.45, 0.52), "rough": 0.55, "spec": 0.5,
		"emit": Color(0.2, 0.5, 1.0), "emit_energy": 0.0, "rock_lo": 0.26, "rock_hi": 0.5,
		"detail": [2.0, 14.0, 0.40, 0.45, 0.14],
	},
	"volcanic": {
		"dirt": Color(0.10, 0.085, 0.085), "grain": 0.65,
		"sea": -4.0, "amp": 1.0,
		"pal": [Color(0.075, 0.07, 0.08), Color(0.17, 0.15, 0.145), Color(0.30, 0.12, 0.07), Color(0.04, 0.04, 0.05), Color(0.50, 0.08, 0.02), Color(0.28, 0.22, 0.18), Color(1.0, 0.45, 0.08)],
		"rock": Color(0.055, 0.05, 0.055), "rock2": Color(0.20, 0.17, 0.16), "rough": 0.85, "spec": 0.3,
		"emit": Color(1.0, 0.30, 0.04), "emit_energy": 1.8, "rock_lo": 0.22, "rock_hi": 0.45,
		"detail": [1.8, 12.0, 0.65, 0.5, 0.35],
	},
	"toxic": {
		"dirt": Color(0.26, 0.16, 0.30), "grain": 0.55,
		"sea": -2.5, "amp": 1.0,
		"pal": [Color(0.36, 0.17, 0.46), Color(0.38, 0.47, 0.12), Color(0.68, 0.74, 0.16), Color(0.12, 0.05, 0.18), Color(0.62, 0.26, 0.66), Color(0.20, 0.36, 0.22), Color(0.55, 1.0, 0.2)],
		"rock": Color(0.19, 0.12, 0.24), "rock2": Color(0.30, 0.22, 0.36), "rough": 0.8, "spec": 0.3,
		"emit": Color(0.35, 1.0, 0.12), "emit_energy": 1.6, "rock_lo": 0.25, "rock_hi": 0.5,
		"detail": [1.5, 9.0, 0.6, 0.5, 0.35],
	},
	"barren": {
		"dirt": Color(0.40, 0.38, 0.36), "grain": 0.60,
		"sea": 0.0, "amp": 1.0,
		"pal": [Color(0.50, 0.49, 0.48), Color(0.37, 0.36, 0.37), Color(0.64, 0.62, 0.60), Color(0.26, 0.26, 0.28), Color(0.52, 0.46, 0.40), Color(0.44, 0.43, 0.43), Color(0.70, 0.68, 0.66)],
		"rock": Color(0.30, 0.30, 0.31), "rock2": Color(0.46, 0.45, 0.44), "rough": 0.97, "spec": 0.08,
		"emit": Color(0, 0, 0), "emit_energy": 0.0, "rock_lo": 0.32, "rock_hi": 0.62,
		"detail": [1.4, 9.0, 0.5, 0.45, 0.2],
	},
	"ocean": {
		"dirt": Color(0.52, 0.46, 0.34), "grain": 0.45, "beach_h": 6.5,
		"sea": 0.0, "amp": 0.8,
		"pal": [Color(0.93, 0.89, 0.72), Color(0.25, 0.55, 0.17), Color(0.40, 0.66, 0.20), Color(0.35, 0.68, 0.64), Color(0.10, 0.28, 0.42), Color(0.60, 0.56, 0.48), Color(0.85, 0.80, 0.60)],
		"rock": Color(0.40, 0.37, 0.34), "rock2": Color(0.55, 0.52, 0.46), "rough": 0.9, "spec": 0.2,
		"emit": Color(0, 0, 0), "emit_energy": 0.0, "rock_lo": 0.22, "rock_hi": 0.45,
		"detail": [2.2, 14.0, 0.45, 0.4, 0.22],
	},
	"exotic": {
		"dirt": Color(0.34, 0.14, 0.46), "grain": 0.45,
		"sea": 0.0, "amp": 1.0,
		"pal": [Color(0.78, 0.14, 0.66), Color(0.12, 0.70, 0.82), Color(0.36, 0.16, 0.72), Color(0.95, 0.74, 0.18), Color(0.20, 0.08, 0.38), Color(0.95, 0.45, 0.85), Color(0.5, 1.0, 1.0)],
		"rock": Color(0.22, 0.10, 0.34), "rock2": Color(0.50, 0.25, 0.60), "rough": 0.5, "spec": 0.6,
		"emit": Color(0.75, 0.35, 1.0), "emit_energy": 3.0, "rock_lo": 0.30, "rock_hi": 0.60,
		"detail": [1.8, 12.0, 0.4, 0.35, 0.3],
	},
	"swamp": {
		"dirt": Color(0.24, 0.20, 0.12), "grain": 0.55,
		"sea": 1.0, "amp": 0.6,
		"pal": [Color(0.31, 0.34, 0.14), Color(0.20, 0.20, 0.11), Color(0.18, 0.37, 0.12), Color(0.16, 0.22, 0.14), Color(0.42, 0.40, 0.20), Color(0.30, 0.28, 0.18), Color(0.5, 0.6, 0.2)],
		"rock": Color(0.26, 0.25, 0.20), "rock2": Color(0.36, 0.34, 0.26), "rough": 0.95, "spec": 0.14,
		"emit": Color(0.5, 0.9, 0.2), "emit_energy": 1.0, "rock_lo": 0.25, "rock_hi": 0.5,
		"detail": [1.8, 12.0, 0.5, 0.4, 0.3],
	},
	"radioactive": {
		"dirt": Color(0.40, 0.38, 0.24), "grain": 0.55,
		"sea": 0.0, "amp": 0.9,
		"pal": [Color(0.62, 0.66, 0.18), Color(0.40, 0.38, 0.30), Color(0.75, 0.82, 0.22), Color(0.24, 0.23, 0.18), Color(0.55, 0.50, 0.28), Color(0.33, 0.36, 0.20), Color(0.6, 1.0, 0.1)],
		"rock": Color(0.28, 0.27, 0.20), "rock2": Color(0.42, 0.40, 0.28), "rough": 0.9, "spec": 0.15,
		"emit": Color(0.55, 1.0, 0.08), "emit_energy": 3.0, "rock_lo": 0.28, "rock_hi": 0.55,
		"detail": [1.6, 10.0, 0.5, 0.45, 0.3],
	},
}

static func get_profile(biome: String) -> Dictionary:
	if P.has(biome):
		return P[biome]
	return P["barren"]
