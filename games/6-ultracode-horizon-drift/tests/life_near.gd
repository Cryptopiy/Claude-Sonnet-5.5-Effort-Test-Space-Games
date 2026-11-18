extends RefCounted
## Lists creatures around the spawn point and shoots the nearest few ground ones from player eye height.
## --test=res://tests/life_near.gd --freecam --preset=freecam:<b>:3 --tag=x [--wait=8] [--k=3] [--fov=60] [--eye=1.7]
func run(game: Node) -> void:
	var tag := "near"
	var wait := 8.0
	var kmax := 3
	var fov := 60.0
	var eye := 1.7
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--tag="):
			tag = s.substr(6)
		elif s.begins_with("--wait="):
			wait = float(s.substr(7))
		elif s.begins_with("--k="):
			kmax = int(s.substr(4))
		elif s.begins_with("--fov="):
			fov = float(s.substr(6))
		elif s.begins_with("--eye="):
			eye = float(s.substr(6))
	var tree: SceneTree = game.get_tree()
	await tree.create_timer(wait).timeout
	var cam: Node3D = game.freecam
	var cam3: Camera3D = Game.active_camera()
	cam3.fov = fov
	var fm: FaunaManager = game.fauna
	var pl := Frame.anchor_node() as Planet
	var def := Frame.anchor_def()
	var sd := PoiSites.start_dir(def)
	var p0 := sd * (pl.terrain_radius_at(sd) + eye)
	cam.global_position = p0
	var list: Array = []
	for c in fm.creatures.values():
		var cr := c as Creature
		list.append([cr.position.distance_to(p0), cr])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var ground := 0
	var n_shown := 0
	for e in list:
		var cr: Creature = e[1]
		if n_shown < 14:
			print("[life_near] ", cr.species, " d=%.0f" % float(e[0]), " state=", cr.state, " alt=%.1f" % (cr.position.length() - pl.terrain_radius_at(cr.position.normalized())))
			n_shown += 1
	var shot := 0
	for e in list:
		var cr: Creature = e[1]
		if cr.type != "walker" and cr.type != "crawler":
			continue
		if float(e[0]) < 12.0 or shot >= kmax:
			continue
		var up := p0.normalized()
		var tgt := cr.position + up * 0.8
		cam.look_at_from_position(p0, tgt, up)
		for k in 14:
			await tree.process_frame
		cam.look_at_from_position(p0, cr.position + up * 0.8, up)
		await tree.process_frame
		await tree.process_frame
		var path := ProjectSettings.globalize_path("res://.previews/%s_%d.png" % [tag, shot])
		cam.get_viewport().get_texture().get_image().save_png(path)
		print("[life_near] shot ", shot, " species=", cr.species, " d=%.0f" % float(e[0]))
		shot += 1
	print("[life_near] done")
