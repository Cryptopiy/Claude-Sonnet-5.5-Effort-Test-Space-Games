class_name Ship
extends Node3D
## PLAYER SHIP "Wanderer" (module M3 owns ship/*, shaders/ship*, shaders/entry*, tests/ship_*).
## Public API (Game relies on it):
##   is_landed: bool            velocity: Vector3 (LOCAL-frame velocity, m/s)
##   place_landed(dir, yaw)     place_flying(dir, altitude, speed)     place_free(local_pos, basis, vel)
##   exit_position() -> Vector3 ; exit_facing() -> Vector3 ; set_piloted(on) ; can_hyperdrive() ; on_warp_begin() ; on_warp_end(kind)
##   _on_frame_shift(rot, shift, vel_offset)
## Extras: hyperdrive_block_reason() -> String ("" = hyperdrive available, else a player-facing reason); Game.tel["ref_velocity"] (LOCAL-frame velocity of the
##   nearest body that the ship co-moves with: other effects can subtract it from camera motion); hull self-repairs slowly while landed.
## Black-hole contract (M5 writes these every frame while in range): external_accel (local-frame m/s^2), control_authority (0..1),
##   pulse_locked, extra_shake (0..1).
##
## Flight model: arcade 6-DOF "flight assist". Mouse = smoothed pitch/yaw (rate limited), Q/E roll, W/S thrust, A/D strafe, Space/Ctrl vertical
## (ship axes), Shift boost. Velocity always chases the commanded ship-axis velocity, so the ship hovers when you let go (no stalling, no gravity pull).
## Pulse drive (X): heading-locked cruise up to 40 km/s, auto-limited near bodies, drops out in atmosphere. Ground contact is analytic
## (Planet.terrain_radius_at at 3 gear contacts + hull points). Atmosphere: drag cap by density, reentry heat, camera shake.
## Everything the ship stores is either ship-relative or converted in _on_frame_shift (frame switches / rebases are seamless).

const MODEL_ID := "ship_player"

# ---- flight tuning -------------------------------------------------------------------------------------------------------------
const MAX_IMPULSE := 450.0
const MAX_BOOST := 1200.0
const MAX_REVERSE := 160.0
const MAX_STRAFE := 150.0
const MAX_VERT := 120.0
const ACC_VERT := 115.0
const ACC_FWD := 190.0
const ACC_BOOST := 520.0
const ACC_SIDE := 240.0
const ACC_BRAKE_MULT := 1.5
const ASSIST_EASE := 3.5                  # 1/s, exponential ease of the velocity controller near the commanded velocity
const MAX_PITCH_RATE := 1.9               # rad/s
const MAX_YAW_RATE := 1.6
const MAX_ROLL_RATE := 2.4
const STEER_RESPONSE := 15.0              # 1/s: how fast the ship follows pending mouse angle
const STEER_SMOOTH := 22.0                # 1/s: low-pass of the turn rate (higher = snappier)
const BANK_PER_YAW := 0.42                # rad of bank per rad/s of yaw rate (atmosphere / near planet)
const BANK_MAX := 0.62

# ---- pulse drive ---------------------------------------------------------------------------------------------------------------
const PULSE_MAX := 40000.0
const PULSE_CHARGE_TIME := 1.1
const PULSE_MIN_ALT := 3500.0             # drops out below this distance to any surface
const PULSE_ALT_FACTOR := 0.07            # speed limit near bodies: v <= factor * altitude + 150 (brief: 0.04; raised so the approach does not take minutes)
const PULSE_BURN := 0.0028                # fuel/s at full pulse speed (0..1 tank => ~6 min)
const PULSE_FUEL_PER_ZYRITE := 0.30

# ---- atmosphere / heat ---------------------------------------------------------------------------------------------------------
const ATMO_SPEED_LIMIT := 600.0
const HEAT_START_SPEED := 330.0

# ---- landing -------------------------------------------------------------------------------------------------------------------
const SAFE_VSPEED := 7.0
const SAFE_SPEED := 25.0
const SAFE_SLOPE_DEG := 30.0
const GEAR_TIME := 1.3
const AUTO_GEAR_ALT := 120.0
const SPOOL_TIME := 1.7
const GEAR_RETRACT_FRONT := deg_to_rad(85.0)
const GEAR_RETRACT_SIDE := deg_to_rad(80.0)

enum Pulse { OFF, CHARGING, ACTIVE }

# ---- public state --------------------------------------------------------------------------------------------------------------
var velocity := Vector3.ZERO
var is_landed := false
var piloted := true
var cam: Camera3D                          # chase camera (compat with the stub)
var model: Node3D
var gear_deployed := true
var pulse_state: int = Pulse.OFF
var altitude := -1.0                       # m above ground / cloud tops (anchored body), -1 in space
var atmo_density := 0.0
var heat := 0.0                            # 0..1 atmospheric entry heat
var boosting := false

# black hole contract
var external_accel := Vector3.ZERO
var control_authority := 1.0
var pulse_locked := false
var extra_shake := 0.0

# debug / test hooks (rad/s, ship axes) - active when != null
var debug_steer = null                     # Vector3(pitch, yaw, roll) rates or null

# ---- FX read-outs (ShipFX / camera rig read these) -----------------------------------------------------------------------------
var fx_thrust := 0.0                       # 0..1 engine thrust level
var fx_boost := 0.0                        # 0..1 smoothed boost
var fx_pulse := 0.0                        # 0..1 smoothed pulse intensity (charging ramps up)
var fx_spool := 0.0                        # take-off spool 0..1
var fx_gear := 0.0                         # 0 deployed .. 1 retracted
var fx_flow_dir := Vector3(0, 0, -1)       # direction of motion in ship space (for the heat shell)
var fx_speed := 0.0                        # speed relative to reference (m/s)
var fx_ground_point := Vector3.ZERO        # LOCAL position of the ground under the ship (valid if fx_ground_valid)
var fx_ground_valid := false
var fx_ground_normal := Vector3.UP
var fx_ground_dist := 999.0                # distance from the ship's lowest point to the ground
var fx_accel_local := Vector3.ZERO         # smoothed ship-axis acceleration (m/s^2)
var rig: ShipCameraRig
var fx: ShipFX

# ---- internals -----------------------------------------------------------------------------------------------------------------
var _planet: Planet
var _gas: Node3D
var _def: BodyDef
var _up := Vector3.UP
var _ground_r := 0.0
var _ref_vel := Vector3.ZERO
var _near_alt := INF
var _near_idx := -1
var _near_dir := Vector3.UP               # unit vector from the nearest body's centre to the ship
var _pressure := 0.0
var _in_atmo := false
var _warp_hold := false
var _assist := 1.0                         # 0..1 ramp that restores flight assist after a warp arrival
var _pend := Vector2.ZERO                  # pending mouse angle (x = yaw, y = pitch), radians
var _rate := Vector3.ZERO                  # smoothed (pitch, yaw, roll) rate
var _in_fwd := 0.0
var _in_strafe := 0.0
var _in_vert := 0.0
var _in_roll := 0.0
var _in_boost := false
var _gear_t := 0.0
var _gear_manual_until := 0.0              # while > Time: auto gear logic is suppressed
var _spool := 0.0
var _pulse_t := 0.0
var _pulse_speed := 0.0
var _pulse_ref_w := 1.0                    # weight of the reference-body velocity that the pulse motion added to `velocity` last frame
var _pulse_exit := 0.0                     # > 0 for a moment after the pulse drive ends: excess speed is bled off quickly
var _pulse_reason := ""
var _takeoff_assist := 0.0
var _settle_t := 1.0
var _settle_from := Transform3D.IDENTITY
var _settle_to := Transform3D.IDENTITY
var _susp := 0.0                           # suspension bob (m)
var _susp_v := 0.0
var _crash_cd := 0.0
var _last_vel := Vector3.ZERO
var _interact_lock := 0.0
var _hint_cd := 0.0
var _gas_warn_cd := 0.0
var _landed_body := -1
var _time := 0.0
var _unpiloted_engine_off := false
var _was_piloted := false

# model nodes
var _gear_front: Node3D
var _gear_l: Node3D
var _gear_r: Node3D
var _feet: Array = []                      # [{node, hinge, off}] foot contact data (ship space, deployed)
var _hull_pts: Array = []                  # Vector3 ship-space hull contact samples
var _anchor_exit := Vector3(-3.3, -1.9, -1.36)
var _anchor_chase := Vector3(0, 4.5, 16.0)
var _anchor_cockpit := Vector3(0, 1.15, -2.75)
var _anchor_engine_l := Vector3(-1.95, 0.02, 6.8)
var _anchor_engine_r := Vector3(1.95, 0.02, 6.8)

# =====================================================================================================================
# setup
# =====================================================================================================================
func _ready() -> void:
	add_to_group("frame_objects")
	_build_model()
	rig = ShipCameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(self)
	cam = rig.chase
	fx = ShipFX.new()
	fx.name = "FX"
	add_child(fx)
	fx.setup(self, model)
	set_piloted(true)

func _build_model() -> void:
	model = ModelLib.instantiate(MODEL_ID)
	model.name = "Model"
	add_child(model)
	_gear_front = ModelLib.find_node(model, "Gear_Front") as Node3D
	_gear_l = ModelLib.find_node(model, "Gear_L") as Node3D
	_gear_r = ModelLib.find_node(model, "Gear_R") as Node3D
	_anchor_exit = _anchor("Anchor_Exit", _anchor_exit)
	_anchor_chase = _anchor("Anchor_ChaseCam", _anchor_chase)
	_anchor_cockpit = _anchor("Anchor_Cockpit", _anchor_cockpit)
	_anchor_engine_l = _anchor("Anchor_Engine_L", _anchor_engine_l)
	_anchor_engine_r = _anchor("Anchor_Engine_R", _anchor_engine_r)
	_feet.clear()
	var defs := [["Gear_Front", "Anchor_GearContact_Front", Vector3(0, -1.9, -3.51)],
		["Gear_L", "Anchor_GearContact_L", Vector3(-3.3, -1.9, 2.3)],
		["Gear_R", "Anchor_GearContact_R", Vector3(3.3, -1.9, 2.3)]]
	for d in defs:
		var gn := ModelLib.find_node(model, d[0]) as Node3D
		var hinge: Vector3 = _rel_pos(gn) if gn != null else Vector3(d[2].x, -0.3, d[2].z)
		var foot: Vector3 = _anchor(d[1], d[2])
		_feet.append({"node": gn, "hinge": hinge, "off": foot - hinge, "rest": gn.transform.basis if gn != null else Basis.IDENTITY})
	_hull_pts = [Vector3(0, -0.45, -6.3), Vector3(0, -0.9, -2.6), Vector3(0, -0.9, 3.2), Vector3(-1.95, -0.9, 5.9), Vector3(1.95, -0.9, 5.9),
		Vector3(-5.5, 0.0, 3.9), Vector3(5.5, 0.0, 3.9), Vector3(0, 2.4, 4.8)]

func _anchor(node_name: String, fallback: Vector3) -> Vector3:
	var n := ModelLib.find_node(model, node_name) as Node3D
	return _rel_pos(n) if n != null else fallback

## position of a model node relative to the model root (the glb root node is identity, so this is ship space)
func _rel_pos(n: Node3D) -> Vector3:
	var p := Vector3.ZERO
	var cur: Node = n
	var xf := Transform3D.IDENTITY
	while cur != null and cur != model:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	p = xf.origin
	return p

func anchor_chase() -> Vector3:
	return _anchor_chase

func anchor_cockpit() -> Vector3:
	return _anchor_cockpit

func anchor_engine(left: bool) -> Vector3:
	return _anchor_engine_l if left else _anchor_engine_r

# =====================================================================================================================
# placement API
# =====================================================================================================================
func _anchored_planet() -> Planet:
	return Frame.anchor_node() as Planet

func _ground_radius_at(dir: Vector3) -> float:
	var p := _anchored_planet()
	if p != null:
		return p.terrain_radius_at(dir)
	var d := Frame.anchor_def()
	return d.radius if d != null else 0.0

func _heading_basis(up: Vector3, yaw: float) -> Basis:
	var north := Vector3.UP - up * up.y
	if north.length() < 0.2:
		north = Vector3.FORWARD - up * up.dot(Vector3.FORWARD)
	north = north.normalized().rotated(up, yaw)
	return Basis.looking_at(north, up)

func place_landed(dir: Vector3, yaw: float) -> void:
	var up := dir.normalized()
	_reset_state()
	gear_deployed = true
	_gear_t = 0.0
	_apply_gear_pose()
	var bas := _heading_basis(up, yaw)
	global_transform = Transform3D(bas, up * (_ground_radius_at(up) + 1.9))
	velocity = Vector3.ZERO
	is_landed = true
	_snap_to_ground(3)
	_landed_body = Frame.anchor
	_settle_t = 1.0
	_refresh_env()

func place_flying(dir: Vector3, altitude_m: float, speed: float) -> void:
	var up := dir.normalized()
	_reset_state()
	var bas := _heading_basis(up, 0.0)
	var r := _ground_radius_at(up) + altitude_m
	global_transform = Transform3D(bas, up * r)
	velocity = -bas.z * speed
	is_landed = false
	gear_deployed = altitude_m < AUTO_GEAR_ALT * 1.5 and speed < 90.0
	_gear_t = 0.0 if gear_deployed else 1.0
	_apply_gear_pose()
	_refresh_env()

func place_free(local_pos: Vector3, bas: Basis, vel: Vector3) -> void:
	_reset_state()
	global_transform = Transform3D(bas.orthonormalized(), local_pos)
	velocity = vel
	is_landed = false
	gear_deployed = false
	_gear_t = 1.0
	_apply_gear_pose()
	_refresh_env()

func _reset_state() -> void:
	pulse_state = Pulse.OFF
	_pulse_t = 0.0
	_pulse_speed = 0.0
	_spool = 0.0
	_takeoff_assist = 0.0
	_pend = Vector2.ZERO
	_rate = Vector3.ZERO
	heat = 0.0
	external_accel = Vector3.ZERO
	control_authority = 1.0
	pulse_locked = false
	extra_shake = 0.0
	_assist = 1.0
	_settle_t = 1.0
	_susp = 0.0
	_susp_v = 0.0
	_warp_hold = false
	_last_vel = Vector3.ZERO
	if rig != null:
		rig.reset()
	if fx != null:
		fx.reset()

## LOCAL position on the ground beside the left door + the direction the astronaut should face
func exit_position() -> Vector3:
	var bas := global_transform.basis
	var p := global_transform * (_anchor_exit + Vector3(-1.2, 0.0, 0.0))
	var d := p.normalized()
	var r := _ground_radius_at(d)
	if _anchored_planet() == null and Frame.anchor_def() == null:
		return p
	return d * (r + 0.05)

func exit_facing() -> Vector3:
	var b := global_transform.basis
	return (-b.x * 0.6 - b.z * 0.8).normalized()

func set_piloted(on: bool) -> void:
	piloted = on
	if rig != null:
		rig.set_active(on)
	if on:
		_interact_lock = 0.5
		_was_piloted = true

## Hyperdrive (galaxy map jump) is available when the ship is flying (not landed), clear of every surface / the atmosphere (altitude > 1.5 km, or in open
## space) and not caught in a gravity well (black hole danger zone = pulse_locked), not mid-warp.
func can_hyperdrive() -> bool:
	return hyperdrive_block_reason() == ""

## "" when the hyperdrive can engage, otherwise a short player-facing reason (UI / Game can show it)
func hyperdrive_block_reason() -> String:
	if _warp_hold:
		return "hyperdrive already charging"
	if is_landed:
		return "ship is landed - take off first"
	if pulse_locked:
		return "gravity well interference"
	if _def != null and altitude <= 1500.0:
		return "too close to the surface (climb above 1.5 km)"
	return ""

func on_warp_begin() -> void:
	_warp_hold = true
	velocity = Vector3.ZERO
	_set_pulse(Pulse.OFF, false)
	heat = 0.0
	external_accel = Vector3.ZERO
	if fx != null:
		fx.reset()

func on_warp_end(kind: String) -> void:
	_warp_hold = false
	_set_pulse(Pulse.OFF, false)
	heat = 0.0
	_pend = Vector2.ZERO
	_rate = Vector3.ZERO
	_last_vel = velocity
	if rig != null:
		rig.reset()
	if fx != null:
		fx.reset()
	if kind == "blackhole":
		_assist = 0.06                     # coast outward for a few seconds after being ejected from the singularity
	else:
		_assist = 1.0
	is_landed = false
	_refresh_env()

func _on_frame_shift(rot: Basis, shift: Vector3, vel_offset: Vector3) -> void:
	velocity = rot * velocity + vel_offset
	_last_vel = rot * _last_vel + vel_offset
	external_accel = rot * external_accel
	if fx != null:
		fx.on_frame_shift(rot, shift)
	if rig != null:
		rig.on_frame_shift(rot)
	if is_landed:
		_settle_from = Transform3D(rot, shift) * _settle_from
		_settle_to = Transform3D(rot, shift) * _settle_to

# =====================================================================================================================
# input
# =====================================================================================================================
func _unhandled_input(ev: InputEvent) -> void:
	if not piloted:
		return
	var d := Game.mouse_look_delta(ev)
	if d != Vector2.ZERO:
		_pend.x += d.x
		_pend.y += d.y
		_pend = _pend.limit_length(1.6)

func _read_input() -> void:
	_in_fwd = 0.0
	_in_strafe = 0.0
	_in_vert = 0.0
	_in_roll = 0.0
	_in_boost = false
	if not (piloted and Game.input_enabled()):
		return
	_in_fwd = Input.get_axis("move_back", "move_forward")
	_in_strafe = Input.get_axis("move_left", "move_right")
	_in_vert = Input.get_axis("move_down", "move_up")
	_in_roll = Input.get_axis("roll_right", "roll_left")
	_in_boost = Input.is_action_pressed("sprint")
	if Input.is_action_just_pressed("landing_gear"):
		_toggle_gear()
	if Input.is_action_just_pressed("pulse_drive"):
		_toggle_pulse()
	if Input.is_action_just_pressed("toggle_camera") and rig != null:
		rig.toggle()
	if Input.is_action_just_pressed("toggle_light") and fx != null:
		fx.toggle_lights()
		Events.notify.emit("Ship floodlights " + ("on" if fx.lights_on else "off"), "info")
	if _interact_lock <= 0.0 and is_landed and Input.is_action_just_pressed("interact"):
		_request_exit.call_deferred()

func _request_exit() -> void:
	if is_landed and piloted and Game.mode == Game.Mode.SHIP:
		Game.exit_ship()

# =====================================================================================================================
# main loop
# =====================================================================================================================
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if dt <= 0.0 or _warp_hold:
		return
	_time += dt
	_interact_lock = maxf(0.0, _interact_lock - dt)
	_crash_cd = maxf(0.0, _crash_cd - dt)
	_hint_cd = maxf(0.0, _hint_cd - dt)
	_gas_warn_cd = maxf(0.0, _gas_warn_cd - dt)
	_read_input()
	_refresh_env()
	_update_gear(dt)
	_update_pulse_state(dt)
	if is_landed:
		_update_landed(dt)
	else:
		_update_flight(dt)
	_update_heat(dt)
	_update_readouts(dt)
	global_transform.basis = global_transform.basis.orthonormalized()
	if fx != null:
		fx.update(dt)
	if rig != null:
		rig.update(dt)
	_publish(dt)
	_last_vel = velocity

# =====================================================================================================================
# environment: anchored body, altitude, density, nearest body, reference velocity
# =====================================================================================================================
func _refresh_env() -> void:
	var p := global_position
	var n := Frame.anchor_node()
	_planet = n as Planet
	_gas = n if n is GasGiant else null
	_def = Frame.anchor_def()
	altitude = -1.0
	atmo_density = 0.0
	_pressure = 0.0
	fx_ground_valid = false
	if _def != null:
		var dist := maxf(p.length(), 1.0)
		_up = p / dist
		var surf := _def.radius
		if _planet != null and dist - _def.radius < 7000.0:
			surf = _planet.terrain_radius_at(_up)
		_ground_r = surf
		altitude = dist - surf
		if _planet != null:
			atmo_density = _planet.atmosphere_density_at(p)
		elif _gas != null:
			var ah: float = maxf(_def.atmo_height, 1.0)
			atmo_density = clampf(1.0 - (dist - _def.radius) / ah, 0.0, 1.0)
			if _gas.has_method("pressure_depth"):
				_pressure = float(_gas.call("pressure_depth", p))
		if atmo_density > 0.0015 and not _in_atmo:
			_in_atmo = true
			Events.atmosphere_entered.emit(_def.index)
		elif atmo_density < 0.0005 and _in_atmo:
			_in_atmo = false
			Events.atmosphere_left.emit(_def.index)
	else:
		_up = global_transform.basis.y
		if _in_atmo:
			_in_atmo = false
	_scan_bodies()

func _scan_bodies() -> void:
	var sys := Universe.system
	_near_alt = INF
	_near_idx = -1
	_ref_vel = Vector3.ZERO
	if sys == null:
		return
	var nodes := Universe.body_nodes
	var p := global_position
	var wsum := 0.0
	var vsum := Vector3.ZERO
	var in_space := Frame.anchor < 0
	for i in mini(nodes.size(), sys.bodies.size()):
		var b: BodyDef = sys.bodies[i]
		if b.kind == BodyDef.Kind.BLACK_HOLE:
			continue
		var bn := nodes[i] as Node3D
		if bn == null or not is_instance_valid(bn):
			continue
		var off := p - bn.global_position
		var d := off.length()
		var surf := d - b.radius
		if surf < _near_alt:
			_near_alt = surf
			_near_idx = i
			_near_dir = off / maxf(d, 0.001)
		if in_space and b.capture_radius > 0.0:
			var w := 1.0 - smoothstep(2.5 * b.capture_radius, 8.0 * b.capture_radius, d)
			if w > 0.0:
				vsum += Universe.body_velocity(i) * w
				wsum += w
	# the star counts as a body for the pulse-drive limiter
	var sl := p - Frame.star_local
	var sd := sl.length()
	var salt := sd - Universe.system.star.radius
	if salt < _near_alt:
		_near_alt = salt
		_near_idx = -2
		_near_dir = sl / maxf(sd, 0.001)
	if in_space and wsum > 0.0:
		_ref_vel = vsum / maxf(wsum, 1.0)

# =====================================================================================================================
# gear
# =====================================================================================================================
func _toggle_gear() -> void:
	if is_landed:
		return
	gear_deployed = not gear_deployed
	_gear_manual_until = _time + 10.0
	Events.gear_changed.emit(gear_deployed)

func _set_gear(on: bool) -> void:
	if gear_deployed == on:
		return
	gear_deployed = on
	Events.gear_changed.emit(on)

func _update_gear(dt: float) -> void:
	if not is_landed and _time > _gear_manual_until and piloted:
		var vr := velocity - _ref_vel
		var spd := vr.length()
		var v_down := -vr.dot(_up)
		# deploy when low and slow, or earlier when descending steadily (a pilot diving at the ground at 100+ m/s still gets gear + flare)
		var gear_alt := AUTO_GEAR_ALT + 1.6 * maxf(v_down - 20.0, 0.0)
		var descending := v_down > 25.0 and spd < 260.0
		if not gear_deployed and _def != null and altitude < gear_alt and (spd < 90.0 or descending) and _planet != null and pulse_state == Pulse.OFF:
			_set_gear(true)
			Events.notify.emit("Landing gear deployed", "info")
		elif gear_deployed and _takeoff_assist <= 0.0 and (altitude > maxf(260.0, gear_alt + 120.0) or _def == null) and spd > 40.0 and v_down < 12.0 and _gear_manual_until < _time:
			_set_gear(false)
	var target := 0.0 if gear_deployed else 1.0
	_gear_t = move_toward(_gear_t, target, dt / GEAR_TIME)
	_apply_gear_pose()

func _apply_gear_pose() -> void:
	var e := smoothstep(0.0, 1.0, _gear_t)
	fx_gear = e
	if _gear_front != null:
		_gear_front.transform.basis = Basis(Vector3.RIGHT, GEAR_RETRACT_FRONT * e)
	if _gear_l != null:
		_gear_l.transform.basis = Basis(Vector3.BACK, GEAR_RETRACT_SIDE * e)
	if _gear_r != null:
		_gear_r.transform.basis = Basis(Vector3.BACK, -GEAR_RETRACT_SIDE * e)

## ship-space positions of the three foot pads for the current gear pose
func _foot_positions() -> Array:
	var out: Array = []
	var e := smoothstep(0.0, 1.0, _gear_t)
	for i in _feet.size():
		var f: Dictionary = _feet[i]
		var hinge: Vector3 = f["hinge"]
		var off: Vector3 = f["off"]
		var bas := Basis.IDENTITY
		if i == 0:
			bas = Basis(Vector3.RIGHT, GEAR_RETRACT_FRONT * e)
		elif i == 1:
			bas = Basis(Vector3.BACK, GEAR_RETRACT_SIDE * e)
		else:
			bas = Basis(Vector3.BACK, -GEAR_RETRACT_SIDE * e)
		out.append(hinge + bas * off)
	return out

# =====================================================================================================================
# pulse drive
# =====================================================================================================================
func _toggle_pulse() -> void:
	if pulse_state != Pulse.OFF:
		_set_pulse(Pulse.OFF, true)
		return
	var why := _pulse_block_reason()
	if why != "":
		Events.hint.emit("Pulse drive unavailable: " + why, 3.0)
		Events.notify.emit("Pulse drive offline - " + why, "warn")
		return
	if Game.ship_fuel < 0.02 and int(Game.inventory.get("zyrite", 0)) <= 0:
		Events.hint.emit("Pulse drive: out of fuel - mine Zyrite", 3.5)
		Events.notify.emit("Pulse drive: no fuel (collect Zyrite)", "warn")
		return
	_pulse_t = 0.0
	_set_pulse(Pulse.CHARGING, true)

func _pulse_block_reason() -> String:
	if is_landed:
		return "ship is landed"
	if pulse_locked:
		return "gravity well interference"
	if atmo_density > 0.0:
		return "inside atmosphere"
	if _near_alt < PULSE_MIN_ALT:
		return "too close to a body"
	return ""

func _set_pulse(s: int, announce: bool) -> void:
	if pulse_state == s:
		return
	var was_on := pulse_state != Pulse.OFF
	pulse_state = s
	var is_on := s != Pulse.OFF
	if is_on != was_on and announce:
		Events.pulse_changed.emit(is_on)
	if s == Pulse.OFF:
		_pulse_t = 0.0
		if was_on and _pulse_speed > MAX_BOOST * 1.1:
			_pulse_exit = 3.0                  # "drop out of pulse": shed the excess speed in ~1.5 s instead of coasting for a minute
		_pulse_speed = 0.0
	elif s == Pulse.ACTIVE:
		_pulse_speed = maxf((velocity - _ref_vel).length(), 150.0)
		_pulse_ref_w = 1.0

func _pulse_cap() -> float:
	var base := PULSE_ALT_FACTOR * maxf(_near_alt, 0.0) + 150.0
	# leaving a body: allow a much faster departure so the climb away does not take a minute
	var f := -global_transform.basis.z
	var radial := f.dot(_near_dir)
	var boost := lerpf(1.0, 3.2, smoothstep(0.25, 0.75, radial))
	return minf(PULSE_MAX, base * boost)

func _update_pulse_state(dt: float) -> void:
	if pulse_state == Pulse.OFF:
		return
	var why := _pulse_block_reason()
	if why != "":
		_set_pulse(Pulse.OFF, true)
		if why != "ship is landed" and piloted:
			Events.notify.emit("Pulse drive disengaged - " + why, "info")
		return
	# fuel
	if pulse_state == Pulse.ACTIVE:
		var burn := PULSE_BURN * (0.35 + 0.65 * clampf(_pulse_speed / PULSE_MAX, 0.0, 1.0))
		Game.ship_fuel = maxf(0.0, Game.ship_fuel - burn * dt)
		if Game.ship_fuel <= 0.0:
			if Game.consume_resource("zyrite", 1) > 0:
				Game.ship_fuel = PULSE_FUEL_PER_ZYRITE
				Events.notify.emit("Pulse drive refuelled from Zyrite", "good")
			else:
				_set_pulse(Pulse.OFF, true)
				Events.notify.emit("Pulse drive: out of fuel", "warn")
				return
	if pulse_state == Pulse.CHARGING:
		_pulse_t += dt
		if _pulse_t >= PULSE_CHARGE_TIME:
			_set_pulse(Pulse.ACTIVE, false)
	if Input.is_action_pressed("move_back") and piloted and Game.input_enabled() and pulse_state == Pulse.ACTIVE:
		# braking drops out of pulse
		_set_pulse(Pulse.OFF, true)

# =====================================================================================================================
# landed state / take-off
# =====================================================================================================================
func _update_landed(dt: float) -> void:
	velocity = Vector3.ZERO
	# settle animation (touch-down pose -> aligned pose), plus a small suspension bob on the model
	if _settle_t < 1.0:
		_settle_t = minf(1.0, _settle_t + dt / 0.55)
		var e := 1.0 - pow(1.0 - _settle_t, 3.0)
		var q := _settle_from.basis.get_rotation_quaternion().slerp(_settle_to.basis.get_rotation_quaternion(), e)
		global_transform = Transform3D(Basis(q), _settle_from.origin.lerp(_settle_to.origin, e))
	# hull self-repair while parked (a crash must not leave the ship damaged for ever): ~80 s from 0 to 100 %
	if Game.ship_hull < 1.0 and _settle_t >= 1.0:
		Game.ship_hull = minf(1.0, Game.ship_hull + 0.0125 * dt)
	_susp_v += (-90.0 * _susp - 11.0 * _susp_v) * dt
	_susp += _susp_v * dt
	if model != null:
		model.position = Vector3(0, _susp, 0)
	# take-off request
	var want := piloted and Game.input_enabled() and (Input.is_action_pressed("move_up") or Input.is_action_pressed("move_forward"))
	if want and _settle_t >= 0.6:
		_spool = minf(1.0, _spool + dt / SPOOL_TIME)
	else:
		_spool = maxf(0.0, _spool - dt * 1.6)
	fx_spool = _spool
	if _planet != null:
		_planet.set_collision_focus(global_position, 70.0)
	if piloted:
		if _spool > 0.02:
			Game.set_context_hint("TAKE-OFF  ...  engines spooling")
		else:
			Game.set_context_hint("[F] Exit ship      [Space] / [W] Take off")
	if _spool >= 1.0:
		_lift_off()

func _lift_off() -> void:
	is_landed = false
	_spool = 0.0
	_takeoff_assist = 5.0
	velocity = _up * 2.5
	_susp = 0.0
	_susp_v = 0.0
	if model != null:
		model.position = Vector3.ZERO
	_gear_manual_until = 0.0
	Events.ship_took_off.emit()
	if rig != null:
		rig.kick(Vector3(0, -0.25, 0), 0.35)

# =====================================================================================================================
# flight
# =====================================================================================================================
func _update_flight(dt: float) -> void:
	var auth := clampf(control_authority, 0.0, 1.0)
	_assist = minf(1.0, _assist + dt * 0.18) if _assist < 1.0 else 1.0
	if _takeoff_assist > 0.0:
		_takeoff_assist -= dt
		if altitude > 40.0 or not gear_deployed:
			_takeoff_assist = minf(_takeoff_assist, 0.0)
	_steer(dt, auth)
	if pulse_state == Pulse.ACTIVE:
		_motion_pulse(dt, auth)
	else:
		_motion_impulse(dt, auth)
	if external_accel != Vector3.ZERO:
		velocity += external_accel * dt
	_apply_atmosphere(dt)
	_apply_gas_barrier(dt)
	global_position += velocity * dt
	_ground_contact(dt)

## mouse/keys -> rotation. Mouse angle is accumulated, then followed with a rate limit and low-pass (smooth, never snappy).
func _steer(dt: float, auth: float) -> void:
	var rate_scale := auth
	if pulse_state == Pulse.ACTIVE:
		rate_scale *= 0.42
	elif pulse_state == Pulse.CHARGING:
		rate_scale *= 0.7
	var tp := 0.0
	var ty := 0.0
	var tr := 0.0
	if debug_steer != null:
		var ds: Vector3 = debug_steer
		tp = ds.x
		ty = ds.y
		tr = ds.z
	else:
		var turn := _pend * STEER_RESPONSE
		tp = clampf(-turn.y, -MAX_PITCH_RATE, MAX_PITCH_RATE)
		ty = clampf(-turn.x, -MAX_YAW_RATE, MAX_YAW_RATE)
		# consume the part of the pending angle that was actually turned
		var used := Vector2(-ty, -tp) * dt
		_pend -= used
		if absf(_pend.x) < 0.0004: _pend.x = 0.0
		if absf(_pend.y) < 0.0004: _pend.y = 0.0
		tr = _in_roll * MAX_ROLL_RATE
	tp *= rate_scale
	ty *= rate_scale
	tr *= rate_scale
	# auto-level: bank into turns near planets, level out for landing
	var lvl := _auto_level_strength()
	if lvl.x > 0.0 and absf(_in_roll) < 0.01 and (debug_steer == null or (debug_steer as Vector3).z == 0.0):
		var b := global_transform.basis
		var upn := _up
		var bank := -asin(clampf(b.x.dot(upn), -1.0, 1.0))          # + = right wing down
		var bank_target := clampf(_rate.y * -BANK_PER_YAW, -BANK_MAX, BANK_MAX)
		if lvl.y > 0.0:
			bank_target = 0.0
		var k := 2.6 * lvl.x + 3.0 * lvl.y
		tr = clampf(-(bank_target - bank) * k, -MAX_ROLL_RATE, MAX_ROLL_RATE) * maxf(rate_scale, 0.25)
	var a := 1.0 - exp(-STEER_SMOOTH * dt)
	_rate.x = lerpf(_rate.x, tp, a)
	_rate.y = lerpf(_rate.y, ty, a)
	_rate.z = lerpf(_rate.z, tr, a)
	rotate_object_local(Vector3.RIGHT, _rate.x * dt)
	rotate_object_local(Vector3.UP, _rate.y * dt)
	rotate_object_local(Vector3.BACK, _rate.z * dt)
	# landing assist: gently flatten the attitude when slow, low, with gear down
	if lvl.y > 0.0:
		var f := -global_transform.basis.z
		var fh := f - _up * f.dot(_up)
		if fh.length() < 0.15:
			fh = global_transform.basis.y - _up * global_transform.basis.y.dot(_up)
			fh = -fh if fh.length() > 0.01 else Vector3.FORWARD
		var target := Basis.looking_at(fh.normalized(), _up)
		var qk := 1.0 - exp(-lvl.y * 1.4 * dt)
		var q := global_transform.basis.get_rotation_quaternion().slerp(target.get_rotation_quaternion(), qk)
		global_transform.basis = Basis(q)

## x = banked-turn / roll auto-level strength (near planets), y = landing flatten strength (gear down, low, slow)
func _auto_level_strength() -> Vector2:
	if _def == null or altitude < 0.0:
		return Vector2.ZERO
	var near := 1.0 - smoothstep(4000.0, 9000.0, altitude)
	if pulse_state == Pulse.ACTIVE:
		near = 0.0
	var land := 0.0
	if gear_deployed and _planet != null:
		var spd := (velocity - _ref_vel).length()
		land = (1.0 - smoothstep(35.0, 110.0, altitude)) * (1.0 - smoothstep(40.0, 110.0, spd))
	return Vector2(near, land)

func _approach(cur: float, tgt: float, acc: float, dt: float) -> float:
	var delta := tgt - cur
	var braking := signf(tgt) != signf(cur) or absf(tgt) < absf(cur)
	var a := acc * (ACC_BRAKE_MULT if braking else 1.0)
	var step := clampf(delta * ASSIST_EASE * dt, -a * dt, a * dt)
	if absf(delta) < 0.04:
		return tgt
	# make sure we move at least a little (the easing alone would stall at tiny deltas)
	if absf(step) < 0.25 * a * dt and absf(delta) > 0.04:
		step = clampf(delta, -0.25 * a * dt, 0.25 * a * dt)
	return cur + step

func _motion_impulse(dt: float, auth: float) -> void:
	var b := global_transform.basis
	var vrel := velocity - _ref_vel
	if _pulse_exit > 0.0:
		_pulse_exit = maxf(0.0, _pulse_exit - dt)
		var sp := vrel.length()
		var lim := MAX_BOOST * 1.05
		if sp > lim and external_accel.length() < 1.0:
			var ex := sp - lim
			var nex := maxf(ex * exp(-2.6 * dt) - 2500.0 * dt, 0.0)
			vrel = vrel / sp * (lim + nex)
			velocity = vrel + _ref_vel
	var vloc := b.transposed() * vrel
	var fwd := _in_fwd
	boosting = _in_boost and (fwd >= 0.0) and piloted and Game.input_enabled() and auth > 0.1
	if boosting:
		fwd = 1.0
	var vert := _in_vert
	var strafe := _in_strafe
	# take-off assist: climb automatically while the gear is down and we are low
	if _takeoff_assist > 0.0:
		vert = maxf(vert, 0.75)
		fwd = minf(fwd, 0.35)
	var smax := MAX_BOOST if boosting else MAX_IMPULSE
	var cap := _atmo_speed_cap()
	smax = minf(smax, cap)
	var cmd := Vector3(strafe * MAX_STRAFE, vert * MAX_VERT, -(fwd * (smax if fwd > 0.0 else MAX_REVERSE)))
	# ground effect: lift-off from the pad is a controlled climb
	if _planet != null and altitude < 40.0 and cmd.y > 0.0:
		cmd.y = minf(cmd.y, 18.0 + altitude * 2.2)
	var acc_f := ACC_BOOST if boosting else ACC_FWD
	var eff := auth * _assist
	# when the black hole pull is active the ship's thrust is limited to ~150 m/s^2 (M5's escape model)
	if external_accel.length() > 1.0:
		eff *= 0.4
	vloc.x = _approach(vloc.x, cmd.x, ACC_SIDE * eff, dt)
	vloc.y = _approach(vloc.y, cmd.y, ACC_VERT * eff, dt)
	vloc.z = _approach(vloc.z, cmd.z, acc_f * eff, dt)
	velocity = b * vloc + _ref_vel
	_landing_flare(dt, auth)

## terrain-proximity descent limiter ("thrusters flare"): with the gear down you can never descend faster than a soft touch-down profile allows
func _landing_flare(dt: float, auth: float) -> void:
	if _planet == null or not gear_deployed or pulse_state != Pulse.OFF or _gear_t > 0.5:
		return
	var clearance := altitude - 1.9
	if clearance > 140.0:
		return
	var v_down := -(velocity - _ref_vel).dot(_up)
	var allowed := 2.2 + sqrt(2.0 * 38.0 * maxf(clearance - 0.6, 0.0))
	if v_down > allowed:
		velocity += _up * minf(v_down - allowed, 330.0 * dt) * clampf(auth * 2.0, 0.0, 1.0)

func _motion_pulse(dt: float, auth: float) -> void:
	var f := -global_transform.basis.z
	var cap := _pulse_cap()
	# heading = velocity minus the part of the reference-body velocity that was ADDED last frame (otherwise the heading drifts retrograde at speed)
	var v := (velocity - _ref_vel * _pulse_ref_w)
	var spd := v.length()
	_pulse_speed = maxf(spd, 1.0) if _pulse_speed <= 0.0 else _pulse_speed
	var target := cap
	if _pulse_speed < target:
		_pulse_speed = minf(target, _pulse_speed + maxf(1200.0, _pulse_speed * 1.15) * dt)
	else:
		_pulse_speed = move_toward(_pulse_speed, target, maxf(3000.0, (_pulse_speed - target) * 4.0) * dt)
	var dir := v.normalized() if v.length() > 5.0 else f
	var a := 1.0 - exp(-3.2 * maxf(auth, 0.2) * dt)
	dir = dir.slerp(f, a).normalized()
	_pulse_ref_w = 1.0 - smoothstep(600.0, 3000.0, _pulse_speed)
	velocity = dir * _pulse_speed + _ref_vel * _pulse_ref_w
	boosting = false

# =====================================================================================================================
# atmosphere: drag cap + entry heat, gas giant pressure
# =====================================================================================================================
func _atmo_speed_cap() -> float:
	if atmo_density <= 0.0:
		return INF
	return lerpf(2600.0, ATMO_SPEED_LIMIT, smoothstep(0.0, 0.35, atmo_density))

func _apply_atmosphere(dt: float) -> void:
	if atmo_density <= 0.0:
		return
	var v := velocity - _ref_vel
	var spd := v.length()
	var cap := _atmo_speed_cap()
	if spd > cap:
		var excess := spd - cap
		var k := (1.6 + 5.0 * atmo_density)
		var new_spd := spd - excess * (1.0 - exp(-k * dt))
		velocity = v / spd * new_spd + _ref_vel

func _update_heat(dt: float) -> void:
	var vrel := velocity - _ref_vel
	var spd := vrel.length()
	var dens := smoothstep(0.02, 0.22, atmo_density)
	# re-entry heating is about ploughing DOWN into thickening air: climbing out / cruising level only glows faintly
	var descent := 0.0
	if _def != null and spd > 1.0:
		descent = -vrel.dot(_up) / spd
	var dir_f := lerpf(0.08, 1.0, smoothstep(-0.05, 0.45, descent))
	var target := clampf((spd - HEAT_START_SPEED) / 650.0, 0.0, 1.0) * dens * dir_f
	# decelerating from way above the drag cap adds extra heat
	heat = lerpf(heat, target, 1.0 - exp(-(2.2 if target > heat else 1.1) * dt))
	if heat < 0.002:
		heat = 0.0

func _apply_gas_barrier(dt: float) -> void:
	if _gas == null or _pressure <= 0.03:
		return
	var warn := smoothstep(0.03, 0.5, _pressure)
	# push the ship back out: acceleration grows with depth and beats the thrust well before 0.5
	var push := (150.0 + 1300.0 * warn * warn)
	velocity += _up * push * dt * clampf(_pressure * 3.0, 0.0, 1.0)
	var vr := velocity.dot(_up)
	if vr < 0.0 and _pressure > 0.2:
		velocity -= _up * vr * (1.0 - exp(-4.0 * dt))
	if _gas_warn_cd <= 0.0 and piloted:
		_gas_warn_cd = 4.0
		Events.notify.emit("WARNING: crushing atmospheric pressure - pull up!", "danger")
		Events.screen_flash.emit(Color(1.0, 0.45, 0.1, 0.35), 0.4)
	if _pressure > 0.55:
		Game.ship_hull = maxf(0.05, Game.ship_hull - 0.04 * dt)
	extra_shake = maxf(extra_shake, 0.0)
	if rig != null:
		rig.add_shake(warn * 0.5)

# =====================================================================================================================
# ground contact + landing
# =====================================================================================================================
func _contact_points() -> Array:
	var pts: Array = []
	pts.append_array(_foot_positions())
	pts.append_array(_hull_pts)
	return pts

func _ground_contact(dt: float) -> void:
	if _planet == null or _def == null:
		return
	var low := altitude < 28.0
	fx_ground_valid = false
	if altitude < 160.0:
		# ground info for the dust FX (under the ship's centre)
		var gp := _up * _ground_r
		fx_ground_point = gp
		fx_ground_normal = _planet.normal_at(_up)
		fx_ground_valid = true
		fx_ground_dist = altitude - 1.9
	if not low:
		return
	var xf := global_transform
	var sea := _planet.sea_radius()
	var worst := 0.0
	var worst_water := false
	var foot_pen := false
	var pts := _contact_points()
	var foot_gp: Array = []
	for i in pts.size():
		var wp: Vector3 = xf * (pts[i] as Vector3)
		var d := wp.length()
		var dir := wp / maxf(d, 0.001)
		var gr := _planet.terrain_radius_at(dir)
		var water := false
		if sea > 0.0 and sea > gr:
			gr = sea
			water = true
		var pen := gr - d
		if i < 3:
			foot_gp.append(dir * gr)
		if pen > worst:
			worst = pen
			worst_water = water
		if i < 3 and pen > -0.02:
			foot_pen = true
	fx_ground_dist = altitude - 1.9
	if worst <= 0.0 and not foot_pen:
		return
	# --- contact ---
	var n := _planet.normal_at(_up)
	var up := _up
	if worst > 0.0:
		global_position += up * worst
	var vrel := velocity - _ref_vel
	var v_up := vrel.dot(up)               # negative = descending
	var v_in := -vrel.dot(n)
	var spd := vrel.length()
	var slope := rad_to_deg(acos(clampf(n.dot(up), -1.0, 1.0)))
	var gear_ok := _gear_t < 0.3 and gear_deployed
	if worst_water:
		# liquid surface: ride on it softly, cannot land
		if v_in > 0.0:
			velocity = velocity - n * minf(0.0, velocity.dot(n))
		velocity *= 1.0 - minf(1.0, 1.2 * dt)
		if v_in > 12.0 and _crash_cd <= 0.0:
			_crash_cd = 0.6
			if rig != null:
				rig.kick(Vector3(0, 0.1, 0), 0.2)
		if _hint_cd <= 0.0 and altitude < 6.0 and piloted:
			_hint_cd = 5.0
			Events.hint.emit("Cannot land on liquid surfaces", 3.0)
		return
	if gear_ok and -v_up < SAFE_VSPEED and spd < SAFE_SPEED and slope < SAFE_SLOPE_DEG and foot_pen and pulse_state == Pulse.OFF:
		_touch_down(foot_gp, maxf(v_in, 0.0))
		return
	# crash / bounce / scrape
	if v_in > 0.0:
		var restitution := 0.32 if v_in > 4.0 else 0.0
		velocity = velocity - n * (velocity.dot(n)) + n * v_in * restitution
		# friction on the tangential velocity
		var vt := velocity - n * velocity.dot(n)
		velocity -= vt * minf(1.0, 3.0 * dt)
		var hard := v_in > SAFE_VSPEED - 1.0 or (not gear_ok and v_in > 3.0)
		if hard and _crash_cd <= 0.0:
			_crash_cd = 0.5
			var sev := clampf((v_in - 5.0) / 55.0, 0.0, 1.0)
			if not gear_ok:
				sev = clampf(sev + 0.12, 0.0, 1.0)
			_crash(sev, v_in)
		elif _hint_cd <= 0.0 and piloted:
			_hint_cd = 4.0
			if not gear_deployed:
				Events.hint.emit("Deploy landing gear (G) to land", 3.0)
			elif slope >= SAFE_SLOPE_DEG:
				Events.hint.emit("Slope too steep to land (%d deg)" % int(slope), 3.0)
			elif spd >= SAFE_SPEED:
				Events.hint.emit("Too fast to land - slow below 25 m/s", 3.0)

func _crash(sev: float, v_in: float) -> void:
	if sev > 0.02:
		Game.ship_hull = maxf(0.05, Game.ship_hull - sev * 0.3)
	Events.ship_crashed.emit(sev)
	Events.screen_flash.emit(Color(1.0, 0.35, 0.15, 0.25 + 0.4 * sev), 0.35)
	if rig != null:
		rig.kick(Vector3(0, -0.5 * sev, 0), 0.4 + 0.9 * sev)
	if sev > 0.25 and piloted:
		Events.notify.emit("Hull damaged (%d%%)" % int(Game.ship_hull * 100.0), "danger" if Game.ship_hull < 0.35 else "warn")

## settle onto the three foot contact points of the ground and become landed
func _touch_down(foot_gp: Array, v_in: float) -> void:
	var xf := global_transform
	var up_dir := _up
	# iterate: align the foot triangle with the terrain plane through the three ground points
	for it in 3:
		var feet := _foot_positions()
		var gp: Array = []
		for i in 3:
			var wp: Vector3 = xf * (feet[i] as Vector3)
			var dir := wp.normalized()
			gp.append(dir * _planet.terrain_radius_at(dir))
		var nrm := ((gp[1] as Vector3) - (gp[0] as Vector3)).cross((gp[2] as Vector3) - (gp[0] as Vector3))
		if nrm.length() < 0.001:
			break
		nrm = nrm.normalized()
		if nrm.dot(up_dir) < 0.0:
			nrm = -nrm
		# keep the heading: forward projected onto the plane
		var f := -xf.basis.z
		f = f - nrm * f.dot(nrm)
		if f.length() < 0.05:
			f = xf.basis.x.cross(nrm)
		var nb := Basis.looking_at(f.normalized(), nrm)
		# origin so that the feet (ship space) land on the ground points
		var o := Vector3.ZERO
		for i in 3:
			o += (gp[i] as Vector3) - nb * (feet[i] as Vector3)
		o /= 3.0
		xf = Transform3D(nb, o)
	_settle_from = global_transform
	_settle_to = xf
	_settle_t = 0.0
	is_landed = true
	velocity = Vector3.ZERO
	_landed_body = _def.index if _def != null else -1
	_susp = -0.22 - minf(v_in * 0.03, 0.2)
	_susp_v = 0.0
	_spool = 0.0
	_set_pulse(Pulse.OFF, false)
	Events.ship_landed.emit(_landed_body)
	if rig != null:
		rig.kick(Vector3(0, -0.2, 0), 0.25 + minf(v_in * 0.05, 0.3))
	if piloted:
		Events.notify.emit("Landed" if Game.ship_hull > 0.98 else "Landed - hull self-repair engaged", "good")

## used by place_landed(): puts the feet on the ground instantly
func _snap_to_ground(iterations: int) -> void:
	var xf := global_transform
	for it in iterations:
		var feet := _foot_positions()
		var gp: Array = []
		for i in 3:
			var wp: Vector3 = xf * (feet[i] as Vector3)
			var dir := wp.normalized()
			gp.append(dir * _ground_radius_at(dir))
		var nrm := ((gp[1] as Vector3) - (gp[0] as Vector3)).cross((gp[2] as Vector3) - (gp[0] as Vector3))
		if nrm.length() < 0.001:
			break
		nrm = nrm.normalized()
		if nrm.dot(xf.origin.normalized()) < 0.0:
			nrm = -nrm
		var f := -xf.basis.z
		f = f - nrm * f.dot(nrm)
		if f.length() < 0.05:
			f = xf.basis.x.cross(nrm)
		var nb := Basis.looking_at(f.normalized(), nrm)
		var o := Vector3.ZERO
		for i in 3:
			o += (gp[i] as Vector3) - nb * (feet[i] as Vector3)
		o /= 3.0
		xf = Transform3D(nb, o)
	global_transform = xf

# =====================================================================================================================
# read-outs for FX / telemetry
# =====================================================================================================================
func _update_readouts(dt: float) -> void:
	var b := global_transform.basis
	var vrel := velocity - _ref_vel
	fx_speed = vrel.length()
	var vloc := b.transposed() * vrel
	if fx_speed > 1.0:
		fx_flow_dir = b.transposed() * (vrel / fx_speed)
	else:
		fx_flow_dir = Vector3(0, 0, -1)
	# engine thrust level: from commanded acceleration, boost, pulse
	var acc := (velocity - _last_vel) / maxf(dt, 0.0001)
	var acc_loc := b.transposed() * acc
	fx_accel_local = fx_accel_local.lerp(acc_loc, 1.0 - exp(-6.0 * dt))
	var thr := 0.0
	if is_landed:
		thr = 0.0
	else:
		var fwd_speed := -vloc.z
		thr = clampf(maxf(fwd_speed, 0.0) / MAX_IMPULSE, 0.0, 1.0) * 0.8
		thr = maxf(thr, clampf(_in_fwd, 0.0, 1.0) * 0.75)
		thr = maxf(thr, 0.14)
		thr = maxf(thr, absf(_in_vert) * 0.3)
		if _takeoff_assist > 0.0:
			thr = maxf(thr, 0.75)
	fx_thrust = lerpf(fx_thrust, thr, 1.0 - exp(-6.0 * dt))
	fx_boost = lerpf(fx_boost, 1.0 if boosting else 0.0, 1.0 - exp(-5.0 * dt))
	var pt := 0.0
	if pulse_state == Pulse.CHARGING:
		pt = clampf(_pulse_t / PULSE_CHARGE_TIME, 0.0, 1.0) * 0.45
	elif pulse_state == Pulse.ACTIVE:
		pt = 0.5 + 0.5 * clampf(_pulse_speed / 6000.0, 0.0, 1.0)
	fx_pulse = lerpf(fx_pulse, pt, 1.0 - exp(-(4.0 if pt > fx_pulse else 3.0) * dt))
	if fx_pulse < 0.003:
		fx_pulse = 0.0

func _state_name() -> String:
	if is_landed:
		return "LANDED"
	if _spool > 0.0:
		return "TAKE-OFF"
	if pulse_state == Pulse.CHARGING:
		return "PULSE CHARGING"
	if pulse_state == Pulse.ACTIVE:
		return "PULSE DRIVE"
	if heat > 0.2:
		return "ATMOSPHERIC ENTRY"
	if _pressure > 0.08:
		return "CRUSHING PRESSURE"
	if atmo_density > 0.0:
		return "ATMOSPHERE"
	return "SPACE"

func _publish(dt: float) -> void:
	if not piloted:
		if _was_piloted:
			_was_piloted = false
			Audio.stop_engine()
		return
	_was_piloted = true
	var t := Game.tel
	var vrel := velocity - _ref_vel
	t["speed"] = vrel.length()
	t["altitude"] = maxf(altitude - lerpf(1.9, 0.9, fx_gear), 0.0) if _def != null else -1.0
	t["state"] = _state_name()
	t["fuel"] = Game.ship_fuel
	t["hull"] = Game.ship_hull
	t["throttle"] = 1.0 if pulse_state == Pulse.ACTIVE else clampf(maxf(0.0, -(global_transform.basis.transposed() * vrel).z) / MAX_IMPULSE, 0.0, 1.0)
	t["pulse"] = pulse_state != Pulse.OFF
	t["gear"] = gear_deployed and _gear_t < 0.9
	t["boost"] = boosting
	t["vspeed"] = vrel.dot(_up) if _def != null else 0.0
	t["heat"] = heat
	t["pressure"] = _pressure
	t["ship_landed"] = is_landed
	t["ref_velocity"] = _ref_vel          # LOCAL-frame velocity of the nearest body (the ship co-moves with it): other effects can subtract it from camera motion
	Audio.set_engine(0.0 if is_landed else fx_thrust, boosting, pulse_state == Pulse.ACTIVE, atmo_density, vrel.length())
	if rig != null:
		var shake := extra_shake
		rig.base_shake = shake
