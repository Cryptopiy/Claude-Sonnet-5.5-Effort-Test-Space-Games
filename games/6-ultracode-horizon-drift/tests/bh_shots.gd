extends RefCounted
## Visual test: renders the black hole from several viewpoints in ONE run and saves PNGs (windowless).
##   --test=res://tests/bh_shots.gd -- ... --shots="400:0:12;100:0:12;30:0:12;8:0:12" --out=.previews/s --hide-ship
## spec per shot: dist_km:azimuth_deg:elevation_deg  (azimuth/elevation relative to the star-side approach direction; elevation > 0 = above the star direction)
## extra user args:  --bh=name:val,name:val   (BlackHole shader overrides, see black_hole.gd)  --wait=<frames>

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + name + "="):
			return s.substr(name.length() + 3)
		if s == "--" + name:
			return "1"
	return default

func run(game: Node) -> void:
	var sys := Universe.system
	var bi := sys.black_hole_index
	if bi < 0:
		print("FAIL bh_shots: no black hole in this system")
		return
	var bhp := Universe.body_pos(bi)
	var to_star := Vector3(-bhp.x, -bhp.y, -bhp.z).normalized()
	var specs := _arg("shots", "400:0:12;100:0:12;30:0:12;8:0:12").split(";", false)
	var out := _arg("out", ".previews/s")
	var wait_frames := int(_arg("wait", "10"))
	var hide_ship := _arg("hide-ship", "1") != "0"
	var n := 0
	for sp in specs:
		var p := sp.split(":")
		var dist := float(p[0]) * 1000.0
		var az := deg_to_rad(float(p[1])) if p.size() > 1 else 0.0
		var el := deg_to_rad(float(p[2])) if p.size() > 2 else 0.0
		var up := Vector3.UP
		var right := to_star.cross(up).normalized()
		var dir := to_star.rotated(up, az)
		dir = dir.rotated(right.rotated(up, az), el)
		game.place_ship_abs(bhp.add_v3(dir * dist), -dir)
		if hide_ship and game.ship != null:
			game.ship.visible = false
		for i in wait_frames:
			await game.get_tree().process_frame
		var img: Image = game.get_viewport().get_texture().get_image()
		var path := "%s_%d_%s.png" % [out, n, str(p[0])]
		var full := ProjectSettings.globalize_path("res://" + path)
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		img.save_png(full)
		print("[bh_shots] saved ", full, "  fps=", Engine.get_frames_per_second())
		n += 1
