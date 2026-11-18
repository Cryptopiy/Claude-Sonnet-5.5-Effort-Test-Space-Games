class_name Ship
extends Node3D
## Player spaceship. Arcade 6-DOF flight with flight-assist, boost, pulse drive, auto-levelling landing mode.
## The ship lives either in SPACE (system frame, doubles for position) or in a planet's rotating local frame
## (when below the body's frame altitude) - this is what makes take-off/landing seamless.

const GEAR_H := 2.0           # model origin -> foot pad with gear down
const BELLY_H := 1.05
const V_CRUISE := 300.0
const BOOST_MULT := 2.6
const V_ATMO := 260.0
const SOFT_LAND_V := 10.0

signal landed
signal crashed(speed: float)
signal took_off

var frame: Body = null
var apos := DV.new()
var vel := Vector3.ZERO
var basis_w := Basis.IDENTITY
var lpos := Vector3.ZERO
var lvel := Vector3.ZERO
var lbasis := Basis.IDENTITY

var is_landed := false
var gear_down := false
var gear_t := 0.0             # 0 retracted .. 1 extended
var throttle := 0.0
var boosting := false
var pulse_on := false
var pulse_spool := 0.0
var pulse_locked := false
var hull := 100.0
var shield := 100.0
var ang_pending := Vector2.ZERO
var roll_rate := 0.0
var alt := 1e9
var near_body: Body
var rel_vel := Vector3.ZERO    # velocity relative to reference (surface / target / nearest body), render-space axes
var speed := 0.0
var entry_heat := 0.0
var disabled := false
var ext_accel := Vector3.ZERO  # extra acceleration (black hole), system frame
var ref_vel := Vector3.ZERO
var target_body: Body = null
var shake := 0.0
var autopilot_hold := false
var pulse_cap := 0.0
var drop_msg_cd := 0.0
var damage_flash := 0.0

var model: Node3D
var body_node: Node3D
var glass_node: MeshInstance3D
var gear_nodes := {}
var flames: Array = []
var flame_mat: ShaderMaterial
var heat_mi: MeshInstance3D
var heat_mat: ShaderMaterial
var engine_light: OmniLight3D
var nose_light: SpotLight3D
var bank_vis := 0.0
var pitch_vis := 0.0
var flame_len_cur := 0.2


func _ready() -> void:
	_load_model()


func _load_model() -> void:
	var scene: PackedScene = load("res://assets/models/ship.glb")
	model = scene.instantiate()
	ModelLib._tone_emission(model)
	add_child(model)
	body_node = model.find_child("Ship_Body", true, false)
	glass_node = model.find_child("Ship_Glass", true, false) as MeshInstance3D
	for nm in ["Front", "L", "R"]:
		gear_nodes[nm] = model.find_child("Ship_Gear_" + nm, true, false)
	flame_mat = ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/flame.gdshader")
	for nm in ["L", "R", "C"]:
		var f := model.find_child("Ship_Flame_" + nm, true, false) as MeshInstance3D
		if f:
			f.material_override = flame_mat
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flames.append(f)
	# glass: transparent tinted
	if glass_node:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.25, 0.45, 0.6, 0.30)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.roughness = 0.05
		gm.metallic = 0.2
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass_node.material_override = gm
		glass_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	engine_light = OmniLight3D.new()
	engine_light.light_color = Color(0.4, 0.75, 1.0)
	engine_light.omni_range = 40.0
	engine_light.light_energy = 0.0
	engine_light.position = Vector3(0, 0, 6.5)
	engine_light.shadow_enabled = false
	add_child(engine_light)
	nose_light = SpotLight3D.new()
	nose_light.position = Vector3(0, -0.3, -4.6)
	nose_light.rotation = Vector3(deg_to_rad(-9.0), 0, 0)
	nose_light.spot_range = 260.0
	nose_light.spot_angle = 30.0
	nose_light.spot_attenuation = 0.9
	nose_light.light_energy = 9.0
	nose_light.light_color = Color(1.0, 0.96, 0.88)
	nose_light.shadow_enabled = false
	nose_light.visible = false
	add_child(nose_light)
	# atmospheric entry plasma sheath
	heat_mi = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	heat_mi.mesh = sm
	heat_mat = ShaderMaterial.new()
	heat_mat.shader = load("res://shaders/heat.gdshader")
	heat_mi.material_override = heat_mat
	heat_mi.scale = Vector3(3.6, 3.0, 8.5)
	heat_mi.position = Vector3(0, 0, -1.5)
	heat_mi.visible = false
	heat_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(heat_mi)
	_apply_gear_pose()


# ------------------------------------------------------------------ frame helpers
func world_basis() -> Basis:
	return basis_w if frame == null else frame.rot * lbasis


func abs_pos() -> DV:
	return apos if frame == null else frame.local_to_abs(lpos)


func world_velocity() -> Vector3:
	if frame == null:
		return vel
	return frame.local_point_velocity(lpos) + frame.rot * lvel


func enter_frame(b: Body) -> void:
	if frame == b:
		return
	if frame != null:
		leave_frame()
	var p := b.abs_to_local(apos)
	lvel = b.rot.transposed() * (vel - b.local_point_velocity(p))
	lbasis = b.rot.transposed() * basis_w
	lpos = p
	frame = b


func leave_frame() -> void:
	if frame == null:
		return
	var b := frame
	apos = b.local_to_abs(lpos)
	vel = b.local_point_velocity(lpos) + b.rot * lvel
	basis_w = b.rot * lbasis
	frame = null
	ref_vel = b.vel


func teleport_surface(b: Body, dir: Vector3, height: float, face_basis := Basis.IDENTITY) -> void:
	frame = b
	var r: float = b.radius + b.data.height_at(dir) + height
	lpos = dir * r
	lvel = Vector3.ZERO
	var up := dir
	var fwd := up.cross(Vector3.RIGHT).normalized()
	if fwd.length() < 0.1:
		fwd = up.cross(Vector3.FORWARD).normalized()
	lbasis = Basis.looking_at(fwd, up)
	is_landed = false


func teleport_space(p: DV, v: Vector3, bas: Basis) -> void:
	frame = null
	apos = p
	vel = v
	basis_w = bas
	is_landed = false
	ref_vel = v


func set_cockpit_visible(chase: bool) -> void:
	if glass_node:
		glass_node.visible = chase


func set_gear(down: bool) -> void:
	if gear_down != down:
		gear_down = down
		Sfx.play("gear", -4.0)
		if down:
			throttle = 0.0
			pulse_on = false


func _apply_gear_pose() -> void:
	var t := ease(gear_t, 0.6)
	var a := (1.0 - t) * deg_to_rad(95.0)
	var gf: Node3D = gear_nodes.get("Front")
	var gl: Node3D = gear_nodes.get("L")
	var gr: Node3D = gear_nodes.get("R")
	if gf:
		gf.rotation = Vector3(a, 0, 0)
		gf.visible = gear_t > 0.02
	if gl:
		gl.rotation = Vector3(0, 0, a)
		gl.visible = gear_t > 0.02
	if gr:
		gr.rotation = Vector3(0, 0, -a)
		gr.visible = gear_t > 0.02


# ------------------------------------------------------------------ simulation
func _nearest_info(w) -> Dictionary:
	var best: Body = null
	var bd := 1e30
	var cur := abs_pos()
	for b: Body in w.bodies:
		var d := cur.dist(b.apos) - b.radius
		if d < bd:
			bd = d
			best = b
	return {"body": best, "dist": bd}


func _update_frame(w) -> void:
	if frame == null:
		for b: Body in w.bodies:
			if b.is_landable():
				if apos.dist(b.apos) - b.radius < b.frame_alt:
					enter_frame(b)
					return
	else:
		if lpos.length() - frame.radius > frame.frame_alt * 1.25:
			leave_frame()


func sim(dt: float, w, inp: Dictionary) -> void:
	_update_frame(w)
	var info := _nearest_info(w)
	near_body = info.body
	var dsurf: float = info.dist
	var in_local := frame != null
	# ---------------- altitude
	if in_local:
		var d := lpos.length()
		var dir := lpos / d
		var floor_r := frame.radius + frame.data.height_at(dir)
		if frame.data.has_liquid() and frame.data.liquid != PlanetData.Liquid.NONE:
			floor_r = maxf(floor_r, frame.radius + frame.data.sea_level)
		alt = d - floor_r
	else:
		alt = dsurf if dsurf < 60000.0 else 1e9
	# ---------------- input
	var mouse: Vector2 = inp.get("mouse", Vector2.ZERO)
	var roll_in: float = inp.get("roll", 0.0)
	var thr_in: float = inp.get("thr", 0.0)
	var strafe: float = inp.get("strafe", 0.0)
	var vert: float = inp.get("vert", 0.0)
	var want_boost: bool = inp.get("boost", false)
	var want_pulse: bool = inp.get("pulse", false)
	var brake: bool = inp.get("brake", false)
	if disabled:
		mouse = Vector2.ZERO
		roll_in = 0.0
		thr_in = 0.0
		strafe = 0.0
		vert = 0.0
		want_boost = false
		want_pulse = false
	if is_landed:
		_sim_landed(dt, vert, thr_in)
		_post(dt, in_local)
		return
	# ---------------- throttle / modes
	if gear_down:
		throttle = 0.0
	else:
		throttle = clampf(throttle + thr_in * 0.55 * dt, 0.0, 1.0)
		if brake:
			throttle = move_toward(throttle, 0.0, dt * 1.8)
	boosting = want_boost and not gear_down and throttle > 0.02
	# pulse drive (space only)
	var can_pulse := frame == null and not gear_down and not pulse_locked and alt > 3000.0
	if want_pulse and can_pulse:
		if not pulse_on:
			Sfx.play("select", -6.0, 0.6)
		pulse_on = true
	else:
		pulse_on = false
	pulse_spool = move_toward(pulse_spool, 1.0 if pulse_on else 0.0, dt / (1.8 if pulse_on else 0.6))
	# ---------------- orientation
	var B := lbasis if in_local else basis_w
	var sens := 0.0022 * Game.mouse_sens
	var yaw_mul := 1.0 - 0.55 * pulse_spool
	if Game.invert_y:
		mouse.y = -mouse.y
	ang_pending += Vector2(-mouse.y * sens, -mouse.x * sens)
	var k := 1.0 - exp(-dt * 16.0)
	var step := ang_pending * k
	ang_pending -= step
	var max_step := 2.3 * dt * yaw_mul
	step = Vector2(clampf(step.x, -max_step, max_step), clampf(step.y, -max_step, max_step))
	roll_rate = lerpf(roll_rate, roll_in * 1.7, 1.0 - exp(-dt * 7.0))
	B = B * Basis(Vector3.RIGHT, step.x) * Basis(Vector3.UP, step.y) * Basis(Vector3.BACK, roll_rate * dt)
	# landing mode: auto level against local up
	if in_local and gear_down:
		var up := lpos.normalized()
		var fwd := -B.z
		var fh := fwd - up * fwd.dot(up)
		if fh.length() < 0.05:
			fh = -B.y - up * (-B.y).dot(up)
		fh = fh.normalized()
		var target := Basis.looking_at(fh, up)
		var level_k := clampf(1.0 - alt / 400.0, 0.12, 1.0) * dt * 2.4
		B = B.orthonormalized().slerp(target, level_k)
	B = B.orthonormalized()
	if in_local:
		lbasis = B
	else:
		basis_w = B
	# ---------------- velocity control (relative to reference frame)
	var fwd2 := -B.z
	var right := B.x
	var rv: Vector3
	if in_local:
		rv = lvel
	else:
		var want_ref := Vector3.ZERO
		var rb: Body = target_body
		if rb == null and near_body != null and dsurf < near_body.radius * 8.0 + 20000.0:
			rb = near_body
		if rb != null:
			want_ref = rb.vel
		ref_vel = ref_vel.lerp(want_ref, 1.0 - exp(-dt * 1.2))
		rv = vel - ref_vel
	if not in_local:
		rv += ext_accel * dt           # black-hole pull acts on the real velocity, flight assist has to fight it
	var v_cmd := Vector3.ZERO
	var a_lim := 110.0
	if gear_down and in_local:
		var up2 := lpos.normalized()
		var fh2 := (fwd2 - up2 * fwd2.dot(up2)).normalized()
		var rh2 := (right - up2 * right.dot(up2)).normalized()
		var v_vert := -clampf(2.0 + alt * 0.11, 2.0, 46.0)       # auto descent (fast high up, gentle near the ground)
		if vert > 0.0:
			v_vert = 22.0 * vert
		elif vert < 0.0:
			v_vert = -42.0
		elif brake:
			v_vert = 0.0
		if alt < 3.0 and vert <= 0.0:
			v_vert = -3.0
		v_cmd = fh2 * thr_in * 38.0 + rh2 * strafe * 32.0 + up2 * v_vert
		a_lim = 70.0
	else:
		var vmax := V_CRUISE
		if in_local:
			vmax = V_ATMO
			vmax = minf(vmax, 70.0 + maxf(alt, 0.0) * 1.3)
		var boost_f := BOOST_MULT if boosting else 1.0
		var spd_cmd := throttle * vmax * boost_f
		v_cmd = fwd2 * spd_cmd + right * strafe * 55.0 + B.y * vert * 55.0
		if in_local and not gear_down:
			pass
		a_lim = 130.0 + (240.0 if boosting else 0.0)
		if pulse_spool > 0.0:
			var cap := clampf(0.85 * dsurf, 320.0, 24000.0)
			if drop_msg_cd <= 0.0 and cap < 900.0 and pulse_on:
				Game.msg("PULSE DRIVE DISENGAGED - gravity well", "warn")
				drop_msg_cd = 4.0
				pulse_on = false
			pulse_cap = cap
			v_cmd = fwd2 * cap * pulse_spool + v_cmd * (1.0 - pulse_spool)
			a_lim = lerpf(a_lim, 9000.0, pulse_spool)
		if brake and not gear_down:
			v_cmd = Vector3.ZERO
			a_lim = 260.0
	drop_msg_cd = maxf(drop_msg_cd - dt, 0.0)
	# speed far above the commanded speed (leaving pulse drive, atmospheric braking) is shed quickly;
	# not inside a black hole's pull, otherwise the point of no return would not exist
	var excess := rv.length() - v_cmd.length()
	if excess > 60.0 and pulse_spool < 0.25 and ext_accel.length() < 0.4:
		a_lim = maxf(a_lim, excess * 4.0)
	rv += (v_cmd - rv).limit_length(a_lim * dt)
	# ground-proximity assist: limit descent rate near the surface
	if in_local:
		var up3 := lpos.normalized()
		var vv := rv.dot(up3)
		var allow := -(9.0 + maxf(alt, 0.0) * 0.6)
		if vv < allow:
			rv -= up3 * (vv - allow)
	# ---------------- integrate
	if in_local:
		lvel = rv
		lpos += lvel * dt
	else:
		vel = ref_vel + rv
		apos.add_in_place(vel * dt)
	rel_vel = rv
	speed = rv.length()
	_collide(dt)
	_post(dt, in_local)
	# bank / pitch cosmetics
	bank_vis = lerpf(bank_vis, clampf(-strafe * 0.3 + (step.y / maxf(dt, 0.001)) * 0.12, -0.5, 0.5), 1.0 - exp(-dt * 5.0))


func _sim_landed(dt: float, vert: float, thr_in: float) -> void:
	speed = 0.0
	rel_vel = Vector3.ZERO
	if vert > 0.0 or thr_in > 0.5:
		is_landed = false
		var up := lpos.normalized()
		lvel = up * 4.0
		lpos += up * 0.6
		Sfx.play("select", -4.0, 0.7)
		took_off.emit()
		Game.msg("Take-off", "info")


func _collide(dt: float) -> void:
	if frame == null:
		# solid bodies in space: star and gas giants push the ship away
		return
	var d := lpos.length()
	var dir := lpos / d
	var h := frame.data.height_at(dir)
	var ground_r := frame.radius + h
	var on_liquid := false
	if frame.data.has_liquid():
		var lr := frame.radius + frame.data.sea_level
		if lr > ground_r:
			ground_r = lr
			on_liquid = true
	var gh := GEAR_H if gear_down else BELLY_H
	if d - ground_r >= gh:
		return
	var n := dir if on_liquid else frame.data.normal_at(dir, 2.0)
	var vv := lvel.dot(dir)
	var up_ship := lbasis.y
	var tilt := acos(clampf(up_ship.dot(n), -1.0, 1.0))
	var slope_ok := n.dot(dir) > 0.8
	var lat_speed := (lvel - dir * vv).length()
	if gear_down and vv > -SOFT_LAND_V and tilt < 0.65 and slope_ok and lat_speed < 18.0:
		# touchdown
		is_landed = true
		lvel = Vector3.ZERO
		throttle = 0.0
		var fwd := -lbasis.z
		fwd = (fwd - n * fwd.dot(n)).normalized()
		lbasis = Basis.looking_at(fwd, n)
		lpos = dir * (ground_r + GEAR_H * 1.0) if on_liquid else _settle_pos(dir, n, ground_r)
		Sfx.play("thud", -2.0)
		shake = 0.4
		landed.emit()
		if on_liquid:
			if frame.data.liquid == PlanetData.Liquid.WATER:
				Game.msg("Splashdown - ship afloat", "info")
			else:
				Game.msg("WARNING: landed on hazardous liquid", "warn")
		else:
			Game.msg("Landed on %s" % frame.display_name, "good")
		return
	# crash / bounce
	var impact := maxf(-vv, lat_speed * 0.25)
	if impact > 5.0:
		var dmg := (impact - 4.0) * 1.3
		_damage(dmg)
		Sfx.play("thud", 1.0, 0.85)
		crashed.emit(impact)
		Game.msg("Hull impact! %d%% integrity" % int(hull), "warn")
	var bounce := 0.28
	lvel = lvel - dir * vv * (1.0 + bounce)
	lvel *= 0.85
	lpos = dir * (ground_r + gh + 0.05)
	shake = maxf(shake, clampf(impact * 0.05, 0.0, 1.0))


func _settle_pos(dir: Vector3, n: Vector3, ground_r: float) -> Vector3:
	return dir * (ground_r + GEAR_H / maxf(n.dot(dir), 0.8))


func _damage(a: float) -> void:
	damage_flash = 1.0
	var sa := minf(shield, a)
	shield -= sa
	hull = maxf(hull - (a - sa), 0.0)


func _post(dt: float, in_local: bool) -> void:
	# gear animation
	var gt := 1.0 if gear_down else 0.0
	gear_t = move_toward(gear_t, gt, dt / 0.9)
	_apply_gear_pose()
	# shields regen
	shield = minf(shield + dt * 2.0, 100.0)
	if is_landed:
		hull = minf(hull + dt * 1.0, 100.0)
	# atmospheric entry heating
	var heat := 0.0
	if in_local and frame != null and frame.data.atmo_height > 0.0:
		var dens := frame.atmosphere_density_at(maxf(alt, 0.0) * 0.4)   # visual 'thickness' reaches higher than the physical one
		heat = clampf((speed - 90.0) / 220.0, 0.0, 1.0) * clampf(dens * 2.2, 0.0, 1.0)
	entry_heat = lerpf(entry_heat, heat, 1.0 - exp(-dt * 3.0))
	shake = maxf(shake - dt * 1.4, 0.0)
	damage_flash = maxf(damage_flash - dt * 2.5, 0.0)
	# visuals
	var f_target := 0.12 + throttle * 0.7 + (0.9 if boosting else 0.0) + pulse_spool * 2.2
	if is_landed:
		f_target = 0.0
	flame_len_cur = lerpf(flame_len_cur, f_target, 1.0 - exp(-dt * 6.0))
	for f: MeshInstance3D in flames:
		f.scale = Vector3(1.0 + flame_len_cur * 0.12, 1.0 + flame_len_cur * 0.12, maxf(flame_len_cur, 0.02))
		f.visible = flame_len_cur > 0.03
	if flame_mat:
		flame_mat.set_shader_parameter("intensity", 0.7 + flame_len_cur * 0.55)
		flame_mat.set_shader_parameter("col_core", Color(0.45, 0.75, 1.0).lerp(Color(1.0, 0.6, 0.3), clampf(entry_heat, 0.0, 1.0)))
	if engine_light:
		engine_light.light_energy = clampf(flame_len_cur * 1.6, 0.0, 6.0)
	if heat_mi:
		heat_mi.visible = entry_heat > 0.04
		if heat_mat:
			heat_mat.set_shader_parameter("heat", entry_heat)
	if model:
		model.rotation = Vector3(0, 0, bank_vis)


## sound for engines etc. (called by the world with the ship active)
func update_audio() -> void:
	if is_landed or disabled:
		Sfx.set_loop("engine", -80.0)
		Sfx.set_loop("pulse", -80.0)
		return
	var lvl := 0.15 + throttle * 0.85 + (0.5 if boosting else 0.0)
	Sfx.set_loop("engine", -22.0 + lvl * 10.0, 0.7 + lvl * 0.45)
	if pulse_spool > 0.02:
		Sfx.set_loop("pulse", -26.0 + pulse_spool * 18.0, 0.6 + pulse_spool * 0.9)
	else:
		Sfx.set_loop("pulse", -80.0)
