class_name BlackHole
extends Node3D
## BLACK HOLE (module M5).  Visuals: full-screen gravitational-lensing quad (shaders/blackhole_lens.gdshader: event horizon shadow, photon ring,
## accretion disc with Doppler beaming, lensed sky), near-field post effect (shaders/blackhole_post.gdshader).
## Mechanics: pull on the ship (accel = MU / r^2 via ship.external_accel), warning levels (Events.blackhole_warning), pulse-drive lock,
## control-authority fade, camera shake, point of no return (capture field), horizon crossing -> Game.warp_to_system(def.bh_dest_system, "blackhole").
## The node's transform (position = singularity centre in LOCAL coordinates) is set by Frame each frame.
## All numbers live in core/blackhole_params.gd.  Documentation: world/blackhole/README.md.


var def: BodyDef
var system: SystemDef

# ---- visuals --------------------------------------------------------------------------------------------------------------
var _lens: MeshInstance3D
var _lens_mat: ShaderMaterial
var _post_layer: CanvasLayer
var _post_rect: ColorRect
var _post_mat: ShaderMaterial
var _disc_n_abs := Vector3.UP        # accretion-disc normal in ABSOLUTE system space (the local axes are Frame.basis * this)
var _seed_f := 0.0
var _shock_t := -1.0
var _fall_k := 0.0
var _near_k := 0.0
var _tint_k := 0.0

# ---- mechanics ------------------------------------------------------------------------------------------------------------
var level: int = 0                    # 0 clear, 1 caution, 2 danger, 3 no return, 4 horizon
var distance: float = INF             # last measured ship <-> singularity distance
var captured := false                 # crossed the horizon trigger: transition running
var _arrival_t := -1.0                # seconds since a ship arrived through THIS hole (-1 = none)
var _emit_timer := 0.0
var _prev_ship_pos := Vector3.ZERO
var _have_prev := false
var _ship_touched: Node = null        # ship whose contract fields we modified (so we can reset them)
var _rumble_on := false
var _alarm_on := false
var _last_notified := 0
var _interdicted := false

func setup(p_def: BodyDef, p_sys: SystemDef) -> void:
	def = p_def
	system = p_sys

func _ready() -> void:
	process_priority = 10             # after the ship (0) has moved this frame, before Frame (100) repositions everything
	_seed_f = float(def.seed % 9973) * 0.013
	_build_disc_orientation()
	_build_lens()
	_build_post()
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	Frame.origin_shifted.connect(_on_origin_shifted)
	Frame.frame_changed.connect(_on_frame_changed)
	_arrival_t = -1.0
	if Game.warping and Game.warp_fx != null and str(Game.warp_fx.get("last_kind")) == "blackhole":
		_arrival_t = 0.0              # a ship just came out of this hole ("white hole"): pull fades in slowly, shock ring
		_shock_t = 0.0

## the swept horizon test keeps the previous LOCAL ship position: follow Frame's re-basing so a rebase can never fake a crossing
func _on_origin_shifted(shift: Vector3) -> void:
	_prev_ship_pos += shift

func _on_frame_changed(_old: int, _new: int) -> void:
	_have_prev = false

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	if Frame.origin_shifted.is_connected(_on_origin_shifted):
		Frame.origin_shifted.disconnect(_on_origin_shifted)
	if Frame.frame_changed.is_connected(_on_frame_changed):
		Frame.frame_changed.disconnect(_on_frame_changed)
	_reset_ship()
	_set_loops(false, false)

# ======================================================================================================================
# visuals
# ======================================================================================================================
func _build_disc_orientation() -> void:
	# The disc is tilted so that a ship approaching from the star side (the way Game spawns / most players come) looks at it from
	# ~10-18 degrees above its plane, with the disc's major axis horizontal on screen: the classic "Interstellar" view with the far
	# side of the disc lensed over the top and under the bottom.
	var to_star := (-def.fixed_pos).normalized()
	if to_star.length() < 0.5:
		to_star = Vector3.RIGHT
	var upv := Vector3.UP - to_star * to_star.dot(Vector3.UP)
	if upv.length() < 0.2:
		upv = Vector3.RIGHT - to_star * to_star.dot(Vector3.RIGHT)
	upv = upv.normalized()
	var elev := deg_to_rad(10.0 + SeedUtil.rand01(def.seed, 78) * 8.0)
	var n := (to_star * sin(elev) + upv * cos(elev)).normalized()
	var tilt := deg_to_rad((SeedUtil.rand01(def.seed, 77) - 0.5) * 16.0)   # a few degrees of roll around the line of sight
	_disc_n_abs = n.rotated(to_star, tilt).normalized()

func _disc_basis_local() -> Array:
	var n: Vector3 = (Frame.basis * _disc_n_abs).normalized()
	var ref := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var e1 := n.cross(ref).normalized()
	var e2 := n.cross(e1).normalized()     # e1 x e2 = n  (counter-clockwise about n)
	# n x e1 = e2 -> right-handed (e1, e2, n)
	return [n, e1, e2]

func _build_lens() -> void:
	_lens = MeshInstance3D.new()
	_lens.name = "LensQuad"
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	_lens.mesh = qm
	_lens.custom_aabb = AABB(Vector3(-1.0e7, -1.0e7, -1.0e7), Vector3(2.0e7, 2.0e7, 2.0e7))
	_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = load("res://shaders/blackhole_lens.gdshader") as Shader
	_lens_mat.render_priority = -100
	_lens_mat.set_shader_parameter("rs", def.radius)
	_lens_mat.set_shader_parameter("disc_in", def.bh_disc_inner)
	_lens_mat.set_shader_parameter("disc_out", def.bh_disc_outer)
	_lens_mat.set_shader_parameter("influence", def.bh_influence)
	_lens_mat.set_shader_parameter("disc_seed", _seed_f)
	_lens.material_override = _lens_mat
	add_child(_lens)
	_apply_debug_overrides()

## dev/test hook:  --bh=haze_k:0,brightness:1.5   (user args after `--`) overrides lens shader uniforms
func _apply_debug_overrides() -> void:
	for a in OS.get_cmdline_user_args():
		var sa := String(a)
		if not sa.begins_with("--bh="):
			continue
		for kv in sa.substr(5).split(",", false):
			var pr := kv.split(":")
			if pr.size() == 2:
				_lens_mat.set_shader_parameter(pr[0], float(pr[1]))

func _build_post() -> void:
	_post_layer = CanvasLayer.new()
	_post_layer.name = "BlackHolePost"
	_post_layer.layer = 2                 # above the 3D view, below the HUD (UI layer 10) and the warp overlay (20)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://shaders/blackhole_post.gdshader") as Shader
	_post_rect.material = _post_mat
	_post_layer.add_child(_post_rect)
	_post_layer.visible = false
	add_child(_post_layer)

## right before the frame is drawn every node transform is final: update the uniforms that depend on screen position
func _pre_draw() -> void:
	if _post_layer == null or not is_inside_tree():
		return
	var effect := maxf(_near_k, _fall_k)
	_post_layer.visible = effect > 0.004
	if not _post_layer.visible:
		return
	var cam := get_viewport().get_camera_3d()
	var uv := Vector2(0.5, 0.5)
	if cam != null and not cam.is_position_behind(global_position):
		var vs := get_viewport().get_visible_rect().size
		uv = cam.unproject_position(global_position) / vs
	_post_mat.set_shader_parameter("bh_uv", uv)
	_post_mat.set_shader_parameter("near_k", _near_k)
	_post_mat.set_shader_parameter("fall_k", _fall_k)
	_post_mat.set_shader_parameter("tint_k", _tint_k)
	_post_mat.set_shader_parameter("time_s", float(Time.get_ticks_msec() % 100000) * 0.001)

func _update_lens(dt: float) -> void:
	var b := _disc_basis_local()
	_lens_mat.set_shader_parameter("disc_n", b[0])
	_lens_mat.set_shader_parameter("disc_e1", b[1])
	_lens_mat.set_shader_parameter("disc_e2", b[2])
	_lens_mat.set_shader_parameter("disc_time", fposmod(Universe.time, 3600.0))
	if _shock_t >= 0.0:
		if Game.mode == Game.Mode.WARP:
			_shock_t = 0.0                     # the arrival is still hidden under the white-out: start the ring when the flash dissolves
		else:
			_shock_t += dt
		if _shock_t > 9.0:
			_shock_t = -1.0
	_lens_mat.set_shader_parameter("shock_t", _shock_t)
	# cull the quad when the hole is far away and not in view
	var cam := get_viewport().get_camera_3d()
	var show := true
	if cam != null:
		var to := global_position - cam.global_position
		var d := to.length()
		if d > def.bh_influence * 1.05:
			var fwd := -cam.global_transform.basis.z
			var ang := acos(clampf(fwd.dot(to / maxf(d, 1.0)), -1.0, 1.0))
			show = ang < deg_to_rad(cam.fov) * 0.95 + 0.14
	_lens.visible = show

# ======================================================================================================================
# mechanics
# ======================================================================================================================
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_update_lens(dt)
	if _arrival_t >= 0.0:
		if Game.mode == Game.Mode.WARP:
			_arrival_t = 0.0                   # system still being built under the white-out
		else:
			_arrival_t += dt
		if _arrival_t > BlackHoleParams.ARRIVAL_GRACE + 2.0:
			_arrival_t = -1.0
	_update_mechanics(dt)

func _ship_ok() -> bool:
	var s: Node3D = Game.ship
	return s != null and is_instance_valid(s) and s.is_inside_tree()

func _set_prop(ship: Object, prop: String, value: Variant) -> bool:
	if prop in ship:
		ship.set(prop, value)
		return true
	return false

func _reset_ship() -> void:
	var s := _ship_touched
	_ship_touched = null
	if s != null and is_instance_valid(s):
		_set_prop(s, "external_accel", Vector3.ZERO)
		_set_prop(s, "control_authority", 1.0)
		_set_prop(s, "pulse_locked", false)
		_set_prop(s, "extra_shake", 0.0)

func _level_for(r: float) -> int:
	var radii := [BlackHoleParams.WARN_RADIUS, BlackHoleParams.DANGER_RADIUS, BlackHoleParams.POINT_OF_NO_RETURN, def.radius * BlackHoleParams.HORIZON_TRIGGER]
	var up := 0
	for i in radii.size():
		if r < radii[i]:
			up = i + 1
	if up < level:
		# hysteresis on the way out
		if r < float(radii[level - 1]) * BlackHoleParams.HYSTERESIS:
			up = level
	return up

func _update_mechanics(dt: float) -> void:
	if not _ship_ok():
		_near_k = 0.0
		_fall_k = 0.0
		return
	var ship: Node3D = Game.ship
	var spos := ship.global_position
	var to_bh := global_position - spos
	var r := to_bh.length()
	distance = r
	var dir := to_bh / maxf(r, 0.001)
	Game.tel["bh_dist"] = r

	# visual proximity factors (also used when merely passing by)
	_near_k = clampf(1.0 - (r - 20000.0) / 100000.0, 0.0, 1.0)
	_near_k = _near_k * _near_k * (3.0 - 2.0 * _near_k)
	_fall_k = smoothstep(9000.0, def.radius * 1.08, r)
	_tint_k = smoothstep(14000.0, def.radius * 1.2, r)

	var in_warp := Game.mode == Game.Mode.WARP and not captured
	var new_level := _level_for(r)
	if captured:
		new_level = 4
	if in_warp:
		new_level = 0
	if new_level != level:
		level = new_level
		_on_level_changed()
		_emit_timer = 0.0
	elif level > 0:
		_emit_timer -= dt
		if _emit_timer <= 0.0:
			_emit_timer = 0.25
			Events.blackhole_warning.emit(level, r)
	Game.tel["bh_level"] = level

	if in_warp:
		_reset_ship()
		_have_prev = false
		_set_loops(false, false)
		return

	# ---- forces ---------------------------------------------------------------------------------------------------------
	var grace := 1.0
	if _arrival_t >= 0.0:
		grace = smoothstep(5.0, BlackHoleParams.ARRIVAL_GRACE, _arrival_t)
	var pull := def.bh_mu / maxf(r * r, 1.0)
	if r > def.bh_influence:
		pull = 0.0
	var acc := dir * pull * grace
	var vel: Vector3 = ship.get("velocity") if "velocity" in ship else Vector3.ZERO
	var capture := 0.0
	if r < BlackHoleParams.POINT_OF_NO_RETURN * 1.08 and grace >= 0.999:
		capture = smoothstep(BlackHoleParams.POINT_OF_NO_RETURN * 1.08, BlackHoleParams.POINT_OF_NO_RETURN * 0.85, r)
		var v_in := vel.dot(dir)
		var v_t := vel - dir * v_in
		var v_free := sqrt(250.0 * 250.0 + 2.0 * def.bh_mu * maxf(1.0 / r - 1.0 / BlackHoleParams.POINT_OF_NO_RETURN, 0.0))
		acc += dir * (maxf(v_free, v_in) - v_in) * BlackHoleParams.CAPTURE_RATE * capture
		acc -= v_t * BlackHoleParams.DISC_DRAG * capture
	Game.tel["bh_pull"] = pull

	# ---- gravity-well interdiction: inbound speed is limited to what the ship can still brake from before the point of no return
	var v_in_now := vel.dot(dir)
	var cap := _speed_cap(r)
	var over_cap := r < def.bh_influence and grace >= 0.999 and v_in_now > cap
	if over_cap and r > BlackHoleParams.POINT_OF_NO_RETURN * 1.08:
		acc -= dir * (v_in_now - cap) * BlackHoleParams.INTERDICT_GAIN
		if not _interdicted and v_in_now > cap * 1.25 + 200.0:
			_interdicted = true
			Events.notify.emit("Gravity well interdiction  -  drive dropped, braking field engaged", "warn")
			Events.screen_flash.emit(Color(1.0, 0.55, 0.25, 0.35), 0.5)
			Audio.sfx("warn_beep")
	elif _interdicted and v_in_now < cap:
		_interdicted = false

	# ---- "white hole" ejection: the ship leaves the singularity at ARRIVAL_ENTRY_SPEED and coasts down smoothly (the flight assist alone would
	#      stop it within ~2 s, which looks like the ship was never ejected at all) ------------------------------------------------------
	if _arrival_t >= 0.0 and _arrival_t < BlackHoleParams.ARRIVAL_EJECT_TIME and "velocity" in ship:
		var ke := 1.0 - _arrival_t / BlackHoleParams.ARRIVAL_EJECT_TIME
		var v_target := BlackHoleParams.ARRIVAL_ENTRY_SPEED * ke * ke
		var v_out := vel.dot(-dir)
		if v_out < v_target:
			ship.set("velocity", vel + (-dir) * (v_target - v_out))
			vel = ship.get("velocity")
			v_in_now = vel.dot(dir)

	# ---- authority / pulse lock / shake -----------------------------------------------------------------------------------
	var auth := 1.0
	if r < BlackHoleParams.DANGER_RADIUS:
		auth = lerpf(BlackHoleParams.AUTH_AT_DANGER, BlackHoleParams.AUTH_AT_PONR, smoothstep(BlackHoleParams.DANGER_RADIUS, BlackHoleParams.POINT_OF_NO_RETURN, r))
	if r < BlackHoleParams.POINT_OF_NO_RETURN:
		auth = lerpf(BlackHoleParams.AUTH_AT_PONR, BlackHoleParams.AUTH_AT_HORIZON, smoothstep(BlackHoleParams.POINT_OF_NO_RETURN, def.radius * 2.0, r))
	if grace < 1.0:
		auth = 1.0
	var locked := (r < BlackHoleParams.DANGER_RADIUS * (BlackHoleParams.HYSTERESIS if level >= 2 else 1.0)) and grace >= 0.999
	if not locked and grace >= 0.999 and r < def.bh_influence and v_in_now > cap * 0.8:
		locked = true                  # a pulse run that is too fast for the gravity well is dropped out early
	var shake := 0.0
	if r < BlackHoleParams.WARN_RADIUS:
		shake = 0.04 * smoothstep(BlackHoleParams.WARN_RADIUS, BlackHoleParams.DANGER_RADIUS, r)
	if r < BlackHoleParams.DANGER_RADIUS:
		shake = lerpf(0.04, 0.32, smoothstep(BlackHoleParams.DANGER_RADIUS, BlackHoleParams.POINT_OF_NO_RETURN, r))
	if r < BlackHoleParams.POINT_OF_NO_RETURN:
		shake = lerpf(0.32, BlackHoleParams.SHAKE_MAX, smoothstep(BlackHoleParams.POINT_OF_NO_RETURN, def.radius * 1.5, r))
	if grace < 1.0:
		shake *= grace

	_ship_touched = ship
	var has_contract := "external_accel" in ship
	if has_contract:
		_set_prop(ship, "external_accel", acc)
		_set_prop(ship, "control_authority", auth)
		_set_prop(ship, "pulse_locked", locked)
		_set_prop(ship, "extra_shake", shake)
	elif "velocity" in ship:
		# fallback for a ship without the contract: nudge the velocity ourselves
		ship.set("velocity", vel + acc * dt)

	# ---- audio ------------------------------------------------------------------------------------------------------------
	_set_loops(r < BlackHoleParams.WARN_RADIUS * 1.2, level >= 3)
	if _rumble_on:
		Audio.set_loop("blackhole_rumble", true, clampf(1.0 - (r - BlackHoleParams.POINT_OF_NO_RETURN) / BlackHoleParams.WARN_RADIUS, 0.12, 1.0))

	# ---- horizon crossing (swept test so a fast ship cannot tunnel through) --------------------------------------------------
	if not captured and not Game.warping:
		var hz := def.radius * BlackHoleParams.HORIZON_TRIGGER
		var crossed := r < hz
		if _have_prev:
			var seg := spos - _prev_ship_pos
			var segl := seg.length()
			if segl > 0.001:
				var t := clampf((global_position - _prev_ship_pos).dot(seg) / (segl * segl), 0.0, 1.0)
				var closest := _prev_ship_pos + seg * t
				if closest.distance_to(global_position) < hz:
					crossed = true
		if crossed:
			_enter_horizon()
	_prev_ship_pos = spos
	_have_prev = true

## maximum safe inbound speed at distance r (m/s): the speed from which a ship braking at SAFE_BRAKE can still stop before the point of no return
func _speed_cap(r: float) -> float:
	var room := maxf(r - BlackHoleParams.POINT_OF_NO_RETURN * 1.3, 0.0)
	return 300.0 + sqrt(2.0 * BlackHoleParams.SAFE_BRAKE * room)

func _on_level_changed() -> void:
	Events.blackhole_warning.emit(level, distance)
	match level:
		1:
			if _last_notified < 1:
				Events.notify.emit("Gravitational anomaly ahead  -  singularity detected", "warn")
				Audio.sfx("warn_beep")
		2:
			if _last_notified < 2:
				Events.notify.emit("DANGER: pulse drive offline, hull under tidal stress", "danger")
				Audio.sfx("warn_beep")
		3:
			if _last_notified < 3:
				Events.notify.emit("POINT OF NO RETURN", "danger")
				Events.hint.emit("The singularity has you  -  there is no escape now", 5.0)
	_last_notified = maxi(_last_notified, level)
	if level == 0:
		_last_notified = 0

func _set_loops(rumble: bool, alarm: bool) -> void:
	if rumble != _rumble_on:
		_rumble_on = rumble
		Audio.set_loop("blackhole_rumble", rumble, 0.4)
	if alarm != _alarm_on:
		_alarm_on = alarm
		Audio.set_loop("alarm", alarm, 0.7)

func _enter_horizon() -> void:
	captured = true
	level = 4
	Events.blackhole_warning.emit(4, distance)
	Events.blackhole_entered.emit()
	Audio.sfx("blackhole_enter")
	_set_loops(true, false)
	if def.bh_dest_system >= 0:
		Game.warp_to_system(def.bh_dest_system, "blackhole")
