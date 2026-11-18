extends Node
# Black hole visuals + gravity + transport test through the real main scene (hidden desktop).
var main: Node

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run()

func _shot(nm: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT skipped (headless) ", nm)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/bh/" + nm + ".png"))
	print("SHOT ", nm, " fps=", Engine.get_frames_per_second())

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _place(dist: float, dirv: Vector3) -> void:
	var w: SpaceWorld = main.world
	var ship: Ship = main.pc.ship
	var bhp: D3 = w.bh_pos_sys()
	var dn: Vector3 = dirv.normalized()
	w.frame_idx = -1
	w.viewer_pos = Vector3.ZERO
	w.viewer_sys = bhp.plus_v(dn * dist)
	ship.velocity = Vector3.ZERO
	ship.basis = Basis.looking_at(-dn, Vector3.UP)
	ship.cam_basis = ship.basis
	ship.bh_control_loss = 0.0

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/bh/"))
	await _wait(2.0)
	main._on_start_game()
	await _wait(2.5)
	main.pc.ship.cam_mode = 0
	var dirv := Vector3(0.45, 0.10, 0.88)
	for pair in [[200000.0, "d0_far"], [70000.0, "d1_mid"], [26000.0, "d2_near"], [11000.0, "d3_close"], [5000.0, "d4_pnr"]]:
		_place(float(pair[0]), dirv)
		await _wait(1.3)
		print("[", pair[1], "] zone=", main.world.bh_info.get("zone", 0), " dist=", int(main.world.bh_info.get("dist", 0.0)), " pull=", main.world.bh_info.get("pull_ratio", 0.0))
		await _shot(String(pair[1]))
	# fall in
	_place(9000.0, Vector3(0.2, 0.55, 0.8))
	main.pc.ship.velocity = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	var captured_shot := false
	while main.state != 4 and float(Time.get_ticks_msec() - t0) < 40000.0:
		await get_tree().process_frame
		var bi: Dictionary = main.world.bh_info
		if not captured_shot and float(bi.get("dist", 1e9)) < 2600.0:
			captured_shot = true
			await _shot("d5_falling")
	print("captured: state=", main.state, " sys=", main.world.sys.name, " t=", float(Time.get_ticks_msec() - t0) / 1000.0)
	await _wait(1.0)
	await _shot("e0_flash")
	await _wait(4.5)
	print("after transport: sys=", main.world.sys.name, " class=", main.world.sys.star_class, " bodies=", main.world.sys.bodies.size(), " state=", main.state)
	await _shot("e1_arrival")
	await _wait(2.0)
	print("BH TEST DONE")
	get_tree().quit()
