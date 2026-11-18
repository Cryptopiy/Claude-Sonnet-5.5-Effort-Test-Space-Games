extends RefCounted
var g: Node
func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout
func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	await _wait(1.0)
	var d := Vector3(0.696526, -0.597022, 0.398015).normalized()
	var gr := planet.terrain_radius_at(d)
	print("[p3] gr=", gr, " sea=", planet.sea_radius(), " planets in tree: ", g.get_tree().get_nodes_in_group("planet").size())
	p.spawn_at(d * (gr + 3.0), d, d.cross(Vector3.UP))
	for i in 10:
		await _wait(0.5)
		var now := Time.get_ticks_msec() / 1000.0
		print("[p3] t=%.1f alt=%.2f ready=%s busy=%s col_dir=%s want_dir=%s half=%.1f want_r=%.1f since_focus=%.2f off=%.1f" % [0.5 * (i + 1), float(Game.tel.get("altitude", 0.0)), str(planet.is_collision_ready(p.global_position)), str(planet._col_busy), str(planet._col_dir), str(planet._col_want_p.normalized()), planet._col_half, planet._col_want_r, now - planet._col_want_time, (planet._col_want_p.normalized() - planet._col_dir).length() * planet.radius])
