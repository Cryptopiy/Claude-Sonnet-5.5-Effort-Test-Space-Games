extends RefCounted
## Performance + frame-rebase test of the black-hole lens quad (module M5).
##   --test=res://tests/bh_perf.gd -- --autostart --preset=bh:400 [--dists=400,150,45,15,5] [--frames=90]
## For every distance the ship is placed looking at the hole; the GPU render time of the viewport (RenderingServer measured render time)
## and the CPU frame time are averaged over N frames, once with the lens quad + post layer enabled and once with them hidden, so the
## cost of the effect itself is the difference.  A second phase flies at ~40 km/s past the hole (pulse speed) and checks that the
## singularity's local position stays consistent with the absolute one while Frame re-bases every few frames.

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func _bh_node() -> BlackHole:
	return Universe.body_nodes[Universe.system.black_hole_index] as BlackHole

func _measure(game: Node, frames: int) -> Array:
	var vp := game.get_viewport().get_viewport_rid()
	var gpu := 0.0
	var cpu := 0.0
	var n := 0
	for i in frames:
		await game.get_tree().process_frame
		if game.ship != null:
			game.ship.velocity = Vector3.ZERO      # pinned: the capture field must not drag the ship through the horizon mid-measurement
		if i < 8:
			continue
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		n += 1
	return [gpu / maxf(float(n), 1.0), cpu / maxf(float(n), 1.0)]

func run(game: Node) -> void:
	var vp := game.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := int(_arg("frames", "90"))
	var dists: PackedStringArray = _arg("dists", "400,150,45,15,5").split(",", false)
	var bhp := Universe.body_pos(Universe.system.black_hole_index)
	var to_star := Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
	var bh := _bh_node()
	if game.ship != null:
		game.ship.visible = false
	var worst_cost := 0.0
	for ds in dists:
		var dist := float(ds) * 1000.0
		var dir := to_star.rotated(Vector3.UP, 0.25).rotated(to_star.cross(Vector3.UP).normalized(), 0.2)
		game.place_ship_abs(bhp.add_v3(dir * dist), -dir)
		game.ship.velocity = Vector3.ZERO
		# on: lens + post
		bh._lens.visible = true
		bh.set_process(true)
		var on: Array = await _measure(game, frames)
		# off: hide the quad (the BlackHole script re-enables it each frame, so freeze its processing)
		bh.set_process(false)
		bh._lens.visible = false
		bh._post_layer.visible = false
		var off: Array = await _measure(game, frames)
		bh.set_process(true)
		var cost: float = float(on[0]) - float(off[0])
		worst_cost = maxf(worst_cost, cost)
		print("[bh_perf] dist %6.0f km : GPU total %.2f ms (lens off %.2f ms) -> lens cost %.2f ms | CPU %.2f ms" % [dist / 1000.0, float(on[0]), float(off[0]), cost, float(on[1])])
	print(("PASS" if worst_cost <= 6.0 else "FAIL"), " bh_perf: worst-case lens cost %.2f ms (budget 6 ms)" % worst_cost)

	while game.warping:
		await game.get_tree().process_frame
	bh = _bh_node()
	# ---- frame-rebase consistency at pulse speed ---------------------------------------------------------------------------------
	# fly past the hole at 20 km/s with an impact parameter of 60 km (velocity is re-asserted every frame so the flight model cannot slow us)
	bh.set_process(true)
	game.ship.visible = true
	var side := to_star.cross(Vector3.UP).normalized()
	var along := side.rotated(Vector3.UP, 0.6)
	var start := bhp.add_v3(to_star * 60000.0 - along * 180000.0)
	game.place_ship_abs(start, along)
	var rb := [0]
	var max_err := 0.0
	var origin0: DVec = Frame.origin.copy()
	var cb := func(_s: Vector3): rb[0] += 1
	Frame.origin_shifted.connect(cb)
	var t0 := Time.get_ticks_msec()
	var closest := INF
	var shot_done := false
	var frames_run := 0
	while (Time.get_ticks_msec() - t0) < 14000:
		await game.get_tree().process_frame
		game.ship.velocity = Frame.abs_dir_to_local(along * 20000.0)
		var abs_bh := Universe.body_pos(Universe.system.black_hole_index)
		var err := (bh.global_position - Frame.to_local(abs_bh)).length()
		max_err = maxf(max_err, err)
		closest = minf(closest, bh.distance)
		frames_run += 1
		if not shot_done and bh.distance < 75000.0 and bh.distance <= closest + 0.1 and frames_run > 20:
			pass
	Frame.origin_shifted.disconnect(cb)
	print("[bh_perf] %d frames, %d rebases, origin moved %.0f m, closest approach %.0f m (level seen %d), max |BlackHole.global_position - Frame.to_local(abs)| = %.4f m" % [frames_run, rb[0], Frame.origin.distance_to(origin0), closest, bh.level, max_err])
	print(("PASS" if rb[0] > 20 and max_err < 0.5 else "FAIL"), " bh_perf: black hole stays glued to its absolute position across %d Frame rebases at 20 km/s" % rb[0])
