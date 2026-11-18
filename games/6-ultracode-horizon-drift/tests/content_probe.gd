extends RefCounted
## Content probe (M7a): terrain/sea height at every POI of the anchored body, ground clutter near the start pad, interactable census.

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var R := def.radius
	var sea: float = planet.call("sea_radius")
	print("[probe] body=%s biome=%s R=%.0f sea_radius=%.2f water_level=%.2f" % [def.name, def.biome, R, sea, float(planet.get("water_level"))])
	var pois := PoiSites.for_body(def)
	var under := 0
	for i in pois.size():
		var p: Dictionary = pois[i]
		var d: Vector3 = p["dir"]
		var h: float = planet.call("terrain_radius_at", d) - R
		var rel := h - (sea - R if sea > 0.0 else -1.0e9)
		var dist := ScatterGrid.ground_dist(pois[0]["dir"], d, R)
		print("[probe] poi %2d %-10s %-18s dist_from_pad=%6.0f h=%7.2f above_sea=%7.2f flat=%s r=%.0f" % [i, p["kind"], p["name"], dist, h, rel if sea > 0.0 else 999.0, str(p["flat"]), float(p["radius"])])
		if sea > 0.0 and rel < 0.3 and p["kind"] != "landing_pad":
			under += 1
	print("[probe] pois_underwater=%d" % under)
	await game.get_tree().create_timer(3.0).timeout
	var sm: ScatterManager = planet.get_node_or_null("ScatterManager")
	print("[probe] stats=", sm.stats() if sm != null else "no scatter")
	var inter := game.get_tree().get_nodes_in_group("interactable")
	print("[probe] interactables=", inter.size())
	for n in inter:
		print("   ", n.name, " ", n.get_class(), " prompt=", n.call("get_prompt") if n.has_method("get_prompt") else "?")
