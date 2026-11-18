extends Node
# Visual QA of every landable world: landed ship + astronaut at the outpost, plus a higher wide shot. Uses the real main scene.
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
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/biomes/" + nm + ".png"))
	print("SHOT ", nm, " fps=", Engine.get_frames_per_second())

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _wait_terrain(pl: Planet, mn: float, mx: float) -> void:
	var t0 := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if el > mx or (el > mn and pl.terrain.pending_jobs() == 0):
			break

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/biomes/"))
	await _wait(2.0)
	main._on_start_game()
	await _wait(3.0)
	var hud: Control = main.hud
	for idx in world.sys.bodies.size():
		var b: BodyData = world.sys.bodies[idx]
		if not b.landable:
			continue
		if not only.is_empty() and not only.has(b.name):
			continue
		var pl: Planet = world.planets[idx]
		world.time = 0.0
		pc.spawn_landed(idx, 0, false)
		await _wait_terrain(pl, 2.0, 9.0)
		await _wait(1.0)
		print("[", b.name, "] biome=", b.biome, " chunks=", pl.terrain.chunks.size(), " air=", world.air, " alt=", world.altitude)
		await _shot("%s_1_pad" % b.name)
		var up: Vector3 = pc.astro.global_position.normalized()
		var east: Vector3 = U.any_perp(up)
		pc.astro.global_position += east * 150.0 + up * 45.0
		pc.astro.velocity = Vector3.ZERO
		pc.astro.cam_pitch = -0.12
		await _wait_terrain(pl, 1.5, 6.0)
		await _shot("%s_2_wide" % b.name)
	print("BIOME TEST DONE")
	get_tree().quit()
