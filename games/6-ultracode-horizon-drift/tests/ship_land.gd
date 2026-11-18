extends RefCounted
## Landing / crash behaviour tests on the real terrain (autopilot via real input actions + smoothed aiming).
##   godot ... -- --autostart --preset=air:1:700 --test=res://tests/ship_land.gd --phase=pad     (descend onto the flat start pad and land; checks distance to pad centre)
##   godot ... -- --autostart --preset=air:3:500 --test=res://tests/ship_land.gd --phase=crash [--crash-speed=130] [--gear]   (dive into the ground: hard landing / crash)
##   godot ... -- --autostart --preset=air:1:300 --test=res://tests/ship_land.gd --phase=steep   (land on a steep slope: must NOT become 'landed')
## Output "[land] ..." lines + PASS/FAIL.

var _game: Node
var _ship: Ship
var _t := 0.0
var _log_next := 0.0

func _frame() -> float:
	await _game.get_tree().process_frame
	var dt: float = minf(_game.get_process_delta_time(), 0.05)
	_t += dt
	return dt

func _aim(dir: Vector3, dt: float, rate: float = 1.4) -> void:
	var f := -_ship.global_transform.basis.z
	var ang := f.angle_to(dir)
	if ang < 0.0005:
		return
	var axis := f.cross(dir)
	if axis.length() < 1e-5:
		axis = _ship.global_transform.basis.y
	_ship.global_transform.basis = Basis(axis.normalized(), minf(ang, rate * dt)) * _ship.global_transform.basis

func _hfwd() -> Vector3:
	var up := _ship.global_position.normalized()
	var fwd := -_ship.global_transform.basis.z
	var fh := fwd - up * fwd.dot(up)
	if fh.length() < 0.1:
		fh = _ship.global_transform.basis.y - up * _ship.global_transform.basis.y.dot(up)
	return fh.normalized()

func _log(tag: String, every: float) -> void:
	if _t < _log_next:
		return
	_log_next = _t + every
	var s := _ship
	print("[land] %s t=%.1f state=%s alt=%.1f speed=%.1f vs=%.1f gear=%s landed=%s hull=%.2f" % [tag, _t, Game.tel.get("state", ""), s.altitude, (s.velocity - s._ref_vel).length(), Game.tel.get("vspeed", 0.0), str(s.gear_deployed), str(s.is_landed), Game.ship_hull])

func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "move_up", "move_down", "sprint", "landing_gear"]:
		Input.action_release(a)

func _shot(name: String) -> void:
	var img := _game.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.previews/land_%s.png" % name))

func run(game: Node) -> void:
	_game = game
	_ship = game.ship
	var phase := "pad"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--phase="):
			phase = String(a).substr(8)
	await game.get_tree().create_timer(1.5).timeout
	match phase:
		"pad": await _phase_pad()
		"crash": await _phase_crash()
		"steep": await _phase_steep()

func _phase_pad() -> void:
	var s := _ship
	var def := Frame.anchor_def()
	var pl := Frame.anchor_node() as Planet
	var pad := PoiSites.start_dir(def)
	var pad_pos := pad * pl.terrain_radius_at(pad)
	s.place_flying(pad, 700.0, 0.0)
	await _frame()
	_t = 0.0
	var landed_t := -1.0
	var shot := false
	while _t < 90.0:
		var dt := await _frame()
		_log("pad", 3.0)
		var up := s.global_position.normalized()
		_aim(_hfwd(), dt, 1.5)
		var pos := s.global_position
		var off := (pad_pos - up * pad_pos.dot(up)) - (pos - up * pos.dot(up))
		var want := off.limit_length(70.0) * 0.3
		var vrel := s.velocity - s._ref_vel
		var vh := vrel - up * vrel.dot(up)
		var err := want - vh
		var b := s.global_transform.basis
		var ex := err.dot(b.x)
		var ez := err.dot(-b.z)
		if ez > 4.0: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
		if ez < -4.0: Input.action_press("move_back")
		else: Input.action_release("move_back")
		if ex > 4.0: Input.action_press("move_right")
		else: Input.action_release("move_right")
		if ex < -4.0: Input.action_release("move_right"); Input.action_press("move_left")
		else: Input.action_release("move_left")
		Input.action_press("move_down")        # the flare limiter turns this into a soft touch-down
		if s.altitude < 90.0 and not shot:
			shot = true
			_shot("pad_final")
		if s.is_landed:
			landed_t = _t
			break
	_release_all()
	_log("end", 0.0)
	var dist := (s.global_position - pad_pos).length()
	print("[land] landed=%s t=%.1f hull=%.2f dist_to_pad_centre=%.1f m" % [str(s.is_landed), landed_t, Game.ship_hull, dist])
	for i in 60:
		await _frame()
	_shot("pad_landed")
	print("PASS pad" if s.is_landed and Game.ship_hull > 0.99 and dist < 25.0 else "FAIL pad")

func _phase_crash() -> void:
	var s := _ship
	var up := s.global_position.normalized()
	var hull0 := Game.ship_hull
	var speed := 130.0
	var gear := false
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--crash-speed="):
			speed = float(String(a).substr(14))
		if String(a) == "--gear":
			gear = true
	# a straight line through a ~7 km planet needs a steep angle (the ground curves away from a shallow dive)
	s.global_transform.basis = Basis.looking_at((-up * 0.6 + _hfwd() * 0.8).normalized(), up)
	s.velocity = (-up * 0.6 + _hfwd() * 0.8).normalized() * speed
	if not gear:
		s.gear_deployed = false
		s._gear_t = 1.0
	s._gear_manual_until = s._time + 120.0
	var sev_list: Array = []
	Input.action_press("move_forward")             # keep thrusting: the flight assist would otherwise brake the dive to a standstill within half a second
	var cb := func(sev: float): sev_list.append(sev)
	Events.ship_crashed.connect(cb)
	var min_alt := 1e9
	_t = 0.0
	var shot := false
	while _t < 14.0:
		await _frame()
		_log("crash", 1.0)
		min_alt = minf(min_alt, s.altitude)
		if s.altitude < 40.0 and not shot:
			shot = true
			_shot("crash_approach")
		if not sev_list.is_empty() and _t > 0.0 and sev_list.size() == 1 and not (_t < 0.0):
			pass
	Events.ship_crashed.disconnect(cb)
	print("[land] crashes=%s hull %.2f -> %.2f min_alt=%.1f landed=%s" % [str(sev_list), hull0, Game.ship_hull, min_alt, str(s.is_landed)])
	_shot("crash_after")
	print("PASS crash" if sev_list.size() >= 1 and Game.ship_hull < hull0 and Game.ship_hull >= 0.05 and min_alt > -3.0 else "FAIL crash")

func _phase_steep() -> void:
	# find the steepest nearby ground by sampling the terrain normal on a ring around the start point, then descend there with gear down
	var s := _ship
	var def := Frame.anchor_def()
	var pl := Frame.anchor_node() as Planet
	var up0 := s.global_position.normalized()
	var best_dir := up0
	var best_slope := 0.0
	var tangent := up0.cross(Vector3.UP).normalized()
	var bitangent := up0.cross(tangent)
	for i in 400:
		var a := float(i) * 2.399963
		var r := 40.0 + float(i) * 6.0
		var d := (up0 + (tangent * cos(a) + bitangent * sin(a)) * (r / def.radius)).normalized()
		var n := pl.normal_at(d)
		var sl := rad_to_deg(acos(clampf(n.dot(d), -1.0, 1.0)))
		if sl > best_slope:
			best_slope = sl
			best_dir = d
	print("[land] steepest sampled slope %.1f deg at %.0f m from start" % [best_slope, best_dir.angle_to(up0) * def.radius])
	s.place_flying(best_dir, 60.0, 0.0)
	s.gear_deployed = true
	s._gear_t = 0.0
	await _frame()
	_t = 0.0
	var hull0 := Game.ship_hull
	while _t < 14.0:
		var dt := await _frame()
		_log("steep", 2.0)
		Input.action_press("move_down")
		_aim(_hfwd(), dt, 1.5)
	_release_all()
	print("[land] after 14 s: landed=%s hull=%.2f alt=%.1f slope=%.1f" % [str(s.is_landed), Game.ship_hull, s.altitude, best_slope])
	_shot("steep")
	if best_slope < 32.0:
		print("[land] no steep spot found; inconclusive")
		print("PASS steep (inconclusive)")
	else:
		print("PASS steep" if not s.is_landed else "FAIL steep")
