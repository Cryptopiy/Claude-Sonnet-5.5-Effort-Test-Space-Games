extends RefCounted
## END-TO-END black-hole test with the real ship and real input actions (module M5).
##   --test=res://tests/bh_e2e.gd -- --autostart --preset=bh:400 --timescale=1.5 [--shots=.previews/e2e] [--leg=1|2|both] [--fast=1] [--pulse=1]
## Leg 1: Aurelia, 400 km from "Charon's Gate": engage the pulse drive (it must be refused/dropped by the gravity well), hold forward+boost, log every
##        warning level, HUD toasts/hints/flashes, pulse lock, authority fade, point of no return, horizon crossing, warp overlay coverage,
##        arrival in system 1 (Kepler's Rest) next to "Return Gate", ejection speed decaying smoothly.
## Leg 2: ejected outward -> turn around, fly back through the Return Gate, arrive in Aurelia again.
## --fast=1 (default) skips the boring cruise stretches by re-placing the ship on the same line (400 -> 306 km, 290 -> 126 km, 104 -> 70 km): every
##        warning zone and the whole final approach are still flown for real with the real flight model.
## Every phase prints PASS/FAIL lines; `[e2e]` lines are the narrative log.  (--timescale: with the 30 fps cap use 1.5 so that dt = 0.05 s.)

var log_levels: Array = []
var toasts: Array = []
var hints: Array = []
var flashes := 0
var entered := false
var max_shake := 0.0
var min_auth := 1.0
var pulse_lock_seen := false
var pulse_lock_r := 0.0
var cover_seen := false
var warp_started_kind := ""
var warp_finished_id := -1
var t_start_ms := 0
var fast := true

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func _bh_abs() -> DVec:
	return Universe.body_pos(Universe.system.black_hole_index)

func _dist(game: Node) -> float:
	return _bh_abs().distance_to(Frame.to_abs(game.ship.global_position))

func _shot(game: Node, tag: String) -> void:
	var base := _arg("shots", "")
	if base == "":
		return
	var img: Image = game.get_viewport().get_texture().get_image()
	var full := ProjectSettings.globalize_path("res://%s_%s.png" % [base, tag])
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	img.save_png(full)
	print("[e2e] shot ", tag)

func _gt() -> float:
	return (Time.get_ticks_msec() - t_start_ms) / 1000.0

func _hook() -> void:
	Events.blackhole_warning.connect(func(level: int, d: float):
		if log_levels.is_empty() or log_levels[-1] != level:
			log_levels.append(level)
			print("[e2e] t=%.1f Events.blackhole_warning level=%d dist=%.0f m" % [_gt(), level, d]))
	Events.blackhole_entered.connect(func(): entered = true; print("[e2e] t=%.1f Events.blackhole_entered" % _gt()))
	Events.notify.connect(func(txt: String, kind: String): toasts.append(txt); print("[e2e] t=%.1f TOAST(%s): %s" % [_gt(), kind, txt]))
	Events.hint.connect(func(txt: String, _sec: float): hints.append(txt); print("[e2e] t=%.1f HINT: %s" % [_gt(), txt]))
	Events.screen_flash.connect(func(_c: Color, _d: float): flashes += 1)
	Events.warp_started.connect(func(id: int, kind: String): warp_started_kind = kind; print("[e2e] t=%.1f Events.warp_started -> system %d (%s)" % [_gt(), id, kind]))
	Events.warp_finished.connect(func(id: int): warp_finished_id = id; print("[e2e] t=%.1f Events.warp_finished system %d" % [_gt(), id]))

func _sample(game: Node) -> void:
	var s = game.ship
	max_shake = maxf(max_shake, float(s.get("extra_shake")))
	min_auth = minf(min_auth, float(s.get("control_authority")))
	if bool(s.get("pulse_locked")) and not pulse_lock_seen:
		pulse_lock_seen = true
		pulse_lock_r = _dist(game)
		print("[e2e] t=%.1f pulse_locked first set at %.0f m" % [_gt(), pulse_lock_r])
	if game.warp_fx != null and game.warp_fx.get("_progress") != null and float(game.warp_fx.get("_progress")) > 0.95:
		cover_seen = true

## a pilot's correction: aim so that (heading * speed + reference-frame velocity) points at the hole (the flight assist keeps the ship relative to nearby planets)
func _aim(game: Node, speed: float = 1200.0) -> void:
	var s = game.ship
	var to: Vector3 = (Frame.to_local(_bh_abs()) - s.global_position).normalized()
	var ref: Vector3 = s.get("_ref_vel")
	var want: Vector3 = (to * speed - ref).normalized()
	s.look_at(s.global_position + want, Vector3.UP)
	s.set("_pend", Vector2.ZERO)
	s.set("_rate", Vector3.ZERO)

func _line(game: Node, label: String) -> void:
	var s = game.ship
	var to: Vector3 = (Frame.to_local(_bh_abs()) - s.global_position).normalized()
	print("[e2e] t=%.1f %s dist=%.0f m speed=%.0f m/s v_in=%.0f fwd.dot(bh)=%.2f accel=%.1f auth=%.2f lock=%s shake=%.2f lvl=%d" % [_gt(), label, _dist(game), s.velocity.length(), s.velocity.dot(to), (-s.global_transform.basis.z).dot(to), s.external_accel.length(), s.control_authority, str(s.pulse_locked), s.extra_shake, int(game.tel.get("bh_level", -1))])

func _wait_arrival(game: Node, sys: int, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Universe.current_id != sys or game.warping:
		await game.get_tree().process_frame
		_sample(game)
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			return false
	return true

## re-place the ship on the same line to the hole at a new distance, keeping heading and velocity (cruise skipping, --fast)
func _jump(game: Node, new_d: float) -> void:
	var s = game.ship
	var bh := _bh_abs()
	var sp := Frame.to_abs(s.global_position)
	var dir: Vector3 = sp.sub(bh).to_v3().normalized()
	var vel_abs: Vector3 = s.velocity
	var fwd_abs: Vector3 = -s.global_transform.basis.z
	game.place_ship_abs(bh.add_v3(dir * new_d), fwd_abs, vel_abs)
	print("[e2e] t=%.1f (cruise skipped: re-placed at %.0f km)" % [_gt(), new_d / 1000.0])

func _dive(game: Node, label: String, use_pulse: bool = false) -> bool:
	## hold forward + boost (optionally engage the pulse drive first, like a player crossing 400 km) until the horizon trigger fires
	entered = false
	log_levels.clear()
	pulse_lock_seen = false
	max_shake = 0.0
	min_auth = 1.0
	var shot_at := {200000.0: "200", 60000.0: "060", 30000.0: "030", 15000.0: "015", 8000.0: "008", 4000.0: "004"}
	var taken := {}
	var jumps: Array = []
	if fast:
		jumps = [[396000.0, 306000.0], [292000.0, 126000.0], [104000.0, 70000.0]]
	Input.action_press("move_forward")
	Input.action_press("sprint")
	_aim(game)
	if use_pulse:
		Input.action_press("pulse_drive")
		await game.get_tree().process_frame
		await game.get_tree().process_frame
		Input.action_release("pulse_drive")
		print("[e2e] pulse drive requested: state=%d (0 off, 1 charging, 2 active)" % int(game.ship.get("pulse_state")))
	var pulse_dropped_at := -1.0
	var pulse_was_on := false
	var t0 := Time.get_ticks_msec()
	var next_log := 0.0
	var frame_n := 0
	while not entered and (Time.get_ticks_msec() - t0) < 330000:
		await game.get_tree().process_frame
		frame_n += 1
		_sample(game)
		if frame_n % 12 == 0 and not game.warping:
			_aim(game)
		var pst := int(game.ship.get("pulse_state"))
		if pst != 0:
			pulse_was_on = true
		elif pulse_was_on and pulse_dropped_at < 0.0:
			pulse_dropped_at = _dist(game)
			print("[e2e] t=%.1f pulse drive dropped out at %.0f km (locked=%s)" % [_gt(), pulse_dropped_at / 1000.0, str(game.ship.get("pulse_locked"))])
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if el >= next_log:
			next_log = el + 4.0
			_line(game, label)
		var d := _dist(game)
		for thr in shot_at:
			if d < thr and not taken.has(thr):
				taken[thr] = true
				_shot(game, label + "_" + str(shot_at[thr]))
		for j in jumps:
			if d <= float(j[0]) and d > float(j[0]) * 0.97 and d > float(j[1]) and not taken.has(j):
				taken[j] = true
				_jump(game, float(j[1]))
				break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if use_pulse:
		print(("PASS" if pulse_was_on and pulse_dropped_at > 0.0 and pulse_dropped_at > BlackHoleParams.POINT_OF_NO_RETURN else "FAIL"), " %s: pulse drive was engaged and dropped out at %.0f km (gravity well interference)" % [label, pulse_dropped_at / 1000.0])
	return entered

## after an arrival: record the outward speed over time (the ejection must be visible, then coast down) -> [v(0.4s), v(2s), v(4s), v(7s)]
func _watch_ejection(game: Node) -> Array:
	var marks := [0.4, 2.0, 4.0, 7.0]
	var res := [-1.0, -1.0, -1.0, -1.0]
	var bh := _bh_abs()
	var t_ms := Time.get_ticks_msec()
	var game_t := 0.0
	var k := 0
	var last := Time.get_ticks_msec()
	while k < marks.size() and (Time.get_ticks_msec() - t_ms) < 40000:
		await game.get_tree().process_frame
		var now := Time.get_ticks_msec()
		game_t += minf((now - last) / 1000.0 * Engine.time_scale, 0.05)
		last = now
		_sample(game)
		if game_t >= marks[k]:
			var away: Vector3 = Frame.to_abs(game.ship.global_position).sub(bh).to_v3().normalized()
			res[k] = game.ship.velocity.dot(away)
			print("[e2e] ejection: v_out(+%.1fs) = %.0f m/s  (dist %.0f m, warping=%s)" % [marks[k], res[k], _dist(game), str(game.warping)])
			k += 1
	return res

func run(game: Node) -> void:
	t_start_ms = Time.get_ticks_msec()
	fast = _arg("fast", "1") == "1"
	_hook()
	for i in 6:
		await game.get_tree().process_frame
	var leg := _arg("leg", "both")
	var home := Universe.current_id
	var sys0 := Universe.system
	var bh0: BodyDef = sys0.bodies[sys0.black_hole_index]
	var dest: int = bh0.bh_dest_system
	print("[e2e] start: system %d (%s), BH '%s' -> system %d, ship %.0f km away, fast=%s" % [home, sys0.name, bh0.name, dest, _dist(game) / 1000.0, str(fast)])
	_shot(game, "0_start")
	# ----- leg 1 ----------------------------------------------------------------------------------------------------------------
	var ok := await _dive(game, "dive", _arg("pulse", "1") == "1")
	print(("PASS" if ok else "FAIL"), " leg1: horizon reached")
	print(("PASS" if log_levels.has(1) and log_levels.has(2) and log_levels.has(3) and log_levels.has(4) else "FAIL"), " leg1: warning levels 1,2,3,4 emitted: ", log_levels)
	print(("PASS" if pulse_lock_seen and pulse_lock_r > 100000.0 else "FAIL"), " leg1: pulse drive locked at %.0f km (danger radius %.0f km)" % [pulse_lock_r / 1000.0, BlackHoleParams.DANGER_RADIUS / 1000.0])
	print(("PASS" if max_shake > 0.9 and min_auth < 0.2 else "FAIL"), " leg1: camera shake reached %.2f, control authority faded to %.2f" % [max_shake, min_auth])
	# whiteout: sample the overlay while the transition runs
	var covered := false
	var t0 := Time.get_ticks_msec()
	while (Universe.current_id != dest or game.warping) and (Time.get_ticks_msec() - t0) < 60000:
		await game.get_tree().process_frame
		_sample(game)
		var fx = game.warp_fx
		if not covered and float(fx.get("_progress")) > 0.98 and float(fx.get("_flash")) > 0.9:
			covered = true
			_shot(game, "1_whiteout")
		if Universe.current_id == dest and game.warping and covered:
			break                              # arrived: the flash is dissolving, watch the ejection from here
	print(("PASS" if Universe.current_id == dest else "FAIL"), " leg1: arrived in system %d (%s)" % [Universe.current_id, Universe.system.name])
	print(("PASS" if covered else "FAIL"), " leg1: overlay fully covered the screen (white-out) while the systems were swapped; warp kind '%s'" % warp_started_kind)
	var sys1 := Universe.system
	var bh1: BodyDef = sys1.bodies[sys1.black_hole_index]
	var d_arr := _dist(game)
	print(("PASS" if bh1.name == "Return Gate" else "FAIL"), " leg1: destination singularity is '%s'" % bh1.name)
	print(("PASS" if absf(d_arr - BlackHoleParams.SPAWN_DISTANCE) < 8000.0 else "FAIL"), " leg1: arrival %.0f m from the Return Gate (spawn %.0f)" % [d_arr, BlackHoleParams.SPAWN_DISTANCE])
	var ej: Array = await _watch_ejection(game)
	print(("PASS" if ej[0] > 380.0 and ej[1] > 120.0 and ej[2] > 20.0 and ej[3] < 150.0 else "FAIL"), " leg1: ejected outward at ~%.0f m/s, coasting down smoothly: %s" % [BlackHoleParams.ARRIVAL_ENTRY_SPEED, str(ej)])
	_shot(game, "2_arrival")
	print("[e2e] HUD toasts so far: ", toasts)
	print("[e2e] hints so far: ", hints)
	print(("PASS" if toasts.has("Gravitational anomaly ahead  -  singularity detected") and toasts.has("POINT OF NO RETURN") and toasts.size() >= 3 else "FAIL"), " leg1: HUD toasts for caution/danger/no-return were sent")
	if leg == "1":
		return
	# ----- leg 2: ejected outward, take a look, turn around, go back through ------------------------------------------------
	for i in 30:
		await game.get_tree().process_frame
	_line(game, "ejected")
	_shot(game, "3_ejected")
	_aim(game)
	await game.get_tree().process_frame
	_line(game, "turned")
	ok = await _dive(game, "back")
	print(("PASS" if ok else "FAIL"), " leg2: horizon of the Return Gate reached")
	print(("PASS" if log_levels.has(3) and log_levels.has(4) else "FAIL"), " leg2: levels ", log_levels)
	ok = await _wait_arrival(game, home, 60.0)
	while game.warping:
		await game.get_tree().process_frame
	print(("PASS" if ok and Universe.current_id == home else "FAIL"), " leg2: back in system %d (%s)" % [Universe.current_id, Universe.system.name])
	for i in 40:
		await game.get_tree().process_frame
	_line(game, "home")
	_shot(game, "4_home")
	var ov = game.warp_fx
	print(("PASS" if not bool(ov.call("is_playing")) and not ov._rect.visible else "FAIL"), " leg2: warp overlay is gone after arrival (playing=%s rect_visible=%s)" % [str(ov.call("is_playing")), str(ov._rect.visible)])
	print(("PASS" if not game.warping and game.mode == game.Mode.SHIP else "FAIL"), " leg2: game not stuck in warp (warping=%s mode=%d)" % [str(game.warping), game.mode])
	print(("PASS" if int(ov.get("reveal_count")) == 0 else "FAIL"), " watchdog never had to rescue the screen (%d rescues)" % int(ov.get("reveal_count")))
