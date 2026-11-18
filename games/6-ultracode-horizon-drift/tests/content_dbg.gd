extends RefCounted
func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	print("planet=", planet, " script=", planet.get_script().resource_path if planet.get_script() else "none")
	var gen = planet.gen
	print("gen=", gen)
	print("site_count=", gen.site_count, " has_sea=", gen.has_sea, " sea=", gen.sea)
	for i in gen.site_count:
		print(i, " dir=", gen.site_dir[i], " rad=", gen.site_rad[i], " h=", gen.site_h[i])
	var d: Vector3 = PoiSites.start_dir(def)
	print("start dir=", d, " height=", gen.height(d), " raw=", gen._raw_height(d), " boost=", gen._site_boost(d))
	print("height_at=", planet.call("height_at", d), " terrain_r-R=", float(planet.call("terrain_radius_at", d)) - def.radius)
