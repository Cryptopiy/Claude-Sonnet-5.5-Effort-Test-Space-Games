class_name SystemGen
extends RefCounted
## Seeded star-system generator. Same id -> same system, always.

const STAR_CLASSES := {
	"O": {"color": Color(0.62, 0.72, 1.0), "radius": 10000.0, "energy": 3.4, "temp": 35000},
	"B": {"color": Color(0.72, 0.82, 1.0), "radius": 9000.0, "energy": 3.0, "temp": 20000},
	"A": {"color": Color(0.88, 0.92, 1.0), "radius": 7600.0, "energy": 2.6, "temp": 9000},
	"F": {"color": Color(1.0, 0.96, 0.84), "radius": 6800.0, "energy": 2.3, "temp": 7000},
	"G": {"color": Color(1.0, 0.9, 0.66), "radius": 6000.0, "energy": 2.1, "temp": 5800},
	"K": {"color": Color(1.0, 0.72, 0.42), "radius": 5200.0, "energy": 1.8, "temp": 4500},
	"M": {"color": Color(1.0, 0.48, 0.3), "radius": 4500.0, "energy": 1.5, "temp": 3200},
}
const CLASS_WEIGHTS := [["M", 0.3], ["K", 0.22], ["G", 0.17], ["F", 0.11], ["A", 0.09], ["B", 0.07], ["O", 0.04]]


static func _pick_class(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	var acc := 0.0
	for cw in CLASS_WEIGHTS:
		acc += cw[1]
		if r <= acc:
			return cw[0]
	return "M"


static func _apply_class(s: StarSystem, cls: String) -> void:
	var c: Dictionary = STAR_CLASSES[cls]
	s.star_class = cls
	s.star_color = c["color"]
	s.star_radius = c["radius"]
	s.star_energy = c["energy"]


static func _orbit_period(r: float, rng: RandomNumberGenerator) -> float:
	return 4800.0 * pow(r / 185000.0, 1.5) * rng.randf_range(0.9, 1.1)


static func _add(s: StarSystem, p: PlanetData, orbit_r: float, parent: int, rng: RandomNumberGenerator) -> int:
	p.orbit_r = orbit_r
	p.parent = parent
	p.orbit_phase = rng.randf() * TAU
	p.orbit_incl = rng.randf_range(-0.08, 0.08)
	if parent < 0:
		p.orbit_period = _orbit_period(orbit_r, rng)
	else:
		p.orbit_period = 1800.0 * pow(orbit_r / 30000.0, 1.5) * rng.randf_range(0.9, 1.1)
	s.bodies.append(p)
	return s.bodies.size() - 1


## The hand-authored home system.
static func home() -> StarSystem:
	var s := StarSystem.new()
	s.id = 0
	s.name = "Solenne"
	s.seed = 7001
	_apply_class(s, "G")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	_add(s, Biomes.make("volcanic", 11, "Pyrrhus", 3400.0), 72000.0, -1, rng)
	_add(s, Biomes.make("desert", 23, "Kharos", 4700.0), 122000.0, -1, rng)
	var v := _add(s, Biomes.make("lush", 37, "Verdance", 5200.0), 186000.0, -1, rng)
	_add(s, Biomes.make("barren", 41, "Lumen", 1900.0, "moon"), 22000.0, v, rng)
	_add(s, Biomes.make("toxic", 53, "Miasma", 4200.0), 252000.0, -1, rng)
	_add(s, Biomes.make("frozen", 67, "Glacia", 4500.0), 326000.0, -1, rng)
	var g := _add(s, Biomes.make_gas(79, "Titanus", 12500.0), 430000.0, -1, rng)
	_add(s, Biomes.make("barren", 83, "Cinder", 2100.0, "moon"), 46000.0, g, rng)
	_add(s, Biomes.make("frozen", 97, "Hush", 2300.0, "moon"), 72000.0, g, rng)
	s.start_planet = v
	var a := 2.1
	s.black_hole = {"pos": Vector3(cos(a), 0.02, sin(a)) * 600000.0, "rs": 3000.0, "name": "Eventide", "dest": 1}
	return s


static func generate(id: int, gpos: Vector3, seed_: int, forced_class: String = "", dest_bh: int = -1) -> StarSystem:
	if id == 0:
		var h := home()
		h.galaxy_pos = gpos
		return h
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var s := StarSystem.new()
	s.id = id
	s.seed = seed_
	s.galaxy_pos = gpos
	s.name = Biomes.gen_name(rng)
	var cls := forced_class if forced_class != "" else _pick_class(rng)
	_apply_class(s, cls)
	var n := rng.randi_range(4, 6)
	var r: float = rng.randf_range(64000.0, 90000.0) * (STAR_CLASSES[cls]["radius"] / 6000.0) * 0.7 + 10000.0
	var hot_bias: float = {"O": 0.2, "B": 0.15, "A": 0.08, "F": 0.03, "G": 0.0, "K": -0.05, "M": -0.12}[cls]
	var gas_done := false
	var landable := 0
	for i in n:
		var t: float = float(i) / float(maxi(n - 1, 1)) - hot_bias
		var zone := "warm"
		if t < 0.3:
			zone = "hot"
		elif t > 0.68:
			zone = "cold"
		var biome := _pick_biome(rng, zone, cls)
		var pname: String = Biomes.gen_name(rng) + " " + ["I", "II", "III", "IV", "V", "VI", "VII"][i]
		var pseed: int = seed_ * 31 + i * 977 + 5
		var pid := -1
		if biome == "gas" and not gas_done and i >= 2:
			gas_done = true
			var gp := Biomes.make_gas(pseed, pname, rng.randf_range(9000.0, 14000.0))
			pid = _add(s, gp, r, -1, rng)
			var nm := rng.randi_range(1, 3)
			for m in nm:
				var mb := "barren" if rng.randf() < 0.55 else ("frozen" if rng.randf() < 0.6 else "volcanic")
				var moon := Biomes.make(mb, pseed + 17 * (m + 1), Biomes.gen_name(rng), rng.randf_range(1500.0, 2600.0), "moon")
				_add(s, moon, gp.radius * 3.2 + 28000.0 * (m + 1), pid, rng)
				landable += 1
		else:
			if biome == "gas":
				biome = "barren"
			var rad := rng.randf_range(2800.0, 5800.0)
			var p := Biomes.make(biome, pseed, pname, rad)
			pid = _add(s, p, r, -1, rng)
			landable += 1
			if rng.randf() < 0.4:
				var mb := "barren" if rng.randf() < 0.6 else "frozen"
				var moon := Biomes.make(mb, pseed + 13, Biomes.gen_name(rng), rng.randf_range(1500.0, 2400.0), "moon")
				_add(s, moon, rad * 3.4 + 16000.0, pid, rng)
				landable += 1
		r *= rng.randf_range(1.32, 1.6)
	# make sure we have enough landable bodies
	var guard := 0
	while landable < 5 and guard < 4:
		guard += 1
		var moon := Biomes.make("barren", seed_ + guard * 7, Biomes.gen_name(rng), 2000.0, "moon")
		_add(s, moon, 20000.0 + guard * 5000.0, 0, rng)
		landable += 1
	for i in s.bodies.size():
		if s.bodies[i].landable and s.bodies[i].parent < 0 and s.bodies[i].biome in ["lush", "desert", "frozen", "toxic"]:
			s.start_planet = i
			break
	if dest_bh >= 0:
		var a := rng.randf() * TAU
		s.black_hole = {"pos": Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(520000.0, 700000.0), "rs": rng.randf_range(2200.0, 3600.0), "name": "Gate " + s.name, "dest": dest_bh}
	return s


static func _pick_biome(rng: RandomNumberGenerator, zone: String, cls: String) -> String:
	var tbl: Array
	match zone:
		"hot":
			tbl = [["volcanic", 0.35], ["desert", 0.3], ["barren", 0.35]]
		"warm":
			tbl = [["lush", 0.3], ["desert", 0.2], ["toxic", 0.2], ["barren", 0.1], ["volcanic", 0.1], ["frozen", 0.1]]
		_:
			tbl = [["frozen", 0.4], ["toxic", 0.2], ["barren", 0.15], ["gas", 0.25]]
	var r := rng.randf()
	var acc := 0.0
	for e in tbl:
		acc += e[1]
		if r <= acc:
			return e[0]
	return tbl[0][0]
