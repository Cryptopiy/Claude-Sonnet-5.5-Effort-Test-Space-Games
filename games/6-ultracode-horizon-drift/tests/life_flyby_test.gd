extends RefCounted
## Teleports the (real) ship next to the station / a freighter / a satellite and shoots it.  --test=res://tests/life_flyby_test.gd --preset=air:1:12000 --tag=x
func run(game: Node) -> void:
	var tag := "flyby"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--tag="):
			tag = String(a).substr(6)
	var tree: SceneTree = game.get_tree()
	await tree.create_timer(2.0).timeout
	var ex: SystemExtras = game.system_node.get_node("Extras")
	var ship: Node3D = game.ship
	var targets: Array = [ex.station, ex.freighters[0], ex.satellites[0]]
	var dists: Array = [500.0, 380.0, 60.0]
	var n := 0
	for i in targets.size():
		var tg: Node3D = targets[i]
		for k in 2:
			for f in 30:
				await tree.process_frame
				var tp := tg.global_position
				var up := tp.normalized()
				var sun := Frame.sun_dir
				var side := sun.cross(up).normalized()
				var pos := tp + (sun * 0.8 + side * 0.4 + up * 0.15).normalized() * float(dists[i]) * (1.0 if k == 0 else 0.6)
				ship.global_transform = Transform3D(Basis.looking_at((tp - pos).normalized(), up), pos)
				if "velocity" in ship:
					ship.velocity = Vector3.ZERO
			await tree.create_timer(0.3).timeout
			ship.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.previews/%s_%d.png" % [tag, n]))
			n += 1
	print("[life_flyby] done ", n, " shots; fps=", Engine.get_frames_per_second())
