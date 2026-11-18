extends RefCounted
## crash phase + hyperdrive test in ONE process:  godot ... -- --autostart --preset=air:3:500 --phases=crash --test=res://tests/ship_suite.gd
func run(game: Node) -> void:
	var A = load("res://tests/ship_land_all.gd").new()
	await A.run(game)
	var H = load("res://tests/ship_hyper.gd").new()
	await H.run(game)
