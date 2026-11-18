class_name PoiSites
extends RefCounted
## Points of interest per planet, deterministic from the body seed (module M7a owns this file; M1's terrain reads it to flatten the ground).
## for_body(def) -> Array of Dictionary:
##   dir: Vector3 (unit, planet space)  radius: float (metres of flat ground around it)  kind: String  name: String  seed: int  flat: bool
##   extra keys (consumers may ignore them): model: String (ModelLib id)  yaw: float (forward bearing in the ScatterGrid.tangents(dir) frame)
##                                           group: int (settlement id, -1 none)  foot: float (clear-of-vegetation radius, m)  scale: float
## kinds: "landing_pad" | "outpost" | "tower" | "beacon" | "wreck" | "container" | "ruin" | "depot" | "solar" | "pod"
##   outpost = habitat (hab_a / hab_b), tower = comm tower, beacon = ancient monolith, wreck = crashed ship, container = supply crate,
##   ruin = ancient stones / arch, depot = wind turbine field, solar = solar array, pod = drop pod crate.
## Index 0 is ALWAYS the start landing pad (flat radius 32 m). Thread-safe (terrain workers call this).

const PAD_RADIUS := 32.0

static var _cache: Dictionary = {}
static var _mutex: Mutex = Mutex.new()
## poi seeds whose map markers were revealed by terminals / monoliths / towers (cleared when a game starts, see ScatterManager)
static var revealed: Dictionary = {}

static func for_body(def: BodyDef) -> Array:
	if def == null or not def.landable:
		return []
	_mutex.lock()
	var hit: Variant = _cache.get(def.seed)
	if hit != null:
		_mutex.unlock()
		return hit
	var out: Array = _generate(def)
	_cache[def.seed] = out
	_mutex.unlock()
	return out

## unit direction (planet space) of the landing pad where the game starts / the ship is first placed
static func start_dir(def: BodyDef) -> Vector3:
	var sites := for_body(def)
	if sites.is_empty():
		return Vector3.UP
	return sites[0]["dir"]

static func is_revealed(poi: Dictionary) -> bool:
	return revealed.has(int(poi["seed"]))

static func reveal(poi: Dictionary) -> void:
	revealed[int(poi["seed"])] = true

static func clear_revealed() -> void:
	revealed.clear()

# ---------------------------------------------------------------------------------------------------------------------
static func _add(out: Array, kind: String, d: Vector3, radius: float, flat: bool, pname: String, model: String, yaw: float, group: int, sd: int, foot: float = -1.0) -> void:
	out.append({
		"dir": d, "radius": radius, "kind": kind, "name": pname, "seed": sd, "flat": flat,
		"model": model, "yaw": yaw, "group": group, "foot": foot if foot > 0.0 else radius, "scale": 1.0,
	})

static func _generate(def: BodyDef) -> Array:
	var out: Array = []
	var R := def.radius
	var sd := def.seed
	var rng := SeedUtil.rng(sd, 515)
	var small := R < 3600.0
	var start := _pick_dir(sd, 7001)
	_add(out, "landing_pad", start, PAD_RADIUS, true, "%s Landing Pad" % def.name, "landing_pad_a", 0.0, -1, SeedUtil.hash2(sd, 1), 22.0)
	var gid := 0
	# --- settlements: 1 close to the start (a visible first target), then mid / far ones ------------------------------------------
	var settle_dists: Array = [rng.randf_range(150.0, 230.0), rng.randf_range(900.0, 1700.0), rng.randf_range(2200.0, 4200.0)]
	var n_settle := 3 if small else 4
	for k in n_settle:
		var c: Vector3
		if k < settle_dists.size():
			c = ScatterGrid.walk(start, rng.randf() * TAU, float(settle_dists[k]), R)
		else:
			c = _pick_far(out, sd, 7200 + k, R, 1100.0)
		_settlement(out, def, c, gid, rng, k == 0)
		gid += 1
	# --- ancient monoliths: one in sight of the start, one further away ------------------------------------------------------------
	var bd := ScatterGrid.walk(start, rng.randf() * TAU, rng.randf_range(330.0, 520.0), R)
	_add(out, "beacon", bd, 13.0, true, "Ancient Monolith", "beacon_monolith_a", rng.randf() * TAU, -1, SeedUtil.hash2(sd, 300), 11.0)
	for k in (1 if small else 2):
		var bd2 := _pick_far(out, sd, 7300 + k, R, 900.0)
		_add(out, "beacon", bd2, 13.0, true, "Ancient Monolith", "beacon_monolith_a", rng.randf() * TAU, -1, SeedUtil.hash2(sd, 301 + k), 11.0)
	# --- wrecks / ruins ---------------------------------------------------------------------------------------------------------
	for k in 2:
		var wd := _pick_far(out, sd, 7400 + k, R, 700.0) if k > 0 else ScatterGrid.walk(start, rng.randf() * TAU, rng.randf_range(600.0, 1100.0), R)
		_add(out, "wreck", wd, 14.0, true, "Crashed Ship", "crashed_ship_a", rng.randf() * TAU, -1, SeedUtil.hash2(sd, 400 + k), 12.0)
	for k in 2:
		var rd := _pick_far(out, sd, 7500 + k, R, 800.0)
		_add(out, "ruin", rd, 15.0, true, "Ancient Ruins", "", rng.randf() * TAU, -1, SeedUtil.hash2(sd, 500 + k), 14.0)
	# --- loose supply containers (not flattened, simply sit on the ground) -------------------------------------------------------
	var n_cont := 7
	for k in n_cont:
		var cd: Vector3
		if k < 2:
			cd = ScatterGrid.walk(start, rng.randf() * TAU, rng.randf_range(60.0, 140.0), R)
		else:
			cd = _pick_far(out, sd, 7600 + k, R, 250.0)
		_add(out, "container", cd, 4.0, false, "Supply Cache", "supply_container_a", rng.randf() * TAU, -1, SeedUtil.hash2(sd, 600 + k), 3.5)
	return out

static func _settlement(out: Array, def: BodyDef, c: Vector3, gid: int, rng: RandomNumberGenerator, near_start: bool) -> void:
	var R := def.radius
	var sd := def.seed
	var nm := SeedUtil.make_name(SeedUtil.hash2(sd, 900 + gid))
	var base := SeedUtil.hash2(sd, 800 + gid * 16)
	var hab_b := rng.randf() < 0.45
	var model := "outpost_hab_b" if hab_b else "outpost_hab_a"
	var rad := 24.0 if hab_b else 18.0
	var yaw0 := rng.randf() * TAU
	_add(out, "outpost", c, rad, true, "Outpost %s" % nm, model, yaw0, gid, SeedUtil.hash2(base, 1), rad * 0.9)
	var items: Array = []
	if near_start or rng.randf() < 0.65:
		items.append("tower")
	if rng.randf() < 0.6:
		items.append("solar")
	if rng.randf() < 0.55:
		items.append("depot")
	var ang0 := rng.randf() * TAU
	var m := items.size() + 2
	for k in items.size():
		var ang := ang0 + TAU * float(k) / float(m)
		var kind: String = items[k]
		var dist := 38.0 + rng.randf() * 10.0 + (8.0 if hab_b else 0.0)
		var d2 := ScatterGrid.walk(c, ang, dist, R)
		var mdl := ""
		var rr := 14.0
		var pname := ""
		match kind:
			"tower":
				mdl = "outpost_tower_a"
				rr = 14.0
				pname = "Comm Tower"
			"solar":
				mdl = "solar_array_a"
				rr = 17.0
				pname = "Solar Array"
			_:
				mdl = "wind_turbine_a"
				rr = 11.0
				pname = "Wind Turbine"
		# face towards the settlement centre
		var yaw := _bearing_to(d2, c) + rng.randf_range(-0.3, 0.3)
		_add(out, kind, d2, rr, true, pname, mdl, yaw, gid, SeedUtil.hash2(base, 2 + k), rr * 0.9)
	# a couple of crates beside the main building
	for k in 2:
		var d3 := ScatterGrid.walk(c, ang0 + TAU * (float(items.size()) + 0.5 + float(k)) / float(m), 14.0 + float(k) * 3.0, R)
		_add(out, "container", d3, 4.0, false, "Supply Cache", "supply_container_a", rng.randf() * TAU, gid, SeedUtil.hash2(base, 50 + k), 3.5)

## bearing (in the tangent frame of `from`) pointing from `from` to `to`
static func _bearing_to(from: Vector3, to: Vector3) -> float:
	var t := ScatterGrid.tangents(from)
	var dv := to - from * to.dot(from)
	return atan2(dv.dot(t[1]), dv.dot(t[0]))

## a direction at least `min_sep` m from every existing site (best effort), away from the poles
static func _pick_far(sites: Array, sd: int, salt: int, R: float, min_sep: float) -> Vector3:
	var best := Vector3.RIGHT
	var best_score := -1.0
	for k in 24:
		var d := SeedUtil.rand_dir(sd, salt * 64 + k)
		if absf(d.y) > 0.78:
			continue
		var nearest := INF
		for s in sites:
			nearest = minf(nearest, ScatterGrid.ground_dist(d, s["dir"], R))
		if nearest >= min_sep:
			return d
		if nearest > best_score:
			best_score = nearest
			best = d
	return best

static func _pick_dir(seed_value: int, salt: int) -> Vector3:
	for k in 16:
		var d := SeedUtil.rand_dir(seed_value, salt + k * 31)
		if absf(d.y) < 0.75:   # keep away from the poles
			return d
	return Vector3(1, 0, 0)
