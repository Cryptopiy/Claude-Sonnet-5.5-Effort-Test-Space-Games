extends RefCounted
## prints the start state of the on-foot player: terrain, sea, ship, player.
func run(game: Node) -> void:
	await game.get_tree().create_timer(0.5).timeout
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	var d := p.global_position.normalized()
	print("[start] script=", planet.get_script().resource_path, " radius=", planet.radius, " water_level=", planet.water_level, " sea_r=", planet.sea_radius(), " terrain_r=", planet.terrain_radius_at(d))
	var sd := PoiSites.start_dir(planet.def)
	print("[start] start_dir=", sd, " player dir=", d, " dot=", sd.dot(d), " h(start)=", planet.height_at(sd))
	var gen = planet.get("gen")
	print("[start] gen=", gen)
	if gen != null:
		print("[start] sites=", gen.site_count, " site_h=", gen.site_h, " site_rad=", gen.site_rad, " sea=", gen.sea, " has_sea=", gen.has_sea)
	for s in PoiSites.for_body(planet.def):
		print("[start] poi ", s.get("kind"), " flat=", s.get("flat"), " rad=", s.get("radius"), " h=", planet.height_at(s["dir"]))
