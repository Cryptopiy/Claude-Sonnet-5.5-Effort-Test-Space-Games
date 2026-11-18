class_name ShipCameraRig
extends Node3D
## Ship cameras (children of the Ship, so frame shifts / rebases move them for free): a lagged chase camera (anchor Anchor_ChaseCam) and a cockpit camera
## (Anchor_Cockpit). Lag state is stored RELATIVE to the ship (rotation lag basis, position lag in ship axes), so it is frame-agnostic;
## Ship._on_frame_shift() calls on_frame_shift(rot) to keep the reference basis consistent. FOV widens with boost / pulse, shake = continuous + impulses.

var ship: Ship
var chase: Camera3D
var cockpit: Camera3D
var mode := 0                       # 0 chase, 1 cockpit
var base_shake := 0.0               # set by the ship every frame (black-hole shake etc.)
var chase_aim_y := -4.2             # y of the point the chase camera looks at (48 m ahead of the ship); lower = the ship sits higher in the frame (clear of the HUD)
var cockpit_eye := Vector3(0.0, 0.3, 0.4)   # additive offset of the cockpit eye point: the modelled anchor sits inside the canopy ribs; this moves the eye up/back so they frame the view instead of filling it
var hide_canopy_in_cockpit := true  # the glass ribs are modelled as thick geometry: they would block the view from the inside

var _active := false
var _lag := Basis.IDENTITY          # camera orientation relative to the ship
var _prev_basis := Basis.IDENTITY
var _lag_pos := Vector3.ZERO
var _kick_pos := Vector3.ZERO
var _kick_vel := Vector3.ZERO
var _shake_imp := 0.0
var _extra_shake := 0.0
var _fov := 78.0
var _back := 0.0                    # smoothed extra distance behind the ship (speed)
var _t := 0.0
var _canopy: Node3D
var _hull_mi: MeshInstance3D
var _trim_surf := -1
var _ghost_mat: StandardMaterial3D

func setup(p_ship: Ship) -> void:
	ship = p_ship
	chase = Camera3D.new()
	chase.name = "ChaseCam"
	chase.near = Game.CAMERA_NEAR_SHIP
	chase.far = Game.CAMERA_FAR_SHIP
	chase.fov = float(Game.settings.get("fov", 78.0))
	add_child(chase)
	cockpit = Camera3D.new()
	cockpit.name = "CockpitCam"
	cockpit.near = Game.CAMERA_NEAR_FOOT
	cockpit.far = Game.CAMERA_FAR_FOOT
	cockpit.fov = float(Game.settings.get("fov", 78.0))
	add_child(cockpit)
	_prev_basis = ship.global_transform.basis
	_fov = chase.fov
	_canopy = ModelLib.find_node(ship.model, "Canopy") as Node3D
	_apply_static()

func reset() -> void:
	_lag = Basis.IDENTITY
	if ship != null:
		_prev_basis = ship.global_transform.basis
	_lag_pos = Vector3.ZERO
	_kick_pos = Vector3.ZERO
	_kick_vel = Vector3.ZERO
	_shake_imp = 0.0
	_back = 0.0

func on_frame_shift(rot: Basis) -> void:
	_prev_basis = rot * _prev_basis

func set_active(on: bool) -> void:
	_active = on
	if on:
		_select_current()
	else:
		chase.current = false
		cockpit.current = false
		_set_canopy(true)

func toggle() -> void:
	mode = 1 - mode
	_select_current()
	Events.notify.emit("Camera: " + ("cockpit" if mode == 1 else "chase"), "info")

func _select_current() -> void:
	if not _active:
		_set_canopy(true)
		return
	_set_canopy(mode == 0 or not hide_canopy_in_cockpit)
	if mode == 0:
		chase.make_current()
	else:
		cockpit.make_current()

func _set_canopy(vis: bool) -> void:
	if _canopy != null and is_instance_valid(_canopy):
		_canopy.visible = vis
	_set_ribs_ghost(not vis)

## The canopy frame ribs are part of the Hull's "dark" surface (thick when seen from inside): in the cockpit view they are drawn as a faint ghost so they
## still hint at the canopy without caging the view.
func _set_ribs_ghost(on: bool) -> void:
	if _hull_mi == null:
		_hull_mi = ModelLib.find_node(ship.model, "Hull") as MeshInstance3D
		if _hull_mi == null or _hull_mi.mesh == null:
			return
		for i in _hull_mi.mesh.get_surface_count():
			var m := _hull_mi.get_active_material(i) as StandardMaterial3D
			if m != null and m.resource_name.ends_with("dark"):
				_trim_surf = i
				_ghost_mat = m.duplicate() as StandardMaterial3D
				_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_ghost_mat.albedo_color.a = 0.14
				_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _trim_surf < 0 or _hull_mi == null:
		return
	_hull_mi.set_surface_override_material(_trim_surf, _ghost_mat if on else null)

## impulse: positional kick in ship space (decays like a spring), shake: 0..1
func kick(pos_impulse: Vector3, shake: float) -> void:
	_kick_vel += pos_impulse * 14.0
	_shake_imp = maxf(_shake_imp, shake)

func add_shake(amount: float) -> void:
	_extra_shake = maxf(_extra_shake, amount)

func _apply_static() -> void:
	chase.position = ship.anchor_chase()
	cockpit.position = ship.anchor_cockpit()

func _noise(seed_v: float, speed: float) -> float:
	var a := _t * speed + seed_v * 12.9898
	return sin(a) * 0.55 + sin(a * 2.31 + seed_v * 3.7) * 0.3 + sin(a * 4.77 + seed_v * 1.3) * 0.15

func update(dt: float) -> void:
	_t += dt
	var sb := ship.global_transform.basis
	# --- rotation lag (keep the camera's world orientation, then ease back to the ship's) ---
	_lag = (sb.inverse() * _prev_basis) * _lag
	_prev_basis = sb
	var q := _lag.get_rotation_quaternion()
	var ang := q.get_angle()
	if ang > 0.55:
		q = Quaternion.IDENTITY.slerp(q, 0.55 / ang)
	var lag_k := 5.2 + 2.0 * ship.fx_pulse
	q = Quaternion.IDENTITY.slerp(q, exp(-lag_k * dt))
	_lag = Basis(q)
	# --- position lag from acceleration, back-off from speed ---
	var acc := ship.fx_accel_local
	var tgt := Vector3(clampf(-acc.x * 0.012, -1.6, 1.6), clampf(-acc.y * 0.012, -1.2, 1.2), clampf(-acc.z * 0.010, -2.5, 3.5))
	_lag_pos = _lag_pos.lerp(tgt, 1.0 - exp(-4.0 * dt))
	var back_t := 1.8 * ship.fx_boost + 5.5 * ship.fx_pulse
	_back = lerpf(_back, back_t, 1.0 - exp(-3.0 * dt))
	# --- kick spring ---
	_kick_vel += (-120.0 * _kick_pos - 14.0 * _kick_vel) * dt
	_kick_pos += _kick_vel * dt
	_shake_imp = maxf(0.0, _shake_imp - dt * 1.6)
	var cont := ship.fx_boost * 0.10 + ship.fx_pulse * 0.07 + ship.heat * 0.85 + ship.fx_spool * 0.22 + base_shake + _extra_shake
	_extra_shake = 0.0
	var sh := clampf(cont + _shake_imp, 0.0, 1.5)
	# --- FOV ---
	var base_fov := float(Game.settings.get("fov", 78.0))
	var fov_t := base_fov + 9.0 * ship.fx_boost + 26.0 * ship.fx_pulse + clampf(ship.fx_speed / 1500.0, 0.0, 1.0) * 4.0
	_fov = lerpf(_fov, fov_t, 1.0 - exp(-4.0 * dt))
	if not _active:
		return
	if mode == 0:
		_update_chase(sh)
	else:
		_update_cockpit(sh)

func _shake_offset(sh: float, scale: float) -> Vector3:
	return Vector3(_noise(1.0, 38.0), _noise(2.0, 41.0), _noise(3.0, 29.0)) * (0.16 * sh * scale)

func _shake_rot(sh: float, scale: float) -> Basis:
	var ax := _noise(4.0, 33.0) * 0.013 * sh * scale
	var ay := _noise(5.0, 36.0) * 0.013 * sh * scale
	var az := _noise(6.0, 27.0) * 0.016 * sh * scale
	return Basis.from_euler(Vector3(ax, ay, az))

func _update_chase(sh: float) -> void:
	var a := ship.anchor_chase()
	var base := Vector3(a.x, a.y - 0.6 + 0.35 * _back, a.z + 0.4 + _back)
	if ship.is_landed:
		base = Vector3(a.x, a.y + 0.6, a.z + 1.5)
	var target := Vector3(0.0, chase_aim_y, -48.0)
	var look := Basis.looking_at((target - base).normalized(), Vector3.UP)
	var pos := _lag * base + _lag_pos + _kick_pos + _shake_offset(sh, 1.0)
	chase.transform = Transform3D(_lag * look * _shake_rot(sh, 1.0), pos)
	chase.fov = _fov

func _update_cockpit(sh: float) -> void:
	var a := ship.anchor_cockpit()
	var lag_c := Basis(Quaternion.IDENTITY.slerp(_lag.get_rotation_quaternion(), 0.28))
	var pos := a + cockpit_eye + _lag_pos * 0.12 + _kick_pos * 0.4 + _shake_offset(sh, 0.45)
	cockpit.transform = Transform3D(lag_c * _shake_rot(sh, 0.7), pos)
	cockpit.fov = _fov
