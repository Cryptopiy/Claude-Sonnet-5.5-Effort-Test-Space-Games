class_name WeatherProfiles
extends RefCounted
## Per-biome weather tables for WeatherFX (module m7b_life).  Keyed by BiomeDB ids + "space".
## A profile = { wind:[calm, storm] m/s, fog:{color, density, base, chan, scale}, layers:[layer cfg ...] }.
## A layer cfg describes one MultiMesh of streak/dot quads (see shaders/weather_particles.gdshader):
## fog.boost = how much the haze strength (0..1) multiplies the Mie density of M2's atmosphere (WeatherFX.fog_boost = 1 + boost * amount).
##   id, chan (weather channel driving its visibility), scale (chan multiplier), count, box (lattice period), fall (m/s down; negative = rises), wind (0..1+ share of the
##   wind it follows), flutter (m), ff (flutter frequency), size (m), streak (s of motion drawn as streak), max_len (m), a/b (two colours mixed per particle),
##   glow (>0 = self lit HDR, additive), soft (edge falloff), twinkle (0..1), lit (affected by day/night).

const NONE := {"wind": [0.0, 0.0], "fog": {}, "layers": []}

const RAIN_COLOR_A := Color(0.80, 0.88, 1.0, 0.55)
const RAIN_COLOR_B := Color(0.95, 0.97, 1.0, 0.35)

static func get_profile(id: String) -> Dictionary:
	return PROFILES.get(id, NONE)

const PROFILES := {
	"lush": {
		"wind": [1.5, 7.0],
		"fog": {"color": Color(0.64, 0.70, 0.78), "density": 0.006, "base": 0.0, "chan": "rain", "scale": 0.55, "boost": 0.7},
		"layers": [
			{"id": "rain_near", "chan": "rain", "count": 6200, "box": Vector3(34, 24, 34), "fall": 16.0, "wind": 0.5, "size": 0.016, "streak": 0.03, "max_len": 1.5,
				"a": Color(0.80, 0.88, 1.0, 0.68), "b": Color(0.95, 0.97, 1.0, 0.45), "soft": 0.7},
			{"id": "rain_far", "chan": "rain", "count": 8000, "box": Vector3(150, 80, 150), "fall": 16.0, "wind": 0.5, "size": 0.09, "streak": 0.03, "max_len": 3.5,
				"a": Color(0.80, 0.88, 1.0, 0.34), "b": Color(0.95, 0.97, 1.0, 0.22), "soft": 0.8},
		],
	},
	"ocean": {
		"wind": [3.0, 12.0],
		"fog": {"color": Color(0.66, 0.74, 0.82), "density": 0.008, "base": 0.0, "chan": "rain", "scale": 0.7, "boost": 0.7},
		"layers": [
			{"id": "rain_near", "chan": "rain", "count": 5200, "box": Vector3(34, 24, 34), "fall": 19.0, "wind": 0.9, "size": 0.012, "streak": 0.032, "max_len": 1.8,
				"a": Color(0.82, 0.92, 1.0, 0.6), "b": Color(0.95, 0.98, 1.0, 0.4), "soft": 0.7},
			{"id": "rain_far", "chan": "rain", "count": 3800, "box": Vector3(150, 80, 150), "fall": 19.0, "wind": 0.9, "size": 0.055, "streak": 0.03, "max_len": 3.5,
				"a": Color(0.82, 0.92, 1.0, 0.26), "b": Color(0.95, 0.98, 1.0, 0.18), "soft": 0.8},
		],
	},
	"swamp": {
		"wind": [0.5, 3.0],
		"fog": {"color": Color(0.42, 0.50, 0.28), "density": 0.010, "base": 0.38, "chan": "rain", "scale": 0.4, "boost": 1.0},
		"layers": [
			{"id": "drizzle", "chan": "rain", "count": 2400, "box": Vector3(34, 24, 34), "fall": 11.0, "wind": 0.3, "size": 0.010, "streak": 0.03, "max_len": 1.0,
				"a": Color(0.72, 0.80, 0.70, 0.45), "b": Color(0.85, 0.9, 0.8, 0.3), "soft": 0.7, "scale": 0.7},
			{"id": "fireflies", "chan": "ambient", "count": 700, "box": Vector3(46, 14, 46), "fall": -0.05, "wind": 0.2, "flutter": 1.6, "ff": 0.7, "size": 0.07, "streak": 0.0,
				"max_len": 0.2, "a": Color(0.85, 1.0, 0.25, 1.0), "b": Color(0.55, 1.0, 0.45, 1.0), "glow": 3.0, "soft": 1.3, "twinkle": 0.7},
		],
	},
	"desert": {
		"wind": [2.5, 26.0],
		"fog": {"color": Color(0.88, 0.68, 0.42), "density": 0.0165, "base": 0.05, "chan": "dust", "scale": 0.95, "boost": 3.0},
		"layers": [
			{"id": "dust_near", "chan": "dust", "count": 6500, "box": Vector3(50, 22, 50), "fall": 0.4, "wind": 1.0, "flutter": 0.8, "ff": 1.4, "size": 0.035, "streak": 0.05, "max_len": 4.5,
				"a": Color(1.0, 0.90, 0.68, 0.62), "b": Color(0.58, 0.38, 0.20, 0.55), "soft": 0.6},
			{"id": "dust_far", "chan": "dust", "count": 4200, "box": Vector3(170, 60, 170), "fall": 0.2, "wind": 1.0, "flutter": 1.0, "ff": 0.6, "size": 0.30, "streak": 0.035, "max_len": 9.0,
				"a": Color(1.0, 0.86, 0.62, 0.20), "b": Color(0.62, 0.42, 0.22, 0.17), "soft": 1.2},
			{"id": "dust_specks", "chan": "ambient", "count": 900, "box": Vector3(32, 12, 32), "fall": 0.05, "wind": 1.0, "flutter": 0.6, "ff": 1.0, "size": 0.020, "streak": 0.04, "max_len": 0.8,
				"a": Color(0.95, 0.80, 0.55, 0.55), "b": Color(0.85, 0.70, 0.45, 0.45), "soft": 0.8, "scale": 0.5},
		],
	},
	"frozen": {
		"wind": [2.0, 24.0],
		"fog": {"color": Color(0.80, 0.88, 0.96), "density": 0.016, "base": 0.08, "chan": "blizzard", "scale": 0.9, "boost": 2.4},
		"layers": [
			{"id": "snow_near", "chan": "snow", "count": 4500, "box": Vector3(32, 22, 32), "fall": 1.7, "wind": 0.8, "flutter": 0.55, "ff": 1.1, "size": 0.034, "streak": 0.02, "max_len": 0.9,
				"a": Color(1, 1, 1, 0.95), "b": Color(0.82, 0.92, 1.0, 0.8), "soft": 0.5},
			{"id": "snow_far", "chan": "snow", "count": 3500, "box": Vector3(130, 60, 130), "fall": 1.7, "wind": 0.8, "flutter": 0.8, "ff": 0.7, "size": 0.13, "streak": 0.02, "max_len": 2.0,
				"a": Color(1, 1, 1, 0.42), "b": Color(0.82, 0.92, 1.0, 0.34), "soft": 0.7},
			{"id": "blizzard", "chan": "blizzard", "count": 3400, "box": Vector3(60, 26, 60), "fall": 0.8, "wind": 1.3, "flutter": 0.4, "ff": 2.0, "size": 0.03, "streak": 0.06, "max_len": 6.0,
				"a": Color(0.95, 0.98, 1.0, 0.55), "b": Color(0.8, 0.9, 1.0, 0.45), "soft": 0.6},
		],
	},
	"volcanic": {
		"wind": [2.5, 9.0],
		"fog": {"color": Color(0.20, 0.12, 0.09), "density": 0.0045, "base": 0.22, "chan": "ash", "scale": 0.7, "boost": 1.4},
		"layers": [
			{"id": "ash_near", "chan": "ash", "count": 4500, "box": Vector3(40, 26, 40), "fall": 1.2, "wind": 0.7, "flutter": 0.7, "ff": 1.0, "size": 0.045, "streak": 0.025, "max_len": 1.2,
				"a": Color(0.26, 0.23, 0.21, 0.95), "b": Color(0.46, 0.38, 0.32, 0.85), "soft": 0.5},
			{"id": "ash_far", "chan": "ash", "count": 3200, "box": Vector3(140, 70, 140), "fall": 1.2, "wind": 0.7, "flutter": 1.0, "ff": 0.6, "size": 0.17, "streak": 0.02, "max_len": 2.5,
				"a": Color(0.18, 0.15, 0.13, 0.42), "b": Color(0.34, 0.28, 0.24, 0.36), "soft": 0.8},
			{"id": "embers", "chan": "embers", "count": 1500, "box": Vector3(46, 26, 46), "fall": -0.6, "wind": 1.0, "flutter": 1.2, "ff": 2.0, "size": 0.05, "streak": 0.05, "max_len": 1.0,
				"a": Color(1.0, 0.42, 0.08, 1.0), "b": Color(1.0, 0.75, 0.25, 1.0), "glow": 3.0, "soft": 0.9, "twinkle": 0.5},
		],
	},
	"toxic": {
		"wind": [1.0, 5.0],
		"fog": {"color": Color(0.44, 0.62, 0.12), "density": 0.0125, "base": 0.22, "chan": "mist", "scale": 0.6, "boost": 1.8},
		"layers": [
			{"id": "spores_near", "chan": "spores", "count": 1900, "box": Vector3(50, 20, 50), "fall": -0.18, "wind": 0.6, "flutter": 1.6, "ff": 0.6, "size": 0.10, "streak": 0.0, "max_len": 0.3,
				"a": Color(0.55, 1.0, 0.25, 0.95), "b": Color(0.90, 1.0, 0.30, 0.85), "glow": 1.7, "soft": 1.2, "twinkle": 0.7},
			{"id": "spores_far", "chan": "spores", "count": 1700, "box": Vector3(140, 50, 140), "fall": -0.12, "wind": 0.6, "flutter": 2.5, "ff": 0.4, "size": 0.45, "streak": 0.0, "max_len": 0.8,
				"a": Color(0.55, 1.0, 0.25, 0.30), "b": Color(0.90, 1.0, 0.30, 0.25), "glow": 2.0, "soft": 1.6, "twinkle": 0.5},
		],
	},
	"exotic": {
		"wind": [0.8, 3.5],
		"fog": {"color": Color(0.60, 0.42, 0.82), "density": 0.0035, "base": 0.14, "chan": "motes", "scale": 0.25, "boost": 0.3},
		"layers": [
			{"id": "motes_a", "chan": "motes", "count": 1700, "box": Vector3(50, 26, 50), "fall": -0.3, "wind": 0.5, "flutter": 2.0, "ff": 0.5, "size": 0.09, "streak": 0.0, "max_len": 0.3,
				"a": Color(0.20, 0.92, 1.0, 0.95), "b": Color(1.0, 0.30, 0.90, 0.95), "glow": 1.6, "soft": 1.2, "twinkle": 0.6},
			{"id": "motes_b", "chan": "motes", "count": 900, "box": Vector3(90, 40, 90), "fall": -0.2, "wind": 0.5, "flutter": 3.0, "ff": 0.35, "size": 0.2, "streak": 0.0, "max_len": 0.5,
				"a": Color(1.0, 0.85, 0.30, 0.55), "b": Color(0.6, 0.5, 1.0, 0.5), "glow": 1.5, "soft": 1.5, "twinkle": 0.5},
		],
	},
	"radioactive": {
		"wind": [1.5, 6.0],
		"fog": {"color": Color(0.62, 0.65, 0.18), "density": 0.010, "base": 0.30, "chan": "ash", "scale": 0.5, "boost": 1.0},
		"layers": [
			{"id": "ash_near", "chan": "ash", "count": 3200, "box": Vector3(40, 26, 40), "fall": 1.0, "wind": 0.7, "flutter": 0.7, "ff": 1.0, "size": 0.04, "streak": 0.025, "max_len": 1.0,
				"a": Color(0.42, 0.42, 0.16, 0.9), "b": Color(0.60, 0.58, 0.22, 0.8), "soft": 0.5},
			{"id": "isotopes", "chan": "motes", "count": 1300, "box": Vector3(50, 22, 50), "fall": -0.2, "wind": 0.5, "flutter": 1.6, "ff": 0.6, "size": 0.09, "streak": 0.0, "max_len": 0.3,
				"a": Color(0.85, 1.0, 0.10, 1.0), "b": Color(0.55, 1.0, 0.25, 1.0), "glow": 3.0, "soft": 1.2, "twinkle": 0.7},
		],
	},
	"space": {
		"wind": [0.0, 0.0],
		"fog": {},
		"layers": [
			{"id": "space_dust", "chan": "space", "count": 1400, "box": Vector3(160, 160, 160), "fall": 0.0, "wind": 0.0, "size": 0.07, "streak": 0.02, "max_len": 14.0,
				"a": Color(0.85, 0.9, 1.0, 0.55), "b": Color(1.0, 0.92, 0.8, 0.45), "glow": 1.0, "soft": 0.9, "near_a": 2.0, "near_b": 8.0},
		],
	},
}
