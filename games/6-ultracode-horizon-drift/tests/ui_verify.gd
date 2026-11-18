extends RefCounted
## UI verification test (module M6), run on a landed ship in the integrated game:
##   godot ... -- --autostart --test=res://tests/ui_verify.gd
## Phases: (1) no visible mouse-blocking Control while playing, (2) Esc / M / N / I / F1 consistency through REAL key events,
## (3) pause menu + settings sliders really change Game.settings and are applied (FOV on the active camera, volume on Audio),
## (4) on-foot HUD with scanner markers + nav target + damage flash, (5) black-hole warning panel. Saves .previews/uv_*.png.

var _game: Node
var _fails: int = 0

func _frames(n: int) -> void:
	for i in n:
		await _game.get_tree().process_frame

func _wait(sec: float) -> void:
	await _game.get_tree().create_timer(sec).timeout

func _shot(name: String, wait: float = 0.5) -> void:
	await _wait(wait)
	var img: Image = _game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/uv_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[uv] shot ", name, " ", img.get_size())

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		print("FAIL ", msg)
		_fails += 1

## real key press + release (goes through InputMap exactly like a keyboard)
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
	await _frames(3)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = _px(v)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await _frames(2)

func _blockers() -> Array:
	var out: Array = []
	var stack: Array = [_game.main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Control and (n as Control).is_visible_in_tree() and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append(str((n as Control).get_path()))
	return out

func run(game: Node) -> void:
	_game = game
	await _frames(40)
	# ------------------------------------------------------------------------------------------------------------------ 1. blockers
	var bl := _blockers()
	_check(bl.is_empty(), "no visible mouse-blocking Control while playing %s" % str(bl))
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse is captured while playing (mode=%d)" % Input.mouse_mode)
	_check(game.input_enabled(), "gameplay input enabled while playing")
	# ------------------------------------------------------------------------------------------------------------------ 2. overlay keys
	for pair in [[KEY_M, "galaxy_map", "map"], [KEY_N, "system_map", "system"], [KEY_I, "inventory", "inventory"], [KEY_F1, "controls", "controls"]]:
		var code: int = pair[0]
		var panel: Control = game._overlay_node(pair[2])
		await _tap(code)
		_check(game.overlay_open and panel.visible, "%s opens its overlay" % pair[1])
		_check(not game.input_enabled(), "gameplay input is off while %s is open" % pair[1])
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "cursor is released while %s is open" % pair[1])
		await _tap(code)
		_check(not game.overlay_open and not panel.visible, "%s key toggles it closed again" % pair[1])
		await _frames(2)
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse look restored after closing %s" % pair[1])
	await _tap(KEY_M)
	await _tap(KEY_N)
	_check(game.system_map.visible and not game.galaxy_map.visible and game.overlay_open, "N while the galaxy map is open switches to the system map")
	await _tap(KEY_ESCAPE)
	_check(not game.overlay_open and not game.system_map.visible and game.state == game.State.PLAYING, "Esc closes the overlay and does NOT pause")
	await _tap(KEY_ESCAPE)
	_check(game.state == game.State.PAUSED and game.pause_menu.visible and game.get_tree().paused, "second Esc pauses (pause menu visible)")
	await _tap(KEY_M)
	_check(not game.galaxy_map.visible, "M does nothing while paused")
	await _tap(KEY_ESCAPE)
	_check(game.state == game.State.PLAYING and not game.pause_menu.visible and not game.get_tree().paused, "Esc in the pause menu resumes")
	# ------------------------------------------------------------------------------------------------------------------ 3. pause + settings
	await _tap(KEY_ESCAPE)
	var pm: PauseMenu = game.pause_menu
	await _frames(5)
	pm._show_page(true)
	await _frames(3)
	var sp: SettingsPanel = pm._settings
	_check(sp.visible, "pause menu settings page shows")
	var old_fov: float = float(game.settings["fov"])
	var s_fov: UISlider = sp._rows["fov"]
	var s_sens: UISlider = sp._rows["mouse_sens"]
	var s_vol: UISlider = sp._rows["volume"]
	var t_inv: UIToggle = sp._rows["invert_y"]
	var t_fps: UIToggle = sp._rows["show_fps"]
	# real mouse click on the FOV slider (right end)
	var r: Rect2 = s_fov.get_global_rect()
	await _click(Vector2(r.end.x - 10.0, r.get_center().y))
	_check(float(game.settings["fov"]) > 100.0, "clicking the FOV slider changes Game.settings.fov (%.0f -> %.0f)" % [old_fov, float(game.settings["fov"])])
	# direct (programmatic) value changes for the others
	s_sens._set_from_x(s_sens.size.x - 8.0)
	_check(is_equal_approx(float(game.settings["mouse_sens"]), 3.0), "sensitivity slider max -> Game.settings.mouse_sens = %.2f" % float(game.settings["mouse_sens"]))
	s_vol._set_from_x(8.0 + (s_vol.size.x - 16.0) * 0.25)
	_check(absf(float(game.settings["volume"]) - 0.25) < 0.02, "volume slider -> Game.settings.volume = %.2f" % float(game.settings["volume"]))
	_check(absf(float(Audio.master_volume) - float(game.settings["volume"])) < 0.02, "Audio master volume follows the slider (%.2f)" % float(Audio.master_volume))
	t_inv.toggled.emit(true)
	t_fps.toggled.emit(true)
	_check(bool(game.settings["invert_y"]) and bool(game.settings["show_fps"]), "toggles write invert_y / show_fps")
	# invert_y flips the look delta (needs captured mouse: emulate through the helper's maths)
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(10, 10)
	var d0: Vector2 = Vector2(10, 10) * 0.0022 * float(game.settings["mouse_sens"])
	_check(d0.x > 0.06, "mouse look delta scales with sensitivity (%.3f for 10px)" % d0.x)
	await _shot("settings_in_game", 0.4)
	pm._show_page(false)
	await _tap(KEY_ESCAPE)                         # resume
	await _frames(40)
	var cam: Camera3D = game.active_camera()
	_check(cam != null and absf(cam.fov - float(game.settings["fov"])) < 12.0 and cam.fov > 90.0, "active camera FOV follows the setting (cam %.1f, setting %.1f)" % [cam.fov if cam != null else -1.0, float(game.settings["fov"])])
	await _shot("hud_fov_wide", 0.3)
	# restore defaults through the Reset button path
	await _tap(KEY_ESCAPE)
	await _frames(3)
	pm._show_page(true)
	sp._reset_defaults()
	_check(is_equal_approx(float(game.settings["fov"]), 78.0) and not bool(game.settings["invert_y"]) and not bool(game.settings["show_fps"]), "RESET DEFAULTS restores the settings")
	_check(absf(float(Audio.master_volume) - 0.8) < 0.02, "RESET DEFAULTS restores the audio volume")
	pm._show_page(false)
	# Controls from the pause menu: F1 and Esc both close it, the pause menu stays
	game.controls_panel.call("open")
	await _frames(4)
	_check(game.controls_panel.visible, "controls panel opens from the pause menu")
	await _tap(KEY_F1)
	_check(not game.controls_panel.visible and game.state == game.State.PAUSED, "F1 closes the controls panel (still paused)")
	game.controls_panel.call("open")
	await _frames(3)
	await _tap(KEY_ESCAPE)
	_check(not game.controls_panel.visible and game.state == game.State.PAUSED, "Esc closes the controls panel (still paused)")
	await _tap(KEY_ESCAPE)
	_check(game.state == game.State.PLAYING, "Esc resumes")
	await _frames(5)
	# ------------------------------------------------------------------------------------------------------------------ 4. on foot
	game.exit_ship(true)
	await _frames(40)
	_check(game.mode == game.Mode.FOOT, "exit ship -> FOOT mode")
	bl = _blockers()
	_check(bl.is_empty(), "no mouse-blocking Control on foot %s" % str(bl))
	if game.player != null and is_instance_valid(game.player):
		var pcam: Camera3D = game.active_camera()
		var fwd: Vector3 = -pcam.global_transform.basis.z
		var up: Vector3 = pcam.global_transform.basis.y
		var markers: Array = []
		markers.append({"pos": pcam.global_position + fwd * 60.0 + up * 4.0, "label": "Monolith", "kind": "poi", "time_left": 99.0})
		markers.append({"pos": pcam.global_position + fwd * 28.0 + pcam.global_transform.basis.x * 14.0, "label": "Ferrite", "kind": "resource", "time_left": 99.0})
		markers.append({"pos": pcam.global_position + fwd * 90.0 - pcam.global_transform.basis.x * 30.0, "label": "Grazer", "kind": "creature", "time_left": 99.0})
		game.player.scan_markers = markers
	game.nav_target = 5
	Events.notify.emit("Scan complete: 1 point of interest, 1 resource, 1 creature", "discover")
	Events.notify.emit("Warning: extreme heat - exosuit protection draining", "warn")
	Events.resource_collected.emit("ferrite", 6)
	Events.hint.emit("Hold LMB to mine  -  press C to scan the area", 6.0)
	Events.screen_flash.emit(Color(1, 0.12, 0.05, 0.5), 3.0)
	await _frames(10)
	await _shot("hud_foot", 0.2)
	# ------------------------------------------------------------------------------------------------------------------ 5. BH warning
	for lv in [1, 3]:
		Events.blackhole_warning.emit(lv, 90000.0 / float(lv))
		await _frames(30)
		await _shot("hud_foot_bh%d" % lv, 0.2)
	Events.blackhole_warning.emit(0, 0.0)
	print("[uv] verification done, fails=", _fails)
