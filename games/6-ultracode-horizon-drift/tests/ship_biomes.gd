extends RefCounted
## ONE-process visual check of the ship in the chase / cockpit cameras over several biomes + in space (light on the GPU: a single run, a few shots).
##   godot ... -- --autostart --preset=air:1:150 --test=res://tests/ship_biomes.gd [--bodies=1,3,4,0,6,7,2] [--wait=3.0] [--space] [--night] [--cockpit]
## Saves .previews/sb_<tag>.png

var game: Node
var ship: Ship

func _shot(tag: String) -> void:
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var img := game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/sb_%s.png" % tag)
	img.save_png(path)
	print("[sb] shot ", tag, " anchor=", Frame.anchor, " alt=%.0f" % ship.altitude, " state=", Game.tel.get("state", ""))

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await game.get_tree().process_frame
		t += game.get_process_delta_time()

func _put_air(body: int, alt: float, sun: float) -> void:
	var sys := Universe.system
	var b: BodyDef = sys.bodies[body]
	var dir := PoiSites.start_dir(b)
	Universe.time = Universe.time_for_sun_elevation(body, dir, sun, Universe.START_TIME, true)
	Frame.set_body_frame(body)
	ship.place_flying(dir, alt, 0.0)
	Frame.set_focus(ship)

func run(g: Node) -> void:
	game = g
	ship = g.ship
	var bodies: Array = [1, 3, 4, 0, 6, 7, 2]
	var wait := 3.0
	var do_space := false
	var do_night := false
	var do_cockpit := false
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--bodies="):
			bodies = []
			for x in s.substr(9).split(","):
				bodies.append(int(x))
		elif s.begins_with("--wait="):
			wait = float(s.substr(7))
		elif s == "--space":
			do_space = true
		elif s == "--night":
			do_night = true
		elif s == "--cockpit":
			do_cockpit = true
	await _wait(1.0)
	for b in bodies:
		var name_s: String = Universe.system.bodies[b].biome
		_put_air(b, 150.0, 25.0)
		await _wait(wait)
		await _shot("air_%d_%s" % [b, name_s])
		if do_cockpit and b == bodies[0]:
			ship.rig.toggle()
			await _wait(0.6)
			await _shot("cockpit_%d" % b)
			ship.rig.toggle()
	if do_night:
		_put_air(1, 150.0, -12.0)
		await _wait(wait)
		await _shot("night_1")
	if do_space:
		# 600 km out from Verdant on the sunward side, aimed at the planet
		var bp := Universe.body_pos(1)
		var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
		var side := to_star.cross(Vector3.UP).normalized()
		game.place_ship_abs(bp.add_v3(to_star * 600000.0 + side * 150000.0), -(to_star + side * 0.25).normalized())
		await _wait(2.0)
		await _shot("space_idle")
		Input.action_press("sprint")
		Input.action_press("move_forward")
		await _wait(3.0)
		await _shot("space_boost")
		Input.action_release("sprint")
		Input.action_release("move_forward")
		Input.action_press("pulse_drive")
		await game.get_tree().process_frame
		Input.action_release("pulse_drive")
		await _wait(0.8)
		await _shot("space_pulse_charge")
		await _wait(4.5)
		await _shot("space_pulse")
		print("[sb] pulse state=", ship.pulse_state, " speed=%.0f" % ship.velocity.length(), " fov=%.1f" % ship.rig.chase.fov)
	print("PASS biomes")
