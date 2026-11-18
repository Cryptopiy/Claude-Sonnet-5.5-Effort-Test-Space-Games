extends RefCounted
## UI interaction test (module M6): drives the real input path (synthetic mouse events + actions) through the galaxy map, system map,
## pause menu, nav-target cycling and the HUD event feed; asserts on resulting game state and saves screenshots.
##   godot ... -- --autostart --test=res://tests/ui_interact.gd

var _game: Node
var _fails: int = 0

func _frames(n: int) -> void:
	for i in n:
		await _game.get_tree().process_frame

func _shot(name: String) -> void:
	await _game.get_tree().create_timer(0.5).timeout
	var img: Image = _game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/ui_%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[ui] shot ", name)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		print("FAIL ", msg)
		_fails += 1

## virtual canvas position -> window pixel position (what a real mouse would report)
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

func run(game: Node) -> void:
	_game = game
	await _frames(30)
	# ---------------------------------------------------------------- galaxy map: hover, select, warp refusal
	await _key("galaxy_map")
	_check(game.overlay_open and game.galaxy_map.visible, "M key opens the galaxy map")
	await _frames(60)
	var gm: GalaxyMap = game.galaxy_map
	var near := Universe.nearest_stars(Universe.current_id, 1)
	var sid: int = (near[0] as GalaxyStar).id
	gm._focus_on(sid, 4000.0)
	await game.get_tree().create_timer(1.4).timeout
	var sp: Vector2 = gm._screen[sid]
	print("[ui] star ", sid, " at ", sp, " vp=", gm.size)
	await _move(sp)
	_check(gm._hover == sid, "hovering a star highlights it (hover=%d want %d)" % [gm._hover, sid])
	await _click(sp)
	_check(gm._selected == sid, "clicking a star selects it (selected=%d)" % gm._selected)
	await _shot("map_selected")
	game.warp_cells = 0
	gm._engage()
	await _frames(5)
	_check(gm._msg_text != "" and gm._msg_t > 0.0, "warp without cells shows a reason: '%s'" % gm._msg_text)
	await _shot("map_warp_refused")
	game.warp_cells = 2
	await _key("galaxy_map")
	_check(not game.overlay_open, "M closes the galaxy map")
	# ---------------------------------------------------------------- system map: click a body = nav target, T cycles
	await _key("system_map")
	_check(game.overlay_open and game.system_map.visible, "N key opens the system map")
	await game.get_tree().create_timer(1.0).timeout
	var sm: SystemMap = game.system_map
	var target := 3
	var tp: Vector2 = sm._disp[target]
	await _click(tp)
	_check(game.nav_target == target, "clicking a body sets Game.nav_target (=%d)" % game.nav_target)
	await _shot("system_nav")
	await _key("system_map")
	await _frames(10)
	var before: int = game.nav_target
	await _key("nav_next")
	_check(game.nav_target != before, "T cycles the navigation target (%d -> %d)" % [before, game.nav_target])
	# ---------------------------------------------------------------- inventory use buttons
	game.add_resource("zyrite", 3)
	game.ship_fuel = 0.3
	await _key("inventory")
	var inv: InventoryPanel = game.inventory_panel
	inv._use("zyrite")
	_check(game.ship_fuel > 0.45, "REFUEL button consumes Zyrite and raises fuel (%.2f)" % game.ship_fuel)
	await _key("inventory")
	# ---------------------------------------------------------------- HUD feed: toasts, hints, black hole warning, flash
	Events.notify.emit("Scanner pulse found 3 points of interest", "discover")
	Events.notify.emit("Warp cell crafted  (3)", "good")
	Events.notify.emit("Hull damaged: 12% remaining", "danger")
	Events.notify.emit("Hyperdrive offline: leave the atmosphere (altitude > 1.5 km) and clear the surface first", "warn")
	Events.hint.emit("Hold LMB to mine  -  press C to scan the area", 8.0)
	Events.resource_collected.emit("ferrite", 8)
	Events.resource_collected.emit("zyrite", 4)
	Events.screen_flash.emit(Color(1, 0.2, 0.1, 0.4), 1.2)
	await _frames(20)
	await _shot("hud_toasts")
	for lv in [1, 2, 3, 4]:
		Events.blackhole_warning.emit(lv, 250000.0 / float(lv * lv))
		await game.get_tree().create_timer(0.6).timeout
		await _shot("hud_bh%d" % lv)
	Events.blackhole_warning.emit(0, 0.0)
	# ---------------------------------------------------------------- pause menu flow
	game.toggle_pause()
	await _frames(5)
	_check(game.pause_menu.visible and game.get_tree().paused, "pause menu shows and pauses the tree")
	game.resume()
	await _frames(5)
	_check(not game.pause_menu.visible, "resume hides the pause menu")
	print("[ui] interaction test done, fails=", _fails)
