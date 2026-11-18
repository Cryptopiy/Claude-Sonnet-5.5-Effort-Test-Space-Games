extends RefCounted
## Mechanics test (scripted input).  --test=res://tests/bh_fly.gd -- --autostart --preset=bh:300 --timescale=4 --scenario=dive|escape|trap|pulse --shots=.previews/f
##   dive   : hold forward+boost straight into the hole, verify warning levels 1..4, pulse lock, transition to the other system, arrival
##            near its singularity (SPAWN_DISTANCE, moving away), then fly back through the destination singularity to the home system.
##   escape : start 45 km from the hole moving inwards, thrust away: must get out.
##   trap   : start 17 km from the hole (inside the point of no return), thrust away at full boost: must still be captured.
##   pulse  : engage the pulse drive (X) 600 km out, aimed at the hole: pulse must be locked at the danger radius and the ship must be captured.
## The ship used here must honour external_accel / control_authority / pulse_locked / extra_shake (see ARCHITECTURE section 5).

var levels: Array = []
var entered := false
var warped := false
var max_shake := 0.0
var min_auth := 1.0
var pulse_lock_seen := false

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func _on_warning(level: int, dist: float) -> void:
	if levels.is_empty() or levels[-1] != level:
		levels.append(level)
		print("[bh_fly] warning level -> %d at %.0f m" % [level, dist])

func _bh_abs() -> DVec:
	return Universe.body_pos(Universe.system.black_hole_index)

func _dist(game: Node) -> float:
	return _bh_abs().distance_to(Frame.to_abs(game.ship.global_position))

func _face_bh(game: Node) -> void:
	var bh_local := Frame.to_local(_bh_abs())
	game.ship.look_at(bh_local, Vector3.UP)

func _sample(game: Node) -> void:
	var s = game.ship
	max_shake = maxf(max_shake, float(s.get("extra_shake")))
	min_auth = minf(min_auth, float(s.get("control_authority")))
	if bool(s.get("pulse_locked")):
		pulse_lock_seen = true

func _wait_system(game: Node, sys: int, timeout_s: float, label: String) -> bool:
	var t0 := Time.get_ticks_msec()
	var next_print := 0.0
	while Universe.current_id != sys or game.warping:
		await game.get_tree().process_frame
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if el > next_print and game.ship != null and not game.warping:
			next_print = el + 3.0
			print("[bh_fly] %s t=%.0fs  dist=%.0f m  speed=%.0f m/s  level=%d" % [label, el, _dist(game), game.ship.velocity.length(), int(game.tel.get("bh_level", -1))])
		if el > timeout_s:
			return false
	return true

func _overlay_clear(game: Node) -> bool:
	var fx = game.warp_fx
	if fx == null:
		return true
	var rect: ColorRect = fx.get("_rect")
	return not fx.is_playing() and (rect == null or not rect.visible)

func run(game: Node) -> void:
	Events.notify.connect(func(text: String, kind: String): print("[bh_fly][HUD toast/", kind, "] ", text))
	Events.hint.connect(func(text: String, secs: float): print("[bh_fly][HUD hint] ", text))
	Events.screen_flash.connect(func(c: Color, d: float): print("[bh_fly][flash] ", c, " ", d))
	Events.warp_started.connect(func(id: int, kind: String): print("[bh_fly] warp_started -> system ", id, " kind=", kind))
	Events.blackhole_warning.connect(_on_warning)
	Events.blackhole_entered.connect(func(): entered = true)
	Events.warp_finished.connect(func(_id): warped = true)
	var scenario := _arg("scenario", "dive")
	var home := Universe.current_id
	var ship = game.ship
	match scenario:
		"dive":
			await _dive(game, home)
		"escape":
			await _escape(game, 45000.0, true)
		"trap":
			await _escape(game, 17000.0, false)
		"escape+trap":
			await _escape(game, 45000.0, true)
			entered = false
			await _escape(game, 17000.0, false)
		"pulse":
			await _pulse(game, home)
		"arrive":
			await _arrive_and_return(game, home)

func _dive(game: Node, home: int) -> void:
	var dest: int = Universe.system.bodies[Universe.system.black_hole_index].bh_dest_system
	_face_bh(game)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var shot := _arg("shots", "")
	var shots_taken := {}
	var t0 := Time.get_ticks_msec()
	var ok_time := false
	while not entered and (Time.get_ticks_msec() - t0) < 180000:
		await game.get_tree().process_frame
		_sample(game)
		var d := _dist(game)
		if shot != "":
			for thr in [200000.0, 60000.0, 30000.0, 15000.0, 8000.0, 4000.0]:
				if d < thr and not shots_taken.has(thr):
					shots_taken[thr] = true
					var img: Image = game.get_viewport().get_texture().get_image()
					var full := ProjectSettings.globalize_path("res://%s_%d.png" % [shot, int(thr / 1000.0)])
					DirAccess.make_dir_recursive_absolute(full.get_base_dir())
					img.save_png(full)
					print("[bh_fly] shot at %.0f m -> %s" % [d, full])
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print(("PASS" if entered else "FAIL"), " dive: horizon reached (blackhole_entered), levels seen: ", levels)
	print(("PASS" if levels.has(1) and levels.has(2) and levels.has(3) and levels.has(4) else "FAIL"), " dive: all warning levels 1-4 emitted")
	print(("PASS" if pulse_lock_seen else "FAIL"), " dive: pulse_locked set inside the danger zone; max shake=%.2f min authority=%.2f" % [max_shake, min_auth])
	var arrived := await _wait_system(game, dest, 40.0, "transit")
	while game.warping:
		await game.get_tree().process_frame
	print(("PASS" if arrived and Universe.current_id == dest else "FAIL"), " dive: arrived in system %d (wanted %d)" % [Universe.current_id, dest])
	print(("PASS" if _overlay_clear(game) and not game.warping else "FAIL"), " dive: warp overlay released after arrival (not stuck covered), mode=%d" % game.mode)
	for i in 30:
		await game.get_tree().process_frame
	var d_arr := _dist(game)
	var vel_ok: bool = game.ship.velocity.length() > 300.0
	print(("PASS" if absf(d_arr - BlackHoleParams.SPAWN_DISTANCE) < 12000.0 else "FAIL"), " dive: arrival distance %.0f m from the destination singularity (spawn %.0f), speed %.0f m/s moving away: %s" % [d_arr, BlackHoleParams.SPAWN_DISTANCE, game.ship.velocity.length(), str(vel_ok)])
	print("[bh_fly] ship fields after arrival: external_accel=", game.ship.external_accel, " authority=", game.ship.control_authority, " pulse_locked=", game.ship.pulse_locked)
	# ---- return trip: turn around and fly through the destination singularity ----------------------------------------------
	levels.clear()
	entered = false
	warped = false
	await game.get_tree().create_timer(2.0).timeout
	_face_bh(game)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	t0 = Time.get_ticks_msec()
	while not entered and (Time.get_ticks_msec() - t0) < 240000:
		await game.get_tree().process_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print(("PASS" if entered else "FAIL"), " return: horizon reached, levels ", levels)
	var back := await _wait_system(game, home, 40.0, "return")
	while game.warping:
		await game.get_tree().process_frame
	print(("PASS" if back and Universe.current_id == home else "FAIL"), " return: back in system %d" % Universe.current_id)
	print(("PASS" if _overlay_clear(game) and not game.warping else "FAIL"), " return: warp overlay released after arrival")

func _escape(game: Node, start_m: float, expect_escape: bool) -> void:
	var bhp := _bh_abs()
	var to_star := Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
	var start := bhp.add_v3(to_star * start_m)
	game.place_ship_abs(start, to_star, -to_star * 300.0)     # moving inwards at 300 m/s, facing away from the hole
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t0 := Time.get_ticks_msec()
	var best := start_m
	var worst := start_m
	var res := ""
	while (Time.get_ticks_msec() - t0) < 90000:
		await game.get_tree().process_frame
		if entered or game.warping:
			res = "captured"
			break
		var d := _dist(game)
		best = maxf(best, d)
		worst = minf(worst, d)
		if d > 160000.0:
			res = "escaped"
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var want := "escaped" if expect_escape else "captured"
	print(("PASS" if res == want else "FAIL"), " %s: start %.0f km -> %s (wanted %s), closest %.0f km, farthest %.0f km, levels %s" % [("escape" if expect_escape else "trap"), start_m / 1000.0, res, want, worst / 1000.0, best / 1000.0, str(levels)])

func _pulse(game: Node, home: int) -> void:
	_face_bh(game)
	var t0 := Time.get_ticks_msec()
	Input.action_press("pulse_drive")
	await game.get_tree().create_timer(0.2).timeout
	Input.action_release("pulse_drive")
	while not entered and (Time.get_ticks_msec() - t0) < 120000:
		await game.get_tree().process_frame
		_sample(game)
	print(("PASS" if pulse_lock_seen else "FAIL"), " pulse: pulse_locked was set; entered=", entered, " levels=", levels)

func _dbg_line(game: Node, tag: String) -> void:
	var s = game.ship
	var bhp := _bh_abs()
	var bh_local := Frame.to_local(bhp)
	var to_bh: Vector3 = (bh_local - s.global_position)
	var dir := to_bh.normalized()
	var fwd: Vector3 = -s.global_transform.basis.z
	print("[bh_fly][%s] r=%.0f v_in=%.0f |v|=%.0f heading.dir=%.2f auth=%.2f lock=%s acc=%.1f pulse=%s assist=%s level=%d anchor=%d" % [tag, to_bh.length(), s.velocity.dot(dir), s.velocity.length(), fwd.dot(dir), s.control_authority, str(s.pulse_locked), s.external_accel.length(), str(s.get("pulse_state")), str(s.get("_assist")), int(game.tel.get("bh_level", -1)), Frame.anchor])

## warp through the hole, wait for arrival, turn around, dive back in while logging the ship state
func _arrive_and_return(game: Node, home: int) -> void:
	var dest: int = Universe.system.bodies[Universe.system.black_hole_index].bh_dest_system
	game.warp_to_system(dest, "blackhole")
	while not game.warping:
		await game.get_tree().process_frame
	while game.warping:
		await game.get_tree().process_frame
	print("[bh_fly] arrived in system ", Universe.current_id)
	await game.get_tree().create_timer(2.0).timeout
	_face_bh(game)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t0 := Time.get_ticks_msec()
	var next_log := 0.0
	while not entered and (Time.get_ticks_msec() - t0) < 150000:
		await game.get_tree().process_frame
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if el > next_log:
			next_log = el + 2.0
			_dbg_line(game, "ret")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print(("PASS" if entered else "FAIL"), " arrive/return: horizon reached, levels ", levels)
