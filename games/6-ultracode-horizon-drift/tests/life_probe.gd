extends RefCounted
func run(game: Node) -> void:
	await game.get_tree().create_timer(1.0).timeout
	var pl := Frame.anchor_node() as Planet
	var def := Frame.anchor_def()
	var sd := PoiSites.start_dir(def)
	print("[probe] def.radius=", def.radius, " pl.radius=", pl.radius, " water_level=", pl.water_level, " sea_radius=", pl.sea_radius())
	print("[probe] start h=", pl.height_at(sd), " terrain_r=", pl.terrain_radius_at(sd), " normal.dot=", pl.normal_at(sd).dot(sd))
	var n_land := 0
	var n := 0
	for i in 400:
		var d := SeedUtil.rand_dir(1234, i)
		n += 1
		if pl.height_at(d) > pl.water_level:
			n_land += 1
	print("[probe] land fraction=", float(n_land) / float(n))
	for k in 6:
		var ang := float(k) * 1.0
		var best := -999.0
		print("[probe] h@start+", k, "=", pl.height_at((sd + Vector3(0.02 * k, 0, 0)).normalized()))
	var fp := Frame.focus.global_position
	print("[probe] focus r=", fp.length(), " dir.dot(start)=", fp.normalized().dot(sd))
