extends RefCounted
## Content test (M7a): the on-foot player must be blocked by structures and trees (colliders on layer 2).
##   godot.ps1 ... -GodotArgs "--resolution 1280x720 -- --autostart --preset=foot:1 --test=res://tests/content_walk.gd"
## For each target: teleport the player 18 m away facing it, hold move_forward for 6 s, report the closest approach to the target centre.

func _teleport(game: Node, planet: Node3D, dir: Vector3, face_to: Vector3) -> void:
	var r: float = planet.call("terrain_radius_at", dir)
	var pos := dir * (r + 1.2)
	var up := dir
	var f := (face_to - pos)
	f = (f - up * f.dot(up)).normalized()
	game.player.call("spawn_at", pos, up, f)

func _walk(game: Node, planet: Node3D, target_pos: Vector3, from_dir: Vector3, secs: float, label: String, expect_block: float) -> void:
	_teleport(game, planet, from_dir, target_pos)
	await game.get_tree().create_timer(3.5).timeout       # collision patch + props colliders
	var best := 1.0e9
	Input.action_press("move_forward")
	var t := 0.0
	while t < secs:
		await game.get_tree().process_frame
		t += get_process_delta_time_safe(game)
		var d: float = (game.player.global_position - target_pos).length()
		best = minf(best, d)
	Input.action_release("move_forward")
	var verdict := "BLOCKED" if best > expect_block else "WALKED THROUGH"
	print("[walk] %-26s closest=%.2f m (blocked if > %.1f) -> %s" % [label, best, expect_block, verdict])

func get_process_delta_time_safe(game: Node) -> float:
	return clampf(1.0 / maxf(Engine.get_frames_per_second(), 10.0), 0.004, 0.1)

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var sm: ScatterManager = planet.get_node_or_null("ScatterManager")
	var R := def.radius
	var pois := PoiSites.for_body(def)
	await game.get_tree().create_timer(2.0).timeout
	var kinds := {"outpost": 4.5, "tower": 3.5, "beacon": 2.0, "container": 0.6, "wreck": 3.5, "depot": 0.8, "solar": 2.0}
	var done: Dictionary = {}
	for i in pois.size():
		var p: Dictionary = pois[i]
		var k: String = p["kind"]
		if not kinds.has(k) or done.has(k):
			continue
		# only test sites close to the start (they must stream in around the player)
		if ScatterGrid.ground_dist(p["dir"], pois[0]["dir"], R) > 700.0:
			continue
		done[k] = true
		var dir: Vector3 = p["dir"]
		var gp: Vector3 = dir * float(planet.call("terrain_radius_at", dir))
		var from_dir := ScatterGrid.walk(dir, float(p["yaw"]) + 0.8, 18.0, R)
		await _walk(game, planet, gp + dir * 1.0, from_dir, 6.0, "%s (%s)" % [k, p["model"]], kinds[k])
	# a tree: pick the closest collider body of the tree/cactus type around the start
	await game.get_tree().create_timer(1.0).timeout
	var tree_pos := Vector3.ZERO
	var found := false
	var best := 1.0e9
	var origin: Vector3 = (pois[0]["dir"] as Vector3) * float(planet.call("terrain_radius_at", pois[0]["dir"]))
	for k in sm._bodies:
		var b: Node3D = sm._bodies[k]
		if not is_instance_valid(b):
			continue
		var d2 := b.position.distance_to(origin)
		if d2 > 30.0 and d2 < best and b.get_child_count() > 0:
			var cs := b.get_child(0) as CollisionShape3D
			if cs != null and cs.shape is CylinderShape3D and (cs.shape as CylinderShape3D).radius > 0.25:
				best = d2
				tree_pos = b.position
				found = true
	if found:
		var tdir := tree_pos.normalized()
		var from_dir2 := ScatterGrid.walk(tdir, 0.3, 10.0, R)
		await _walk(game, planet, tree_pos, from_dir2, 4.0, "tree/cactus collider", 0.35)
	else:
		print("[walk] no tree collider found near the start")
	print("PASS content_walk (read the verdict lines above)")
