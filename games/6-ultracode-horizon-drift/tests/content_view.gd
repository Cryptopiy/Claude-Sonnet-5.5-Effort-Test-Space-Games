extends RefCounted
## Content view (M7a): custom camera shots at/near the start pad or a POI kind.  user args: --test=res://tests/content_view.gd
## Shots are defined in the list below: [name, kind_or_pad, ang, dist, alt, look_alt, wait]
func _cam(game: Node, dir: Vector3, alt: float, look_dir: Vector3, look_alt: float) -> void:
	var planet: Node3D = Frame.anchor_node()
	var r0: float = planet.call("terrain_radius_at", dir)
	var fc: Node3D = game.freecam
	fc.global_position = dir * (r0 + alt)
	var r1: float = planet.call("terrain_radius_at", look_dir)
	fc.look_at(look_dir * (r1 + look_alt), dir)

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var R := def.radius
	var pois := PoiSites.for_body(def)
	var start := PoiSites.start_dir(def)
	var args := OS.get_cmdline_user_args()
	var spec := "pad"
	var out_tag := "v"
	for a in args:
		if a.begins_with("--view="):
			spec = a.substr(7)
		if a.begins_with("--vtag="):
			out_tag = a.substr(7)
	# spec: kind:index:ang:dist:alt:lookalt[,...]   (kind = poi kind, index = nth of that kind)
	var n := 0
	for s in spec.split(","):
		var p := s.split(":")
		var kind := p[0]
		var idx := int(p[1])
		var ang := float(p[2])
		var dist := float(p[3])
		var alt := float(p[4])
		var lalt := float(p[5])
		var target := start
		var c := 0
		for q in pois:
			if q["kind"] == kind or (kind == "pad" and q["kind"] == "landing_pad"):
				if c == idx:
					target = q["dir"]
					break
				c += 1
		var from := ScatterGrid.walk(target, ang, dist, R)
		_cam(game, from, alt, target, lalt)
		await game.get_tree().create_timer(6.0).timeout
		var img := game.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.previews/%s_%d_%s.png" % [out_tag, n, kind])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		print("[view] saved ", path, " fps=", Engine.get_frames_per_second())
		n += 1
