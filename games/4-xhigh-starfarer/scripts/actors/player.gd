class_name Player
extends Node3D
## The astronaut. Simulated in the local (rotating) frame of a planet: radial gravity, analytic terrain
## collision (PlanetData.height_at), walk / sprint / jump / jetpack / swim. Procedural limb animation.

signal died

const EYE_H := 1.62
const WALK := 5.2
const SPRINT := 10.5

var frame: Body
var lpos := Vector3.ZERO
var lvel := Vector3.ZERO
var fwd_dir := Vector3.FORWARD
var pitch := 0.0
var grounded := false
var air_time := 0.0
var fuel := 100.0
var health := 100.0
var protection := 100.0
var sprinting := false
var swimming := false
var liquid_depth := 0.0
var in_hazard_liquid := false
var props: Node = null            # PropField for collisions
var model: Node3D
var parts := {}
var jet_flames: Array = []
var tool_node: Node3D
var walk_phase := 0.0
var speed_h := 0.0
var lean := 0.0
var jet_on := false
var mining := false
var equip_t := 0.0
var step_timer := 0.0
var ground_normal := Vector3.UP
var alt := 0.0
var fuel_cd := 0.0
var landing_cd := 0.0
var dead_cd := 0.0
var shake := 0.0
var lamp: SpotLight3D


func _ready() -> void:
	var scene: PackedScene = load("res://assets/models/astronaut.glb")
	model = scene.instantiate()
	ModelLib._tone_emission(model)
	add_child(model)
	for nm in ["hips", "torso", "head", "armL1", "armL2", "armR1", "armR2", "legL1", "legL2", "legR1", "legR2", "JetFlame_L", "JetFlame_R", "HandR"]:
		parts[nm] = model.find_child("Astro_" + nm, true, false)
	for nm in ["JetFlame_L", "JetFlame_R"]:
		var f := parts[nm] as MeshInstance3D
		if f:
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/flame.gdshader")
			m.set_shader_parameter("flame_len", 0.55)
			m.set_shader_parameter("intensity", 1.4)
			f.material_override = m
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			jet_flames.append(f)
	var ts: PackedScene = load("res://assets/models/multitool.glb")
	tool_node = ts.instantiate()
	var hand: Node3D = parts.get("HandR")
	if hand:
		hand.add_child(tool_node)
		tool_node.position = Vector3(0, -0.02, -0.02)
		tool_node.rotation = Vector3(0, 0, 0)
		tool_node.scale = Vector3(1.3, 1.3, 1.3)
	tool_node.visible = false
	lamp = SpotLight3D.new()
	lamp.position = Vector3(0, 1.62, -0.25)
	lamp.spot_range = 70.0
	lamp.spot_angle = 34.0
	lamp.spot_attenuation = 0.8
	lamp.light_energy = 5.0
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.shadow_enabled = false
	lamp.visible = false
	add_child(lamp)


func world_basis() -> Basis:
	var up := lpos.normalized()
	return frame.rot * Basis.looking_at(fwd_dir, up)


func abs_pos() -> DV:
	return frame.local_to_abs(lpos)


func world_velocity() -> Vector3:
	return frame.local_point_velocity(lpos) + frame.rot * lvel


func place_at(b: Body, dir: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	frame = b
	var r: float = b.radius + b.data.height_at(dir)
	lpos = dir * r
	lvel = Vector3.ZERO
	grounded = true
	var f := face if face != Vector3.ZERO else Vector3.RIGHT.cross(dir)
	fwd_dir = (f - dir * f.dot(dir)).normalized()
	if fwd_dir.length() < 0.1:
		fwd_dir = Vector3.FORWARD.cross(dir).normalized()


func place_from_world(b: Body, p: DV, face_world: Vector3) -> void:
	frame = b
	lpos = b.abs_to_local(p)
	lvel = Vector3.ZERO
	var up := lpos.normalized()
	var fl := b.rot.transposed() * face_world
	fwd_dir = (fl - up * fl.dot(up)).normalized()
	if fwd_dir.length() < 0.1:
		fwd_dir = Vector3.RIGHT.cross(up).normalized()
	snap_to_ground()


func snap_to_ground() -> void:
	var dir := lpos.normalized()
	lpos = dir * (frame.radius + frame.data.height_at(dir))
	grounded = true


func head_pos_local() -> Vector3:
	return lpos + lpos.normalized() * EYE_H


func sim(dt: float, inp: Dictionary) -> void:
	var data: PlanetData = frame.data
	var up := lpos.normalized()
	var mouse: Vector2 = inp.get("mouse", Vector2.ZERO)
	var move: Vector2 = inp.get("move", Vector2.ZERO)
	var want_sprint: bool = inp.get("sprint", false)
	var jump_held: bool = inp.get("jump", false)
	var jump_pressed: bool = inp.get("jump_pressed", false)
	var sens := 0.0022 * Game.mouse_sens
	if Game.invert_y:
		mouse.y = -mouse.y
	fwd_dir = fwd_dir.rotated(up, -mouse.x * sens)
	pitch = clampf(pitch - mouse.y * sens, -1.45, 1.45)
	fwd_dir = (fwd_dir - up * fwd_dir.dot(up)).normalized()
	var right := fwd_dir.cross(up)
	# ---- ground info at current position
	var h_now := data.height_at(up)
	var ground_r := frame.radius + h_now
	var liq_r := -1e9
	liquid_depth = 0.0
	if data.has_liquid():
		liq_r = frame.radius + data.sea_level
		liquid_depth = maxf(liq_r - ground_r, 0.0)
	swimming = liquid_depth > 1.35
	in_hazard_liquid = liquid_depth > 0.2 and data.liquid != PlanetData.Liquid.WATER
	var floor_r := ground_r
	if swimming:
		floor_r = liq_r - 1.05
	alt = lpos.length() - floor_r
	# ---- horizontal control
	var spd := WALK
	sprinting = want_sprint and move.length() > 0.1 and not swimming
	if sprinting:
		spd = SPRINT
	if swimming:
		spd = 3.4
	elif liquid_depth > 0.25:
		spd *= 0.65
	var wish := (fwd_dir * move.y + right * move.x)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish *= spd
	var vv := lvel.dot(up)
	var vh := lvel - up * vv
	var grounded_now := grounded or alt < 0.08
	var jet_spd := 13.0
	var accel := 38.0 if grounded_now else 9.0
	var target := wish
	if not grounded_now and jet_on:
		target = wish * (jet_spd / maxf(spd, 0.01)) * 0.95
		accel = 14.0
	vh = vh.move_toward(target, accel * dt)
	# ---- vertical
	var g := data.gravity
	jet_on = false
	if grounded_now:
		air_time = 0.0
		if jump_pressed and not swimming:
			vv = 6.4
			grounded = false
			grounded_now = false
		elif swimming and jump_held:
			vv = 3.5
	else:
		air_time += dt
	if not grounded_now:
		vv -= g * dt
		if jump_held and air_time > 0.18 and fuel > 0.5:
			vv += (g + 11.0) * dt
			vv = minf(vv, 9.5)
			fuel = maxf(fuel - 26.0 * dt, 0.0)
			jet_on = true
			fuel_cd = 0.8
	fuel_cd = maxf(fuel_cd - dt, 0.0)
	if grounded_now and fuel_cd <= 0.0:
		fuel = minf(fuel + 38.0 * dt, 100.0)
	# ---- integrate with slope limit
	lvel = vh + up * vv
	var np := lpos + lvel * dt
	var ndir := np.normalized()
	var n_h := data.height_at(ndir)
	var n_ground := frame.radius + n_h
	var n_floor := n_ground
	if data.has_liquid():
		var nl := frame.radius + data.sea_level
		if nl - n_ground > 1.35:
			n_floor = nl - 1.05
	var hd := vh.length() * dt
	if grounded_now and (n_floor - floor_r) > hd * 1.2 + 0.1 and not swimming:
		# too steep: block horizontal motion
		np = lpos + up * (vv * dt)
		ndir = np.normalized()
		n_floor = frame.radius + data.height_at(ndir)
		lvel = up * vv
		vh = Vector3.ZERO
	# props
	if props != null and props.has_method("resolve"):
		var fixed: Vector3 = props.resolve(np, ndir, vv > 0.0 or not grounded_now)
		if fixed != np:
			np = fixed
			ndir = np.normalized()
			lvel -= vh * 0.5
	var nd := np.length()
	if nd <= n_floor + 0.02 or (grounded_now and vv <= 0.0 and nd - n_floor < 0.6):
		if not grounded and vv < -6.0 and landing_cd <= 0.0:
			Sfx.play("thud", -10.0 + clampf(-vv, 0, 20) * 0.3, 1.2)
			landing_cd = 0.3
			shake = clampf(-vv * 0.02, 0.0, 0.4)
		np = ndir * n_floor
		grounded = true
		var dvv := lvel.dot(ndir)
		if dvv < 0.0:
			lvel -= ndir * dvv
	else:
		grounded = false
	landing_cd = maxf(landing_cd - dt, 0.0)
	lpos = np
	ground_normal = data.normal_at(ndir, 1.5) if grounded else ndir
	speed_h = (lvel - ndir * lvel.dot(ndir)).length()
	# ---- hazards
	_hazards(dt, data)
	# ---- footsteps
	if grounded and speed_h > 1.5 and not swimming:
		step_timer -= dt * (speed_h / WALK)
		if step_timer <= 0.0:
			step_timer = 0.42
			var snowy := data.biome == PlanetData.Biome.FROZEN
			Sfx.play("step_snow" if snowy else "step", -12.0 + (3.0 if sprinting else 0.0), randf_range(0.85, 1.15))
	_animate(dt)
	lamp.rotation = Vector3(pitch, 0, 0)
	shake = maxf(shake - dt * 2.0, 0.0)
	Sfx.set_loop("jet", -14.0 if jet_on else -80.0, 1.0)


func _hazards(dt: float, data: PlanetData) -> void:
	var drain := 0.0
	if data.hazard != "":
		drain += data.hazard_level * 1.5
	if data.atmo_height <= 0.0:
		drain += 0.45
	if in_hazard_liquid:
		var dmg := 35.0 if data.liquid == PlanetData.Liquid.LAVA else 12.0
		health -= dmg * dt
		drain += 4.0
		shake = maxf(shake, 0.15)
	protection = clampf(protection - drain * dt, 0.0, 100.0)
	if protection <= 0.0 and drain > 0.0:
		health -= (2.0 + data.hazard_level * 4.0) * dt
	elif health < 100.0 and protection > 15.0 and not in_hazard_liquid:
		health = minf(health + 2.5 * dt, 100.0)
	if health <= 0.0:
		health = 0.0
		died.emit()


func refill() -> void:
	protection = 100.0
	health = maxf(health, 60.0)
	fuel = 100.0


# ------------------------------------------------------------------ animation
func _animate(dt: float) -> void:
	if parts.is_empty() or parts.get("legL1") == null:
		return
	var moving := speed_h > 0.4 and grounded
	var run := clampf(speed_h / SPRINT, 0.0, 1.0)
	walk_phase += dt * (3.2 + speed_h * 1.25) * (1.0 if moving else 0.0)
	var amp := clampf(speed_h / 6.0, 0.0, 1.0) * (0.75 if sprinting else 0.55)
	var sw := sin(walk_phase)
	var t := Time.get_ticks_msec() * 0.001
	var legL1: Node3D = parts.legL1
	var legR1: Node3D = parts.legR1
	var legL2: Node3D = parts.legL2
	var legR2: Node3D = parts.legR2
	var armL1: Node3D = parts.armL1
	var armR1: Node3D = parts.armR1
	var armL2: Node3D = parts.armL2
	var armR2: Node3D = parts.armR2
	var torso: Node3D = parts.torso
	var head: Node3D = parts.head
	var hips: Node3D = parts.hips
	if grounded or swimming:
		legL1.rotation.x = lerpf(legL1.rotation.x, sw * amp, 0.4)
		legR1.rotation.x = lerpf(legR1.rotation.x, -sw * amp, 0.4)
		legL2.rotation.x = lerpf(legL2.rotation.x, -maxf(0.0, -sw) * amp * 1.3 - 0.04, 0.4)
		legR2.rotation.x = lerpf(legR2.rotation.x, -maxf(0.0, sw) * amp * 1.3 - 0.04, 0.4)
		armL1.rotation.x = lerpf(armL1.rotation.x, -sw * amp * 0.9, 0.4)
		armL2.rotation.x = lerpf(armL2.rotation.x, 0.1 + run * 0.9 * absf(sw), 0.4)
		if not mining:
			armR1.rotation.x = lerpf(armR1.rotation.x, sw * amp * 0.9, 0.4)
			armR2.rotation.x = lerpf(armR2.rotation.x, 0.1 + run * 0.9 * absf(sw), 0.4)
		hips.position.y = 0.98 + (absf(sw) * 0.03 * amp if moving else sin(t * 1.6) * 0.004)
	else:
		# airborne / jetpack pose
		legL1.rotation.x = lerpf(legL1.rotation.x, 0.25, 0.2)
		legR1.rotation.x = lerpf(legR1.rotation.x, -0.15, 0.2)
		legL2.rotation.x = lerpf(legL2.rotation.x, -0.5, 0.2)
		legR2.rotation.x = lerpf(legR2.rotation.x, -0.25, 0.2)
		armL1.rotation.x = lerpf(armL1.rotation.x, -0.5, 0.2)
		armL2.rotation.x = lerpf(armL2.rotation.x, 0.3, 0.2)
		if not mining:
			armR1.rotation.x = lerpf(armR1.rotation.x, -0.5, 0.2)
			armR2.rotation.x = lerpf(armR2.rotation.x, 0.3, 0.2)
	if mining:
		equip_t = minf(equip_t + dt * 5.0, 1.0)
		armR1.rotation.x = lerpf(armR1.rotation.x, 1.35, 0.3)
		armR2.rotation.x = lerpf(armR2.rotation.x, 0.15, 0.3)
	else:
		equip_t = maxf(equip_t - dt * 5.0, 0.0)
	tool_node.visible = equip_t > 0.3
	lean = lerpf(lean, run * 0.22 if grounded else 0.1, 0.1)
	torso.rotation.x = -lean + sin(t * 1.6) * 0.01
	head.rotation.x = clampf(-pitch * 0.5, -0.5, 0.5) + lean * 0.8
	for f: MeshInstance3D in jet_flames:
		f.visible = jet_on
		f.scale = Vector3(1, 0.8 + randf() * 0.5, 1)
