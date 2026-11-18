extends RefCounted
## Ocean test harness (module M2): finds a shoreline on the body (default Verdant) and renders full-size shots around it.
##   godot.ps1 ... -- --autostart --preset=freecam:1:200 --test=res://tests/sky_ocean.gd [--body=1] [--only=a,b] [--sun=35] [--prefix=ocean_fork]
## Shot keys: label, off (m along the seaward azimuth from the shoreline, + = offshore), mode "sea"|"ground" (alt measured from the water surface or from the terrain),
##   alt (m), pitch (deg), face "sea"|"sun"|"away" + yaw (deg offset), sun (deg elevation), fov, kind "space" (dist_km, phase)

var game: Node
var cam: Camera3D
var pl: Node3D
var def: BodyDef
var body_i := 1
var start: Vector3
var axis: Vector3
var s_shore := 0.0
var sea_h := 0.0

func _arg(key: String, def_val: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + key + "="):
			return s.substr(key.length() + 3)
	return def_val

func _dir_at(s: float) -> Vector3:
	return start.rotated(axis, s / def.radius).normalized()

func _find_shore() -> bool:
	var best := 1.0e9
	var t_base: Vector3 = start.cross(Vector3.UP).normalized()
	for k in 24:
		var t0: Vector3 = t_base.rotated(start, TAU * float(k) / 24.0)
		var ax: Vector3 = start.cross(t0).normalized()
		var prev_land := true
		var s := 0.0
		while s < 6000.0:
			var d: Vector3 = start.rotated(ax, s / def.radius).normalized()
			var h: float = pl.call("height_at", d)
			if h > sea_h + 1.0:
				prev_land = true
			elif prev_land and h < sea_h - 0.3 and s > 20.0:
				# make sure it is a real sea: deep a bit further
				var deep := true
				for j in 6:
					var d2: Vector3 = start.rotated(ax, (s + 80.0 * float(j + 1)) / def.radius).normalized()
					if float(pl.call("height_at", d2)) > sea_h - 0.5:
						deep = false
				if deep and s < best:
					best = s
					axis = ax
					s_shore = s
				break
			s += 25.0
	return best < 1.0e8

func _sets(name: String) -> Array:
	var out: Array = []
	match name:
		"main":
			out.append({"label": "shore_ground", "off": -25.0, "mode": "ground", "alt": 2.5, "pitch": -2.0, "face": "sea"})
			out.append({"label": "shore_wade", "off": 6.0, "mode": "sea", "alt": 1.6, "pitch": -6.0, "face": "sea"})
			out.append({"label": "air300_shore", "off": -60.0, "mode": "sea", "alt": 300.0, "pitch": -14.0, "face": "sea"})
			out.append({"label": "air300_out", "off": 900.0, "mode": "sea", "alt": 300.0, "pitch": -8.0, "face": "sea", "yaw": 40.0})
			out.append({"label": "air300_sun", "off": 900.0, "mode": "sea", "alt": 300.0, "pitch": -8.0, "face": "sun"})
			out.append({"label": "low40_sun", "off": 600.0, "mode": "sea", "alt": 40.0, "pitch": -3.0, "face": "sun"})
			out.append({"label": "low40_away", "off": 600.0, "mode": "sea", "alt": 40.0, "pitch": -6.0, "face": "away"})
			out.append({"label": "far_2km", "off": 2000.0, "mode": "sea", "alt": 150.0, "pitch": -2.0, "face": "sea", "yaw": 30.0})
			out.append({"label": "far_10km_air", "off": 1500.0, "mode": "sea", "alt": 2500.0, "pitch": -4.0, "face": "sea", "yaw": 20.0})
			out.append({"label": "grazing_2m", "off": 400.0, "mode": "sea", "alt": 2.0, "pitch": 0.0, "face": "sea", "yaw": 25.0})
			out.append({"label": "under_4m", "off": 300.0, "mode": "sea", "alt": -4.0, "pitch": 0.0, "face": "sea"})
			out.append({"label": "under_look_up", "off": 300.0, "mode": "sea", "alt": -6.0, "pitch": 55.0, "face": "sea"})
			out.append({"label": "space_60", "kind": "space", "dist_km": 60.0, "phase": 50.0})
			out.append({"label": "space_250", "kind": "space", "dist_km": 250.0, "phase": 40.0})
		"sunset":
			out.append({"label": "ss_low_sun", "off": 600.0, "mode": "sea", "alt": 40.0, "pitch": -2.0, "face": "sun", "sun": 3.0})
			out.append({"label": "ss_away", "off": 600.0, "mode": "sea", "alt": 40.0, "pitch": -4.0, "face": "away", "sun": 3.0})
			out.append({"label": "night", "off": 600.0, "mode": "sea", "alt": 40.0, "pitch": -8.0, "face": "sea", "sun": -30.0})
		_:
			out.append({"label": "default", "off": 100.0, "mode": "sea", "alt": 30.0, "pitch": -8.0, "face": "sea"})
	return out

func run(g: Node) -> void:
	game = g
	body_i = int(_arg("body", "1"))
	def = Universe.system.bodies[body_i]
	cam = Camera3D.new()
	cam.name = "OceanTestCam"
	cam.near = Game.CAMERA_NEAR_FOOT
	cam.far = Game.CAMERA_FAR_FOOT
	cam.fov = float(_arg("fov", "75"))
	Game.local_root.add_child(cam)
	cam.add_to_group("frame_objects")
	if Game.ship != null:
		Game.ship.visible = false
	if Game.hud != null:
		Game.hud.visible = false
	Frame.set_body_frame(body_i)
	pl = Frame.anchor_node()
	start = PoiSites.start_dir(def)
	var sr: float = float(pl.call("sea_radius"))
	sea_h = sr - def.radius if sr > 0.0 else 0.0
	print("[ocean] body ", body_i, " ", def.name, " biome=", def.biome, " has_ocean=", def.has_ocean, " kind=", def.ocean_kind, " sea_h=", sea_h)
	var found := _find_shore()
	print("[ocean] shore found=", found, " s_shore=", s_shore)
	if not found:
		print("[ocean] no shore: only space shots")
	var shots := _sets(_arg("set", "main"))
	var only := _arg("only", "")
	var prefix := _arg("prefix", "ocean_fork")
	await game.get_tree().create_timer(3.0).timeout
	for s in shots:
		if only != "" and not (String(s["label"]) in only.split(",")):
			continue
		if String(s.get("kind", "")) != "space" and not found:
			continue
		await _setup_shot(s)
		await game.get_tree().create_timer(float(_arg("settle", "3.0"))).timeout
		for i in 3:
			await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := game.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://.previews/%s_%s.png" % [prefix, s["label"]]))
		print("[ocean] shot ", s["label"], " sun_elev=", game.sky.sun_elevation_deg)

func _setup_shot(s: Dictionary) -> void:
	if String(s.get("kind", "")) == "space":
		var dist := float(s["dist_km"]) * 1000.0
		var bp := Universe.body_pos(body_i)
		var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
		var dirc := to_star.rotated(Vector3.UP, deg_to_rad(float(s.get("phase", 50.0))))
		var cp := bp.add_v3(dirc * dist + Vector3.UP * dist * 0.15)
		Frame.set_space_frame(cp)
		cam.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
		cam.look_at(Frame.to_local(bp), Vector3.UP)
		Frame.set_focus(cam)
		cam.make_current()
		return
	var s_pos := s_shore + float(s["off"])
	var dir := _dir_at(s_pos)
	var sun_el := float(s.get("sun", float(_arg("sun", "35"))))
	Frame.set_body_frame(body_i)
	Universe.time = Universe.time_for_sun_elevation(body_i, dir, sun_el, Universe.time, true)
	Frame.set_body_frame(body_i)
	var h: float = float(pl.call("height_at", dir))
	var alt := float(s["alt"])
	var rad: float = def.radius + (sea_h if String(s["mode"]) == "sea" else h) + alt
	var pos: Vector3 = dir * rad
	var up := dir
	var sd := Universe.sun_dir_body_local(body_i)
	var sun_h := sd - up * sd.dot(up)
	if sun_h.length() < 0.01:
		sun_h = up.cross(Vector3.RIGHT)
	sun_h = sun_h.normalized()
	var sea_t: Vector3 = axis.cross(dir).normalized()
	var base_fwd: Vector3 = sea_t
	match String(s.get("face", "sea")):
		"sun": base_fwd = sun_h
		"away": base_fwd = -sun_h
	var fwd_h: Vector3 = base_fwd.rotated(up, deg_to_rad(float(s.get("yaw", 0.0))))
	var right: Vector3 = fwd_h.cross(up).normalized()
	var fwd: Vector3 = fwd_h.rotated(right, deg_to_rad(float(s.get("pitch", 0.0)))).normalized()
	cam.global_transform = Transform3D(Basis.looking_at(fwd, up), pos)
	Frame.set_focus(cam)
	cam.make_current()
