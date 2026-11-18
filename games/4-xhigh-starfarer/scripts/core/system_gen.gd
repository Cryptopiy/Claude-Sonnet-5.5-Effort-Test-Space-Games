class_name SystemGen
extends RefCounted
## Builds the list of PlanetData for a star. The home system is hand-composed (guaranteed variety), all others are
## generated from the star seed. Orbital layout is compact so travel between planets takes seconds with the pulse drive.

var info: Galaxy.StarInfo
var planets: Array = []          # PlanetData
var star_radius := 4000.0
var star_color := Color(1.0, 0.9, 0.7)
var star_lum := 1.0
var bh_present := false
var bh_orbit := 800000.0
var bh_phase := 3.4
var bh_radius := 900.0


static func orbit_period(a: float) -> float:
	return 1500.0 * pow(a / 100000.0, 1.5)


func _add(biome: int, pname: String, seed: int, radius: float, a: float, parent := -1) -> PlanetData:
	var p := Biomes.make(biome, seed, radius, pname)
	p.index = planets.size()
	p.parent_idx = parent
	if parent >= 0:
		p.orbit_radius = a
		p.orbit_period = 650.0 * pow(a / 22000.0, 1.5)
	else:
		p.orbit_radius = a
		p.orbit_period = orbit_period(a)
	planets.append(p)
	return p


func build(star: Galaxy.StarInfo) -> void:
	info = star
	planets.clear()
	star_color = star.color
	star_lum = star.lum
	star_radius = 4000.0 * star.size_mul
	bh_present = star.has_bh
	var rng := RandomNumberGenerator.new()
	rng.seed = star.seed
	if star.id == Galaxy.HOME_ID:
		_home()
	else:
		_random(rng)
	if bh_present:
		bh_orbit = rng.randf_range(760000.0, 980000.0)
		bh_phase = rng.randf() * TAU
		if star.id == Galaxy.HOME_ID:
			bh_orbit = 820000.0
			bh_phase = 3.5


func _home() -> void:
	var p0 := _add(PlanetData.Biome.VOLCANIC, "Ember", 101, 3300.0, 105000.0)
	p0.spin_period = 1100.0
	var p1 := _add(PlanetData.Biome.DESERT, "Dune", 202, 4300.0, 165000.0)
	p1.spin_period = 1400.0
	var p2 := _add(PlanetData.Biome.LUSH, "Verdant", 303, 5200.0, 250000.0)
	p2.spin_period = 1500.0
	p2.axial_tilt = 0.2
	_add(PlanetData.Biome.BARREN, "Pale", 404, 1700.0, 26000.0, p2.index)
	var g := _add(PlanetData.Biome.GAS, "Goliath", 505, 17000.0, 360000.0)
	g.spin_period = 900.0
	_add(PlanetData.Biome.EXOTIC, "Prismara", 606, 2800.0, 64000.0, g.index)
	_add(PlanetData.Biome.TOXIC, "Mire", 707, 3900.0, 470000.0)
	_add(PlanetData.Biome.FROZEN, "Frost", 808, 4700.0, 590000.0)


func _random(rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(5, 7)
	var a := rng.randf_range(90000.0, 120000.0) * sqrt(info.size_mul)
	var zone_hot: Array = [PlanetData.Biome.VOLCANIC, PlanetData.Biome.DESERT, PlanetData.Biome.BARREN]
	var zone_mid: Array = [PlanetData.Biome.LUSH, PlanetData.Biome.TOXIC, PlanetData.Biome.EXOTIC, PlanetData.Biome.DESERT]
	var zone_cold: Array = [PlanetData.Biome.FROZEN, PlanetData.Biome.BARREN, PlanetData.Biome.EXOTIC, PlanetData.Biome.GAS]
	if info.cls == "M" or info.cls == "K":
		zone_mid = [PlanetData.Biome.LUSH, PlanetData.Biome.FROZEN, PlanetData.Biome.TOXIC, PlanetData.Biome.EXOTIC]
	elif info.cls == "O" or info.cls == "B" or info.cls == "A":
		zone_hot = [PlanetData.Biome.VOLCANIC, PlanetData.Biome.BARREN, PlanetData.Biome.DESERT]
		zone_mid = [PlanetData.Biome.DESERT, PlanetData.Biome.EXOTIC, PlanetData.Biome.TOXIC, PlanetData.Biome.VOLCANIC]
	var used := {}
	var gas_done := false
	for i in n:
		var f := float(i) / float(n - 1)
		var pool: Array = zone_hot if f < 0.28 else (zone_mid if f < 0.62 else zone_cold)
		var b: int = pool[rng.randi() % pool.size()]
		var tries := 0
		while used.has(b) and used[b] >= 2 and tries < 8:
			b = pool[rng.randi() % pool.size()]
			tries += 1
		if b == PlanetData.Biome.GAS and gas_done:
			b = PlanetData.Biome.FROZEN
		used[b] = used.get(b, 0) + 1
		var rad := rng.randf_range(2600.0, 5600.0)
		if b == PlanetData.Biome.GAS:
			rad = rng.randf_range(13000.0, 21000.0)
			gas_done = true
		elif b == PlanetData.Biome.BARREN:
			rad = rng.randf_range(1500.0, 3200.0)
		var pn := "%s %s" % [info.name, ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][i]]
		var p := _add(b, pn, rng.randi() & 0x7FFFFFF, rad, a)
		a *= rng.randf_range(1.35, 1.6)
		if b == PlanetData.Biome.GAS or (rng.randf() < 0.3 and b != PlanetData.Biome.BARREN):
			var mb: int = [PlanetData.Biome.BARREN, PlanetData.Biome.FROZEN, PlanetData.Biome.EXOTIC][rng.randi() % 3]
			var mr := rng.randf_range(1500.0, 2800.0)
			_add(mb, pn + "-a", rng.randi() & 0x7FFFFFF, mr, maxf(p.radius * 3.0, 18000.0) + rng.randf_range(0.0, 20000.0), p.index)
	# make sure at least 4 landable bodies exist
	var landable := 0
	for p in planets:
		if p.landable:
			landable += 1
	if landable < 4:
		_add(PlanetData.Biome.BARREN, info.name + " Minor", rng.randi() & 0x7FFFFFF, 2200.0, a)


## A good landing direction: low, flat, above the waterline, away from the poles.
static func find_landing_site(d: PlanetData, seed_hint := 1) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = d.seed + seed_hint
	var best := Vector3.UP
	var best_score := -1e9
	for i in 120:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1, 1)).normalized()
		var h := d.height_at(dir)
		var n := d.normal_at(dir, 3.0)
		var flat := n.dot(dir)
		var above := h - (d.sea_level if d.has_liquid() else -1e6)
		var score := flat * 100.0 - absf(h - 25.0) * 0.1
		if d.has_liquid() and above < 8.0:
			score -= 200.0
		if flat < 0.97:
			score -= 50.0
		if score > best_score:
			best_score = score
			best = dir
	return best
