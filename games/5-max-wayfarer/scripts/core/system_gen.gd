class_name SystemGen
extends RefCounted
## Generates SystemData: a hand-tuned home system and seeded procedural systems for every other star.

const K_PLANET: float = 1.66e-4      # orbital period = K * r^1.5   (about 53-120 m/s orbital speed)
const K_MOON: float = 1.35e-3

static func kepler(orbit_r: float, is_moon: bool, jitter: float = 1.0) -> float:
	return (K_MOON if is_moon else K_PLANET) * pow(orbit_r, 1.5) * jitter

static func orbit_offset(b: BodyData, t: float) -> Vector3:
	var th: float = b.orbit_phase + TAU * t / b.orbit_period
	var x: float = b.orbit_r * cos(th)
	var z: float = b.orbit_r * sin(th)
	var y2: float = -z * sin(b.orbit_incl)
	var z2: float = z * cos(b.orbit_incl)
	var sn: float = sin(b.orbit_node)
	var cn: float = cos(b.orbit_node)
	return Vector3(x * cn + z2 * sn, y2, -x * sn + z2 * cn)

static func _body(sys: SystemData, nm: String, kind: String, biome: String, radius: float, orbit_r: float, parent: int, seed_i: int, r: RandomNumberGenerator) -> BodyData:
	var b := BodyData.new()
	b.index = sys.bodies.size()
	b.name = nm
	b.kind = kind
	b.biome = biome
	b.seed_i = seed_i
	b.radius = radius
	b.landable = kind != "gas"
	b.parent = parent
	b.orbit_r = orbit_r
	b.orbit_period = kepler(orbit_r, parent >= 0, r.randf_range(0.92, 1.08))
	b.orbit_phase = r.randf() * TAU
	b.orbit_incl = deg_to_rad(r.randf_range(-3.0, 3.0)) if parent < 0 else deg_to_rad(r.randf_range(-12.0, 12.0))
	b.orbit_node = r.randf() * TAU
	b.spin_phase = r.randf() * TAU
	b.tilt = deg_to_rad(r.randf_range(-24.0, 24.0))
	if kind == "gas":
		b.profile = {"label": "Gas Giant", "g": 22.0, "day_len": 540.0, "atm": {"on": true, "thick": 0.0}}
		b.spin_period = r.randf_range(420.0, 700.0)
		b.gravity = 22.0
		b.gas_colors = _gas_palette(r)
		b.rings = {"inner": radius * 1.35, "outer": radius * r.randf_range(2.1, 2.6), "tilt": r.randf_range(-0.4, 0.4)} if r.randf() < 0.75 else {}
	else:
		b.profile = Biomes.make_profile(biome, seed_i, radius)
		b.spin_period = float(b.profile["day_len"])
		if parent >= 0:
			b.tilt *= 0.4
		_make_outposts(b, r)
	b.derive()
	if parent >= 0:
		sys.bodies[parent].moons.append(b.index)
	sys.bodies.append(b)
	return b

static func _gas_palette(r: RandomNumberGenerator) -> Array:
	var sets: Array = [
		[Color(0.86, 0.66, 0.42), Color(0.95, 0.88, 0.74), Color(0.62, 0.38, 0.22), Color(0.80, 0.55, 0.36)],
		[Color(0.36, 0.60, 0.74), Color(0.62, 0.82, 0.90), Color(0.20, 0.38, 0.56), Color(0.50, 0.70, 0.82)],
		[Color(0.80, 0.50, 0.58), Color(0.94, 0.78, 0.76), Color(0.56, 0.30, 0.46), Color(0.72, 0.44, 0.52)],
		[Color(0.52, 0.72, 0.42), Color(0.82, 0.90, 0.66), Color(0.30, 0.50, 0.30), Color(0.64, 0.80, 0.50)],
	]
	return sets[r.randi() % sets.size()]

static func _make_outposts(b: BodyData, r: RandomNumberGenerator) -> void:
	var n: int = 3 if b.kind == "planet" else 2
	var kinds: Array = ["beacon", "crash", "monolith", "base", "crash"]
	b.outposts.clear()
	for i in n:
		var kind: String = "base" if i == 0 else String(kinds[r.randi() % kinds.size()])
		var dir: Vector3 = U.rand_unit(r)
		if absf(dir.y) > 0.85:
			dir.y *= 0.6
			dir = dir.normalized()
		var big: bool = kind == "base"
		b.outposts.append({"dir": dir, "kind": kind, "seed": r.randi(), "r_in": 36.0 if big else 14.0, "r_out": 84.0 if big else 38.0, "flat_h": 0.0, "placed": false})

static func _finish(sys: SystemData, r: RandomNumberGenerator) -> void:
	sys.nebula_a = Color.from_hsv(r.randf(), r.randf_range(0.45, 0.8), r.randf_range(0.5, 0.9))
	sys.nebula_b = Color.from_hsv(fposmod(sys.nebula_a.h + r.randf_range(0.25, 0.55), 1.0), r.randf_range(0.4, 0.8), r.randf_range(0.5, 0.9))
	sys.sky_seed = r.randf() * 100.0

## The hand-designed starting system.
static func home_system() -> SystemData:
	var g: Galaxy = Galaxy.get_galaxy()
	var info: Dictionary = g.star(Galaxy.HOME_INDEX)
	var s := SystemData.new()
	s.seed_i = 1001
	s.galaxy_index = Galaxy.HOME_INDEX
	s.name = "Helios"
	s.star_name = "Helios"
	s.star_class = "G"
	s.star_color = Color(1.0, 0.93, 0.76)
	s.star_radius = 2700.0
	s.star_temp = 5700.0
	s.star_light = 1.0
	var r := U.rng(s.seed_i)
	_body(s, "Cinder", "planet", "volcanic", 2600.0, 92000.0, -1, 101, r)
	_body(s, "Dune", "planet", "desert", 3500.0, 148000.0, -1, 102, r)
	var eden: BodyData = _body(s, "Eden", "planet", "lush", 4300.0, 214000.0, -1, 103, r)
	_body(s, "Selene", "moon", "dead", 1300.0, 25000.0, eden.index, 104, r)
	_body(s, "Mire", "planet", "toxic", 3100.0, 285000.0, -1, 105, r)
	var gol: BodyData = _body(s, "Goliath", "gas", "gas", 15000.0, 378000.0, -1, 106, r)
	gol.rings = {"inner": 21000.0, "outer": 36500.0, "tilt": 0.22}
	_body(s, "Rime", "moon", "frozen", 1700.0, 72000.0, gol.index, 107, r)
	_body(s, "Glacia", "planet", "frozen", 3700.0, 470000.0, -1, 108, r)
	_body(s, "Vesper", "planet", "radioactive", 2500.0, 565000.0, -1, 109, r)
	# fix phases so Eden starts in a pleasant place and the black hole is away from the planets
	eden.orbit_phase = 0.4
	eden.spin_phase = 1.0
	# the moon starts to the side of Eden (90 deg off the star direction) so the first approach is clear
	var selene: BodyData = s.bodies[3]
	var to_star: Vector3 = (-orbit_offset(eden, 0.0)).normalized()
	var side_ref: Vector3 = to_star.cross(Vector3.UP).normalized()
	var best_th: float = 0.0
	var best_score: float = -1e9
	for k in 360:
		selene.orbit_phase = float(k) * TAU / 360.0
		var off: Vector3 = orbit_offset(selene, 0.0).normalized()
		var score: float = -absf(off.dot(to_star)) * 3.0 + off.dot(side_ref)
		if score > best_score:
			best_score = score
			best_th = selene.orbit_phase
	selene.orbit_phase = best_th
	eden.pois = [
		{"kind": "station", "name": "Helios Gate", "dir": Vector3(0.46, 0.63, 0.62).normalized(), "alt": 7200.0, "scale": 2.4, "seed": 11},
		{"kind": "satellite", "dir": Vector3(0.40, 0.70, 0.59).normalized(), "alt": 7600.0, "scale": 1.8, "seed": 12},
		{"kind": "asteroids", "dir": Vector3(0.66, 0.50, 0.56).normalized(), "alt": 8600.0, "count": 16, "radius": 420.0, "seed": 13},
	]
	gol.pois = [
		{"kind": "asteroids", "dir": Vector3(0.9, 0.12, 0.42).normalized(), "alt": 32000.0, "count": 22, "radius": 700.0, "seed": 21},
		{"kind": "satellite", "dir": Vector3(-0.5, 0.2, 0.84).normalized(), "alt": 9000.0, "scale": 2.2, "seed": 22},
	]
	s.bodies[1].pois = [{"kind": "satellite", "dir": Vector3(0.2, 0.9, -0.38).normalized(), "alt": 6500.0, "scale": 1.8, "seed": 31}]
	s.has_black_hole = true
	s.bh_orbit_r = 735000.0
	s.bh_phase = 3.9
	s.bh_incl = deg_to_rad(4.0)
	s.bh_rs = 620.0
	s.bh_dest_index = int(info["bh_dest"])
	s.bh_axis = Vector3(0.20, 0.95, 0.24).normalized()
	_finish(s, r)
	s.nebula_a = Color(0.30, 0.38, 0.85)
	s.nebula_b = Color(0.80, 0.30, 0.55)
	return s

## Procedural system for any star of the galaxy.
static func generate(star_index: int) -> SystemData:
	if star_index == Galaxy.HOME_INDEX:
		return home_system()
	var g: Galaxy = Galaxy.get_galaxy()
	var info: Dictionary = g.star(star_index)
	var s := SystemData.new()
	s.seed_i = int(info["seed"])
	s.galaxy_index = star_index
	s.name = String(info["name"])
	s.star_name = s.name
	s.star_class = String(info["cls"])
	s.star_color = info["color"]
	s.star_radius = float(info["radius"])
	s.star_temp = float(info["temp"])
	s.star_light = float(info["light"])
	var r := U.rng(s.seed_i)
	var n_planets: int = r.randi_range(4, 7)
	var orbit: float = r.randf_range(40000.0, 62000.0)
	var hab: float = 200000.0 * sqrt(s.star_light)
	var gas_count: int = 0
	var used: Dictionary = {}
	for i in n_planets:
		orbit += r.randf_range(52000.0, 92000.0) + 12000.0 * float(i)
		var zone: float = orbit / hab
		var gas_p: float = 0.03 if zone < 0.9 else (0.22 if zone < 1.8 else 0.38)
		var pseed: int = U.hash2(s.seed_i, i + 1)
		var pname: String = U.gen_name(pseed)
		if r.randf() < gas_p and gas_count < 2 and i >= 2:
			gas_count += 1
			var gp: BodyData = _body(s, pname, "gas", "gas", r.randf_range(11000.0, 19000.0), orbit, -1, pseed, r)
			if gp.rings.is_empty() and r.randf() < 0.5:
				gp.rings = {"inner": gp.radius * 1.4, "outer": gp.radius * 2.2, "tilt": r.randf_range(-0.3, 0.3)}
			if r.randf() < 0.7:
				var mseed: int = U.hash2(pseed, 99)
				var mb: String = "frozen" if zone > 1.4 else "dead"
				_body(s, U.gen_name(mseed), "moon", mb, r.randf_range(1100.0, 1800.0), gp.radius * r.randf_range(4.0, 5.2) + 20000.0, gp.index, mseed, r)
			continue
		var biome: String = _pick_biome(zone, r, used)
		used[biome] = int(used.get(biome, 0)) + 1
		var radius: float = r.randf_range(2200.0, 4900.0)
		var p: BodyData = _body(s, pname, "planet", biome, radius, orbit, -1, pseed, r)
		if radius > 2800.0 and r.randf() < 0.4:
			var mseed2: int = U.hash2(pseed, 77)
			var mbiome: String = "dead" if (zone < 1.3 or r.randf() < 0.55) else "frozen"
			var mr: float = r.randf_range(950.0, 1700.0)
			_body(s, U.gen_name(mseed2), "moon", mbiome, mr, p.frame_radius + mr + 6000.0 + r.randf_range(2000.0, 6000.0) + mr * 2.2, p.index, mseed2, r)
	_add_pois(s, r)
	# guarantee at least four landable bodies
	while s.landable_bodies().size() < 4:
		var mseed3: int = U.hash2(s.seed_i, 500 + s.bodies.size())
		orbit += 90000.0
		_body(s, U.gen_name(mseed3), "planet", _pick_biome(orbit / hab, r, used), r.randf_range(2200.0, 4400.0), orbit, -1, mseed3, r)
	if bool(info["bh"]):
		s.has_black_hole = true
		s.bh_orbit_r = minf(orbit * 1.12 + 70000.0, 980000.0)
		s.bh_phase = r.randf() * TAU
		s.bh_incl = deg_to_rad(r.randf_range(-6.0, 6.0))
		s.bh_rs = r.randf_range(520.0, 720.0)
		s.bh_dest_index = int(info["bh_dest"])
		s.bh_axis = Vector3(r.randf_range(-0.3, 0.3), 1.0, r.randf_range(-0.3, 0.3)).normalized()
	_finish(s, r)
	return s

## orbital extras of a generated system: sometimes a station above a habitable world, derelict satellites, asteroid clusters
static func _add_pois(s: SystemData, r: RandomNumberGenerator) -> void:
	var land: Array = []
	for b in s.bodies:
		if b.landable and b.kind == "planet":
			land.append(b)
	if land.is_empty():
		return
	if r.randf() < 0.5:
		var hostb: BodyData = land[r.randi() % land.size()]
		var d: Vector3 = U.rand_unit(r)
		hostb.pois.append({"kind": "station", "name": "%s Gate" % hostb.name, "dir": d, "alt": r.randf_range(6500.0, 8000.0), "scale": 2.4, "seed": r.randi()})
		hostb.pois.append({"kind": "asteroids", "dir": U.rand_unit(r), "alt": r.randf_range(7000.0, 9500.0), "count": 14, "radius": 380.0, "seed": r.randi()})
	for b2 in s.bodies:
		if b2.kind != "gas" and r.randf() < 0.3:
			b2.pois.append({"kind": "satellite", "dir": U.rand_unit(r), "alt": r.randf_range(5500.0, 9000.0), "scale": 1.8, "seed": r.randi()})
		elif b2.kind == "gas" and r.randf() < 0.7:
			b2.pois.append({"kind": "asteroids", "dir": U.rand_unit(r), "alt": b2.radius * 2.3, "count": 20, "radius": 650.0, "seed": r.randi()})

static func _pick_biome(zone: float, r: RandomNumberGenerator, used: Dictionary) -> String:
	var w: Dictionary
	if zone < 0.6:
		w = {"volcanic": 0.34, "desert": 0.28, "dead": 0.16, "radioactive": 0.14, "toxic": 0.08}
	elif zone < 1.5:
		w = {"lush": 0.30, "desert": 0.16, "toxic": 0.18, "dead": 0.08, "frozen": 0.06, "volcanic": 0.08, "radioactive": 0.08, "toxic2": 0.0}
	else:
		w = {"frozen": 0.40, "dead": 0.18, "radioactive": 0.10, "toxic": 0.10, "desert": 0.10, "lush": 0.06, "volcanic": 0.06}
	# discourage duplicates
	var total: float = 0.0
	var keys: Array = []
	var weights: Array = []
	for k in w.keys():
		if k == "toxic2":
			continue
		var wt: float = float(w[k]) / (1.0 + 1.8 * float(used.get(k, 0)))
		keys.append(k)
		weights.append(wt)
		total += wt
	var x: float = r.randf() * total
	for i in keys.size():
		x -= float(weights[i])
		if x <= 0.0:
			return String(keys[i])
	return String(keys[0])
