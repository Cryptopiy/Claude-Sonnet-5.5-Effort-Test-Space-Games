class_name Galaxy
extends RefCounted
## The procedural galaxy: a few hundred named stars on spiral arms. Systems are generated lazily from their seeds.

const N_STARS := 640
const RADIUS_LY := 50000.0
const GALAXY_SEED := 5150

var stars: Array = []  # {id, pos: Vector3 (ly), cls, name, seed, bh: bool, bh_dest}
var _cache: Dictionary = {}
var home_id: int = 0
var gate_id: int = 1  # destination of the home black hole ("Atlas Gate")
var core_pos: Vector3 = Vector3.ZERO


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GALAXY_SEED
	var arms := 4
	for i in N_STARS:
		var u := rng.randf()
		var r := RADIUS_LY * pow(u, 0.62)
		if i < 70:
			r = RADIUS_LY * 0.18 * pow(rng.randf(), 0.8)  # galactic bulge
		var arm := rng.randi() % arms
		var ang := float(arm) / float(arms) * TAU + r / RADIUS_LY * 5.2 + rng.randfn(0.0, 0.1 + 0.35 * exp(-r / 6000.0))
		var z := rng.randfn(0.0, 600.0 * exp(-r / 22000.0) + 120.0)
		var pos := Vector3(cos(ang) * r, z, sin(ang) * r)
		var st := {"id": i, "pos": pos, "cls": "", "name": Biomes.gen_name(rng), "seed": rng.randi() & 0x7fffffff, "bh": false, "bh_dest": -1}
		stars.append(st)
	# fixed story stars
	var home_ang := 0.75
	stars[0]["pos"] = Vector3(cos(home_ang) * 26000.0, 40.0, sin(home_ang) * 26000.0)
	stars[0]["name"] = "Solenne"
	stars[0]["cls"] = "G"
	stars[1]["pos"] = Vector3(cos(home_ang + 0.12) * 19000.0, -120.0, sin(home_ang + 0.12) * 19000.0)
	stars[1]["name"] = "Kharon"
	stars[1]["cls"] = "A"
	for st in stars:
		if st["cls"] == "":
			var rr := RandomNumberGenerator.new()
			rr.seed = st["seed"]
			st["cls"] = SystemGen._pick_class(rr)
	# black holes: home, the gate system, and ~9% of others
	for st in stars:
		var h: int = (st["seed"] * 2654435761) & 0xffffffff
		if st["id"] == 0:
			st["bh"] = true
			st["bh_dest"] = 1
		elif st["id"] == 1:
			st["bh"] = true
			st["bh_dest"] = 0
		elif (h >> 8) % 11 == 0:
			st["bh"] = true
			st["bh_dest"] = _nearest_toward_core(st["id"])


func _nearest_toward_core(id: int) -> int:
	# like NMS: a black hole sends you ~7000 ly closer to the galactic centre
	var p: Vector3 = stars[id]["pos"]
	var r := Vector2(p.x, p.z).length()
	var target_r := maxf(r - 7000.0, 1500.0)
	var best := 0
	var best_d := 1e30
	var dir := Vector3(p.x, 0, p.z).normalized()
	var tp := dir * target_r
	for st in stars:
		if st["id"] == id:
			continue
		var d := (st["pos"] as Vector3).distance_to(tp)
		if d < best_d:
			best_d = d
			best = st["id"]
	return best


func star(id: int) -> Dictionary:
	return stars[id]


func distance_ly(a: int, b: int) -> float:
	return (stars[a]["pos"] as Vector3).distance_to(stars[b]["pos"])


func get_system(id: int) -> StarSystem:
	if _cache.has(id):
		return _cache[id]
	var st: Dictionary = stars[id]
	var forced := "A" if id == 1 else ""
	var s := SystemGen.generate(id, st["pos"], st["seed"], forced, st["bh_dest"] if st["bh"] else -1)
	if id == 1:
		s.name = "Kharon"
	s.name = st["name"] if id != 0 else "Solenne"
	_cache[id] = s
	return s
