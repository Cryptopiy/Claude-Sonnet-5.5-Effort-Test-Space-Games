extends RefCounted
## Probe (M7a): compares the VISUAL terrain mesh vertices near the start pad with the analytic terrain_radius_at.
func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var start := PoiSites.start_dir(def)
	var fc: Node3D = game.freecam
	fc.global_position = start * (float(planet.call("terrain_radius_at", start)) + 4.0)
	await game.get_tree().create_timer(6.0).timeout
	var terrain: Node = planet.get_node("Terrain")
	var centre := start * float(planet.call("terrain_radius_at", start))
	var best := 0
	var worst := 0.0
	var worst_pos := Vector3.ZERO
	var count := 0
	var hist: Array = [0,0,0,0,0,0,0,0,0,0,0,0,0]
	var near_sum := 0.0
	var near_n := 0
	var meshes := 0
	var stack: Array = [terrain]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var aabb := mi.global_transform * mi.get_aabb()
		if aabb.grow(2.0).has_point(centre) == false and not aabb.grow(30.0).has_point(centre):
			continue
		meshes += 1
		var arr := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var gt := mi.global_transform
		for v in verts:
			var wp := gt * v
			if wp.distance_to(centre) < 22.0:
				var an: float = planet.call("terrain_radius_at", wp.normalized())
				var dh := wp.length() - an
				count += 1
				hist[clampi(int(floor(dh * 2.0)) + 6, 0, 12)] += 1
				if wp.distance_to(centre) < 13.0:
					near_sum += dh
					near_n += 1
				if absf(dh) > absf(worst):
					worst = dh
					worst_pos = wp
	print("[mesh] chunks near=%d verts<22m=%d worst dh=%.3f at dist %.1f" % [meshes, count, worst, worst_pos.distance_to(centre)])
	print("[mesh] hist dh in 0.5m bins from -3: ", hist, " mean dh <13m = ", near_sum / maxf(near_n, 1.0), " n=", near_n)
