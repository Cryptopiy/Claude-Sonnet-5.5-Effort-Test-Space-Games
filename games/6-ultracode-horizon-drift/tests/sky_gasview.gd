extends RefCounted
## Gas-giant view harness (module M2): camera placed relative to the planet's ring plane.
##   godot.ps1 ... -- --autostart --preset=freecam:1:200 --test=res://tests/sky_gasview.gd --views=far,near,above,edge --w=960
## view = {label, dist_km, el (deg above the ring plane), az (deg around the pole, 0 = towards the star), fov}
## Writes .previews/gas_fork_<label>.png at full camera resolution (HUD / ship hidden).

var cam: Camera3D

func _arg(key: String, def_val: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + key + "="):
			return s.substr(key.length() + 3)
	return def_val

func _views() -> Dictionary:
	return {
		"far": {"dist_km": 500.0, "el": 12.0, "az": 55.0},
		"mid": {"dist_km": 250.0, "el": 18.0, "az": 70.0},
		"near": {"dist_km": 100.0, "el": 20.0, "az": 45.0},
		"close": {"dist_km": 50.0, "el": 15.0, "az": 40.0},
		"above": {"dist_km": 320.0, "el": 62.0, "az": 25.0},
		"edge": {"dist_km": 320.0, "el": 1.0, "az": 80.0},
		"back": {"dist_km": 320.0, "el": 10.0, "az": 150.0},
		"night": {"dist_km": 320.0, "el": 12.0, "az": 170.0},
		"under": {"dist_km": 320.0, "el": -25.0, "az": 60.0},
		"crescent": {"dist_km": 400.0, "el": 15.0, "az": 130.0},
	}

func run(g: Node) -> void:
	cam = Camera3D.new()
	cam.name = "GasViewCam"
	cam.near = Game.CAMERA_NEAR_SHIP
	cam.far = Game.CAMERA_FAR_SHIP
	cam.fov = float(_arg("fov", "60"))
	Game.local_root.add_child(cam)
	cam.add_to_group("frame_objects")
	if Game.ship != null:
		Game.ship.visible = false
	if Game.hud != null:
		Game.hud.visible = false
	if _arg("noatmo", "0") == "1":
		for n in Universe.body_nodes:
			for c in n.get_children():
				if c is AtmosphereEffect:
					c.visible = false
	var views := _views()
	var wanted := _arg("views", "far,near").split(",")
	await g.get_tree().create_timer(3.0).timeout
	var body_i := int(_arg("body", "5"))
	for label in wanted:
		if not views.has(label):
			continue
		var v: Dictionary = views[label]
		_place(body_i, float(v["dist_km"]) * 1000.0, float(v["el"]), float(v["az"]))
		await g.get_tree().create_timer(1.2).timeout
		for i in 3:
			await g.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := g.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.previews/gas_fork_%s.png" % label)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		print("[gasview] ", label, " saved anchor=", Frame.anchor, " ", img.get_size())

func _place(body_i: int, dist: float, el_deg: float, az_deg: float) -> void:
	var bp := Universe.body_pos(body_i)
	var bas: Basis = Universe.body_basis(body_i, Universe.time)
	var pole: Vector3 = bas.y.normalized()
	var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
	var u := (to_star - pole * to_star.dot(pole)).normalized()
	var w := pole.cross(u).normalized()
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	var dirc := (u * cos(az) + w * sin(az)) * cos(el) + pole * sin(el)
	var cp := bp.add_v3(dirc * dist)
	Frame.set_space_frame(cp)
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	cam.look_at(Frame.to_local(bp), pole)
	Frame.set_focus(cam)
	cam.make_current()
