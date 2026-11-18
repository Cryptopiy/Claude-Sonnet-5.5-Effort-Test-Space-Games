extends Node
## FRAME: the local reference frame that all rendering + physics happen in (the answer to float32 precision at planetary/interplanetary scale).
##
## Absolute positions (DVec, doubles) live in "system space" (star at the origin, non-rotating, metres).
## Everything you see/collide with lives in LOCAL coordinates (Vector3) defined by:   local = basis * (abs - origin)
##   * SPACE frame (anchor == -1): basis = identity, origin = a floating point in space that is re-centred on the focus (ship) whenever it
##     drifts REBASE_DISTANCE away, so the ship is always within ~2 km of local (0,0,0).  Planets/star are placed at (their abs - origin).
##   * BODY frame (anchor == i): entered automatically when the focus comes inside body i's capture_radius. origin = the planet centre,
##     basis = inverse of the planet's spin, so the PLANET IS FIXED at local (0,0,0) with no rotation: terrain, props, colliders, ship and
##     player all live in planet coordinates (max ~15 km -> millimetre precision), the sun/stars/other bodies sweep across the sky instead.
##     Moons have their own nested frame (deepest capture sphere wins).
## Switching frames converts every node in group "frame_objects" (ship, player, drops, ...) with one rigid transform, so nothing visibly pops.
## Velocity continuity: objects may implement `_on_frame_shift(rot: Basis, shift: Vector3, vel_offset: Vector3)` and must set
##   `velocity = rot * velocity + vel_offset` (their transform is already updated). Velocities are local-frame velocities; the planet's orbital
##   velocity is subtracted/added on capture/release (vel_offset), the rotating-frame (w x r) term is deliberately ignored (arcade).
##
## This node runs LAST each frame (process_priority 100): all gameplay moves things first, then Frame advances universe time, switches
## frames / rebases, and finally repositions every celestial body node + the sun. Nothing else may move bodies.

signal frame_changed(old_anchor: int, new_anchor: int)
signal origin_shifted(shift: Vector3)

const REBASE_DISTANCE := 2000.0
const CAPTURE_HYSTERESIS := 1.12
const STAR_MAX_DIST := 1.5e6          # the star is drawn at most this far from the camera (moved closer + uniformly scaled, same angular size) so it is always inside the far plane

var anchor: int = -1
var origin: DVec = DVec.new()
var basis: Basis = Basis.IDENTITY
var origin_vel: Vector3 = Vector3.ZERO     # absolute velocity of the frame origin (anchor body's orbital velocity)
var focus: Node3D = null                   # the node whose position drives capture/release/rebase (ship, player or debug cam). Set via Frame.set_focus()
var sun_dir: Vector3 = Vector3.UP          # unit vector from the focus towards the star, LOCAL coordinates
var star_local: Vector3 = Vector3.ZERO     # local position of the star
var frozen: bool = false                   # Game sets true while paused-in-menu etc.
var _space_objects: Array = []             # [{node, pos_fn, basis_fn}] extra things placed at absolute positions (stations, asteroids...)

func _ready() -> void:
	process_priority = 100
	process_physics_priority = 100

# ---------------------------------------------------------------------------------------------------------------------
# conversions
# ---------------------------------------------------------------------------------------------------------------------
func to_local(p: DVec) -> Vector3:
	return basis * origin.offset_to_v3(p)

func to_abs(v: Vector3) -> DVec:
	return origin.add_v3(basis.inverse() * v)

func abs_dir_to_local(d: Vector3) -> Vector3:
	return basis * d

func local_dir_to_abs(d: Vector3) -> Vector3:
	return basis.inverse() * d

func is_space() -> bool:
	return anchor < 0

func anchor_def() -> BodyDef:
	if anchor < 0 or Universe.system == null:
		return null
	return Universe.system.bodies[anchor]

func anchor_node() -> Node3D:
	if anchor < 0 or anchor >= Universe.body_nodes.size():
		return null
	return Universe.body_nodes[anchor]

func set_focus(n: Node3D) -> void:
	focus = n

func register_object(n: Node3D) -> void:
	n.add_to_group("frame_objects")

## Register a node (child of the System node or any Node3D with identity parent transform) whose ABSOLUTE position is pos_fn(t) -> DVec
## (and optional orientation basis_fn(t) -> Basis in absolute space). Frame converts it to local coordinates every frame.
func register_space_object(node: Node3D, pos_fn: Callable, basis_fn: Callable = Callable()) -> void:
	_space_objects.append({"node": node, "pos_fn": pos_fn, "basis_fn": basis_fn})

func clear_space_objects() -> void:
	_space_objects.clear()

# ---------------------------------------------------------------------------------------------------------------------
# hard placement (no conversion of objects): used when (re)building the world or teleporting. The caller then positions objects
# in the new local coordinates.
# ---------------------------------------------------------------------------------------------------------------------
func set_space_frame(abs_origin: DVec) -> void:
	var old := anchor
	anchor = -1
	origin = abs_origin.copy()
	basis = Basis.IDENTITY
	origin_vel = Vector3.ZERO
	if old != -1:
		frame_changed.emit(old, -1)
	_update_nodes(Universe.time)

func set_body_frame(body_index: int) -> void:
	var old := anchor
	anchor = body_index
	_refresh_anchor_frame(Universe.time)
	if old != anchor:
		frame_changed.emit(old, anchor)
	_update_nodes(Universe.time)

# ---------------------------------------------------------------------------------------------------------------------
# per-frame update
# ---------------------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if Universe.system == null or frozen:
		return
	var dt := minf(delta, 0.1)
	Universe.time += dt
	var t := Universe.time
	if anchor >= 0:
		_refresh_anchor_frame(t)
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		var fl := focus.global_position
		var fa := to_abs(fl)
		var want := _desired_anchor(fa, t)
		if want != anchor:
			_switch_to(want, fa, t)
		elif anchor == -1 and fl.length() > REBASE_DISTANCE:
			_rebase(fl)
	_update_nodes(t)

func _refresh_anchor_frame(t: float) -> void:
	origin = Universe.body_pos(anchor, t)
	basis = Universe.body_basis(anchor, t).inverse()
	origin_vel = Universe.body_velocity(anchor, t)

## which body frame (or -1 = space) an absolute position belongs to
func desired_anchor(fa: DVec) -> int:
	return _desired_anchor(fa, Universe.time)

func _desired_anchor(fa: DVec, t: float) -> int:
	var best := -1
	var best_depth := -1
	var best_d := INF
	for b in Universe.system.bodies:
		if b.capture_radius <= 0.0:
			continue
		var r: float = b.capture_radius * (CAPTURE_HYSTERESIS if b.index == anchor else 1.0)
		var d := Universe.body_pos(b.index, t).distance_to(fa)
		if d < r:
			var depth := 0 if b.parent < 0 else 1
			if depth > best_depth or (depth == best_depth and d < best_d):
				best = b.index
				best_depth = depth
				best_d = d
	return best

func _switch_to(new_anchor: int, fa: DVec, t: float) -> void:
	var old_anchor := anchor
	var old_origin := origin
	var old_basis := basis
	var old_vel := origin_vel
	var new_origin: DVec
	var new_basis: Basis
	var new_vel: Vector3
	if new_anchor >= 0:
		new_origin = Universe.body_pos(new_anchor, t)
		new_basis = Universe.body_basis(new_anchor, t).inverse()
		new_vel = Universe.body_velocity(new_anchor, t)
	else:
		new_origin = fa.copy()
		new_basis = Basis.IDENTITY
		new_vel = Vector3.ZERO
	var rot := new_basis * old_basis.inverse()
	var shift := new_basis * new_origin.offset_to_v3(old_origin)
	var vel_offset := new_basis * (old_vel - new_vel)
	var xf := Transform3D(rot, shift)
	for n in get_tree().get_nodes_in_group("frame_objects"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		n3.global_transform = xf * n3.global_transform
		if n3.has_method("_on_frame_shift"):
			n3.call("_on_frame_shift", rot, shift, vel_offset)
	anchor = new_anchor
	origin = new_origin
	basis = new_basis
	origin_vel = new_vel
	frame_changed.emit(old_anchor, new_anchor)

func _rebase(fl: Vector3) -> void:
	origin = origin.add_v3(fl)
	for n in get_tree().get_nodes_in_group("frame_objects"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		n3.global_position -= fl
		if n3.has_method("_on_frame_shift"):
			n3.call("_on_frame_shift", Basis.IDENTITY, -fl, Vector3.ZERO)
	origin_shifted.emit(-fl)

func _update_nodes(t: float) -> void:
	var sys := Universe.system
	if sys == null:
		return
	var nodes := Universe.body_nodes
	for i in nodes.size():
		var n: Node3D = nodes[i]
		if n == null or not is_instance_valid(n):
			continue
		if i == anchor:
			n.transform = Transform3D.IDENTITY
		else:
			n.transform = Transform3D(basis * Universe.body_basis(i, t), to_local(Universe.body_pos(i, t)))
	var keep: Array = []
	for o in _space_objects:
		var sn: Node3D = o["node"]
		if sn == null or not is_instance_valid(sn):
			continue
		keep.append(o)
		var pa: DVec = (o["pos_fn"] as Callable).call(t)
		var bb := Basis.IDENTITY
		if (o["basis_fn"] as Callable).is_valid():
			bb = (o["basis_fn"] as Callable).call(t)
		sn.transform = Transform3D(basis * bb, to_local(pa))
	if keep.size() != _space_objects.size():
		_space_objects = keep
	star_local = to_local(DVec.new())
	if Universe.star_node != null and is_instance_valid(Universe.star_node):
		var sd := star_local.length()
		var ssc := 1.0
		var spos := star_local
		if sd > STAR_MAX_DIST:
			ssc = STAR_MAX_DIST / sd
			spos = star_local * ssc
		Universe.star_node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(ssc, ssc, ssc)), spos)
	var fpos := Vector3.ZERO
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		fpos = focus.global_position
	sun_dir = (star_local - fpos).normalized()
	RenderingServer.global_shader_parameter_set("sun_dir", sun_dir)
	RenderingServer.global_shader_parameter_set("sky_basis", basis)
