extends Node
## Global state, input map, settings and the HUD message bus.

signal message(text: String, kind: String)
signal state_changed(new_state: int)

enum State { MENU, PLAYING, PAUSED, MAP, WARP }

var state: int = State.MENU
var mouse_sens := 1.0
var master_volume := 0.8
var fov_base := 75.0
var show_hud := true
var invert_y := false
var lamp_enabled := true
var stealth := false              # test mode: nothing visible, rendering into a SubViewport
var args := {}
var galaxy: Galaxy
var inventory := {}               # resource name -> amount
var discovered := {}              # body name -> true
var visited_systems := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	stealth = args.has("stealth")
	_register_inputs()
	galaxy = Galaxy.new()
	galaxy.generate(20260610)


func set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


func msg(text: String, kind := "info") -> void:
	message.emit(text, kind)


func add_resource(rname: String, amount: int) -> void:
	inventory[rname] = int(inventory.get(rname, 0)) + amount


func _key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	InputMap.action_add_event(action, ev)


func _register_inputs() -> void:
	_key("fwd", KEY_W)
	_key("back", KEY_S)
	_key("left", KEY_A)
	_key("right", KEY_D)
	_key("up", KEY_SPACE)
	_key("down", KEY_CTRL)
	_key("roll_l", KEY_Q)
	_key("roll_r", KEY_E)
	_key("boost", KEY_SHIFT)
	_key("gear", KEY_L)
	_key("use", KEY_E)
	_key("exit_ship", KEY_F)
	_key("cam", KEY_V)
	_key("target", KEY_T)
	_key("untarget", KEY_Y)
	_key("map", KEY_M)
	_key("pause", KEY_ESCAPE)
	_key("controls", KEY_F1)
	_key("hud", KEY_H)
	_key("cut", KEY_X)
	_key("scan", KEY_Q)
	_key("refill", KEY_R)
	_key("inventory", KEY_I)
	_key("confirm", KEY_ENTER)
	_key("confirm", KEY_KP_ENTER)
	_key("shot", KEY_F12)
	_key("timewarp", KEY_N)
	_key("lamp", KEY_G)
	_mouse("mine", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
