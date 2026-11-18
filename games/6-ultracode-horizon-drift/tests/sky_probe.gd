extends RefCounted
func run(game: Node) -> void:
	await game.get_tree().create_timer(3.0).timeout
	var cam := game.get_viewport().get_camera_3d()
	var pl := Frame.anchor_node()
	var def := Frame.anchor_def()
	var sd := PoiSites.start_dir(def)
	print("[probe] anchor=", Frame.anchor, " |cam|=", cam.global_position.length(), " ship=", game.ship.global_position.length())
	print("[probe] start_dir=", sd, " height_at(start)=", pl.call("height_at", sd), " sea=", pl.call("sea_radius") - def.radius)
	print("[probe] cam dir=", cam.global_position.normalized(), " dot=", cam.global_position.normalized().dot(sd))
	for a in [0.0, 5.0, 10.0, 20.0, 40.0, 80.0, 160.0, 300.0]:
		var d2: Vector3 = sd.cross(Vector3.UP).normalized()
		var dd: Vector3 = (sd + d2 * a / def.radius).normalized()
		print("[probe] +", a, " m: h=", pl.call("height_at", dd))
