extends RefCounted
## Content probe (M7a): terrain height vs the landing pad / ground profile around the start pad.
func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var R := def.radius
	var start := PoiSites.start_dir(def)
	await game.get_tree().create_timer(4.0).timeout
	var h0: float = planet.call("terrain_radius_at", start)
	print("[pad] centre r=%.3f (h=%.3f)" % [h0, h0 - R])
	for ang in [0.0, 1.57, 3.14, 4.71]:
		var s := ""
		for dist in [3.0, 6.0, 9.0, 12.0, 16.0, 24.0, 32.0, 48.0, 80.0]:
			var d := ScatterGrid.walk(start, ang, dist, R)
			s += " %d:%.2f" % [int(dist), float(planet.call("terrain_radius_at", d)) - h0]
		print("[pad] ang=%.2f dh:%s" % [ang, s])
	# real collision / mesh check: raycast down at a few points
	var space := (planet as Node3D).get_world_3d().direct_space_state
	planet.call("set_collision_focus", start * h0, 120.0)
	await game.get_tree().create_timer(2.0).timeout
	for dist in [0.0, 6.0, 12.0, 20.0, 40.0]:
		var d2 := ScatterGrid.walk(start, 0.3, dist, R)
		var top := d2 * (h0 + 30.0)
		var q := PhysicsRayQueryParameters3D.create(top, d2 * (h0 - 30.0), 1)
		var hit := space.intersect_ray(q)
		var an := float(planet.call("terrain_radius_at", d2))
		print("[pad] ray d=%.0f hit=%s analytic=%.3f" % [dist, ("%.3f" % (hit["position"] as Vector3).length()) if not hit.is_empty() else "none", an])
	# the pad node
	var sm: Node = planet.get_node_or_null("ScatterManager")
	var pn: Node3D = sm.call("poi_node", 0) if sm != null else null
	print("[pad] pad node=", pn, " pos_r=", pn.global_position.length() if pn != null else -1.0)
