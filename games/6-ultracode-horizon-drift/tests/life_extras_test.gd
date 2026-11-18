extends RefCounted
## SystemExtras visual test.  --test=res://tests/life_extras_test.gd --freecam --preset=freecam:1:3 --scene=station|freighter|freighter2|sat|belt|ring|cluster --tag=x
## Parks the free camera next to the chosen object (tracking it for a moment) and writes .previews/<tag>_<n>.png
func run(game: Node) -> void:
	var tag := "extras"
	var scene := "station"
	var dist := 0.0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--tag="):
			tag = s.substr(6)
		elif s.begins_with("--scene="):
			scene = s.substr(8)
		elif s.begins_with("--dist="):
			dist = float(s.substr(7))
	var tree: SceneTree = game.get_tree()
	await tree.create_timer(1.5).timeout
	var ex: SystemExtras = game.system_node.get_node("Extras")
	print("[life_extras] station=", ex.station != null, " freighters=", ex.freighters.size(), " sats=", ex.satellites.size(), " fields=", ex.fields.size())
	for f in ex.fields:
		print("[life_extras]   field ", f.label, " kind=", f.kind, " shape=", f.shape)
	var cam: Node3D = game.freecam
	var target: Node3D = null
	var d := dist
	match scene:
		"station":
			target = ex.station
			d = d if d > 0.0 else 420.0
		"freighter":
			target = ex.freighters[0]
			d = d if d > 0.0 else 330.0
		"freighter2":
			target = ex.freighters[1] if ex.freighters.size() > 1 else null
			d = d if d > 0.0 else 330.0
		"sat":
			target = ex.satellites[0]
			d = d if d > 0.0 else 40.0
	if target != null:
		for k in 4:
			for i in 40:
				await tree.process_frame
				var tp := target.global_position
				var up := tp.normalized()
				var sun := Frame.sun_dir
				var side := sun.cross(up).normalized()
				cam.global_position = tp + (sun * 0.7 + side * 0.5 + up * 0.25).normalized() * d
				cam.look_at(tp, up)
			await tree.process_frame
			await tree.process_frame
			cam.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.previews/%s_%d.png" % [tag, k]))
			d *= 0.55 if k < 2 else 1.0
			print("[life_extras] shot ", k, " dist=", d, " target=", target.name, " pos=", target.global_position)
	else:
		var f: AsteroidField = null
		var kind_want: String = scene
		for fl in ex.fields:
			if fl.kind == kind_want:
				f = fl
		if f == null:
			print("[life_extras] no field of kind ", scene)
			return
		var abs_pos: DVec
		var t := Universe.time
		if scene == "belt":
			var r0: float = f.shape["r0"]
			abs_pos = DVec.new(r0 * cos(0.7), 0.0, r0 * sin(0.7))
			Frame.set_space_frame(abs_pos)
			cam.global_position = Vector3.ZERO
		elif scene == "ring":
			var bi: int = -1
			for b in Universe.system.bodies:
				if b.kind == BodyDef.Kind.GAS_GIANT and b.has_rings:
					bi = b.index
			Frame.set_body_frame(bi)
			var rmid: float = (float(f.shape["rin"]) + float(f.shape["rout"])) * 0.5
			cam.global_position = Vector3(rmid, 150.0, 0.0)
			cam.look_at(Vector3(rmid, 100.0, -1000.0), Vector3.UP)
		else:
			var c: DVec = f.center_fn.call(t)
			abs_pos = c.add_v3(Vector3(5000.0, 400.0, 0.0))
			Frame.set_space_frame(abs_pos)
			cam.global_position = Vector3.ZERO
			cam.look_at(Vector3(-5000.0, -400.0, 0.0), Vector3.UP)
		for k in 3:
			await tree.create_timer(2.0).timeout
			print("[life_extras] rocks=", f.rock_count(), " active=", f.active, " cache=", f._cache.size(), " fps=", Engine.get_frames_per_second())
			cam.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.previews/%s_%d.png" % [tag, k]))
			if k == 1:
				cam.rotate_y(0.9)
	print("[life_extras] done")
