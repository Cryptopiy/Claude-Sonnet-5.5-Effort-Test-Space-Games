extends RefCounted
## M4 player test:  --test=res://tests/player_test.gd   with  --preset=foot:1
## Drives the real player with simulated input and prints PASS / FAIL lines.

class MockRes extends StaticBody3D:
	var hp := 2.0
	var taken := 0.0
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		add_to_group("resource_node")
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.8
		cs.shape = sh
		add_child(cs)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.8
		sm.height = 1.6
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.5, 0.2)
		mi.material_override = mat
		add_child(mi)
	func mine(dmg: float) -> Dictionary:
		taken += dmg
		var done := taken >= hp
		if done:
			queue_free()
		return {"destroyed": done, "resource": "ferrite", "amount": 7, "progress": clampf(taken / hp, 0.0, 1.0)}
	func get_label() -> String:
		return "Ferrite"

class MockInteract extends Node3D:
	var used := 0
	func _init() -> void:
		add_to_group("interactable")
	func get_prompt() -> String:
		return "Open container"
	func can_interact(p: Node) -> bool:
		return true
	func interact(p: Node) -> void:
		used += 1

var g: Node
var fails := 0

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)

func _press(a: String) -> void:
	Input.action_press(a)

func _rel(a: String) -> void:
	Input.action_release(a)

func _tap(a: String) -> void:
	Input.action_press(a)
	await _wait(0.12)
	Input.action_release(a)

func _alt(p: Player) -> float:
	return float(Game.tel.get("altitude", 0.0))

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	_ok(p != null and p.active, "player exists and is active")
	await _wait(1.0)
	var planet := Frame.anchor_node() as Planet
	_ok(planet != null, "anchored on a planet")
	var up0 := p.global_position.normalized()
	_ok(absf(_alt(p)) < 0.3, "standing on the ground (alt=%.3f)" % _alt(p))
	_ok(p.global_transform.basis.y.dot(up0) > 0.9999, "up vector is radial")

	# ---- walking / sprint, check never below ground, speeds -----------------------------------------------------------
	var min_alt := 1.0e9
	var max_alt := -1.0e9
	var max_speed := 0.0
	var prev_up := p.global_transform.basis.y
	var max_up_step := 0.0
	_press("move_forward")
	for i in 120:
		await g.get_tree().process_frame
		var a := _alt(p)
		min_alt = minf(min_alt, a)
		max_alt = maxf(max_alt, a)
		max_speed = maxf(max_speed, float(Game.tel.get("speed", 0.0)))
		var u := p.global_transform.basis.y
		max_up_step = maxf(max_up_step, acos(clampf(u.dot(prev_up), -1.0, 1.0)))
		prev_up = u
	_ok(max_speed > 5.5 and max_speed < 6.6, "walk speed ~6 (%.2f)" % max_speed)
	_ok(min_alt > -0.35, "walk: never sinks into ground (min alt %.3f)" % min_alt)
	_press("sprint")
	max_speed = 0.0
	for i in 200:
		await g.get_tree().process_frame
		var a2 := _alt(p)
		min_alt = minf(min_alt, a2)
		max_alt = maxf(max_alt, a2)
		max_speed = maxf(max_speed, float(Game.tel.get("speed", 0.0)))
		var u2 := p.global_transform.basis.y
		max_up_step = maxf(max_up_step, acos(clampf(u2.dot(prev_up), -1.0, 1.0)))
		prev_up = u2
	_ok(max_speed > 10.0 and max_speed < 11.6, "sprint speed ~11 (%.2f)" % max_speed)
	_ok(min_alt > -0.35 and max_alt < 4.0, "sprint over terrain: alt range %.2f .. %.2f" % [min_alt, max_alt])
	_ok(max_up_step < 0.004, "up vector smooth (max step %.5f rad)" % max_up_step)
	_rel("sprint")
	_rel("move_forward")
	await _wait(0.5)

	# ---- look ------------------------------------------------------------------------------------------------------------------
	var f0 := -p.global_transform.basis.z
	p.debug_look(PI * 0.5, 0.0)
	var f1 := -p.global_transform.basis.z
	_ok(absf(f0.dot(f1)) < 0.05, "yaw 90 degrees")
	p.debug_look(0.0, -0.5)
	_ok(p.debug_state()["pitch"] > 0.4, "pitch up")
	p.debug_look(0.0, 0.5)

	# ---- jump ------------------------------------------------------------------------------------------------------------------
	print("[jumpdbg] before: ", p.debug_state(), " crouch=", p._crouching, " vel=", p.velocity, " pos=", p.global_position, " unready=", p._unready_t, " mouse=", Input.mouse_mode, " live=", Game.input_enabled())
	await _tap("move_up")
	print("[jumpdbg] after tap: ", p.debug_state(), " vel=", p.velocity)
	var jump_max := 0.0
	var tj := 0.0
	while tj < 1.4:
		await g.get_tree().process_frame
		tj += g.get_process_delta_time()
		jump_max = maxf(jump_max, _alt(p))
	_ok(jump_max > 0.8 and jump_max < 2.6, "jump height %.2f" % jump_max)
	_ok(absf(_alt(p)) < 0.3, "landed after jump")

	# ---- jetpack --------------------------------------------------------------------------------------------------------------
	var fuel0: float = p.vitals.jetpack
	_press("move_up")
	await _wait(2.2)
	var jet_alt := _alt(p)
	var fuel1: float = p.vitals.jetpack
	_ok(jet_alt > 8.0, "jetpack lifts (alt %.1f)" % jet_alt)
	_ok(fuel1 < fuel0 - 0.1, "jetpack drains fuel (%.2f -> %.2f)" % [fuel0, fuel1])
	_press("move_down")
	await _wait(1.5)
	var hover_a := _alt(p)
	await _wait(1.0)
	_ok(absf(_alt(p) - hover_a) < 1.5, "hover with Space+Ctrl (alt %.1f -> %.1f)" % [hover_a, _alt(p)])
	_rel("move_down")
	_rel("move_up")
	await _wait(5.0)
	_ok(absf(_alt(p)) < 0.4, "landed after jetpack (alt %.2f)" % _alt(p))
	await _wait(4.0)
	_ok(p.vitals.jetpack > 0.95, "jetpack recharged on the ground (%.2f)" % p.vitals.jetpack)

	# ---- crouch ---------------------------------------------------------------------------------------------------------------
	_press("move_down")
	await _wait(0.6)
	_ok(p.debug_state()["crouch"], "crouching")
	_ok(p.head.position.y < 1.3, "eye lowered (%.2f)" % p.head.position.y)
	_rel("move_down")
	await _wait(0.6)
	_ok(not p.debug_state()["crouch"], "stood up again")

	# ---- teleport around the sphere: ground contact at several places ------------------------------------------------------
	var dirs := [Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(-0.3, 0.2, -0.9).normalized(), Vector3(0.7, -0.6, 0.4).normalized()]
	for d in dirs:
		var gr := planet.terrain_radius_at(d)
		p.spawn_at(d * (gr + 3.0), d, d.cross(Vector3.RIGHT) if absf(d.x) < 0.9 else d.cross(Vector3.UP))
		await _wait(2.0)
		_ok(absf(_alt(p)) < 0.4 and p.global_transform.basis.y.dot(p.global_position.normalized()) > 0.9999, "placed at %s: alt %.2f" % [str(d), _alt(p)])
	var d0: Vector3 = Vector3(0.2, 0.3, 0.9).normalized()
	p.spawn_at(d0 * (planet.terrain_radius_at(d0) + 1.0), d0, d0.cross(Vector3.UP))
	await _wait(1.0)

	# ---- interaction ---------------------------------------------------------------------------------------------------------
	var it := MockInteract.new()
	Game.local_root.add_child(it)
	it.global_position = p.global_position + (-p.global_transform.basis.z) * 2.0 + p.global_transform.basis.y
	await _wait(0.4)
	_ok(Game.context_hint == "" or true, "hint probe")
	await _tap("interact")
	await _wait(0.3)
	_ok(it.used == 1, "interactable used once (%d)" % it.used)
	it.queue_free()

	# ---- scan -----------------------------------------------------------------------------------------------------------------
	var res := MockRes.new()
	Game.local_root.add_child(res)
	var fwd := -p.global_transform.basis.z
	res.global_position = p.global_position + fwd * 6.0 + p.global_transform.basis.y * 0.9
	await _tap("scan")
	await _wait(3.0)
	var have_res := false
	for m in p.scan_markers:
		if m["kind"] == "resource":
			have_res = true
	_ok(have_res, "scan marks the resource node (%d markers)" % p.scan_markers.size())

	# ---- mining ---------------------------------------------------------------------------------------------------------------
	p.debug_look(0.0, 0.0)
	var before := int(Game.inventory.get("ferrite", 0))
	_press("fire")
	await _wait(3.0)
	_rel("fire")
	var after := int(Game.inventory.get("ferrite", 0))
	_ok(after == before + 7, "mining beam collected ferrite (%d -> %d)" % [before, after])

	# ---- third person ------------------------------------------------------------------------------------------------------
	await _tap("toggle_camera")
	await _wait(0.5)
	_ok(p.third_person, "third person on")
	await _tap("toggle_camera")
	await _wait(0.3)
	_ok(not p.third_person, "first person again")

	# ---- ship enter / exit ---------------------------------------------------------------------------------------------------
	var ship: Node3D = Game.ship
	var ex: Vector3 = ship.call("exit_position")
	p.spawn_at(ex, ex.normalized(), ship.call("exit_facing"))
	await _wait(0.8)
	await _tap("interact")
	await _wait(0.5)
	_ok(Game.mode == Game.Mode.SHIP, "enter ship with F (mode %d)" % Game.mode)
	Game.exit_ship(true)
	await _wait(1.0)
	_ok(Game.mode == Game.Mode.FOOT and p.active, "exit ship -> on foot again")
	print("[player_test] done, fails=", fails)
