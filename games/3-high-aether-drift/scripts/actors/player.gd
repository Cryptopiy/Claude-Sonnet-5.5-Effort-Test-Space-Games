class_name Player
extends Node3D
## On-foot astronaut. Lives in the planet's local frame (child of the PlanetBody), so the planet's spin and orbit carry
## it along for free. Gravity points at the planet centre; "up" is the radial direction.

signal message(text: String, level: int)
signal interact(kind: String, node: Node)
signal died()
signal collected(item: String, amount: int)

const WALK := 6.5
const SPRINT := 15.0
const EYE_H := 1.7

var planet: PlanetBody
var vel: Vector3 = Vector3.ZERO  # planet-local
var fwd: Vector3 = Vector3(0, 0, -1)
var pitch: float = 0.0
var on_floor: bool = false
var in_liquid: bool = false
var third_person: bool = false
var jetting: bool = false
var sprinting: bool = false
var health: float = 100.0
var protection: float = 100.0
var jet_fuel: float = 100.0
var inventory: Dictionary = {}
var power_cells: int = 2
var scan_timer: float = 0.0
var sheltered: bool = false
var weather_factor: float = 1.0
var mining_progress: float = 0.0
var mining_target: Dictionary = {}
var look_pool: Vector2 = Vector2.ZERO
var look_sens: float = 1.0

var model: Node3D
var cam_mount: Node3D
var tool_node: Node3D
var beam: MeshInstance3D
var scan_ring: MeshInstance3D
var jet_light: OmniLight3D
var _jet_fx: Array = []
var _walk_phase: float = 0.0
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _bob: float = 0.0
var _scan_t: float = -1.0
var interact_info: Dictionary = {}
var _slide: bool = false
var ship_ref: Node3D = null
var used_pois: Dictionary = {}


func _ready() -> void:
	model = Assets.instance("astronaut")
	model.name = "Model"
	add_child(model)
	_leg_l = model.find_child("LegL", true, false)
	_leg_r = model.find_child("LegR", true, false)
	_arm_l = model.find_child("ArmL", true, false)
	_arm_r = model.find_child("ArmR", true, false)
	_head = model.find_child("Head", true, false)
	model.visible = false
	cam_mount = Node3D.new()
	cam_mount.name = "CamMount"
	cam_mount.position = Vector3(0, EYE_H, 0)
	add_child(cam_mount)
	tool_node = Assets.instance("multitool")
	tool_node.position = Vector3(0.27, -0.27, -0.55)
	tool_node.rotation_degrees = Vector3(2, -3, 0)
	cam_mount.add_child(tool_node)
	# mining beam
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 1.0
	cm.radial_segments = 6
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.3, 0.9, 1.0)
	bm.emission_enabled = true
	bm.emission = Color(0.3, 0.9, 1.0)
	bm.emission_energy_multiplier = 4.0
	beam.material_override = bm
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	# scanner ring
	scan_ring = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	scan_ring.mesh = sm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.3, 0.8, 1.0, 0.12)
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.emission_enabled = true
	rm.emission = Color(0.3, 0.8, 1.0)
	rm.emission_energy_multiplier = 1.5
	scan_ring.material_override = rm
	scan_ring.visible = false
	scan_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scan_ring)
	# jetpack flames
	jet_light = OmniLight3D.new()
	jet_light.light_color = Color(0.4, 0.8, 1.0)
	jet_light.omni_range = 7.0
	jet_light.light_energy = 0.0
	jet_light.position = Vector3(0, 0.9, 0.4)
	add_child(jet_light)
	for n in ["JetL", "JetR"]:
		var e := model.find_child(n, true, false)
		if e == null:
			continue
		var cmesh := CylinderMesh.new()
		cmesh.top_radius = 0.0
		cmesh.bottom_radius = 0.07
		cmesh.height = 0.6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(0.4, 0.8, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.4, 0.8, 1.0)
		m.emission_energy_multiplier = 3.0
		var f := MeshInstance3D.new()
		f.mesh = cmesh
		f.material_override = m
		f.rotation_degrees = Vector3(180, 0, 0)
		f.position = Vector3(0, -0.3, 0)
		f.visible = false
		e.add_child(f)
		_jet_fx.append(f)


func set_third_person(on: bool) -> void:
	third_person = on
	model.visible = on
	tool_node.visible = not on
	if on:
		cam_mount.position = Vector3(0, EYE_H, 0)


func camera_offset() -> Vector3:
	return Vector3(0.45, 0.35, 3.6) if third_person else Vector3.ZERO


func spawn_at(pl: PlanetBody, local_pos: Vector3, heading: Vector3) -> void:
	planet = pl
	if get_parent():
		get_parent().remove_child(self)
	pl.add_child(self)
	var up := local_pos.normalized()
	var d := up
	var gr := pl.ground_radius(d)
	var p := d * (gr + 0.2)
	fwd = (heading - up * heading.dot(up)).normalized()
	vel = Vector3.ZERO
	pitch = 0.0
	_apply_transform(p)
	on_floor = false


func _apply_transform(p: Vector3) -> void:
	var up := p.normalized()
	fwd = (fwd - up * fwd.dot(up))
	if fwd.length() < 0.001:
		fwd = up.cross(Vector3.RIGHT)
	fwd = fwd.normalized()
	var right := fwd.cross(up).normalized()
	transform = Transform3D(Basis(right, up, -fwd), p)
	cam_mount.rotation.x = pitch


func update_player(dt: float, inp: Dictionary, uni: Universe) -> void:
	if planet == null:
		return
	var tp := planet.data.terrain
	var R := planet.data.radius
	var p := position
	var up := p.normalized()
	# --- look
	look_pool += inp.get("look", Vector2.ZERO)
	var step := look_pool * (1.0 - exp(-30.0 * dt))
	look_pool -= step
	var sens := 0.0022 * look_sens
	fwd = fwd.rotated(up, -step.x * sens)
	pitch = clampf(pitch - step.y * sens, -1.45, 1.45)
	var right := fwd.cross(up).normalized()
	# --- gravity / ground
	var g := planet.data.gravity
	var dir := up
	var gr := R + tp.ground(dir)
	var alt := p.length() - gr
	var terrain_h := tp.height(dir)
	in_liquid = tp.sea_level > -50000.0 and terrain_h < tp.sea_level - 0.3 and alt < 0.6
	var vup: float = vel.dot(up)
	var vh := vel - up * vup
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	var wish := (fwd * mv.y + right * mv.x)
	if wish.length() > 1.0:
		wish = wish.normalized()
	sprinting = inp.get("sprint", false) and mv.y > 0.1 and not in_liquid
	var spd := SPRINT if sprinting else WALK
	if in_liquid:
		spd = 3.4
	var jump_pressed: bool = inp.get("jump_pressed", false)
	var jump_held: bool = inp.get("jump_held", false)
	on_floor = alt < 0.12 and vup <= 0.5
	jetting = false
	if on_floor:
		var n := tp.normal_at(dir, 1.2)
		var slope_cos := n.dot(up)
		_slide = slope_cos < 0.55 and not in_liquid
		var target := wish * spd
		vh = vh.move_toward(target, (70.0 if mv.length() > 0.01 else 55.0) * dt)
		if _slide:
			var gvec := -up
			var sl := gvec - n * gvec.dot(n)
			vh += sl.normalized() * g * 1.8 * dt
		if jump_pressed and not _slide:
			vup = sqrt(2.0 * g * 1.5)
			on_floor = false
	else:
		vh = vh.move_toward(wish * spd, 14.0 * dt)
		vup -= g * dt
		# jetpack
		if jump_held and jet_fuel > 0.0 and not jump_pressed:
			jetting = true
			vup += g * 1.9 * dt
			vup = minf(vup, 12.0)
			jet_fuel = maxf(jet_fuel - 24.0 * dt, 0.0)
	if on_floor and not jetting:
		jet_fuel = minf(jet_fuel + 40.0 * dt, 100.0)
	if in_liquid and not jetting:
		vup = maxf(vup, -2.0)
	vel = vh + up * vup
	# --- integrate + collide
	p += vel * dt
	if planet.props:
		var push := planet.props.collide(p, 0.45)
		if push.length() > 0.0:
			p += push
			var pn := push.normalized()
			vel -= pn * minf(vel.dot(pn), 0.0)
	var ndir := p.normalized()
	var ngr := R + tp.ground(ndir)
	var nalt := p.length() - ngr
	var snap := nalt < 0.5 and on_floor and (vel.dot(ndir) <= 0.5)
	if nalt < 0.0 or snap:
		p = ndir * ngr
		var vr := vel.dot(ndir)
		if vr < 0.0:
			vel -= ndir * vr
			on_floor = true
	_apply_transform(p)
	# --- animation
	_animate(dt, vh.length(), vup)
	# --- bob in first person
	var sp := vh.length()
	_bob += sp * dt * (1.3 if sprinting else 1.6)
	if on_floor and not third_person:
		cam_mount.position.y = EYE_H + sin(_bob * 2.0) * 0.035 * clampf(sp / 6.0, 0.0, 1.0)
		tool_node.position.x = 0.27 + sin(_bob) * 0.012 * clampf(sp / 6.0, 0.0, 1.0)
		tool_node.position.y = -0.27 + sin(_bob * 2.0) * 0.01 * clampf(sp / 6.0, 0.0, 1.0)
	else:
		cam_mount.position.y = EYE_H
	# --- hazards
	_update_hazard(dt, uni)
	# --- scanner / mining / interactions
	_update_scan(dt)
	_update_mining(dt, inp)
	_update_interact(inp)
	if jetting:
		for f in _jet_fx:
			f.visible = true
			f.scale = Vector3(1, 0.8 + randf() * 0.5, 1)
		jet_light.light_energy = 1.5
	else:
		for f in _jet_fx:
			f.visible = false
		jet_light.light_energy = 0.0


func _animate(dt: float, sp: float, vup: float) -> void:
	if _leg_l == null:
		return
	var amt := clampf(sp / 6.0, 0.0, 1.4)
	if on_floor:
		_walk_phase += sp * dt * 1.5
		var sw := sin(_walk_phase * 2.0) * 0.75 * amt
		_leg_l.rotation.x = sw
		_leg_r.rotation.x = -sw
		_arm_l.rotation.x = -sw * 0.8
		_arm_r.rotation.x = sw * 0.8 - 0.25
		model.position.y = absf(sin(_walk_phase * 2.0)) * 0.05 * amt
	else:
		var tuck := 0.5 if jetting else 0.25
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, tuck, 6.0 * dt)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -tuck * 0.5, 6.0 * dt)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.5, 6.0 * dt)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.9, 6.0 * dt)
		model.position.y = 0.0
	if _head:
		_head.rotation.x = clampf(pitch, -0.6, 0.6)


func _update_hazard(dt: float, uni: Universe) -> void:
	var hz: Dictionary = planet.data.hazard
	var rate: float = hz.get("rate", 0.0) * weather_factor
	sheltered = false
	if ship_ref and is_instance_valid(ship_ref) and ship_ref.global_position.distance_to(global_position) < 14.0:
		sheltered = true
	if planet.props and planet.props.site_node:
		var sp: Vector3 = planet.props.site_node.position
		if position.distance_to(sp) < 24.0:
			sheltered = true
	if sheltered:
		protection = minf(protection + 25.0 * dt, 100.0)
	elif rate > 0.0:
		protection = maxf(protection - rate * dt * 1.4, 0.0)
	if protection <= 0.0 and rate > 0.0 and not sheltered:
		health -= 3.5 * dt
	else:
		health = minf(health + 4.0 * dt, 100.0)
	if in_liquid and planet.data.liquid in ["lava", "toxic"]:
		health -= 22.0 * dt
		protection = maxf(protection - 15.0 * dt, 0.0)
	if health <= 0.0:
		health = 100.0
		protection = 100.0
		died.emit()


func use_power_cell() -> void:
	if power_cells > 0 and protection < 99.0:
		power_cells -= 1
		protection = minf(protection + 45.0, 100.0)
		jet_fuel = 100.0
		message.emit("Suit recharged  (+45 protection)", 0)
	elif power_cells <= 0:
		message.emit("No power cells - collect resources", 1)


func add_item(item: String, n: int = 1) -> void:
	inventory[item] = inventory.get(item, 0) + n
	collected.emit(item, n)
	# every few crystals/ore condense into a power cell
	if item == planet.data.resource_name and inventory[item] % 3 == 0:
		power_cells += 1
		message.emit("Power cell fabricated", 0)


func do_scan() -> void:
	if _scan_t >= 0.0:
		return
	_scan_t = 0.0
	scan_timer = 14.0
	message.emit("Scanning area...", 0)


func _update_scan(dt: float) -> void:
	scan_timer = maxf(scan_timer - dt, 0.0)
	if _scan_t >= 0.0:
		_scan_t += dt
		scan_ring.visible = true
		scan_ring.position = Vector3(0, 1.0, 0)
		var r := _scan_t * 160.0 + 1.0
		scan_ring.scale = Vector3.ONE * r
		var m := scan_ring.material_override as StandardMaterial3D
		m.albedo_color.a = clampf(0.2 * (1.0 - _scan_t / 1.4), 0.0, 1.0)
		if _scan_t > 1.4:
			_scan_t = -1.0
			scan_ring.visible = false


func _update_mining(dt: float, inp: Dictionary) -> void:
	var firing: bool = inp.get("fire", false)
	beam.visible = false
	if not firing or planet.props == null:
		mining_progress = maxf(mining_progress - dt * 2.0, 0.0)
		mining_target = {}
		return
	var cam := cam_mount
	var o := planet.to_local(cam.global_position) if false else (planet.global_transform.affine_inverse() * cam.global_position)
	var d := (planet.global_basis.inverse() * (-cam.global_basis.z)).normalized()
	var r := planet.props.nearest_resource(o, d, 38.0, 2.4)
	if r.is_empty():
		mining_progress = maxf(mining_progress - dt * 2.0, 0.0)
		mining_target = {}
		# short visible beam when firing into nothing
		_show_beam(cam.global_position + (-cam.global_basis.z) * 22.0)
		return
	if mining_target.is_empty() or mining_target.get("id", -1) != r["id"]:
		mining_progress = 0.0
	mining_target = r
	mining_progress += dt / 1.1
	_show_beam(planet.global_transform * (r["pos"] as Vector3) + planet.global_basis * ((r["pos"] as Vector3).normalized() * 0.7))
	if mining_progress >= 1.0:
		mining_progress = 0.0
		var kind: String = r["kind"]
		var item: String = planet.data.resource_name if kind == "crystal" else planet.data.ore_name
		planet.props.remove_resource(r)
		mining_target = {}
		add_item(item, 1 if kind == "crystal" else 2)
		message.emit("+%d %s" % [1 if kind == "crystal" else 2, item], 0)


func _show_beam(target_global: Vector3) -> void:
	var muzzle := tool_node.find_child("Muzzle", true, false)
	var start: Vector3 = muzzle.global_position if (muzzle and tool_node.visible) else cam_mount.global_position + Vector3.DOWN * 0.3
	var len := start.distance_to(target_global)
	if len < 0.1:
		return
	beam.visible = true
	var mid := (start + target_global) * 0.5
	var dirv := (target_global - start).normalized()
	var upv := Vector3.UP if absf(dirv.y) < 0.95 else Vector3.RIGHT
	var bs := Basis.looking_at(dirv, upv) * Basis(Vector3.RIGHT, deg_to_rad(90)) * Basis.from_scale(Vector3(1, len, 1))
	beam.global_transform = Transform3D(bs, mid)


func _update_interact(inp: Dictionary) -> void:
	interact_info = {}
	if planet == null:
		return
	# enter ship
	if ship_ref and is_instance_valid(ship_ref):
		var dship := ship_ref.global_position.distance_to(global_position)
		if dship < 10.0:
			interact_info = {"text": "[E] Enter ship", "kind": "ship", "node": ship_ref}
	if planet.props:
		for n in planet.props.poi_nodes:
			if not is_instance_valid(n) or used_pois.has(n.get_instance_id()):
				continue
			var dd: float = n.global_position.distance_to(global_position)
			var typ: String = n.get_meta("poi", "supply")
			var lim := 9.0 if typ != "supply" else 5.0
			if dd < lim:
				var t: String = {"monolith": "[E] Touch the monolith", "beacon": "[E] Activate beacon", "supply": "[E] Open supply crate"}[typ]
				interact_info = {"text": t, "kind": typ, "node": n}
	if inp.get("interact", false) and not interact_info.is_empty():
		var n: Node = interact_info["node"]
		if interact_info["kind"] != "ship":
			used_pois[n.get_instance_id()] = true
		interact.emit(interact_info["kind"], n)
