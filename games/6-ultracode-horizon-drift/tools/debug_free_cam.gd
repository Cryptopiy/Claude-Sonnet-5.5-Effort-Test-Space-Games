class_name DebugFreeCam
extends Node3D
## Free-fly debug camera (a frame object, so it survives frame switches). WASD + mouse, Shift = fast (x10), Ctrl = very fast, Q/E = down/up (planet: along local up).
## Speed scales automatically with altitude above the anchored planet. Used with `--freecam` / `--preset=freecam`.

var cam: Camera3D
var speed := 40.0
var _yaw := 0.0
var _pitch := 0.0
var active := false

func _ready() -> void:
	add_to_group("frame_objects")
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.near = 0.1
	cam.far = Game.CAMERA_FAR
	cam.fov = float(Game.settings.get("fov", 75.0))
	add_child(cam)

func activate() -> void:
	active = true
	cam.make_current()

func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var d := (ev as InputEventMouseMotion).relative * 0.0025
		rotate_object_local(Vector3.UP, -d.x)
		rotate_object_local(Vector3.RIGHT, -d.y)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed *= 1.3
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed /= 1.3

func _process(dt: float) -> void:
	if not active:
		return
	var up_ref := Vector3.UP
	var alt := 100.0
	if Frame.anchor >= 0:
		up_ref = global_position.normalized()
		alt = maxf(global_position.length() - Universe.system.bodies[Frame.anchor].radius, 5.0)
	var base := clampf(alt * 0.5, 4.0, 4000.0)
	var mult := 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		mult = 10.0
	if Input.is_key_pressed(KEY_CTRL):
		mult = 60.0
	var v := Vector3.ZERO
	var b := global_transform.basis
	if Input.is_key_pressed(KEY_W): v -= b.z
	if Input.is_key_pressed(KEY_S): v += b.z
	if Input.is_key_pressed(KEY_A): v -= b.x
	if Input.is_key_pressed(KEY_D): v += b.x
	if Input.is_key_pressed(KEY_E): v += up_ref
	if Input.is_key_pressed(KEY_Q): v -= up_ref
	if v.length() > 0.0:
		global_position += v.normalized() * base * mult * dt
