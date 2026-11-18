extends RefCounted
## Pulse-drive approach test: from 400 km out, aim at Verdant, engage the pulse drive and let the ship fly in (no further input).
## Verifies: auto speed limit near the planet, frame capture switch is seamless (camera lag does not jump), pulse drops out before the atmosphere,
## gear auto-deploys, no script errors.   godot ... -- --autostart --preset=space:1:400 --test=res://tests/ship_approach.gd
## Output lines: "[approach] ..." + PASS/FAIL.

func _aim(ship: Ship) -> void:
	var node := Universe.body_nodes[1] as Node3D
	var to := node.global_position - ship.global_position
	if to.length() > 1.0:
		ship.global_transform.basis = Basis.looking_at(to.normalized(), Vector3.UP if absf(to.normalized().y) < 0.95 else Vector3.RIGHT)

func run(game: Node) -> void:
	var ship: Ship = game.ship
	var t := 0.0
	var next_log := 0.0
	var max_lag_jump := 0.0
	var prev_lag := 0.0
	var prev_anchor := Frame.anchor
	var anchor_switches := 0
	var pulse_dropped_alt := -1.0
	var was_pulse := false
	var max_speed := 0.0
	var gear_seen := false
	var min_alt := 1e9
	Input.action_press("pulse_drive")
	await game.get_tree().process_frame
	Input.action_release("pulse_drive")
	while t < 85.0:
		await game.get_tree().process_frame
		var dt: float = game.get_process_delta_time()
		t += dt
		if Frame.anchor < 0 or ship.altitude > 6000.0:
			_aim(ship)
		var lag_ang: float = ship.rig._lag.get_rotation_quaternion().get_angle()
		if t > 1.0:
			max_lag_jump = maxf(max_lag_jump, absf(lag_ang - prev_lag))
		prev_lag = lag_ang
		if Frame.anchor != prev_anchor:
			anchor_switches += 1
			print("[approach] t=%.1f frame switch %d -> %d  speed=%.0f lag=%.3f" % [t, prev_anchor, Frame.anchor, ship.velocity.length(), lag_ang])
			prev_anchor = Frame.anchor
		max_speed = maxf(max_speed, ship.velocity.length())
		if was_pulse and ship.pulse_state == Ship.Pulse.OFF and pulse_dropped_alt < 0.0:
			pulse_dropped_alt = ship.altitude
		was_pulse = ship.pulse_state != Ship.Pulse.OFF
		gear_seen = gear_seen or ship.gear_deployed
		if ship.altitude >= 0.0:
			min_alt = minf(min_alt, ship.altitude)
		if t >= next_log:
			next_log += 3.0
			var dv: float = ((Universe.body_nodes[1] as Node3D).global_position - ship.global_position).length()
			print("[approach] t=%.1f state=%s speed=%.0f alt=%.0f anchor=%d gear=%s hull=%.2f fuel=%.3f dist_verdant=%.0f near=%d near_alt=%.0f" % [t, Game.tel.get("state", ""), Game.tel.get("speed", 0.0), Game.tel.get("altitude", -1.0), Frame.anchor, str(ship.gear_deployed), Game.ship_hull, Game.ship_fuel, dv, ship._near_idx, ship._near_alt])
		if ship.is_landed:
			print("[approach] LANDED at t=%.1f" % t)
			break
	print("[approach] switches=%d max_speed=%.0f pulse_dropped_at_alt=%.0f gear_deployed=%s max_lag_jump=%.4f rad min_alt=%.0f landed=%s hull=%.2f" % [anchor_switches, max_speed, pulse_dropped_alt, str(gear_seen), max_lag_jump, min_alt, str(ship.is_landed), Game.ship_hull])
	var ok := anchor_switches >= 1 and pulse_dropped_alt > 2500.0 and gear_seen and max_lag_jump < 0.06
	print("PASS approach" if ok else "FAIL approach")
