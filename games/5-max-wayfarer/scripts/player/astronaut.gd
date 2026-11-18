class_name Astronaut
extends CharacterBody3D
## On-foot character. Gravity points to the planet centre ("up" follows the surface), walking / sprinting / jumping /
## jetpack, third- and first-person cameras, procedural limb animation on the Blender-made model.

const WALK_SPEED: float = 6.4
const SPRINT_SPEED: float = 12.5
const EYE_HEIGHT: float = 1.62

var world: SpaceWorld
var model: Node3D
var parts: Dictionary = {}
var facing: Vector3 = Vector3(0, 0, -1)
var cam_pitch: float = 0.1
var third_person: bool = true
var jet_fuel: float = 1.0
var jetting: bool = false
var sprinting: bool = false
var air_time: float = 0.0
var on_ground: bool = true
var walk_phase: float = 0.0
var speed_h: float = 0.0
var active: bool = false
var cam_dist: float = 4.6
var in_water: bool = false
var fall_speed: float = 0.0
var jet_vis: Array[Node3D] = []
var _jet_mat: ShaderMaterial
var _t: float = 0.0
var _cam_pos_smooth: Vector3 = Vector3.ZERO
var _land_shake: float = 0.0
var step_timer: float = 0.0
signal footstep(strong: bool)
signal landed_hard(speed: float)

func setup(w: SpaceWorld) -> void:
	world = w
	name = "Astronaut"
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.7
	floor_stop_on_slope = true
	floor_block_on_wall = false
	max_slides = 6
	safe_margin = 0.01
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.78
	cs.shape = cap
	cs.position = Vector3(0, 0.89, 0)
	add_child(cs)
	model = Models.instantiate("astronaut")
	add_child(model)
	_set_layers(model, 1)
	for nm in ["Pelvis", "Torso", "Head", "Visor", "Arm_L_Upper", "Arm_L_Lower", "Arm_R_Upper", "Arm_R_Lower", "Leg_L_Upper", "Leg_L_Lower", "Leg_R_Upper", "Leg_R_Lower",
			"Foot_L", "Foot_R", "Backpack", "Marker_JetL", "Marker_JetR", "Marker_Eye", "Chest_Light", "Hand_L", "Hand_R", "Marker_Tool"]:
		var n: Node = model.find_child(nm, true, false)
		if n != null:
			parts[nm] = n
	_build_jets()
	set_active(false)

func _set_layers(n: Node, bits: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = bits
	for c in n.get_children():
		_set_layers(c, bits)

func _build_jets() -> void:
	_jet_mat = ShaderMaterial.new()
	_jet_mat.shader = load("res://shaders/flame.gdshader")
	_jet_mat.set_shader_parameter("color_core", Color(0.9, 0.95, 1.0))
	_jet_mat.set_shader_parameter("color_edge", Color(1.0, 0.55, 0.15))
	_jet_mat.set_shader_parameter("power", 0.9)
	var anchors: Array = []
	if parts.has("Marker_JetL") and parts.has("Marker_JetR"):
		anchors = [parts["Marker_JetL"], parts["Marker_JetR"]]
	else:
		var a := Node3D.new()
		a.position = Vector3(-0.18, 0.9, 0.3)
		add_child(a)
		var b := Node3D.new()
		b.position = Vector3(0.18, 0.9, 0.3)
		add_child(b)
		anchors = [a, b]
	for an in anchors:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 1.0
		cone.radial_segments = 8
		cone.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = _jet_mat
		mi.rotation = Vector3(deg_to_rad(-90.0), 0, 0)    # the jet points DOWN (-Y)
		mi.position = Vector3(0, -0.5, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 1
		var pivot := Node3D.new()
		pivot.visible = false
		pivot.add_child(mi)
		(an as Node3D).add_child(pivot)
		jet_vis.append(pivot)

func set_active(on: bool) -> void:
	active = on
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	collision_layer = 8 if on else 0
	collision_mask = (1 | 2 | 4) if on else 0

func spawn_at(local_pos: Vector3, face_dir: Vector3) -> void:
	var up: Vector3 = local_pos.normalized()
	var f: Vector3 = face_dir - up * face_dir.dot(up)
	if f.length_squared() < 0.001:
		f = U.any_perp(up)
	facing = f.normalized()
	global_transform = Transform3D(U.basis_from_up(up, facing), local_pos)
	velocity = Vector3.ZERO
	cam_pitch = 0.15
	_cam_pos_smooth = Vector3.ZERO
	jet_fuel = 1.0
	set_active(true)
	up_direction = up
	world.viewer_pos = local_pos

func step(delta: float, controls_on: bool) -> void:
	_t += delta
	var planet: Planet = world.planets[world.frame_idx]
	var pos: Vector3 = global_position
	var up: Vector3 = pos.normalized()
	up_direction = up
	var g: float = planet.gravity_at(pos.length())
	# --- look
	var md: Vector2 = Game.consume_mouse() if controls_on else Vector2.ZERO
	var sens: float = 0.0023 * Game.mouse_sens
	if md != Vector2.ZERO:
		facing = facing.rotated(up, -md.x * sens).normalized()
		cam_pitch = clampf(cam_pitch + md.y * sens * (1.0 if Game.invert_y else -1.0) * -1.0 * -1.0, -1.35, 1.35)
	# keep facing in the tangent plane
	facing = (facing - up * facing.dot(up)).normalized()
	var right: Vector3 = facing.cross(up).normalized()
	# --- input
	var mv := Vector2.ZERO
	if controls_on:
		mv = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_fwd"))
		if Input.is_action_just_pressed("camera_toggle"):
			third_person = not third_person
	sprinting = controls_on and Input.is_action_pressed("sprint") and mv.y > 0.0
	var speed: float = SPRINT_SPEED if sprinting else WALK_SPEED
	if in_water:
		speed *= 0.55
	var wish: Vector3 = (right * mv.x + facing * mv.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish *= speed
	var v: Vector3 = velocity
	var v_up: float = v.dot(up)
	var v_h: Vector3 = v - up * v_up
	var grounded: bool = is_on_floor()
	var accel: float = (48.0 if grounded else 11.0)
	if jetting:
		accel = 22.0
	v_h = v_h.move_toward(wish, accel * delta)
	# water: radius below the sea level of the planet
	in_water = false
	if planet.gen != null and planet.gen.has_sea:
		var sea_r: float = planet.data.radius + planet.gen.sea_h
		in_water = pos.length() < sea_r - 0.2
	# --- vertical
	jetting = false
	if in_water:
		v_up += -g * 0.25 * delta
		v_up = lerpf(v_up, 0.0, 1.0 - exp(-2.0 * delta))
		if controls_on and Input.is_action_pressed("jump"):
			v_up = lerpf(v_up, 4.5, 1.0 - exp(-4.0 * delta))
	else:
		if not grounded:
			v_up -= g * delta
			air_time += delta
		else:
			if air_time > 0.0 and fall_speed > 14.0:
				landed_hard.emit(fall_speed)
				_land_shake = clampf(fall_speed / 30.0, 0.2, 1.0)
			air_time = 0.0
			if v_up < 0.0:
				v_up = 0.0
		if controls_on and grounded and Input.is_action_just_pressed("jump"):
			v_up = sqrt(2.0 * g * 1.35)
			air_time = 0.001
		elif controls_on and not grounded and Input.is_action_pressed("jump") and air_time > 0.22 and jet_fuel > 0.0:
			jetting = true
			v_up = minf(v_up + (g * 1.75 + 2.0) * delta, 10.5 + g * 0.2)
			jet_fuel = maxf(0.0, jet_fuel - 0.30 * delta)
		if grounded and not jetting:
			jet_fuel = minf(1.0, jet_fuel + 0.55 * delta)
		elif not jetting:
			jet_fuel = minf(1.0, jet_fuel + 0.10 * delta)
	fall_speed = maxf(0.0, -v_up)
	velocity = v_h + up * v_up
	global_transform = Transform3D(U.basis_from_up(up, facing), pos)
	move_and_slide()
	speed_h = (velocity - up * velocity.dot(up)).length()
	on_ground = grounded
	# ground-hugging safety: never fall through the analytic surface (collider might not be built yet)
	var p2: Vector3 = global_position
	var gr: float = planet.data.radius + planet.ground_height(p2.normalized()) + planet.pad_bonus(p2)
	if p2.length() < gr - 0.05:
		global_position = p2.normalized() * (gr + 0.02)
		velocity -= up * velocity.dot(up) * 0.9
	world.viewer_pos = global_position
	_animate(delta)

func _animate(delta: float) -> void:
	var moving: float = clampf(speed_h / 6.0, 0.0, 1.6)
	var airborne: bool = not on_ground and not in_water
	var rate: float = (speed_h * 0.55 + 1.0) * 2.0 if on_ground else 0.0
	if on_ground and speed_h > 0.3:
		var prev: float = walk_phase
		walk_phase += delta * (5.0 + speed_h * 0.62)
		if floorf(prev / PI) != floorf(walk_phase / PI):
			footstep.emit(sprinting)
	else:
		walk_phase += delta * 1.5
	var sw: float = sin(walk_phase) * 0.7 * clampf(speed_h / 6.4, 0.0, 1.5)
	var sw2: float = sin(walk_phase + PI) * 0.7 * clampf(speed_h / 6.4, 0.0, 1.5)
	var idle: float = sin(_t * 1.6) * 0.02
	var lean: float = clampf(speed_h / 12.0, 0.0, 1.0) * (0.22 if sprinting else 0.1)
	var k: float = 1.0 - exp(-14.0 * delta)
	var set_rot := func(nm: String, e: Vector3) -> void:
		if parts.has(nm):
			var n: Node3D = parts[nm]
			var b: Basis = Basis.from_euler(e)
			n.transform.basis = n.transform.basis.slerp(b, k)
	if airborne:
		var fall_pose: float = 0.4 if jetting else 0.65
		set_rot.call("Leg_L_Upper", Vector3(0.35, 0, 0.1))
		set_rot.call("Leg_R_Upper", Vector3(-0.15, 0, -0.1))
		set_rot.call("Leg_L_Lower", Vector3(0.6, 0, 0))
		set_rot.call("Leg_R_Lower", Vector3(0.35, 0, 0))
		set_rot.call("Arm_L_Upper", Vector3(-0.2, 0, 0.9 * fall_pose))
		set_rot.call("Arm_R_Upper", Vector3(-0.2, 0, -0.9 * fall_pose))
		set_rot.call("Arm_L_Lower", Vector3(-0.4, 0, 0))
		set_rot.call("Arm_R_Lower", Vector3(-0.4, 0, 0))
	else:
		set_rot.call("Leg_L_Upper", Vector3(sw, 0, 0))
		set_rot.call("Leg_R_Upper", Vector3(sw2, 0, 0))
		set_rot.call("Leg_L_Lower", Vector3(maxf(0.0, -sin(walk_phase + 1.2)) * 0.9 * moving, 0, 0))
		set_rot.call("Leg_R_Lower", Vector3(maxf(0.0, -sin(walk_phase + PI + 1.2)) * 0.9 * moving, 0, 0))
		set_rot.call("Arm_L_Upper", Vector3(sw2 * 0.8 + idle, 0, 0.08))
		set_rot.call("Arm_R_Upper", Vector3(sw * 0.8 - idle, 0, -0.08))
		set_rot.call("Arm_L_Lower", Vector3(-0.25 - 0.35 * moving, 0, 0))
		set_rot.call("Arm_R_Lower", Vector3(-0.25 - 0.35 * moving, 0, 0))
	if parts.has("Torso"):
		var tn: Node3D = parts["Torso"]
		tn.transform.basis = tn.transform.basis.slerp(Basis.from_euler(Vector3(-lean, sin(walk_phase) * 0.06 * moving, 0)), k)
	if parts.has("Pelvis"):
		var pn: Node3D = parts["Pelvis"]
		var bob: float = absf(sin(walk_phase)) * 0.045 * clampf(speed_h / 6.0, 0.0, 1.5)
		if not parts.has("_pelvis_y"):
			parts["_pelvis_y"] = pn.position.y
		pn.position.y = float(parts["_pelvis_y"]) + bob
	for j in jet_vis:
		j.visible = jetting
		if jetting:
			j.scale = Vector3(1, 1, 1) * (1.6 + 0.4 * sin(_t * 40.0))
	model.visible = third_person

# ------------------------------------------------------------------------------------------- camera
func eye_pos() -> Vector3:
	var up: Vector3 = global_position.normalized()
	return global_position + up * EYE_HEIGHT

func camera_transform(delta: float) -> Transform3D:
	var up: Vector3 = global_position.normalized()
	var right: Vector3 = facing.cross(up).normalized()
	# view direction from facing + pitch
	var view_dir: Vector3 = (facing * cos(cam_pitch) + up * sin(cam_pitch)).normalized()
	if not third_person:
		var eye: Vector3 = eye_pos()
		var xf := Transform3D(Basis.looking_at(view_dir, up), eye)
		_cam_pos_smooth = eye
		return _shake(xf)
	var pivot: Vector3 = global_position + up * 1.55 + right * 0.45
	var dist: float = cam_dist + (0.7 if sprinting else 0.0)
	var back_dir: Vector3 = -view_dir
	var want: Vector3 = pivot + back_dir * dist + up * 0.25
	# collide the camera boom against terrain and props
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pivot, want, 1 | 2 | 4)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		want = (hit["position"] as Vector3) + (pivot - want).normalized() * 0.25
	# never below the analytic terrain
	var pl: Planet = world.planets[world.frame_idx]
	var dd: Vector3 = want.normalized()
	var gr: float = pl.data.radius + pl.ground_height(dd) + 0.45
	if want.length() < gr:
		want = dd * gr
	if _cam_pos_smooth == Vector3.ZERO:
		_cam_pos_smooth = want
	_cam_pos_smooth = _cam_pos_smooth.lerp(want, 1.0 - exp(-22.0 * delta))
	var look_at: Vector3 = pivot + view_dir * 6.0
	var xf2 := Transform3D(Basis.looking_at((look_at - _cam_pos_smooth).normalized(), up), _cam_pos_smooth)
	return _shake(xf2)

func _shake(xf: Transform3D) -> Transform3D:
	var s: float = _land_shake
	_land_shake = maxf(0.0, _land_shake - 0.035)
	if sprinting and on_ground:
		s += 0.06
	if s > 0.002:
		xf.basis = xf.basis * Basis.from_euler(Vector3(sin(_t * 53.0) * s * 0.02, sin(_t * 41.0) * s * 0.02, 0))
	return xf
