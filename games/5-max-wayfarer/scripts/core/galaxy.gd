class_name Galaxy
extends RefCounted
## Procedural galaxy: ~2600 stars laid out as a two-armed spiral with a central bulge.
## Every star carries a seed from which its system is generated deterministically.

const GALAXY_SEED: int = 7741
const COUNT: int = 2600
const RADIUS_LY: float = 50000.0
const HOME_INDEX: int = 0
const BH_SHIFT_LY: float = 7000.0         # a black hole carries you ~7000 ly toward the galactic core

const CLASSES: Array = [
	# class, weight, color, temp, radius range, light
	["O", 0.02, Color(0.62, 0.72, 1.00), 32000.0, Vector2(4600, 6000), 1.55],
	["B", 0.05, Color(0.70, 0.80, 1.00), 16000.0, Vector2(3900, 5000), 1.40],
	["A", 0.10, Color(0.86, 0.92, 1.00), 9000.0, Vector2(3300, 4200), 1.25],
	["F", 0.18, Color(1.00, 0.97, 0.88), 7000.0, Vector2(2800, 3600), 1.10],
	["G", 0.25, Color(1.00, 0.92, 0.72), 5700.0, Vector2(2400, 3000), 1.00],
	["K", 0.25, Color(1.00, 0.74, 0.46), 4500.0, Vector2(2000, 2600), 0.85],
	["M", 0.15, Color(1.00, 0.50, 0.30), 3200.0, Vector2(1500, 2100), 0.66],
]

static var _inst: Galaxy = null

var stars: Array[Dictionary] = []
var bh_systems: Array[int] = []

static func get_galaxy() -> Galaxy:
	if _inst == null:
		_inst = Galaxy.new()
		_inst._generate()
	return _inst

func _pick_class(r: RandomNumberGenerator) -> Array:
	var x: float = r.randf()
	var acc: float = 0.0
	for c in CLASSES:
		acc += float(c[1])
		if x <= acc:
			return c
	return CLASSES[4]

func _generate() -> void:
	var r := U.rng(GALAXY_SEED)
	stars.clear()
	for i in COUNT:
		var sr := U.rng(GALAXY_SEED * 31 + i * 7919)
		var pos := Vector3.ZERO
		if i == HOME_INDEX:
			# home star: ~27 000 ly from the core on a spiral arm
			var th: float = 0.9
			pos = Vector3(cos(th) * 27000.0, 40.0, sin(th) * 27000.0)
		else:
			var kind: float = sr.randf()
			if kind < 0.22:
				# bulge
				var rr: float = -log(1.0 - sr.randf() * 0.98) * 4200.0
				var v: Vector3 = U.rand_unit(sr)
				pos = Vector3(v.x * rr, v.y * rr * 0.55, v.z * rr)
			else:
				# disc with two logarithmic spiral arms
				var rr2: float = 3000.0 + sqrt(sr.randf()) * (RADIUS_LY - 3000.0)
				var arm: float = float(sr.randi() % 2) * PI
				var th2: float = arm + 2.6 * log(rr2 / 3000.0) * 1.0 + sr.randfn(0.0, 0.34 + 0.15 * (rr2 / RADIUS_LY))
				var zt: float = sr.randfn(0.0, 450.0 * (1.0 - 0.6 * rr2 / RADIUS_LY))
				pos = Vector3(cos(th2) * rr2, zt, sin(th2) * rr2)
		var c: Array = _pick_class(sr)
		if i == HOME_INDEX:
			c = CLASSES[4]
		var sd: int = U.hash2(GALAXY_SEED, i)
		var info: Dictionary = {
			"id": i, "pos": pos, "cls": c[0], "color": c[2], "temp": c[3], "light": c[5],
			"radius": lerpf(float(c[4].x), float(c[4].y), sr.randf()),
			"seed": sd, "name": "Helios" if i == HOME_INDEX else U.gen_name(sd), "bh": false, "bh_dest": -1,
		}
		stars.append(info)
	# black holes: home system + ~40 others (not too close to the very centre)
	var cand: Array[int] = []
	for i in range(1, COUNT):
		var p: Vector3 = stars[i]["pos"]
		if p.length() > 9000.0:
			var h: float = U.hf2(GALAXY_SEED, i + 100000)
			if h < 0.016:
				cand.append(i)
	bh_systems.append(HOME_INDEX)
	stars[HOME_INDEX]["bh"] = true
	for i in cand:
		stars[i]["bh"] = true
		bh_systems.append(i)
	# destinations: the star closest to the point 7000 ly closer to the core
	for i in bh_systems:
		var p2: Vector3 = stars[i]["pos"]
		var target: Vector3 = p2 * (1.0 - BH_SHIFT_LY / maxf(p2.length(), 1.0))
		var best: int = -1
		var bd: float = 1e30
		for j in COUNT:
			if j == i or bool(stars[j]["bh"]):
				continue
			var d: float = (stars[j]["pos"] as Vector3).distance_squared_to(target)
			if d < bd:
				bd = d
				best = j
		stars[i]["bh_dest"] = best

func star(i: int) -> Dictionary:
	return stars[clampi(i, 0, stars.size() - 1)]

func distance_ly(a: int, b: int) -> float:
	return (stars[a]["pos"] as Vector3).distance_to(stars[b]["pos"])

func region_name(i: int) -> String:
	var p: Vector3 = stars[i]["pos"]
	var gx: int = int(floor(p.x / 4000.0))
	var gz: int = int(floor(p.z / 4000.0))
	return "%s Region" % U.gen_name(U.hash3(GALAXY_SEED, gx + 50, gz + 50), 2)

func nearest_to(p: Vector3, exclude: int = -1) -> int:
	var best: int = -1
	var bd: float = 1e30
	for j in COUNT:
		if j == exclude:
			continue
		var d: float = (stars[j]["pos"] as Vector3).distance_squared_to(p)
		if d < bd:
			bd = d
			best = j
	return best
