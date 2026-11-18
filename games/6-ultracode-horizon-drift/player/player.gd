class_name Player
extends CharacterBody3D
## ON-FOOT PLAYER (module M4 owns player/* and shaders/player*).
##
## Public API (Game relies on it, do not change):
##   spawn_at(local_pos: Vector3, up: Vector3, facing: Vector3)   # stand at the position (planet space == local space in a body frame)
##   set_active(on: bool)                                         # enable input / visibility / make the player camera current
##   _on_frame_shift(rot, shift, vel_offset)                      # Frame calls after moving the node: velocity = rot*velocity + vel_offset
## Extra public surface:
##   scan_markers: Array of {pos: Vector3 (LOCAL), label: String, kind: String ("poi"|"resource"|"creature"|"ship"), time_left: float}  (HUD reads it)
##   third_person (V toggles), health/protection/jetpack/stamina via `vitals`, debug_look(dx, dy), debug_state()
##
## Controller: CharacterBody3D standing on a sphere (up = radial), gravity from Planet.gravity_at, collision from the terrain patch
## (Planet.set_collision_focus / is_collision_ready) with an analytic terrain_radius_at safety net so the player can never fall through.
## Runs in _process (priority -10: before HUD/ship/Frame) with a clamped variable dt, like the rest of the game.
## Writes Game.tel: speed, state, health, protection, jetpack, stamina, gravity, temp_c, hazard, hazard_level, altitude, vspeed (+ mine_progress).

# ---- tuning -----------------------------------------------------------------------------------------------------------------
const WALK_SPEED := 6.0
const SPRINT_SPEED := 11.0
const CROUCH_SPEED := 3.0
const SWIM_SPEED := 3.4
const GROUND_ACCEL := 60.0
const GROUND_FRICTION := 46.0
const AIR_ACCEL := 5.0
const JET_ACCEL_H := 15.0
const JET_UP_SPEED := 9.0
const JET_UP_ACCEL := 13.0
const JET_DRAIN := 0.11
const RADIUS := 0.36
const STAND_H := 1.8
const CROUCH_H := 1.25
const EYE_STAND := 1.62
const EYE_CROUCH := 1.08
const MINE_RANGE := 25.0
const MINING_POWER := 1.0              # beam damage per second given to resource_node.mine(dmg)
const SCAN_RANGE := 600.0
const SCAN_COOLDOWN := 3.0
const CREATURE_SCAN_RANGE := 260.0
const RESOURCE_CLUSTER_RADIUS := 24.0
const CREATURE_CLUSTER_RADIUS := 40.0
const MAX_RESOURCE_MARKERS := 14
const MAX_CREATURE_MARKERS := 4
const MARKER_LIFETIME := 20.0
const INTERACT_RANGE := 4.5
const SHIP_ENTER_RANGE := 6.5
const SHIP_HALF := Vector3(5.6, 2.3, 6.8)    # approximate walk-around box of the ship (ship space)
# physics layers (docs/ARCHITECTURE.md section 4): 1 terrain, 2 props, 3 resource nodes, 4 ship hull, 5 player, 6 creatures, 7 interactables
const LAYER_PLAYER := 16
const MASK_BODY := 1 | 2 | 8 | 32
const MASK_MINING := 1 | 2 | 4 | 32
const MASK_CAMERA := 1 | 2 | 8
const ONE_SHOTS := ["interact", "scan", "toggle_light", "toggle_camera", "move_up"]
const SURFACES := {"lush": "grass", "desert": "sand", "frozen": "snow", "volcanic": "ash", "toxic": "mud", "barren": "rock", "ocean": "sand",
	"exotic": "rock", "swamp": "mud", "radioactive": "ash"}
const DUST_COLORS := {"lush": Color(0.48, 0.44, 0.30), "desert": Color(0.82, 0.64, 0.40), "frozen": Color(0.90, 0.95, 1.0),
	"volcanic": Color(0.25, 0.22, 0.21), "toxic": Color(0.52, 0.62, 0.30), "barren": Color(0.58, 0.57, 0.55), "ocean": Color(0.86, 0.82, 0.68),
	"exotic": Color(0.72, 0.52, 0.82), "swamp": Color(0.40, 0.45, 0.28), "radioactive": Color(0.70, 0.72, 0.30)}

# ---- public state -------------------------------------------------------------------------------------------------------------
var cam: Camera3D
var active: bool = false
var third_person: bool = false
var scan_markers: Array = []
var vitals: PlayerVitals = PlayerVitals.new()
var rig: AstronautRig
var viewmodel: FPViewmodel
var beam: MiningBeam
var scanner: ScannerFX
var head: Node3D
var flashlight: SpotLight3D
var on_floor_state: bool = false
var debug_orbit: Vector3 = Vector3.INF   # test helper: (yaw, height, distance) of a 3rd-person orbit camera around the player

# ---- internals -----------------------------------------------------------------------------------------------------------------
var _col: CollisionShape3D
var _cap: CapsuleShape3D
var _planet: Planet
var _pitch: float = 0.0
var _look_frame: Vector2 = Vector2.ZERO
var _eye: float = EYE_STAND
var _crouch: float = 0.0
var _crouching: bool = false
var _grounded: bool = false
var _was_grounded: bool = false
var _coyote: float = 0.0
var _air_time: float = 0.0
var _ground_time: float = 0.0
var _jet_on: bool = false
var _jet_visual: float = 0.0
var _jet_was_on: bool = false
var _phase: float = 0.0
var _last_step_idx: int = 0
var _swimming: bool = false
var _water_depth: float = 0.0
var _liquid_kind: String = "water"
var _sprinting: bool = false
var _land_dip: float = 0.0
var _fall_speed: float = 0.0
var _bob_x: float = 0.0
var _bob_y: float = 0.0
var _roll: float = 0.0
var _fov_cur: float = 78.0
var _tp_dist: float = 3.2
var _t: float = 0.0
var _unready_t: float = 0.0
var _prev: Dictionary = {}
var _queued: Dictionary = {}
var _scan_cd: float = 0.0
var _scan_clock: float = -1.0
var _pending_scan: Array = []
var _scan_found: Array = [0, 0, 0]
var _interact_target: Node = null
var _interact_is_ship: bool = false
var _interact_timer: float = 0.0
var _mine_progress: float = 0.0
var _mine_target: Node = null
var _beam_color: Color = Color(0.20, 0.85, 1.0)
var _mining_active: bool = false
var _ambient_timer: float = 0.0
var _vitals_emit: float = 0.0
var _sun_sin: float = 1.0
var _water_overlay: ColorRect
var _water_layer: CanvasLayer
var _dust: GPUParticles3D
var _jet_dust: GPUParticles3D
var _dust_mat: StandardMaterial3D
var _last_surface: String = "rock"
var _dying: bool = false
var _hint_hold: float = 0.0
var _jump_buffer: float = 0.0

func _ready() -> void:
	add_to_group("frame_objects")
	process_priority = -10
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_constant_speed = false
	max_slides = 6
	wall_min_slide_angle = deg_to_rad(12.0)
	collision_layer = 0
	collision_mask = MASK_BODY
	_build()
	visible = false

func _build() -> void:
	_col = CollisionShape3D.new()
	_col.name = "Collider"
	_cap = CapsuleShape3D.new()
	_cap.radius = RADIUS
	_cap.height = STAND_H
	_col.shape = _cap
	_col.position.y = STAND_H * 0.5
	_col.disabled = true
	add_child(_col)
	rig = AstronautRig.new()
	rig.name = "Rig"
	add_child(rig)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.name = "PlayerCamera"
	cam.near = Game.CAMERA_NEAR_FOOT
	cam.far = Game.CAMERA_FAR_FOOT
	_fov_cur = float(Game.settings.get("fov", 78.0))
	cam.fov = _fov_cur
	head.add_child(cam)
	viewmodel = FPViewmodel.new()
	viewmodel.name = "Viewmodel"
	cam.add_child(viewmodel)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(1.0, 0.96, 0.86)
	flashlight.light_energy = 6.0
	flashlight.spot_range = 90.0
	flashlight.spot_angle = 30.0
	flashlight.spot_angle_attenuation = 0.8
	flashlight.spot_attenuation = 0.8
	flashlight.shadow_enabled = true
	flashlight.light_cull_mask = 0xFFFFF & ~FPViewmodel.LAYER_MASK      # the flashlight must not wash out the first-person arms/tool
	flashlight.position = Vector3(0.16, -0.14, -0.15)
	flashlight.visible = false
	head.add_child(flashlight)
	beam = MiningBeam.new()
	beam.name = "MiningBeam"
	add_child(beam)
	scanner = ScannerFX.new()
	scanner.name = "ScannerFX"
	add_child(scanner)
	_build_dust()
	var focus_keeper: Node = preload("res://player/collision_focus.gd").new()
	focus_keeper.name = "CollisionFocus"
	focus_keeper.set("player", self)
	add_child(focus_keeper)
	_water_layer = CanvasLayer.new()
	_water_layer.layer = 4
	_water_layer.visible = false
	add_child(_water_layer)
	_water_overlay = ColorRect.new()
	_water_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_overlay.color = Color(0.05, 0.28, 0.42, 0.45)
	_water_layer.add_child(_water_overlay)
	rig.set_first_person(not third_person)
	rig.set_tool_visible(third_person)
	viewmodel.visible = not third_person

func _build_dust() -> void:
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.vertex_color_use_as_albedo = true
	_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_mat.albedo_texture = MiningBeam.glow_texture()
	_dust_mat.albedo_color = Color(0.6, 0.55, 0.45, 0.8)
	_dust_mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = _dust_mat
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	for i in 2:
		var p := GPUParticles3D.new()
		p.local_coords = false
		p.emitting = false
		p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 80.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 2.2
		pm.gravity = Vector3(0, 0.2, 0)
		pm.damping_min = 0.8
		pm.damping_max = 1.6
		pm.scale_min = 0.8
		pm.scale_max = 1.6
		pm.scale_curve = sct
		pm.color_ramp = rt
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.35
		p.process_material = pm
		p.draw_pass_1 = quad
		if i == 0:
			p.amount = 14
			p.lifetime = 1.3
			p.one_shot = true
			p.explosiveness = 0.95
			_dust = p
		else:
			p.amount = 34
			p.lifetime = 1.0
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 5.0
			pm.spread = 88.0
			pm.emission_sphere_radius = 0.9
			_jet_dust = p
		p.top_level = true
		add_child(p)

# =====================================================================================================================
# public API
# =====================================================================================================================
func spawn_at(pos: Vector3, up: Vector3, facing: Vector3) -> void:
	var up_n := up.normalized()
	var planet := Frame.anchor_node() as Planet
	var p := pos
	if planet != null and pos.length() > 1.0:
		var d := pos.normalized()
		var gr := planet.terrain_radius_at(d)
		if pos.length() < gr + 0.08:
			p = d * (gr + 0.08)
		up_n = d
	var f := facing - up_n * facing.dot(up_n)
	if f.length_squared() < 0.0001:
		f = up_n.cross(Vector3.RIGHT)
		if f.length_squared() < 0.0001:
			f = up_n.cross(Vector3.FORWARD)
	f = f.normalized()
	global_transform = Transform3D(Basis.looking_at(f, up_n), p)
	velocity = Vector3.ZERO
	_pitch = 0.0
	_crouch = 0.0
	_crouching = false
	_eye = EYE_STAND
	_set_height(false)
	_air_time = 0.0
	_ground_time = 0.0
	_jet_on = false
	_swimming = false
	_land_dip = 0.0
	_unready_t = 0.0
	_fall_speed = 0.0
	_mine_target = null
	scan_markers.clear()
	_pending_scan.clear()
	_dying = false
	if vitals.dead:
		vitals.reset(0.75)
	if planet != null:
		planet.set_collision_focus(p, 80.0)

func set_active(on: bool) -> void:
	active = on
	visible = on
	_col.set_deferred("disabled", not on)
	collision_layer = LAYER_PLAYER if on else 0
	if on:
		cam.make_current()
		_apply_view_mode()
		_prev.clear()
		_queued.clear()
		velocity = Vector3.ZERO
		_unready_t = 0.0
		_hint_hold = 0.0
	else:
		_stop_loops()
		beam.stop()
		flashlight.visible = false
		_water_layer.visible = false
		scanner.visible = false
		# the HUD draws player.scan_markers in every mode: nothing of an on-foot scan may linger on the ship HUD
		scan_markers.clear()
		_pending_scan.clear()
		_scan_clock = -1.0
		_interact_target = null
		_interact_is_ship = false

func _on_frame_shift(rot: Basis, shift: Vector3, vel_offset: Vector3) -> void:
	velocity = rot * velocity + vel_offset
	for m in scan_markers:
		var md: Dictionary = m
		md["pos"] = rot * (md["pos"] as Vector3) + shift
	for pe in _pending_scan:
		var pd: Dictionary = pe
		var mk: Dictionary = pd["marker"]
		mk["pos"] = rot * (mk["pos"] as Vector3) + shift
	if scanner != null:
		scanner._on_frame_shift(rot, shift, vel_offset)

## test helper: apply a mouse-look delta in radians (yaw right = +x, look down = +y)
func debug_look(dx: float, dy: float) -> void:
	_apply_look(Vector2(dx, dy))

func debug_state() -> Dictionary:
	return {"grounded": _grounded, "jet": _jet_on, "swim": _swimming, "crouch": _crouching, "sprint": _sprinting, "pitch": _pitch,
		"up": global_transform.basis.y, "alt": Game.tel.get("altitude", -1.0), "third": third_person, "markers": scan_markers.size()}

# =====================================================================================================================
# input
# =====================================================================================================================
func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventMouseMotion:
		_apply_look(Game.mouse_look_delta(ev))
		return
	for a in ONE_SHOTS:
		if ev.is_action_pressed(a) and not ev.is_echo():
			_queued[a] = true

func _edge(action: String, live: bool) -> bool:
	var now := Input.is_action_pressed(action)
	var hit: bool = (now and not bool(_prev.get(action, false))) or bool(_queued.get(action, false))
	_prev[action] = now
	_queued[action] = false
	return hit and live

func _apply_look(d: Vector2) -> void:
	if d == Vector2.ZERO:
		return
	var b := global_transform.basis
	global_transform.basis = (Basis(b.y, -d.x) * b).orthonormalized()
	_pitch = clampf(_pitch - d.y, -1.50, 1.50)
	_look_frame += d

# =====================================================================================================================
# main loop
# =====================================================================================================================
func _process(delta: float) -> void:
	if not active:
		return
	var dt := minf(delta, 0.05)
	_t += dt
	var live := Game.input_enabled()
	_planet = Frame.anchor_node() as Planet
	_align_up(dt)
	var up := global_transform.basis.y
	_sun_sin = Frame.sun_dir.dot(up)

	# ---- one-shot actions --------------------------------------------------------------------------------------------------
	var e_interact := _edge("interact", live)
	var e_scan := _edge("scan", live)
	var e_light := _edge("toggle_light", live)
	var e_cam := _edge("toggle_camera", live)
	var e_jump := _edge("move_up", live)
	if e_cam:
		third_person = not third_person
		_apply_view_mode()
	if e_light:
		flashlight.visible = not flashlight.visible
		Audio.sfx("ui_click")
	if e_jump:
		_jump_buffer = 0.12
	_jump_buffer = maxf(0.0, _jump_buffer - dt)

	var in_vec := Vector2.ZERO
	var held_up := false
	var held_down := false
	var held_sprint := false
	var fire := false
	var aim := false
	if live:
		in_vec = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		held_up = Input.is_action_pressed("move_up")
		held_down = Input.is_action_pressed("move_down")
		held_sprint = Input.is_action_pressed("sprint")
		fire = Input.is_action_pressed("fire")
		aim = Input.is_action_pressed("aim")

	_update_water(dt)
	_move(dt, in_vec, held_sprint, held_up, held_down)

	# ---- vitals / hazards ------------------------------------------------------------------------------------------------
	var near_ship := _ship_distance() < 9.0
	var def := _planet.def if _planet != null else null
	vitals.evaluate_hazard(def, _sun_sin, _liquid_kind if _planet != null and _planet.sea_radius() > 0.0 else "", _water_depth)
	var died := vitals.update(dt, near_ship, _liquid_kind, _water_depth, _sprinting, _jet_on, _grounded)
	if died and not _dying:
		_dying = true
		Events.screen_flash.emit(Color(1.0, 0.1, 0.05, 0.6), 1.0)
		Events.player_died.emit()
	_vitals_emit -= dt
	if _vitals_emit <= 0.0:
		_vitals_emit = 0.5
		Events.vitals_changed.emit()

	# ---- tools ---------------------------------------------------------------------------------------------------------------
	_update_camera(dt, aim, fire)
	_update_mining(dt, fire and not _swimming_underwater())
	_update_scan(dt, e_scan)
	_update_markers(dt)
	_update_interaction(dt, e_interact)
	_update_fx(dt)
	_update_rig(dt, fire)
	_update_tel()
	_update_ambient(dt)
	_look_frame = Vector2.ZERO

# =====================================================================================================================
# movement
# =====================================================================================================================
func _align_up(dt: float) -> void:
	if _planet == null:
		return
	var p := global_position
	if p.length() < 1.0:
		return
	var target := p.normalized()
	var b := global_transform.basis
	var cur := b.y
	var d := clampf(cur.dot(target), -1.0, 1.0)
	if d > 0.9999995:
		return
	var angle := acos(d)
	var axis := cur.cross(target)
	if axis.length_squared() < 1e-12:
		axis = b.x
	axis = axis.normalized()
	var k := 1.0 if angle > 0.35 else 1.0 - exp(-16.0 * dt)
	global_transform.basis = (Basis(axis, angle * k) * b).orthonormalized()

func _set_height(crouching: bool) -> void:
	var h := CROUCH_H if crouching else STAND_H
	if absf(_cap.height - h) > 0.001:
		_cap.height = h
		_col.position.y = h * 0.5

func _can_stand() -> bool:
	if _cap.height >= STAND_H - 0.01:
		return true
	var up := global_transform.basis.y
	var saved_h := _cap.height
	_cap.height = STAND_H
	_col.position.y = STAND_H * 0.5
	var blocked := test_move(global_transform, up * 0.06)
	_cap.height = saved_h
	_col.position.y = saved_h * 0.5
	return not blocked

func _update_water(dt: float) -> void:
	_water_depth = 0.0
	_liquid_kind = "water"
	if _planet == null:
		return
	var sea := _planet.sea_radius()
	if sea <= 0.0:
		return
	_liquid_kind = _planet.def.ocean_kind if _planet.def.ocean_kind != "" else "water"
	var feet := global_position.length()
	_water_depth = maxf(0.0, sea - feet)
	if _swimming:
		if _water_depth < 0.9:
			_swimming = false
	elif _water_depth > 1.25:
		_swimming = true

func _swimming_underwater() -> bool:
	if _planet == null or _water_depth <= 0.0:
		return false
	return _water_depth - _eye > 0.0

func _move(dt: float, in_vec: Vector2, held_sprint: bool, held_up: bool, held_down: bool) -> void:
	var b := global_transform.basis
	var up := b.y
	var fwd := -b.z
	var right := b.x
	var planet := _planet
	# ---- terrain collision patch ---------------------------------------------------------------------------------------
	if planet != null:
		planet.set_collision_focus(global_position, 80.0)
		if not planet.is_collision_ready(global_position) and _unready_t < 2.5:
			_unready_t += dt
			velocity = Vector3.ZERO
			var r0 := global_position.length()
			var d0 := global_position / maxf(r0, 1.0)
			var g0 := planet.terrain_radius_at(d0)
			if r0 < g0:
				global_position = d0 * g0
			_grounded = true
			return
		else:
			_unready_t = 0.0 if planet.is_collision_ready(global_position) else _unready_t
	var g_vec := Vector3.ZERO
	if planet != null:
		g_vec = planet.gravity_at(global_position)
	var g_mag := g_vec.length()
	var v_up := velocity.dot(up)
	var v_h := velocity - up * v_up
	var prev_v_up := v_up
	_was_grounded = _grounded

	# ---- state flags ------------------------------------------------------------------------------------------------------
	var want_crouch := held_down and _grounded and not _swimming
	if want_crouch:
		_crouching = true
	elif _crouching and _can_stand():
		_crouching = false
	var wants_move := in_vec.length() > 0.1
	var can_sprint := (not vitals.exhausted) and vitals.stamina > 0.02
	_sprinting = held_sprint and in_vec.y > 0.1 and not _crouching and (can_sprint or _swimming or _jet_on) and (_grounded or _swimming or _jet_on)
	_set_height(_crouching)

	# ---- target horizontal velocity -----------------------------------------------------------------------------------------
	var speed := WALK_SPEED
	if _crouching:
		speed = CROUCH_SPEED
	elif _sprinting:
		speed = SPRINT_SPEED
	if _swimming:
		speed = SWIM_SPEED * (1.7 if held_sprint else 1.0)
	elif _water_depth > 0.1:
		var wade := clampf(_water_depth / 1.2, 0.0, 1.0)
		speed *= lerpf(1.0, 0.55, wade)
		if _liquid_kind == "lava":
			speed *= 0.6
	if _jet_on:
		speed = maxf(speed, 13.0 if held_sprint else 8.5)
	var wish := right * in_vec.x + fwd * in_vec.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target_v := wish * speed
	var accel := 0.0
	if _swimming:
		accel = 10.0
	elif _grounded:
		accel = GROUND_ACCEL if wants_move else GROUND_FRICTION
	elif _jet_on:
		accel = JET_ACCEL_H if wants_move else 3.0
	elif wants_move:
		accel = AIR_ACCEL
	if planet == null:
		accel = 20.0 if wants_move else 4.0
	if accel > 0.0:
		v_h = v_h.move_toward(target_v if (wants_move or _grounded or _swimming) else v_h, accel * dt)
	if not _grounded and not wants_move and not _jet_on:
		v_h *= (1.0 - 0.02 * dt)

	# ---- vertical: gravity, jump, jetpack, swimming ---------------------------------------------------------------------------
	_coyote = 0.12 if _grounded else maxf(0.0, _coyote - dt)
	var thrusting := false
	if _swimming:
		var sea := planet.sea_radius() if planet != null else 0.0
		var feet := global_position.length()
		var buoy_target := sea - (_eye - 0.18)
		var vt := clampf((buoy_target - feet) * 2.2, -2.5, 2.5)
		if held_up:
			vt = 3.0
		elif held_down:
			vt = -3.0
		v_up = lerpf(v_up, vt, 1.0 - exp(-6.0 * dt))
		if _liquid_kind == "lava":
			v_up = lerpf(v_up, maxf(vt, 0.6), 1.0 - exp(-3.0 * dt))
	else:
		v_up -= g_mag * dt
		var can_jump := (_grounded or _coyote > 0.0) and not _crouching
		if _jump_buffer > 0.0 and can_jump:
			var jv := clampf(sqrt(2.0 * maxf(g_mag, 1.0) * 1.25), 3.4, 7.2)
			v_up = jv
			_jump_buffer = 0.0
			_coyote = 0.0
			_grounded = false
			_air_time = 0.0
			Audio.sfx("jump")
			_burst_dust(0.5)
		# jetpack: hold jump while airborne
		if held_up and not _grounded and _air_time > 0.2 and vitals.jetpack > 0.01 and planet != null:
			thrusting = true
			var hover := held_down
			var climb := 0.0 if hover else JET_UP_SPEED
			if v_up < climb:
				v_up = minf(climb, v_up + (g_mag + JET_UP_ACCEL) * dt)
			elif hover:
				v_up = maxf(climb, v_up - 18.0 * dt)
			else:
				v_up = minf(v_up, climb + 0.5)
			vitals.jetpack = maxf(0.0, vitals.jetpack - JET_DRAIN * (0.55 if hover else 1.0) * dt)
	if planet == null:
		v_up = 0.0
		if held_up:
			v_up = 6.0
		elif held_down:
			v_up = -6.0
	_jet_on = thrusting
	if _jet_on and not _jet_was_on:
		Audio.sfx("jetpack_puff")
	_jet_was_on = _jet_on
	velocity = v_h + up * v_up

	# ---- slide ----------------------------------------------------------------------------------------------------------------
	up_direction = up
	floor_snap_length = 0.55 if (_grounded and v_up <= 0.05 and not _swimming) else 0.0
	move_and_slide()
	on_floor_state = is_on_floor()
	var grounded_now := is_on_floor()

	# ---- analytic safety net: never below the analytic surface -------------------------------------------------------------
	if planet != null:
		var p := global_position
		var r := p.length()
		if r > 1.0:
			var d := p / r
			var gr := planet.terrain_radius_at(d)
			if r < gr:
				global_position = d * gr
				var vu := velocity.dot(d)
				if vu < 0.0:
					velocity -= d * vu
				grounded_now = true
			elif r < gr + 0.05 and velocity.dot(d) <= 0.2 and not _swimming:
				grounded_now = true
	if _swimming:
		grounded_now = false
	_grounded = grounded_now
	var vu2 := velocity.dot(up)
	# ---- landing ------------------------------------------------------------------------------------------------------------
	if _grounded:
		if not _was_grounded:
			var impact := maxf(0.0, -prev_v_up)
			_fall_speed = maxf(_fall_speed, impact)
			_on_landed(_fall_speed)
			_fall_speed = 0.0
		_air_time = 0.0
		_ground_time += dt
	else:
		_ground_time = 0.0
		_air_time += dt
		_fall_speed = maxf(_fall_speed, -vu2)
	# ---- stride phase + footsteps -----------------------------------------------------------------------------------------------
	var hs := (velocity - up * velocity.dot(up)).length()
	if _swimming:
		_phase += dt * 3.0
	elif _grounded and hs > 0.3:
		var stride := 1.3 if _crouching else (2.6 if _sprinting else 1.95)
		_phase += hs * dt / stride * PI
		var idx := int(floor(_phase / PI))
		if idx != _last_step_idx:
			_last_step_idx = idx
			_footstep()
	else:
		_phase = lerpf(_phase, round(_phase / PI) * PI, clampf(dt * 5.0, 0.0, 1.0))

func _on_landed(impact: float) -> void:
	if impact > 3.0:
		_land_dip = maxf(_land_dip, clampf(impact * 0.022, 0.0, 0.32))
		viewmodel.kick_land(clampf(impact / 10.0, 0.0, 1.0))
		Audio.sfx("land_foot", Vector3.INF, minf(0.0, -10.0 + impact))
		_burst_dust(clampf(impact / 9.0, 0.3, 1.0))
	if impact > 22.0:
		vitals.damage((impact - 22.0) * 0.012)

func _footstep() -> void:
	var surface := _surface_under()
	if _water_depth > 0.15:
		surface = "mud"
	Audio.footstep(surface, _sprinting)
	if _sprinting and _grounded:
		_dust.global_position = global_position + global_transform.basis.y * 0.1
		_set_dust_color()
		(_dust.process_material as ParticleProcessMaterial).initial_velocity_max = 1.4
		_dust.amount = 6
		_dust.restart()
		_dust.emitting = true

func _surface_under() -> String:
	var surf: String = SURFACES.get(_planet.def.biome if _planet != null else "barren", "rock")
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().dot(global_transform.basis.y) < 0.5:
			continue
		var col := c.get_collider() as Node
		if col == null:
			continue
		if col.has_meta("surface"):
			surf = str(col.get_meta("surface"))
		elif col.is_in_group("structure") or col.is_in_group("metal") or (col.get_parent() != null and col.get_parent().is_in_group("structure")):
			surf = "metal"
		break
	_last_surface = surf
	return surf

# =====================================================================================================================
# camera
# =====================================================================================================================
func _apply_view_mode() -> void:
	rig.set_first_person(not third_person)
	rig.set_tool_visible(third_person)
	viewmodel.visible = not third_person

func _update_camera(dt: float, aim: bool, fire: bool) -> void:
	var b := global_transform.basis
	var up := b.y
	var hs := (velocity - up * velocity.dot(up)).length()
	var target_eye := lerpf(EYE_STAND, EYE_CROUCH, _crouch)
	_crouch = move_toward(_crouch, 1.0 if _crouching else 0.0, dt * 5.0)
	_eye = lerpf(_eye, target_eye, 1.0 - exp(-14.0 * dt))
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-5.0 * dt))
	var bob_on: bool = bool(Game.settings.get("head_bob", true))
	var bob_k := clampf(hs / 6.0, 0.0, 1.5) * (1.0 if _grounded else 0.0) * (1.0 if bob_on else 0.25)
	var by := absf(sin(_phase)) * 0.045 * bob_k * (0.6 if _crouching else 1.0)
	var bx := cos(_phase) * 0.02 * bob_k
	_bob_y = lerpf(_bob_y, by, 1.0 - exp(-18.0 * dt))
	_bob_x = lerpf(_bob_x, bx, 1.0 - exp(-18.0 * dt))
	var strafe := Input.get_axis("move_left", "move_right") if Game.input_enabled() else 0.0
	_roll = lerpf(_roll, -strafe * 0.018 * clampf(hs / 6.0, 0.0, 1.5), 1.0 - exp(-8.0 * dt))
	var swim_bob := sin(_t * 1.6) * 0.03 if _swimming else 0.0
	head.position = Vector3(_bob_x, _eye - _bob_y - _land_dip + swim_bob, 0.0)
	var base_fov := float(Game.settings.get("fov", 78.0))
	var fov_t := base_fov
	if _sprinting and hs > 7.0:
		fov_t += 5.0
	if _jet_on:
		fov_t += 3.5
	if aim and not third_person:
		fov_t *= 0.55
	_fov_cur = lerpf(_fov_cur, fov_t, 1.0 - exp(-9.0 * dt))
	cam.fov = _fov_cur
	if third_person:
		head.rotation = Vector3(_pitch, 0.0, 0.0)
		var from := head.global_position
		var desired_local := Vector3(0.5, 0.18, 3.3 - (1.2 if aim else 0.0))
		if debug_orbit.x < 1.0e6:
			desired_local = Vector3(sin(debug_orbit.x) * debug_orbit.z, debug_orbit.y, cos(debug_orbit.x) * debug_orbit.z)
		var desired := head.global_transform * desired_local
		var hit := _ray(from, desired, MASK_CAMERA)
		var dist_full := from.distance_to(desired)
		var want := dist_full
		if not hit.is_empty():
			want = maxf(0.4, from.distance_to(hit["position"]) - 0.25)
		if want < _tp_dist:
			_tp_dist = want
		else:
			_tp_dist = lerpf(_tp_dist, want, 1.0 - exp(-4.0 * dt))
		var dir := (desired - from).normalized()
		cam.global_position = from + dir * _tp_dist
		cam.rotation = Vector3.ZERO
		if debug_orbit.x < 1.0e6:
			cam.look_at(global_position + up * 1.0, up)
	else:
		head.rotation = Vector3(_pitch, 0.0, _roll)
		cam.position = Vector3.ZERO
		cam.rotation = Vector3.ZERO
	# viewmodel
	if not third_person:
		var retract := 0.0
		var ray := _ray(cam.global_position, cam.global_position - cam.global_transform.basis.z * 0.9, MASK_CAMERA)
		if not ray.is_empty():
			retract = clampf(1.0 - cam.global_position.distance_to(ray["position"]) / 0.9, 0.0, 1.0)
		viewmodel.update_view({"dt": dt, "speed": hs, "phase": _phase, "grounded": _grounded, "sprint": _sprinting, "fire": fire and _mining_active,
			"vspeed": velocity.dot(up), "crouch": _crouch, "look": _look_frame, "retract": retract, "jet": 1.0 if _jet_on else 0.0, "bob": bob_on})
	# underwater tint
	var under := _planet != null and _water_depth > 0.0 and (_water_depth - (_eye - 0.05 - 0.0)) > 0.0 and not third_person
	if third_person:
		under = _planet != null and (_planet.sea_radius() - cam.global_position.length()) > 0.0
	_water_layer.visible = under
	if under:
		if _liquid_kind == "lava":
			_water_overlay.color = Color(0.9, 0.25, 0.05, 0.6)
		elif _liquid_kind == "acid":
			_water_overlay.color = Color(0.3, 0.6, 0.05, 0.5)
		else:
			_water_overlay.color = Color(0.04, 0.26, 0.40, 0.45)

func _ray(from: Vector3, to: Vector3, mask: int, areas: bool = false) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = [get_rid()]
	q.collide_with_areas = areas
	q.hit_from_inside = false
	return space.intersect_ray(q)

# =====================================================================================================================
# mining beam
# =====================================================================================================================
func _muzzle_pos() -> Vector3:
	if third_person:
		return rig.muzzle_global().origin
	if viewmodel.muzzle != null:
		return viewmodel.muzzle_global().origin
	return cam.global_position + cam.global_transform.basis * Vector3(0.2, -0.15, -0.6)

func _update_mining(dt: float, fire: bool) -> void:
	var up := global_transform.basis.y
	var grav_dir := -up
	var cam_xf := cam.global_transform
	var fwd := -cam_xf.basis.z
	var extra := 0.0 if not third_person else cam.global_position.distance_to(head.global_position)
	var from_cam := cam_xf.origin
	var to_far := from_cam + fwd * (MINE_RANGE + extra)
	var muzzle := _muzzle_pos()
	_mining_active = fire and not _swimming_underwater()
	var hit := false
	var hit_pos := to_far
	var hit_normal := up
	var res_info: Dictionary = {}
	if _mining_active:
		var r := _ray(from_cam, to_far, MASK_MINING, true)
		if not r.is_empty():
			hit = true
			hit_pos = r["position"]
			hit_normal = r["normal"]
			var target := _resource_of(r["collider"] as Node)
			if target != null and target.has_method("mine"):
				var dmg := dt * MINING_POWER
				var result: Dictionary = target.call("mine", dmg)
				_mine_target = target
				_mine_progress = float(result.get("progress", 0.0))
				var rid := str(result.get("resource", ""))
				res_info = ResourceDB.info(rid)
				if bool(result.get("destroyed", false)):
					var amt := int(result.get("amount", 0))
					if amt > 0 and rid != "":
						Game.add_resource(rid, amt)
						var nm: String = str(res_info.get("name", rid.capitalize()))
						Events.notify.emit("+%d %s" % [amt, nm], "good")
						Audio.sfx("resource_collect")
					_mine_target = null
					_mine_progress = 0.0
			else:
				_mine_target = null
				_mine_progress = 0.0
		else:
			_mine_target = null
			_mine_progress = 0.0
		if not hit:
			hit_pos = from_cam + fwd * minf(MINE_RANGE, 14.0)
	else:
		_mine_target = null
		_mine_progress = 0.0
	var tint := Color(0.20, 0.85, 1.0)
	var hit_col := Color(1.0, 0.82, 0.55)
	if not res_info.is_empty():
		var rc: Color = res_info.get("color", Color.WHITE)
		tint = tint.lerp(rc, 0.45)
		hit_col = rc.lerp(Color.WHITE, 0.25)
	elif hit:
		hit_col = Color(0.85, 0.95, 1.0)
	_beam_color = _beam_color.lerp(tint, clampf(dt * 10.0, 0.0, 1.0))
	beam.set_colors(_beam_color, hit_col)
	# when aiming at something very close behind the muzzle the beam would point backwards: keep it going forward
	var m_to_hit := hit_pos - muzzle
	if m_to_hit.dot(fwd) < 0.05:
		hit_pos = muzzle + fwd * 0.5
	beam.update_beam(dt, _mining_active, muzzle, hit_pos, hit, hit_normal, up, grav_dir, 1.0 if third_person else 0.42)
	Audio.set_loop("mining_beam", _mining_active, 1.0)

func _resource_of(n: Node) -> Node:
	var cur := n
	var guard := 0
	while cur != null and guard < 6:
		if cur.is_in_group("resource_node"):
			return cur
		cur = cur.get_parent()
		guard += 1
	return null

# =====================================================================================================================
# scanner
# =====================================================================================================================
func _update_scan(dt: float, pressed: bool) -> void:
	_scan_cd = maxf(0.0, _scan_cd - dt)
	if pressed and _scan_cd <= 0.0 and _planet != null:
		_scan_cd = SCAN_COOLDOWN
		_start_scan()
	# reveal markers as the ring reaches them
	if _scan_clock >= 0.0:
		_scan_clock += dt
		var i := _pending_scan.size() - 1
		while i >= 0:
			var pe: Dictionary = _pending_scan[i]
			if _scan_clock >= float(pe["reveal"]):
				var mk: Dictionary = pe["marker"]
				scan_markers.append(mk)
				_pending_scan.remove_at(i)
				if mk["kind"] == "poi" or mk["kind"] == "resource":
					Audio.sfx("scan_ping", mk["pos"], -6.0)
			i -= 1
		if _pending_scan.is_empty() and _scan_clock > ScannerFX.DURATION:
			_scan_clock = -1.0
			var pois: int = _scan_found[0]
			var res: int = _scan_found[1]
			var cre: int = _scan_found[2]
			if pois + res + cre == 0:
				Events.notify.emit("Scan complete: nothing of interest within %d m" % int(SCAN_RANGE), "info")
			else:
				var parts: Array[String] = []
				if pois > 0: parts.append("%d point%s of interest" % [pois, "" if pois == 1 else "s"])
				if res > 0: parts.append("%d resource%s" % [res, "" if res == 1 else "s"])
				if cre > 0: parts.append("%d creature%s" % [cre, "" if cre == 1 else "s"])
				Events.notify.emit("Scan complete: " + ", ".join(parts), "discover")

func _start_scan() -> void:
	var up := global_transform.basis.y
	var origin := global_position + up * 0.9
	scanner.fire(origin)
	viewmodel.play_scan()
	Audio.sfx("scan_ping")
	Events.scan_pulse.emit(origin)
	_pending_scan.clear()
	_scan_clock = 0.0
	_scan_found = [0, 0, 0]
	var now_markers: Array = []
	# points of interest (ScatterManager knows where its POI structures really are; fall back to the planet's PoiSites list)
	var sm := _scatter_manager()
	if sm != null and sm.has_method("get_scan_targets"):
		for t in sm.call("get_scan_targets", global_position, SCAN_RANGE):
			var td: Dictionary = t
			if td.get("kind", "") != "poi":
				continue
			var tp: Vector3 = td["pos"]
			now_markers.append({"pos": tp + tp.normalized() * 6.0, "label": str(td.get("label", "Point of interest")), "kind": "poi", "dist": tp.distance_to(global_position)})
			_scan_found[0] += 1
	else:
		for poi in _planet.get_pois():
			if str(poi.get("kind", "")) == "landing_pad":
				continue
			var d: Vector3 = poi["dir"]
			var gp := d * _planet.terrain_radius_at(d)
			var dist := gp.distance_to(global_position)
			if dist <= SCAN_RANGE:
				now_markers.append({"pos": gp + d * 6.0, "label": str(poi.get("name", "Point of interest")), "kind": "poi", "dist": dist})
				_scan_found[0] += 1
	# resources: a lush planet has 60+ deposits within 600 m, so neighbours of one type are merged into one "Sodium x4" marker
	var res_raw: Array = []
	for n in get_tree().get_nodes_in_group("resource_node"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var dist2 := n3.global_position.distance_to(global_position)
		if dist2 <= SCAN_RANGE:
			res_raw.append({"pos": n3.global_position + n3.global_position.normalized() * 1.2, "label": _label_of(n3), "kind": "resource", "dist": dist2, "node": n3})
			_scan_found[1] += 1
	now_markers.append_array(_cluster_markers(res_raw, RESOURCE_CLUSTER_RADIUS, MAX_RESOURCE_MARKERS))
	# creatures: only the closest herds
	var cre_raw: Array = []
	var seen_cre: Dictionary = {}
	for grp in ["creature", "fauna"]:
		for n in get_tree().get_nodes_in_group(grp):
			var c3 := n as Node3D
			if c3 == null or not c3.is_inside_tree() or seen_cre.has(c3):
				continue
			seen_cre[c3] = true
			var dist3 := c3.global_position.distance_to(global_position)
			if dist3 <= CREATURE_SCAN_RANGE:
				cre_raw.append({"pos": c3.global_position + c3.global_position.normalized() * 1.5, "label": _label_of(c3, "Creature"), "kind": "creature", "dist": dist3, "node": c3})
				_scan_found[2] += 1
	now_markers.append_array(_cluster_markers(cre_raw, CREATURE_CLUSTER_RADIUS, MAX_CREATURE_MARKERS))
	# the ship
	if Game.ship != null and is_instance_valid(Game.ship):
		var sd := Game.ship.global_position.distance_to(global_position)
		if sd <= SCAN_RANGE and sd > 4.0:
			now_markers.append({"pos": Game.ship.global_position + up * 4.0, "label": "Wanderer", "kind": "ship", "dist": sd, "node": Game.ship})
	# replace the previous markers of the same scan area
	scan_markers.clear()
	for mk in now_markers:
		var m: Dictionary = mk
		m["time_left"] = MARKER_LIFETIME
		_pending_scan.append({"reveal": ScannerFX.delay_for(float(m["dist"])), "marker": m})

## Merge markers of the same label that lie within `radius` of each other (greedy, nearest first) into one marker that tracks all of its nodes
## ("nodes": the members, "base": label without the count); keep at most `cap` clusters (the nearest ones).
func _cluster_markers(raw: Array, radius: float, cap: int) -> Array:
	raw.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["dist"]) < float(b["dist"]))
	var out: Array = []
	for r in raw:
		var rd: Dictionary = r
		var merged := false
		for c in out:
			var cd: Dictionary = c
			if cd["base"] == rd["label"] and (cd["pos"] as Vector3).distance_to(rd["pos"] as Vector3) < radius:
				(cd["nodes"] as Array).append(rd["node"])
				merged = true
				break
		if merged:
			continue
		if out.size() >= cap:
			continue
		rd["base"] = rd["label"]
		rd["nodes"] = [rd["node"]]
		out.append(rd)
	for c in out:
		_relabel_cluster(c as Dictionary)
	return out

func _relabel_cluster(m: Dictionary) -> void:
	var n: int = (m["nodes"] as Array).size()
	m["label"] = str(m["base"]) if n <= 1 else "%s x%d" % [m["base"], n]

func _scatter_manager() -> Node:
	if _planet == null:
		return null
	for c in _planet.get_children():
		if c is ScatterManager:
			return c
	return null

func _label_of(n: Node, fallback: String = "Resource") -> String:
	if n.has_method("get_scan_label"):
		return str(n.call("get_scan_label"))
	if n.has_method("get_label"):
		return str(n.call("get_label"))
	if n.has_meta("label"):
		return str(n.get_meta("label"))
	for prop in ["resource_id", "resource", "res_id", "kind"]:
		var v: Variant = n.get(prop)
		if v is String and v != "":
			var info := ResourceDB.info(v)
			if not info.is_empty():
				return str(info["name"])
			return (v as String).capitalize()
	if n.has_meta("resource"):
		var mv := str(n.get_meta("resource"))
		var info2 := ResourceDB.info(mv)
		return str(info2.get("name", mv.capitalize()))
	return fallback

func _node_alive(n: Variant) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var nd := n as Node
	return nd != null and nd.is_inside_tree() and not nd.is_queued_for_deletion()

func _update_markers(dt: float) -> void:
	var i := scan_markers.size() - 1
	var up := global_transform.basis.y
	while i >= 0:
		var m: Dictionary = scan_markers[i]
		m["time_left"] = float(m["time_left"]) - dt
		var keep := float(m["time_left"]) > 0.0
		if m.has("node"):
			var nd: Variant = m["node"]
			var alive: bool = _node_alive(nd)
			if not alive and m.has("nodes"):
				# a merged marker (several deposits / a herd): drop the dead members and follow the next one
				var members: Array = m["nodes"]
				var k := members.size() - 1
				while k >= 0:
					if not _node_alive(members[k]):
						members.remove_at(k)
					k -= 1
				if not members.is_empty():
					m["node"] = members[0]
					nd = members[0]
					alive = true
					_relabel_cluster(m)
			if not alive:
				keep = false
			else:
				var n3 := nd as Node3D
				var off := 1.2 if m["kind"] == "resource" else (1.5 if m["kind"] == "creature" else 4.0)
				m["pos"] = n3.global_position + n3.global_position.normalized() * off
		if not keep:
			scan_markers.remove_at(i)
		i -= 1

# =====================================================================================================================
# interaction / ship
# =====================================================================================================================
func _ship_distance() -> float:
	var ship := Game.ship
	if ship == null or not is_instance_valid(ship) or not ship.is_inside_tree():
		return INF
	var lp := ship.global_transform.affine_inverse() * global_position
	var cl := lp.clamp(-SHIP_HALF, SHIP_HALF)
	return lp.distance_to(cl)

func _update_interaction(dt: float, pressed: bool) -> void:
	_interact_timer -= dt
	if _interact_timer <= 0.0:
		_interact_timer = 0.07
		_find_interactable()
	var hint := ""
	if _interact_target != null and is_instance_valid(_interact_target):
		if _interact_is_ship:
			hint = "[F] Enter ship"
		else:
			var prompt := ""
			if _interact_target.has_method("get_prompt"):
				prompt = str(_interact_target.call("get_prompt"))
			hint = "[F] " + prompt
	if hint != "":
		Game.set_context_hint(hint)
	if pressed and _interact_target != null and is_instance_valid(_interact_target) and Game.input_enabled():
		if _interact_is_ship:
			Audio.sfx("airlock")
			Game.enter_ship()
		else:
			Audio.sfx("interact")
			if _interact_target.has_method("interact"):
				_interact_target.call("interact", self)

func _find_interactable() -> void:
	_interact_target = null
	_interact_is_ship = false
	var best := 1.0e9
	var pos := global_position + global_transform.basis.y * 1.0
	var fwd := -cam.global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var to := n3.global_position - pos
		var d := to.length()
		if d > INTERACT_RANGE:
			continue
		var facing := fwd.dot(to / maxf(d, 0.01))
		if d > 1.8 and facing < 0.15:
			continue
		if n3.has_method("can_interact") and not bool(n3.call("can_interact", self)):
			continue
		var score := d - facing * 1.2
		if score < best:
			best = score
			_interact_target = n3
	# the ship
	var sd := _ship_distance()
	if sd < SHIP_ENTER_RANGE and Game.ship != null:
		var score_s := sd * 0.8
		if _interact_target == null or score_s < best:
			_interact_target = Game.ship
			_interact_is_ship = true

# =====================================================================================================================
# effects, rig, telemetry, audio
# =====================================================================================================================
func _set_dust_color() -> void:
	var biome := _planet.def.biome if _planet != null else "barren"
	var c: Color = DUST_COLORS.get(biome, Color(0.6, 0.58, 0.52))
	var day := 0.25 + 0.75 * smoothstep(-0.1, 0.3, _sun_sin)
	_dust_mat.albedo_color = Color(c.r * day, c.g * day, c.b * day, 0.85)

func _burst_dust(strength: float) -> void:
	if _planet == null:
		return
	_dust.global_position = global_position + global_transform.basis.y * 0.12
	_set_dust_color()
	_dust.amount = int(8 + 10 * strength)
	(_dust.process_material as ParticleProcessMaterial).initial_velocity_max = 1.2 + 2.0 * strength
	_dust.restart()
	_dust.emitting = true

func _update_fx(dt: float) -> void:
	# jetpack dust blast when thrusting close to the ground
	var alt := float(Game.tel.get("altitude", 99.0))
	var near_ground := _jet_on and alt < 7.0 and _planet != null
	if near_ground:
		var d := global_position.normalized()
		var gp := d * _planet.terrain_radius_at(d)
		_jet_dust.global_position = gp + d * 0.15
		_set_dust_color()
		var pm := _jet_dust.process_material as ParticleProcessMaterial
		pm.initial_velocity_max = lerpf(6.0, 2.5, clampf(alt / 7.0, 0.0, 1.0))
	if _jet_dust.emitting != near_ground:
		_jet_dust.emitting = near_ground
	# jetpack visual / audio
	_jet_visual = move_toward(_jet_visual, 1.0 if _jet_on else 0.0, dt * (6.0 if _jet_on else 4.0))
	Audio.set_loop("jetpack", _jet_on, 0.55 + 0.45 * clampf(velocity.length() / 12.0, 0.0, 1.0))

func _update_rig(dt: float, fire: bool) -> void:
	if not third_person:
		# keep the (shadow-only) body animated so the shadow looks right
		pass
	var up := global_transform.basis.y
	var hs := (velocity - up * velocity.dot(up)).length()
	rig.update_pose({"dt": dt, "speed": hs, "phase": _phase, "grounded": _grounded, "crouch": _crouch, "jet": _jet_visual,
		"swim": _swimming, "aim": 1.0 if (_mining_active or _scan_clock >= 0.0 and _scan_clock < 1.0) else 0.0, "pitch": _pitch,
		"vspeed": velocity.dot(up), "fire": _mining_active})

func _update_tel() -> void:
	var up := global_transform.basis.y
	var tel := Game.tel
	tel["speed"] = velocity.length()
	tel["state"] = "ON FOOT"
	tel["vspeed"] = velocity.dot(up)
	var alt := 0.0
	var gmag := 0.0
	if _planet != null:
		var d := global_position.normalized()
		alt = global_position.length() - _planet.terrain_radius_at(d)
		gmag = _planet.gravity_at(global_position).length()
	tel["altitude"] = maxf(alt, 0.0)       # the HUD prints "---" for negative values (a hair below the analytic surface while standing)
	tel["gravity"] = gmag
	tel["mine_progress"] = _mine_progress
	tel["scan_cooldown"] = _scan_cd / SCAN_COOLDOWN
	tel["foot_state"] = "SWIMMING" if _swimming else ("JETPACK" if _jet_on else ("SPRINTING" if _sprinting else ("CROUCHED" if _crouching else ("AIRBORNE" if not _grounded else ("WALKING" if velocity.length() > 0.5 else "IDLE")))))
	tel["flashlight"] = flashlight.visible
	vitals.write_tel(tel)

func _update_ambient(dt: float) -> void:
	_ambient_timer -= dt
	if _ambient_timer > 0.0 or _planet == null:
		return
	_ambient_timer = 0.35
	var def := _planet.def
	var wind := 0.0
	if def.has_atmosphere:
		wind = clampf(0.25 + 0.5 * _planet.atmosphere_density_at(global_position) + 0.0, 0.0, 1.0)
		wind *= 0.7 + 0.3 * sin(Universe.time * 0.11 + float(def.seed % 97))
	var night := 1.0 - smoothstep(-0.12, 0.12, _sun_sin)
	Audio.set_ambient(def.biome, wind, night, false)

func _stop_loops() -> void:
	Audio.set_loop("mining_beam", false)
	Audio.set_loop("jetpack", false)
