class_name Outposts
extends RefCounted
## Builds the structures of an outpost site (landing pad base, beacon, crash site, monolith) from the Blender models.
## Local frame of the returned node: Y = planet up at the site, origin on the flattened ground.

static func build(planet: Planet, o: Dictionary, idx: int) -> Node3D:
	var root := Node3D.new()
	var dir: Vector3 = o["dir"]
	var kind: String = String(o["kind"])
	var rng := U.rng(int(o["seed"]))
	var yaw: float = rng.randf() * TAU
	var fwd: Vector3 = U.any_perp(dir).rotated(dir, yaw)
	var bas: Basis = U.basis_from_up(dir, fwd)
	root.transform = Transform3D(bas, dir * (planet.data.radius + float(o["flat_h"])))
	root.name = "Outpost_%d_%s" % [idx, kind]
	var tints: Dictionary = planet.data.profile.get("tint", {})
	match kind:
		"base":
			_add(root, "landing_pad", Vector3(0, 0.12, 0), 0.0, planet)
			_add(root, "outpost_hab", Vector3(24, 0, -6), deg_to_rad(90.0 + 20.0), planet)
			_add(root, "outpost_tower", Vector3(-21, 0, -15), deg_to_rad(30.0), planet)
			_add(root, "outpost_container", Vector3(17, 0, 19), deg_to_rad(20.0), planet)
			_add(root, "outpost_container_b", Vector3(-13, 0, 22), deg_to_rad(-15.0), planet)
			_add(root, "outpost_solar", Vector3(-27, 0, 7), deg_to_rad(90.0), planet)
			_add(root, "outpost_tank", Vector3(4, 0, -29), deg_to_rad(0.0), planet)
			_add_crate(root, Vector3(13, 0, -2), rng.randf() * TAU, planet, "supplies")
			_add_crate(root, Vector3(-10, 0, 10), rng.randf() * TAU, planet, "supplies")
			_add_crate(root, Vector3(11, 0, 8), rng.randf() * TAU, planet, "supplies")
			root.set_meta("pad", true)
		"beacon":
			_add(root, "beacon_pylon", Vector3(0, 0, 0), 0.0, planet)
			_add_crate(root, Vector3(5, 0, 3), rng.randf() * TAU, planet, "supplies")
			_add_crate(root, Vector3(-4, 0, 5), rng.randf() * TAU, planet, "supplies")
		"crash":
			_add(root, "wreck_ship", Vector3(0, 0, 0), rng.randf() * TAU, planet)
			_add_crate(root, Vector3(9, 0, 4), rng.randf() * TAU, planet, "salvage")
			_add_crate(root, Vector3(-8, 0, 7), rng.randf() * TAU, planet, "salvage")
			_add_crate(root, Vector3(4, 0, -9), rng.randf() * TAU, planet, "salvage")
		"monolith":
			_add(root, "monolith", Vector3(0, 0, 0), 0.0, planet)
			root.set_meta("monolith", true)
	root.set_meta("kind", kind)
	return root

static func _add(root: Node3D, model: String, pos: Vector3, yaw: float, planet: Planet) -> Node3D:
	var n: Node3D = Models.instantiate(model)
	n.position = pos
	n.rotation.y = yaw
	root.add_child(n)
	_set_layers(n, planet.layer_bit)
	_collide(n, model)
	return n

static func _set_layers(n: Node, bit: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = bit
	for c in n.get_children():
		_set_layers(c, bit)

static func _collide(n: Node3D, model: String) -> void:
	var hint: Dictionary = Models.collision_hint(model)
	var shp: String = String(hint.get("shape", "none"))
	if shp == "none":
		return
	var off: Array = hint.get("offset", [0, 0, 0])
	var sb := StaticBody3D.new()
	sb.collision_layer = 2
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	match shp:
		"cylinder":
			var s := CylinderShape3D.new()
			s.radius = float(hint["radius"])
			s.height = float(hint["height"])
			cs.shape = s
		"sphere":
			var s2 := SphereShape3D.new()
			s2.radius = float(hint["radius"])
			cs.shape = s2
		"capsule":
			var s3 := CapsuleShape3D.new()
			s3.radius = float(hint["radius"])
			s3.height = float(hint["height"])
			cs.shape = s3
		"box":
			var sz: Array = hint["size"]
			var s4 := BoxShape3D.new()
			s4.size = Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
			cs.shape = s4
		_:
			return
	cs.position = Vector3(float(off[0]), float(off[1]), float(off[2]))
	sb.add_child(cs)
	n.add_child(sb)

static func _add_crate(root: Node3D, pos: Vector3, yaw: float, planet: Planet, loot: String) -> void:
	var n: Node3D = _add(root, "crate_supply", pos, yaw, planet)
	n.add_to_group("interact")
	n.set_meta("interact_type", "crate")
	n.set_meta("loot", loot)
	n.set_meta("prompt", "Open supply crate")
