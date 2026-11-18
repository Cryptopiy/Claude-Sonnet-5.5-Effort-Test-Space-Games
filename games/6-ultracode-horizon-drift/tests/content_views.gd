extends RefCounted
## Content views (M7a): free-camera screenshots at custom viewpoints relative to POIs of the loaded body.
##   godot.ps1 ... -GodotArgs "--resolution 1280x720 -- --autostart --preset=landed:1 --freecam --sun=35 --test=res://tests/content_views.gd
##       --views=pad_side|start|1.0|16|2.0|0|0|2|7;settle|outpost|1.0|30|2.0|0|0|3|7"
## each view: name|at|ang|dist|alt|look_ang|look_dist|look_alt|wait_s      at = start | <kind> | <kind>:<n>   (nth poi of that kind)
## writes .previews/cv_<biome>_<name>.png, prints scatter stats + fps. Optional --tag=<x> adds a prefix.

func _poi_dir(def: BodyDef, at: String) -> Vector3:
	var pois := PoiSites.for_body(def)
	if at == "start":
		return PoiSites.start_dir(def)
	var kind := at
	var nth := 0
	if at.contains(":"):
		kind = at.get_slice(":", 0)
		nth = int(at.get_slice(":", 1))
	var k := 0
	for p in pois:
		if String(p["kind"]) == kind:
			if k == nth:
				return p["dir"]
			k += 1
	return PoiSites.start_dir(def)

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var sm: Node = planet.get_node_or_null("ScatterManager")
	var R := def.radius
	var args := OS.get_cmdline_user_args()
	var views_s := ""
	var prefix := ""
	var sun := 35.0
	for a in args:
		var s := String(a)
		if s.begins_with("--views="):
			views_s = s.substr(8)
		elif s.begins_with("--tag="):
			prefix = s.substr(6) + "_"
		elif s.begins_with("--sun="):
			sun = float(s.substr(6))
	if game.freecam == null:
		print("FAIL need --freecam")
		return
	Universe.time = Universe.time_for_sun_elevation(def.index, PoiSites.start_dir(def), sun, Universe.START_TIME, true)
	var fc: Node3D = game.freecam
	for v in views_s.split(";", false):
		var f := v.split("|")
		var vname := f[0]
		var base := _poi_dir(def, f[1])
		var pos_d := ScatterGrid.walk(base, float(f[2]), float(f[3]), R)
		var look_d := ScatterGrid.walk(base, float(f[5]), float(f[6]), R)
		var r0: float = planet.call("terrain_radius_at", pos_d)
		var r1: float = planet.call("terrain_radius_at", look_d)
		fc.global_position = pos_d * (r0 + float(f[4]))
		fc.look_at(look_d * (r1 + float(f[7])), pos_d)
		await game.get_tree().create_timer(float(f[8])).timeout
		var img := game.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.previews/cv_%s%s_%s.png" % [prefix, def.biome, vname])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		var st: Dictionary = sm.call("stats") if sm != null else {}
		print("[views] %s fps=%d draws=%d prims=%dk inst=%s bodies=%s res=%s" % [vname, Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			str(st.get("instances", -1)), str(st.get("bodies", -1)), str(st.get("res_nodes", -1))])
