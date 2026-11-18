extends RefCounted
## FULL UI VERIFICATION (module M6). Drives every screen through the REAL input path (synthetic mouse events + input actions), asserts on the
## resulting game state and saves screenshots to .previews/uif_<name>.png.  Real-time waits (the first seconds of a windowless run are slow).
##   godot --resolution 1280x720 ... -- --autostart --test=res://tests/ui_full.gd --screens=hud,toasts,bh,markers,flash,keys,settings,map,system,inventory,menu
## groups: hud toasts bh markers flash keys settings mouse map system inventory menu warp foot

var _game: Node
var _fails: int = 0
var _passes: int = 0

func _sec(s: float) -> void:
	await _game.get_tree().create_timer(s).timeout

func _frames(n: int) -> void:
	for i in n:
		await _game.get_tree().process_frame

func _warm() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000:
		await _frames(3)
		if Engine.get_frames_per_second() >= 14 and Time.get_ticks_msec() - t0 > 3500:
			break
	print("[uif] warm after ", Time.get_ticks_msec() - t0, " ms, fps=", Engine.get_frames_per_second())

func _shot(name: String, wait: float = 0.5) -> void:
	await _sec(wait)
	await _frames(2)
	var img: Image = _game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/uif_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[uif] shot ", name, " ", img.get_size())

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)

## virtual canvas position -> window pixel position
func _px(v: Vector2) -> Vector2:
	var vis: Vector2 = _game.get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(_game.get_window().size)
	return v * (win / vis)

func _move(v: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _px(v)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	await _frames(3)

func _click(v: Vector2) -> void:
	await _move(v)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = _px(v)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await _frames(2)

func _key(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		ev.strength = 1.0 if pressed else 0.0
		Input.parse_input_event(ev)
		await _frames(2)

func _find_btn(root: Node, text: String) -> UIButton:
	if root is UIButton and (root as UIButton).text == text and (root as Control).is_visible_in_tree():
		return root as UIButton
	for c in root.get_children():
		var r := _find_btn(c, text)
		if r != null:
			return r
	return null

func _click_btn(root: Node, text: String) -> bool:
	var b := _find_btn(root, text)
	if b == null:
		print("[uif] button not found: ", text)
		return false
	await _click(b.get_global_rect().get_center())
	return true

func _scan_blockers(root: Node, out: Array) -> void:
	if root is Control:
		var c := root as Control
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append("%s (%s) filter=%d" % [c.get_path(), c.get_class(), c.mouse_filter])
	for ch in root.get_children():
		_scan_blockers(ch, out)

func _freeze_ship_tel() -> void:
	# ship / player overwrite Game.tel every frame; stop them so a demo telemetry set stays on screen
	if _game.ship != null and is_instance_valid(_game.ship):
		_game.ship.process_mode = Node.PROCESS_MODE_DISABLED

func _demo_tel(extra: Dictionary = {}) -> void:
	var demo := {"speed": 412.0, "altitude": 3200.0, "state": "ATMOSPHERE", "fuel": 0.72, "hull": 0.9, "throttle": 0.6, "gear": false, "boost": true,
		"pulse": false, "gravity": 9.8, "temp_c": 24.0, "vspeed": -12.0, "shield": 0.8, "hazard": "", "hazard_level": 0.0, "heat": 0.0, "pressure": 0.0}
	demo.merge(extra, true)
	_game.tel.merge(demo, true)

func run(game: Node) -> void:
	_game = game
	var which: PackedStringArray = PackedStringArray(["hud", "toasts", "bh", "flash", "keys", "mouse", "settings", "map", "system", "inventory", "menu"])
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--screens="):
			which = String(a).substr(10).split(",")
	await _warm()
	for s in which:
		print("[uif] ===== ", s)
		match s:
			"hud": await _t_hud()
			"toasts": await _t_toasts()
			"bh": await _t_bh()
			"markers": await _t_markers()
			"flash": await _t_flash()
			"keys": await _t_keys()
			"mouse": await _t_mouse()
			"settings": await _t_settings()
			"map": await _t_map()
			"system": await _t_system()
			"inventory": await _t_inventory()
			"menu": await _t_menu()
			"warp": await _t_warp()
			"foot": await _t_foot()
	print("[uif] DONE passes=", _passes, " fails=", _fails)

# =============================================================================================================================
func _t_hud() -> void:
	await _shot("hud_landed", 0.3)
	_freeze_ship_tel()
	_demo_tel()
	await _frames(40)
	Events.hint.emit("Press W / Space to lift off  -  G toggles landing gear  -  F1 shows all controls", 6.0)
	await _shot("hud_flight_hint", 0.6)
	# long wrapped hint + context prompt: nothing may touch the speed / altitude cluster
	Events.hint.emit("Pulse drive unavailable: you are too close to a planet. Climb above the atmosphere and clear the surface, then press X again to engage the cruise drive.", 6.0)
	for i in 30:
		_game.set_context_hint("[F] Enter ship")
		await _frames(1)
	await _shot("hud_long_hint", 0.2)
	_demo_tel({"state": "PULSE DRIVE", "speed": 38500.0, "altitude": 842000.0, "pulse": true, "boost": false, "throttle": 1.0, "vspeed": 0.0, "gravity": 0.0})
	await _frames(30)
	await _shot("hud_pulse", 0.3)
	_demo_tel({"state": "ATMOSPHERIC ENTRY", "speed": 612.0, "altitude": 18400.0, "heat": 0.7, "pulse": false, "boost": false, "gravity": 11.2, "temp_c": 41.0, "vspeed": -180.0, "hull": 0.18})
	await _frames(30)
	await _shot("hud_entry", 0.3)

func _t_toasts() -> void:
	Events.notify.emit("Warp cell crafted  (3)", "good")
	Events.notify.emit("Discovered: Comm Tower", "discover")
	Events.notify.emit("Hull damaged (62%)", "danger")
	Events.notify.emit("Pulse drive offline - too close to a planet", "warn")
	Events.notify.emit("Navigation target: Dune", "info")
	Events.resource_collected.emit("ferrite", 8)
	Events.resource_collected.emit("zyrite", 4)
	Events.hint.emit("Hold LMB to mine  -  press C to scan the area", 8.0)
	await _frames(40)
	await _shot("toasts", 0.3)
	# location banner: re-trigger
	Events.location_changed.emit("COLOSSUS  -  Gas giant")
	await _shot("banner_gas", 1.4)

func _t_bh() -> void:
	for lv in [1, 2, 3, 4]:
		Events.blackhole_warning.emit(lv, 250000.0 / float(lv * lv * lv))
		await _shot("bh%d" % lv, 0.9)
	Events.blackhole_warning.emit(0, 0.0)

func _t_markers() -> void:
	# nav target far to the side / behind the camera -> clamped edge arrow; plus scanner markers if a player exists
	var sys: SystemDef = Universe.system
	var pick := 5
	_game.nav_target = pick
	Events.nav_target_changed.emit(pick)
	await _shot("nav_marker", 0.6)
	if _game.player != null and is_instance_valid(_game.player):
		var cam: Camera3D = _game.active_camera()
		var f := -cam.global_transform.basis.z
		var r := cam.global_transform.basis.x
		var base := cam.global_position
		var mk: Array = []
		mk.append({"pos": base + f * 45.0 + r * 8.0, "label": "Monolith", "kind": "poi", "time_left": 20.0})
		mk.append({"pos": base + f * 28.0 - r * 12.0, "label": "Ferrite deposit", "kind": "resource", "time_left": 20.0})
		mk.append({"pos": base + f * 70.0 + r * -30.0, "label": "Gorm Grazer", "kind": "creature", "time_left": 20.0})
		_game.player.scan_markers = mk
		Events.scan_pulse.emit(base)
		await _shot("scan_markers", 0.7)
		_game.player.scan_markers = []
	_game.nav_target = -1
	Events.nav_target_changed.emit(-1)
	print("[uif] system bodies: ", sys.bodies.size())

func _t_flash() -> void:
	Events.screen_flash.emit(Color(1.0, 0.12, 0.06, 0.55), 1.2)
	await _frames(4)
	await _shot("damage_flash", 0.05)

func _t_keys() -> void:
	var g := _game
	await _key("galaxy_map")
	_check(g.overlay_open and g.galaxy_map.visible, "M opens the galaxy map")
	await _key("system_map")
	_check(g.overlay_open and g.system_map.visible and not g.galaxy_map.visible, "N while the map is open switches to the system map")
	await _key("inventory")
	_check(g.overlay_open and g.inventory_panel.visible and not g.system_map.visible, "I switches to the inventory")
	await _key("controls")
	_check(g.overlay_open and g.controls_panel.visible and not g.inventory_panel.visible, "F1 switches to the controls overview")
	await _key("pause")
	_check(not g.overlay_open and not g.controls_panel.visible and g.state == g.State.PLAYING, "Esc closes the overlay (no pause)")
	await _key("pause")
	_check(g.state == g.State.PAUSED and g.pause_menu.visible and g.get_tree().paused, "Esc again opens the pause menu")
	await _key("galaxy_map")
	_check(not g.galaxy_map.visible, "M is ignored while paused")
	await _key("controls")
	_check(not g.controls_panel.visible, "F1 is ignored while paused (Controls button is used there)")
	await _click_btn(g.pause_menu, "CONTROLS")
	await _frames(3)
	_check(g.controls_panel.visible, "pause menu CONTROLS button opens the overview")
	await _shot("controls_from_pause", 0.5)
	await _key("pause")
	_check(not g.controls_panel.visible and g.state == g.State.PAUSED, "Esc closes the controls but stays paused")
	await _key("pause")
	_check(g.state == g.State.PLAYING and not g.pause_menu.visible and not g.get_tree().paused, "Esc resumes the game")
	await _key("controls")
	_check(g.controls_panel.visible, "F1 opens the controls overview in game")
	await _shot("controls_f1", 0.4)
	await _key("controls")
	_check(not g.controls_panel.visible and not g.overlay_open, "F1 closes it again")
	await _key("system_map")
	await _key("system_map")
	_check(not g.overlay_open, "N toggles the system map off again")

func _t_mouse() -> void:
	var blockers: Array = []
	_scan_blockers(_game.ui_root, blockers)
	_scan_blockers(_game.overlay_root, blockers)
	for b in blockers:
		print("[uif] mouse blocker while playing: ", b)
	_check(blockers.is_empty(), "no visible UI element captures the mouse while playing (%d found)" % blockers.size())

func _t_settings() -> void:
	var g := _game
	g.toggle_pause()
	await _frames(5)
	await _click_btn(g.pause_menu, "SETTINGS")
	await _frames(3)
	var sp: SettingsPanel = g.pause_menu._settings
	_check(sp.visible, "pause menu SETTINGS opens the settings page")
	await _shot("settings_default", 0.4)
	# click each slider at 75 % of its width
	var targets := {"fov": 0.8, "mouse_sens": 0.5, "volume": 0.3, "ui_scale": 0.5}
	for k in targets:
		var s: UISlider = sp._rows[k]
		var f: float = targets[k]
		var r := s.get_global_rect()
		await _click(Vector2(r.position.x + 8.0 + f * (r.size.x - 16.0), r.get_center().y))
	var want_fov := 60.0 + 0.8 * 50.0
	_check(absf(float(g.settings["fov"]) - want_fov) < 3.0, "FOV slider writes Game.settings (fov=%.1f want ~%.0f)" % [float(g.settings["fov"]), want_fov])
	_check(absf(float(g.settings["mouse_sens"]) - (0.2 + 0.5 * 2.8)) < 0.2, "sensitivity slider writes Game.settings (%.2f)" % float(g.settings["mouse_sens"]))
	_check(absf(float(g.settings["volume"]) - 0.3) < 0.05, "volume slider writes Game.settings (%.2f)" % float(g.settings["volume"]))
	_check(absf(Audio.master_volume - float(g.settings["volume"])) < 0.001, "volume is applied to Audio (%.2f)" % Audio.master_volume)
	# toggles
	var tg: UIToggle = sp._rows["show_fps"]
	await _click(tg.get_global_rect().get_center())
	_check(bool(g.settings["show_fps"]), "FPS toggle writes Game.settings")
	var tinv: UIToggle = sp._rows["invert_y"]
	await _click(tinv.get_global_rect().get_center())
	_check(bool(g.settings["invert_y"]), "invert-Y toggle writes Game.settings")
	await _shot("settings_changed", 0.4)
	# Esc from the settings page goes back to the pause page
	await _key("pause")
	_check(not sp.visible and g.pause_menu.visible, "Esc leaves the settings page first")
	await _key("pause")
	await _frames(3)
	# FOV applied to the live camera (ship rig lerps towards the setting)
	await _sec(1.5)
	var cam: Camera3D = g.active_camera()
	_check(cam != null and absf(cam.fov - want_fov) < 8.0, "live camera FOV follows the setting (cam %.1f, setting %.1f)" % [cam.fov if cam != null else -1.0, want_fov])
	# sensitivity + invert reach Game.mouse_look_delta (needs captured mouse; check the formula inputs only)
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(10, 10)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var d: Vector2 = g.mouse_look_delta(ev)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_check(d.y < 0.0 and absf(d.x) > 0.0, "mouse_look_delta honours sensitivity / invert-Y (%s)" % str(d))
	await _shot("hud_fps_on", 0.3)
	# restore defaults through the button
	g.toggle_pause()
	await _frames(4)
	await _click_btn(g.pause_menu, "SETTINGS")
	await _click_btn(g.pause_menu, "RESET DEFAULTS")
	_check(absf(float(g.settings["fov"]) - 78.0) < 0.01 and not bool(g.settings["show_fps"]) and not bool(g.settings["invert_y"]), "RESET DEFAULTS restores the defaults")
	g.resume()
	await _frames(4)

func _t_map() -> void:
	var g := _game
	await _key("galaxy_map")
	var gm: GalaxyMap = g.galaxy_map
	_check(g.overlay_open and gm.visible, "galaxy map open")
	await _sec(2.2)
	await _shot("map_default", 0.2)
	# a star in the middle of the screen's nearby list: hover + click
	var near := Universe.nearest_stars(Universe.current_id, 3)
	var sid: int = (near[0] as GalaxyStar).id
	gm._focus_on(sid, 5000.0)
	await _sec(2.5)
	var sp: Vector2 = gm._screen[sid]
	await _move(sp)
	await _sec(0.4)
	_check(gm._hover == sid, "hovering a star highlights it (hover=%d want %d at %s)" % [gm._hover, sid, str(sp)])
	await _shot("map_hover", 0.2)
	await _click(sp)
	_check(gm._selected == sid, "clicking a star selects it (selected=%d)" % gm._selected)
	await _shot("map_selected", 0.6)
	# warp refusal reasons
	g.warp_cells = 0
	gm._engage()
	await _frames(4)
	_check(gm._msg_text != "", "warp refused shows a reason: '%s'" % gm._msg_text)
	await _shot("map_warp_refused", 0.4)
	g.warp_cells = 2
	# black hole link: select the BH destination
	var dest := Universe.black_hole_destination(Universe.current_id)
	gm._selected = dest
	gm._focus_on(dest, 9000.0)
	await _sec(2.5)
	_check(dest >= 0, "home system has a black-hole link (dest=%d)" % dest)
	await _shot("map_blackhole_dest", 0.5)
	gm._view_galaxy()
	gm._selected = -1
	gm._t_pitch = 0.45
	await _sec(2.5)
	await _shot("map_tilted", 0.2)
	# zoom with the wheel, orbit by dragging
	var c := Vector2(720, 405)
	var before_d: float = gm._t_dist
	for i in 3:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.position = _px(c)
		Input.parse_input_event(ev)
		await _frames(2)
	_check(gm._t_dist < before_d, "mouse wheel zooms (%.0f -> %.0f)" % [before_d, gm._t_dist])
	await _key("galaxy_map")
	_check(not g.overlay_open and not gm.visible, "M closes the galaxy map")
	_check(not g.get_viewport().disable_3d, "3D rendering is back after closing the map")

func _t_system() -> void:
	var g := _game
	await _key("system_map")
	var sm: SystemMap = g.system_map
	_check(g.overlay_open and sm.visible, "system map open")
	await _sec(1.5)
	await _shot("system_open", 0.2)
	var target := 3
	var tp: Vector2 = sm._disp[target]
	await _click(tp)
	_check(sm._selected == target, "clicking a body selects it on the system map (sel=%d)" % sm._selected)
	await _shot("system_selected", 0.5)
	await _click_btn(sm, "SET NAVIGATION TARGET")
	_check(g.nav_target == target, "SET NAVIGATION TARGET sets Game.nav_target (=%d)" % g.nav_target)
	await _shot("system_nav_set", 0.4)
	# orbit animation: positions change over time
	var p0: Vector2 = sm._disp[4]
	await _sec(1.5)
	var p1: Vector2 = sm._disp[4]
	_check(p0.distance_to(p1) > 0.3, "orbits are animated (moved %.1f px)" % p0.distance_to(p1))
	await _key("system_map")
	var before: int = g.nav_target
	await _key("nav_next")
	_check(g.nav_target != before, "T cycles the navigation target (%d -> %d)" % [before, g.nav_target])
	await _shot("hud_nav_target", 0.8)

func _t_inventory() -> void:
	var g := _game
	g.add_resource("ferrite", 24)
	g.add_resource("zyrite", 9)
	g.add_resource("sodium", 31)
	g.add_resource("voidstone", 5)
	g.ship_fuel = 0.4
	g.ship_hull = 0.6
	await _key("inventory")
	await _shot("inventory", 0.7)
	await _click_btn(g.inventory_panel, "REFUEL PULSE DRIVE  (-1)")
	_check(g.ship_fuel > 0.45, "REFUEL button raises fuel (%.2f)" % g.ship_fuel)
	await _key("inventory")

func _t_menu() -> void:
	var g := _game
	await g.quit_to_menu()
	await _sec(1.0)
	await _shot("menu_a", 0.2)
	await _sec(5.0)
	await _shot("menu_b", 0.1)
	await _key("controls")
	await _frames(3)
	print("[uif] F1 in the main menu opens controls: ", g.controls_panel.visible)
	_check(g.controls_panel.visible, "F1 opens the controls overview from the main menu")
	if not g.controls_panel.visible:
		await _click_btn(g.main_menu, "CONTROLS")
	await _shot("menu_controls", 0.5)
	await _key("pause")
	_check(not g.controls_panel.visible, "Esc closes the controls overview in the main menu")
	await _click_btn(g.main_menu, "SETTINGS")
	await _shot("menu_settings", 0.4)
	await _click_btn(g.main_menu, "BACK")

func _t_warp() -> void:
	var g := _game
	await _key("galaxy_map")
	var gm: GalaxyMap = g.galaxy_map
	var dest := Universe.black_hole_destination(Universe.current_id)
	var near := Universe.nearest_stars(Universe.current_id, 1)
	var sid: int = (near[0] as GalaxyStar).id
	g.warp_cells = 5
	gm._selected = sid
	gm._focus_on(sid, 7000.0)
	await _sec(2.0)
	await _shot("warp_ready", 0.2)
	gm._engage()
	var t0 := Time.get_ticks_msec()
	var started := false
	while Time.get_ticks_msec() - t0 < 40000:
		await _frames(5)
		if g.warping:
			started = true
		if started and not g.warping:
			break
	_check(started, "ENTER on the selected star starts the hyperdrive jump")
	_check(Universe.current_id == sid, "arrived in the destination system (current=%d want %d)" % [Universe.current_id, sid])
	await _sec(1.5)
	await _shot("warp_arrived", 0.5)
	await _key("galaxy_map")
	await _sec(2.2)
	await _shot("map_after_warp", 0.3)
	await _key("galaxy_map")
	print("[uif] bh dest was ", dest)

func _t_foot() -> void:
	await _shot("foot_hud", 0.4)
	var blockers: Array = []
	_scan_blockers(_game.ui_root, blockers)
	_check(blockers.is_empty(), "foot mode: no UI blocks the mouse")
