extends Node
## UNIVERSE: the seeded galaxy, system generation and celestial mechanics (all in double precision via DVec).
## Pure simulation data - no rendering. Rendering nodes are created by world/star_system.gd and positioned by autoload/frame.gd.

const GALAXY_SEED := 20261031
const STAR_COUNT := 720
const GALAXY_RADIUS_LY := 50000.0
const HOME_ID := 0
const SECOND_ID := 1
const BH_JUMP_LY := 7000.0              # black holes lead roughly this far toward the galactic centre (like in NMS)
const START_TIME := 120.0

const STAR_CLASSES := {
	"O": {"color": Color(0.60, 0.70, 1.00), "temp": 35000.0, "radius": 90000.0, "energy": 2.0, "weight": 0.01, "zone_shift": 0.18},
	"B": {"color": Color(0.68, 0.78, 1.00), "temp": 18000.0, "radius": 76000.0, "energy": 1.8, "weight": 0.03, "zone_shift": 0.14},
	"A": {"color": Color(0.82, 0.88, 1.00), "temp": 9000.0, "radius": 62000.0, "energy": 1.55, "weight": 0.05, "zone_shift": 0.08},
	"F": {"color": Color(1.00, 0.97, 0.86), "temp": 6800.0, "radius": 52000.0, "energy": 1.4, "weight": 0.09, "zone_shift": 0.04},
	"G": {"color": Color(1.00, 0.90, 0.62), "temp": 5800.0, "radius": 48000.0, "energy": 1.25, "weight": 0.12, "zone_shift": 0.0},
	"K": {"color": Color(1.00, 0.68, 0.36), "temp": 4500.0, "radius": 42000.0, "energy": 1.05, "weight": 0.20, "zone_shift": -0.08},
	"M": {"color": Color(1.00, 0.40, 0.24), "temp": 3200.0, "radius": 36000.0, "energy": 0.9, "weight": 0.50, "zone_shift": -0.16},
}
const CLASS_ORDER := ["O", "B", "A", "F", "G", "K", "M"]

signal system_changed(system_id: int)

var time: float = START_TIME                    # seconds of universe time (advanced by Frame each frame)
var galaxy: Array = []                          # Array[GalaxyStar]
var current_id: int = -1
var system: SystemDef = null                    # the loaded system
var body_nodes: Array = []                      # Array[Node3D], aligned with system.bodies (set by StarSystem.build)
var star_node: Node3D = null                    # the star visual (set by StarSystem.build)
var _system_cache: Dictionary = {}
var _bh_dest_cache: Dictionary = {}

func _ready() -> void:
	_generate_galaxy()

# ---------------------------------------------------------------------------------------------------------------------
# Galaxy
# ---------------------------------------------------------------------------------------------------------------------
func _generate_galaxy() -> void:
	galaxy.clear()
	var rng := SeedUtil.rng(GALAXY_SEED)
	var used_names: Dictionary = {}

	var home := GalaxyStar.new()
	home.id = HOME_ID
	home.name = "Aurelia"
	home.spectral_class = "G"
	var a0 := 2.05
	home.pos = Vector3(26000.0 * cos(a0), 95.0, 26000.0 * sin(a0))
	home.special = true
	home.has_black_hole = true
	galaxy.append(home)

	var second := GalaxyStar.new()
	second.id = SECOND_ID
	second.name = "Kepler's Rest"
	second.spectral_class = "K"
	var to_center := (-home.pos).normalized()
	second.pos = home.pos + to_center * BH_JUMP_LY + Vector3(310.0, -140.0, -260.0)
	second.special = true
	second.has_black_hole = true
	galaxy.append(second)
	used_names["Aurelia"] = 1
	used_names["Kepler's Rest"] = 1

	var weights: Array = []
	for c in CLASS_ORDER:
		weights.append(STAR_CLASSES[c]["weight"])

	for i in range(2, STAR_COUNT):
		var s := GalaxyStar.new()
		s.id = i
		s.seed = SeedUtil.hash2(GALAXY_SEED, i)
		var r: float
		var ang: float
		var y: float
		if rng.randf() < 0.20:   # bulge
			r = absf(rng.randfn(0.0, 4200.0))
			ang = rng.randf() * TAU
			y = rng.randfn(0.0, 1500.0)
		else:                    # two-armed logarithmic spiral
			r = 2800.0 + pow(rng.randf(), 0.85) * (GALAXY_RADIUS_LY - 2800.0)
			var arm := float(rng.randi() % 2)
			ang = 2.35 * log(r / 2800.0) + arm * PI + rng.randfn(0.0, 0.30)
			y = rng.randfn(0.0, 650.0 * (1.15 - 0.5 * r / GALAXY_RADIUS_LY))
		s.pos = Vector3(r * cos(ang), y, r * sin(ang))
		var ci := SeedUtil.pick_weighted(rng, weights)
		s.spectral_class = CLASS_ORDER[ci]
		var nm := SeedUtil.make_name(s.seed)
		if used_names.has(nm):
			used_names[nm] += 1
			nm += " " + SeedUtil.roman(used_names[nm])
		else:
			used_names[nm] = 1
		s.name = nm
		s.has_black_hole = SeedUtil.rand01(s.seed, 991) < 0.10
		galaxy.append(s)

	for s in galaxy:
		var cdef: Dictionary = STAR_CLASSES[s.spectral_class]
		s.color = cdef["color"]
		if s.seed == 0:
			s.seed = SeedUtil.hash2(GALAXY_SEED, s.id)

func get_star(id: int) -> GalaxyStar:
	return galaxy[clampi(id, 0, galaxy.size() - 1)]

func current_star() -> GalaxyStar:
	return get_star(maxi(current_id, 0))

## the k nearest stars to star `id`, excluding itself, as Array[GalaxyStar]
func nearest_stars(id: int, k: int) -> Array:
	var me: GalaxyStar = get_star(id)
	var arr: Array = []
	for s in galaxy:
		if s.id != id:
			arr.append([me.pos.distance_squared_to(s.pos), s])
	arr.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for i in mini(k, arr.size()):
		out.append(arr[i][1])
	return out

## Where does the black hole of system `id` lead? (home <-> second system; others: ~7000 ly toward the centre)
func black_hole_destination(id: int) -> int:
	if id == HOME_ID:
		return SECOND_ID
	if id == SECOND_ID:
		return HOME_ID
	if _bh_dest_cache.has(id):
		return _bh_dest_cache[id]
	var me := get_star(id)
	var target := me.pos + (-me.pos).normalized() * minf(BH_JUMP_LY, me.pos.length())
	var best := -1
	var bd := INF
	for s in galaxy:
		if s.id == id:
			continue
		var d := target.distance_squared_to(s.pos)
		if d < bd:
			bd = d
			best = s.id
	_bh_dest_cache[id] = best
	return best

# ---------------------------------------------------------------------------------------------------------------------
# Systems
# ---------------------------------------------------------------------------------------------------------------------
func get_system(id: int) -> SystemDef:
	if _system_cache.has(id):
		return _system_cache[id]
	var s := _generate_system(id)
	_system_cache[id] = s
	return s

## make `id` the current system (does not build nodes; Game/StarSystem do that)
func set_current(id: int) -> SystemDef:
	current_id = id
	system = get_system(id)
	body_nodes = []
	star_node = null
	system_changed.emit(id)
	return system

func _generate_system(id: int) -> SystemDef:
	var gs: GalaxyStar = get_star(id)
	var s := SystemDef.new()
	s.id = id
	s.name = gs.name
	s.seed = gs.seed
	s.star = _make_star(gs)
	var rng := SeedUtil.rng(gs.seed, 4242)
	if id == HOME_ID:
		_fill_home(s, rng)
	else:
		_fill_procedural(s, gs, rng)
	_finalize_system(s, gs, rng)
	return s

func _make_star(gs: GalaxyStar) -> StarDef:
	var c: Dictionary = STAR_CLASSES[gs.spectral_class]
	var st := StarDef.new()
	st.name = gs.name
	st.spectral_class = gs.spectral_class
	st.color = c["color"]
	st.light_color = c["color"].lerp(Color(1, 1, 1), 0.55)
	st.temperature = c["temp"]
	var var_r := 1.0 + (SeedUtil.rand01(gs.seed, 5) - 0.5) * 0.2
	st.radius = c["radius"] * var_r
	st.light_energy = c["energy"]
	return st

func _make_body(s: SystemDef, kind: int, parent: int, biome: String, name: String, rng: RandomNumberGenerator) -> BodyDef:
	var b := BodyDef.new()
	b.index = s.bodies.size()
	b.system_id = s.id
	b.kind = kind
	b.parent = parent
	b.biome = biome
	b.name = name
	b.seed = SeedUtil.hash2(s.seed, b.index + 1)
	b.palette_seed = SeedUtil.hash2(b.seed, 31337)
	var bio: Dictionary = BiomeDB.get_biome(biome)
	b.radius = rng.randf_range(bio["radius"][0], bio["radius"][1])
	b.gravity = rng.randf_range(bio["gravity"][0], bio["gravity"][1])
	b.landable = bio["landable"]
	b.spin_period = rng.randf_range(bio["spin"][0], bio["spin"][1])
	b.spin_phase = rng.randf() * TAU
	b.axial_tilt = deg_to_rad(rng.randf_range(0.0, 26.0))
	b.tilt_azimuth = rng.randf() * TAU
	b.has_atmosphere = rng.randf() < bio["atmo_chance"]
	b.atmo_height = clampf(b.radius * bio["atmo_frac"], 2500.0, 6000.0) if b.has_atmosphere else 0.0
	b.ocean_kind = bio["ocean"] if rng.randf() < bio["ocean_chance"] else ""
	b.has_ocean = b.ocean_kind != ""
	b.temp_day_c = rng.randf_range(bio["temp_day"][0], bio["temp_day"][1])
	b.temp_night_c = rng.randf_range(bio["temp_night"][0], bio["temp_night"][1])
	b.toxicity = bio["toxic"]
	b.radiation = bio["radiation"]
	b.tint = Color.from_hsv(rng.randf(), 0.0, 1.0)   # (saturation 0 = neutral; modules may re-derive from palette_seed)
	if kind == BodyDef.Kind.GAS_GIANT:
		b.has_rings = rng.randf() < 0.5
		b.capture_radius = b.radius * 12.0
		b.gravity = 0.0
		b.landable = false
		b.has_atmosphere = true
		b.atmo_height = b.radius * 0.12
	else:
		b.capture_radius = b.radius * 14.0
	if b.has_rings:
		b.ring_inner = b.radius * 1.35
		b.ring_outer = b.radius * 2.3
	s.bodies.append(b)
	if parent >= 0:
		s.bodies[parent].moons.append(b.index)
	return b

func _set_orbit(b: BodyDef, orbit_radius: float, speed: float, rng: RandomNumberGenerator, max_incl_deg: float = 3.0) -> void:
	b.orbit_radius = orbit_radius
	b.orbit_period = TAU * orbit_radius / speed
	b.orbit_phase = rng.randf() * TAU
	var node := rng.randf() * TAU
	var incl := deg_to_rad(rng.randf_range(-max_incl_deg, max_incl_deg))
	var u := Vector3(cos(node), 0.0, sin(node))
	var n := Vector3.UP.rotated(u, incl)
	b.orbit_u = u
	b.orbit_v = n.cross(u).normalized()

## Hand-authored home system "Aurelia": 5 landable worlds in 6 biomes + a gas giant, guaranteed variety for the first session.
func _fill_home(s: SystemDef, rng: RandomNumberGenerator) -> void:
	var defs := [
		# name, kind, parent, biome, radius, gravity, orbit_km, speed, spin_s
		["Cinder", BodyDef.Kind.PLANET, -1, "volcanic", 6200.0, 11.5, 520.0, 430.0, 640.0],
		["Verdant", BodyDef.Kind.PLANET, -1, "lush", 9000.0, 9.8, 900.0, 390.0, 960.0],
		["Pale", BodyDef.Kind.MOON, 1, "barren", 2700.0, 3.4, 78.0, 260.0, 1500.0],
		["Dune", BodyDef.Kind.PLANET, -1, "desert", 7600.0, 8.6, 1400.0, 360.0, 780.0],
		["Boreas", BodyDef.Kind.PLANET, -1, "frozen", 8200.0, 9.1, 2000.0, 330.0, 1100.0],
		["Colossus", BodyDef.Kind.GAS_GIANT, -1, "gas", 36000.0, 0.0, 2800.0, 300.0, 420.0],
		["Miasma", BodyDef.Kind.MOON, 5, "toxic", 4400.0, 6.4, 190.0, 220.0, 900.0],
		["Prism", BodyDef.Kind.MOON, 5, "exotic", 3600.0, 5.2, 310.0, 180.0, 1200.0],
	]
	for d in defs:
		var b := _make_body(s, d[1], d[2], d[3], d[0], rng)
		b.radius = d[4]
		if d[1] != BodyDef.Kind.GAS_GIANT:
			b.gravity = d[5]
			b.capture_radius = b.radius * 14.0
		else:
			b.capture_radius = b.radius * 12.0
			b.has_rings = true
			b.ring_inner = b.radius * 1.35
			b.ring_outer = b.radius * 2.3
		b.has_atmosphere = d[3] != "barren"
		b.atmo_height = clampf(b.radius * BiomeDB.get_biome(d[3])["atmo_frac"], 2500.0, 6000.0) if b.has_atmosphere else 0.0
		if d[3] == "gas":
			b.atmo_height = b.radius * 0.12
		b.ocean_kind = BiomeDB.get_biome(d[3])["ocean"]
		b.has_ocean = b.ocean_kind != ""
		b.spin_period = d[8]
		_set_orbit(b, d[6] * 1000.0, d[7], rng, 2.0)
	# fixed, pleasing start arrangement
	s.bodies[1].orbit_phase = 0.9
	s.bodies[0].orbit_phase = 2.6
	s.bodies[3].orbit_phase = 4.1
	s.bodies[4].orbit_phase = 5.5
	s.bodies[5].orbit_phase = 3.3
	s.bodies[2].orbit_phase = 1.0
	s.bodies[6].orbit_phase = 0.4
	s.bodies[7].orbit_phase = 3.9
	s.start_body = 1
	s.arrival_body = 1

func _fill_procedural(s: SystemDef, gs: GalaxyStar, rng: RandomNumberGenerator) -> void:
	var cdef: Dictionary = STAR_CLASSES[gs.spectral_class]
	var zone_shift: float = cdef["zone_shift"]
	var n_planets := rng.randi_range(4, 6)
	var prev_orbit := 0.0
	var prev_cap := 0.0
	var gas_count := 0
	var prefix := gs.name
	var planet_biomes: Array = []
	for i in n_planets:
		var z := float(i) / float(maxi(n_planets - 1, 1))
		var is_gas := i >= 2 and gas_count < 2 and rng.randf() < 0.18 + 0.30 * z
		var biome := "gas"
		var kind := BodyDef.Kind.GAS_GIANT
		if not is_gas:
			kind = BodyDef.Kind.PLANET
			biome = _pick_biome(rng, clampf(z - zone_shift, 0.0, 1.0), planet_biomes)
		else:
			gas_count += 1
		var nm := "%s %s" % [prefix, SeedUtil.roman(s.bodies.size() + 1)]
		var b := _make_body(s, kind, -1, biome, nm, rng)
		var orbit: float
		if i == 0:
			orbit = rng.randf_range(450.0, 620.0) * 1000.0
		else:
			orbit = maxf(prev_orbit * rng.randf_range(1.32, 1.6), prev_orbit + prev_cap + b.capture_radius + 130000.0)
		_set_orbit(b, orbit, rng.randf_range(300.0, 440.0), rng, 3.0)
		prev_orbit = orbit
		prev_cap = b.capture_radius
		planet_biomes.append(biome)
		# moons
		var n_moons := 0
		if kind == BodyDef.Kind.GAS_GIANT:
			n_moons = rng.randi_range(1, 3)
		elif rng.randf() < 0.38:
			n_moons = 1
		for m in n_moons:
			var mbiome := _pick_moon_biome(rng, z)
			var mb := _make_body(s, BodyDef.Kind.MOON, b.index, mbiome, "%s %s" % [nm, char(97 + m)], rng)
			mb.radius = minf(mb.radius, b.radius * 0.45)
			mb.radius = maxf(mb.radius, 1900.0)
			mb.capture_radius = mb.radius * 14.0
			var lo := b.radius * (2.7 if kind == BodyDef.Kind.GAS_GIANT else 5.0)
			var a := lo * (1.0 + 0.55 * m) + mb.capture_radius * 0.4 + m * 40000.0
			a = minf(a, b.capture_radius * 0.82)
			_set_orbit(mb, a, rng.randf_range(160.0, 280.0), rng, 4.0)
	# ensure >= 5 bodies, >= 4 landable, >= 4 distinct biomes among landable
	_ensure_requirements(s, rng)
	# keep names unique/readable
	s.start_body = 0
	for b in s.bodies:
		if b.landable:
			s.start_body = b.index
			break
	s.arrival_body = s.start_body

func _pick_biome(rng: RandomNumberGenerator, zone: float, used: Array) -> String:
	var ids: Array = []
	var w: Array = []
	for id in BiomeDB.LANDABLE_IDS:
		var bio: Dictionary = BiomeDB.get_biome(id)
		var dz: float = absf(zone - float(bio["zone"]))
		var wt: float = float(bio["weight"]) * exp(-pow(dz / maxf(float(bio["zone_width"]), 0.05), 2.0))
		if id in used:
			wt *= 0.35
		ids.append(id)
		w.append(wt + 0.01)
	return ids[SeedUtil.pick_weighted(rng, w)]

func _pick_moon_biome(rng: RandomNumberGenerator, zone: float) -> String:
	var opts := ["barren", "barren", "frozen", "toxic", "exotic", "desert", "radioactive", "volcanic"]
	if zone > 0.7:
		opts = ["barren", "frozen", "frozen", "toxic", "exotic", "barren"]
	return opts[rng.randi() % opts.size()]

func _ensure_requirements(s: SystemDef, rng: RandomNumberGenerator) -> void:
	var guard := 0
	while s.landable_bodies().size() < 4 and guard < 8:
		guard += 1
		# add a moon to a random landable planet (or convert a gas giant's moon list)
		var cand: Array = []
		for b in s.bodies:
			if b.kind == BodyDef.Kind.PLANET:
				cand.append(b)
		if cand.is_empty():
			break
		var host: BodyDef = cand[rng.randi() % cand.size()]
		var mb := _make_body(s, BodyDef.Kind.MOON, host.index, _pick_moon_biome(rng, 0.5), "%s x%d" % [host.name, guard], rng)
		mb.radius = clampf(mb.radius, 1900.0, host.radius * 0.45)
		mb.capture_radius = mb.radius * 14.0
		_set_orbit(mb, minf(host.radius * (5.5 + guard), host.capture_radius * 0.8), rng.randf_range(160.0, 280.0), rng, 4.0)
	while s.bodies.size() < 5 and guard < 16:
		guard += 1
		var host2: BodyDef = s.bodies[0]
		var mb2 := _make_body(s, BodyDef.Kind.MOON, host2.index, _pick_moon_biome(rng, 0.5), "%s y%d" % [host2.name, guard], rng)
		mb2.radius = clampf(mb2.radius, 1900.0, host2.radius * 0.45)
		mb2.capture_radius = mb2.radius * 14.0
		_set_orbit(mb2, minf(host2.radius * (5.5 + guard), host2.capture_radius * 0.8), rng.randf_range(160.0, 280.0), rng, 4.0)
	# distinct biomes
	var guard2 := 0
	while s.biome_set().size() < 4 and guard2 < 12:
		guard2 += 1
		var counts: Dictionary = {}
		for b in s.bodies:
			if b.landable:
				counts[b.biome] = counts.get(b.biome, 0) + 1
		var victim: BodyDef = null
		for b in s.bodies:
			if b.landable and counts[b.biome] > 1 and b.kind != BodyDef.Kind.GAS_GIANT:
				victim = b
		if victim == null:
			break
		var unused: Array = []
		for id in BiomeDB.LANDABLE_IDS:
			if not (id in s.biome_set()):
				unused.append(id)
		if unused.is_empty():
			break
		var nb: String = unused[rng.randi() % unused.size()]
		_rebiome(victim, nb, rng)

func _rebiome(b: BodyDef, biome: String, rng: RandomNumberGenerator) -> void:
	var bio: Dictionary = BiomeDB.get_biome(biome)
	b.biome = biome
	b.radius = clampf(rng.randf_range(bio["radius"][0], bio["radius"][1]), 1900.0, 1.0e9)
	b.gravity = rng.randf_range(bio["gravity"][0], bio["gravity"][1])
	b.has_atmosphere = rng.randf() < bio["atmo_chance"]
	b.atmo_height = clampf(b.radius * bio["atmo_frac"], 2500.0, 6000.0) if b.has_atmosphere else 0.0
	b.ocean_kind = bio["ocean"] if rng.randf() < bio["ocean_chance"] else ""
	b.has_ocean = b.ocean_kind != ""
	b.temp_day_c = rng.randf_range(bio["temp_day"][0], bio["temp_day"][1])
	b.temp_night_c = rng.randf_range(bio["temp_night"][0], bio["temp_night"][1])
	b.toxicity = bio["toxic"]
	b.radiation = bio["radiation"]
	b.capture_radius = b.radius * 14.0
	if b.parent >= 0:
		# moons keep their orbit; shrink radius if it would exceed the host constraint
		b.radius = minf(b.radius, 4500.0)
		b.capture_radius = b.radius * 14.0

func _finalize_system(s: SystemDef, gs: GalaxyStar, rng: RandomNumberGenerator) -> void:
	# black hole
	if gs.has_black_hole:
		var bh := BodyDef.new()
		bh.index = s.bodies.size()
		bh.system_id = s.id
		bh.kind = BodyDef.Kind.BLACK_HOLE
		bh.biome = "blackhole"
		bh.name = "Charon's Gate" if s.id == HOME_ID else ("Return Gate" if s.id == SECOND_ID else (gs.name + " Singularity"))
		bh.seed = SeedUtil.hash2(s.seed, 90210)
		bh.radius = BlackHoleParams.RS
		bh.bh_mu = BlackHoleParams.MU
		bh.bh_disc_inner = BlackHoleParams.DISC_INNER
		bh.bh_disc_outer = BlackHoleParams.DISC_OUTER
		bh.bh_influence = BlackHoleParams.INFLUENCE
		bh.bh_dest_system = black_hole_destination(s.id)
		bh.landable = false
		bh.gravity = 0.0
		bh.capture_radius = 0.0
		bh.orbit_radius = 0.0
		# place in the widest gap between planet orbits, off the orbital plane so no planet ever passes through it
		var orbits: Array = []
		for b in s.bodies:
			if b.parent == -1:
				orbits.append(b.orbit_radius)
		orbits.sort()
		var best_gap := 0.0
		var d_bh: float = float(orbits[orbits.size() - 1]) * 1.35
		for i in range(1, orbits.size()):
			var g: float = orbits[i] - orbits[i - 1]
			if g > best_gap:
				best_gap = g
				d_bh = sqrt(orbits[i] * orbits[i - 1])
		var ref_phase: float = s.bodies[s.start_body].orbit_phase
		var ang: float = ref_phase + 0.6 + rng.randf() * 0.4
		var h := (600000.0 + rng.randf() * 200000.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		bh.fixed_pos = Vector3(d_bh * cos(ang), h, d_bh * sin(ang))
		s.bodies.append(bh)
		s.black_hole_index = bh.index

## ---------------------------------------------------------------------------------------------------------------------
## Celestial mechanics (absolute system coordinates, doubles)
## ---------------------------------------------------------------------------------------------------------------------
func body_pos(i: int, t: float = -1.0) -> DVec:
	if t < 0.0:
		t = time
	var d: BodyDef = system.bodies[i]
	if d.kind == BodyDef.Kind.BLACK_HOLE:
		return DVec.from_v3(d.fixed_pos)
	var ang := d.orbit_phase + TAU * fposmod(t / d.orbit_period, 1.0)
	var c := cos(ang) * d.orbit_radius
	var sn := sin(ang) * d.orbit_radius
	var rel := DVec.new(c * d.orbit_u.x + sn * d.orbit_v.x, c * d.orbit_u.y + sn * d.orbit_v.y, c * d.orbit_u.z + sn * d.orbit_v.z)
	if d.parent >= 0:
		return body_pos(d.parent, t).add(rel)
	return rel

## absolute velocity (m/s) of body i
func body_velocity(i: int, t: float = -1.0) -> Vector3:
	if t < 0.0:
		t = time
	var d: BodyDef = system.bodies[i]
	if d.kind == BodyDef.Kind.BLACK_HOLE:
		return Vector3.ZERO
	var w := TAU / d.orbit_period
	var ang := d.orbit_phase + TAU * fposmod(t / d.orbit_period, 1.0)
	var sp := w * d.orbit_radius
	var v := (-sin(ang) * d.orbit_u + cos(ang) * d.orbit_v) * sp
	if d.parent >= 0:
		v += body_velocity(d.parent, t)
	return v

## orientation of body i's local frame (pole = +Y, tilted, spun) in absolute (non-rotating) system space
func body_basis(i: int, t: float = -1.0) -> Basis:
	if t < 0.0:
		t = time
	var d: BodyDef = system.bodies[i]
	if d.kind == BodyDef.Kind.BLACK_HOLE:
		return Basis.IDENTITY
	var ang := fposmod(d.spin_phase + TAU * fposmod(t / d.spin_period, 1.0), TAU)
	return d.rest_basis() * Basis(Vector3.UP, ang)

## unit direction from body i towards the star, in body-local coordinates at time t (what the "sun" direction is for a planet-fixed observer)
func sun_dir_body_local(i: int, t: float = -1.0) -> Vector3:
	var p := body_pos(i, t)
	var to_star := Vector3(-p.x, -p.y, -p.z).normalized()
	return (body_basis(i, t).inverse() * to_star).normalized()

## Find a universe time t >= after_t at which the sun stands at `elev_deg` above the horizon at planet-local direction `dir`,
## on the rising side (morning) if rising==true. Used to start the game at dawn. Scans one day.
func time_for_sun_elevation(i: int, dir: Vector3, elev_deg: float, after_t: float, rising: bool = true) -> float:
	var d: BodyDef = system.bodies[i]
	var target := sin(deg_to_rad(elev_deg))
	var steps := 360
	var dt := d.spin_period / float(steps)
	var prev := 0.0
	var best_t := after_t
	for k in steps + 1:
		var t := after_t + dt * float(k)
		var e := sun_dir_body_local(i, t).dot(dir.normalized())
		if k > 0:
			var crossed := (prev - target) * (e - target) <= 0.0
			var going_up := e > prev
			if crossed and going_up == rising:
				# linear refine
				var f := 0.0 if absf(e - prev) < 1e-9 else (target - prev) / (e - prev)
				return after_t + dt * (float(k - 1) + clampf(f, 0.0, 1.0))
		prev = e
		best_t = t
	return best_t

func nearest_body(p: DVec, only_landable: bool = false) -> int:
	var best := -1
	var bd := INF
	for b in system.bodies:
		if only_landable and not b.landable:
			continue
		var d := body_pos(b.index).distance_to(p)
		if d < bd:
			bd = d
			best = b.index
	return best

## arrival point for hyperdrive jumps: outside the capture radius of the arrival body, on the star-facing side
func hyperdrive_arrival() -> DVec:
	var bi := system.arrival_body
	var bp := body_pos(bi)
	var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
	var dist: float = system.bodies[bi].capture_radius * 2.2
	return bp.add_v3(to_star * dist)
