extends RefCounted
## Contact-sheet screenshot harness for the sky / atmosphere module (module M2).
##   godot.ps1 ... -- --autostart --preset=freecam:1:200 --test=res://tests/sky_shots.gd --set=noon [--cols=3] [--w=640]
## A shot = {label, body, mode "ground"|"space"|"air", alt (m), sun (deg elevation), yaw (deg relative to the sun azimuth, 0 = towards the sun), pitch (deg),
##           dist_km + phase (space shots: camera distance and star-planet-camera angle), fov, sys}
## All shots of a set are rendered one after the other and pasted into a single PNG: .previews/sky_<set>.png

var game: Node
var cam: Camera3D

const BIOME_BODIES := [1, 3, 4, 0, 6, 2, 7]     # lush, desert, frozen, volcanic, toxic(moon), barren(moon), exotic(moon)

func _sets(name: String) -> Array:
	var out: Array = []
	match name:
		"noon":
			for b in BIOME_BODIES:
				out.append({"label": "noon_%d" % b, "body": b, "alt": 3.0, "sun": 50.0, "yaw": 150.0, "pitch": 12.0})
		"sunset":
			for b in BIOME_BODIES:
				out.append({"label": "sunset_%d" % b, "body": b, "alt": 3.0, "sun": 2.5, "yaw": 0.0, "pitch": 6.0})
		"dusk_away":
			for b in BIOME_BODIES:
				out.append({"label": "dusk_%d" % b, "body": b, "alt": 3.0, "sun": -4.0, "yaw": 180.0, "pitch": 25.0})
		"night":
			for b in BIOME_BODIES:
				out.append({"label": "night_%d" % b, "body": b, "alt": 3.0, "sun": -35.0, "yaw": 0.0, "pitch": 35.0})
		"zenith":
			for b in BIOME_BODIES:
				out.append({"label": "zen_%d" % b, "body": b, "alt": 3.0, "sun": 40.0, "yaw": 90.0, "pitch": 70.0})
		"low":
			for b in BIOME_BODIES:
				out.append({"label": "low_%d" % b, "body": b, "alt": 150.0, "sun": 35.0, "yaw": 160.0, "pitch": -8.0})
		"lowsun":
			for b in BIOME_BODIES:
				out.append({"label": "lowsun_%d" % b, "body": b, "alt": 150.0, "sun": 35.0, "yaw": 10.0, "pitch": 4.0})
		"cloudtop":
			for b in [1, 3, 4, 6]:
				out.append({"label": "ctop_%d" % b, "body": b, "alt": 3000.0, "sun": 35.0, "yaw": 160.0, "pitch": -35.0})
			for b in [1, 3, 4, 6]:
				out.append({"label": "c30_%d" % b, "body": b, "alt": 30000.0, "sun": 35.0, "yaw": 160.0, "pitch": -55.0})
		"air":
			for b in [1, 3, 4, 0, 6, 7]:
				out.append({"label": "air_%d" % b, "body": b, "alt": 1200.0, "sun": 30.0, "yaw": 160.0, "pitch": -10.0})
		"space":
			for b in [1, 3, 4, 0, 6, 7]:
				out.append({"label": "space_%d" % b, "mode": "space", "body": b, "dist_km": 60.0 + 0.0, "phase": 55.0})
		"space_far":
			for b in [1, 3, 4, 0, 5, 7]:
				out.append({"label": "spaceF_%d" % b, "mode": "space", "body": b, "dist_km": 300.0, "phase": 35.0})
		"crescent":
			for b in [1, 3, 4, 0, 6, 7]:
				out.append({"label": "cres_%d" % b, "mode": "space", "body": b, "dist_km": 45.0, "phase": 140.0})
		"gas":
			out.append({"label": "gas_far", "mode": "space", "body": 5, "dist_km": 900.0, "phase": 50.0})
			out.append({"label": "gas_mid", "mode": "space", "body": 5, "dist_km": 380.0, "phase": 60.0})
			out.append({"label": "gas_ring", "mode": "space", "body": 5, "dist_km": 250.0, "phase": 100.0, "pitch": 10.0})
			out.append({"label": "gas_near", "mode": "space", "body": 5, "dist_km": 120.0, "phase": 40.0})
			out.append({"label": "gas_top", "mode": "ground", "body": 5, "alt": 6000.0, "sun": 30.0, "yaw": 160.0, "pitch": -15.0})
			out.append({"label": "gas_in", "mode": "ground", "body": 5, "alt": 1500.0, "sun": 30.0, "yaw": 160.0, "pitch": -10.0})
		"star":
			for d in [3000.0, 900.0, 300.0, 120.0, 60.0, 40.0]:
				out.append({"label": "star_%d" % int(d), "mode": "star", "dist_km": d})
		"sea":
			out.append({"label": "sea_1", "body": 1, "alt": 3.0, "sun": 30.0, "yaw": 160.0, "pitch": -5.0, "dir": Vector3(0.9, 0.05, 0.3)})
		_:
			out.append({"label": "default", "body": 1, "alt": 3.0, "sun": 30.0, "yaw": 150.0, "pitch": 10.0})
	return out

func _arg(key: String, def_val: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + key + "="):
			return s.substr(key.length() + 3)
	return def_val

func run(g: Node) -> void:
	game = g
	var set_name := _arg("set", "noon")
	var cols := int(_arg("cols", "3"))
	var w := int(_arg("w", "640"))
	var shots: Array = []
	for sn in set_name.split("+"):
		shots.append_array(_sets(sn))
	var only := _arg("only", "")
	cam = Camera3D.new()
	cam.name = "SkyTestCam"
	cam.near = Game.CAMERA_NEAR_FOOT
	cam.far = Game.CAMERA_FAR_FOOT
	cam.fov = float(_arg("fov", "75"))
	Game.local_root.add_child(cam)
	cam.add_to_group("frame_objects")
	if Game.ship != null and _arg("ship", "0") != "1":
		Game.ship.visible = false
	if Game.hud != null and _arg("hud", "0") != "1":
		Game.hud.visible = false
	if _arg("glow", "1") == "0" and Game.sky != null:
		Game.sky.env.glow_enabled = false
	var hide := _arg("hide", "")
	if hide != "":
		for n in Universe.body_nodes:
			for c in n.get_children():
				if (hide.contains("ocean") and c is OceanSurface) or (hide.contains("cloud") and c is CloudLayer) or (hide.contains("atmo") and c is AtmosphereEffect):
					c.visible = false
	var imgs: Array = []
	var h := int(round(w * 9.0 / 16.0))
	await game.get_tree().create_timer(4.0).timeout
	for s in shots:
		if only != "" and not (String(s["label"]) in only.split(",")):
			continue
		await _setup_shot(s)
		await game.get_tree().create_timer(float(_arg("settle", "0.9"))).timeout
		for i in 3:
			await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := game.get_viewport().get_texture().get_image()
		if _arg("full", "0") == "1":
			img.save_png(ProjectSettings.globalize_path("res://.previews/sky_%s_%s.png" % [set_name, s["label"]]))
		img.convert(Image.FORMAT_RGB8)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		imgs.append(img)
		print("[sky_shots] %d: %s  sun_elev=%.1f  energy=%.2f night=%.2f" % [imgs.size() - 1, s["label"], game.sky.sun_elevation_deg, game.sky.sun_energy_now, game.sky.night_now])
	var rows := int(ceil(float(imgs.size()) / cols))
	var sheet := Image.create(cols * w, rows * h, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	var path := ProjectSettings.globalize_path("res://.previews/sky_%s.png" % set_name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	sheet.save_png(path)
	print("[sky_shots] sheet saved ", path)

func _setup_shot(s: Dictionary) -> void:
	var mode := String(s.get("mode", "ground"))
	var sys: SystemDef = Universe.system
	var body_i: int = int(s.get("body", 1))
	var b: BodyDef = sys.bodies[body_i]
	Game.nav_target = -1
	if mode == "star":
		var dist := float(s["dist_km"]) * 1000.0
		Frame.set_space_frame(DVec.new(dist, dist * 0.1, 0.0))
		cam.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
		var tgt := Frame.star_local
		cam.look_at(tgt, Vector3.UP)
		Frame.set_focus(cam)
		cam.make_current()
		return
	if mode == "space":
		var dist2 := float(s["dist_km"]) * 1000.0
		var bp := Universe.body_pos(body_i)
		var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
		var axis := Vector3.UP
		var dirc := to_star.rotated(axis, deg_to_rad(float(s.get("phase", 50.0))))
		var cp := bp.add_v3(dirc * dist2 + Vector3.UP * dist2 * 0.15)
		Frame.set_space_frame(cp)
		cam.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
		var tgt2 := Frame.to_local(bp)
		cam.look_at(tgt2, Vector3.UP)
		if s.has("pitch"):
			cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(float(s["pitch"])) * 0.0)
		Frame.set_focus(cam)
		cam.make_current()
		return
	# ground / air: body frame
	var dir: Vector3 = s.get("dir", Vector3(0.78, 0.12, 0.62)) as Vector3
	dir = dir.normalized()
	Frame.set_body_frame(body_i)
	Universe.time = Universe.time_for_sun_elevation(body_i, dir, float(s.get("sun", 30.0)), Universe.time, true)
	Frame.set_body_frame(body_i)
	var pl := Frame.anchor_node()
	var hgt := 0.0
	if pl != null and pl.has_method("height_at") and b.landable:
		hgt = float(pl.call("height_at", dir))
	var alt := float(s.get("alt", 3.0))
	if pl != null and pl.has_method("sea_radius") and float(pl.call("sea_radius")) > 0.0:
		hgt = maxf(hgt, float(pl.call("sea_radius")) - b.radius + 2.0)
	var pos := dir * (b.radius + hgt + alt)
	var up := dir
	var sd := Universe.sun_dir_body_local(body_i)
	var hor := sd - up * sd.dot(up)
	if hor.length() < 0.01:
		hor = up.cross(Vector3.RIGHT)
	hor = hor.normalized()
	var yaw := deg_to_rad(float(s.get("yaw", 0.0)))
	var fwd_h := hor.rotated(up, yaw)
	var right := fwd_h.cross(up).normalized()
	var pitch := deg_to_rad(float(s.get("pitch", 0.0)))
	var fwd := fwd_h.rotated(right, pitch).normalized()
	cam.global_transform = Transform3D(Basis.looking_at(fwd, up), pos)
	Frame.set_focus(cam)
	cam.make_current()
