extends RefCounted
## Findability of the black hole from far away (module M5):  --test=res://tests/bh_far.gd -- --autostart --preset=bh:2000 [--out=.previews/far] [--spec=home:0;2000:0;2000:30;1000:0;600:0]
## Each spec = <distance km | "home">:<yaw offset deg>.  "home" = a point 250 km above the start planet on the side facing the hole (what a player sees from the home planet area).
## All shots are taken in ONE run (ship visible, HUD on) so the HUD marker + the in-world cue can be judged together.

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
	return default

func run(game: Node) -> void:
	var out := _arg("out", ".previews/far")
	var specs := _arg("spec", "home:0;2000:0;2000:35;1000:0;600:0").split(";", false)
	var sys := Universe.system
	var bi := sys.black_hole_index
	var bh := Universe.body_pos(bi)
	var hb: BodyDef = sys.bodies[sys.start_body]
	var hp := Universe.body_pos(sys.start_body)
	var to_star := Vector3(-bh.x, -bh.y, -bh.z).normalized()
	print("[bh_far] start planet '%s' is %.0f km from '%s'; the star is %.0f km from the hole" % [hb.name, hp.distance_to(bh) / 1000.0, sys.bodies[bi].name, bh.length() / 1000.0])
	for i in 8:
		await game.get_tree().process_frame
	var n := 0
	for sp in specs:
		var p := sp.split(":")
		var pos: DVec
		var ang := deg_to_rad(float(p[1]))
		var tag := String(p[0])
		if tag == "home":
			var dirh := Vector3(bh.x - hp.x, bh.y - hp.y, bh.z - hp.z).normalized()
			pos = hp.add_v3(dirh * (hb.radius + 250000.0))
		else:
			pos = bh.add_v3(to_star * (float(tag) * 1000.0))
		var fwd := Vector3(bh.x - pos.x, bh.y - pos.y, bh.z - pos.z).normalized().rotated(Vector3.UP, ang)
		game.place_ship_abs(pos, fwd)
		for i in 14:
			await game.get_tree().process_frame
		var img: Image = game.get_viewport().get_texture().get_image()
		var full := ProjectSettings.globalize_path("res://%s_%d_%s_%d.png" % [out, n, tag, int(float(p[1]))])
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		img.save_png(full)
		print("[bh_far] shot %d  from %s (distance to hole %.0f km), yaw offset %s deg -> %s" % [n, tag, bh.distance_to(Frame.to_abs(game.ship.global_position)) / 1000.0, p[1], full])
		n += 1
