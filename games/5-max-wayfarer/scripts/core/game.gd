extends Node
## Autoload "Game": input map, settings, shared state and notification bus.

signal message(text: String, secs: float, kind: String)
signal paused_changed(p: bool)
signal discovery(text: String)
signal settings_applied
signal sfx(name: String, volume_db: float, pitch: float)

const ACTIONS := {
	# flight
	"thrust_fwd": [KEY_W], "thrust_back": [KEY_S], "strafe_left": [KEY_A], "strafe_right": [KEY_D],
	"thrust_up": [KEY_SPACE], "thrust_down": [KEY_CTRL, KEY_C], "roll_left": [KEY_Q], "roll_right": [KEY_E],
	"boost": [KEY_SHIFT], "pulse": [KEY_X], "land_assist": [KEY_L], "cycle_target": [KEY_T], "auto_pulse": [KEY_Z],
	"camera_toggle": [KEY_V], "interact": [KEY_F], "scan": [KEY_R], "map": [KEY_M, KEY_TAB], "pause": [KEY_ESCAPE],
	"help": [KEY_H, KEY_F1], "mine": [], "recharge": [KEY_G], "warp_confirm": [KEY_ENTER],
	# on foot
	"move_fwd": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "time_skip": [KEY_Y],
}

var mouse_delta: Vector2 = Vector2.ZERO
var mouse_sens: float = 1.0
var invert_y: bool = false
var fov_setting: float = 75.0
var master_volume: float = 0.8
var show_hints: bool = true
var show_fps: bool = false
var quality: int = 2                       # 0 low, 1 medium, 2 high
var in_game: bool = false
var paused: bool = false
var map_open: bool = false
var current_system_index: int = 0
var discovered: Dictionary = {}
var stats: Dictionary = {"distance": 0.0, "landings": 0, "bh_jumps": 0, "warps": 0, "scans": 0, "collected": 0}
var inventory: Dictionary = {"carbon": 20, "ferrite": 20, "sodium": 12, "warp_cells": 3}
var collected_items: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_register_actions()
	load_settings()
	# automated test runs are throttled through an environment variable so they stay light on a shared GPU
	var cap: String = OS.get_environment("WAYFARER_MAX_FPS")
	if cap != "":
		Engine.max_fps = clampi(int(cap), 5, 240)

const SETTINGS_PATH := "user://wayfarer_settings.cfg"

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("input", "mouse_sens", mouse_sens)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("video", "fov", fov_setting)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("audio", "master", master_volume)
	cf.save(SETTINGS_PATH)

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		mouse_sens = float(cf.get_value("input", "mouse_sens", mouse_sens))
		invert_y = bool(cf.get_value("input", "invert_y", invert_y))
		fov_setting = float(cf.get_value("video", "fov", fov_setting))
		quality = int(cf.get_value("video", "quality", quality))
		show_fps = bool(cf.get_value("video", "show_fps", show_fps))
		master_volume = float(cf.get_value("audio", "master", master_volume))
	elif DisplayServer.screen_get_size().y > 1500:
		quality = 1                    # first start on a 4K-class screen: MSAA 2x keeps the frame rate comfortable
	apply_settings()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(quality, 0, 2)]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	settings_applied.emit()

func _register_actions() -> void:
	for a in ACTIONS.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("mine", mb)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_delta += (event as InputEventMouseMotion).relative
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).physical_keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

func consume_mouse() -> Vector2:
	var d: Vector2 = mouse_delta
	mouse_delta = Vector2.ZERO
	return d

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	sfx.emit(sfx_name, volume_db, pitch)

func notify(text: String, secs: float = 3.5, kind: String = "info") -> void:
	message.emit(text, secs, kind)

func set_paused(p: bool) -> void:
	paused = p
	paused_changed.emit(p)

func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	mouse_delta = Vector2.ZERO

func discover(key: String, text: String) -> void:
	if not discovered.has(key):
		discovered[key] = true
		discovery.emit(text)

func add_item(kind: String, amount: int) -> void:
	inventory[kind] = int(inventory.get(kind, 0)) + amount
	stats["collected"] = int(stats["collected"]) + amount

func get_item(kind: String) -> int:
	return int(inventory.get(kind, 0))
