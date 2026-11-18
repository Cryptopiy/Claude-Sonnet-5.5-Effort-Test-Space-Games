extends RefCounted
## Panorama at the focus with the free camera: --test=res://tests/life_pano.gd --freecam --preset=freecam:<b>:3 --tag=x [--n=4] [--wait=6] [--pitch=5] [--eye=1.7] [--fov=75]
## Saves .previews/<tag>_<i>.png looking around the horizon (and prints creature info per view).
func run(game: Node) -> void:
	var tag := "pano"
	var n := 4
	var wait := 6.0
	var pitch := 5.0
	var eye := 1.7
	var fov := 75.0
	var yaw0 := 0.0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--tag="):
			tag = s.substr(6)
		elif s.begins_with("--n="):
			n = int(s.substr(4))
		elif s.begins_with("--wait="):
			wait = float(s.substr(7))
		elif s.begins_with("--pitch="):
			pitch = float(s.substr(8))
		elif s.begins_with("--eye="):
			eye = float(s.substr(6))
		elif s.begins_with("--fov="):
			fov = float(s.substr(6))
		elif s.begins_with("--yaw0="):
			yaw0 = float(s.substr(7))
	var tree: SceneTree = game.get_tree()
	await tree.create_timer(wait).timeout
	var cam: Node3D = game.freecam
	var fm: FaunaManager = game.fauna
	var cam3: Camera3D = Game.active_camera()
	cam3.fov = fov
	var p0 := cam.global_position
	var up := p0.normalized()
	var pl := Frame.anchor_node() as Planet
	if pl != null:
		cam.global_position = up * (pl.terrain_radius_at(up) + eye)
	p0 = cam.global_position
	var east := up.cross(Vector3.UP).normalized()
	if east.length() < 0.1:
		east = up.cross(Vector3.RIGHT).normalized()
	var north := up.cross(east).normalized()
	for i in n:
		var yaw := deg_to_rad(yaw0 + 360.0 * float(i) / float(n))
		var f := (north * cos(yaw) + east * sin(yaw)).normalized()
		var fl := (f * cos(deg_to_rad(pitch)) + up * sin(deg_to_rad(pitch))).normalized()
		cam.look_at_from_position(p0, p0 + fl, up)
		for k in 12:
			await tree.process_frame
		await tree.create_timer(0.3).timeout
		var vis := 0
		var cr_view := cam3
		for c in fm.creatures.values():
			var cp: Vector3 = (c as Node3D).global_position
			if cr_view.is_position_in_frustum(cp) and cp.distance_to(p0) < 260.0:
				vis += 1
		var path := ProjectSettings.globalize_path("res://.previews/%s_%d.png" % [tag, i])
		cam.get_viewport().get_texture().get_image().save_png(path)
		print("[life_pano] view ", i, " yaw=", rad_to_deg(yaw), " creatures in view <260m: ", vis, " total=", fm.creature_count(), " weather=", Game.weather.kind, " int=%.2f" % Game.weather.intensity, " fps=", Engine.get_frames_per_second())
	print("[life_pano] done")
