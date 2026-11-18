extends RefCounted
## Probe: what is around the ship (planet children, pad node, terrain height under the ship).  godot ... -- --autostart --preset=landed --test=res://tests/ship_probe.gd

func run(game: Node) -> void:
	await game.get_tree().create_timer(5.0).timeout
	var ship: Ship = game.ship
	var pl := Frame.anchor_node() as Planet
	print("[probe] anchor=", Frame.anchor, " planet=", pl, " ship pos=", ship.global_position, " |r|=", ship.global_position.length())
	if pl != null:
		var d := ship.global_position.normalized()
		print("[probe] terrain_radius_at=", pl.terrain_radius_at(d), " sea_radius=", pl.sea_radius(), " height=", pl.height_at(d), " radius=", pl.radius)
		print("[probe] collision_ready=", pl.is_collision_ready(ship.global_position))
		for c in pl.get_children():
			print("[probe] child ", c.name, " ", c.get_class(), " children=", c.get_child_count())
		var sm := pl.get_node_or_null("ScatterManager")
		if sm != null and sm.has_method("stats"):
			print("[probe] scatter stats=", sm.call("stats"))
			var n: Node3D = sm.call("poi_node", 0)
			print("[probe] poi0 node=", n, " pos=", n.global_position if n != null else Vector3.ZERO)
	print("[probe] feet world: ", ship._foot_positions())
