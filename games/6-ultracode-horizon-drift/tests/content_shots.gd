extends RefCounted
## Content test (M7a): flies the free camera to a series of viewpoints around the start pad of the loaded body, waits for the scatter to stream in,
## prints scatter stats + fps and saves screenshots to .previews/content_<biome>_<n>.png.
##   godot.ps1 ... -GodotArgs "--resolution 1280x720 -- --autostart --preset=freecam:1:5 --test=res://tests/content_shots.gd"

func _cam_to(game: Node, dir: Vector3, alt: float, look_at_dir: Vector3, look_alt: float) -> void:
	var planet: Node3D = Frame.anchor_node()
	var def: BodyDef = Frame.anchor_def()
	var r0: float = planet.call("terrain_radius_at", dir)
	var fc: Node3D = game.freecam
	fc.global_position = dir * (r0 + alt)
	var r1: float = planet.call("terrain_radius_at", look_at_dir)
	var tgt := look_at_dir * (r1 + look_alt)
	var up := dir
	fc.look_at(tgt, up)

func _wait(game: Node, sec: float) -> void:
	await game.get_tree().create_timer(sec).timeout

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var sm: ScatterManager = planet.get_node_or_null("ScatterManager")
	if sm == null:
		print("FAIL no ScatterManager")
		return
	var R := def.radius
	var start := PoiSites.start_dir(def)
	var pois := PoiSites.for_body(def)
	print("[content] body=%s biome=%s pois=%d" % [def.name, def.biome, pois.size()])
	var tag := def.biome
	var views: Array = []
	# 1: ground view from the pad edge looking out
	var t := ScatterGrid.tangents(start)
	var out_dir := ScatterGrid.walk(start, 0.6, 70.0, R)
	views.append(["ground_pad", ScatterGrid.walk(start, 0.6 + PI, 20.0, R), 1.8, out_dir, 4.0, 4.0])
	# 2: toward the nearest settlement (index of the first outpost)
	var first_out := Vector3.ZERO
	for p in pois:
		if p["kind"] == "outpost":
			first_out = p["dir"]
			break
	var from_d := ScatterGrid.walk(first_out, 1.0, 70.0, R)
	views.append(["settlement", from_d, 2.0, first_out, 4.0, 3.0])
	# 3: raised view over the pad
	views.append(["raised", ScatterGrid.walk(start, 2.4, 55.0, R), 22.0, start, 0.0, 4.0])
	# 4: overview 250 m
	views.append(["air250", ScatterGrid.walk(start, 0.3, 260.0, R), 150.0, ScatterGrid.walk(start, 0.3 + PI, 400.0, R), 0.0, 6.0])
	# 5: overview 700 m
	views.append(["air700", ScatterGrid.walk(start, 0.9, 900.0, R), 380.0, start, 0.0, 7.0])
	var n := 0
	for v in views:
		_cam_to(game, v[1], v[2], v[3], v[4])
		await _wait(game, float(v[5]))
		var img := game.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.previews/content_%s_%d_%s.png" % [tag, n, v[0]])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		var rs := "draws=%d prims=%dk objs=%d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)]
		print("[content] shot %s fps=%d %s stats=%s" % [v[0], Engine.get_frames_per_second(), rs, str(sm.stats())])
		n += 1
