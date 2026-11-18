class_name BiomeDB
extends RefCounted
## Shared, minimal biome identity data (names, colours, hazards, generation ranges).
## Module-specific tuning (terrain noise, palettes, atmosphere colours, flora tables, weather) lives in each module's OWN table keyed by these ids:
##   world/planet/terrain_profiles.gd   (M1)    world/atmosphere/atmosphere_profiles.gd (M2)    world/content/flora_tables.gd (M7)
## Do not add module-specific fields here.

const LANDABLE_IDS := ["lush", "desert", "frozen", "volcanic", "toxic", "barren", "ocean", "exotic", "swamp", "radioactive"]

const BIOMES := {
	"lush": {
		"name": "Lush", "ui_color": Color(0.30, 0.78, 0.32), "desc": "Temperate forests, grasslands and seas under a deep blue sky.",
		"landable": true, "radius": [7500.0, 11000.0], "gravity": [8.0, 11.0], "atmo_chance": 1.0, "atmo_frac": 0.45,
		"ocean": "water", "ocean_chance": 0.85, "temp_day": [18.0, 30.0], "temp_night": [4.0, 14.0], "toxic": 0.0, "radiation": 0.0,
		"zone": 0.45, "zone_width": 0.30, "weight": 1.2, "spin": [800.0, 1500.0],
	},
	"desert": {
		"name": "Scorched", "ui_color": Color(0.92, 0.66, 0.30), "desc": "Wind-carved dunes, mesas and dry canyons baked by a harsh sun.",
		"landable": true, "radius": [6500.0, 10000.0], "gravity": [7.0, 10.0], "atmo_chance": 1.0, "atmo_frac": 0.40,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [44.0, 62.0], "temp_night": [2.0, 14.0], "toxic": 0.0, "radiation": 0.0,
		"zone": 0.30, "zone_width": 0.30, "weight": 1.1, "spin": [600.0, 1300.0],
	},
	"frozen": {
		"name": "Frozen", "ui_color": Color(0.72, 0.88, 1.0), "desc": "Glaciers, ice spires and snow-swept plains in a bitter silence.",
		"landable": true, "radius": [6500.0, 10000.0], "gravity": [6.5, 10.0], "atmo_chance": 1.0, "atmo_frac": 0.40,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [-35.0, -20.0], "temp_night": [-80.0, -55.0], "toxic": 0.0, "radiation": 0.0,
		"zone": 0.85, "zone_width": 0.30, "weight": 1.0, "spin": [700.0, 1600.0],
	},
	"volcanic": {
		"name": "Volcanic", "ui_color": Color(1.0, 0.36, 0.14), "desc": "Black basalt, rivers of lava, ash storms and glowing vents.",
		"landable": true, "radius": [5500.0, 8500.0], "gravity": [9.0, 13.0], "atmo_chance": 1.0, "atmo_frac": 0.35,
		"ocean": "lava", "ocean_chance": 0.9, "temp_day": [75.0, 110.0], "temp_night": [50.0, 80.0], "toxic": 0.2, "radiation": 0.0,
		"zone": 0.05, "zone_width": 0.25, "weight": 0.9, "spin": [500.0, 1000.0],
	},
	"toxic": {
		"name": "Toxic", "ui_color": Color(0.62, 0.90, 0.18), "desc": "Acid pools, bioluminescent fungi and caustic green mists.",
		"landable": true, "radius": [4000.0, 8000.0], "gravity": [5.0, 9.0], "atmo_chance": 1.0, "atmo_frac": 0.45,
		"ocean": "acid", "ocean_chance": 0.7, "temp_day": [25.0, 45.0], "temp_night": [10.0, 28.0], "toxic": 0.75, "radiation": 0.0,
		"zone": 0.55, "zone_width": 0.45, "weight": 0.9, "spin": [700.0, 1400.0],
	},
	"barren": {
		"name": "Barren", "ui_color": Color(0.66, 0.66, 0.70), "desc": "Airless, cratered regolith under a black sky full of stars.",
		"landable": true, "radius": [2200.0, 5500.0], "gravity": [2.5, 5.5], "atmo_chance": 0.0, "atmo_frac": 0.0,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [60.0, 110.0], "temp_night": [-120.0, -80.0], "toxic": 0.0, "radiation": 0.1,
		"zone": 0.50, "zone_width": 1.0, "weight": 1.0, "spin": [900.0, 2200.0],
	},
	"ocean": {
		"name": "Ocean", "ui_color": Color(0.20, 0.55, 0.95), "desc": "A waterworld of scattered islands, coral and endless waves.",
		"landable": true, "radius": [7500.0, 11000.0], "gravity": [7.5, 10.5], "atmo_chance": 1.0, "atmo_frac": 0.50,
		"ocean": "water", "ocean_chance": 1.0, "temp_day": [20.0, 32.0], "temp_night": [10.0, 20.0], "toxic": 0.0, "radiation": 0.0,
		"zone": 0.45, "zone_width": 0.25, "weight": 0.7, "spin": [800.0, 1500.0],
	},
	"exotic": {
		"name": "Exotic", "ui_color": Color(0.82, 0.38, 1.0), "desc": "Impossible colours, crystal growths and floating rock under a violet sky.",
		"landable": true, "radius": [4000.0, 8500.0], "gravity": [4.5, 9.0], "atmo_chance": 1.0, "atmo_frac": 0.50,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [15.0, 35.0], "temp_night": [0.0, 15.0], "toxic": 0.0, "radiation": 0.15,
		"zone": 0.55, "zone_width": 0.50, "weight": 0.8, "spin": [600.0, 1500.0],
	},
	"swamp": {
		"name": "Swamp", "ui_color": Color(0.42, 0.55, 0.22), "desc": "Murky shallows, gnarled trees and drifting fog.",
		"landable": true, "radius": [6500.0, 9500.0], "gravity": [7.0, 10.0], "atmo_chance": 1.0, "atmo_frac": 0.45,
		"ocean": "water", "ocean_chance": 1.0, "temp_day": [26.0, 38.0], "temp_night": [16.0, 26.0], "toxic": 0.15, "radiation": 0.0,
		"zone": 0.40, "zone_width": 0.25, "weight": 0.6, "spin": [800.0, 1500.0],
	},
	"radioactive": {
		"name": "Irradiated", "ui_color": Color(0.85, 0.95, 0.20), "desc": "Glowing isotopes, dead forests and a sickly yellow sky.",
		"landable": true, "radius": [5000.0, 8500.0], "gravity": [6.0, 10.0], "atmo_chance": 1.0, "atmo_frac": 0.40,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [30.0, 50.0], "temp_night": [10.0, 25.0], "toxic": 0.1, "radiation": 0.8,
		"zone": 0.35, "zone_width": 0.40, "weight": 0.6, "spin": [700.0, 1400.0],
	},
	"gas": {
		"name": "Gas giant", "ui_color": Color(0.90, 0.72, 0.50), "desc": "A churning world of banded storms. No solid surface.",
		"landable": false, "radius": [28000.0, 45000.0], "gravity": [20.0, 30.0], "atmo_chance": 1.0, "atmo_frac": 0.10,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [-140.0, -100.0], "temp_night": [-140.0, -100.0], "toxic": 1.0, "radiation": 0.0,
		"zone": 0.75, "zone_width": 0.5, "weight": 0.0, "spin": [300.0, 600.0],
	},
	"blackhole": {
		"name": "Singularity", "ui_color": Color(0.55, 0.45, 1.0), "desc": "A collapsed star. Light itself cannot escape.",
		"landable": false, "radius": [2000.0, 2000.0], "gravity": [0.0, 0.0], "atmo_chance": 0.0, "atmo_frac": 0.0,
		"ocean": "", "ocean_chance": 0.0, "temp_day": [-270.0, -270.0], "temp_night": [-270.0, -270.0], "toxic": 0.0, "radiation": 1.0,
		"zone": 0.0, "zone_width": 0.0, "weight": 0.0, "spin": [1.0, 1.0],
	},
}

static func get_biome(id: String) -> Dictionary:
	return BIOMES.get(id, BIOMES["barren"])

static func display_name(id: String) -> String:
	return str(get_biome(id).get("name", id.capitalize()))

static func ui_color(id: String) -> Color:
	return get_biome(id).get("ui_color", Color.WHITE)
