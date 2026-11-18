extends RefCounted
## Weather tour at the start pad of the anchored planet with the free camera; writes ONE contact sheet (6 views, 640x360 each) + one full-size eye-level shot.
##   --test=res://tests/life_wx_tour.gd --freecam --preset=freecam:<b>:3 --weather=0.85 --pt=400 --tag=wx_b3 [--wait=7]
## Views: 1 eye level horizon, 2 eye level looking up, 3 eye level looking down-wind, 4 120 m altitude (ship-like), 5 fast low flight (450 m/s), 6 1800 m altitude.
## Prints weather kind / intensity / fog / fps / layer visibility for each view.
func run(game: Node) -> void:
	var tag := "wx"
	var wait := 7.0
	var pt := 400.0
	var sun := 35.0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--tag="):
			tag = s.substr(6)
		elif s.begins_with("--wait="):
			wait = float(s.substr(7))
		elif s.begins_with("--pt="):
			pt = float(s.substr(5))
		elif s.begins_with("--sun="):
			sun = float(s.substr(6))
	var tree: SceneTree = game.get_tree()
	Game.playing_time = pt
	var def0 := Frame.anchor_def()
	if def0 != null and sun > -90.0:
		Universe.time = Universe.time_for_sun_elevation(def0.index, PoiSites.start_dir(def0), sun, Universe.time, true)
	await tree.create_timer(wait).timeout
	var cam: Node3D = game.freecam
	var cam3: Camera3D = Game.active_camera()
	cam3.fov = 75.0
	var pl := Frame.anchor_node() as Planet
	var def := Frame.anchor_def()
	if pl == null:
		print("[wx_tour] no planet anchored (anchor=", Frame.anchor, ")")
	var sd := PoiSites.start_dir(def) if def != null else Vector3.UP
	var up := sd
	var north := (Vector3.UP - up * up.y).normalized()
	var east := north.cross(up).normalized()
	var sheet := Image.create(1280, 1080, false, Image.FORMAT_RGBA8)
	var views: Array = []
	# 1..3 eye level
	var eye := pl.terrain_radius_at(up) + 1.7 if pl != null else 1000.0
	var p0 := up * eye
	views.append({"name": "eye_horizon", "pos": p0, "look": p0 + north * 100.0 + up * 6.0, "up": up, "settle": 1.0})
	views.append({"name": "eye_up", "pos": p0, "look": p0 + north * 60.0 + up * 70.0, "up": up, "settle": 0.6})
	views.append({"name": "eye_wind", "pos": p0, "look": p0 + (east * 0.7 - north * 0.4).normalized() * 100.0 + up * 3.0, "up": up, "settle": 0.6})
	# 4 ship-like
	var p4 := up * ((pl.terrain_radius_at(up) if pl != null else 1000.0) + 120.0)
	views.append({"name": "alt120", "pos": p4, "look": p4 + north * 200.0 - up * 70.0, "up": up, "settle": 0.8})
	var idx := 0
	for v in views:
		cam.look_at_from_position(v["pos"], v["look"], v["up"])
		await tree.create_timer(float(v["settle"])).timeout
		cam.look_at_from_position(v["pos"], v["look"], v["up"])
		await tree.process_frame
		await tree.process_frame
		_grab(game, sheet, idx, tag, v["name"] == "eye_horizon")
		_report(game, str(v["name"]))
		idx += 1
	# 5 fast low flight
	var dir := up
	var speed := 450.0
	var t_end := 3.2
	var t := 0.0
	var fwd := north
	while t < t_end:
		await tree.process_frame
		var dt := minf(tree.root.get_process_delta_time(), 0.05)
		t += dt
		var ang := speed * dt / (pl.radius if pl != null else 8000.0)
		var axis := dir.cross(fwd).normalized()
		dir = dir.rotated(axis, ang).normalized()
		fwd = fwd.rotated(axis, ang).normalized()
		var h := pl.terrain_radius_at(dir) + 80.0 if pl != null else 1000.0
		cam.look_at_from_position(dir * h, dir * h + fwd * 100.0, dir)
	_grab(game, sheet, idx, tag, false)
	_report(game, "fast450")
	idx += 1
	# 6 high altitude
	var p6 := up * ((pl.terrain_radius_at(up) if pl != null else 1000.0) + 1800.0)
	cam.look_at_from_position(p6, p6 + north * 200.0 - up * 120.0, up)
	await tree.create_timer(2.5).timeout
	cam.look_at_from_position(p6, p6 + north * 200.0 - up * 120.0, up)
	await tree.process_frame
	await tree.process_frame
	_grab(game, sheet, idx, tag, false)
	_report(game, "alt1800")
	sheet.save_png(ProjectSettings.globalize_path("res://.previews/%s_sheet.png" % tag))
	print("[wx_tour] done")

func _grab(game: Node, sheet: Image, idx: int, tag: String, save_full: bool) -> void:
	var img: Image = game.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if save_full:
		img.save_png(ProjectSettings.globalize_path("res://.previews/%s_full.png" % tag))
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((idx % 2) * 640, (idx / 2) * 360))

func _report(game: Node, nm: String) -> void:
	var w: WeatherFX = game.weather
	var fm: FaunaManager = game.fauna
	var fpos: Vector3 = Frame.focus.global_position if Frame.focus != null else Vector3.ZERO
	var g150 := 0
	var tot_g := 0
	var tot_f := 0
	var tot_y := 0
	for c in fm.creatures.values():
		var cr := c as Creature
		if cr.type == "flyer":
			tot_y += 1
		elif cr.type == "floater":
			tot_f += 1
		else:
			tot_g += 1
			if cr.position.distance_to(fpos) < 150.0:
				g150 += 1
	print("[wx_tour]   fauna ground=%d (<150m: %d) floaters=%d flyers=%d" % [tot_g, g150, tot_f, tot_y])
	var vis: Array = []
	for k in w._layers:
		var L: Dictionary = w._layers[k]
		if (L["node"] as MultiMeshInstance3D).visible:
			vis.append("%s=%.2f" % [String(k).get_slice("/", 1), float(L["fade"])])
	print("[wx_tour] %s profile=%s kind=%s int=%.2f fog=%.2f boost=%.2f wind=%.1f fps=%d layers=%s" % [nm, w._profile, w.kind, w.intensity, w.fog_amount, w.fog_boost, w.wind.length(), Engine.get_frames_per_second(), vis])
