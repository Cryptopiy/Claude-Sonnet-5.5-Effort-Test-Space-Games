extends RefCounted
## All landing / crash phases of ship_land.gd in ONE process (fewer GPU start-ups):  pad (Verdant, flat start pad) -> crash (Dune, no gear, 130 m/s dive) -> steep slope (Boreas).
##   godot ... -- --autostart --preset=air:1:700 --test=res://tests/ship_land_all.gd

func _put_air(game: Node, body: int, alt: float) -> void:
	var b: BodyDef = Universe.system.bodies[body]
	var dir := PoiSites.start_dir(b)
	Universe.time = Universe.time_for_sun_elevation(body, dir, 25.0, Universe.START_TIME, true)
	Frame.set_body_frame(body)
	game.ship.place_flying(dir, alt, 0.0)
	Frame.set_focus(game.ship)

func run(game: Node) -> void:
	var phases := "pad,crash,steep"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--phases="):
			phases = String(a).substr(9)
	var L = load("res://tests/ship_land.gd").new()
	L._game = game
	L._ship = game.ship
	await game.get_tree().create_timer(1.5).timeout
	if phases.contains("pad"):
		_put_air(game, 1, 700.0)
		await game.get_tree().create_timer(1.0).timeout
		await L._phase_pad()
		L._release_all()
	if phases.contains("crash"):
		_put_air(game, 3, 500.0)
		await game.get_tree().create_timer(2.5).timeout
		await L._phase_crash()
		L._release_all()
	if phases.contains("steep"):
		_put_air(game, 4, 300.0)
		await game.get_tree().create_timer(2.5).timeout
		await L._phase_steep()
		L._release_all()
