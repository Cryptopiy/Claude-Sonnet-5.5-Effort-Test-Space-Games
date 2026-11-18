extends RefCounted
## Collision patch test: --preset=freecam:<body>:50 --test=res://tests/terrain_collision.gd
## Walks a focus point along the ground, waits for the patch, raycasts down onto layer 1 and compares with terrain_radius_at.
func run(game: Node) -> void:
	var pl := Frame.anchor_node() as Planet
	var b: BodyDef = Universe.system.bodies[Frame.anchor]
	var dir := PoiSites.start_dir(b)
	var east := dir.cross(Vector3.UP).normalized()
	var north := east.cross(dir).normalized()
	var space := pl.get_world_3d().direct_space_state
	var worst := 0.0
	var fails := 0
	var waits: Array = []
	for step in 12:
		var d := (dir * b.radius + north * float(step) * 14.0 + east * float(step) * 5.0).normalized()
		var p := d * pl.terrain_radius_at(d)
		pl.set_collision_focus(p, 60.0)
		var t0 := Time.get_ticks_msec()
		while not pl.is_collision_ready(p) and Time.get_ticks_msec() - t0 < 5000:
			pl.set_collision_focus(p, 60.0)
			await game.get_tree().process_frame
		waits.append(Time.get_ticks_msec() - t0)
		await game.get_tree().physics_frame
		await game.get_tree().physics_frame
		for k in 9:
			var off := (east * (float(k % 3) - 1.0) * 17.0 + north * (float(k / 3) - 1.0) * 17.0)
			var q := (p + off).normalized()
			var h := pl.terrain_radius_at(q)
			var from := q * (h + 40.0)
			var to := q * (h - 40.0)
			var rq := PhysicsRayQueryParameters3D.create(from, to, 1)
			var hit := space.intersect_ray(rq)
			if hit.is_empty():
				fails += 1
				continue
			var hr: float = (hit["position"] as Vector3).length()
			worst = maxf(worst, absf(hr - h))
	print("[collision] ray misses=", fails, " worst height error m=", worst, " patch wait ms=", waits)
	print("PASS" if fails == 0 and worst < 0.6 else "FAIL", " terrain collision")
