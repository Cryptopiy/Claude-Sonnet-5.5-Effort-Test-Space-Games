class_name AstronautRig
extends Node3D
## Third-person body of the player: the Blender astronaut.glb driven by procedural limb animation (module M4).
## Node pivots (docs/MODELS_SPEC.md): every limb node's origin is its joint, rotation.x > 0 swings a hanging limb's far end FORWARD (-Z).
## update_pose() is called every frame by Player with a small state dictionary; nothing here touches physics.

const NAMES := ["Hips", "Torso", "Head", "Visor", "Arm_L", "Arm_R", "Forearm_L", "Forearm_R", "Jetpack", "JetFlame_L", "JetFlame_R",
	"Leg_L", "Leg_R", "Shin_L", "Shin_R"]
## direction elbow -> hand in the forearm's local space (from the model: Anchor_Hand_R at (-0.02, -0.17, -0.20))
const FOREARM_HAND_ANGLE := 0.865     # radians the hand direction is rotated forward from "straight down"

var model: Node3D
var tool_model: Node3D
var tool_muzzle: Node3D
var jet_light: OmniLight3D

var _n: Dictionary = {}
var _rest: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _t: float = 0.0
var _aim: float = 0.0
var _tool_vis: float = 0.0
var _first_person: bool = false
var _look_pitch: float = 0.0
var _fire_shake: float = 0.0

func _ready() -> void:
	model = ModelLib.instantiate("astronaut")
	add_child(model)
	for nm in NAMES:
		var nd := ModelLib.find_node(model, nm) as Node3D
		if nd != null:
			_n[nm] = nd
			_rest[nm] = nd.transform
	_collect_meshes(model)
	for fl in ["JetFlame_L", "JetFlame_R"]:
		var f := _n.get(fl) as MeshInstance3D
		if f != null:
			_flames.append(f)
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.visible = false
	# multitool in the right hand
	var hand := ModelLib.find_node(model, "Anchor_Hand_R") as Node3D
	if hand != null:
		tool_model = ModelLib.instantiate("multitool")
		hand.add_child(tool_model)
		var d := Vector3(0.0, -0.17, -0.20).normalized()
		tool_model.transform = Transform3D(hand.transform.basis.inverse() * Basis.looking_at(d, d.rotated(Vector3.RIGHT, PI * 0.5)), Vector3.ZERO)
		tool_muzzle = ModelLib.find_node(tool_model, "Muzzle") as Node3D
		for c in _all_meshes(tool_model):
			_meshes.append(c)
	jet_light = OmniLight3D.new()
	jet_light.light_color = Color(1.0, 0.62, 0.25)
	jet_light.omni_range = 6.0
	jet_light.light_energy = 0.0
	jet_light.shadow_enabled = false
	jet_light.visible = false
	var jp := _n.get("Jetpack") as Node3D
	if jp != null:
		jp.add_child(jet_light)
		jet_light.position = Vector3(0, -1.0, 0.25)

func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		for c in n.get_children():
			stack.append(c)
	return out

func _collect_meshes(root: Node) -> void:
	for m in _all_meshes(root):
		_meshes.append(m)

## first person: the body is not drawn but still casts a shadow
func set_first_person(on: bool) -> void:
	_first_person = on
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for m in _meshes:
		if m in _flames:
			continue
		m.cast_shadow = mode

func _rot(nm: String, ax: float, ay: float = 0.0, az: float = 0.0, offset: Vector3 = Vector3.ZERO) -> void:
	var nd := _n.get(nm) as Node3D
	if nd == null:
		return
	var rest: Transform3D = _rest[nm]
	var b := rest.basis * Basis.from_euler(Vector3(ax, ay, az), EULER_ORDER_YXZ)
	nd.transform = Transform3D(b, rest.origin + offset)

## st: speed (horizontal m/s), phase (stride phase, pi per step), grounded, crouch 0..1, sprint, jet 0..1, swim, aim 0..1, pitch (rad, +up),
##     vspeed (m/s along up), fire (bool), lean (strafe -1..1), dt
func update_pose(st: Dictionary) -> void:
	var dt: float = st.get("dt", 0.016)
	_t += dt
	var speed: float = st.get("speed", 0.0)
	var phase: float = st.get("phase", 0.0)
	var grounded: bool = st.get("grounded", true)
	var crouch: float = st.get("crouch", 0.0)
	var jet: float = st.get("jet", 0.0)
	var swim: bool = st.get("swim", false)
	var aim_target: float = st.get("aim", 0.0)
	var pitch: float = st.get("pitch", 0.0)
	var vspeed: float = st.get("vspeed", 0.0)
	var fire: bool = st.get("fire", false)
	_look_pitch = pitch
	_aim = lerpf(_aim, aim_target, clampf(dt * 9.0, 0.0, 1.0))
	var walk_w := clampf(speed / 1.6, 0.0, 1.0) * (1.0 if grounded else 0.0) * (1.0 - crouch * 0.4)
	var run_k := clampf((speed - 3.0) / 8.0, 0.0, 1.0)
	var amp := lerpf(0.38, 0.95, run_k) * walk_w
	var s := sin(phase)
	var c := cos(phase)
	var air_w := 0.0 if grounded or swim else 1.0
	var breathe := sin(_t * 1.7) * 0.012

	# ---- hips / torso ----------------------------------------------------------------------------------------------------
	var bob := (cos(phase * 2.0) * 0.5 - 0.5) * 0.045 * walk_w * (0.6 + run_k)
	var crouch_drop := 0.31 * crouch
	var lean := lerpf(0.04, 0.24, run_k) * walk_w + 0.18 * crouch
	var swim_pitch := 0.0
	if swim:
		swim_pitch = 1.05
	var jet_lean := clampf(speed * 0.02, 0.0, 0.3) * clampf(jet * 3.0, 0.0, 1.0)
	_rot("Hips", 0.0, s * 0.10 * walk_w, -s * 0.035 * walk_w, Vector3(0, bob - crouch_drop - (0.10 if swim else 0.0), 0))
	var torso_x := -(lean + jet_lean + swim_pitch * 0.55) + breathe + pitch * 0.12 * _aim
	_rot("Torso", torso_x, -s * 0.16 * walk_w + (0.0 if _aim < 0.5 else 0.0), s * 0.03 * walk_w)
	_rot("Head", pitch * 0.55 - torso_x * 0.55 + (0.2 * swim_pitch), s * 0.05 * walk_w, 0.0)
	_rot("Visor", 0.0)

	# ---- legs ---------------------------------------------------------------------------------------------------------------
	var thigh_l := s * amp
	var thigh_r := -s * amp
	var knee_l := -(maxf(0.0, c) * amp * 1.35 + 0.05 * walk_w)
	var knee_r := -(maxf(0.0, -c) * amp * 1.35 + 0.05 * walk_w)
	# crouch: thighs forward, shins back
	thigh_l += 1.0 * crouch
	thigh_r += 1.0 * crouch
	knee_l -= 1.8 * crouch
	knee_r -= 1.8 * crouch
	# airborne
	if air_w > 0.0:
		var rising := clampf(vspeed / 8.0, -1.0, 1.0)
		var a_l := 0.42 - rising * 0.10
		var a_r := -0.22 - rising * 0.05
		var k_l := -0.75
		var k_r := -0.25
		if jet > 0.05:
			a_l = 0.12; a_r = -0.06; k_l = -0.35; k_r = -0.2
		thigh_l = lerpf(thigh_l, a_l, air_w)
		thigh_r = lerpf(thigh_r, a_r, air_w)
		knee_l = lerpf(knee_l, k_l, air_w)
		knee_r = lerpf(knee_r, k_r, air_w)
	if swim:
		var kick := sin(_t * 7.0) * 0.45
		thigh_l = 0.2 + kick
		thigh_r = 0.2 - kick
		knee_l = -0.35 - maxf(0.0, -kick) * 0.6
		knee_r = -0.35 - maxf(0.0, kick) * 0.6
	_rot("Leg_L", thigh_l, 0.0, -0.03 - crouch * 0.07)
	_rot("Leg_R", thigh_r, 0.0, 0.03 + crouch * 0.07)
	_rot("Shin_L", knee_l)
	_rot("Shin_R", knee_r)

	# ---- arms ---------------------------------------------------------------------------------------------------------------
	var swing := amp * 0.9
	var arm_l_x := -s * swing
	var arm_r_x := s * swing
	var fore_l_x := 0.12 + run_k * 0.55 * walk_w
	var fore_r_x := 0.12 + run_k * 0.55 * walk_w
	var arm_l_z := -0.05
	var arm_r_z := 0.05
	if air_w > 0.0:
		var spread := 0.55 if jet < 0.05 else 0.28
		arm_l_x = lerpf(arm_l_x, 0.35, air_w)
		arm_r_x = lerpf(arm_r_x, 0.35, air_w)
		arm_l_z = lerpf(arm_l_z, -spread, air_w)
		arm_r_z = lerpf(arm_r_z, spread, air_w)
	if swim:
		var stroke := sin(_t * 3.2)
		arm_l_x = 1.9 + stroke * 0.9
		arm_r_x = 1.9 - stroke * 0.9
		fore_l_x = 0.2
		fore_r_x = 0.2
	# aiming / tool pose (right arm holds the multitool, left supports it)
	var aim_elev := PI * 0.5 + pitch
	var aim_arm := 1.22 + pitch * 0.6
	var aim_fore_r := aim_elev - FOREARM_HAND_ANGLE - aim_arm
	arm_r_x = lerpf(arm_r_x, aim_arm, _aim)
	fore_r_x = lerpf(fore_r_x, aim_fore_r, _aim)
	arm_r_z = lerpf(arm_r_z, -0.10, _aim)
	arm_l_x = lerpf(arm_l_x, aim_arm - 0.12, _aim)
	fore_l_x = lerpf(fore_l_x, aim_fore_r + 0.2, _aim)
	arm_l_z = lerpf(arm_l_z, 0.55, _aim)
	var shake := 0.0
	if fire:
		shake = sin(_t * 70.0) * 0.012
	_rot("Arm_L", arm_l_x + shake, 0.0, arm_l_z)
	_rot("Arm_R", arm_r_x + shake, 0.0, arm_r_z)
	_rot("Forearm_L", fore_l_x, 0.0, 0.0)
	_rot("Forearm_R", fore_r_x, 0.0, 0.0)

	# ---- jetpack flames ------------------------------------------------------------------------------------------------------
	var thrust := clampf(jet, 0.0, 1.0)
	for i in _flames.size():
		var f := _flames[i]
		f.visible = thrust > 0.03 and not _first_person
		var fl := thrust * (0.85 + 0.3 * sin(_t * 47.0 + float(i) * 2.0) + 0.1 * sin(_t * 91.0))
		f.scale = Vector3(1.0 + 0.2 * thrust, maxf(0.05, fl * 1.9), 1.0 + 0.2 * thrust)
	if jet_light != null:
		jet_light.visible = thrust > 0.03
		jet_light.light_energy = thrust * 0.9 * (0.85 + 0.15 * sin(_t * 37.0))

## world position + direction of the tool muzzle (valid in third person)
func muzzle_global() -> Transform3D:
	if tool_muzzle != null and tool_muzzle.is_inside_tree():
		return tool_muzzle.global_transform
	return global_transform

func set_tool_visible(v: bool) -> void:
	if tool_model != null:
		tool_model.visible = v

func jetpack_nozzles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in _flames:
		out.append(f.global_position)
	return out
