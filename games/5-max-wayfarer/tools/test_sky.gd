extends Node
# Sky / ground check: for every landable world, lands at the first outpost and shoots at local noon and near sunset (run via tools/run_godot.ps1).
var main: Node
var world: SpaceWorld
var pc: PlayerController
var only: PackedStringArray = PackedStringArray()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	pc = main.pc
	_run()

func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/sky/" + nm + ".png"))
	print("SHOT ", nm)

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _set_sun(target_up: float, rising: bool, b: BodyData) -> void:
	# scan the day for the time where the sun elevation at the viewer matches
	var best_t: float = 0.0
	var best_e: float = 1e9
	var t0: float = world.time
	var steps: int = 96
	for i in steps:
		world.time = t0 + b.spin_period * float(i) / float(steps)
		await get_tree().process_frame
		var e: float = absf(world.sun_up_at_viewer - target_up)
		if e < best_e:
			best_e = e
			best_t = world.time
	world.time = best_t

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/sky/"))
	await _wait(2.0)
	main._on_start_game()
	await _wait(3.0)
	main.hud.visible = false
	for idx in world.sys.bodies.size():
		var b: BodyData = world.sys.bodies[idx]
		if not b.landable:
			continue
		if not only.is_empty() and not only.has(b.name):
			continue
		world.time = 0.0
		pc.spawn_landed(idx, 0, false)
		await _wait(3.0)
		pc.astro.cam_pitch = 0.12
		await _set_sun(0.92, true, b)
		await _wait(2.5)
		await _shot("%s_noon" % b.name)
		await _set_sun(0.10, true, b)
		await _wait(2.0)
		await _shot("%s_dusk" % b.name)
	print("SKY TEST DONE")
	get_tree().quit()
