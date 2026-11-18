extends RefCounted
## Descent from space to the surface with the free camera: --preset=freecam:<body>:20 --test=res://tests/terrain_descent.gd --alt0=100000 --v1=3000 --v2=500 --secs=70 --heading=0
## Straight radial descent above the start site (looking 50 degrees below the horizon so the horizon curve and the ground ahead are in view), every frame
## casts view rays against the visible chunk set (Planet.debug_view_holes) and records frame-time hitches; prints a summary + PASS/FAIL (0 holes).
func run(game: Node) -> void:
	var alt0 := 100000.0
	var v1 := 3000.0
	var v2 := 500.0
	var secs := 80.0
	var tilt := 50.0
	var settle_alt := 60.0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--alt0="): alt0 = float(s.substr(7))
		elif s.begins_with("--v1="): v1 = float(s.substr(5))
		elif s.begins_with("--v2="): v2 = float(s.substr(5))
		elif s.begins_with("--secs="): secs = float(s.substr(7))
		elif s.begins_with("--tilt="): tilt = float(s.substr(7))
	var fc: Node3D = game.freecam
	if game.hud != null:
		game.hud.visible = false
	var body := Frame.anchor
	var b: BodyDef = Universe.system.bodies[body]
	var pl_node := Universe.body_nodes[body] as Planet
	var dir := PoiSites.start_dir(b)
	var east := dir.cross(Vector3.UP).normalized()
	var north := east.cross(dir).normalized()
	Universe.time = _best_time(body, dir, 50.0)
	var alt := alt0
	var holes_total := 0
	var hits_total := 0
	var worst_frame := 0.0
	var frames := 0
	var t := 0.0
	var last := Time.get_ticks_usec()
	var pend_max := 0
	var next_print := 0.0
	while t < secs and alt > settle_alt:
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := minf(float(now - last) / 1.0e6, 0.1)
		last = now
		t += dt
		frames += 1
		worst_frame = maxf(worst_frame, dt) if frames > 3 else worst_frame
		var speed := v1 if alt > 12000.0 else lerpf(v2, v1, clampf((alt - 1500.0) / 10500.0, 0.0, 1.0))
		alt -= speed * dt
		pl_node = Universe.body_nodes[body] as Planet
		var ground := pl_node.height_at(dir)
		var up := dir
		var fwd := (north * cos(deg_to_rad(tilt)) - up * sin(deg_to_rad(tilt))).normalized()
		var pos := dir * (b.radius + maxf(ground, 0.0) + alt)
		var cam_local_dir: Vector3
		if Frame.anchor == body:
			fc.global_position = pos
			fc.look_at(pos + fwd * 100.0, north)
			cam_local_dir = fwd
		else:
			fc.global_position = Frame.to_local(Universe.body_pos(body).add_v3(pos))
			fc.look_at(fc.global_position + Frame.abs_dir_to_local(fwd) * 100.0, Frame.abs_dir_to_local(north))
			cam_local_dir = fwd
		# planet-space view check (the planet node's own transform maps local -> planet space)
		var cam_ps := pos
		var st := pl_node.debug_stats()
		pend_max = maxi(pend_max, int(st["pending"]))
		var res := pl_node.debug_view_holes(cam_ps, cam_local_dir, 38.0, 90)
		hits_total += res.x
		if t > 2.5:
			holes_total += res.y
			if res.y > 0:
				print("[descent] t=%.1f alt=%.0f HOLES=%d/%d pending=%d" % [t, alt, res.y, res.x, int(st["pending"])])
		if t >= next_print:
			next_print = t + 5.0
			print("[descent] t=%.1f alt=%.0f frame=%d anchor=%d chunks=%d shown=%d pending=%d per_level=%s fps=%d" % [t, alt, frames, Frame.anchor, int(st["chunks"]), int(st["shown"]), int(st["pending"]), str(st["shown_per_level"]), Engine.get_frames_per_second()])
	print("[descent] DONE frames=", frames, " game_s=", t, " worst_frame_ms=", worst_frame * 1000.0, " rays_on_ground=", hits_total, " holes=", holes_total, " max_pending=", pend_max)
	await game.get_tree().create_timer(1.5).timeout
	var img: Image = game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/descent_end_%d.png" % body)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("PASS" if holes_total == 0 else "FAIL", " terrain descent holes")

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
