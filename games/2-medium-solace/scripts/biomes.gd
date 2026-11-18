class_name Biomes
extends RefCounted
## Static biome definitions. Terrain wavelengths/amplitudes are in metres.

const M := "res://assets/models/"

static func get_def(id: String) -> Dictionary:
	match id:
		"lush":
			return {
				"id": "lush", "label": "Lush", "gravity": 9.0, "hazard": "none", "hazard_rate": 0.0,
				"resource": "Carbon", "res_color": Color(0.4, 1.0, 0.4),
				"terrain": {"base_wl": 650.0, "base_a": 38.0, "ridge_wl": 420.0, "ridge_a": 95.0, "mask_wl": 1400.0,
					"lift": 14.0, "sea": 0.0, "detail_a": 1.2},
				"colors": {"low": Color(0.80, 0.74, 0.46), "mid": Color(0.20, 0.50, 0.12), "high": Color(0.44, 0.40, 0.36),
					"rock": Color(0.40, 0.37, 0.33), "alt": Color(0.40, 0.58, 0.14)},
				"sky_zenith": Color(0.14, 0.38, 0.82), "sky_horizon": Color(0.62, 0.78, 0.95),
				"atmo": Color(0.35, 0.62, 1.0), "density": 1.0, "fog": 0.00022, "ambient": 0.55,
				"water": Color(0.05, 0.28, 0.45),
				"flora": [
					{"model": "tree_lush", "dens": 3.0, "smin": 0.8, "smax": 1.7, "dist": 220.0, "min_h": 2.0, "slope": 0.35},
					{"model": "grass", "dens": 90.0, "smin": 0.8, "smax": 1.5, "dist": 60.0, "min_h": 1.5, "slope": 0.3},
					{"model": "rock_a", "dens": 1.2, "smin": 0.6, "smax": 2.2, "dist": 200.0, "min_h": 0.5, "slope": 1.0},
				],
				"weather": "rain",
			}
		"desert":
			return {
				"id": "desert", "label": "Scorched Desert", "gravity": 11.0, "hazard": "heat", "hazard_rate": 1.6,
				"resource": "Sodium", "res_color": Color(1.0, 0.9, 0.3),
				"terrain": {"base_wl": 520.0, "base_a": 30.0, "ridge_wl": 700.0, "ridge_a": 70.0, "mask_wl": 1800.0,
					"lift": 40.0, "terrace": 26.0, "detail_a": 0.9},
				"colors": {"low": Color(0.86, 0.62, 0.32), "mid": Color(0.80, 0.50, 0.24), "high": Color(0.62, 0.30, 0.18),
					"rock": Color(0.52, 0.30, 0.20), "alt": Color(0.92, 0.72, 0.42)},
				"sky_zenith": Color(0.42, 0.34, 0.50), "sky_horizon": Color(0.98, 0.70, 0.42),
				"atmo": Color(1.0, 0.6, 0.3), "density": 0.8, "fog": 0.00055, "ambient": 0.6,
				"flora": [
					{"model": "cactus", "dens": 1.4, "smin": 0.8, "smax": 1.8, "dist": 200.0, "min_h": -999.0, "slope": 0.3},
					{"model": "rock_b", "dens": 1.2, "smin": 0.7, "smax": 2.4, "dist": 220.0, "min_h": -999.0, "slope": 1.0},
					{"model": "dead_tree", "dens": 0.35, "smin": 0.8, "smax": 1.4, "dist": 200.0, "min_h": -999.0, "slope": 0.3},
					{"model": "rock_a", "dens": 1.5, "smin": 0.4, "smax": 1.6, "dist": 140.0, "min_h": -999.0, "slope": 1.0},
				],
				"weather": "dust",
			}
		"frozen":
			return {
				"id": "frozen", "label": "Frozen", "gravity": 7.5, "hazard": "cold", "hazard_rate": 1.4,
				"resource": "Dihydrogen", "res_color": Color(0.5, 0.9, 1.0),
				"terrain": {"base_wl": 900.0, "base_a": 26.0, "ridge_wl": 380.0, "ridge_a": 130.0, "mask_wl": 1200.0,
					"lift": 20.0, "detail_a": 0.6},
				"colors": {"low": Color(0.82, 0.90, 0.97), "mid": Color(0.90, 0.95, 1.0), "high": Color(0.97, 0.99, 1.0),
					"rock": Color(0.38, 0.45, 0.55), "alt": Color(0.70, 0.84, 0.95)},
				"sky_zenith": Color(0.25, 0.45, 0.72), "sky_horizon": Color(0.80, 0.90, 1.0),
				"atmo": Color(0.65, 0.85, 1.0), "density": 0.9, "fog": 0.0008, "ambient": 0.7,
				"flora": [
					{"model": "ice_spike", "dens": 1.8, "smin": 0.7, "smax": 2.0, "dist": 220.0, "min_h": -999.0, "slope": 0.5},
					{"model": "rock_a", "dens": 0.8, "smin": 0.6, "smax": 2.0, "dist": 200.0, "min_h": -999.0, "slope": 1.0},
					{"model": "crystal_blue", "dens": 0.25, "smin": 0.8, "smax": 1.6, "dist": 200.0, "min_h": -999.0, "slope": 0.6},
				],
				"weather": "snow",
			}
		"volcanic":
			return {
				"id": "volcanic", "label": "Volcanic", "gravity": 10.5, "hazard": "heat", "hazard_rate": 2.4,
				"resource": "Ferrite", "res_color": Color(1.0, 0.45, 0.2),
				"terrain": {"base_wl": 450.0, "base_a": 42.0, "ridge_wl": 300.0, "ridge_a": 150.0, "mask_wl": 900.0,
					"lift": 8.0, "lava": -26.0, "detail_a": 1.8},
				"colors": {"low": Color(0.07, 0.05, 0.05), "mid": Color(0.14, 0.10, 0.09), "high": Color(0.26, 0.20, 0.18),
					"rock": Color(0.10, 0.08, 0.08), "alt": Color(0.30, 0.12, 0.08)},
				"sky_zenith": Color(0.10, 0.04, 0.04), "sky_horizon": Color(0.75, 0.22, 0.06),
				"atmo": Color(1.0, 0.35, 0.1), "density": 1.0, "fog": 0.0011, "ambient": 0.5,
				"flora": [
					{"model": "lava_spire", "dens": 1.4, "smin": 0.7, "smax": 2.0, "dist": 230.0, "min_h": -20.0, "slope": 1.0},
					{"model": "rock_b", "dens": 1.0, "smin": 0.6, "smax": 2.0, "dist": 200.0, "min_h": -20.0, "slope": 1.0},
					{"model": "crystal_red", "dens": 0.3, "smin": 0.8, "smax": 1.8, "dist": 200.0, "min_h": -20.0, "slope": 1.0},
				],
				"weather": "ash",
			}
		"toxic":
			return {
				"id": "toxic", "label": "Toxic Swamp", "gravity": 8.5, "hazard": "toxic", "hazard_rate": 1.8,
				"resource": "Radon", "res_color": Color(0.7, 1.0, 0.2),
				"terrain": {"base_wl": 380.0, "base_a": 14.0, "ridge_wl": 500.0, "ridge_a": 40.0, "mask_wl": 1000.0,
					"lift": 5.0, "sea": 0.0, "detail_a": 0.8},
				"colors": {"low": Color(0.30, 0.34, 0.12), "mid": Color(0.42, 0.50, 0.14), "high": Color(0.50, 0.45, 0.22),
					"rock": Color(0.30, 0.28, 0.18), "alt": Color(0.55, 0.62, 0.20)},
				"sky_zenith": Color(0.26, 0.36, 0.08), "sky_horizon": Color(0.68, 0.78, 0.24),
				"atmo": Color(0.75, 0.9, 0.2), "density": 1.0, "fog": 0.0012, "ambient": 0.55,
				"water": Color(0.25, 0.45, 0.06),
				"flora": [
					{"model": "mushroom", "dens": 3.0, "smin": 0.8, "smax": 2.4, "dist": 220.0, "min_h": 1.0, "slope": 0.4},
					{"model": "tree_alien", "dens": 1.2, "smin": 0.9, "smax": 1.8, "dist": 220.0, "min_h": 1.0, "slope": 0.4},
					{"model": "dead_tree", "dens": 0.6, "smin": 0.8, "smax": 1.5, "dist": 200.0, "min_h": 1.0, "slope": 0.4},
				],
				"weather": "spores",
			}
		"barren":
			return {
				"id": "barren", "label": "Barren / Airless", "gravity": 3.2, "hazard": "radiation", "hazard_rate": 1.0,
				"resource": "Silicate", "res_color": Color(0.8, 0.8, 1.0),
				"terrain": {"base_wl": 800.0, "base_a": 14.0, "crater_a": 40.0, "crater_wl": 520.0, "lift": 0.0, "detail_a": 0.8},
				"colors": {"low": Color(0.30, 0.30, 0.32), "mid": Color(0.45, 0.44, 0.43), "high": Color(0.58, 0.57, 0.55),
					"rock": Color(0.33, 0.32, 0.32), "alt": Color(0.50, 0.46, 0.42)},
				"sky_zenith": Color(0.0, 0.0, 0.0), "sky_horizon": Color(0.0, 0.0, 0.0),
				"atmo": Color(0.5, 0.5, 0.6), "density": 0.0, "fog": 0.0, "ambient": 0.18,
				"flora": [
					{"model": "rock_a", "dens": 3.0, "smin": 0.5, "smax": 2.6, "dist": 220.0, "min_h": -999.0, "slope": 1.0},
					{"model": "rock_b", "dens": 0.7, "smin": 0.6, "smax": 2.0, "dist": 220.0, "min_h": -999.0, "slope": 1.0},
					{"model": "crystal_blue", "dens": 0.12, "smin": 0.8, "smax": 1.4, "dist": 200.0, "min_h": -999.0, "slope": 1.0},
				],
				"weather": "none",
			}
		"exotic":
			return {
				"id": "exotic", "label": "Exotic", "gravity": 6.5, "hazard": "radiation", "hazard_rate": 1.2,
				"resource": "Aether", "res_color": Color(1.0, 0.4, 1.0),
				"terrain": {"base_wl": 300.0, "base_a": 36.0, "ridge_wl": 220.0, "ridge_a": 90.0, "mask_wl": 700.0,
					"lift": 12.0, "detail_a": 1.2},
				"colors": {"low": Color(0.12, 0.08, 0.30), "mid": Color(0.45, 0.14, 0.62), "high": Color(0.15, 0.75, 0.80),
					"rock": Color(0.20, 0.10, 0.34), "alt": Color(0.85, 0.30, 0.65)},
				"sky_zenith": Color(0.30, 0.08, 0.50), "sky_horizon": Color(0.95, 0.42, 0.82),
				"atmo": Color(0.9, 0.4, 1.0), "density": 0.9, "fog": 0.0007, "ambient": 0.7,
				"flora": [
					{"model": "tree_alien", "dens": 2.4, "smin": 0.9, "smax": 2.2, "dist": 230.0, "min_h": -999.0, "slope": 0.5},
					{"model": "crystal_blue", "dens": 0.8, "smin": 1.0, "smax": 2.6, "dist": 220.0, "min_h": -999.0, "slope": 1.0},
					{"model": "mushroom", "dens": 1.2, "smin": 0.8, "smax": 1.8, "dist": 200.0, "min_h": -999.0, "slope": 0.5},
					{"model": "crystal_red", "dens": 0.35, "smin": 0.8, "smax": 1.8, "dist": 200.0, "min_h": -999.0, "slope": 1.0},
				],
				"weather": "spores",
			}
	return get_def("barren")

const LANDABLE := ["lush", "desert", "frozen", "volcanic", "toxic", "barren", "exotic"]
