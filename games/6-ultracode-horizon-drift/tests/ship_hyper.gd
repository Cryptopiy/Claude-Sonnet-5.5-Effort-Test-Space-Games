extends RefCounted
## Hyperdrive semantics (can_hyperdrive / hyperdrive_block_reason / Game.try_hyperdrive) + the real jump + arrival.
##   godot ... -- --autostart --preset=space:1:400 --test=res://tests/ship_hyper.gd
## Checks: refused when landed / low over the ground / pulse_locked (gravity well); allowed in space and above 1.5 km; Game.try_hyperdrive pays warp cells and
## the ship arrives in the new system flying (not landed, controls work), then the shake/lock fields are clean.

var game: Node
var ship: Ship
var ok := true

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await game.get_tree().process_frame
		t += game.get_process_delta_time()

func _check(label: String, cond: bool, extra: String = "") -> void:
	print(("PASS " if cond else "FAIL ") + "hyper: " + label + ("  " + extra if extra != "" else ""))
	ok = ok and cond

func _put_air(body: int, alt: float) -> void:
	var b: BodyDef = Universe.system.bodies[body]
	var dir := PoiSites.start_dir(b)
	Frame.set_body_frame(body)
	ship.place_flying(dir, alt, 0.0)
	Frame.set_focus(ship)

func run(g: Node) -> void:
	game = g
	ship = g.ship
	var dest: int = Universe.nearest_stars(Universe.current_id, 1)[0].id
	var bp := Universe.body_pos(1)
	game.place_ship_abs(bp.add_v3(Vector3(0, 0, 600000.0)), Vector3.FORWARD)
	await _wait(1.0)
	_check("in space: can_hyperdrive", ship.can_hyperdrive(), "reason='%s'" % ship.hyperdrive_block_reason())
	# landed
	Frame.set_body_frame(1)
	ship.place_landed(PoiSites.start_dir(Universe.system.bodies[1]), 0.0)
	await _wait(1.0)
	_check("landed: refused", not ship.can_hyperdrive(), "reason='%s'" % ship.hyperdrive_block_reason())
	var msg: String = game.try_hyperdrive(dest)
	_check("landed: Game.try_hyperdrive refuses (" + msg + ")", msg != "" and Game.warp_cells == 2)
	# low over the ground / high in the atmosphere
	_put_air(1, 800.0)
	await _wait(1.0)
	_check("800 m altitude: refused", not ship.can_hyperdrive(), "alt=%.0f reason='%s'" % [ship.altitude, ship.hyperdrive_block_reason()])
	_put_air(1, 2400.0)
	await _wait(1.0)
	_check("2.4 km altitude: allowed", ship.can_hyperdrive(), "alt=%.0f" % ship.altitude)
	# gravity well
	ship.pulse_locked = true
	_check("pulse_locked (gravity well): refused", not ship.can_hyperdrive(), "reason='%s'" % ship.hyperdrive_block_reason())
	ship.pulse_locked = false
	# not enough cells
	var cells := Game.warp_cells
	Game.warp_cells = 0
	var m2: String = game.try_hyperdrive(dest)
	_check("no warp cells: refused (" + m2 + ")", m2 != "")
	Game.warp_cells = cells
	# the real jump, from 2.4 km over Verdant (frame anchored)
	var cost: int = game.hyperdrive_cost(dest)
	var cur := Universe.current_id
	var r: String = game.try_hyperdrive(dest)
	_check("try_hyperdrive returns '' (" + r + ")", r == "")
	var t0 := Time.get_ticks_msec()
	while (game.warping or Universe.current_id == cur) and (Time.get_ticks_msec() - t0) < 25000:
		await game.get_tree().process_frame
	_check("arrived in system %d" % dest, Universe.current_id == dest and not game.warping)
	_check("warp cells paid (%d -> %d, cost %d)" % [cells, Game.warp_cells, cost], Game.warp_cells == cells - cost)
	await _wait(3.0)
	_check("flying after arrival", not ship.is_landed and ship.piloted and Game.mode == Game.Mode.SHIP, "state=%s speed=%.0f anchor=%d" % [str(Game.tel.get("state", "")), ship.velocity.length(), Frame.anchor])
	_check("black-hole fields clean", ship.external_accel == Vector3.ZERO and ship.control_authority >= 0.99 and not ship.pulse_locked and ship.extra_shake == 0.0)
	_check("camera is the ship chase cam", game.get_viewport().get_camera_3d() == ship.rig.chase)
	var img := game.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.previews/hyper_arrival.png"))
	# control check: boost forward for 2 s moves the ship
	Input.action_press("move_forward")
	var p0 := ship.global_position
	await _wait(2.0)
	Input.action_release("move_forward")
	_check("ship accepts thrust after arrival", ship.global_position.distance_to(p0) > 20.0, "moved %.0f m" % ship.global_position.distance_to(p0))
	print("PASS hyper" if ok else "FAIL hyper")
