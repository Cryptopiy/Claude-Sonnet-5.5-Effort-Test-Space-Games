class_name Ship
extends Node3D
## The player's spacecraft. Arcade flight model with inertial dampers, boost, pulse drive, atmospheric limits,
## landing gear + landing detection against the analytic terrain, parked/landed state and chase / cockpit cameras.
## Position/velocity are expressed in the *current frame* of SpaceWorld (see space_world.gd).

enum State { FLYING, LANDED }

const ACC_FWD: float = 78.0
const ACC_SIDE: float = 40.0
const V_SPACE: float = 420.0
const V_BOOST: float = 1250.0
const V_ATM: float = 200.0
const V_ATM_BOOST: float = 430.0
const PULSE_SPEED: float = 9000.0
const MAX_RATE: float = 1.9

const GEAR_AXES := {
	"Gear_Front": [Vector3(1, 0, 0), -90.0],
	"Gear_RearL": [Vector3(1, 0, 0), -90.0],
	"Gear_RearR": [Vector3(1, 0, 0), -90.0],
}

var world: SpaceWorld
var state: int = State.FLYING
var velocity: Vector3 = Vector3.ZERO
var rates: Vector3 = Vector3.ZERO           # smoothed local pitch(x) yaw(y) roll(z) rates, rad/s
var pilot_inside: bool = true
var model: Node3D
var parts: Dictionary = {}
var foot_local: Array[Vector3] = [Vector3(0, -2.2, -4.0), Vector3(-3.0, -2.2, 3.0), Vector3(3.0, -2.2, 3.0)]
var eye_local: Vector3 = Vector3(0, 0.9, -3.0)
var exit_local: Vector3 = Vector3(-3.6, -2.2, 0.0)
var hatch_local: Vector3 = Vector3(-1.4, -0.4, 0.5)
var collider: StaticBody3D

# systems
var gear: float = 1.0
var boost_energy: float = 1.0
var boosting: bool = false
var shield: float = 100.0
var fuel: float = 100.0
var pulse_on: bool = false
var pulse_speed: float = 0.0
var auto_pulse: bool = false
var landing_assist: bool = false
var heat: float = 0.0
var thrust_vis: float = 0.0
var bank_vis: float = 0.0
var target_idx: int = -1                    # -1 none; 0..n-1 bodies; n = star; n+1 = black hole
var last_impact: float = 0.0
var bh_control_loss: float = 0.0            # 0..1 set by the black hole: reduces steering/thrust authority
var disabled_time: float = 0.0
var tidal: float = 0.0                      # 0..1 set by the black hole near the horizon (stretch + tumble)
var bh_dir: Vector3 = Vector3.ZERO
var speed_ref: float = 0.0                  # speed relative to current frame (for HUD)

# camera
var cam_mode: int = 0                       # 0 chase, 1 cockpit
var cam_basis: Basis = Basis.IDENTITY
var cam_off: Vector3 = Vector3(0, 3.4, 13.0)
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.25
var shake: float = 0.0
var cam_fov: float = 75.0
var menu_cam: bool = false                 # title-screen cinematic: ship drifts, camera orbits
var menu_orbit_t: float = 0.0

# visuals
var flames: Array[Node3D] = []
var engine_mats: Array[StandardMaterial3D] = []
var flame_lights: Array[OmniLight3D] = []
var flame_mat: ShaderMaterial
var plasma: MeshInstance3D
var plasma_mat: ShaderMaterial
var nav_lights: Array[MeshInstance3D] = []
var _land_t: float = 1.0
var _land_target_pos: Vector3
var _land_target_basis: Basis
var _t: float = 0.0
var _ground_cache: Dictionary = {}

func setup(w: SpaceWorld) -> void:
	world = w
	name = "Ship"
	model = Models.instantiate("ship_explorer")
	add_child(model)
	_set_layers(model, 1)
	_find_parts()
	_setup_engine_glow()
	_build_collider()
	_build_vfx()
	set_pilot_inside(true)

func _rel_to_model(n: Node3D) -> Vector3:
	## position of node n in the model root's space (works while outside the scene tree)
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != model:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf.origin

func _set_layers(n: Node, bits: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = bits
	for c in n.get_children():
		_set_layers(c, bits)

func _find_parts() -> void:
	for nm in ["Hull", "Cockpit_Glass", "Cockpit_Interior", "Gear_Front", "Gear_RearL", "Gear_RearR", "Engine_Glow_L", "Engine_Glow_R",
			"Marker_Eye", "Marker_EngineL", "Marker_EngineR", "Marker_Exit", "Marker_FootFront", "Marker_FootRearL", "Marker_FootRearR",
			"Marker_Headlight_L", "Marker_Headlight_R", "Marker_Hatch", "Light_Nav_L", "Light_Nav_R", "Light_Beacon"]:
		var n: Node = model.find_child(nm, true, false)
		if n == null:
			n = model.find_child(nm + "*", true, false)
		if n != null:
			parts[nm] = n
	var rel := func(n: Node3D) -> Vector3:
		return _rel_to_model(n)
	if parts.has("Marker_Eye"):
		eye_local = rel.call(parts["Marker_Eye"])
	if parts.has("Marker_Exit"):
		exit_local = rel.call(parts["Marker_Exit"])
	if parts.has("Marker_Hatch"):
		hatch_local = rel.call(parts["Marker_Hatch"])
	if parts.has("Marker_FootFront") and parts.has("Marker_FootRearL") and parts.has("Marker_FootRearR"):
		foot_local = [rel.call(parts["Marker_FootFront"]), rel.call(parts["Marker_FootRearL"]), rel.call(parts["Marker_FootRearR"])]
	if parts.has("Cockpit_Interior"):
		(parts["Cockpit_Interior"] as Node3D).visible = true

func _setup_engine_glow() -> void:
	for nm in ["Engine_Glow_L", "Engine_Glow_R"]:
		if parts.has(nm) and parts[nm] is MeshInstance3D:
			var mi: MeshInstance3D = parts[nm]
			var m: Material = mi.get_active_material(0)
			if m is StandardMaterial3D:
				var dup: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
				mi.material_override = dup
				engine_mats.append(dup)

func _build_collider() -> void:
	collider = StaticBody3D.new()
	collider.collision_layer = 0
	collider.collision_mask = 0
	var sz: Vector3 = Models.model_size("ship_explorer")
	var hull := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(maxf(sz.x * 0.3, 2.6), 2.6, maxf(sz.z * 0.85, 11.0))
	hull.shape = bs
	hull.position = Vector3(0, 0.1, 0)
	collider.add_child(hull)
	var wing := CollisionShape3D.new()
	var ws := BoxShape3D.new()
	ws.size = Vector3(maxf(sz.x * 0.9, 9.0), 0.5, 4.6)
	wing.shape = ws
	wing.position = Vector3(0, -0.3, 2.0)
	collider.add_child(wing)
	add_child(collider)

func _build_vfx() -> void:
	flame_mat = ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/flame.gdshader")
	var pos_l: Vector3 = Vector3(-1.9, 0.0, 6.4)
	var pos_r: Vector3 = Vector3(1.9, 0.0, 6.4)
	var rel := func(n: Node3D) -> Vector3:
		return _rel_to_model(n)
	if parts.has("Marker_EngineL"):
		pos_l = rel.call(parts["Marker_EngineL"])
	if parts.has("Marker_EngineR"):
		pos_r = rel.call(parts["Marker_EngineR"])
	for p in [pos_l, pos_r]:
		var pivot := Node3D.new()
		pivot.position = p
		add_child(pivot)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.62
		cone.height = 1.0
		cone.radial_segments = 14
		cone.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = flame_mat
		mi.rotation = Vector3(deg_to_rad(90.0), 0, 0)
		mi.position = Vector3(0, 0, 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 1
		pivot.add_child(mi)
		flames.append(pivot)
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.45, 0.7, 1.0)
		lt.omni_range = 22.0
		lt.light_energy = 0.0
		lt.shadow_enabled = false
		lt.position = Vector3(0, 0, 1.5)
		lt.light_cull_mask = 0xFFFFF
		pivot.add_child(lt)
		flame_lights.append(lt)
	# plasma sheath
	plasma_mat = ShaderMaterial.new()
	plasma_mat.shader = load("res://shaders/plasma.gdshader")
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	plasma = MeshInstance3D.new()
	plasma.mesh = sm
	plasma.scale = Vector3(4.6, 2.9, 9.6)
	plasma.position = Vector3(0, 0.2, -1.0)
	plasma.material_override = plasma_mat
	plasma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plasma.layers = 1 << 19
	plasma.visible = false
	add_child(plasma)

func set_pilot_inside(inside: bool) -> void:
	pilot_inside = inside

func is_landed() -> bool:
	return state == State.LANDED

# ---------------------------------------------------------------------------------------------------------
# SpaceWorld actor protocol helpers (called through PlayerController)
func convert_to_planet(rt: Basis, r_s: Vector3, vk: Vector3, om: Vector3) -> void:
	velocity = rt * (velocity - vk - om.cross(r_s))
	basis = rt * basis
	position = rt * r_s
	cam_basis = rt * cam_basis
	world.viewer_pos = position

func convert_to_system(rk: Basis, r_s: Vector3, vk: Vector3, om: Vector3) -> void:
	velocity = rk * velocity + vk + om.cross(r_s)
	basis = rk * basis
	position = Vector3.ZERO
	cam_basis = rk * cam_basis
	world.viewer_pos = Vector3.ZERO

# ---------------------------------------------------------------------------------------------------------
func planet_here() -> Planet:
	if world.frame_idx >= 0:
		return world.planets[world.frame_idx]
	return null

func up_vec() -> Vector3:
	if world.frame_idx >= 0:
		return position.normalized()
	return basis.y

func step(delta: float, controls_on: bool) -> void:
	_t += delta
	speed_ref = velocity.length()
	disabled_time = maxf(0.0, disabled_time - delta)
	shield = minf(100.0, shield + 2.5 * delta)
	if state == State.LANDED:
		_step_landed(delta, controls_on)
	else:
		_step_flying(delta, controls_on)
	_animate_gear(delta)
	_update_vfx(delta)
	if world.frame_idx >= 0:
		world.viewer_pos = position

# ----------------------------------------------------------------------------------------------- flying
func _read_stick(delta: float) -> Vector2:
	var md: Vector2 = Game.consume_mouse()
	return md

func _menu_step(delta: float) -> void:
	menu_orbit_t += delta * 0.10
	velocity = -basis.z * 26.0
	rates = Vector3.ZERO
	thrust_vis = lerpf(thrust_vis, 0.5, 1.0 - exp(-3.0 * delta))
	heat = 0.0
	_integrate(delta)

func _step_flying(delta: float, controls_on: bool) -> void:
	if menu_cam:
		_menu_step(delta)
		return
	var inp := Vector3.ZERO
	var rate_in := Vector3.ZERO
	var want_boost := false
	var ctl: float = 1.0 - bh_control_loss
	if disabled_time > 0.0:
		ctl = 0.0
	if controls_on and pilot_inside and ctl > 0.0:
		inp.z = Input.get_axis("thrust_fwd", "thrust_back")        # +1 = backwards (local +Z)
		inp.x = Input.get_axis("strafe_left", "strafe_right")
		inp.y = Input.get_axis("thrust_down", "thrust_up")
		rate_in.z = Input.get_axis("roll_right", "roll_left")
		want_boost = Input.is_action_pressed("boost")
		var md: Vector2 = Game.consume_mouse()
		var sens: float = 0.0022 * Game.mouse_sens
		var yinv: float = -1.0 if Game.invert_y else 1.0
		var steer: float = 1.0 if not pulse_on else 0.4
		if cam_mode == 0 and false:
			steer = 1.0
		rate_in.y = clampf(-md.x * sens / maxf(delta, 0.001), -MAX_RATE, MAX_RATE) * steer
		rate_in.x = clampf(-md.y * sens * yinv / maxf(delta, 0.001), -MAX_RATE, MAX_RATE) * steer
		rate_in.z *= 1.5 * steer
		if Input.is_action_just_pressed("pulse"):
			_toggle_pulse()
		if Input.is_action_just_pressed("auto_pulse"):
			_toggle_auto_pulse()
		if Input.is_action_just_pressed("cycle_target"):
			_cycle_target()
		if Input.is_action_just_pressed("land_assist"):
			_toggle_landing_assist()
		if Input.is_action_just_pressed("camera_toggle"):
			cam_mode = 1 - cam_mode
		if landing_assist and (absf(inp.z) > 0.0 or absf(inp.y) > 0.0 or absf(inp.x) > 0.0):
			landing_assist = false
			Game.notify("Landing assist cancelled", 1.5)
	elif controls_on:
		Game.consume_mouse()
	var air: float = world.air
	var in_planet: bool = world.frame_idx >= 0
	var planet: Planet = planet_here()
	# --- rotation
	var rr: float = 1.0 - minf(0.55, speed_ref / 4000.0 * 0.0)
	rates = rates.lerp(rate_in * ctl, 1.0 - exp(-11.0 * delta))
	if auto_pulse:
		_auto_pulse_steer(delta)
	elif landing_assist and in_planet:
		_landing_assist_attitude(delta)
	else:
		# gentle self-levelling inside atmosphere when not rolling
		if in_planet and air > 0.05 and rate_in.z == 0.0 and controls_on:
			var up_ref: Vector3 = position.normalized()
			var fwd: Vector3 = -basis.z
			var side: float = basis.y.cross(up_ref).dot(fwd)
			var roll_err: float = atan2(side, basis.y.dot(up_ref))
			basis = (Basis(fwd, clampf(roll_err, -1.0, 1.0) * 0.8 * delta * minf(air * 3.0, 1.0)) * basis).orthonormalized()
		var dq: Basis = Basis.from_euler(rates * delta, EULER_ORDER_YXZ)
		basis = (basis * Basis(Vector3.RIGHT, rates.x * delta) * Basis(Vector3.UP, rates.y * delta) * Basis(Vector3.BACK, rates.z * delta)).orthonormalized()
	if tidal > 0.001 and bh_dir != Vector3.ZERO:
		# tidal alignment: the nose is dragged towards the hole while the hull tumbles
		var cur: Vector3 = -basis.z
		var ang: float = cur.angle_to(bh_dir)
		var axis: Vector3 = cur.cross(bh_dir)
		if ang > 0.001 and axis.length_squared() > 1e-8:
			basis = (Basis(axis.normalized(), minf(ang, (0.3 + 2.4 * tidal) * delta)) * basis).orthonormalized()
		basis = (basis * Basis(Vector3.BACK, (1.2 + 5.5 * tidal) * tidal * delta)).orthonormalized()
	bank_vis = lerpf(bank_vis, clampf(-rates.y * 0.35, -0.6, 0.6), 1.0 - exp(-5.0 * delta))
	# --- translation
	_update_boost(delta, want_boost and inp.z < 0.0 and not pulse_on and ctl > 0.0)
	var cap: float = _speed_cap(air)
	var acc_mul: float = 2.7 if boosting else 1.0
	if pulse_on:
		_step_pulse(delta, controls_on)
	else:
		var a_local: Vector3 = Vector3(inp.x * ACC_SIDE, inp.y * ACC_SIDE, inp.z * ACC_FWD * acc_mul) * ctl
		if landing_assist and in_planet:
			a_local = Vector3.ZERO
		velocity += basis * a_local * delta
		# inertial dampers on axes without input
		var vl: Vector3 = basis.inverse() * velocity
		var damp_rate: float = 7.0 + vl.length() * 0.35 + air * 24.0
		if inp.x == 0.0 and not landing_assist:
			vl.x = move_toward(vl.x, 0.0, damp_rate * delta)
		if inp.y == 0.0 and not landing_assist:
			vl.y = move_toward(vl.y, 0.0, damp_rate * delta)
		if inp.z == 0.0 and not landing_assist:
			vl.z = move_toward(vl.z, 0.0, damp_rate * delta)
		velocity = basis * vl
		# speed limit (drag above the cap, stronger in atmosphere)
		var sp: float = velocity.length()
		if sp > cap:
			var k: float = 2.4 + air * 6.0
			if pulse_speed > 400.0:
				k = 1.6
			velocity = velocity.normalized() * lerpf(sp, cap, 1.0 - exp(-k * delta))
			if world.frame_idx >= 0 and air > 0.02:
				pass
	# decay residual pulse speed after drop-out
	if not pulse_on:
		pulse_speed = maxf(0.0, pulse_speed - 4500.0 * delta)
	# --- special zones
	_apply_environment_forces(delta)
	# --- landing assist vertical control
	if landing_assist and in_planet:
		_landing_assist_motion(delta, planet)
	# --- move
	_integrate(delta)
	_auto_gear(planet)
	# --- ground
	if in_planet and planet != null and planet.data.landable:
		_check_ground(delta, planet)
	# --- heat
	var heat_target: float = clampf((speed_ref - 110.0) / 450.0, 0.0, 1.0) * clampf(air * 7.0, 0.0, 1.0)
	heat = lerpf(heat, heat_target, 1.0 - exp(-4.0 * delta))
	thrust_vis = lerpf(thrust_vis, clampf(maxf(-inp.z, 0.0) * (1.0 if not boosting else 1.6) * ctl + (0.7 if pulse_on else 0.0) + (0.5 if auto_pulse else 0.0), 0.0, 1.8), 1.0 - exp(-8.0 * delta))
	if landing_assist:
		thrust_vis = maxf(thrust_vis, 0.35)

func _speed_cap(air: float) -> float:
	var in_planet: bool = world.frame_idx >= 0
	var base: float = V_SPACE
	var boost_cap: float = V_BOOST
	if in_planet:
		var altitude: float = world.altitude
		var thin: float = clampf(altitude / 1200.0, 0.0, 1.0)
		var cap_ground: float = lerpf(V_ATM, V_SPACE, thin * thin)
		var cap_boost: float = lerpf(V_ATM_BOOST, V_BOOST, thin * thin)
		base = lerpf(V_SPACE, cap_ground, clampf(air * 4.0, 0.0, 1.0))
		boost_cap = lerpf(V_BOOST, cap_boost, clampf(air * 4.0, 0.0, 1.0))
		if altitude < 25.0:
			base = minf(base, 90.0)
			boost_cap = minf(boost_cap, 150.0)
	return boost_cap if boosting else base

func _update_boost(delta: float, want: bool) -> void:
	if want and boost_energy > 0.04:
		boosting = true
		boost_energy = maxf(0.0, boost_energy - 0.22 * delta)
	else:
		boosting = false
		boost_energy = minf(1.0, boost_energy + 0.14 * delta)

func _integrate(delta: float) -> void:
	var d: Vector3 = velocity * delta
	if world.frame_idx < 0:
		world.viewer_sys.add_v(d)
		position = Vector3.ZERO
	else:
		position += d
	Game.stats["distance"] = float(Game.stats["distance"]) + d.length()

func _apply_environment_forces(delta: float) -> void:
	if world.frame_idx >= 0:
		return
	var sy: D3 = world.viewer_sys
	# gas giant crush depth: soft wall
	for i in world.sys.bodies.size():
		var b: BodyData = world.sys.bodies[i]
		if b.kind == "gas":
			var d: float = sy.dist(world.body_pos(i, world.time))
			if d < b.radius * 1.12:
				var out_dir: Vector3 = (sy.rel(world.body_pos(i, world.time))).normalized()
				var depth: float = 1.0 - (d / (b.radius * 1.12))
				velocity += out_dir * (260.0 + 900.0 * depth) * delta
				if _t - last_warn_time > 3.0:
					last_warn_time = _t
					Game.notify("WARNING: gas giant pressure - hull stress critical, pull up!", 3.0, "warn")
				shield = maxf(0.0, shield - 14.0 * delta)
	# star
	var sd: float = sy.length()
	var sr: float = world.sys.star_radius
	if sd < sr * 2.4:
		var heat_f: float = 1.0 - sd / (sr * 2.4)
		shield = maxf(0.0, shield - 18.0 * heat_f * delta)
		if _t - last_warn_time > 3.0:
			last_warn_time = _t
			Game.notify("WARNING: stellar radiation - shields failing", 3.0, "warn")
		if sd < sr * 1.15:
			var out2: Vector3 = sy.to_v3().normalized()
			velocity += out2 * (900.0 + 2500.0 * (1.0 - sd / (sr * 1.15))) * delta

var last_warn_time: float = -10.0
var assist_has_target: bool = false
var assist_target: Vector3 = Vector3.ZERO

# ------------------------------------------------------------------------------------------ pulse drive
func _pulse_allowed() -> bool:
	if world.frame_idx >= 0:
		return false
	if bh_control_loss > 0.2:
		return false
	var sy: D3 = world.viewer_sys
	for i in world.sys.bodies.size():
		var b: BodyData = world.sys.bodies[i]
		var lim: float = b.frame_radius * 1.9 if b.kind != "gas" else b.radius * 2.0
		if sy.dist(world.body_pos(i, world.time)) < lim:
			return false
	if sy.length() < world.sys.star_radius * 5.0:
		return false
	return true

func _toggle_pulse() -> void:
	if pulse_on:
		_stop_pulse()
		return
	if not _pulse_allowed():
		if world.frame_idx >= 0:
			Game.notify("Pulse drive offline inside a planetary gravity well", 2.5, "warn")
		else:
			Game.notify("Pulse drive offline: too close to a massive body", 2.5, "warn")
		return
	pulse_on = true
	pulse_speed = maxf(speed_ref, 300.0)
	Game.notify("PULSE DRIVE ENGAGED", 1.8)

func _stop_pulse() -> void:
	if pulse_on:
		pulse_on = false
		auto_pulse = false
		velocity = velocity.normalized() * minf(velocity.length(), 900.0)
		Game.notify("Pulse drive disengaged", 1.5)

func _step_pulse(delta: float, controls_on: bool) -> void:
	if not _pulse_allowed():
		_stop_pulse()
		return
	var target_speed: float = PULSE_SPEED
	if auto_pulse:
		var info: Dictionary = target_info()
		if info.is_empty():
			auto_pulse = false
		else:
			var d: float = float(info["dist"]) - float(info["stop"])
			target_speed = minf(PULSE_SPEED, sqrt(2.0 * 850.0 * maxf(d, 0.0)) + 150.0)
			if d <= 0.0:
				_stop_pulse()
				velocity = -basis.z * 150.0
				Game.notify("Arrived at %s" % String(info["name"]), 2.5)
				return
	pulse_speed = lerpf(pulse_speed, target_speed, 1.0 - exp(-(1.1 if target_speed > pulse_speed else 2.6) * delta))
	velocity = -basis.z * pulse_speed

func _toggle_auto_pulse() -> void:
	if auto_pulse:
		auto_pulse = false
		Game.notify("Auto-pulse cancelled", 1.5)
		return
	var info: Dictionary = target_info()
	if info.is_empty():
		Game.notify("No target selected - press T to cycle targets", 2.5, "warn")
		return
	if world.frame_idx >= 0:
		Game.notify("Leave the planetary gravity well first", 2.5, "warn")
		return
	auto_pulse = true
	if not pulse_on:
		_toggle_pulse()
		if not pulse_on:
			auto_pulse = false
			return
	Game.notify("AUTO-PULSE to %s" % String(info["name"]), 2.5)

func _auto_pulse_steer(delta: float) -> void:
	var info: Dictionary = target_info()
	if info.is_empty():
		return
	var want: Vector3 = (info["dir"] as Vector3)
	var cur: Vector3 = -basis.z
	var ang: float = cur.angle_to(want)
	if ang > 0.0005:
		var axis: Vector3 = cur.cross(want).normalized()
		var step_a: float = minf(ang, (0.9 + ang * 1.4) * delta)
		basis = (Basis(axis, step_a) * basis).orthonormalized()
	rates = rates.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta))

## Description of the current target: {name, dist, stop, dir (in current frame axes), idx}
func target_info() -> Dictionary:
	if target_idx < 0 or world.frame_idx >= 0:
		return {}
	var n: int = world.sys.bodies.size()
	var sy: D3 = world.viewer_sys
	if target_idx < n:
		var b: BodyData = world.sys.bodies[target_idx]
		var rel: Vector3 = world.body_pos(target_idx, world.time).rel(sy)
		return {"name": b.name, "dist": rel.length(), "stop": b.frame_radius * 1.02 if b.kind != "gas" else b.radius * 3.0, "dir": rel.normalized(), "idx": target_idx}
	if target_idx == n:
		var rel2: Vector3 = Vector3.ZERO - sy.to_v3()
		return {"name": world.sys.star_name, "dist": rel2.length(), "stop": world.sys.star_radius * 9.0, "dir": rel2.normalized(), "idx": target_idx}
	if target_idx == n + 1 and world.sys.has_black_hole:
		var rel3: Vector3 = world.bh_pos_sys().rel(sy)
		return {"name": "Black Hole", "dist": rel3.length(), "stop": 90000.0, "dir": rel3.normalized(), "idx": target_idx}
	return {}

func _cycle_target() -> void:
	var n: int = world.sys.bodies.size()
	var total: int = n + 1 + (1 if world.sys.has_black_hole else 0)
	target_idx = (target_idx + 1) % (total + 1)
	if target_idx == total:
		target_idx = -1
		Game.notify("Target cleared", 1.2)
		return
	if world.frame_idx >= 0:
		var nm: String = ""
		Game.notify("Target set (leave the gravity well to use auto-pulse)", 1.8)
		return
	var info: Dictionary = target_info()
	if not info.is_empty():
		Game.notify("Target: %s  (%s)" % [info["name"], U.fmt_dist(float(info["dist"]))], 2.0)

func target_name() -> String:
	var n: int = world.sys.bodies.size()
	if target_idx < 0:
		return ""
	if target_idx < n:
		return world.sys.bodies[target_idx].name
	if target_idx == n:
		return world.sys.star_name
	return "Black Hole"

## Target position as an offset from the viewer in current frame axes (for HUD markers)
func target_vector(idx: int) -> Vector3:
	var n: int = world.sys.bodies.size()
	if world.frame_idx < 0:
		var sy: D3 = world.viewer_sys
		if idx < n:
			return world.body_pos(idx, world.time).rel(sy)
		if idx == n:
			return Vector3.ZERO - sy.to_v3()
		return world.bh_pos_sys().rel(sy)
	var k: int = world.frame_idx
	var pk: D3 = world.body_pos(k, world.time)
	var rt: Basis = world.body_basis(k, world.time).transposed()
	if idx < n:
		if idx == k:
			return Vector3.ZERO - position
		return rt * world.body_pos(idx, world.time).rel(pk) - position
	if idx == n:
		return rt * (Vector3.ZERO - pk.to_v3()) - position
	return rt * world.bh_pos_sys().rel(pk) - position

# ------------------------------------------------------------------------------------------ landing
func _toggle_landing_assist() -> void:
	if landing_assist:
		landing_assist = false
		Game.notify("Landing assist off", 1.5)
		return
	var p: Planet = planet_here()
	if p == null or not p.data.landable:
		Game.notify("No landable surface nearby", 2.0, "warn")
		return
	if world.altitude > 2200.0:
		Game.notify("Too high - descend below 2 km to engage landing assist", 2.5, "warn")
		return
	landing_assist = true
	pulse_on = false
	assist_has_target = false
	var best_d: float = 9000.0
	for o in p.data.outposts:
		var od: Vector3 = o["dir"]
		var tp: Vector3 = od * (p.data.radius + float(o["flat_h"]) + 0.12)
		if String(o["kind"]) != "base":
			var side: Vector3 = U.any_perp(od)
			var tp2: Vector3 = (od + side * (26.0 / p.data.radius)).normalized()
			tp = tp2 * (p.data.radius + p.ground_height(tp2) + 0.1)
		var dd: float = tp.distance_to(position)
		if dd < best_d:
			best_d = dd
			assist_target = tp
			assist_has_target = true
	if assist_has_target:
		Game.notify("LANDING ASSIST - flying to the nearest landing zone (%s)" % U.fmt_dist(best_d), 3.0)
	else:
		Game.notify("LANDING ASSIST ENGAGED", 2.0)

func _landing_assist_attitude(delta: float) -> void:
	var up_ref: Vector3 = position.normalized()
	var info: Dictionary = _ground_info(planet_here())
	var n: Vector3 = info.get("normal", up_ref)
	var fwd: Vector3 = -basis.z
	var fwd_t: Vector3 = (fwd - n * fwd.dot(n))
	if fwd_t.length_squared() < 0.01:
		fwd_t = U.any_perp(n)
	var target: Basis = U.basis_from_up(n.lerp(up_ref, 0.5).normalized(), fwd_t.normalized())
	var q: Quaternion = Quaternion(basis.orthonormalized()).slerp(Quaternion(target), 1.0 - exp(-2.2 * delta))
	basis = Basis(q)
	rates = rates.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))

func _landing_assist_motion(delta: float, planet: Planet) -> void:
	if planet == null:
		return
	var up: Vector3 = position.normalized()
	var alt: float = world.altitude
	var v_up: float = velocity.dot(up)
	var v_h: Vector3 = velocity - up * v_up
	var target_vs: float = -clampf(alt * 0.2 + 1.8, 1.8, 28.0)
	var vh_target := Vector3.ZERO
	if assist_has_target:
		var to_t: Vector3 = assist_target - position
		to_t -= up * to_t.dot(up)
		var dh: float = to_t.length()
		if dh > 5.0:
			vh_target = to_t / dh * clampf(dh * 0.33, 4.0, 75.0)
		var above: bool = dh < maxf(28.0, alt * 0.4)
		if not above:
			target_vs = 0.0 if alt < 140.0 else -clampf((alt - 140.0) * 0.2, 0.0, 18.0)
	v_h = v_h.lerp(vh_target, 1.0 - exp(-1.7 * delta))
	v_up = lerpf(v_up, target_vs, 1.0 - exp(-2.6 * delta))
	velocity = v_h + up * v_up

func _auto_gear(planet: Planet) -> void:
	var want: float = 0.0
	if world.frame_idx >= 0 and planet != null and planet.data.landable:
		if world.altitude < 90.0 and speed_ref < 140.0:
			want = 1.0
		elif gear > 0.5 and world.altitude < 160.0:
			want = 1.0
	if landing_assist:
		want = 1.0 if world.altitude < 400.0 else gear
	gear_target = want

var gear_target: float = 1.0

func _animate_gear(delta: float) -> void:
	gear = move_toward(gear, gear_target, delta * 0.75)
	for nm in GEAR_AXES.keys():
		if parts.has(nm):
			var cfg: Array = GEAR_AXES[nm]
			var ang: float = deg_to_rad(float(cfg[1])) * (1.0 - gear)
			(parts[nm] as Node3D).transform.basis = Basis(cfg[0] as Vector3, ang)

## Ground info under the three feet using the analytic terrain
func _ground_info(planet: Planet) -> Dictionary:
	if planet == null or planet.gen == null:
		return {}
	var R: float = planet.data.radius
	var min_c: float = 1e9
	var pts: Array[Vector3] = []
	var gscale: float = clampf(gear, 0.0, 1.0)
	for fl in foot_local:
		var fy: float = lerpf(-1.05, fl.y, gscale)
		var f: Vector3 = position + basis * Vector3(fl.x, fy, fl.z)
		var d: Vector3 = f.normalized()
		var gr: float = R + planet.ground_height(d) + planet.pad_bonus(f)
		var c: float = f.length() - gr
		if c < min_c:
			min_c = c
		pts.append(d * gr)
	var nrm: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	var upv: Vector3 = position.normalized()
	if nrm.dot(upv) < 0.0:
		nrm = -nrm
	# belly clearance for retracted gear
	var dc: Vector3 = upv
	var belly: float = position.length() - (R + planet.ground_height(dc) + planet.pad_bonus(position)) - 1.5
	return {"clearance": minf(min_c, belly), "normal": nrm, "feet": pts, "belly": belly}

func _check_ground(delta: float, planet: Planet) -> void:
	var alt: float = world.altitude
	if alt > 60.0:
		return
	var info: Dictionary = _ground_info(planet)
	if info.is_empty():
		return
	var c: float = float(info["clearance"])
	if c > 0.05:
		return
	var n: Vector3 = info["normal"]
	var upv: Vector3 = position.normalized()
	var vn: float = velocity.dot(upv)
	var v_h: float = (velocity - upv * vn).length()
	var slope_ok: bool = n.dot(upv) > cos(deg_to_rad(31.0))
	if gear >= 0.8 and vn > -10.0 and v_h < 34.0 and slope_ok and not pulse_on:
		if _landing_blocked():
			position += upv * 28.0
			velocity = upv * 8.0
			landing_assist = false
			Game.notify("Landing zone obstructed - trees or structures below. Find clear ground (outposts have landing zones).", 4.0, "warn")
			return
		_land(info, planet)
	else:
		# bump: push out and bounce, damage on hard impacts
		var impact: float = maxf(0.0, -velocity.dot(n))
		position += n * (0.3 - c)
		velocity = velocity - n * velocity.dot(n) * (1.0 + 0.25)
		velocity *= 0.8
		if impact > 6.0:
			shield = maxf(0.0, shield - impact * 1.6)
			last_impact = impact
			shake = maxf(shake, clampf(impact / 40.0, 0.2, 1.0))
			if shield <= 0.0:
				disabled_time = 2.0
				Game.notify("HULL BREACH - systems rebooting", 3.0, "warn")
			elif gear < 0.8:
				Game.notify("Impact! Deploy landing gear before touching down", 3.0, "warn")
			else:
				Game.notify("Hard impact - slow down for a safe landing", 3.0, "warn")

func _landing_blocked() -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7.5, 2.2, 11.0)
	q.shape = bs
	q.transform = Transform3D(basis, position + basis.y * 0.2)
	q.collision_mask = 2
	q.collide_with_areas = false
	return not space.intersect_shape(q, 1).is_empty()

func _land(info: Dictionary, planet: Planet) -> void:
	state = State.LANDED
	velocity = Vector3.ZERO
	rates = Vector3.ZERO
	landing_assist = false
	pulse_on = false
	auto_pulse = false
	_land_t = 0.0
	var n: Vector3 = info["normal"]
	var upv: Vector3 = position.normalized()
	var fwd: Vector3 = -basis.z
	fwd = (fwd - n * fwd.dot(n))
	if fwd.length_squared() < 0.001:
		fwd = U.any_perp(n)
	_land_target_basis = U.basis_from_up(n.lerp(upv, 0.15).normalized(), fwd.normalized())
	_land_target_pos = position
	# find the position at which the lowest foot touches the ground with the new attitude
	var old_basis: Basis = basis
	var old_pos: Vector3 = position
	basis = _land_target_basis
	var inf2: Dictionary = _ground_info(planet)
	var c2: float = float(inf2["clearance"])
	_land_target_pos = old_pos - upv * c2
	basis = old_basis
	Game.stats["landings"] = int(Game.stats["landings"]) + 1
	Game.notify("Touchdown on %s" % planet.data.name, 2.5)
	Game.discover("land_" + planet.data.name, "Landed on %s - %s world" % [planet.data.name, planet.data.biome_label()])
	_set_collider(true)

func _step_landed(delta: float, controls_on: bool) -> void:
	if _land_t < 1.0:
		_land_t = minf(1.0, _land_t + delta / 0.7)
		var k: float = _land_t * _land_t * (3.0 - 2.0 * _land_t)
		position = position.lerp(_land_target_pos, k * 0.35 + 0.0)
		basis = Basis(Quaternion(basis.orthonormalized()).slerp(Quaternion(_land_target_basis), minf(1.0, k * 0.5 + 0.1)))
		if _land_t >= 1.0:
			position = _land_target_pos
			basis = _land_target_basis
	if world.frame_idx >= 0:
		velocity = Vector3.ZERO
	gear_target = 1.0
	heat = lerpf(heat, 0.0, 1.0 - exp(-3.0 * delta))
	thrust_vis = lerpf(thrust_vis, 0.0, 1.0 - exp(-8.0 * delta))
	# orbit camera by mouse while parked and the pilot is inside
	if controls_on:
		var md: Vector2 = Game.consume_mouse()
		if pilot_inside:
			orbit_yaw -= md.x * 0.0035 * Game.mouse_sens
			orbit_pitch = clampf(orbit_pitch + md.y * 0.0035 * Game.mouse_sens * (-1.0 if Game.invert_y else 1.0), -0.3, 1.3)
			if Input.is_action_just_pressed("camera_toggle"):
				cam_mode = 1 - cam_mode
			# launch
			if Input.is_action_pressed("thrust_up") or Input.is_action_pressed("thrust_fwd"):
				_launch()

func _launch() -> void:
	state = State.FLYING
	_set_collider(false)
	var upv: Vector3 = position.normalized()
	velocity = upv * 10.0
	gear_target = 1.0
	Game.notify("Launch! Gear retracts above 160 m", 2.5)
	# face the ship slightly up
	cam_basis = basis

func _set_collider(on: bool) -> void:
	collider.collision_layer = 4 if on else 0

# ------------------------------------------------------------------------------------------ placement
func reset_after_transport() -> void:
	tidal = 0.0
	bh_control_loss = 0.0
	bh_dir = Vector3.ZERO
	pulse_on = false
	auto_pulse = false
	landing_assist = false
	target_idx = -1
	shake = 0.0
	if model != null:
		model.scale = Vector3.ONE
	Engine.time_scale = 1.0

func place_landed(planet_idx: int, local_pos: Vector3, fwd_hint: Vector3) -> void:
	world.frame_idx = planet_idx
	var planet: Planet = world.planets[planet_idx]
	var upv: Vector3 = local_pos.normalized()
	var f: Vector3 = (fwd_hint - upv * fwd_hint.dot(upv))
	if f.length_squared() < 0.001:
		f = U.any_perp(upv)
	basis = U.basis_from_up(upv, f.normalized())
	position = local_pos
	state = State.LANDED
	velocity = Vector3.ZERO
	gear = 1.0
	gear_target = 1.0
	var info: Dictionary = _ground_info(planet)
	var n: Vector3 = info["normal"]
	basis = U.basis_from_up(n.lerp(upv, 0.15).normalized(), f.normalized())
	info = _ground_info(planet)
	position = position - upv * float(info["clearance"])
	_land_t = 1.0
	_land_target_pos = position
	_land_target_basis = basis
	cam_basis = basis
	world.viewer_pos = position
	_set_collider(true)

func hatch_world() -> Vector3:
	return position + basis * hatch_local

func exit_world() -> Vector3:
	return position + basis * exit_local

# ------------------------------------------------------------------------------------------ visuals
func _update_vfx(delta: float) -> void:
	var th: float = thrust_vis
	for i in flames.size():
		var f: Node3D = flames[i]
		var show: bool = th > 0.03 and (pilot_inside or state == State.FLYING)
		f.visible = show
		f.scale = Vector3(1.0 + th * 0.10, 1.0 + th * 0.10, 0.8 + th * 2.6 + (3.5 if pulse_on else 0.0))
		flame_lights[i].light_energy = th * 0.7
	for em in engine_mats:
		em.emission_energy_multiplier = lerpf(0.5, 4.2, clampf(th / 1.4, 0.0, 1.0))
	flame_mat.set_shader_parameter("power", clampf(0.30 + th * 0.35, 0.0, 1.2))
	if parts.has("Engine_Glow_L") or parts.has("Engine_Glow_R"):
		for nm in ["Engine_Glow_L", "Engine_Glow_R"]:
			if parts.has(nm):
				var mi: MeshInstance3D = parts[nm] as MeshInstance3D
				if mi != null:
					mi.scale = Vector3.ONE * (1.0 + th * 0.15)
	if model != null:
		var st: float = tidal
		model.scale = model.scale.lerp(Vector3(1.0 - 0.5 * st, 1.0 - 0.5 * st, 1.0 + 3.0 * st), 1.0 - exp(-10.0 * delta))
	plasma.visible = heat > 0.06
	plasma_mat.set_shader_parameter("heat", heat)
	if model != null:
		model.rotation.z = lerpf(model.rotation.z, bank_vis, 1.0 - exp(-8.0 * delta)) if state == State.FLYING else lerpf(model.rotation.z, 0.0, 1.0 - exp(-6.0 * delta))
	# cockpit interior only in cockpit view
	if parts.has("Cockpit_Interior"):
		(parts["Cockpit_Interior"] as Node3D).visible = true
	# nav light blink
	var blink: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 5.0))
	for nm in ["Light_Nav_L", "Light_Nav_R", "Light_Beacon"]:
		if parts.has(nm):
			(parts[nm] as Node3D).visible = blink > 0.35 or nm != "Light_Beacon"

# ------------------------------------------------------------------------------------------ camera
func camera_transform(delta: float) -> Transform3D:
	var spd: float = speed_ref
	var base_pos: Vector3 = position if world.frame_idx >= 0 else Vector3.ZERO
	# smooth camera orientation (lag gives a sense of motion)
	var follow: float = 9.0 if state == State.FLYING else 20.0
	var q_cam: Quaternion = Quaternion(cam_basis.orthonormalized())
	var q_ship: Quaternion = Quaternion(basis.orthonormalized())
	if q_cam.dot(q_ship) < 0.0:
		q_ship = -q_ship
	cam_basis = Basis(q_cam.slerp(q_ship, 1.0 - exp(-follow * delta)))
	var xf: Transform3D
	if menu_cam:
		var ang: float = menu_orbit_t
		var off: Vector3 = basis * Vector3(sin(ang) * 32.0, 5.0 + 3.5 * sin(ang * 0.6), cos(ang) * 32.0)
		var mpos: Vector3 = base_pos + off
		var mlook: Vector3 = base_pos + basis * Vector3(0, 0.6, -1.5)
		return Transform3D(Basis.looking_at((mlook - mpos).normalized(), basis.y), mpos)
	if cam_mode == 1:
		var eye: Vector3 = base_pos + basis * eye_local
		xf = Transform3D(basis, eye)
	else:
		var back: float = 15.2 + clampf(spd / 90.0, 0.0, 7.0) + (5.0 if pulse_on else 0.0)
		var target_off: Vector3 = Vector3(0, 4.3 + clampf(spd / 400.0, 0.0, 1.2), back)
		cam_off = cam_off.lerp(target_off, 1.0 - exp(-3.0 * delta))
		if state == State.LANDED:
			var orbit_basis: Basis = basis * Basis(Vector3.UP, orbit_yaw) * Basis(Vector3.RIGHT, -orbit_pitch)
			var pos: Vector3 = base_pos + orbit_basis * Vector3(0, 0, 17.0) + basis.y * 1.5
			var look_p: Vector3 = base_pos + basis.y * 1.2
			xf = Transform3D(Basis.looking_at((look_p - pos).normalized(), basis.y), pos)
		else:
			var cpos: Vector3 = base_pos + cam_basis * cam_off
			var look_at_p: Vector3 = base_pos + basis * Vector3(0, -3.4, -34.0)
			xf = Transform3D(Basis.looking_at((look_at_p - cpos).normalized(), cam_basis.y), cpos)
	# ground clamp (chase camera must not dip under the terrain)
	if world.frame_idx >= 0 and cam_mode == 0:
		var pl: Planet = world.planets[world.frame_idx]
		var d: Vector3 = xf.origin.normalized()
		var gr: float = pl.data.radius + pl.ground_height(d) + 1.2
		if xf.origin.length() < gr:
			xf.origin = d * gr
	# shake
	shake = maxf(0.0, shake - delta * 1.2)
	var amp: float = shake * 0.35 + heat * 0.12 + (0.05 if boosting else 0.0)
	if amp > 0.001:
		var rx: float = sin(_t * 61.0) * amp * 0.02
		var ry: float = sin(_t * 47.0 + 1.7) * amp * 0.02
		xf.basis = xf.basis * Basis.from_euler(Vector3(rx, ry, 0.0))
	return xf

func target_fov() -> float:
	if menu_cam:
		return 52.0
	var f: float = Game.fov_setting
	if pulse_on:
		f += 28.0 * clampf(pulse_speed / PULSE_SPEED, 0.0, 1.0)
	if boosting:
		f += 8.0
	f += heat * 6.0
	return f
