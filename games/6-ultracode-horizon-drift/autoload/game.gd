extends Node
## GAME: top-level state machine and orchestration (menu / playing / paused, ship <-> on-foot, system loading, warps), input map,
## shared persistent state (fuel, hull, warp cells, inventory) and the HUD telemetry blackboard.
## See docs/ARCHITECTURE.md for the module contracts this file relies on.

enum State { MENU, PLAYING, PAUSED }
enum Mode { SHIP, FOOT, WARP }

## Camera clip planes. HARD RULE: far/near <= 2e7 or Godot's light culler spams 'create_frustum_points' errors (measured: ok 0.1/2e6, 0.3/6e6, 0.3/8e6;
## errors 0.1/2.5e6, 0.2/8e6, 0.05/2e6). Reverse-Z keeps depth precision fine at these ratios. Use these constants for EVERY gameplay camera.
const CAMERA_NEAR_SHIP := 0.3
const CAMERA_FAR_SHIP := 6.0e6
const CAMERA_NEAR_FOOT := 0.1
const CAMERA_FAR_FOOT := 2.0e6
const CAMERA_FAR := 2.0e6     # generic default (use with near >= 0.1)

## action -> {keys:[physical keycodes], mouse:[buttons], label, section}. Registered at startup (no project.godot input map needed).
const ACTIONS := {
	"move_forward": {"keys": [KEY_W], "label": "Thrust forward / walk forward", "section": "Movement"},
	"move_back": {"keys": [KEY_S], "label": "Thrust back / walk back", "section": "Movement"},
	"move_left": {"keys": [KEY_A], "label": "Strafe left", "section": "Movement"},
	"move_right": {"keys": [KEY_D], "label": "Strafe right", "section": "Movement"},
	"move_up": {"keys": [KEY_SPACE], "label": "Jump / jetpack  |  ship: ascend / take off", "section": "Movement"},
	"move_down": {"keys": [KEY_CTRL], "label": "Crouch  |  ship: descend", "section": "Movement"},
	"sprint": {"keys": [KEY_SHIFT], "label": "Sprint  |  ship: boost", "section": "Movement"},
	"roll_left": {"keys": [KEY_Q], "label": "Ship: roll left", "section": "Ship"},
	"roll_right": {"keys": [KEY_E], "label": "Ship: roll right", "section": "Ship"},
	"pulse_drive": {"keys": [KEY_X], "label": "Toggle pulse drive (interplanetary cruise)", "section": "Ship"},
	"landing_gear": {"keys": [KEY_G], "label": "Landing gear up / down", "section": "Ship"},
	"interact": {"keys": [KEY_F], "label": "Interact  |  enter / exit ship", "section": "Actions"},
	"fire": {"mouse": [MOUSE_BUTTON_LEFT], "label": "Mining beam (hold)", "section": "Actions"},
	"aim": {"mouse": [MOUSE_BUTTON_RIGHT], "label": "Zoom / secondary", "section": "Actions"},
	"scan": {"keys": [KEY_C], "label": "Scanner pulse (reveals points of interest)", "section": "Actions"},
	"toggle_light": {"keys": [KEY_L], "label": "Flashlight", "section": "Actions"},
	"toggle_camera": {"keys": [KEY_V], "label": "Change camera (chase / cockpit, first / third person)", "section": "Interface"},
	"galaxy_map": {"keys": [KEY_M], "label": "Galaxy map (hyperdrive jumps)", "section": "Interface"},
	"system_map": {"keys": [KEY_N], "label": "System map / navigation", "section": "Interface"},
	"nav_next": {"keys": [KEY_T], "label": "Cycle navigation target", "section": "Interface"},
	"inventory": {"keys": [KEY_I], "label": "Inventory", "section": "Interface"},
	"controls": {"keys": [KEY_F1], "label": "Controls overview", "section": "Interface"},
	"screenshot": {"keys": [KEY_F12], "label": "Screenshot", "section": "Interface"},
	"pause": {"keys": [KEY_ESCAPE], "label": "Pause menu", "section": "Interface"},
}

# ---- scene references (set by scenes/main.gd) ------------------------------------------------------------------------
var main: Node = null
var world: Node3D = null            # all 3D content
var local_root: Node3D = null       # parent of frame objects (ship, player, free cam ...), identity transform
var system_node: Node3D = null      # StarSystem (star + bodies), rebuilt per system
var sky: Node = null                # SkyController
var ui_root: CanvasLayer = null
var overlay_root: CanvasLayer = null
var hud: Control = null
var main_menu: Control = null
var pause_menu: Control = null
var galaxy_map: Control = null
var controls_panel: Control = null
var system_map: Control = null
var inventory_panel: Control = null
var warp_fx: Node = null            # WarpEffect (play_out/play_in coroutines)
var weather: Node = null
var fauna: Node = null

# ---- gameplay entities ---------------------------------------------------------------------------------------------------
var ship: Node3D = null             # Ship
var player: Node3D = null           # Player
var freecam: Node3D = null          # debug free camera (DebugCLI)

# ---- state ----------------------------------------------------------------------------------------------------------------
var state: int = State.MENU
var mode: int = Mode.SHIP
var overlay_open: bool = false      # a modal UI (galaxy map / controls / inventory / system map) is open: gameplay input is off
var warping: bool = false
var playing_time: float = 0.0

# ---- persistent player/ship state -----------------------------------------------------------------------------------------
var ship_fuel: float = 1.0          # pulse-drive fuel 0..1 (refilled by Zyrite)
var ship_hull: float = 1.0          # 0..1
var warp_cells: int = 2             # hyperdrive jump cost: 1 cell + 1 per 6000 ly
var inventory: Dictionary = {"ferrite": 0, "zyrite": 0, "sodium": 0, "voidstone": 0}
var discovered_bodies: Dictionary = {}     # "systemid:bodyindex" -> true
var visited_systems: Dictionary = {}
var depleted_nodes: Dictionary = {}        # resource node ids already mined (stable per seed) -> true
var nav_target: int = -1                   # body index (current system), -1 none
var settings: Dictionary = {"mouse_sens": 1.0, "fov": 78.0, "invert_y": false, "volume": 0.8, "show_fps": false, "head_bob": true}

## HUD telemetry blackboard. Ship/Player/etc write; HUD reads. Documented keys (all optional):
##  "speed" (m/s)  "altitude" (m above ground, -1 if none)  "state" (String: "SPACE","PULSE","ATMOSPHERE","LANDED","ON FOOT",...)
##  "fuel" "hull" "shield" "health" "protection" "jetpack" "stamina" (0..1)  "throttle" (0..1)  "pulse" (bool)  "gear" (bool)  "boost" (bool)
##  "gravity" (m/s^2)  "temp_c"  "hazard" (String)  "hazard_level" (0..1)  "target_dist" (m)  "vspeed" (m/s)
var tel: Dictionary = {}
var context_hint: String = ""       # set by modules every frame while relevant ("Press F to enter ship"); cleared each frame

var _screenshot_n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 200
	_setup_input()
	Events.player_died.connect(_on_player_died)

# =====================================================================================================================
# input
# =====================================================================================================================
func _setup_input() -> void:
	for action in ACTIONS:
		var a: Dictionary = ACTIONS[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in a.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for mb in a.get("mouse", []):
			var mev := InputEventMouseButton.new()
			mev.button_index = mb
			InputMap.action_add_event(action, mev)

## gameplay (ship/player/camera) input is allowed
func input_enabled() -> bool:
	return state == State.PLAYING and not overlay_open and not warping and not get_tree().paused

## helper for look-around: returns mouse delta scaled by settings; call from _unhandled_input / _input
func mouse_look_delta(ev: InputEvent) -> Vector2:
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and input_enabled():
		var d: Vector2 = (ev as InputEventMouseMotion).relative * 0.0022 * float(settings["mouse_sens"])
		if settings["invert_y"]:
			d.y = -d.y
		return d
	return Vector2.ZERO

func _unhandled_input(ev: InputEvent) -> void:
	if state == State.MENU:
		return
	if ev.is_action_pressed("pause"):
		if overlay_open:
			close_overlays()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("screenshot"):
		take_screenshot()
	elif state == State.PLAYING and not warping:
		if ev.is_action_pressed("controls"):
			toggle_overlay("controls")
		elif ev.is_action_pressed("galaxy_map"):
			toggle_overlay("map")
		elif ev.is_action_pressed("system_map"):
			toggle_overlay("system")
		elif ev.is_action_pressed("inventory"):
			toggle_overlay("inventory")

func _process(delta: float) -> void:
	context_hint = ""   # modules (priority < 200) set it earlier in the same frame; HUD (priority 0..100) already read it
	if state == State.PLAYING and not get_tree().paused:
		playing_time += delta
	_update_mouse_mode()

func _update_mouse_mode() -> void:
	var want := Input.MOUSE_MODE_VISIBLE
	if state == State.PLAYING and not overlay_open and not warping and not get_tree().paused:
		want = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want

func take_screenshot() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var img := get_viewport().get_texture().get_image()
	_screenshot_n += 1
	var path := "user://screenshots/horizon_drift_%d_%d.png" % [Time.get_ticks_msec(), _screenshot_n]
	img.save_png(path)
	Events.notify.emit("Screenshot saved", "info")

# =====================================================================================================================
# scene registration (called by scenes/main.gd)
# =====================================================================================================================
func register_main(p_main: Node, p_world: Node3D, p_local: Node3D, p_ui: CanvasLayer, p_overlay: CanvasLayer) -> void:
	main = p_main
	world = p_world
	local_root = p_local
	ui_root = p_ui
	overlay_root = p_overlay

# =====================================================================================================================
# overlays / pause
# =====================================================================================================================
func toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		Events.game_paused.emit(true)
	elif state == State.PAUSED:
		resume()

func resume() -> void:
	if state == State.PAUSED:
		state = State.PLAYING
		get_tree().paused = false
		Events.game_paused.emit(false)

func toggle_overlay(kind: String) -> void:
	var panel: Control = _overlay_node(kind)
	if panel == null:
		return
	var opening := not panel.visible
	close_overlays()
	if opening:
		if panel.has_method("open"):
			panel.call("open")
		else:
			panel.visible = true
		overlay_open = true

func close_overlays() -> void:
	for kind in ["map", "controls", "system", "inventory"]:
		var panel: Control = _overlay_node(kind)
		if panel != null and panel.visible:
			if panel.has_method("close"):
				panel.call("close")
			else:
				panel.visible = false
	overlay_open = false

func _overlay_node(kind: String) -> Control:
	match kind:
		"map": return galaxy_map
		"controls": return controls_panel
		"system": return system_map
		"inventory": return inventory_panel
	return null

# =====================================================================================================================
# starting / ending a game
# =====================================================================================================================
## opts: preset ("landed" default | "foot" | "air" | "space" | "bh" | "star" | "freecam"), body (int), alt (m), dist_km, sun (deg), system (id)
func start_game(opts: Dictionary = {}) -> void:
	if state != State.MENU:
		await end_game()
	warping = true
	_reset_state()
	Events.game_started.emit()
	var sid: int = int(opts.get("system", Universe.HOME_ID))
	await load_system(sid)
	await _spawn_entities(opts)
	warping = false
	state = State.PLAYING
	get_tree().paused = false
	if main_menu:
		main_menu.visible = false
	if hud:
		hud.visible = true
	await get_tree().process_frame
	Events.hint.emit("Press W / Space to lift off  -  G toggles landing gear  -  F1 shows all controls", 9.0)

func _reset_state() -> void:
	ship_fuel = 1.0
	ship_hull = 1.0
	warp_cells = 2
	for k in inventory:
		inventory[k] = 0
	discovered_bodies.clear()
	visited_systems.clear()
	depleted_nodes.clear()
	nav_target = -1
	playing_time = 0.0
	tel = {}
	Universe.time = Universe.START_TIME

func end_game() -> void:
	state = State.MENU
	get_tree().paused = false
	close_overlays()
	for n in [ship, player, freecam]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	ship = null
	player = null
	freecam = null
	Frame.focus = null
	if system_node != null:
		system_node.queue_free()
		system_node = null
	Universe.body_nodes = []
	await get_tree().process_frame
	if hud:
		hud.visible = false
	Events.returned_to_menu.emit()

func quit_to_menu() -> void:
	await end_game()
	if main_menu:
		main_menu.visible = true
	if pause_menu:
		pause_menu.visible = false

## (re)build the 3D system for galaxy star `id`
func load_system(id: int) -> void:
	if system_node != null:
		system_node.queue_free()
		system_node = null
		await get_tree().process_frame
	Frame.clear_space_objects()
	var sys := Universe.set_current(id)
	visited_systems[id] = true
	system_node = StarSystem.new()
	system_node.name = "System"
	world.add_child(system_node)
	world.move_child(system_node, 0)
	system_node.call("build", sys)
	Events.system_loaded.emit(id)

# =====================================================================================================================
# spawning + presets
# =====================================================================================================================
func _spawn_entities(opts: Dictionary) -> void:
	var sys := Universe.system
	ship = Ship.new()
	ship.name = "Ship"
	local_root.add_child(ship)
	player = Player.new()
	player.name = "Player"
	local_root.add_child(player)
	var preset: String = str(opts.get("preset", "landed"))
	var body_i: int = int(opts.get("body", sys.start_body))
	if body_i < 0 or body_i >= sys.bodies.size():
		body_i = sys.start_body
	var b: BodyDef = sys.bodies[body_i]
	match preset:
		"landed", "foot":
			if not b.landable:
				body_i = sys.start_body
				b = sys.bodies[body_i]
			var dir := PoiSites.start_dir(b)
			Universe.time = Universe.time_for_sun_elevation(body_i, dir, float(opts.get("sun", 14.0)), Universe.START_TIME, true)
			Frame.set_body_frame(body_i)
			ship.call("place_landed", dir, float(opts.get("yaw", 0.0)))
			_set_mode(Mode.SHIP)
			if preset == "foot":
				await get_tree().process_frame
				exit_ship(true)
		"air":
			if not b.landable and not b.is_gas_giant():
				body_i = sys.start_body
				b = sys.bodies[body_i]
			var dir2 := PoiSites.start_dir(b)
			Universe.time = Universe.time_for_sun_elevation(body_i, dir2, float(opts.get("sun", 25.0)), Universe.START_TIME, true)
			Frame.set_body_frame(body_i)
			ship.call("place_flying", dir2, float(opts.get("alt", 800.0)), float(opts.get("speed", 60.0)))
			_set_mode(Mode.SHIP)
		"space":
			var bp := Universe.body_pos(body_i)
			var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
			var dist := float(opts.get("dist_km", 400.0)) * 1000.0
			var side := to_star.cross(Vector3.UP).normalized()
			place_ship_abs(bp.add_v3(to_star * dist + side * dist * 0.25), -(to_star + side * 0.25).normalized())
			_set_mode(Mode.SHIP)
		"star":
			var dist2 := float(opts.get("dist_km", 600.0)) * 1000.0
			place_ship_abs(DVec.new(dist2, dist2 * 0.1, 0.0), Vector3.LEFT)
			_set_mode(Mode.SHIP)
		"bh":
			if sys.black_hole_index < 0:
				push_warning("Game: this system has no black hole")
			else:
				var bhp := Universe.body_pos(sys.black_hole_index)
				var dir3 := Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
				var dist3 := float(opts.get("dist_km", 300.0)) * 1000.0
				place_ship_abs(bhp.add_v3(dir3 * dist3), -dir3)
				_set_mode(Mode.SHIP)
		"freecam":
			if b.landable:
				Frame.set_body_frame(body_i)
			else:
				Frame.set_space_frame(Universe.body_pos(body_i).add_v3(Vector3(0, 0, b.radius * 4.0)))
			_set_mode(Mode.SHIP)
		_:
			push_warning("Game: unknown preset '%s'" % preset)
	_apply_focus()

## place the ship at an absolute position (picks the right frame automatically)
func place_ship_abs(abs_pos: DVec, forward_abs: Vector3, velocity_abs: Vector3 = Vector3.ZERO) -> void:
	var want := Frame.desired_anchor(abs_pos)
	if want >= 0:
		Frame.set_body_frame(want)
	else:
		Frame.set_space_frame(abs_pos)
	var lp := Frame.to_local(abs_pos)
	var fwd := Frame.abs_dir_to_local(forward_abs).normalized()
	var up := Frame.abs_dir_to_local(Vector3.UP)
	if absf(fwd.dot(up)) > 0.98:
		up = Frame.abs_dir_to_local(Vector3.RIGHT)
	var bas := Basis.looking_at(fwd, up)
	ship.call("place_free", lp, bas, Frame.abs_dir_to_local(velocity_abs) - Frame.basis * Frame.origin_vel)

func _apply_focus() -> void:
	if mode == Mode.FOOT and player != null:
		Frame.set_focus(player)
	elif ship != null:
		Frame.set_focus(ship)

func _set_mode(m: int) -> void:
	mode = m
	Events.mode_changed.emit(m)
	_apply_focus()

func active_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

# =====================================================================================================================
# ship <-> on foot
# =====================================================================================================================
func exit_ship(force: bool = false) -> void:
	if mode != Mode.SHIP or ship == null or player == null:
		return
	if not force and not bool(ship.get("is_landed")):
		Events.hint.emit("Land the ship to disembark", 3.0)
		return
	var pos: Vector3 = ship.call("exit_position")
	var up := pos.normalized()
	ship.call("set_piloted", false)
	player.call("spawn_at", pos, up, ship.call("exit_facing"))
	player.call("set_active", true)
	_set_mode(Mode.FOOT)
	Events.player_exited_ship.emit()

func enter_ship() -> void:
	if mode != Mode.FOOT or ship == null or player == null:
		return
	player.call("set_active", false)
	ship.call("set_piloted", true)
	_set_mode(Mode.SHIP)
	Events.player_entered_ship.emit()

func ship_distance_to_player() -> float:
	if ship == null or player == null:
		return INF
	return ship.global_position.distance_to(player.global_position)

func _on_player_died() -> void:
	# rescued by the ship: respawn beside it
	if ship != null and player != null and mode == Mode.FOOT:
		Events.notify.emit("Exosuit failure - emergency teleport to ship", "danger")
		var pos: Vector3 = ship.call("exit_position")
		player.call("spawn_at", pos, pos.normalized(), ship.call("exit_facing"))

# =====================================================================================================================
# warp (hyperdrive from the galaxy map, or through a black hole)
# =====================================================================================================================
## kind = "hyperdrive" | "blackhole". Cost for hyperdrive is paid by the caller (see hyperdrive_cost / try_hyperdrive).
func warp_to_system(system_id: int, kind: String) -> void:
	if warping or ship == null:
		return
	warping = true
	close_overlays()
	var old_mode := mode
	if mode == Mode.FOOT:
		enter_ship()
	var from_id := Universe.current_id
	_set_mode(Mode.WARP)
	Events.warp_started.emit(system_id, kind)
	if warp_fx != null:
		await warp_fx.call("play_out", kind)
	ship.call("on_warp_begin")
	await load_system(system_id)
	var sys := Universe.system
	var forward := Vector3.RIGHT
	var arrive := DVec.new()
	var vel := Vector3.ZERO
	if kind == "blackhole" and sys.black_hole_index >= 0:
		var bhp := Universe.body_pos(sys.black_hole_index)
		var to_star := Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
		var spawn_pos := bhp.add_v3(to_star * BlackHoleParams.SPAWN_DISTANCE)
		forward = to_star
		arrive = spawn_pos
		vel = to_star * 500.0
	else:
		arrive = Universe.hyperdrive_arrival()
		var bp := Universe.body_pos(sys.arrival_body)
		forward = Vector3(bp.x - arrive.x, bp.y - arrive.y, bp.z - arrive.z).normalized()
	Universe.time += 0.0
	player.call("set_active", false)
	place_ship_abs(arrive, forward, vel)
	ship.call("on_warp_end", kind)
	_set_mode(Mode.SHIP)
	ship.call("set_piloted", true)
	nav_target = -1
	if warp_fx != null:
		await warp_fx.call("play_in", kind)
	warping = false
	Events.warp_finished.emit(system_id)
	Events.notify.emit("Arrived in the %s system" % sys.name, "discover")

func hyperdrive_cost(system_id: int) -> int:
	var d := Universe.get_star(Universe.current_id).distance_to(Universe.get_star(system_id))
	return 1 + int(d / 6000.0)

## returns "" on success, otherwise the reason it is not possible
func try_hyperdrive(system_id: int) -> String:
	if warping:
		return "Hyperdrive already charging"
	if system_id == Universe.current_id:
		return "Already in this system"
	if mode != Mode.SHIP:
		return "Return to your ship to engage the hyperdrive"
	if ship == null or not bool(ship.call("can_hyperdrive")):
		return "Hyperdrive offline: leave the atmosphere (altitude > 1.5 km) and clear the surface first"
	var cost := hyperdrive_cost(system_id)
	if warp_cells < cost:
		return "Not enough warp cells (%d needed, %d available). Mine Voidstone: 3 = 1 cell." % [cost, warp_cells]
	warp_cells -= cost
	warp_to_system(system_id, "hyperdrive")
	return ""

# =====================================================================================================================
# resources / helpers
# =====================================================================================================================
func add_resource(id: String, amount: int) -> void:
	if not inventory.has(id):
		inventory[id] = 0
	inventory[id] += amount
	Events.resource_collected.emit(id, amount)
	if id == "voidstone":
		while inventory["voidstone"] >= 3:
			inventory["voidstone"] -= 3
			warp_cells += 1
			Events.notify.emit("Warp cell crafted  (%d)" % warp_cells, "good")
	Events.inventory_changed.emit()

## remove up to n of a resource, returns how many were actually taken
func consume_resource(id: String, n: int) -> int:
	var have: int = int(inventory.get(id, 0))
	var take := mini(have, n)
	if take > 0:
		inventory[id] = have - take
		Events.inventory_changed.emit()
	return take

func set_tel(key: String, value: Variant) -> void:
	tel[key] = value

func set_context_hint(text: String) -> void:
	context_hint = text

func is_discovered(body_index: int) -> bool:
	return discovered_bodies.has("%d:%d" % [Universe.current_id, body_index])

func mark_discovered(body_index: int) -> bool:
	var k := "%d:%d" % [Universe.current_id, body_index]
	if discovered_bodies.has(k):
		return false
	discovered_bodies[k] = true
	return true
