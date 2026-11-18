extends RefCounted
## Black-hole contract test (external_accel / control_authority / pulse_locked / extra_shake).  godot ... -- --autostart --preset=space:1:400 --test=res://tests/ship_bh_contract.gd

func run(game: Node) -> void:
	var ship: Ship = game.ship
	var ok := true
	await game.get_tree().create_timer(0.5).timeout
	# 1. pulse refused while locked
	ship.pulse_locked = true
	Input.action_press("pulse_drive")
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	Input.action_release("pulse_drive")
	await game.get_tree().process_frame
	var refused := ship.pulse_state == Ship.Pulse.OFF
	print("[bh] pulse refused while pulse_locked: ", refused)
	ok = ok and refused
	ship.pulse_locked = false
	# 2. pull with no authority is not cancelled by flight assist
	ship.control_authority = 0.0
	var t := 0.0
	while t < 3.0:
		ship.external_accel = Vector3(40, 0, 0)
		await game.get_tree().process_frame
		t += game.get_process_delta_time()
	var vx := ship.velocity.x
	print("[bh] velocity.x after 3 s of 40 m/s^2 pull with authority 0: %.1f (expect ~120)" % vx)
	ok = ok and vx > 100.0
	# 3. full authority: assist (thrust limited to 40%%) fights the pull
	ship.control_authority = 1.0
	t = 0.0
	while t < 3.0:
		ship.external_accel = Vector3(40, 0, 0)
		await game.get_tree().process_frame
		t += game.get_process_delta_time()
	print("[bh] velocity.x with authority 1 and the same pull: %.1f (assist must reduce it)" % ship.velocity.x)
	ok = ok and ship.velocity.x < vx
	ship.external_accel = Vector3.ZERO
	# 4. shake
	ship.extra_shake = 1.0
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	print("[bh] rig base_shake = %.2f" % ship.rig.base_shake)
	ok = ok and ship.rig.base_shake > 0.5
	ship.extra_shake = 0.0
	print("PASS bh_contract" if ok else "FAIL bh_contract")
