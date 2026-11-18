class_name Creature
extends Node3D
## A simple procedurally animated animal living in planet-local coordinates.
## kinds: strider (walks, flees), floater (hovers/drifts), flyer (circles overhead).

var kind := "strider"
var data: PlanetData
var lpos := Vector3.ZERO
var fwd := Vector3.FORWARD
var model: Node3D
var legs: Array = []
var wings: Array = []
var phase := 0.0
var speed := 0.0
var target_speed := 0.0
var turn_t := 0.0
var ground_h := 0.0
var h_cd := 0
var center := Vector3.ZERO       # flyer orbit centre (unit dir)
var orbit_r := 30.0
var orbit_ang := 0.0
var orbit_dir := 1.0
var alt_above := 25.0
var rng := RandomNumberGenerator.new()
var scale_f := 1.0
var fleeing := false


func setup(p_kind: String, d: PlanetData, p_lpos: Vector3, seed: int, tint: Dictionary) -> void:
	kind = p_kind
	data = d
	lpos = p_lpos
	rng.seed = seed
	var mname := "creature_" + kind
	model = ModelLib.instance(mname, tint)
	add_child(model)
	for nm in ["FL", "FR", "BL", "BR"]:
		var n := model.find_child("Creature_Leg" + nm, true, false)
		if n:
			legs.append(n)
	for nm in ["L", "R"]:
		var n := model.find_child("Creature_Wing" + nm, true, false)
		if n:
			wings.append(n)
	var up := lpos.normalized()
	var t := up.cross(Vector3.RIGHT)
	if t.length() < 0.1:
		t = up.cross(Vector3.FORWARD)
	fwd = t.normalized().rotated(up, rng.randf() * TAU)
	phase = rng.randf() * 10.0
	scale_f = rng.randf_range(0.9, 1.5) if kind == "strider" else rng.randf_range(0.8, 1.4)
	model.scale = Vector3.ONE * scale_f
	ground_h = d.height_at(up)
	if kind == "flyer":
		center = up
		orbit_r = rng.randf_range(22.0, 45.0)
		orbit_ang = rng.randf() * TAU
		orbit_dir = 1.0 if rng.randf() < 0.5 else -1.0
		alt_above = rng.randf_range(18.0, 38.0)
	elif kind == "floater":
		alt_above = rng.randf_range(3.5, 9.0)


func tick(dt: float, player_lpos: Vector3, player_present: bool) -> void:
	phase += dt
	var R := data.radius
	var up := lpos.normalized()
	if kind == "flyer":
		_tick_flyer(dt, R)
		return
	h_cd -= 1
	if h_cd <= 0:
		ground_h = data.height_at(up)
		h_cd = 6
	var to_p := player_lpos - lpos
	var dist_p := to_p.length()
	if kind == "strider":
		fleeing = player_present and dist_p < 14.0
		if fleeing:
			var away := (-to_p - up * (-to_p).dot(up)).normalized()
			fwd = fwd.lerp(away, clampf(dt * 3.0, 0.0, 1.0)).normalized()
			target_speed = 6.5
		else:
			turn_t -= dt
			if turn_t <= 0.0:
				turn_t = rng.randf_range(2.0, 6.0)
				fwd = fwd.rotated(up, rng.randf_range(-1.3, 1.3))
				target_speed = 0.0 if rng.randf() < 0.3 else rng.randf_range(0.9, 1.7)
		speed = lerpf(speed, target_speed, clampf(dt * 2.0, 0.0, 1.0))
		var np := lpos + fwd * speed * dt
		var nd := np.normalized()
		var nh := data.height_at(nd)
		# stay out of water and off cliffs
		var blocked := data.has_liquid() and nh < data.sea_level + 0.6
		if absf(nh - ground_h) > speed * dt * 1.4 + 0.25:
			blocked = true
		if blocked:
			fwd = fwd.rotated(up, PI * 0.6 + rng.randf_range(-0.4, 0.4))
			speed = 0.0
		else:
			lpos = nd * (R + nh)
			ground_h = nh
		fwd = (fwd - up * fwd.dot(up)).normalized()
		for i in legs.size():
			var ph := 1.0 if (i == 0 or i == 3) else -1.0
			(legs[i] as Node3D).rotation.x = sin(phase * (3.0 + speed * 2.2) + (0.0 if ph > 0 else PI)) * clampf(speed / 3.0, 0.0, 0.8)
		var nrm := up
		var b := Basis.looking_at(fwd, nrm)
		transform = Transform3D(b, lpos)
	elif kind == "floater":
		turn_t -= dt
		if turn_t <= 0.0:
			turn_t = rng.randf_range(4.0, 9.0)
			fwd = fwd.rotated(up, rng.randf_range(-1.0, 1.0))
		var drift := 1.1
		var np2 := lpos + fwd * drift * dt
		var nd2 := np2.normalized()
		var hh := ground_h
		var want_r := R + hh + alt_above + sin(phase * 0.8) * 0.9
		lpos = nd2 * lerpf(lpos.length(), want_r, clampf(dt * 1.5, 0.0, 1.0))
		fwd = (fwd - nd2 * fwd.dot(nd2)).normalized()
		var bb := Basis.looking_at(fwd, nd2)
		bb = bb * Basis(Vector3.RIGHT, sin(phase * 0.7) * 0.08) * Basis(Vector3.UP, phase * 0.15)
		transform = Transform3D(bb, lpos)
		model.scale = Vector3(1.0, 1.0 + sin(phase * 2.2) * 0.06, 1.0) * scale_f * 1.3


func _tick_flyer(dt: float, R: float) -> void:
	orbit_ang += dt * orbit_dir * (7.0 / orbit_r)
	var up := center
	var t1 := up.cross(Vector3.RIGHT)
	if t1.length() < 0.1:
		t1 = up.cross(Vector3.FORWARD)
	t1 = t1.normalized()
	var t2 := up.cross(t1)
	var off := (t1 * cos(orbit_ang) + t2 * sin(orbit_ang)) * orbit_r
	var d := (up * R + off).normalized()
	lpos = d * (R + ground_h + alt_above + sin(phase * 0.5) * 2.0)
	var vel_dir := (-t1 * sin(orbit_ang) + t2 * cos(orbit_ang)) * orbit_dir
	vel_dir = (vel_dir - d * vel_dir.dot(d)).normalized()
	var b := Basis.looking_at(vel_dir, d)
	b = b * Basis(Vector3.FORWARD, -orbit_dir * 0.35)
	transform = Transform3D(b, lpos)
	var flap := sin(phase * 9.0)
	for i in wings.size():
		var sgn := -1.0 if i == 0 else 1.0
		(wings[i] as Node3D).rotation.z = flap * 0.7 * sgn
