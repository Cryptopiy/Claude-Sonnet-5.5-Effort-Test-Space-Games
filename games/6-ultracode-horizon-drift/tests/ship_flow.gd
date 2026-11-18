extends RefCounted
## FULL FLIGHT-LOOP BOT (real terrain + atmosphere):  take-off from the start pad -> climb -> leave the atmosphere -> pulse across the system to another
## planet (auto-slow) -> atmospheric entry with heat -> descent -> landing on terrain -> take-off again.  Real input actions (hold/press) are used for
## thrust, boost, pulse, vertical; steering uses Ship.debug_steer (rates computed like a pilot would).
##   godot ... -- --autostart --preset=landed:1 --test=res://tests/ship_flow.gd [--target=3] --quit-at=330
## Prints "[flow] ..." lines and PASS/FAIL per stage.

var ship: Ship
var game: Node
var t := 0.0
var _log_next := 0.0
var _results := {}
var _events: Array = []
var _shot_idx := 0

func _planet_dir_local(body: int) -> Vector3:
	var n := Universe.body_nodes[body] as Node3D
	return (n.global_position - ship.global_position)

func _steer_to(dir: Vector3, gain: float = 2.2, max_rate: float = 1.6) -> float:
	var d := ship.global_transform.basis.transposed() * dir.normalized()
	var pitch := atan2(d.y, -d.z)
	var yaw := atan2(-d.x, -d.z)
	var ang := acos(clampf(-d.z, -1.0, 1.0))
	ship.debug_steer = Vector3(clampf(pitch * gain, -max_rate, max_rate), clampf(yaw * gain, -max_rate, max_rate), 0.0)
	return ang

# ---- pop / jitter probe: screen position of the target planet's centre must continue smoothly across frame switches / rebases --------------------------
var _probe_target := -1
var _probe_hist: Array = []            # [[Vector2 screen_pos, anchor]]
var _probe_errs: Array = []            # extrapolation error (px) on ordinary frames
var _probe_sw: Array = []              # ... on the frame a frame switch happened
var _probe_rb: Array = []              # ... on frames where the SPACE origin was rebased
var _probe_rebased := false
var _speed_jumps: Array = []           # |abs velocity change| across a frame switch (m/s)
var _prev_abs_v := Vector3.ZERO

func _abs_vel() -> Vector3:
	return Frame.basis.inverse() * ship.velocity + Frame.origin_vel

func _probe() -> void:
	if _probe_target < 0:
		return
	var cam := game.get_viewport().get_camera_3d()
	var pn: Node3D = Universe.body_nodes[_probe_target] as Node3D
	if cam == null or pn == null or not is_instance_valid(pn):
		return
	var wp := pn.global_position
	if cam.is_position_behind(wp):
		_probe_hist.clear()
		return
	var sp := cam.unproject_position(wp)
	var an := Frame.anchor
	if _probe_hist.size() >= 2:
		var p1: Vector2 = _probe_hist[-1][0]
		var p2: Vector2 = _probe_hist[-2][0]
		var err := sp.distance_to(p1 * 2.0 - p2)
		if an != int(_probe_hist[-1][1]):
			_probe_sw.append(err)
			print("[flow] PROBE frame switch %d -> %d: planet screen error %.2f px (frame step %.2f px)  abs-velocity change %.1f m/s" % [int(_probe_hist[-1][1]), an, err, p1.distance_to(p2), (_abs_vel() - _prev_abs_v).length()])
			_speed_jumps.append((_abs_vel() - _prev_abs_v).length())
		elif _probe_rebased:
			_probe_rb.append(err)
		else:
			_probe_errs.append(err)
	_probe_rebased = false
	_prev_abs_v = _abs_vel()
	_probe_hist.append([sp, an])
	if _probe_hist.size() > 3:
		_probe_hist.pop_front()

func _probe_report() -> void:
	var sorted := _probe_errs.duplicate()
	sorted.sort()
	var p95 := 0.0
	var mx := 0.0
	if not sorted.is_empty():
		p95 = float(sorted[int(sorted.size() * 0.95)])
		mx = float(sorted[-1])
	var sw_max := 0.0
	for e in _probe_sw:
		sw_max = maxf(sw_max, float(e))
	var rb_max := 0.0
	for e in _probe_rb:
		rb_max = maxf(rb_max, float(e))
	print("[flow] PROBE summary: ordinary frames n=%d p95=%.2f px max=%.2f px | frame switches n=%d max=%.2f px | rebase frames n=%d max=%.2f px" % [sorted.size(), p95, mx, _probe_sw.size(), sw_max, _probe_rb.size(), rb_max])
	_results["no_pop_at_frame_switch"] = _probe_sw.is_empty() or sw_max < maxf(6.0, p95 * 3.0)

func _frame() -> float:
	await game.get_tree().process_frame
	var dt: float = game.get_process_delta_time()
	t += dt
	_probe()
	return dt

func _tel(tag: String) -> void:
	if t < _log_next:
		return
	_log_next = t + 3.0
	var tel := Game.tel
	print("[flow] t=%5.1f %-9s state=%-18s alt=%7.0f spd=%7.0f anchor=%2d gear=%s heat=%.2f dens=%.2f hull=%.2f fuel=%.3f pulse=%d near=%d/%.0f" % [t, tag, str(tel.get("state", "")), float(tel.get("altitude", -1.0)), float(tel.get("speed", 0.0)), Frame.anchor, str(ship.gear_deployed), ship.heat, ship.atmo_density, Game.ship_hull, Game.ship_fuel, ship.pulse_state, ship._near_idx, ship._near_alt])

func _shot(tag: String) -> void:
	var img := game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/flow_%s.png" % tag)
	img.save_png(path)
	print("[flow] shot ", tag)

func _release_all() -> void:
	for a in ["move_up", "move_down", "move_forward", "move_back", "sprint", "move_left", "move_right"]:
		Input.action_release(a)

func run(g: Node) -> void:
	game = g
	ship = g.ship
	var target := 3
	var from_stage := 1
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--target="):
			target = int(String(a).substr(9))
		if String(a).begins_with("--from="):
			from_stage = int(String(a).substr(7))
	Events.ship_landed.connect(func(b): print("[flow] EVENT ship_landed body=", b, " t=%.1f" % t))
	Events.ship_took_off.connect(func(): print("[flow] EVENT ship_took_off t=%.1f" % t))
	Events.ship_crashed.connect(func(s): print("[flow] EVENT ship_crashed sev=%.2f t=%.1f hull=%.2f" % [s, t, Game.ship_hull]))
	Events.atmosphere_entered.connect(func(b): print("[flow] EVENT atmosphere_entered ", b, " t=%.1f" % t))
	Events.atmosphere_left.connect(func(b): print("[flow] EVENT atmosphere_left ", b, " t=%.1f" % t))
	Events.pulse_changed.connect(func(on): print("[flow] EVENT pulse_changed ", on, " t=%.1f" % t))
	Events.gear_changed.connect(func(on): print("[flow] EVENT gear_changed deployed=", on, " t=%.1f" % t))
	Frame.origin_shifted.connect(func(_s): _probe_rebased = true)
	Frame.frame_changed.connect(func(a, b): print("[flow] EVENT frame_changed ", a, " -> ", b, " t=%.1f speed=%.0f" % [t, ship.velocity.length()]))
	print("[flow] START landed=", ship.is_landed, " anchor=", Frame.anchor, " target body=", target)
	await _frame()
	await _frame()

	# ---------------- stage 1: take-off ----------------
	if from_stage <= 1:
		var t0 := t
		Input.action_press("move_up")
		while ship.is_landed and t - t0 < 12.0:
			await _frame()
			_tel("takeoff")
		var took := not ship.is_landed
		print("[flow] STAGE take-off: %s after %.1f s (spool)" % ["OK" if took else "FAILED", t - t0])
		_results["takeoff"] = took
		var up0 := ship.global_position.normalized()
		# hold up until 60 m, then climb with boost at ~50 deg
		while ship.altitude < 60.0 and t - t0 < 30.0:
			await _frame()
			_tel("liftoff")
		_shot("a_liftoff")
		ship.rig.toggle()
		for i in 12:
			await _frame()
		_shot("a2_cockpit")
		ship.rig.toggle()
		Input.action_release("move_up")
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var tc := t
		var max_speed_atmo := 0.0
		var left_atmo := false
		var shot_climb := false
		while t - tc < 60.0:
			await _frame()
			var up := ship.global_position.normalized()
			var f_h := (-ship.global_transform.basis.z - up * (-ship.global_transform.basis.z).dot(up))
			if f_h.length() < 0.2:
				f_h = ship.global_transform.basis.x
			var aim := (up * 0.85 + f_h.normalized() * 0.5).normalized()
			_steer_to(aim)
			max_speed_atmo = maxf(max_speed_atmo, ship.velocity.length() if ship.atmo_density > 0.0 else 0.0)
			_tel("climb")
			if not shot_climb and ship.altitude > 400.0:
				shot_climb = true
				_shot("b_climb")
			if ship.atmo_density <= 0.0 and ship.altitude > 3600.0:
				left_atmo = true
				break
		print("[flow] STAGE climb/leave atmosphere: %s t=%.1f alt=%.0f max_speed_in_atmosphere=%.0f" % ["OK" if left_atmo else "FAILED", t - tc, ship.altitude, max_speed_atmo])
		_results["leave_atmosphere"] = left_atmo
		_shot("c_space")

	# ---------------- stage 2: pulse across the system ----------------
	if from_stage <= 2:
		Input.action_release("sprint")
		Input.action_release("move_forward")
		var tp := t
		var pulse_was_active := false
		var max_pulse_speed := 0.0
		var dropped := false
		var anchors_seen := {}
		var pulse_cmd_t := -10.0
		var d_start := _planet_dir_local(target).length()
		_probe_target = target
		print("[flow] STAGE pulse: distance to target %.0f km" % (d_start / 1000.0))
		while t - tp < 200.0:
			await _frame()
			var to := _planet_dir_local(target)
			_steer_to(to)
			anchors_seen[Frame.anchor] = true
			max_pulse_speed = maxf(max_pulse_speed, ship.velocity.length())
			if ship.pulse_state == Ship.Pulse.ACTIVE:
				pulse_was_active = true
			if ship.pulse_state == Ship.Pulse.OFF:
				if pulse_was_active:
					dropped = true
					break
				if t - pulse_cmd_t > 2.5:
					var ang := ship.global_transform.basis.z.dot(-to.normalized())
					if ang > 0.97:
						pulse_cmd_t = t
						Input.action_press("pulse_drive")
						await _frame()
						Input.action_release("pulse_drive")
			_tel("pulse")
			if t - tp > 20.0 and not _results.has("pulse_shot") and ship.pulse_state == Ship.Pulse.ACTIVE:
				_results["pulse_shot"] = true
				_shot("d_pulse")
		print("[flow] STAGE pulse: %s dropped_out=%s max_speed=%.0f anchors=%s dist_now=%.0f km t=%.1f alt=%.0f" % ["OK" if pulse_was_active and dropped else "FAILED", str(dropped), max_pulse_speed, str(anchors_seen.keys()), _planet_dir_local(target).length() / 1000.0, t - tp, ship.altitude])
		_results["pulse"] = pulse_was_active and dropped

	# ---------------- stage 3: entry with heat ----------------
	if from_stage <= 3:
		var te := t
		var max_heat := 0.0
		var saw_entry := false
		var shot_entry := false
		Input.action_press("sprint")
		Input.action_press("move_forward")
		while t - te < 40.0:
			await _frame()
			var to := _planet_dir_local(target)
			if Frame.anchor == target:
				to = -ship.global_position
			_steer_to(to.normalized() * 0.6 + ship.global_position.normalized() * -0.0)
			max_heat = maxf(max_heat, ship.heat)
			if str(Game.tel.get("state", "")) == "ATMOSPHERIC ENTRY":
				saw_entry = true
			_tel("entry")
			if ship.heat > 0.45 and not shot_entry:
				shot_entry = true
				_shot("e_entry")
			if ship.altitude >= 0.0 and ship.altitude < 900.0:
				break
		print("[flow] STAGE entry: max_heat=%.2f saw_state=%s speed=%.0f alt=%.0f t=%.1f" % [max_heat, str(saw_entry), ship.velocity.length(), ship.altitude, t - te])
		_results["entry_heat"] = max_heat > 0.2
		_shot("f_descent")

	_probe_report()
	_probe_target = -1
	# ---------------- stage 4: descent + landing ----------------
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var tl := t
	var crashed_before := Game.ship_hull
	var did_final_shot := false
	var did_mid_shot := false
	while t - tl < 150.0 and not ship.is_landed:
		await _frame()
		var up := ship.global_position.normalized()
		var fwd := -ship.global_transform.basis.z
		var f_h := fwd - up * fwd.dot(up)
		if f_h.length() < 0.2:
			f_h = ship.global_transform.basis.x.cross(up)
		f_h = f_h.normalized()
		var alt := ship.altitude
		var vrel := ship.velocity
		var vh := vrel - up * vrel.dot(up)
		var vz := vrel.dot(up)
		if alt > 600.0:
			# glide down at a shallow angle, speed ~200 m/s
			_steer_to((f_h * 1.0 - up * 0.45).normalized())
			if ship.velocity.length() < 220.0:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			Input.action_release("move_down")
			Input.action_release("move_back")
		else:
			# final approach: level off, kill horizontal speed, descend on the vertical thrusters (the ship's flare handles the touch-down)
			_steer_to(f_h)
			Input.action_release("move_forward")
			if vh.length() > 30.0:
				Input.action_press("move_back")
			else:
				Input.action_release("move_back")
			if alt > 30.0 and vz > -40.0:
				Input.action_press("move_down")
			elif alt <= 30.0:
				Input.action_press("move_down") if vz > -4.0 else Input.action_release("move_down")
			else:
				Input.action_release("move_down")
			# slope check: look for flatter ground by strafing
			if alt < 140.0 and alt > 12.0 and _slope_deg() > 18.0 and vh.length() < 12.0:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")
		if alt < 600.0 and not did_mid_shot:
			did_mid_shot = true
			_shot("g_mid")
		if alt < 60.0 and not did_final_shot:
			did_final_shot = true
			_shot("g_final")
		_tel("land")
	_release_all()
	ship.debug_steer = null
	await _frame()
	print("[flow] STAGE landing: %s t=%.1f hull_loss=%.2f slope=%.1f deg gear=%s" % ["OK" if ship.is_landed else "FAILED", t - tl, crashed_before - Game.ship_hull, _slope_deg(), str(ship.gear_deployed)])
	_results["landing"] = ship.is_landed
	for i in 40:
		await _frame()
	_shot("h_landed")
	print("[flow] landed pos |r|=%.1f ground r=%.1f feet err" % [ship.global_position.length(), ship._ground_r])

	# ---------------- stage 5: take off again ----------------
	var tt := t
	Input.action_press("move_up")
	while ship.is_landed and t - tt < 12.0:
		await _frame()
		_tel("retake")
	var took2 := not ship.is_landed
	while ship.altitude < 150.0 and t - tt < 40.0:
		await _frame()
		_tel("retake")
	_release_all()
	print("[flow] STAGE re-takeoff: %s alt=%.0f t=%.1f" % ["OK" if took2 and ship.altitude > 100.0 else "FAILED", ship.altitude, t - tt])
	_results["retakeoff"] = took2 and ship.altitude > 100.0
	_shot("i_retakeoff")
	# ---------------- stage 6: crash (no gear, steep dive): hull damage + bounce, never below the terrain ----------------
	await _crash_stage()
	var all_ok := true
	for k in _results.keys():
		if k == "pulse_shot":
			continue
		print("[flow] ", k, " = ", _results[k])
		all_ok = all_ok and bool(_results[k])
	print("PASS flow" if all_ok else "FAIL flow")

func _slope_deg() -> float:
	var pl := Frame.anchor_node() as Planet
	if pl == null:
		return 0.0
	var up := ship.global_position.normalized()
	var n := pl.normal_at(up)
	return rad_to_deg(acos(clampf(n.dot(up), -1.0, 1.0)))


func _crash_stage() -> void:
	var up := ship.global_position.normalized()
	var hull0 := Game.ship_hull
	var sev_list: Array = []
	var cb := func(sev: float): sev_list.append(sev)
	Events.ship_crashed.connect(cb)
	var fwd := -ship.global_transform.basis.z
	var f_h := (fwd - up * fwd.dot(up)).normalized()
	var dive := (-up * 0.6 + f_h * 0.8).normalized()
	ship.global_transform.basis = Basis.looking_at(dive, up)
	ship.velocity = dive * 200.0
	ship.gear_deployed = false
	ship._gear_t = 1.0
	ship._gear_manual_until = ship._time + 60.0
	Input.action_press("move_forward")
	var tc := t
	var min_clear := 1e9
	while t - tc < 8.0:
		await _frame()
		var pl := Frame.anchor_node() as Planet
		if pl != null:
			min_clear = minf(min_clear, ship.global_position.length() - pl.terrain_radius_at(ship.global_position.normalized()))
		_tel("crash")
		if sev_list.size() == 1 and t - tc > 1.0:
			_shot("j_crash")
			sev_list.append(-1.0)
	Input.action_release("move_forward")
	Events.ship_crashed.disconnect(cb)
	print("[flow] STAGE crash: crashes=%s hull %.2f -> %.2f min clearance over terrain %.1f m" % [str(sev_list), hull0, Game.ship_hull, min_clear])
	_results["crash"] = sev_list.size() >= 1 and Game.ship_hull < hull0 and Game.ship_hull >= 0.05 and min_clear > -4.0
