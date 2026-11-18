extends RefCounted
## LOD hole / hitch test: --preset=freecam:<body>:<alt> --test=res://tests/terrain_walk.gd --speed=11 --secs=12 --alt=3 --shotevery=0
## Flies the free camera along the surface at <speed> m/s (altitude above ground <alt>), every frame checks that every sample point on the ground ahead
## is covered by a visible chunk (Planet.debug_holes) and records frame-time spikes.
func run(game: Node) -> void:
	var speed := 11.0
	var secs := 12.0
	var alt := 3.0
	var prefix := "walk"
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--speed="): speed = float(s.substr(8))
		elif s.begins_with("--secs=") or s.begins_with("--walk-secs="): secs = float(s.substr(s.find("=") + 1))
		elif s.begins_with("--alt="): alt = float(s.substr(6))
		elif s.begins_with("--prefix="): prefix = s.substr(9)
	var fc: Node3D = game.freecam
	var body := Frame.anchor
	var pl := Frame.anchor_node() as Planet
	var b: BodyDef = Universe.system.bodies[body]
	var dir := PoiSites.start_dir(b)
	var east := dir.cross(Vector3.UP).normalized()
	var north := east.cross(dir).normalized()
	var heading := (north * 0.8 + east * 0.6).normalized()
	var pos_dir := dir
	var fwd_dir := heading
	# wait for the initial LOD
	var t0 := Time.get_ticks_msec()
	await game.get_tree().create_timer(1.0).timeout
	while Time.get_ticks_msec() - t0 < 40000:
		var st := pl.debug_stats()
		if int(st["pending"]) == 0 and int(st["inflight"]) == 0:
			break
		await game.get_tree().create_timer(0.25).timeout
	var holes_total := 0
	var view_holes_total := 0
	var heading_deg := 0.0
	for a2 in OS.get_cmdline_user_args():
		if String(a2).begins_with("--heading="): heading_deg = float(String(a2).substr(10))
	if heading_deg != 0.0:
		fwd_dir = (north * cos(deg_to_rad(heading_deg)) + east * sin(deg_to_rad(heading_deg))).normalized()
	var worst_frame := 0.0
	var worst_lod := 0.0
	var frames := 0
	var t := 0.0
	var last := Time.get_ticks_usec()
	var pending_max := 0
	while t < secs:
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1.0e6
		last = now
		t += dt
		frames += 1
		worst_frame = maxf(worst_frame, dt)
		# advance along the great circle
		var ang := speed * dt / b.radius
		var new_dir := (pos_dir * cos(ang) + fwd_dir * sin(ang)).normalized()
		fwd_dir = (fwd_dir * cos(ang) - pos_dir * sin(ang)).normalized()
		pos_dir = new_dir
		var p := pos_dir * (pl.terrain_radius_at(pos_dir) + alt)
		fc.global_position = p
		fc.look_at(p + fwd_dir * 100.0 - pos_dir * 10.0, pos_dir)
		var st2 := pl.debug_stats()
		pending_max = maxi(pending_max, int(st2["pending"]))
		if frames % 4 == 0:
			var holes := pl.debug_holes(p, 40)
			holes_total += holes
			if holes > 0:
				print("[walk] t=%.1f HOLES=%d" % [t, holes])
		worst_lod = maxf(worst_lod, float(st2.get("lod_ms_max", 0.0)))
		if frames % 3 == 0:
			var vh := pl.debug_view_holes(p, fwd_dir - pos_dir * 0.12, 35.0, 80)
			view_holes_total += vh.y
			if vh.y > 0:
				print("[walk] t=%.1f VIEW HOLES=%d/%d" % [t, vh.y, vh.x])
	print("[walk] frames=", frames, " avg_fps=", float(frames) / t, " worst_frame_ms=", worst_frame * 1000.0, " holes=", holes_total, " view_holes=", view_holes_total, " max_pending=", pending_max, " lod_ms_max=", worst_lod, " ", pl.debug_stats())
	print("PASS" if holes_total == 0 and view_holes_total == 0 else "FAIL", " terrain walk holes")
