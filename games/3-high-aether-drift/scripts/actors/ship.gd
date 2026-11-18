class_name Ship
extends Node3D
## The player's spaceship: arcade flight model (thrust, boost, pulse drive), atmospheric entry, landing / takeoff,
## black-hole gravity, hull / shield.

signal landed(planet: PlanetBody)
signal took_off()
signal crashed(damage: float)
signal destroyed()
signal horizon_crossed()
signal message(text: String, level: int)

enum State { FLYING, LANDED }

const CRUISE := 260.0
const BOOST := 950.0
const PULSE := 14000.0
const CRUISE_ACC := 95.0
const BOOST_ACC := 230.0
const PULSE_ACC := 3500.0
const GEAR_H := 2.35
const MAX_HULL := 100.0

var state: int = State.LANDED
var velocity: Vector3 = Vector3.ZERO
var vg: Vector3 = Vector3.ZERO  # velocity gained from black-hole gravity (engines do not cancel it)
var throttle: float = 0.0
var boosting: bool = false
var pulse: bool = false
var hull: float = MAX_HULL
var shield: float = 100.0
var heat: float = 0.0
var gear: float = 1.0  # 1 = extended
var planet: PlanetBody = null  # planet we are parked on / flying close to
var altitude: float = 99999.0
var vspeed: float = 0.0
var speed: float = 0.0
var air_density: float = 0.0
var pool_look: Vector2 = Vector2.ZERO
var roll_vel: float = 0.0
var bank: float = 0.0
var lift_assist: float = 0.0
var landing_ok: bool = false
var pull_g: float = 0.0
var bh_dist: float = -1.0
var in_pnr: bool = false
var warp_lock: bool = false
var invulnerable: bool = false
var cockpit_view: bool = false
var shake: float = 0.0
var look_sens: float = 1.0

var model: Node3D
var cockpit: Node3D
var cam_mount: Node3D
var camera_chase: Vector3 = Vector3(0.0, 3.6, 16.5)
var camera_cockpit: Vector3 = Vector3(0.0, 1.12, -1.7)
var gear_nodes: Array = []
var flames: Array = []
var heat_mesh: MeshInstance3D
var _uni: Universe
var _flame_t: float = 0.0
var _crash_cd: float = 0.0
var _msg_cd: float = 0.0
var _liquid_warned: float = 0.0
var liftoff_t: float = 0.0


func _ready() -> void:
	model = Assets.instance("ship")
	model.name = "Model"
	add_child(model)
	for n in ["Gear_Front", "Gear_L", "Gear_R"]:
		var g := model.find_child(n, true, false)
		if g:
			gear_nodes.append(g)
	_make_flames()
	cam_mount = Node3D.new()
	cam_mount.name = "CamMount"
	add_child(cam_mount)
	cockpit = Assets.instance("cockpit")
	cockpit.position = camera_cockpit
	cockpit.visible = false
	add_child(cockpit)
	# heat shell for atmospheric entry
	heat_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	heat_mesh.mesh = sm
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(1.0, 0.45, 0.12, 0.0)
	hm.cull_mode = BaseMaterial3D.CULL_FRONT
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.4, 0.1)
	hm.emission_energy_multiplier = 3.0
	hm.no_depth_test = false
	heat_mesh.material_override = hm
	heat_mesh.scale = Vector3(5.5, 3.2, 9.0)
	heat_mesh.position = Vector3(0, 0.2, -2.0)
	heat_mesh.visible = false
	heat_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(heat_mesh)


func _make_flames() -> void:
	for n in ["Engine_L", "Engine_R"]:
		var e := model.find_child(n, true, false)
		if e == null:
			continue
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.42
		cm.height = 1.0
		cm.radial_segments = 14
		cm.rings = 1
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.4, 0.8, 1.0, 0.9)
		m.emission_enabled = true
		m.emission = Color(0.35, 0.75, 1.0)
		m.emission_energy_multiplier = 3.5
		var f := MeshInstance3D.new()
		f.mesh = cm
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var holder := Node3D.new()
		e.add_child(holder)
		holder.add_child(f)
		f.rotation_degrees = Vector3(90, 0, 0)
		holder.set_meta("mesh", f)
		flames.append(holder)
		var light := OmniLight3D.new()
		light.light_color = Color(0.4, 0.8, 1.0)
		light.omni_range = 18.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		holder.add_child(light)
		holder.set_meta("light", light)


func set_cockpit(on: bool) -> void:
	cockpit_view = on
	cockpit.visible = on
	model.visible = not on


func total_velocity() -> Vector3:
	return velocity + vg


func is_flying() -> bool:
	return state == State.FLYING


func status_text() -> String:
	return "HULL %d  SHIELD %d" % [int(hull), int(shield)]


# ------------------------------------------------------------------ lifecycle helpers
func place_on_pad(pl: PlanetBody) -> void:
	planet = pl
	if get_parent():
		get_parent().remove_child(self)
	pl.add_child(self)
	var xf: Transform3D = pl.props.pad_transform_local()
	transform = Transform3D(xf.basis, xf.origin + xf.basis.y * GEAR_H)
	rotate_object_local(Vector3.UP, 0.0)
	state = State.LANDED
	velocity = Vector3.ZERO
	throttle = 0.0
	gear = 1.0
	_apply_gear()


func take_off(uni: Universe) -> void:
	if state != State.LANDED:
		return
	var pl := planet
	var xf := global_transform
	if pl and get_parent() == pl:
		pl.remove_child(self)
		uni.add_child(self)
	global_transform = xf
	state = State.FLYING
	vg = Vector3.ZERO
	var up := global_basis.y
	velocity = up * 6.0
	lift_assist = 4.0
	throttle = 0.0
	liftoff_t = 2.6
	took_off.emit()


func _land_on(pl: PlanetBody, normal_world: Vector3, ground_point: Vector3) -> void:
	state = State.LANDED
	velocity = Vector3.ZERO
	vg = Vector3.ZERO
	throttle = 0.0
	pulse = false
	boosting = false
	planet = pl
	var xf := global_transform
	# align to surface, keep heading
	var up := normal_world
	var fwd := (-xf.basis.z - up * (-xf.basis.z).dot(up)).normalized()
	var right := fwd.cross(up).normalized()
	var b := Basis(right, up, -fwd)
	xf = Transform3D(b, ground_point + up * GEAR_H)
	if get_parent() != pl:
		get_parent().remove_child(self)
		pl.add_child(self)
	global_transform = xf
	landed.emit(pl)


# ------------------------------------------------------------------ main update
func update_ship(dt: float, inp: Dictionary, uni: Universe) -> void:
	_uni = uni
	_crash_cd = maxf(_crash_cd - dt, 0.0)
	_msg_cd = maxf(_msg_cd - dt, 0.0)
	shield = minf(shield + 6.0 * dt, 100.0)
	shake = maxf(shake - dt * 2.0, 0.0)
	if state == State.LANDED:
		_update_landed(dt, inp, uni)
	else:
		_update_flight(dt, inp, uni)
	_update_fx(dt, uni)


func _update_landed(dt: float, inp: Dictionary, uni: Universe) -> void:
	speed = 0.0
	altitude = GEAR_H
	vspeed = 0.0
	gear = 1.0
	_apply_gear()
	hull = minf(hull + 10.0 * dt, MAX_HULL)
	if inp.get("takeoff", false) and not warp_lock:
		take_off(uni)


func _update_flight(dt: float, inp: Dictionary, uni: Universe) -> void:
	# --- rotation (mouse look pooled & eased, roll keys)
	var look: Vector2 = inp.get("look", Vector2.ZERO)
	pool_look += look
	var k := 1.0 - exp(-22.0 * dt)
	var step := pool_look * k
	pool_look -= step
	var sens := 0.0021 * look_sens
	var spd_factor := 1.0 / (1.0 + clampf(speed / 6000.0, 0.0, 1.5))
	var yaw := -step.x * sens * spd_factor
	var pitch := -step.y * sens * spd_factor
	var rollk: float = inp.get("roll", 0.0)
	roll_vel = lerpf(roll_vel, rollk * 1.5, 1.0 - exp(-6.0 * dt))
	var b := global_basis
	b = b * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll_vel * dt)
	global_basis = b.orthonormalized()
	bank = lerpf(bank, clampf(-step.x * 0.02 / maxf(dt, 0.001) * 0.002, -0.7, 0.7) + roll_vel * 0.25, 1.0 - exp(-5.0 * dt))
	model.rotation.z = bank * 0.6

	# --- environment around the ship
	var pos := global_position
	var near: PlanetBody = uni.nearest_body(pos)
	planet = near
	altitude = 1e9
	air_density = 0.0
	var ground_h_dir := Vector3.UP
	var gnormal_local := Vector3.UP
	var surf_alt := 1e9
	var local := Vector3.ZERO
	if near:
		local = near.to_local(pos)
		var l := local.length()
		surf_alt = near.altitude_local(local)
		altitude = surf_alt
		if near.data.has_atmo:
			air_density = exp(-maxf(l - near.data.radius, 0.0) / (near.data.radius * 0.17))
	var in_space := surf_alt > 0.0 and (near == null or surf_alt > near.data.radius * 1.5)
	var up_ref := Vector3.UP
	if near:
		up_ref = (pos - near.global_position).normalized()

	# --- pulse drive
	var bh_rel := Vector3.ZERO
	bh_dist = -1.0
	if uni.bh:
		bh_rel = uni.black_hole_rel(pos)
		bh_dist = bh_rel.length()
	var pulse_ok := in_space and (bh_dist < 0.0 or bh_dist > BlackHole.SHEAR_RANGE)
	if star_too_close(uni, pos):
		pulse_ok = false
	if inp.get("pulse_toggle", false):
		if pulse:
			pulse = false
		elif pulse_ok and not warp_lock:
			pulse = true
			message.emit("PULSE DRIVE ENGAGED", 0)
		else:
			message.emit("PULSE DRIVE UNAVAILABLE HERE", 1)
	if pulse and not pulse_ok:
		pulse = false
		message.emit("PULSE DRIVE DISENGAGED", 1)
	boosting = inp.get("boost", false) and not pulse

	# --- target velocity
	var thr_axis: float = inp.get("thrust", 0.0)
	throttle = clampf(throttle + thr_axis * 0.55 * dt, 0.0, 1.0)
	if inp.get("cut", false):
		throttle = 0.0
	var fwd := -global_basis.z
	var right := global_basis.x
	var upv := global_basis.y
	var target_speed := throttle * CRUISE
	var acc_lim := CRUISE_ACC
	if boosting:
		target_speed = BOOST
		acc_lim = BOOST_ACC
	if pulse:
		var nearest_alt := surf_alt if near else 1e9
		target_speed = clampf(nearest_alt * 0.7, 700.0, PULSE)
		acc_lim = PULSE_ACC
		throttle = maxf(throttle, 0.5)
	# slow down near the ground automatically (terrain safety)
	if near and surf_alt < 200.0 and not pulse:
		target_speed *= clampf(surf_alt / 200.0, 0.2, 1.0)
	# atmosphere drag (cap)
	if air_density > 0.02 and not pulse:
		target_speed = minf(target_speed, lerpf(BOOST, 520.0, clampf(air_density, 0.0, 1.0)))
	var strafe: float = inp.get("strafe", 0.0)
	var vert: float = inp.get("vert", 0.0)
	var brake: bool = inp.get("brake", false)
	var near_k := 1.0
	if near and surf_alt < 100.0:
		near_k = clampf(surf_alt / 100.0, 0.12, 1.0)
	var target := fwd * target_speed + right * strafe * 85.0 * near_k + upv * vert * 85.0 * near_k
	if brake:
		target = Vector3.ZERO
		acc_lim = CRUISE_ACC * 1.8
		throttle = maxf(throttle - dt * 1.5, 0.0)
	var delta_v := target - velocity
	var lim := acc_lim * dt
	if delta_v.length() > lim:
		delta_v = delta_v.normalized() * lim
	velocity += delta_v

	# --- gravity (arcade): sinks the ship at low speed near a planet surface
	if near and not near.is_gas and surf_alt < near.data.radius * 0.5:
		var g := near.data.gravity
		var fall := g * (1.0 - smoothstep(near.data.radius * 0.12, near.data.radius * 0.5, surf_alt))
		var lift := clampf((velocity.length() - 20.0) / 70.0, 0.0, 1.0)
		var tw := 1.0 - clampf(lift, 0.0, 1.0)
		if lift_assist > 0.0:
			lift_assist -= dt
			tw = 0.0
		velocity -= up_ref * fall * tw * dt * (0.0 if vert > 0.1 else 1.0)

	# --- black hole
	in_pnr = false
	pull_g = 0.0
	if uni.bh and bh_dist > 0.0:
		var a := BlackHole.pull_accel(bh_rel)
		if bh_dist < BlackHole.WARN_RANGE * 1.2:
			vg += a * dt
			pull_g = a.length()
		else:
			vg *= exp(-1.5 * dt)
		in_pnr = bh_dist < BlackHole.PNR
		if bh_dist < uni.bh.rs * BlackHole.HORIZON_FACTOR and not warp_lock:
			horizon_crossed.emit()
		if bh_dist < BlackHole.WARN_RANGE:
			var inten := clampf(1.0 - bh_dist / BlackHole.WARN_RANGE, 0.0, 1.0)
			shake = maxf(shake, inten * inten * 1.2)

	# --- star heat / gas giant pressure
	if uni.star:
		var sd := pos.distance_to(uni.star.global_position)
		if sd < uni.star.radius * 1.5:
			_damage(30.0 * dt * (1.0 + (uni.star.radius * 1.5 - sd) / uni.star.radius * 2.0), false)
			velocity += (pos - uni.star.global_position).normalized() * 250.0 * dt
			if _msg_cd <= 0.0:
				message.emit("STELLAR RADIATION - TURN BACK", 2)
				_msg_cd = 2.0
	if near and near.is_gas and surf_alt < 0.0:
		_damage(35.0 * dt, false)
		velocity += (pos - near.global_position).normalized() * 500.0 * dt
		shake = maxf(shake, 0.6)
		if _msg_cd <= 0.0:
			message.emit("CRUSHING PRESSURE - CLIMB!", 2)
			_msg_cd = 2.0

	if liftoff_t > 0.0:
		liftoff_t -= dt
		velocity += up_ref * 13.0 * dt
	if brake:
		vg = vg.move_toward(Vector3.ZERO, CRUISE_ACC * 1.2 * dt)
	if uni.bh == null or bh_dist < 0.0:
		vg = Vector3.ZERO
	# --- integrate
	global_position += (velocity + vg) * dt
	speed = (velocity + vg).length()

	# --- atmospheric heat
	var heat_target := 0.0
	if air_density > 0.03 and not in_space:
		heat_target = clampf((speed - 350.0) / 450.0, 0.0, 1.0) * clampf(air_density * 3.0, 0.0, 1.0)
	heat = lerpf(heat, heat_target, 1.0 - exp(-3.0 * dt))
	if heat > 0.5:
		shake = maxf(shake, (heat - 0.5) * 0.7)

	# --- auto-level roll in the atmosphere
	if near and surf_alt < near.data.radius * 0.25 and absf(rollk) < 0.05 and not near.is_gas:
		var rr := global_basis.x.dot(up_ref)
		var ang := asin(clampf(rr, -1.0, 1.0))
		global_basis = (global_basis * Basis(Vector3.BACK, -ang * 1.6 * dt)).orthonormalized()

	# --- gear
	var want_gear := 1.0 if (near and surf_alt < 120.0 and speed < 130.0) else 0.0
	gear = move_toward(gear, want_gear, dt * 1.2)
	_apply_gear()

	# --- terrain contact / landing
	if near and not near.is_gas and surf_alt < GEAR_H + 0.2 and liftoff_t <= 0.0:
		_contact(near, uni, dt)
	vspeed = velocity.dot(up_ref)


func star_too_close(uni: Universe, pos: Vector3) -> bool:
	return uni.star != null and pos.distance_to(uni.star.global_position) < uni.star.radius * 4.0


func _apply_gear() -> void:
	for g in gear_nodes:
		g.scale = Vector3(1.0, lerpf(0.02, 1.0, gear), 1.0)


func _damage(amount: float, with_shield: bool = true) -> void:
	if invulnerable or amount <= 0.0:
		return
	if with_shield and shield > 0.0:
		var s := minf(shield, amount)
		shield -= s
		amount -= s
	hull -= amount
	if hull <= 0.0:
		hull = 0.0
		destroyed.emit()


func _contact(near: PlanetBody, uni: Universe, dt: float) -> void:
	var local := near.to_local(global_position)
	var dir := local.normalized()
	var tp := near.data.terrain
	var ground_r := near.data.radius + tp.ground(dir)
	var on_liquid := tp.sea_level > -50000.0 and tp.height(dir) < tp.sea_level
	var n_local := tp.normal_at(dir, 2.5)
	var n_world := (near.global_basis * n_local).normalized()
	var ground_pt := near.global_position + near.global_basis * (dir * ground_r)
	var rel_v := velocity
	var vn := rel_v.dot(n_world)  # negative = into ground
	var vt := (rel_v - n_world * vn).length()
	var tilt := rad_to_deg(acos(clampf(global_basis.y.dot(n_world), -1.0, 1.0)))
	var h := (global_position - ground_pt).dot(n_world)
	if h > GEAR_H + 0.1:
		return
	if on_liquid:
		# bounce gently off liquid, never land on it
		global_position = ground_pt + n_world * (GEAR_H + 0.2)
		velocity = velocity - n_world * minf(vn, 0.0) + n_world * 6.0
		if vn < -30.0:
			_damage(-vn * 0.15)
		if _liquid_warned <= 0.0:
			message.emit("CANNOT LAND ON LIQUID", 1)
			_liquid_warned = 3.0
		return
	_liquid_warned = maxf(_liquid_warned - dt, 0.0)
	var soft := -vn < 14.0 and vt < 50.0 and tilt < 38.0
	landing_ok = soft
	if soft and gear > 0.8:
		_land_on(near, n_world, ground_pt)
		return
	# crash
	var impact := maxf(-vn, 0.0) + vt * 0.25
	global_position = ground_pt + n_world * (GEAR_H + 0.05)
	if _crash_cd <= 0.0 and impact > 6.0:
		var dmg := clampf((impact - 6.0) * 1.1, 1.0, 120.0)
		_damage(dmg)
		crashed.emit(dmg)
		_crash_cd = 0.6
		shake = 1.0
		message.emit("HARD IMPACT  -%d" % int(dmg), 2)
	if vn < 0.0:
		velocity -= n_world * vn * 1.25
	velocity *= (1.0 - minf(dt * 3.0, 0.8))
	if soft and gear <= 0.8:
		if _msg_cd <= 0.0:
			message.emit("EXTEND LANDING GEAR - slow down", 1)
			_msg_cd = 2.0


func repair() -> void:
	hull = MAX_HULL
	shield = 100.0


# ------------------------------------------------------------------ visuals
func _update_fx(dt: float, uni: Universe) -> void:
	_flame_t += dt
	var power := 0.0
	if state == State.FLYING:
		power = clampf(throttle * 0.6 + (0.5 if boosting else 0.0) + (1.0 if pulse else 0.0) + 0.15, 0.0, 2.2)
	else:
		power = 0.0
	for f in flames:
		var mesh: MeshInstance3D = f.get_meta("mesh")
		var len := (0.4 + power * 3.2) * (0.92 + 0.08 * sin(_flame_t * 60.0 + f.get_instance_id() % 7))
		mesh.scale = Vector3(1.0 + power * 0.25, len, 1.0 + power * 0.25)
		mesh.position = Vector3(0, 0, len * 0.5)
		mesh.visible = power > 0.05
		var m := mesh.material_override as StandardMaterial3D
		var col := Color(0.35, 0.75, 1.0).lerp(Color(0.8, 0.9, 1.0), clampf(power - 1.0, 0.0, 1.0))
		if boosting:
			col = Color(0.6, 0.65, 1.0)
		m.emission = col
		m.albedo_color = Color(col.r, col.g, col.b, 0.85)
		var li: OmniLight3D = f.get_meta("light")
		li.light_energy = clampf(power * 2.2, 0.0, 5.0)
		li.light_color = col
	heat_mesh.visible = heat > 0.05
	if heat_mesh.visible:
		var hm := heat_mesh.material_override as StandardMaterial3D
		var fl := 0.85 + 0.15 * sin(_flame_t * 40.0)
		hm.albedo_color = Color(1.0, 0.4 + 0.3 * (1.0 - heat), 0.12, clampf(heat, 0.0, 1.0) * 0.55 * fl)
		heat_mesh.scale = Vector3(5.2, 3.0, 8.0 + heat * 6.0)
		heat_mesh.position = Vector3(0, 0.1, -2.0 - heat * 2.0)
