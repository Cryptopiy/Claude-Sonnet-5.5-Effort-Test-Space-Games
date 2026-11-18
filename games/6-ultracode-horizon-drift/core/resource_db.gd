class_name ResourceDB
extends RefCounted
## Gatherable resources (the surface "core loop"). Models are made in Blender (see docs/MODELS_SPEC.md group flora3).

const RESOURCES := {
	"ferrite": {
		"name": "Ferrite", "color": Color(0.95, 0.52, 0.18), "model": "res_ore_ferrite", "hp": 3.0, "yield": [6, 12],
		"use": "Hull repair (reinforces the ship hull)", "effect": "hull",
	},
	"zyrite": {
		"name": "Zyrite", "color": Color(0.45, 0.85, 1.0), "model": "res_fuel_crystal", "hp": 2.0, "yield": [4, 9],
		"use": "Pulse-drive fuel", "effect": "fuel",
	},
	"sodium": {
		"name": "Sodium", "color": Color(0.85, 0.95, 0.30), "model": "res_bulb_plant", "hp": 1.0, "yield": [8, 16],
		"use": "Recharges exosuit hazard protection", "effect": "protection",
	},
	"voidstone": {
		"name": "Voidstone", "color": Color(0.82, 0.32, 1.0), "model": "res_warp_crystal", "hp": 5.0, "yield": [1, 2],
		"use": "Crafts hyperdrive warp cells (3 Voidstone = 1 cell)", "effect": "warp",
	},
}

static func ids() -> Array:
	return RESOURCES.keys()

static func info(id: String) -> Dictionary:
	return RESOURCES.get(id, {})
