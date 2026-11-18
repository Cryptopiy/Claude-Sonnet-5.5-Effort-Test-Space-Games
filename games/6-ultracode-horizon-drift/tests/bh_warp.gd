extends RefCounted
## Visual/functional test of the warp transition:  --test=res://tests/bh_warp.gd -- ... --kind=hyperdrive|blackhole --dest=1 --times=0.3,0.8,1.4,2.0,2.5,3.2,4.0 --out=.previews/w
## Calls Game.warp_to_system (not awaited), saves screenshots at the given times (seconds since the call) and checks the result.

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func run(game: Node) -> void:
	var kind := _arg("kind", "hyperdrive")
	var dest := int(_arg("dest", "1"))
	var out := _arg("out", ".previews/w")
	var times: PackedStringArray = _arg("times", "0.3,0.8,1.4,2.0,2.5,3.2,4.0,5.0").split(",", false)
	var t0 := Time.get_ticks_msec()
	var start_sys := Universe.current_id
	game.warp_to_system(dest, kind)
	var n := 0
	for ts in times:
		var target := float(ts)
		while (Time.get_ticks_msec() - t0) / 1000.0 < target:
			await game.get_tree().process_frame
		var img: Image = game.get_viewport().get_texture().get_image()
		var full := ProjectSettings.globalize_path("res://%s_%d_%s.png" % [out, n, ts])
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		img.save_png(full)
		print("[bh_warp] t=%.2f saved %s warping=%s system=%d" % [(Time.get_ticks_msec() - t0) / 1000.0, full, str(game.warping), Universe.current_id])
		n += 1
	while game.warping:
		await game.get_tree().process_frame
	var ok := Universe.current_id == dest and Universe.current_id != start_sys
	print("PASS" if ok else "FAIL", " bh_warp: arrived in system ", Universe.current_id, " (wanted ", dest, ") kind=", kind)
	if game.ship != null:
		var sys := Universe.system
		if sys.black_hole_index >= 0 and kind == "blackhole":
			var bhp := Universe.body_pos(sys.black_hole_index)
			var sp := Frame.to_abs(game.ship.global_position)
			var d := bhp.distance_to(sp)
			print("[bh_warp] ship distance to destination singularity: %.0f m (spawn %.0f)" % [d, BlackHoleParams.SPAWN_DISTANCE])
