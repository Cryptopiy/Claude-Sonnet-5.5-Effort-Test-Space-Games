class_name FPViewmodel
extends Node3D
## First-person view model (module M4): the Blender fp_viewmodel.glb (gloved arms + multitool) parented to the player camera.
## Built for a camera at the origin looking along -Z. This node adds sway, walk bob, sprint lower, jump/land lag, firing jitter,
## scan gesture and wall retraction on top.  The beam starts at muzzle_global().

const VM_SCALE := 0.66
const VM_OFFSET := Vector3(0.095, -0.05, -0.10)
## visual layer 20: only the viewmodel is on it (the flashlight's light_cull_mask excludes it)
const LAYER_MASK := 1 << 19

var model: Node3D
var muzzle: Node3D
var fill: OmniLight3D
var _tool: Node3D
var _tool_rest: Transform3D
var _t: float = 0.0
var _sway: Vector2 = Vector2.ZERO          # smoothed mouse lag (yaw, pitch) in radians
var _sway_vel: Vector2 = Vector2.ZERO
var _pos_off: Vector3 = Vector3.ZERO
var _pos_vel: Vector3 = Vector3.ZERO
var _rot_off: Vector3 = Vector3.ZERO
var _sprint_w: float = 0.0
var _fire_w: float = 0.0
var _scan_t: float = -1.0
var _retract: float = 0.0
var _land_kick: float = 0.0

func _ready() -> void:
	model = ModelLib.instantiate("fp_viewmodel")
	model.scale = Vector3.ONE * VM_SCALE
	model.position = VM_OFFSET
	add_child(model)
	_tool = ModelLib.find_node(model, "FP_Tool") as Node3D
	if _tool != null:
		_tool_rest = _tool.transform
		muzzle = ModelLib.find_node(_tool, "Muzzle") as Node3D
	# never cast shadows from the floating arms; they live on their own visual layer so the flashlight (which sits a few cm from the tool)
	# can skip them instead of blowing them out white
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(n as GeometryInstance3D).layers = LAYER_MASK
		for c in n.get_children():
			stack.append(c)
	# soft fill light that only touches the viewmodel, so the tool stays readable at night
	fill = OmniLight3D.new()
	fill.name = "VMFill"
	fill.light_color = Color(0.82, 0.92, 1.0)
	fill.light_energy = 0.35
	fill.omni_range = 2.5
	fill.omni_attenuation = 1.2
	fill.shadow_enabled = false
	fill.light_cull_mask = LAYER_MASK
	fill.position = Vector3(0.05, 0.28, 0.05)
	add_child(fill)

func play_scan() -> void:
	_scan_t = 0.0

func kick_land(strength: float) -> void:
	_land_kick = maxf(_land_kick, strength)

## st: speed, phase, grounded, sprint, fire, vspeed, crouch, jet, look (Vector2 radians this frame), retract (0..1 wall proximity), dt
func update_view(st: Dictionary) -> void:
	var dt: float = st.get("dt", 0.016)
	_t += dt
	var speed: float = st.get("speed", 0.0)
	var phase: float = st.get("phase", 0.0)
	var grounded: bool = st.get("grounded", true)
	var sprint: bool = st.get("sprint", false)
	var fire: bool = st.get("fire", false)
	var vspeed: float = st.get("vspeed", 0.0)
	var crouch: float = st.get("crouch", 0.0)
	var look: Vector2 = st.get("look", Vector2.ZERO)
	var retract_target: float = st.get("retract", 0.0)
	var jet: float = st.get("jet", 0.0)
	var bob_on: bool = st.get("bob", true)

	_sprint_w = lerpf(_sprint_w, 1.0 if (sprint and speed > 6.0 and grounded) else 0.0, clampf(dt * 7.0, 0.0, 1.0))
	_fire_w = lerpf(_fire_w, 1.0 if fire else 0.0, clampf(dt * 12.0, 0.0, 1.0))
	_retract = lerpf(_retract, retract_target, clampf(dt * 14.0, 0.0, 1.0))
	_land_kick = maxf(0.0, _land_kick - dt * 3.0)

	# mouse look lag: the weapon trails the view then springs back
	_sway_vel += Vector2(-look.x, look.y) * 22.0
	_sway_vel -= _sway * 160.0 * dt
	_sway_vel *= exp(-9.0 * dt)
	_sway += _sway_vel * dt
	_sway = _sway.clamp(Vector2(-0.12, -0.10), Vector2(0.12, 0.10))

	var walk_w := clampf(speed / 3.0, 0.0, 1.0) * (1.0 if grounded else 0.0)
	var bob_amp := (0.5 + 0.5 * clampf((speed - 4.0) / 6.0, 0.0, 1.0)) * walk_w
	if not bob_on:
		bob_amp *= 0.25
	var bx := cos(phase) * 0.012 * bob_amp
	var by := -absf(sin(phase)) * 0.016 * bob_amp
	var breathe := sin(_t * 1.6) * 0.0025 + sin(_t * 0.9) * 0.0015

	var target := Vector3(bx - _sway.x * 0.35, by + breathe + _sway.y * 0.25, 0.0)
	# falling / jumping lag
	target.y -= clampf(vspeed * 0.0035, -0.03, 0.03)
	target.y -= _land_kick * 0.05
	target.y -= crouch * 0.01
	# sprint: tool lowered and pulled in
	var rot := Vector3(0.0, 0.0, 0.0)
	rot.x = -_sway.y * 0.6
	rot.y = _sway.x * 0.7
	rot.z = bx * 1.8
	rot.x -= _sprint_w * 0.32
	rot.y += _sprint_w * 0.20
	target.y -= _sprint_w * 0.07
	target.x += _sprint_w * 0.05
	target.z += _sprint_w * 0.03
	# jetpack: arms braced
	rot.x += jet * 0.05
	# firing jitter
	if _fire_w > 0.01:
		target += Vector3(sin(_t * 61.0), sin(_t * 73.0 + 1.0), 0.0) * 0.0016 * _fire_w
		target.z += 0.012 * _fire_w
		rot.x += 0.015 * _fire_w
	# scan gesture: push forward, tilt up, return
	if _scan_t >= 0.0:
		_scan_t += dt
		var u := clampf(_scan_t / 0.9, 0.0, 1.0)
		var env := sin(u * PI)
		target.z -= 0.05 * env
		target.y += 0.02 * env
		rot.x += 0.28 * env
		if u >= 1.0:
			_scan_t = -1.0
	# wall retraction
	target.z += _retract * 0.26
	target.y -= _retract * 0.07
	rot.x -= _retract * 0.45
	_pos_off = _pos_off.lerp(target, clampf(dt * 16.0, 0.0, 1.0))
	_rot_off = _rot_off.lerp(rot, clampf(dt * 16.0, 0.0, 1.0))
	transform = Transform3D(Basis.from_euler(_rot_off, EULER_ORDER_YXZ), _pos_off)

func muzzle_global() -> Transform3D:
	if muzzle != null and muzzle.is_inside_tree():
		return muzzle.global_transform
	return global_transform

## tint the cyan glow / energy accents of the multitool (e.g. while mining a coloured resource)
func set_glow_energy(e: float) -> void:
	pass
