extends Node
# Loads the real main scene, screenshots the menu, starts the game, screenshots the HUD, opens pause.
var main: Node
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run()
func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/ui/" + nm + ".png"))
	print("SHOT ", nm)
func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame
func tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/ui/"))
	await _wait(5.0)
	await _shot("01_menu")
	main.menus.show_page(Menus.Page.CONTROLS)
	await _wait(0.5)
	await _shot("02_controls")
	main.menus.show_page(Menus.Page.SETTINGS)
	await _wait(0.5)
	await _shot("03_settings")
	main.menus.show_page(Menus.Page.MAIN)
	main._on_start_game()
	await _wait(3.5)
	await _shot("04_hud_start")
	var eden: BodyData = main.world.sys.find_body("Eden")
	await tap("auto_pulse")
	await _wait(6.0)
	await _shot("05_pulse")
	await tap("pause")
	await _wait(0.6)
	await _shot("06_pause")
	await tap("pause")
	await _wait(0.4)
	main._open_map()
	await _wait(0.8)
	main.galaxy_map.selected = 40
	await _wait(0.5)
	await _shot("07_galaxy_map")
	main.galaxy_map.zoom = 0.05
	main.galaxy_map.focus_target = main.galaxy_map.galaxy.stars[0]["pos"]
	await _wait(1.0)
	await _shot("08_galaxy_zoom")
	main.galaxy_map._set_tab(1)
	await _wait(2.0)
	await _shot("09_system_map")
	main.galaxy_map.close_map()
	await _wait(0.5)
	print("MENU TEST DONE state=", main.state)
	get_tree().quit()
