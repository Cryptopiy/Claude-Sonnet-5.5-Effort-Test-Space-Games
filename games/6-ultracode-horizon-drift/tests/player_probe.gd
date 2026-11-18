extends RefCounted
## prints the spawn situation of the on-foot player (sea level vs ground, collision readiness)
func run(game: Node) -> void:
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	var sites := PoiSites.for_body(planet.def)
	var g := TerrainGen.new(planet.def, sites)
	var sd := PoiSites.start_dir(planet.def)
	print("sites=", sites.size(), " site_count=", g.site_count, " has_sea=", g.has_sea, " sea=", g.sea)
	for i in mini(g.site_count, 4):
		print(" site ", i, " h=", g.site_h[i], " rad=", g.site_rad[i], " dir=", g.site_dir[i])
	print(" height(start)=", g.height(sd), " raw=", g._raw_height(sd))
	print(" planet height_at=", planet.height_at(sd))
	for k in 6:
		var a := float(k) * 0.35
		var dd := (sd + Vector3(sin(a), 0, cos(a)) * (float(k) * 6.0 / planet.radius)).normalized()
		print("  offset ", k * 6, " m: h=", g.height(dd))
