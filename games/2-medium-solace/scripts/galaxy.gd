class_name Galaxy
extends RefCounted
## Procedural galaxy (spiral of stars) and seeded star-system generation.

const STAR_COUNT := 900
const GALAXY_RADIUS := 50000.0 # light years
const HOME := 0

const CLASSES := [
	{"id": "M", "color": Color(1.0, 0.45, 0.25), "radius": 4200.0, "lum": 0.45, "w": 40},
	{"id": "K", "color": Color(1.0, 0.68, 0.38), "radius": 5200.0, "lum": 0.75, "w": 25},
	{"id": "G", "color": Color(1.0, 0.93, 0.70), "radius": 6000.0, "lum": 1.0, "w": 15},
	{"id": "F", "color": Color(1.0, 0.98, 0.9), "radius": 6600.0, "lum": 1.3, "w": 10},
	{"id": "A", "color": Color(0.80, 0.88, 1.0), "radius": 7400.0, "lum": 1.7, "w": 6},
	{"id": "B", "color": Color(0.55, 0.70, 1.0), "radius": 8600.0, "lum": 2.2, "w": 4},
]

static var stars: Array = []   # {pos: Vector2, z: float, cls: int, name: String}
static var _sys_cache: Dictionary = {}

static func _syll(rng: RandomNumberGenerator) -> String:
	var a := ["ka", "to", "ri", "ve", "la", "su", "mo", "ne", "xi", "dar", "ol", "an", "ze", "hu", "pi", "qua", "ru", "sen", "ith", "or"]
	var n := 2 + rng.randi() % 2
	var s := ""
	for i in n:
		s += a[rng.randi() % a.size()]
	return s.capitalize()

static func init_galaxy() -> void:
	if stars.size() > 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in STAR_COUNT:
		var r := GALAXY_RADIUS * pow(rng.randf(), 0.7)
		var arm := rng.randi() % 2
		var ang := float(arm) * PI + r * 0.00011 + rng.randfn(0.0, 0.28 + 0.4 * (1.0 - r / GALAXY_RADIUS) * 0.3)
		if i == HOME:
			r = 26000.0
			ang = 0.9
		var pos := Vector2(cos(ang), sin(ang)) * r
		var w := rng.randf() * 100.0
		var acc := 0.0
		var cls := 0
		for k in CLASSES.size():
			acc += CLASSES[k]["w"]
			if w <= acc:
				cls = k
				break
		if i == HOME:
			cls = 2
		var nm := _syll(rng)
		if i == HOME:
			nm = "Solace"
		stars.append({"pos": pos, "z": rng.randfn(0.0, 600.0), "cls": cls, "name": nm})

## Black hole destination: star roughly 7000 ly closer to the galactic centre.
static func bh_target(idx: int) -> int:
	var p: Vector2 = stars[idx]["pos"]
	var want := maxf(p.length() - 7000.0, 1500.0)
	var best := -1
	var best_d := 1e12
	for j in stars.size():
		if j == idx:
			continue
		var q: Vector2 = stars[j]["pos"]
		var d := absf(q.length() - want) * 1.0 + q.distance_to(p.normalized() * want) * 0.6
		if d < best_d:
			best_d = d
			best = j
	return best

static func make_system(idx: int) -> Dictionary:
	if _sys_cache.has(idx):
		return _sys_cache[idx]
	init_galaxy()
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 7717 + 13
	var st: Dictionary = stars[idx]
	var cls: Dictionary = CLASSES[st["cls"]]
	var sys := {"index": idx, "name": st["name"], "star_class": cls["id"], "star_color": cls["color"],
		"star_radius": cls["radius"], "lum": cls["lum"], "bodies": []}
	var bodies: Array = []
	if idx == HOME:
		var specs := [
			["Cinder", "volcanic", 24000.0, 2000.0], ["Verdance", "lush", 36000.0, 2600.0], ["Dune", "desert", 52000.0, 2300.0],
			["Mycelia", "toxic", 70000.0, 2100.0], ["Aurora", "gas", 96000.0, 9000.0], ["Glacia", "frozen", 130000.0, 2500.0],
			["Vesper", "exotic", 168000.0, 2200.0]]
		for s in specs:
			bodies.append({"name": s[0], "biome": s[1], "orbit": s[2], "radius": s[3], "parent": -1})
		bodies.append({"name": "Lumen", "biome": "barren", "orbit": 11500.0, "radius": 1500.0, "parent": 1})
	else:
		var n := 5 + rng.randi() % 3
		var orbit := 22000.0 + rng.randf() * 8000.0
		var had_gas := false
		for k in n:
			var temp: float = cls["lum"] / pow(orbit / 60000.0, 2.0)
			var biome := ""
			if rng.randf() < 0.17 and not had_gas and k >= 2:
				biome = "gas"
				had_gas = true
			elif temp > 3.0:
				biome = ["volcanic", "desert", "barren", "volcanic"][rng.randi() % 4]
			elif temp > 1.0:
				biome = ["desert", "lush", "toxic", "exotic", "lush"][rng.randi() % 5]
			elif temp > 0.35:
				biome = ["lush", "toxic", "frozen", "exotic", "desert"][rng.randi() % 5]
			else:
				biome = ["frozen", "barren", "exotic", "frozen"][rng.randi() % 4]
			var rad := 9000.0 if biome == "gas" else rng.randf_range(1700.0, 3000.0)
			bodies.append({"name": _syll(rng) + " " + ["I", "II", "III", "IV", "V", "VI", "VII"][k], "biome": biome, "orbit": orbit, "radius": rad, "parent": -1})
			orbit *= rng.randf_range(1.3, 1.45)
		# make sure at least 4 landable bodies, add moons
		var landable := 0
		for b in bodies:
			if b["biome"] != "gas":
				landable += 1
		var guard := 0
		while landable < 4 and guard < 6:
			guard += 1
			var pi_ := rng.randi() % bodies.size()
			if bodies[pi_]["biome"] == "gas" and rng.randf() < 0.5:
				continue
			bodies.append({"name": bodies[pi_]["name"] + " " + ["a", "b", "c"][guard % 3], "biome": ["barren", "frozen"][rng.randi() % 2],
				"orbit": rng.randf_range(10000.0, 14000.0), "radius": rng.randf_range(1200.0, 1700.0), "parent": pi_})
			landable += 1
	for i in bodies.size():
		var b: Dictionary = bodies[i]
		b["seed"] = idx * 1009 + i * 97 + 5
		b["phase"] = rng.randf() * TAU
		var o: float = b["orbit"]
		var par: float = 1.0 if b["parent"] < 0 else 0.35
		b["period"] = (2600.0 + o * 0.085) * par + 200.0       # seconds; slow, plausible orbits
		b["spin"] = rng.randf_range(480.0, 900.0)              # day length in seconds
		b["tilt"] = rng.randf_range(-0.4, 0.4)
		b["incl"] = rng.randf_range(-0.05, 0.05)
		b["landable"] = b["biome"] != "gas"
		b["gas_seed"] = rng.randf()
	sys["bodies"] = bodies
	sys["bh_distance"] = 200000.0 + rng.randf() * 30000.0
	sys["bh_angle"] = rng.randf() * TAU
	sys["bh_target"] = bh_target(idx)
	_sys_cache[idx] = sys
	return sys
