class_name PlayerController
extends RefCounted
## The SpaceWorld "actor": owns the ship and the astronaut, switches between them, runs hazards, interactions and the camera.

enum Mode { SHIP, FOOT }

var world: SpaceWorld
var ship: Ship
var astro: Astronaut
var mode: int = Mode.SHIP
var controls_on: bool = true
var prompt: String = ""
var prompt_key: String = ""
var protection: float = 100.0
var health: float = 100.0
var hazard_type: String = "none"
var hazard_rate: float = 0.0
var in_safe_zone: bool = false
var weather_mul: float = 1.0
var scan_t: float = 99.0
var scan_origin: Vector3 = Vector3.ZERO
var scan_hits: Array = []
var scan_hits_time: float = 0.0
var cinematic: bool = false
var respawn_pending: bool = false
var mine_t: float = 0.0
var mine_target: Dictionary = {}
var mine_scan_t: float = 0.0
var beam: MeshInstance3D
signal mode_changed(mode: int)
signal entered_ship
signal exited_ship
signal respawned

func setup(w: SpaceWorld, parent: Node) -> void:
	world = w
	ship = Ship.new()
	parent.add_child(ship)
	ship.setup(w)
	astro = Astronaut.new()
	parent.add_child(astro)
	astro.setup(w)
	w.actor = self
	w.cam_driver = self
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.4, 1.0, 0.9, 0.85)
	bm.emission_enabled = true
	bm.emission = Color(0.3, 1.0, 0.85)
	bm.emission_energy_multiplier = 3.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bm
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)

# --- SpaceWorld actor protocol -----------------------------------------------------------------------------
func convert_to_planet(rt: Basis, r_s: Vector3, vk: Vector3, om: Vector3) -> void:
	ship.convert_to_planet(rt, r_s, vk, om)

func convert_to_system(rk: Basis, r_s: Vector3, vk: Vector3, om: Vector3) -> void:
	ship.convert_to_system(rk, r_s, vk, om)

func step(delta: float) -> void:
	var skipping: bool = controls_on and Input.is_action_pressed("time_skip") and world.frame_idx >= 0 and (mode == Mode.FOOT or ship.state == Ship.State.LANDED)
	world.time_scale = 120.0 if skipping else 1.0
	_update_prompt_and_interact(delta)
	if mode == Mode.SHIP:
		ship.step(delta, controls_on and not cinematic)
	else:
		ship.step(delta, false)
		if world.frame_idx >= 0:
			astro.step(delta, controls_on)
	_update_hazards(delta)
	scan_t += delta

func update_camera(w: SpaceWorld, delta: float) -> void:
	var xf: Transform3D
	var fov: float
	if mode == Mode.SHIP:
		xf = ship.camera_transform(delta)
		fov = ship.target_fov()
	else:
		xf = astro.camera_transform(delta)
		fov = Game.fov_setting + (6.0 if astro.sprinting else 0.0)
	w.camera.global_transform = xf
	w.camera.fov = lerpf(w.camera.fov, fov, 1.0 - exp(-6.0 * delta))
	var cockpit: bool = mode == Mode.SHIP and ship.cam_mode == 1 and not ship.menu_cam
	w.camera.near = 0.08 if cockpit else 0.2
	w.camera.far = 1000000.0 if cockpit else 1500000.0

# --- interaction -------------------------------------------------------------------------------------------
func _update_prompt_and_interact(delta: float) -> void:
	prompt = ""
	prompt_key = ""
	if cinematic or not controls_on:
		return
	var pressed: bool = Input.is_action_just_pressed("interact")
	if mode == Mode.SHIP:
		if ship.state == Ship.State.LANDED and ship._land_t >= 1.0:
			prompt = "Exit ship"
			prompt_key = "F"
			if pressed:
				exit_ship()
		elif ship.state == Ship.State.FLYING:
			var p: Planet = ship.planet_here()
			if p != null and p.data.landable and world.altitude < 2000.0:
				if ship.landing_assist:
					prompt = "Landing assist active - descending (any thrust key cancels)"
					prompt_key = "L"
				elif world.altitude < 400.0:
					prompt = "Landing assist: auto-land"
					prompt_key = "L"
			elif p == null and ship.target_idx >= 0 and not ship.auto_pulse:
				prompt = "Auto-pulse to %s" % ship.target_name()
				prompt_key = "Z"
	else:
		if world.frame_idx < 0:
			return
		# nearest interactable
		var best: Node3D = null
		var best_d: float = 4.5
		var pos: Vector3 = astro.global_position
		for n in astro.get_tree().get_nodes_in_group("interact"):
			var nn: Node3D = n as Node3D
			if nn == null or not nn.is_inside_tree():
				continue
			var d: float = nn.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = nn
		var hatch_d: float = astro.global_position.distance_to(ship.hatch_world())
		var ship_d: float = astro.global_position.distance_to(ship.global_position)
		if hatch_d < 7.0 or ship_d < 9.0:
			prompt = "Enter ship"
			prompt_key = "F"
			if pressed:
				enter_ship()
				return
		if best != null:
			prompt = String(best.get_meta("prompt", "Interact"))
			prompt_key = "F"
			if pressed:
				_interact_with(best)
				return
		if Input.is_action_just_pressed("scan"):
			do_scan()
		if Input.is_action_pressed("recharge"):
			_recharge(delta)
		_update_mining(delta, best == null)

func _update_mining(delta: float, allowed: bool) -> void:
	mine_scan_t -= delta
	if mine_scan_t <= 0.0:
		mine_scan_t = 0.15
		mine_target = {}
		var pl: Planet = world.planets[world.frame_idx]
		var cam_fwd: Vector3 = -world.camera.global_basis.z
		var cpos: Vector3 = world.camera.global_position
		var best_s: float = 0.0
		for h in pl.terrain.find_resources(astro.global_position, 11.0):
			var to: Vector3 = ((h["pos"] as Vector3) + (astro.global_position.normalized() * 0.8)) - cpos
			var d: float = to.length()
			var facing: float = to.normalized().dot(cam_fwd)
			if d < 11.0 and facing > 0.35:
				var sc: float = facing * 2.0 - d * 0.1
				if sc > best_s or mine_target.is_empty():
					best_s = sc
					mine_target = h
	if mine_target.is_empty() or not allowed:
		mine_t = maxf(0.0, mine_t - delta * 2.0)
		beam.visible = false
		return
	var rec: Dictionary = mine_target["res"]
	if bool(rec["done"]):
		mine_target = {}
		return
	if prompt == "":
		prompt = "Hold mouse button: mine %s" % String(rec["label"])
		prompt_key = "LMB"
	if Input.is_action_pressed("mine") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mine_t += delta / 1.15
		var from_p: Vector3 = astro.global_position + astro.global_position.normalized() * 1.25
		var to_p: Vector3 = mine_target["pos"]
		to_p += astro.global_position.normalized() * 0.5
		var mid: Vector3 = (from_p + to_p) * 0.5
		var dvec: Vector3 = to_p - from_p
		beam.visible = true
		beam.global_transform = Transform3D(U.basis_from_up(dvec.normalized(), Vector3.FORWARD).scaled(Vector3(1, dvec.length(), 1)), mid)
		if mine_t >= 1.0:
			mine_t = 0.0
			var amount: int = randi_range(5, 11)
			world.planets[world.frame_idx].terrain.collect_resource(rec)
			Game.add_item(String(rec["kind"]), amount)
			Game.notify("+%d %s" % [amount, String(rec["kind"]).capitalize()], 2.5, "good")
			Game.play_sfx("pickup", -4.0)
			beam.visible = false
			mine_target = {}
	else:
		mine_t = maxf(0.0, mine_t - delta * 2.0)
		beam.visible = false

func _interact_with(n: Node3D) -> void:
	match String(n.get_meta("interact_type", "")):
		"crate":
			var loot: String = String(n.get_meta("loot", "supplies"))
			var r := U.rng(int(n.global_position.x * 13.0 + n.global_position.z * 7.0 + n.global_position.y * 3.0) + 17)
			var parts: Array[String] = []
			var c: int = r.randi_range(8, 22)
			Game.add_item("carbon", c)
			parts.append("%d Carbon" % c)
			var f: int = r.randi_range(6, 20)
			Game.add_item("ferrite", f)
			parts.append("%d Ferrite" % f)
			if r.randf() < 0.6:
				var s: int = r.randi_range(4, 14)
				Game.add_item("sodium", s)
				parts.append("%d Sodium" % s)
			if r.randf() < 0.25:
				Game.add_item("warp_cells", 1)
				parts.append("1 Warp Cell")
			Game.notify("Crate opened: " + ", ".join(parts), 4.0, "good")
			n.remove_from_group("interact")
			n.visible = false
			for ch in n.get_children():
				if ch is StaticBody3D:
					(ch as StaticBody3D).collision_layer = 0
		_:
			pass

func do_scan() -> void:
	scan_t = 0.0
	scan_origin = astro.global_position if mode == Mode.FOOT else ship.global_position
	Game.stats["scans"] = int(Game.stats["scans"]) + 1
	scan_hits.clear()
	scan_hits_time = 0.0
	if world.frame_idx < 0:
		return
	var pl: Planet = world.planets[world.frame_idx]
	var found: Array = pl.find_points_of_interest(scan_origin, 300.0)
	for f in found:
		scan_hits.append(f)
	for n in astro.get_tree().get_nodes_in_group("interact"):
		var nn: Node3D = n as Node3D
		if nn != null and nn.is_inside_tree() and nn.global_position.distance_to(scan_origin) < 420.0:
			scan_hits.append({"pos": nn.global_position, "label": "Supply crate", "kind": "crate"})
	scan_hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector3).distance_squared_to(scan_origin) < (b["pos"] as Vector3).distance_squared_to(scan_origin))
	if scan_hits.size() > 36:
		scan_hits.resize(36)
	for fa in astro.get_tree().get_nodes_in_group("fauna"):
		var fn: Node3D = fa as Node3D
		if fn != null and fn.global_position.distance_to(scan_origin) < 260.0:
			var sp: String = String(fn.get("species"))
			scan_hits.append({"pos": fn.global_position + fn.global_position.normalized() * 1.0, "label": "Fauna: " + sp, "kind": "creature"})
			if fn.global_position.distance_to(scan_origin) < 120.0:
				Game.discover("fauna_" + sp, "New species catalogued: %s" % sp)
	Game.notify("Scan complete: %d signals detected" % scan_hits.size(), 2.5)
	Game.play_sfx("ping", -4.0)
	Game.discover("first_scan", "Scanner online - signals marked on your HUD")

func _recharge(delta: float) -> void:
	if protection >= 100.0:
		return
	if Game.get_item("sodium") <= 0:
		if int(Time.get_ticks_msec() / 800) % 4 == 0:
			Game.notify("No Sodium left to recharge your protection", 1.5, "warn")
		return
	_recharge_acc += delta * 30.0
	protection = minf(100.0, protection + delta * 30.0)
	if _recharge_acc >= 25.0:
		_recharge_acc = 0.0
		Game.inventory["sodium"] = int(Game.inventory["sodium"]) - 1

var _recharge_acc: float = 0.0

# --- mode switching ------------------------------------------------------------------------------------
func exit_ship() -> void:
	if ship.state != Ship.State.LANDED or world.frame_idx < 0:
		return
	var up: Vector3 = ship.position.normalized()
	var side: float = -1.0 if ship.exit_local.x <= 0.0 else 1.0
	# step out beyond the wing tip, a little ahead of the hull centre
	var ex: Vector3 = ship.position + ship.basis * Vector3(side * 9.0, ship.exit_local.y, ship.exit_local.z - 2.5)
	var pl: Planet = world.planets[world.frame_idx]
	var d: Vector3 = ex.normalized()
	var gr: float = pl.data.radius + pl.ground_height(d) + 0.15
	ex = d * maxf(ex.length(), gr)
	var outward: Vector3 = ex - ship.position
	outward -= up * outward.dot(up)
	var fwd: Vector3 = -ship.basis.z
	fwd -= up * fwd.dot(up)
	var face: Vector3 = outward.normalized() * 0.7 + fwd.normalized() * 0.7
	astro.spawn_at(ex, face)
	astro.third_person = true
	ship.set_pilot_inside(false)
	mode = Mode.FOOT
	Game.capture_mouse(true)
	exited_ship.emit()
	mode_changed.emit(mode)
	Game.notify("You left the ship - WASD move, Shift sprint, Space jump / hold for jetpack", 4.0)
	Game.discover("first_exit", "First steps on %s" % world.planets[world.frame_idx].data.name)

func enter_ship() -> void:
	astro.set_active(false)
	ship.set_pilot_inside(true)
	ship.cam_basis = ship.basis
	mode = Mode.SHIP
	exited_ship.emit()
	entered_ship.emit()
	mode_changed.emit(mode)
	Game.notify("Back in the cockpit - hold Space or W to take off", 3.5)
	protection = 100.0

# --- hazards ------------------------------------------------------------------------------------------
func _update_hazards(delta: float) -> void:
	hazard_type = "none"
	hazard_rate = 0.0
	in_safe_zone = false
	if world.frame_idx < 0:
		protection = minf(100.0, protection + 8.0 * delta)
		health = minf(100.0, health + 4.0 * delta)
		return
	var pl: Planet = world.planets[world.frame_idx]
	var hz: Dictionary = pl.data.profile.get("hazard", {})
	hazard_type = String(hz.get("type", "none"))
	var level: float = float(hz.get("level", 0.0))
	if mode == Mode.SHIP:
		in_safe_zone = true
	else:
		var d: float = astro.global_position.distance_to(ship.global_position)
		in_safe_zone = d < 14.0
	if hazard_type == "none" or level <= 0.0:
		protection = minf(100.0, protection + 10.0 * delta)
		health = minf(100.0, health + 4.0 * delta)
		return
	hazard_rate = level * 1.45 * weather_mul
	if in_safe_zone:
		protection = minf(100.0, protection + 12.0 * delta)
		health = minf(100.0, health + 6.0 * delta)
		return
	protection = maxf(0.0, protection - hazard_rate * delta)
	if protection <= 0.0:
		health = maxf(0.0, health - 4.0 * delta)
		if health <= 0.0 and not respawn_pending:
			_suit_failure()

func _suit_failure() -> void:
	respawn_pending = true
	Game.notify("SUIT FAILURE - emergency teleport to your ship", 4.0, "warn")
	protection = 60.0
	health = 70.0
	if mode == Mode.FOOT and ship.state == Ship.State.LANDED:
		var ex: Vector3 = ship.exit_world()
		astro.global_position = ex
		astro.velocity = Vector3.ZERO
	respawn_pending = false
	respawned.emit()

# --- spawning helpers ----------------------------------------------------------------------------------
func spawn_flying_near(body_i: int, alt_m: float, look_at_body: bool = true) -> void:
	var pos: D3 = world.orbit_position_near(body_i, alt_m)
	world.frame_idx = -1
	world.viewer_sys = pos.copy()
	world.viewer_pos = Vector3.ZERO
	ship.state = Ship.State.FLYING
	ship.position = Vector3.ZERO
	var pk: D3 = world.body_pos(body_i, world.time)
	var d: Vector3 = pk.rel(pos).normalized()
	ship.basis = Basis.looking_at(d, Vector3.UP)
	ship.cam_basis = ship.basis
	ship.velocity = Vector3.ZERO
	ship.gear_target = 0.0
	ship.gear = 0.0
	ship._set_collider(false)
	mode = Mode.SHIP
	astro.set_active(false)
	ship.set_pilot_inside(true)
	world.frame_changed.emit(-1)

func spawn_landed(body_i: int, outpost_i: int, pilot_inside: bool = false) -> void:
	var pl: Planet = world.planets[body_i]
	var o: Dictionary = pl.data.outposts[outpost_i]
	var dir: Vector3 = o["dir"]
	var base: Vector3 = dir * (pl.data.radius + float(o["flat_h"]) + 0.12)
	ship.place_landed(body_i, base, U.any_perp(dir))
	ship.gear = 1.0
	world.viewer_pos = ship.position
	if pilot_inside:
		mode = Mode.SHIP
		astro.set_active(false)
		ship.set_pilot_inside(true)
	else:
		mode = Mode.SHIP
		exit_ship()
	world.frame_changed.emit(body_i)

## Place the ship in a freshly loaded system (after a black hole transit or a hyperdrive jump).
func arrive_in_system(sys: SystemData, _kind: String) -> void:
	world.frame_idx = -1
	world.viewer_pos = Vector3.ZERO
	ship.reset_after_transport()
	ship.state = Ship.State.FLYING
	ship._set_collider(false)
	ship.position = Vector3.ZERO
	ship.gear = 0.0
	ship.gear_target = 0.0
	mode = Mode.SHIP
	astro.set_active(false)
	ship.set_pilot_inside(true)
	var r := U.rng(sys.seed_i * 3 + 11)
	# arrive ~70-95 km from a landable planet, on its star-facing side, looking at it
	var cands: Array[BodyData] = sys.landable_bodies()
	var tgt: BodyData = cands[r.randi() % cands.size()]
	world.time = 0.0
	var pos: D3 = world.orbit_position_near(tgt.index, 70000.0 + r.randf() * 25000.0, U.rand_unit(r))
	world.viewer_sys = pos
	var pk: D3 = world.body_pos(tgt.index, world.time)
	var d: Vector3 = pk.rel(pos).normalized()
	ship.basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT)
	ship.cam_basis = ship.basis
	ship.velocity = d * 380.0
	ship.target_idx = tgt.index
	world.frame_changed.emit(-1)
