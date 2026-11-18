extends RefCounted
## UI screenshot test (module M6). Opens every UI screen and saves a PNG into .previews/ui_<name>.png.
##   godot ... -- --autostart --test=res://tests/ui_shots.gd --screens=hud,pause,controls,map,system,inventory,menu,settings
## Also asserts that the overlays open/close through Game.toggle_overlay and that Game.overlay_open tracks them.

var _game: Node
var _fails: int = 0

func _shot(name: String, wait: float = 0.7) -> void:
	await _game.get_tree().create_timer(wait).timeout
	var img: Image = _game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/ui_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("[ui] shot ", name, " err=", err, " ", img.get_size())

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		print("FAIL ", msg)
		_fails += 1

func run(game: Node) -> void:
	_game = game
	var which: PackedStringArray = PackedStringArray(["hud", "pause", "controls", "map", "system", "inventory", "menu", "settings"])
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--screens="):
			which = String(a).substr(10).split(",")
	for s in which:
		match s:
			"hud":
				Events.notify.emit("Warp cell crafted  (3)", "good")
				Events.notify.emit("Discovered Verdant  (Lush world)", "discover")
				Events.hint.emit("Press W / Space to lift off  -  G toggles landing gear", 6.0)
				var demo := {"speed": 412.0, "altitude": 3200.0, "state": "ATMOSPHERE", "fuel": 0.72, "hull": 0.9, "throttle": 0.6, "gear": false, "boost": true,
					"pulse": false, "gravity": 9.8, "temp_c": 24.0, "vspeed": -12.0, "shield": 0.8, "hazard": "", "hazard_level": 0.0}
				for i in 45:
					game.tel.merge(demo, true)
					await game.get_tree().process_frame
				await _shot("hud", 0.3)
			"pause":
				game.toggle_pause()
				await _shot("pause", 0.8)
				game.resume()
			"controls":
				game.toggle_overlay("controls")
				_check(game.overlay_open, "controls overlay open")
				await _shot("controls", 0.7)
				game.close_overlays()
				_check(not game.overlay_open, "controls overlay closed")
			"map":
				game.toggle_overlay("map")
				_check(game.overlay_open, "galaxy map open")
				await _shot("map", 1.2)
				game.close_overlays()
			"system":
				game.toggle_overlay("system")
				await _shot("system", 1.2)
				game.close_overlays()
			"inventory":
				game.add_resource("ferrite", 24)
				game.add_resource("zyrite", 9)
				game.add_resource("sodium", 31)
				game.add_resource("voidstone", 2)
				game.toggle_overlay("inventory")
				await _shot("inventory", 0.9)
				game.close_overlays()
			"menu":
				await game.quit_to_menu()
				await _shot("menu", 3.0)
			"settings":
				if game.main_menu != null and game.main_menu.has_method("_show_settings"):
					game.main_menu.call("_show_settings", true)
					await _shot("settings", 0.6)
	print("[ui] test done, fails=", _fails)
