extends RefCounted
## External-camera viewer for the ship: godot ... -- --autostart --preset=landed --test=res://tests/ship_view.gd --view=<tag>:<az>:<el>:<dist>:<wait_s>  (repeatable)
## Places a Camera3D around the ship (ship space: az 0 = behind, 90 = right side; el degrees; dist metres) and saves .previews/m3_view_<tag>.png
## Any scripted keys (--keys=...) keep working, shots are taken at wait_s after the test starts.

func run(game: Node) -> void:
	var views: Array = []
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--view="):
			var p := s.substr(7).split(":")
			views.append({"tag": p[0], "az": float(p[1]), "el": float(p[2]), "dist": float(p[3]), "t": float(p[4])})
	views.sort_custom(func(x, y): return x["t"] < y["t"])
	var ship: Ship = game.ship
	var cam := Camera3D.new()
	cam.near = 0.3
	cam.far = 6.0e6
	cam.fov = 55.0
	ship.add_child(cam)
	cam.top_level = false
	var t := 0.0
	var vi := 0
	while vi < views.size():
		await game.get_tree().process_frame
		t += game.get_process_delta_time()
		var v: Dictionary = views[vi]
		var az := deg_to_rad(float(v["az"]))
		var el := deg_to_rad(float(v["el"]))
		var d: float = v["dist"]
		var off := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * d
		cam.transform = Transform3D(Basis.looking_at(-off, Vector3.UP), off)
		cam.make_current()
		if t >= float(v["t"]):
			await game.get_tree().process_frame
			await game.get_tree().process_frame
			var img := game.get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path("res://.previews/m3_view_%s.png" % v["tag"])
			img.save_png(path)
			print("[view] saved ", path, " speed=", ship.velocity.length(), " alt=", ship.altitude)
			vi += 1
	ship.rig.chase.make_current()
