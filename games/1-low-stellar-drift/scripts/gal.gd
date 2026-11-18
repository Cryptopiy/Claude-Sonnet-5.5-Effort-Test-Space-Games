class_name Gal
extends RefCounted
## Galaxy data: seeds, star classes, biomes and system generation.

const STAR_TYPES = [
	{"c": "O", "col": Color(0.55, 0.7, 1.0), "size": 1.3, "energy": 1.4},
	{"c": "B", "col": Color(0.65, 0.8, 1.0), "size": 1.2, "energy": 1.3},
	{"c": "A", "col": Color(0.9, 0.93, 1.0), "size": 1.1, "energy": 1.2},
	{"c": "F", "col": Color(1.0, 0.97, 0.85), "size": 1.0, "energy": 1.15},
	{"c": "G", "col": Color(1.0, 0.85, 0.5), "size": 1.0, "energy": 1.1},
	{"c": "K", "col": Color(1.0, 0.6, 0.3), "size": 0.9, "energy": 1.0},
	{"c": "M", "col": Color(1.0, 0.35, 0.2), "size": 0.8, "energy": 0.95},
]

# shape: 0 hills, 1 dunes, 2 spikes, 3 terraces, 4 craters, 5 rough
const BIOMES = {
	"lush": {"name": "Lush", "shape": 0, "amp": 34.0, "low": Color(0.17, 0.5, 0.14), "mid": Color(0.28, 0.62, 0.2), "high": Color(0.5, 0.45, 0.35), "slope": Color(0.4, 0.36, 0.3), "shore": Color(0.76, 0.7, 0.48),
		"sea": -6.0, "sea_col": Color(0.1, 0.35, 0.6, 0.78), "sea_emit": false, "horizon": Color(0.65, 0.8, 0.95), "zenith": Color(0.12, 0.38, 0.85), "fog": 0.0007, "grav": 10.0, "atmo": true, "clouds": 0.38, "cloud_col": Color(1, 1, 1),
		"hazard": "", "haz_rate": 0.0, "weather": "rain", "props": [["tree", 1500, 1.3, 2.4], ["rock", 260, 0.8, 2.2], ["mushroom", 80, 0.8, 1.6]], "fauna": 22},
	"desert": {"name": "Scorched Desert", "shape": 1, "amp": 30.0, "low": Color(0.82, 0.52, 0.25), "mid": Color(0.9, 0.65, 0.33), "high": Color(0.95, 0.78, 0.5), "slope": Color(0.6, 0.35, 0.2), "shore": Color(0.82, 0.52, 0.25),
		"sea": -999.0, "sea_col": Color(0, 0, 0, 0), "sea_emit": false, "horizon": Color(0.95, 0.7, 0.45), "zenith": Color(0.55, 0.35, 0.3), "fog": 0.0012, "grav": 8.0, "atmo": true, "clouds": 0.0, "cloud_col": Color(1, 0.9, 0.8),
		"hazard": "Extreme heat", "haz_rate": 2.5, "weather": "dust", "props": [["cactus", 1100, 1.0, 2.4], ["rock", 400, 0.8, 2.6], ["crystal", 40, 0.8, 1.6]], "fauna": 0},
	"frozen": {"name": "Frozen", "shape": 2, "amp": 45.0, "low": Color(0.8, 0.9, 0.98), "mid": Color(0.92, 0.96, 1.0), "high": Color(1.0, 1.0, 1.0), "slope": Color(0.45, 0.55, 0.7), "shore": Color(0.8, 0.9, 0.98),
		"sea": -999.0, "sea_col": Color(0, 0, 0, 0), "sea_emit": false, "horizon": Color(0.75, 0.88, 1.0), "zenith": Color(0.3, 0.45, 0.7), "fog": 0.0016, "grav": 9.0, "atmo": true, "clouds": 0.35, "cloud_col": Color(0.9, 0.95, 1),
		"hazard": "Extreme cold", "haz_rate": 2.0, "weather": "snow", "props": [["crystal", 600, 1.0, 3.5], ["rock", 350, 0.8, 2.4]], "fauna": 0},
	"lava": {"name": "Volcanic", "shape": 3, "amp": 40.0, "low": Color(0.12, 0.09, 0.09), "mid": Color(0.2, 0.15, 0.14), "high": Color(0.35, 0.25, 0.22), "slope": Color(0.08, 0.06, 0.06), "shore": Color(0.25, 0.1, 0.05),
		"sea": -4.0, "sea_col": Color(1.0, 0.35, 0.05, 1.0), "sea_emit": true, "horizon": Color(0.8, 0.25, 0.1), "zenith": Color(0.25, 0.05, 0.05), "fog": 0.0014, "grav": 12.0, "atmo": true, "clouds": 0.55, "cloud_col": Color(0.25, 0.18, 0.16),
		"hazard": "Scorching temperatures", "haz_rate": 3.2, "weather": "ash", "props": [["rock", 800, 1.0, 3.0], ["crystal", 120, 0.8, 2.2]], "fauna": 0},
	"toxic": {"name": "Toxic", "shape": 5, "amp": 26.0, "low": Color(0.35, 0.2, 0.45), "mid": Color(0.48, 0.55, 0.2), "high": Color(0.7, 0.7, 0.3), "slope": Color(0.3, 0.2, 0.3), "shore": Color(0.5, 0.55, 0.15),
		"sea": -8.0, "sea_col": Color(0.4, 0.9, 0.1, 0.85), "sea_emit": true, "horizon": Color(0.6, 0.85, 0.3), "zenith": Color(0.3, 0.15, 0.4), "fog": 0.0022, "grav": 7.0, "atmo": true, "clouds": 0.5, "cloud_col": Color(0.6, 0.9, 0.4),
		"hazard": "Toxic atmosphere", "haz_rate": 2.2, "weather": "spores", "props": [["mushroom", 1300, 1.0, 3.0], ["crystal", 100, 0.8, 2.0], ["rock", 200, 0.8, 1.8]], "fauna": 30},
	"moon": {"name": "Barren Moon", "shape": 4, "amp": 22.0, "low": Color(0.38, 0.38, 0.4), "mid": Color(0.5, 0.5, 0.52), "high": Color(0.65, 0.64, 0.62), "slope": Color(0.25, 0.25, 0.27), "shore": Color(0.4, 0.4, 0.4),
		"sea": -999.0, "sea_col": Color(0, 0, 0, 0), "sea_emit": false, "horizon": Color(0.0, 0.0, 0.0), "zenith": Color(0.0, 0.0, 0.0), "fog": 0.0, "grav": 3.0, "atmo": false, "clouds": 0.0, "cloud_col": Color(1, 1, 1),
		"hazard": "Vacuum / radiation", "haz_rate": 1.5, "weather": "", "props": [["rock", 700, 0.8, 3.0], ["crystal", 90, 1.0, 2.5]], "fauna": 0},
	"gas": {"name": "Gas Giant", "shape": 0, "amp": 0.0, "atmo": false, "grav": 0.0, "hazard": "", "haz_rate": 0.0, "props": []},
}
const LANDABLE = ["lush", "desert", "frozen", "lava", "toxic", "moon"]
const SYL = ["ka", "ra", "lo", "mi", "ta", "ven", "xi", "or", "ul", "ae", "zu", "ne", "sar", "dol", "pho", "ith", "qua", "ber", "el", "gan", "yu", "tor", "ix"]
const ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII"]

static func make_name(sd: int) -> String:
	var r = RandomNumberGenerator.new()
	r.seed = sd
	var n = ""
	for i in range(2 + r.randi() % 2):
		n += SYL[r.randi() % SYL.size()]
	return n.capitalize()

# galaxy: 90 stars on a spiral. star 0 = home, DEST_STAR = black hole destination
const NUM_STARS = 90
const HOME_STAR = 0
const DEST_STAR = 37
static var _stars = []

static func stars() -> Array:
	if _stars.size() > 0:
		return _stars
	var r = RandomNumberGenerator.new()
	r.seed = 424242
	for i in range(NUM_STARS):
		var arm = i % 3
		var t = r.randf_range(0.08, 1.0)
		var ang = arm * TAU / 3.0 + t * 4.2 + r.randfn(0.0, 0.18)
		var rad = t * 12000.0 + r.randfn(0.0, 300.0)   # light years
		var p = Vector3(cos(ang) * rad, r.randfn(0.0, 300.0), sin(ang) * rad)
		if i == HOME_STAR:
			p = Vector3(cos(2.0) * 7200.0, 20.0, sin(2.0) * 7200.0)
		if i == DEST_STAR:
			p = Vector3(cos(0.9) * 2600.0, -40.0, sin(0.9) * 2600.0)
		var tp = r.randi() % STAR_TYPES.size()
		if i == HOME_STAR: tp = 4
		if i == DEST_STAR: tp = 1
		_stars.append({"id": i, "pos": p, "type": tp, "name": make_name(1000 + i * 17)})
	_stars[HOME_STAR]["name"] = "Aurelia"
	_stars[DEST_STAR]["name"] = "Cygnaris Prime"
	return _stars

static func make_system(id: int) -> Dictionary:
	var st = stars()[id]
	var r = RandomNumberGenerator.new()
	r.seed = 7000 + id * 131
	var stype = STAR_TYPES[st["type"]]
	var bodies = []
	var biomes = []
	if id == HOME_STAR:
		biomes = ["lush", "desert", "frozen", "gas", "lava", "toxic", "moon"]
	elif id == DEST_STAR:
		biomes = ["toxic", "lava", "frozen", "gas", "desert", "lush", "moon"]
	else:
		var n = 5 + r.randi() % 3
		for i in range(n):
			biomes.append(["lush", "desert", "frozen", "lava", "toxic", "moon", "gas"][r.randi() % 7])
		if not biomes.has("gas"): biomes[2] = "gas"
	var orbit = 10000.0 + r.randf() * 2000.0
	var gas_idx = -1
	for i in range(biomes.size()):
		var b = biomes[i]
		var d = {"biome": b, "seed": 100 + id * 977 + i * 31, "name": "%s %s" % [st["name"], ROMAN[i]]}
		d["name"] = make_name(id * 53 + i * 7 + 3) + " " + ROMAN[i] if id != HOME_STAR else ["Eden", "Dunmar", "Glacia", "Jovan", "Ignis", "Miasma", "Selene"][i]
		d["radius"] = r.randf_range(480.0, 760.0)
		if b == "gas": d["radius"] = r.randf_range(1300.0, 1700.0); gas_idx = i
		if b == "moon": d["radius"] = r.randf_range(380.0, 480.0)
		d["parent"] = -1
		d["orbit_r"] = orbit
		d["phase"] = r.randf() * TAU
		d["period"] = 500.0 + orbit * 0.02
		d["incl"] = r.randf_range(-0.05, 0.05)
		orbit += r.randf_range(4000.0, 6500.0)
		if b == "gas": d["orbit_r"] = orbit + 800.0
		bodies.append(d)
	# the moon orbits the gas giant (a moon of a gas giant)
	var mi = biomes.find("moon")
	if mi >= 0 and gas_idx >= 0:
		bodies[mi]["parent"] = gas_idx
		bodies[mi]["orbit_r"] = 4200.0
		bodies[mi]["period"] = 160.0
	var bh_ang = r.randf() * TAU
	return {"id": id, "name": st["name"], "star": stype, "bodies": bodies, "bh_pos": Vector3(cos(bh_ang), 0.05, sin(bh_ang)) * 62000.0, "star_radius": 900.0 * stype["size"]}
