extends RefCounted
## Gas giant barrier test: dive into Colossus' cloud tops with boost held; the crushing-pressure barrier must stop and push the ship back.
##   godot ... -- --autostart --preset=air:5:6000 --test=res://tests/ship_gas.gd

func run(game: Node) -> void:
	var ship: Ship = game.ship
	var up := ship.global_position.normalized()
	ship.global_transform.basis = Basis.looking_at(-up, Vector3.RIGHT)
	ship.velocity = -up * 800.0
	Input.action_press("sprint")
	var t := 0.0
	var max_pressure := 0.0
	var min_r := 1e12
	var R: float = Universe.system.bodies[5].radius
	var next := 0.0
	var states := {}
	while t < 14.0:
		await game.get_tree().process_frame
		t += game.get_process_delta_time()
		max_pressure = maxf(max_pressure, ship._pressure)
		min_r = minf(min_r, ship.global_position.length())
		states[str(Game.tel.get("state", ""))] = true
		if t >= next:
			next += 1.5
			print("[gas] t=%.1f r-R=%.0f speed=%.0f pressure=%.2f state=%s hull=%.2f heat=%.2f" % [t, ship.global_position.length() - R, ship.velocity.length(), ship._pressure, Game.tel.get("state", ""), Game.ship_hull, ship.heat])
	Input.action_release("sprint")
	var depth_below_tops := R - min_r
	print("[gas] max_pressure=%.2f min (r-R)=%.0f states=%s" % [max_pressure, -depth_below_tops, str(states.keys())])
	print("PASS gas" if ship.global_position.length() > R * 0.95 and max_pressure > 0.0 else "FAIL gas")
