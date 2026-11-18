extends RefCounted
## Fog quad probe: --test=res://tests/life_fog_probe.gd --freecam --preset=freecam:3:3 --weather=0.85 --tag=fogp
## Takes an eye-level shot with the fog colour forced to magenta (shows where/how strongly the fog quad blends over terrain and sky).
func run(game: Node) -> void:
	var tag := "fogp"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--tag="):
			tag = String(a).substr(6)
	var tree: SceneTree = game.get_tree()
	Game.playing_time = 400.0
	var def0 := Frame.anchor_def()
	Universe.time = Universe.time_for_sun_elevation(def0.index, PoiSites.start_dir(def0), 35.0, Universe.time, true)
	await tree.create_timer(6.0).timeout
	var cam: Node3D = game.freecam
	var pl := Frame.anchor_node() as Planet
	var up := PoiSites.start_dir(def0)
	var north := (Vector3.UP - up * up.y).normalized()
	var p0 := up * (pl.terrain_radius_at(up) + 1.7)
	var w: WeatherFX = game.weather
	w.debug_fog_color = Color(1.0, 0.0, 1.0, 1.0)
	cam.look_at_from_position(p0, p0 + north * 100.0 + up * 6.0, up)
	await tree.create_timer(1.5).timeout
	cam.look_at_from_position(p0, p0 + north * 100.0 + up * 6.0, up)
	await tree.process_frame
	await tree.process_frame
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.previews/%s.png" % tag))
	print("[fogp] fog_boost=", w.fog_boost, " amount=", w._fog_amount, " vis=", w._fog_mi.visible, " density=", w._fog_mat.get_shader_parameter("density"), " amt=", w._fog_mat.get_shader_parameter("amount"))
	print("[fogp] done")
