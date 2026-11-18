extends RefCounted
## Main-menu verification (module M6): quit to the menu, check the animated backdrop really moves, open Controls and Settings
## with REAL mouse clicks (Esc / F1 close them), change a setting, then click START JOURNEY and make sure the game begins again.
##   godot ... -- --autostart --test=res://tests/ui_menu_flow.gd

var _game: Node
var _fails: int = 0

func _frames(n: int) -> void:
	for i in n:
		await _game.get_tree().process_frame

func _wait(sec: float) -> void:
	await _game.get_tree().create_timer(sec).timeout

func _img() -> Image:
	return _game.get_viewport().get_texture().get_image()

func _save(img: Image, name: String) -> void:
	var path := ProjectSettings.globalize_path("res://.previews/um_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[um] shot ", name, " ", img.get_size())

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		print("FAIL ", msg)
		_fails += 1

func _tap(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(3)

func _px(v: Vector2) -> Vector2:
	var vis: Vector2 = _game.get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(_game.get_window().size)
	return v * (win / vis)

func _click(v: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = _px(v)
	m.global_position = m.position
	Input.parse_input_event(m)
	await _frames(4)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = _px(v)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await _frames(3)

func _diff(a: Image, b: Image) -> float:
	var total := 0.0
	var n := 0
	var step := 7
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return total / float(maxi(n, 1))

func _btn(mm: MainMenu, text: String) -> UIButton:
	for b in mm._buttons:
		if (b as UIButton).text == text:
			return b
	return null

func run(game: Node) -> void:
	_game = game
	await _frames(20)
	await game.quit_to_menu()
	await _wait(3.2)
	var mm: MainMenu = game.main_menu
	_check(mm.visible and game.state == game.State.MENU, "quit to menu shows the main menu")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "cursor visible in the menu")
	_check(not game.hud.visible, "HUD hidden in the menu")
	var a := _img()
	_save(a, "menu_a")
	await _wait(2.5)
	var b := _img()
	_save(b, "menu_b")
	var d := _diff(a, b)
	_check(d > 0.004, "menu backdrop is animated (mean diff %.4f between frames 2.5 s apart)" % d)
	# ---- Controls (real click) -> Esc closes
	var bc := _btn(mm, "CONTROLS")
	await _click(bc.get_global_rect().get_center())
	_check(game.controls_panel.visible, "CONTROLS button opens the controls overview")
	await _wait(0.5)
	_save(_img(), "menu_controls")
	await _tap(KEY_ESCAPE)
	_check(not game.controls_panel.visible, "Esc closes the controls overview in the menu")
	await _click(bc.get_global_rect().get_center())
	await _tap(KEY_F1)
	_check(not game.controls_panel.visible, "F1 closes the controls overview in the menu")
	# ---- Settings (real click): move the volume slider, Esc back
	var bs := _btn(mm, "SETTINGS")
	await _click(bs.get_global_rect().get_center())
	_check(mm._settings_wrap.visible, "SETTINGS button opens the settings page")
	var sl: UISlider = mm._settings._rows["volume"]
	var r: Rect2 = sl.get_global_rect()
	await _click(Vector2(r.position.x + 8.0 + (r.size.x - 16.0) * 0.5, r.get_center().y))
	_check(absf(float(game.settings["volume"]) - 0.5) < 0.03, "volume slider click -> %.2f (want 0.50)" % float(game.settings["volume"]))
	_check(absf(float(Audio.master_volume) - float(game.settings["volume"])) < 0.02, "Audio master volume applied (%.2f)" % float(Audio.master_volume))
	await _wait(0.4)
	_save(_img(), "menu_settings")
	await _tap(KEY_ESCAPE)
	_check(not mm._settings_wrap.visible and mm._box.visible, "Esc leaves the settings page")
	game.settings["volume"] = 0.8
	Audio.set_master_volume(0.8)
	# ---- START JOURNEY (real click)
	var bst := _btn(mm, "START JOURNEY")
	await _click(bst.get_global_rect().get_center())
	var waited := 0.0
	while game.state != game.State.PLAYING and waited < 120.0:
		await _wait(0.5)
		waited += 0.5
	_check(game.state == game.State.PLAYING, "START JOURNEY starts the game (%.1f s)" % waited)
	_check(not mm.visible and game.hud.visible, "menu hidden, HUD shown after start")
	await _wait(2.0)
	_save(_img(), "after_start")
	print("[um] menu flow done, fails=", _fails)
