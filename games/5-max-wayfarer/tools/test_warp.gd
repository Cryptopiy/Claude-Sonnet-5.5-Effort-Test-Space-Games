extends Node
# Hyperdrive jump through the real main scene: find a star in range, jump, verify the new system + screenshots.
var main: Node
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.message.connect(func(t: String, _s: float, k: String) -> void: print("MSG[%s] %s" % [k, t]))
	_run()

func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/warp/" + nm + ".png"))
	print("SHOT ", nm, " fps=", Engine.get_frames_per_second())

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/warp/"))
	await _wait(2.0)
	main._on_start_game()
	await _wait(3.0)
	var g: Galaxy = Galaxy.get_galaxy()
	var best: int = -1
	var bd: float = 1e9
	for i in Galaxy.COUNT:
		if i == Galaxy.HOME_INDEX:
			continue
		var d: float = g.distance_ly(Galaxy.HOME_INDEX, i)
		if d > 900.0 and d < bd:
			bd = d
			best = i
	print("nearest star >900ly: ", best, " ", g.stars[best]["name"], " class ", g.stars[best]["cls"], " dist ", int(bd))
	# the map should allow the jump from here
	var gm: GalaxyMap = main.galaxy_map
	main._open_map()
	await _wait(0.5)
	gm.selected = best
	print("jump status: '", gm._jump_status(best), "'")
	await _shot("w0_map")
	gm.close_map()
	await _wait(0.4)
	main.hyperdrive_jump(best)
	await _wait(1.0)
	await _shot("w1_warp")
	await _wait(3.5)
	await _shot("w2_arrival")
	await _wait(2.5)
	print("system now: ", main.world.sys.name, " class ", main.world.sys.star_class, " bodies ", main.world.sys.bodies.size(), " state=", main.state)
	for b in main.world.sys.bodies:
		print("  body ", b.name, " ", b.kind, " ", b.biome, " R=", int(b.radius), " orbit=", int(b.orbit_r))
	await _shot("w3_cruise")
	print("WARP TEST DONE")
	get_tree().quit()
