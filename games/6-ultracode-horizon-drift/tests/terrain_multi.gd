extends RefCounted
## Multi-body screenshot tour in ONE process (one Godot start-up for many planets):
##   --preset=freecam:1:20 --test=res://tests/terrain_multi.gd --bodies=0,6,2,7 --alts=1.7,150 --sunel=50 --tilt=14 --off=260,-200 --prefix=r3
## For every body: teleport the free camera above the start site (Frame switches anchors by itself), set the time so the sun stands at --sunel degrees,
## wait until the terrain LOD has settled, then save .previews/<prefix>_<body>_<alt>.png.
func run(game: Node) -> void:
	var bodies: Array = [0, 6, 2, 7]
	var alts: Array = [1.7, 150.0]
	var prefix := "multi"
	var sun := 50.0
	var tilt_arg := -1.0
	var dir_off := Vector2.ZERO
	var yaws: Array = []
	var tag := ""
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--bodies="):
			bodies = []
			for t in s.substr(9).split(",", false):
				bodies.append(int(t))
		elif s.begins_with("--alts="):
			alts = []
			for t in s.substr(7).split(",", false):
				alts.append(float(t))
		elif s.begins_with("--prefix="): prefix = s.substr(9)
		elif s.begins_with("--yaws="):
			for t in s.substr(7).split(",", false):
				yaws.append(float(t))
		elif s.begins_with("--sunel="): sun = float(s.substr(8))
		elif s.begins_with("--tilt="): tilt_arg = float(s.substr(7))
		elif s.begins_with("--off="):
			var q := s.substr(6).split(",")
			dir_off = Vector2(float(q[0]), float(q[1]))
	var fc: Node3D = game.freecam
	if game.hud != null:
		game.hud.visible = false
	for bi in bodies.size():
		var body: int = bodies[bi]
		var yaw := deg_to_rad(float(yaws[bi]) if bi < yaws.size() else 0.0)
		tag = "" if yaw == 0.0 else "_y%d" % int(rad_to_deg(yaw))
		var b: BodyDef = Universe.system.bodies[body]
		var pl := Universe.body_nodes[body] as Planet
		var dir := PoiSites.start_dir(b)
		if dir_off != Vector2.ZERO:
			var e0 := dir.cross(Vector3.UP).normalized()
			var n0 := e0.cross(dir).normalized()
			dir = (dir * b.radius + e0 * dir_off.x + n0 * dir_off.y).normalized()
		Universe.time = _best_time(body, dir, sun)
		for alt_v in alts:
			var alt: float = alt_v
			var up := dir
			var east := up.cross(Vector3.UP).normalized()
			if absf(up.y) > 0.95:
				east = up.cross(Vector3.RIGHT).normalized()
			var north := east.cross(up).normalized()
			var pos := dir * (b.radius + pl.height_at(dir) + alt)
			var tilt := tilt_arg if tilt_arg >= 0.0 else (4.0 if alt < 100.0 else 22.0)
			var hd := (north * cos(yaw) + east * sin(yaw)).normalized()
			var fwd := (hd * cos(deg_to_rad(tilt)) - up * sin(deg_to_rad(tilt))).normalized()
			if Frame.anchor == body:
				fc.global_position = pos
				fc.look_at(pos + fwd * 100.0, up)
			else:
				fc.global_position = Frame.to_local(Universe.body_pos(body).add_v3(pos))
				fc.look_at(fc.global_position + Frame.abs_dir_to_local(fwd) * 100.0, Frame.abs_dir_to_local(up))
			await game.get_tree().create_timer(0.8).timeout
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 45000:
				var st := pl.debug_stats()
				if int(st["pending"]) == 0 and int(st["inflight"]) == 0 and Frame.anchor == body:
					break
				await game.get_tree().create_timer(0.25).timeout
			# re-place after the anchor switch (positions are now planet space)
			if Frame.anchor == body:
				fc.global_position = pos
				fc.look_at(pos + fwd * 100.0, up)
			await game.get_tree().create_timer(1.6).timeout
			var img: Image = game.get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path("res://.previews/%s_%d_%d%s.png" % [prefix, body, int(alt), tag])
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			img.save_png(path)
			print("[multi] ", path.get_file(), " anchor=", Frame.anchor, " ", pl.debug_stats(), " settle_ms=", Time.get_ticks_msec() - t0)

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
