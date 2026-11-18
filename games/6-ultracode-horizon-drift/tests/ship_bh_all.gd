extends RefCounted
## Black-hole contract end-to-end with the real ship + real BlackHole (m5), in ONE process:
##   1. dive: hold forward+boost from 150 km straight into the hole; sample external_accel / control_authority / pulse_locked / extra_shake / camera shake / FOV
##   2. arrival in the other system (ejected outward), contract fields cleaned up, ship flies normally
##   3. escape from 30 km (moving inwards, thrusting away) must succeed;  trap at 17 km (inside the point of no return) must still be captured
##   godot ... -- --autostart --preset=bh:150 --test=res://tests/ship_bh_all.gd [--shots=.previews/bh_m3]

var B
var game: Node
var ship: Ship
var ok := true

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func _check(label: String, cond: bool, extra: String = "") -> void:
	print(("PASS " if cond else "FAIL ") + "bh_m3: " + label + ("  " + extra if extra != "" else ""))
	ok = ok and cond

func _shot(tag: String) -> void:
	var base := _arg("shots", "")
	if base == "":
		return
	var full := ProjectSettings.globalize_path("res://%s_%s.png" % [base, tag])
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	game.get_viewport().get_texture().get_image().save_png(full)

func run(g: Node) -> void:
	game = g
	ship = g.ship
	B = load("res://tests/bh_fly.gd").new()
	Events.blackhole_warning.connect(B._on_warning)
	Events.blackhole_entered.connect(func(): B.entered = true)
	Events.notify.connect(func(text: String, kind: String): print("[bh_m3][toast/", kind, "] ", text))
	Events.hint.connect(func(text: String, _s: float): print("[bh_m3][hint] ", text))
	var dest: int = Universe.system.bodies[Universe.system.black_hole_index].bh_dest_system
	var home := Universe.current_id
	await game.get_tree().create_timer(1.0).timeout
	B._face_bh(game)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t0 := Time.get_ticks_msec()
	var next := 0.0
	var max_acc := 0.0
	var max_shake_cam := 0.0
	var min_auth := 1.0
	var lock_r := 0.0
	var pulse_refused := false
	var shots := {}
	var fov_max := 0.0
	var sw_hull := Game.ship_hull
	while not B.entered and (Time.get_ticks_msec() - t0) < 200000:
		await game.get_tree().process_frame
		var d: float = B._dist(game)
		max_acc = maxf(max_acc, ship.external_accel.length())
		min_auth = minf(min_auth, ship.control_authority)
		max_shake_cam = maxf(max_shake_cam, ship.rig.base_shake)
		fov_max = maxf(fov_max, ship.rig.chase.fov)
		if ship.pulse_locked and lock_r <= 0.0:
			lock_r = d
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if el >= next:
			next = el + 4.0
			print("[bh_m3] t=%.0fs r=%.0f speed=%.0f acc=%.1f auth=%.2f lock=%s shake=%.2f camshake=%.2f fov=%.1f state=%s level=%d" % [el, d, ship.velocity.length(), ship.external_accel.length(), ship.control_authority, str(ship.pulse_locked), ship.extra_shake, ship.rig.base_shake, ship.rig.chase.fov, str(Game.tel.get("state", "")), int(Game.tel.get("bh_level", -1))])
		for thr in [100000.0, 40000.0, 15000.0, 6000.0]:
			if d < thr and not shots.has(thr):
				shots[thr] = true
				_shot("r%d" % int(thr / 1000.0))
		# pulse drive must be refused inside the danger zone
		if d < 100000.0 and not pulse_refused:
			pulse_refused = true
			var was := ship.pulse_state
			Input.action_press("pulse_drive")
			await game.get_tree().process_frame
			await game.get_tree().process_frame
			Input.action_release("pulse_drive")
			_check("pulse drive refused inside the danger zone (r=%.0f km)" % (d / 1000.0), ship.pulse_state == Ship.Pulse.OFF and was == Ship.Pulse.OFF)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("horizon reached", B.entered, "levels=%s" % str(B.levels))
	_check("external_accel applied (max %.1f m/s^2)" % max_acc, max_acc > 100.0)
	_check("control_authority faded (min %.2f)" % min_auth, min_auth < 0.5)
	_check("pulse_locked set at r=%.0f km" % (lock_r / 1000.0), lock_r > 0.0 and lock_r < 130000.0)
	_check("extra_shake reaches camera (%.2f)" % max_shake_cam, max_shake_cam > 0.5)
	# ---- arrival ------------------------------------------------------------------------------------------------------------
	var arrived: bool = await B._wait_system(game, dest, 40.0, "transit")
	while game.warping:
		await game.get_tree().process_frame
	_check("arrived in system %d" % dest, arrived and Universe.current_id == dest)
	await game.get_tree().create_timer(2.0).timeout
	var d_arr: float = B._dist(game)
	_check("arrival: ejected outward at speed (%.0f m/s, %.0f km from the singularity)" % [ship.velocity.length(), d_arr / 1000.0], ship.velocity.length() > 300.0 and not ship.is_landed and ship.piloted)
	_shot("arrival")
	# ---- escape / trap ----------------------------------------------------------------------------------------------------
	B.levels.clear()
	B.entered = false
	var bhp: DVec = B._bh_abs()
	var to_star := Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
	game.place_ship_abs(bhp.add_v3(to_star * 30000.0), to_star, -to_star * 300.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	t0 = Time.get_ticks_msec()
	var res := ""
	var closest := 30000.0
	while (Time.get_ticks_msec() - t0) < 80000:
		await game.get_tree().process_frame
		if B.entered or game.warping:
			res = "captured"
			break
		var d2: float = B._dist(game)
		closest = minf(closest, d2)
		if d2 > 70000.0:
			res = "escaped"
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("escape from 30 km moving inward (closest %.1f km): %s" % [closest / 1000.0, res], res == "escaped")
	# trap: 17 km, inside the point of no return
	B.entered = false
	bhp = B._bh_abs()
	to_star = Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
	game.place_ship_abs(bhp.add_v3(to_star * 17000.0), to_star, Vector3.ZERO)
	await game.get_tree().create_timer(0.3).timeout
	Input.action_press("move_forward")
	Input.action_press("sprint")
	t0 = Time.get_ticks_msec()
	res = ""
	while (Time.get_ticks_msec() - t0) < 60000:
		await game.get_tree().process_frame
		if B.entered or game.warping:
			res = "captured"
			break
		if B._dist(game) > 40000.0:
			res = "escaped"
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("trap inside the point of no return: %s" % res, res == "captured")
	while game.warping:
		await game.get_tree().process_frame
	await game.get_tree().create_timer(1.5).timeout
	_check("after the second transit the contract fields are clean", ship.external_accel.length() < 0.5 and ship.control_authority > 0.99 and not ship.pulse_locked and ship.extra_shake < 0.01, "acc=%.2f auth=%.2f" % [ship.external_accel.length(), ship.control_authority])
	print("PASS bh_m3" if ok else "FAIL bh_m3")
