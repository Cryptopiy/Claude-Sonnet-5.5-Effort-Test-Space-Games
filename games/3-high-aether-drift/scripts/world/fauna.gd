class_name Fauna
extends Node3D
## Small wandering creatures (hoppers and floaters) that live near the player on planets with fauna.

const MAX_CREATURES := 9

var planet: PlanetBody
var creatures: Array = []
var _spawn_cd: float = 0.0
var rng := RandomNumberGenerator.new()


class Critter:
	extends RefCounted
	var node: Node3D
	var kind: String
	var dir: Vector3
	var heading: Vector3
	var speed: float = 0.0
	var timer: float = 0.0
	var phase: float = 0.0
	var hop: float = 0.0
	var legs: Array = []
	var tentacles: Array = []
	var height: float = 0.0


func setup(p: PlanetBody) -> void:
	planet = p
	rng.seed = p.data.seed + 99


func update_fauna(player_local: Vector3, dt: float) -> void:
	if planet == null or planet.data.fauna.is_empty():
		return
	var R := planet.data.radius
	var alt := player_local.length() - R
	if alt > 400.0:
		_clear()
		return
	var pdir := player_local.normalized()
	_spawn_cd -= dt
	if creatures.size() < MAX_CREATURES and _spawn_cd <= 0.0:
		_spawn_cd = 0.8
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(35.0, 110.0)
		var t1 := pdir.cross(Vector3.UP if absf(pdir.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := pdir.cross(t1)
		var d := (pdir + (t1 * cos(ang) + t2 * sin(ang)) * dist / R).normalized()
		var tp := planet.data.terrain
		var h := tp.ground(d)
		if tp.sea_level > -50000.0 and h <= tp.sea_level + 0.5 and rng.randf() < 0.9:
			pass
		else:
			_add(d)
	for c in creatures.duplicate():
		var cr: Critter = c
		_update_critter(cr, dt, pdir)
		var far := cr.dir.angle_to(pdir) * R > 170.0
		if far:
			cr.node.queue_free()
			creatures.erase(cr)


func _clear() -> void:
	for c in creatures:
		(c as Critter).node.queue_free()
	creatures.clear()


func _add(d: Vector3) -> void:
	var kind: String = planet.data.fauna[rng.randi() % planet.data.fauna.size()]
	var cr := Critter.new()
	cr.kind = kind
	cr.dir = d
	cr.phase = rng.randf() * 10.0
	cr.node = Assets.instance("creature_" + kind)
	if kind == "hopper":
		var tint := Color.from_hsv(rng.randf(), 0.45, 1.0)
		for mi in Assets.all_meshes(cr.node):
			var m := (mi as MeshInstance3D).mesh.surface_get_material(0)
			if m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled == false:
				var mm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				mm.albedo_color = mm.albedo_color * tint
				(mi as MeshInstance3D).set_surface_override_material(0, mm)
		for n in ["LegFL", "LegFR", "LegBL", "LegBR"]:
			var l := cr.node.find_child(n, true, false)
			if l:
				cr.legs.append(l)
		cr.node.scale = Vector3.ONE * rng.randf_range(0.9, 1.5)
	else:
		for i in 6:
			var t := cr.node.find_child("Tentacle%d" % i, true, false)
			if t:
				cr.tentacles.append(t)
		cr.node.scale = Vector3.ONE * rng.randf_range(0.9, 1.6)
		cr.height = rng.randf_range(4.0, 10.0)
	cr.heading = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized().rotated(d, rng.randf() * TAU)
	add_child(cr.node)
	creatures.append(cr)


func _update_critter(c: Critter, dt: float, player_dir: Vector3) -> void:
	var R := planet.data.radius
	var tp := planet.data.terrain
	c.timer -= dt
	c.phase += dt
	if c.timer <= 0.0:
		c.timer = rng.randf_range(2.0, 6.0)
		c.heading = c.heading.rotated(c.dir, rng.randf_range(-1.6, 1.6))
		c.speed = rng.randf_range(0.0, 3.2) if c.kind == "hopper" else rng.randf_range(0.5, 2.0)
	# flee when the player gets near
	var to_p := (player_dir - c.dir) * R
	var dist := to_p.length()
	if c.kind == "hopper" and dist < 14.0:
		c.heading = (-to_p).normalized()
		c.heading = (c.heading - c.dir * c.heading.dot(c.dir)).normalized()
		c.speed = 7.0
	var mv := c.speed * dt / R
	var nd := (c.dir + c.heading * mv).normalized()
	var gh := tp.ground(nd)
	if tp.sea_level > -50000.0 and tp.height(nd) < tp.sea_level and c.kind == "hopper":
		c.heading = -c.heading
	else:
		c.dir = nd
		c.heading = (c.heading - c.dir * c.heading.dot(c.dir)).normalized()
	var gr := R + tp.ground(c.dir)
	var y_off := 0.0
	if c.kind == "hopper":
		var hop := absf(sin(c.phase * (6.0 if c.speed > 4.0 else 3.0))) * (0.5 if c.speed > 0.2 else 0.0)
		y_off = hop
		for i in c.legs.size():
			(c.legs[i] as Node3D).rotation.x = sin(c.phase * 8.0 + i * 1.6) * 0.5 * clampf(c.speed / 3.0, 0.0, 1.0)
	else:
		y_off = c.height + sin(c.phase * 0.8) * 1.2
		for i in c.tentacles.size():
			var t: Node3D = c.tentacles[i]
			t.rotation.x = sin(c.phase * 1.7 + i) * 0.25
			t.rotation.z = cos(c.phase * 1.3 + i * 1.7) * 0.25
	var up := c.dir
	var right := c.heading.cross(up).normalized()
	c.node.transform = Transform3D(Basis(right, up, -c.heading).scaled(c.node.scale), c.dir * (gr + y_off))
