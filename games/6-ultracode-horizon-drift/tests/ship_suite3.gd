extends RefCounted
## camera shots (chase / cockpit) -> atmospheric entry dive (heat shell + screen heat) -> gas-giant pressure barrier, in ONE process.
##   godot ... -- --autostart --preset=air:1:150 --cp=0,0.3,0.4 --test=res://tests/ship_suite3.gd

func _put_air(game: Node, body: int, alt: float, sun: float = 25.0) -> void:
	var b: BodyDef = Universe.system.bodies[body]
	var dir := PoiSites.start_dir(b)
	Universe.time = Universe.time_for_sun_elevation(body, dir, sun, Universe.START_TIME, true)
	Frame.set_body_frame(body)
	game.ship.place_flying(dir, alt, 0.0)
	Frame.set_focus(game.ship)

func run(game: Node) -> void:
	var C = load("res://tests/ship_cam.gd").new()
	await C.run(game)
	var E = load("res://tests/ship_entry.gd").new()
	_put_air(game, 1, 4600.0)
	await game.get_tree().create_timer(1.5).timeout
	await E.run(game)
	var G = load("res://tests/ship_gas.gd").new()
	_put_air(game, 5, 6000.0)
	await game.get_tree().create_timer(2.0).timeout
	await G.run(game)
