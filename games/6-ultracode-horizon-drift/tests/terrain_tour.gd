extends RefCounted
## Screenshot tour over one planet: --preset=freecam:<body>:<alt> --test=res://tests/terrain_tour.gd --tour=20,300,5000,60000,600000 --prefix=name
## Moves the debug free camera above the start site at each altitude, waits for the LOD to settle and saves .previews/<prefix>_<body>_<alt>.png
func run(game: Node) -> void:
	var alts: Array = [20.0, 300.0, 5000.0]
	var prefix := "tour"
	var sun := 35.0
	var look_tilt := -1.0
	var atmo := true
	var yaw_deg := 0.0
	var dir_off := Vector2.ZERO          # metres east, north of the start site
	var nohud := true
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--tour="):
			alts = []
			for t in s.substr(7).split(",", false):
				alts.append(float(t))
		elif s.begins_with("--prefix="):
			prefix = s.substr(9)
		elif s.begins_with("--sunel="):
			sun = float(s.substr(8))
		elif s.begins_with("--tilt="):
			look_tilt = float(s.substr(7))
		elif s.begins_with("--atmo="):
			atmo = int(s.substr(7)) != 0
		elif s.begins_with("--yaw="):
			yaw_deg = float(s.substr(6))
		elif s.begins_with("--nohud="):
			nohud = int(s.substr(8)) != 0
		elif s.begins_with("--off="):
			var q := s.substr(6).split(",")
			dir_off = Vector2(float(q[0]), float(q[1]))
	var fc: Node3D = game.freecam
	if nohud and game.hud != null:
		game.hud.visible = false
	var body := Frame.anchor
	if body < 0:
		print("[tour] no body anchor")
		return
	var b: BodyDef = Universe.system.bodies[body]
	var dir := PoiSites.start_dir(b)
	if dir_off != Vector2.ZERO:
		var e0 := dir.cross(Vector3.UP).normalized()
		var n0 := e0.cross(dir).normalized()
		dir = (dir * b.radius + e0 * dir_off.x + n0 * dir_off.y).normalized()
	if not atmo:
		for n in ["Atmosphere", "Clouds"]:
			var nd: Node = (Universe.body_nodes[body] as Node).get_node_or_null(n)
			print("[tour] atmo toggle ", n, " found=", nd != null)
			if nd != null:
				nd.set("visible", false)
	Universe.time = _best_time(body, dir, sun)
	for alt_v in alts:
		var alt: float = alt_v
		var pl := Frame.anchor_node() as Planet
		if pl == null or Frame.anchor != body:
			# far away: we are in space frame; just look at the planet
			pl = Universe.body_nodes[body] as Planet
		var h := pl.height_at(dir)
		var up := dir
		var east := up.cross(Vector3.UP).normalized()
		if absf(up.y) > 0.95:
			east = up.cross(Vector3.RIGHT).normalized()
		var north := east.cross(up).normalized()
		var pos := dir * (b.radius + h + alt)
		var fwd: Vector3
		var tilt := look_tilt
		if alt < 100.0:
			if tilt < 0.0: tilt = 4.0
		elif alt < 1500.0:
			if tilt < 0.0: tilt = 22.0
		elif alt < 20000.0:
			if tilt < 0.0: tilt = 50.0
		else:
			if tilt < 0.0: tilt = 90.0
		var tr := deg_to_rad(tilt)
		if alt >= 20000.0:
			fwd = -up
			pos = dir * (b.radius + alt) + east * 0.0
		else:
			var hd := (north * cos(deg_to_rad(yaw_deg)) + east * sin(deg_to_rad(yaw_deg))).normalized()
			fwd = (hd * cos(tr) - up * sin(tr)).normalized()
		if Frame.anchor == body:
			fc.global_position = pos
			fc.look_at(pos + fwd * 100.0, up if absf(fwd.dot(up)) < 0.99 else north)
		else:
			fc.global_position = Frame.to_local(Universe.body_pos(body).add_v3(pos))
			fc.look_at(fc.global_position + Frame.abs_dir_to_local(fwd) * 100.0, Frame.abs_dir_to_local(up))
		# settle
		var t0 := Time.get_ticks_msec()
		await game.get_tree().create_timer(0.6).timeout
		while Time.get_ticks_msec() - t0 < 40000:
			var node := Universe.body_nodes[body] as Planet
			var st: Dictionary = node.debug_stats()
			if int(st["pending"]) == 0 and int(st["inflight"]) == 0:
				break
			await game.get_tree().create_timer(0.25).timeout
		await game.get_tree().create_timer(0.8).timeout
		var img: Image = game.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.previews/%s_%d_%d.png" % [prefix, body, int(alt)])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		var node2 := Universe.body_nodes[body] as Planet
		print("[tour] ", path.get_file(), " ", node2.debug_stats(), " fps=", Engine.get_frames_per_second(), " settle_ms=", Time.get_ticks_msec() - t0)

## time at which the sun elevation over `dir` is closest to elev_deg (falls back to the highest sun when the target is unreachable at this latitude)
static func _best_time(body: int, dir: Vector3, elev_deg: float) -> float:
	var d: BodyDef = Universe.system.bodies[body]
	var target := sin(deg_to_rad(elev_deg))
	var steps := 720
	var dt := d.spin_period / float(steps)
	var best_t := Universe.time
	var best_e := 1.0e9
	for k in steps:
		var t := Universe.time + dt * float(k)
		var e := Universe.sun_dir_body_local(body, t).dot(dir.normalized())
		if absf(e - target) < best_e:
			best_e = absf(e - target)
			best_t = t
	return best_t
