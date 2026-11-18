extends RefCounted
func run(game: Node) -> void:
	var g := game
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	await g.get_tree().create_timer(1.0).timeout
	var d := Vector3(0, -1, 0)
	var gr := planet.terrain_radius_at(d)
	print("[tp] before pos=", p.global_position, " anchor=", Frame.anchor, " focus=", Frame.focus)
	p.spawn_at(d * (gr + 3.0), d, d.cross(Vector3.RIGHT))
	print("[tp] after spawn_at pos=", p.global_position)
	for i in 12:
		await g.get_tree().process_frame
		print("[tp] f=", i, " pos=", p.global_position, " anchor=", Frame.anchor, " parent=", p.get_parent().name)
