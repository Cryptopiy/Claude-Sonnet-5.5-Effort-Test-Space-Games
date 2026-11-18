class_name Biomes
extends RefCounted
## Static biome library. Each biome is a Dictionary describing terrain shape, colour palette, atmosphere,
## weather, hazards and flora. `make_profile()` resolves a biome + seed into a per-planet variant.

const LANDABLE_IDS: Array[String] = ["lush", "desert", "volcanic", "frozen", "toxic", "dead", "radioactive"]

static func _c(r: float, g: float, b: float) -> Color:
	return Color(r, g, b)

## palette stops: [s, Color] where s = (height - sea) / H   (H = sum of terrain amplitudes)
static func def(id: String) -> Dictionary:
	match id:
		"lush":
			return {
				"id": "lush", "label": "Verdant", "adj": "Lush",
				"terrain": {"amp_cont": 0.020, "wl_cont": 1.25, "cont_bias": 0.16, "amp_hill": 0.0085, "wl_hill": 0.19,
					"amp_mount": 0.052, "wl_mount": 0.26, "mount_cover": 0.42, "ridge_pow": 1.5, "detail_amp": 2.6, "detail_wl": 34.0,
					"sea": -0.0015, "terrace": 0.0},
				"palette_a": [[-0.5, _c(0.05, 0.14, 0.18)], [-0.06, _c(0.20, 0.30, 0.26)], [0.0, _c(0.72, 0.66, 0.45)], [0.035, _c(0.33, 0.50, 0.16)],
					[0.14, _c(0.24, 0.50, 0.15)], [0.32, _c(0.14, 0.38, 0.13)], [0.55, _c(0.40, 0.37, 0.32)], [0.8, _c(0.50, 0.48, 0.46)], [1.0, _c(0.92, 0.94, 0.98)]],
				"palette_b": [[-0.5, _c(0.05, 0.14, 0.18)], [-0.06, _c(0.20, 0.30, 0.26)], [0.0, _c(0.78, 0.70, 0.48)], [0.035, _c(0.44, 0.56, 0.18)],
					[0.14, _c(0.36, 0.56, 0.16)], [0.32, _c(0.22, 0.44, 0.14)], [0.55, _c(0.45, 0.40, 0.34)], [0.8, _c(0.52, 0.50, 0.48)], [1.0, _c(0.92, 0.94, 0.98)]],
				"rock": _c(0.36, 0.33, 0.30), "rock_slope": [0.20, 0.50], "veg_max_slope": 0.30, "veg_from": 0.004, "veg_to": 0.55,
				"snow_line": 0.82, "sheen_water": true,
				"ground": "grass", "roughness": 0.92,
				"atm": {"on": true, "thick": 0.26, "scale": 0.24, "rayleigh": Vector3(0.060, 0.150, 0.360), "sky_tint": Vector3(0.92, 0.72, 1.05), "sky_sat": 1.9, "mie": 0.020, "mie_g": 0.78, "haze": Color(0.55, 0.75, 1.0), "ambient": Color(0.45, 0.60, 0.85), "ambient_e": 0.55, "fog_d": 0.0004},
				"clouds": {"cover": 0.46, "color": Color(1, 1, 1), "alt": 0.07, "speed": 0.012, "dark": 0.55},
				"ocean": {"on": true, "shallow": Color(0.10, 0.55, 0.60), "deep": Color(0.01, 0.10, 0.26), "foam": Color(1, 1, 1), "kind": "water"},
				"weather": {"type": "rain", "chance": 0.35, "intensity": 0.9},
				"hazard": {"type": "none", "level": 0.0, "temp": 22},
				"gravity": [8.0, 11.0], "day": [700.0, 1100.0], "sun_boost": 1.0,
				"flora": [
					{"model": "tree_lush_a", "density": 0.0022, "slope_max": 0.24, "s": [0.03, 0.5], "scale": [0.8, 1.35], "tint": "foliage", "collide": true, "veg": 0.45},
					{"model": "tree_lush_b", "density": 0.0016, "slope_max": 0.24, "s": [0.04, 0.45], "scale": [0.8, 1.3], "tint": "foliage", "collide": true, "veg": 0.5},
					{"model": "tree_lush_c", "density": 0.0007, "slope_max": 0.22, "s": [0.03, 0.4], "scale": [0.8, 1.2], "tint": "foliage2", "collide": true, "veg": 0.6},
					{"model": "bush_lush", "density": 0.0060, "slope_max": 0.32, "s": [0.02, 0.6], "scale": [0.7, 1.5], "tint": "foliage", "collide": false, "veg": 0.3},
					{"model": "fern", "density": 0.0050, "slope_max": 0.32, "s": [0.02, 0.5], "scale": [0.7, 1.4], "tint": "foliage", "collide": false, "veg": 0.4},
					{"model": "flower_cluster", "density": 0.0090, "slope_max": 0.28, "s": [0.02, 0.4], "scale": [0.8, 1.6], "tint": "flower", "collide": false, "veg": 0.4},
					{"model": "grass_tuft", "density": 0.060, "slope_max": 0.36, "s": [0.015, 0.55], "scale": [0.8, 1.5], "tint": "grass", "collide": false, "veg": 0.2, "near_only": true},
					{"model": "rock_a", "density": 0.0016, "slope_max": 1.0, "s": [-0.02, 0.9], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_b", "density": 0.0010, "slope_max": 1.0, "s": [-0.02, 0.9], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_c", "density": 0.0008, "slope_max": 1.0, "s": [-0.02, 0.9], "scale": [0.6, 1.5], "tint": "rock", "collide": true, "veg": 0.0},
				],
				"fauna": ["grazer", "flyer", "crawler"], "resources": ["carbon", "ferrite", "sodium"],
				"tint": {"foliage": Color(0.34, 0.62, 0.20), "foliage2": Color(0.80, 0.42, 0.62), "grass": Color(0.40, 0.66, 0.22), "flower": Color(1.0, 0.8, 0.3), "rock": Color(0.62, 0.58, 0.52)},
			}
		"desert":
			return {
				"id": "desert", "label": "Arid", "adj": "Barren",
				"terrain": {"amp_cont": 0.012, "wl_cont": 0.9, "cont_bias": 0.0, "amp_hill": 0.007, "wl_hill": 0.16,
					"amp_mount": 0.050, "wl_mount": 0.22, "mount_cover": 0.55, "ridge_pow": 1.2, "detail_amp": 1.6, "detail_wl": 26.0,
					"terrace": 0.75, "terrace_step": 26.0, "dune_amp": 7.0, "dune_wl": 120.0},
				"palette_a": [[-0.5, _c(0.55, 0.30, 0.16)], [0.0, _c(0.78, 0.46, 0.22)], [0.12, _c(0.86, 0.60, 0.30)], [0.3, _c(0.66, 0.34, 0.18)],
					[0.5, _c(0.50, 0.24, 0.14)], [0.75, _c(0.78, 0.52, 0.32)], [1.0, _c(0.88, 0.70, 0.50)]],
				"palette_b": [[-0.5, _c(0.70, 0.55, 0.36)], [0.0, _c(0.88, 0.76, 0.52)], [0.12, _c(0.92, 0.82, 0.60)], [0.3, _c(0.78, 0.58, 0.38)],
					[0.5, _c(0.60, 0.36, 0.24)], [0.75, _c(0.82, 0.62, 0.42)], [1.0, _c(0.92, 0.80, 0.62)]],
				"rock": _c(0.42, 0.22, 0.14), "rock_slope": [0.18, 0.46], "veg_max_slope": 0.2, "veg_from": 0.05, "veg_to": 0.4,
				"snow_line": 9.0, "ground": "sand", "roughness": 0.95, "banded": true,
				"atm": {"on": true, "thick": 0.22, "scale": 0.26, "rayleigh": Vector3(0.340, 0.170, 0.075), "mie": 0.120, "mie_g": 0.70, "haze": Color(1.0, 0.70, 0.45), "ambient": Color(0.95, 0.62, 0.40), "ambient_e": 0.60, "fog_d": 0.0007},
				"clouds": {"cover": 0.12, "color": Color(1.0, 0.82, 0.62), "alt": 0.08, "speed": 0.02, "dark": 0.6},
				"ocean": {"on": false},
				"weather": {"type": "dust", "chance": 0.40, "intensity": 0.9},
				"hazard": {"type": "heat", "level": 0.45, "temp": 62},
				"gravity": [6.5, 9.5], "day": [600.0, 950.0], "sun_boost": 0.62,
				"flora": [
					{"model": "cactus_a", "density": 0.0014, "slope_max": 0.22, "s": [0.0, 0.5], "scale": [0.8, 1.5], "tint": "cactus", "collide": true, "veg": 0.3},
					{"model": "cactus_b", "density": 0.0022, "slope_max": 0.25, "s": [0.0, 0.5], "scale": [0.8, 1.4], "tint": "cactus", "collide": false, "veg": 0.3},
					{"model": "dead_tree", "density": 0.0007, "slope_max": 0.25, "s": [0.0, 0.5], "scale": [0.8, 1.4], "tint": "wood", "collide": true, "veg": 0.5},
					{"model": "desert_shrub", "density": 0.0045, "slope_max": 0.3, "s": [0.0, 0.6], "scale": [0.7, 1.4], "tint": "shrub", "collide": false, "veg": 0.3},
					{"model": "mesa_rock", "density": 0.00022, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.8, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_a", "density": 0.0014, "slope_max": 1.0, "s": [-0.1, 1.0], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_b", "density": 0.0010, "slope_max": 1.0, "s": [-0.1, 1.0], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_d", "density": 0.0006, "slope_max": 1.0, "s": [-0.1, 1.0], "scale": [0.6, 1.6], "tint": "rock", "collide": true, "veg": 0.0},
				],
				"fauna": ["crawler", "flyer"], "resources": ["ferrite", "sodium", "carbon"],
				"tint": {"foliage": Color(0.50, 0.58, 0.22), "cactus": Color(0.40, 0.58, 0.28), "wood": Color(0.62, 0.50, 0.40), "shrub": Color(0.62, 0.55, 0.26), "rock": Color(0.92, 0.62, 0.42)},
			}
		"volcanic":
			return {
				"id": "volcanic", "label": "Volcanic", "adj": "Scorched",
				"terrain": {"amp_cont": 0.016, "wl_cont": 0.8, "cont_bias": -0.02, "amp_hill": 0.012, "wl_hill": 0.14,
					"amp_mount": 0.075, "wl_mount": 0.20, "mount_cover": 0.55, "ridge_pow": 1.1, "detail_amp": 4.2, "detail_wl": 22.0,
					"cones": 7, "cone_h": 0.10, "cone_w": 0.17, "lava": -0.0062, "terrace": 0.0},
				"palette_a": [[-0.5, _c(0.05, 0.04, 0.04)], [0.0, _c(0.08, 0.07, 0.07)], [0.2, _c(0.13, 0.11, 0.10)], [0.45, _c(0.20, 0.16, 0.14)],
					[0.7, _c(0.28, 0.22, 0.20)], [1.0, _c(0.42, 0.36, 0.33)]],
				"palette_b": [[-0.5, _c(0.08, 0.05, 0.04)], [0.0, _c(0.18, 0.08, 0.05)], [0.2, _c(0.26, 0.12, 0.07)], [0.45, _c(0.32, 0.17, 0.10)],
					[0.7, _c(0.36, 0.24, 0.16)], [1.0, _c(0.46, 0.38, 0.32)]],
				"rock": _c(0.07, 0.065, 0.065), "rock_slope": [0.18, 0.42], "veg_max_slope": 0.0, "veg_from": 9.0, "veg_to": 9.5,
				"snow_line": 9.0, "ground": "rock", "roughness": 0.85, "lava_color": Color(1.0, 0.30, 0.05),
				"atm": {"on": true, "thick": 0.24, "scale": 0.22, "rayleigh": Vector3(0.320, 0.105, 0.040), "sky_tint": Vector3(1.0, 0.62, 0.42), "sky_sat": 1.6, "mie": 0.38, "mie_g": 0.62, "haze": Color(0.9, 0.35, 0.18), "ambient": Color(0.85, 0.38, 0.22), "ambient_e": 0.45, "fog_d": 0.0012},
				"clouds": {"cover": 0.55, "color": Color(0.22, 0.17, 0.16), "alt": 0.09, "speed": 0.03, "dark": 0.2},
				"ocean": {"on": false},
				"weather": {"type": "ash", "chance": 0.7, "intensity": 0.8},
				"hazard": {"type": "heat", "level": 0.85, "temp": 118},
				"gravity": [8.5, 12.0], "day": [500.0, 800.0], "sun_boost": 1.35,
				"flora": [
					{"model": "obsidian_spire", "density": 0.0006, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.8, 1.7], "tint": "obsidian", "collide": true, "veg": 0.0},
					{"model": "lava_rock", "density": 0.0020, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.7, 1.7], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "charred_tree", "density": 0.0007, "slope_max": 0.3, "s": [0.02, 0.5], "scale": [0.8, 1.4], "tint": "wood", "collide": true, "veg": 0.0},
					{"model": "vent_cone", "density": 0.00045, "slope_max": 0.3, "s": [0.0, 0.7], "scale": [0.8, 1.6], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_a", "density": 0.0012, "slope_max": 1.0, "s": [0.0, 1.0], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "rock_d", "density": 0.0008, "slope_max": 1.0, "s": [0.0, 1.0], "scale": [0.6, 1.6], "tint": "rock", "collide": true, "veg": 0.0},
				],
				"fauna": ["crawler"], "resources": ["ferrite", "sodium"],
				"tint": {"rock": Color(0.30, 0.27, 0.26), "obsidian": Color(0.15, 0.13, 0.17), "wood": Color(0.14, 0.12, 0.11), "foliage": Color(0.3, 0.2, 0.15)},
			}
		"frozen":
			return {
				"id": "frozen", "label": "Glacial", "adj": "Frozen",
				"terrain": {"amp_cont": 0.015, "wl_cont": 1.1, "cont_bias": 0.05, "amp_hill": 0.010, "wl_hill": 0.17,
					"amp_mount": 0.062, "wl_mount": 0.24, "mount_cover": 0.40, "ridge_pow": 1.9, "detail_amp": 2.2, "detail_wl": 30.0,
					"lake": -0.0035, "terrace": 0.0},
				"palette_a": [[-0.5, _c(0.40, 0.58, 0.72)], [0.0, _c(0.58, 0.76, 0.90)], [0.1, _c(0.88, 0.93, 1.0)], [0.35, _c(0.80, 0.88, 0.98)],
					[0.6, _c(0.50, 0.58, 0.68)], [0.85, _c(0.86, 0.92, 1.0)], [1.0, _c(0.97, 0.98, 1.0)]],
				"palette_b": [[-0.5, _c(0.30, 0.50, 0.70)], [0.0, _c(0.46, 0.68, 0.86)], [0.1, _c(0.78, 0.88, 0.98)], [0.35, _c(0.70, 0.82, 0.96)],
					[0.6, _c(0.40, 0.50, 0.64)], [0.85, _c(0.82, 0.90, 1.0)], [1.0, _c(0.96, 0.98, 1.0)]],
				"rock": _c(0.30, 0.34, 0.42), "rock_slope": [0.25, 0.55], "veg_max_slope": 0.25, "veg_from": 0.05, "veg_to": 0.5,
				"snow_line": 0.0, "ground": "snow", "roughness": 0.55, "ice": true,
				"atm": {"on": true, "thick": 0.20, "scale": 0.22, "rayleigh": Vector3(0.140, 0.270, 0.520), "sky_tint": Vector3(0.92, 0.80, 1.04), "sky_sat": 1.5, "mie": 0.040, "mie_g": 0.8, "haze": Color(0.75, 0.88, 1.0), "ambient": Color(0.62, 0.74, 0.95), "ambient_e": 0.65, "fog_d": 0.0007},
				"clouds": {"cover": 0.30, "color": Color(0.92, 0.96, 1.0), "alt": 0.06, "speed": 0.015, "dark": 0.7},
				"ocean": {"on": false},
				"weather": {"type": "snow", "chance": 0.55, "intensity": 0.9},
				"hazard": {"type": "cold", "level": 0.55, "temp": -62},
				"gravity": [5.5, 8.0], "day": [800.0, 1300.0], "sun_boost": 0.9,
				"flora": [
					{"model": "tree_pine_snow", "density": 0.0016, "slope_max": 0.3, "s": [0.0, 0.55], "scale": [0.8, 1.4], "tint": "pine", "collide": true, "veg": 0.0},
					{"model": "tree_pine_snow_b", "density": 0.0018, "slope_max": 0.3, "s": [0.0, 0.6], "scale": [0.8, 1.4], "tint": "pine", "collide": true, "veg": 0.0},
					{"model": "ice_spire", "density": 0.0007, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.8, 1.8], "tint": "ice", "collide": true, "veg": 0.0},
					{"model": "ice_boulder", "density": 0.0014, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.7, 1.7], "tint": "ice", "collide": true, "veg": 0.0},
					{"model": "frost_shrub", "density": 0.0035, "slope_max": 0.3, "s": [0.0, 0.6], "scale": [0.7, 1.4], "tint": "frost", "collide": false, "veg": 0.0},
					{"model": "snow_rock", "density": 0.0014, "slope_max": 1.0, "s": [0.0, 1.0], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
				],
				"fauna": ["grazer", "flyer"], "resources": ["sodium", "ferrite", "carbon"],
				"tint": {"pine": Color(0.30, 0.50, 0.42), "ice": Color(0.62, 0.84, 1.0), "frost": Color(0.55, 0.75, 0.85), "rock": Color(0.58, 0.62, 0.68), "foliage": Color(0.4, 0.6, 0.55)},
			}
		"toxic":
			return {
				"id": "toxic", "label": "Toxic", "adj": "Toxic",
				"terrain": {"amp_cont": 0.011, "wl_cont": 1.0, "cont_bias": -0.04, "amp_hill": 0.013, "wl_hill": 0.15,
					"amp_mount": 0.034, "wl_mount": 0.20, "mount_cover": 0.30, "ridge_pow": 1.4, "detail_amp": 2.6, "detail_wl": 24.0,
					"sea": 0.0008, "terrace": 0.0},
				"palette_a": [[-0.5, _c(0.10, 0.18, 0.06)], [-0.05, _c(0.18, 0.26, 0.08)], [0.0, _c(0.34, 0.38, 0.12)], [0.1, _c(0.40, 0.46, 0.14)],
					[0.3, _c(0.30, 0.34, 0.14)], [0.6, _c(0.34, 0.26, 0.30)], [1.0, _c(0.50, 0.44, 0.50)]],
				"palette_b": [[-0.5, _c(0.12, 0.10, 0.18)], [-0.05, _c(0.20, 0.14, 0.24)], [0.0, _c(0.32, 0.22, 0.34)], [0.1, _c(0.44, 0.30, 0.40)],
					[0.3, _c(0.34, 0.26, 0.36)], [0.6, _c(0.38, 0.30, 0.34)], [1.0, _c(0.55, 0.48, 0.52)]],
				"rock": _c(0.24, 0.22, 0.26), "rock_slope": [0.25, 0.55], "veg_max_slope": 0.3, "veg_from": 0.0, "veg_to": 0.5,
				"snow_line": 9.0, "ground": "mud", "roughness": 0.75, "glow_veins": true,
				"atm": {"on": true, "thick": 0.28, "scale": 0.26, "rayleigh": Vector3(0.200, 0.340, 0.090), "mie": 0.22, "mie_g": 0.72, "haze": Color(0.65, 0.9, 0.3), "ambient": Color(0.50, 0.70, 0.30), "ambient_e": 0.55, "fog_d": 0.0016},
				"clouds": {"cover": 0.5, "color": Color(0.70, 0.88, 0.40), "alt": 0.06, "speed": 0.01, "dark": 0.55},
				"ocean": {"on": true, "shallow": Color(0.35, 0.65, 0.12), "deep": Color(0.06, 0.20, 0.04), "foam": Color(0.85, 1.0, 0.4), "kind": "acid"},
				"weather": {"type": "spores", "chance": 0.7, "intensity": 0.9},
				"hazard": {"type": "toxic", "level": 0.65, "temp": 34},
				"gravity": [7.0, 10.0], "day": [650.0, 1000.0], "sun_boost": 0.95,
				"flora": [
					{"model": "mushroom_giant", "density": 0.0012, "slope_max": 0.3, "s": [0.0, 0.6], "scale": [0.8, 1.5], "tint": "glow_a", "collide": true, "veg": 0.0},
					{"model": "mushroom_small", "density": 0.0050, "slope_max": 0.35, "s": [0.0, 0.7], "scale": [0.8, 1.6], "tint": "glow_b", "collide": false, "veg": 0.0},
					{"model": "spore_pod", "density": 0.0030, "slope_max": 0.35, "s": [0.0, 0.6], "scale": [0.8, 1.5], "tint": "glow_a", "collide": false, "veg": 0.0},
					{"model": "tentacle_plant", "density": 0.0018, "slope_max": 0.35, "s": [0.0, 0.6], "scale": [0.8, 1.4], "tint": "tentacle", "collide": false, "veg": 0.0},
					{"model": "toxic_crystal", "density": 0.0008, "slope_max": 1.0, "s": [0.0, 0.8], "scale": [0.8, 1.7], "tint": "glow_c", "collide": true, "veg": 0.0},
					{"model": "rock_c", "density": 0.0008, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.6, 1.5], "tint": "rock", "collide": true, "veg": 0.0},
				],
				"fauna": ["floater", "crawler"], "resources": ["carbon", "sodium", "ferrite"],
				"tint": {"glow_a": Color(0.55, 1.0, 0.25), "glow_b": Color(0.85, 0.35, 1.0), "glow_c": Color(0.4, 1.0, 0.5), "tentacle": Color(0.55, 0.30, 0.70), "rock": Color(0.40, 0.36, 0.40), "foliage": Color(0.5, 0.7, 0.2)},
			}
		"dead":
			return {
				"id": "dead", "label": "Barren", "adj": "Airless",
				"terrain": {"amp_cont": 0.010, "wl_cont": 0.9, "cont_bias": 0.0, "amp_hill": 0.007, "wl_hill": 0.12,
					"amp_mount": 0.030, "wl_mount": 0.18, "mount_cover": 0.35, "ridge_pow": 1.3, "detail_amp": 3.0, "detail_wl": 20.0,
					"crater": 0.55, "crater_wl": 0.30, "terrace": 0.0},
				"palette_a": [[-0.5, _c(0.20, 0.20, 0.21)], [0.0, _c(0.34, 0.33, 0.33)], [0.3, _c(0.46, 0.45, 0.44)], [0.6, _c(0.55, 0.53, 0.52)],
					[1.0, _c(0.72, 0.70, 0.68)]],
				"palette_b": [[-0.5, _c(0.12, 0.12, 0.13)], [0.0, _c(0.22, 0.22, 0.24)], [0.3, _c(0.34, 0.33, 0.34)], [0.6, _c(0.42, 0.41, 0.42)],
					[1.0, _c(0.60, 0.59, 0.60)]],
				"rock": _c(0.30, 0.29, 0.29), "rock_slope": [0.22, 0.5], "veg_max_slope": 0.0, "veg_from": 9.0, "veg_to": 9.5,
				"snow_line": 9.0, "ground": "regolith", "roughness": 0.98,
				"atm": {"on": false, "thick": 0.0, "scale": 0.2, "rayleigh": Vector3(0, 0, 0), "mie": 0.0, "mie_g": 0.7, "haze": Color(0, 0, 0), "ambient": Color(0.20, 0.22, 0.28), "ambient_e": 0.12, "fog_d": 0.0},
				"clouds": {"cover": 0.0, "color": Color(1, 1, 1), "alt": 0.05, "speed": 0.0, "dark": 0.5},
				"ocean": {"on": false},
				"weather": {"type": "none", "chance": 0.0, "intensity": 0.0},
				"hazard": {"type": "cold", "level": 0.30, "temp": -48},
				"gravity": [1.8, 3.4], "day": [900.0, 1500.0], "sun_boost": 1.0,
				"flora": [
					{"model": "moon_rock_a", "density": 0.0020, "slope_max": 1.0, "s": [-0.5, 1.0], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "moon_rock_b", "density": 0.0016, "slope_max": 1.0, "s": [-0.5, 1.0], "scale": [0.6, 1.8], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "boulder_big", "density": 0.00018, "slope_max": 1.0, "s": [-0.5, 1.0], "scale": [0.8, 1.6], "tint": "rock", "collide": true, "veg": 0.0},
					{"model": "probe_wreck", "density": 0.00004, "slope_max": 0.3, "s": [-0.5, 1.0], "scale": [1.0, 1.0], "tint": "none", "collide": true, "veg": 0.0},
				],
				"fauna": [], "resources": ["ferrite", "sodium"],
				"tint": {"rock": Color(0.62, 0.60, 0.58)},
			}
		"radioactive":
			return {
				"id": "radioactive", "label": "Irradiated", "adj": "Irradiated",
				"terrain": {"amp_cont": 0.015, "wl_cont": 0.85, "cont_bias": 0.0, "amp_hill": 0.010, "wl_hill": 0.15,
					"amp_mount": 0.070, "wl_mount": 0.20, "mount_cover": 0.5, "ridge_pow": 2.2, "detail_amp": 3.2, "detail_wl": 22.0, "terrace": 0.0},
				"palette_a": [[-0.5, _c(0.26, 0.30, 0.18)], [0.0, _c(0.32, 0.37, 0.22)], [0.2, _c(0.38, 0.43, 0.27)], [0.5, _c(0.45, 0.49, 0.33)],
					[1.0, _c(0.62, 0.64, 0.52)]],
				"palette_b": [[-0.5, _c(0.28, 0.21, 0.32)], [0.0, _c(0.35, 0.26, 0.40)], [0.2, _c(0.42, 0.32, 0.46)], [0.5, _c(0.50, 0.40, 0.54)],
					[1.0, _c(0.66, 0.58, 0.70)]],
				"rock": _c(0.20, 0.21, 0.19), "rock_slope": [0.2, 0.5], "veg_max_slope": 0.0, "veg_from": 9.0, "veg_to": 9.5,
				"snow_line": 9.0, "ground": "rock", "roughness": 0.8, "glow_veins": true, "vein_color": Color(0.35, 1.0, 0.25),
				"atm": {"on": true, "thick": 0.22, "scale": 0.22, "rayleigh": Vector3(0.250, 0.380, 0.140), "mie": 0.16, "mie_g": 0.7, "haze": Color(0.55, 1.0, 0.45), "ambient": Color(0.35, 0.55, 0.30), "ambient_e": 0.45, "fog_d": 0.0011},
				"clouds": {"cover": 0.35, "color": Color(0.5, 0.7, 0.4), "alt": 0.08, "speed": 0.02, "dark": 0.4},
				"ocean": {"on": false},
				"weather": {"type": "spores", "chance": 0.6, "intensity": 0.6},
				"hazard": {"type": "radiation", "level": 0.75, "temp": 28},
				"gravity": [7.0, 10.0], "day": [600.0, 900.0], "sun_boost": 1.55,
				"flora": [
					{"model": "crystal_cluster_a", "density": 0.0014, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.8, 1.8], "tint": "glow_a", "collide": true, "veg": 0.0},
					{"model": "crystal_cluster_b", "density": 0.0010, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.8, 1.8], "tint": "glow_a", "collide": true, "veg": 0.0},
					{"model": "crystal_cluster_c", "density": 0.0007, "slope_max": 1.0, "s": [0.0, 0.9], "scale": [0.8, 1.8], "tint": "glow_b", "collide": true, "veg": 0.0},
					{"model": "rad_fungus", "density": 0.0030, "slope_max": 0.4, "s": [0.0, 0.8], "scale": [0.8, 1.6], "tint": "glow_a", "collide": false, "veg": 0.0},
					{"model": "rock_d", "density": 0.0012, "slope_max": 1.0, "s": [0.0, 1.0], "scale": [0.6, 1.6], "tint": "rock", "collide": true, "veg": 0.0},
				],
				"fauna": ["crawler"], "resources": ["sodium", "ferrite"],
				"tint": {"glow_a": Color(0.35, 1.0, 0.25), "glow_b": Color(0.7, 0.3, 1.0), "rock": Color(0.28, 0.30, 0.28), "foliage": Color(0.3, 0.6, 0.2)},
			}
		_:
			return def("dead")

## Resolve biome + seed + planet radius into a per-planet profile (variations applied).
static func make_profile(id: String, seed_i: int, radius: float) -> Dictionary:
	var d: Dictionary = def(id).duplicate(true)
	var r := U.rng(seed_i * 7 + 13)
	var t: Dictionary = d["terrain"]
	# terrain variation +-20 %
	for k in ["amp_cont", "amp_hill", "amp_mount", "detail_amp"]:
		if t.has(k):
			t[k] = float(t[k]) * r.randf_range(0.82, 1.22)
	for k in ["wl_cont", "wl_hill", "wl_mount"]:
		if t.has(k):
			t[k] = float(t[k]) * r.randf_range(0.85, 1.2)
	# convert to metres
	var m: Dictionary = {}
	m["amp_cont"] = float(t["amp_cont"]) * radius
	m["wl_cont"] = float(t["wl_cont"]) * radius
	m["cont_bias"] = float(t.get("cont_bias", 0.0))
	m["amp_hill"] = float(t["amp_hill"]) * radius
	m["wl_hill"] = float(t["wl_hill"]) * radius
	m["amp_mount"] = float(t["amp_mount"]) * radius
	m["wl_mount"] = float(t["wl_mount"]) * radius
	m["mount_cover"] = float(t["mount_cover"])
	m["ridge_pow"] = float(t["ridge_pow"])
	m["detail_amp"] = float(t["detail_amp"])
	m["detail_wl"] = float(t["detail_wl"])
	m["terrace"] = float(t.get("terrace", 0.0))
	m["terrace_step"] = float(t.get("terrace_step", 30.0))
	m["dune_amp"] = float(t.get("dune_amp", 0.0))
	m["dune_wl"] = float(t.get("dune_wl", 100.0))
	m["crater"] = float(t.get("crater", 0.0))
	m["crater_wl"] = float(t.get("crater_wl", 0.3)) * radius
	m["cones"] = int(t.get("cones", 0))
	m["cone_h"] = float(t.get("cone_h", 0.0)) * radius
	m["cone_w"] = float(t.get("cone_w", 0.0)) * radius
	m["has_sea"] = t.has("sea") and d["ocean"].get("on", false)
	m["sea"] = float(t.get("sea", 0.0)) * radius if t.has("sea") else -1e9
	m["has_lava"] = t.has("lava")
	m["lava"] = float(t.get("lava", -9.0)) * radius if t.has("lava") else -1e9
	m["has_lake"] = t.has("lake")
	m["lake"] = float(t.get("lake", -9.0)) * radius if t.has("lake") else -1e9
	m["H"] = m["amp_cont"] + m["amp_hill"] + m["amp_mount"]
	d["tm"] = m
	# gravity / day length
	var g: Array = d["gravity"]
	d["g"] = r.randf_range(float(g[0]), float(g[1]))
	var dl: Array = d["day"]
	d["day_len"] = r.randf_range(float(dl[0]), float(dl[1]))
	# subtle palette hue variation per planet
	var hue_shift: float = r.randf_range(-0.035, 0.035)
	var val_mul: float = r.randf_range(0.92, 1.1)
	var flora: Array = d["flora"]
	flora.append_array(_resource_entries(id))
	d["pal_a"] = _varied_palette(d["palette_a"], hue_shift, val_mul)
	d["pal_b"] = _varied_palette(d["palette_b"], hue_shift * 1.5, val_mul)
	return d

static func _resource_entries(id: String) -> Array:
	var dens_na: float = 0.00013
	var dens_fe: float = 0.00014
	var dens_c: float = 0.00011 if id in ["lush", "toxic", "desert", "frozen"] else 0.0
	var out: Array = [
		{"model": "resource_sodium", "density": dens_na, "slope_max": 0.7, "s": [-0.3, 1.3], "scale": [0.9, 1.3], "tint": "none", "collide": false, "veg": 0.0, "resource": "sodium", "label": "Sodium deposit"},
		{"model": "resource_ferrite", "density": dens_fe, "slope_max": 0.8, "s": [-0.3, 1.3], "scale": [0.9, 1.4], "tint": "none", "collide": false, "veg": 0.0, "resource": "ferrite", "label": "Ferrite ore"},
	]
	if dens_c > 0.0:
		out.append({"model": "resource_carbon", "density": dens_c, "slope_max": 0.5, "s": [0.0, 0.8], "scale": [0.9, 1.3], "tint": "none", "collide": false, "veg": 0.0, "resource": "carbon", "label": "Carbon plant"})
	return out

static func _varied_palette(p: Array, hue_shift: float, val_mul: float) -> Array:
	var out: Array = []
	for st in p:
		var c: Color = st[1]
		var hsv_h: float = fposmod(c.h + hue_shift, 1.0)
		var nc: Color = Color.from_hsv(hsv_h, c.s, clampf(c.v * val_mul, 0.0, 1.0))
		out.append([float(st[0]), nc.srgb_to_linear()])
	return out
