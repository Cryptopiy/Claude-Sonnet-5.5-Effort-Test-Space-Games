class_name SystemExtras
extends Node3D
## SYSTEM EXTRAS (module m7b_life).  Built by StarSystem.build(): the things that make a system feel inhabited when you fly through it.
##   * orbital station (station_orbital) circling the start planet, ring spinning, blinking beacon
##   * a freighter in a retrograde orbit around the start planet + a lane freighter shuttling between the start planet and its neighbour (engines throttle with speed)
##   * comms satellites (satellite_a) orbiting landable worlds / gas giants, nadir-pointing, blinking
##   * asteroid belt in a gap between planet orbits, ring-debris fields inside the rings of gas giants, a trojan cluster trailing the start planet
## Everything is placed by Frame.register_space_object (absolute double-precision positions) and is deterministic from sys.seed.
## Each object carries a distance glint (see extras/glint.gdshader) so it is noticeable as a bright point from far away.
## Public API:  build(sys), station: Node3D, freighters: Array[Node3D], satellites: Array[Node3D], fields: Array[AsteroidField]  (nodes are in groups "extra_station" / "extra_freighter" /
##              "extra_satellite", meta "label"); nearest_object(pos_local) -> Node3D.

const GLINT_SHADER := "res://world/content/extras/glint.gdshader"
const GM_GAS := 3.0e9

var sys: SystemDef
var station: Node3D
var freighters: Array = []
var satellites: Array = []
var fields: Array = []
var _anims: Array = []
var _t: float = 0.0
var _glint_shader: Shader

func build(p_sys: SystemDef) -> void:
	sys = p_sys
	process_priority = 50
	_glint_shader = load(GLINT_SHADER)
	var rng := SeedUtil.rng(sys.seed, 8801)
	var start: BodyDef = sys.bodies[sys.start_body]
	_build_station(start, rng)
	_build_freighters(start, rng)
	_build_satellites(start, rng)
	_build_fields(start, rng)

func nearest_object(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for g in ["extra_station", "extra_freighter", "extra_satellite"]:
		for n in get_tree().get_nodes_in_group(g):
			var d := (n as Node3D).global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = n
	return best

# =====================================================================================================================
# orbit maths
# =====================================================================================================================
static func gm_of(b: BodyDef) -> float:
	if b.gravity > 0.0:
		return b.gravity * b.radius * b.radius
	return GM_GAS

static func make_orbit(center: int, r: float, incl: float, node_ang: float, phase: float, omega: float) -> Dictionary:
	var u := Vector3(cos(node_ang), 0.0, sin(node_ang))
	var n := Vector3.UP.rotated(u, incl)
	var v := n.cross(u).normalized()
	return {"c": center, "r": r, "u": u, "v": v, "n": n, "ph": phase, "w": omega}

static func orbit_pos(o: Dictionary, t: float) -> DVec:
	var a: float = float(o["ph"]) + float(o["w"]) * t
	var r: float = o["r"]
	var off: Vector3 = (o["u"] as Vector3) * (cos(a) * r) + (o["v"] as Vector3) * (sin(a) * r)
	return Universe.body_pos(int(o["c"]), t).add_v3(off)

static func orbit_radial(o: Dictionary, t: float) -> Vector3:
	var a: float = float(o["ph"]) + float(o["w"]) * t
	return ((o["u"] as Vector3) * cos(a) + (o["v"] as Vector3) * sin(a)).normalized()

static func orbit_vel_dir(o: Dictionary, t: float) -> Vector3:
	var a: float = float(o["ph"]) + float(o["w"]) * t
	var sgn := signf(float(o["w"]))
	return (((o["v"] as Vector3) * cos(a) - (o["u"] as Vector3) * sin(a)) * sgn).normalized()

func _omega_for(b: BodyDef, r: float) -> float:
	return sqrt(gm_of(b) / (r * r * r))

# =====================================================================================================================
# station
# =====================================================================================================================
func _build_station(start: BodyDef, rng: RandomNumberGenerator) -> void:
	var r := start.radius + start.atmo_height + 7000.0
	var o := make_orbit(start.index, r, deg_to_rad(rng.randf_range(18.0, 40.0)), rng.randf() * TAU, rng.randf() * TAU, _omega_for(start, r))
	var holder := _make_holder("station_orbital", "Orbital station", Color(0.75, 0.9, 1.0), 260.0, 0.0075, 0.0, 1.0)
	holder.add_to_group("extra_station")
	station = holder
	# fixed inertial attitude: ring axis (model Z) tilted away from the orbit normal so the ring is seen at changing angles
	var axis := ((o["n"] as Vector3).rotated(o["u"], deg_to_rad(42.0))).normalized()
	var fixed := Basis.looking_at(-axis, Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT)
	Frame.register_space_object(holder, func(t: float) -> DVec: return orbit_pos(o, t), func(_t2: float) -> Basis: return fixed)
	var model: Node3D = holder.get_meta("model")
	_anims.append({"node": holder, "ring": ModelLib.find_node(model, "Ring"), "ring_w": 0.09, "blinks": _find_blinks(model), "rate": 0.8})

# =====================================================================================================================
# freighters
# =====================================================================================================================
func _build_freighters(start: BodyDef, rng: RandomNumberGenerator) -> void:
	# (1) retrograde orbit around the start planet
	var r := maxf(start.radius * 3.7, start.radius + start.atmo_height + 24000.0)
	var o := make_orbit(start.index, r, deg_to_rad(rng.randf_range(35.0, 62.0)), rng.randf() * TAU, rng.randf() * TAU, -_omega_for(start, r))
	var f1 := _make_holder("ship_freighter", "Freighter", Color(1.0, 0.82, 0.55), 170.0, 0.0065, 0.0, 1.0)
	f1.add_to_group("extra_freighter")
	freighters.append(f1)
	Frame.register_space_object(f1, func(t: float) -> DVec: return orbit_pos(o, t),
		func(t: float) -> Basis: return Basis.looking_at(orbit_vel_dir(o, t), o["n"]))
	_anims.append({"node": f1, "glows": _find_glows(f1.get_meta("model")), "thrust": 0.45, "blinks": _find_blinks(f1.get_meta("model")), "rate": 0.6})
	# (2) lane freighter between the start planet and the neighbouring planet orbit
	var other: BodyDef = null
	var bd := INF
	for b in sys.bodies:
		if b.index == start.index or b.parent >= 0 or b.kind == BodyDef.Kind.BLACK_HOLE:
			continue
		var d := absf(b.orbit_radius - start.orbit_radius)
		if d < bd:
			bd = d
			other = b
	if other == null:
		return
	var f2 := _make_holder("ship_freighter", "Freighter", Color(1.0, 0.82, 0.55), 170.0, 0.0065, 0.0, 1.0)
	f2.add_to_group("extra_freighter")
	freighters.append(f2)
	var off_a := start.capture_radius * 1.55
	var off_b := other.capture_radius * 1.55
	var t0 := Universe.START_TIME
	var len0 := Universe.body_pos(start.index, t0).distance_to(Universe.body_pos(other.index, t0))
	var period := clampf(PI * maxf(len0 - off_a - off_b, 50000.0) / 1300.0, 300.0, 1600.0)
	var ph0 := rng.randf()
	var lane := {"si": start.index, "oi": other.index, "off_a": off_a, "off_b": off_b, "period": period, "ph0": ph0}
	Frame.register_space_object(f2, func(t: float) -> DVec: return _lane_pos(lane, t), func(t: float) -> Basis: return _lane_basis(lane, t))
	_anims.append({"node": f2, "glows": _find_glows(f2.get_meta("model")), "lane": lane, "blinks": _find_blinks(f2.get_meta("model")), "rate": 0.5})

static func _lane_angle(lane: Dictionary, t: float) -> float:
	return TAU * (t / float(lane["period"]) + float(lane["ph0"]))

static func _lane_dir(lane: Dictionary, t: float) -> Vector3:
	var pa := Universe.body_pos(int(lane["si"]), t)
	var pb := Universe.body_pos(int(lane["oi"]), t)
	return Vector3(pb.x - pa.x, pb.y - pa.y, pb.z - pa.z).normalized()

static func _lane_pos(lane: Dictionary, t: float) -> DVec:
	var pa := Universe.body_pos(int(lane["si"]), t)
	var pb := Universe.body_pos(int(lane["oi"]), t)
	var dv := _lane_dir(lane, t)
	var a := pa.add_v3(dv * float(lane["off_a"]))
	var b := pb.sub_v3(dv * float(lane["off_b"]))
	return a.lerp_to(b, 0.5 - 0.5 * cos(_lane_angle(lane, t)))

static func _lane_basis(lane: Dictionary, t: float) -> Basis:
	var yaw := PI * (0.5 - 0.5 * clampf(sin(_lane_angle(lane, t)) * 6.0, -1.0, 1.0))
	return Basis(Vector3.UP, yaw) * Basis.looking_at(_lane_dir(lane, t), Vector3.UP)

static func _trail_pos(si: int, trail: float, t: float) -> DVec:
	var pa := Universe.body_pos(si, t)
	var vel := Universe.body_velocity(si, t).normalized()
	return pa.add_v3(-vel * trail)

# =====================================================================================================================
# satellites
# =====================================================================================================================
func _build_satellites(start: BodyDef, rng: RandomNumberGenerator) -> void:
	for b in sys.bodies:
		if b.kind == BodyDef.Kind.BLACK_HOLE:
			continue
		var n := 0
		if b.index == start.index:
			n = 2
		elif b.kind == BodyDef.Kind.GAS_GIANT:
			n = 1
		elif b.landable and SeedUtil.rand01(sys.seed, 900 + b.index) < 0.7:
			n = 1
		for k in n:
			var base_r: float = b.radius + b.atmo_height + 3500.0
			var r: float = base_r + b.radius * rng.randf_range(0.55, 1.6) + 6000.0 * float(k)
			if b.kind == BodyDef.Kind.GAS_GIANT:
				r = maxf(b.ring_outer * 1.25 if b.has_rings else b.radius * 2.4, b.radius * 2.6) + 4000.0 * float(k)
			var o := make_orbit(b.index, r, deg_to_rad(rng.randf_range(0.0, 75.0)), rng.randf() * TAU, rng.randf() * TAU, _omega_for(b, r) * (1.0 if rng.randf() < 0.75 else -1.0))
			var s := _make_holder("satellite_a", "Satellite", Color(0.6, 1.0, 0.75), 16.0, 0.0042, 1.0, 0.6)
			s.add_to_group("extra_satellite")
			satellites.append(s)
			Frame.register_space_object(s, func(t: float) -> DVec: return orbit_pos(o, t),
				func(t: float) -> Basis: return Basis.looking_at(-orbit_radial(o, t), o["n"]))
			_anims.append({"node": s, "blinks": _find_blinks(s.get_meta("model")), "rate": 0.55 + rng.randf() * 0.3, "off": rng.randf()})

# =====================================================================================================================
# asteroid fields
# =====================================================================================================================
func _build_fields(start: BodyDef, rng: RandomNumberGenerator) -> void:
	# belt in the widest planet-orbit gap that is not the black hole's (second widest), only if there are enough orbits
	var orbits: Array = []
	for b in sys.bodies:
		if b.parent < 0 and b.kind != BodyDef.Kind.BLACK_HOLE:
			orbits.append(b.orbit_radius)
	orbits.sort()
	if orbits.size() >= 3 and (sys.id == Universe.HOME_ID or SeedUtil.rand01(sys.seed, 4711) < 0.7):
		var gaps: Array = []
		for i in range(1, orbits.size()):
			gaps.append([float(orbits[i]) - float(orbits[i - 1]), i])
		gaps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var pick: Array = gaps[1] if (gaps.size() > 1 and sys.black_hole_index >= 0) else gaps[0]
		var i2: int = pick[1]
		var r0 := sqrt(float(orbits[i2]) * float(orbits[i2 - 1]))
		var w := minf(45000.0, float(pick[0]) * 0.12)
		var f := AsteroidField.new()
		f.setup("belt", sys.seed ^ 0xB317, func(_t: float) -> DVec: return DVec.new(), Basis.IDENTITY, {"r0": r0, "w": w, "h": w * 0.45})
		f.label = "Asteroid belt"
		_add_field(f)
	# ring debris inside the rings of every ringed gas giant
	for b in sys.bodies:
		if b.kind == BodyDef.Kind.GAS_GIANT and b.has_rings:
			var f2 := AsteroidField.new()
			var bi: int = b.index
			f2.setup("ring", SeedUtil.hash2(sys.seed, 5000 + bi), func(t: float) -> DVec: return Universe.body_pos(bi, t), b.rest_basis(),
				{"rin": b.ring_inner * 1.02, "rout": b.ring_outer * 0.98, "h": 350.0})
			f2.cell = 380.0
			f2.view_r = 5200.0
			f2.base_p = 0.40
			f2.scale_min = 0.07
			f2.scale_max = 0.55
			f2.label = "Ring debris"
			_add_field(f2)
	# trojan-style cluster trailing the start planet
	var f3 := AsteroidField.new()
	var si := start.index
	var trail := start.capture_radius * 1.6 + 30000.0
	f3.setup("cluster", sys.seed ^ 0x7120, func(t: float) -> DVec: return _trail_pos(si, trail, t), Basis.IDENTITY, {"rad": 4200.0})
	f3.base_p = 0.30
	f3.label = "Asteroid cluster"
	_add_field(f3)

func _add_field(f: AsteroidField) -> void:
	add_child(f)
	fields.append(f)
	Frame.register_space_object(f, f.anchor_pos_fn)

# =====================================================================================================================
# model holders, glints, animation
# =====================================================================================================================
func _make_holder(model_id: String, label: String, glint_col: Color, glint_size: float, glint_angle: float, blink: float, strength: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = label.validate_node_name() + "_" + str(get_child_count())
	var model := ModelLib.instantiate(model_id)
	holder.add_child(model)
	holder.set_meta("model", model)
	holder.set_meta("label", label)
	var q := MeshInstance3D.new()
	q.name = "Glint"
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	q.mesh = qm
	q.extra_cull_margin = 8000.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _glint_shader
	mat.set_shader_parameter("color", glint_col)
	mat.set_shader_parameter("world_size", glint_size)
	mat.set_shader_parameter("min_angle", glint_angle)
	mat.set_shader_parameter("blink", blink)
	mat.set_shader_parameter("blink_rate", 0.6)
	mat.set_shader_parameter("strength", strength)
	mat.render_priority = 40
	q.material_override = mat
	holder.add_child(q)
	add_child(holder)
	return holder

func _find_blinks(model: Node) -> Array:
	var out: Array = []
	for n in ["BlinkLight", "BlinkLight_2"]:
		var b := ModelLib.find_node(model, n)
		if b != null:
			out.append(b)
	return out

func _find_glows(model: Node) -> Array:
	var out: Array = []
	for i in 8:
		var g := ModelLib.find_node(model, "EngineGlow_%d" % i)
		if g != null:
			out.append(g)
	return out

func _process(dt: float) -> void:
	if sys == null:
		return
	_t += dt
	for a in _anims:
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			continue
		var ring: Node3D = a.get("ring")
		if ring != null:
			ring.rotation = Vector3(0.0, 0.0, _t * float(a["ring_w"]))
		var rate: float = float(a.get("rate", 0.7))
		var ph: float = float(a.get("off", 0.0))
		for b in (a["blinks"] as Array):
			(b as Node3D).visible = fposmod(_t * rate + ph, 1.0) < 0.14
		if a.has("glows"):
			var thrust: float = float(a.get("thrust", 0.5))
			if a.has("lane"):
				thrust = 0.2 + 0.8 * absf(sin(_lane_angle(a["lane"], Universe.time)))
			for g in (a["glows"] as Array):
				(g as Node3D).scale = Vector3(1.0, lerpf(0.25, 1.0, thrust), 1.0)
	var fd: DVec = null
	var f: Node3D = Frame.focus
	if f != null and is_instance_valid(f) and f.is_inside_tree():
		fd = Frame.to_abs(f.global_position)
	if fd != null:
		for fl in fields:
			(fl as AsteroidField).update(dt, fd, Universe.time)
