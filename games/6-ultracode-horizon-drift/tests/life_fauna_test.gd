extends RefCounted
## Fauna visual test: finds one creature of every species and shoots it from close up with the free cam.
##   --test=res://tests/life_fauna_test.gd --freecam --preset=freecam:<body>:3 --fauna=8   (args after the test: shots go to .previews/fauna_<n>_<species>.png)
func run(game: Node) -> void:
	var tag := "fauna"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--tag="):
			tag = String(a).substr(6)
	await game.get_tree().create_timer(4.0).timeout
	var fm: FaunaManager = game.fauna
	fm.debug_threat_scale = 0.0
	var counts: Dictionary = {}
	for c in fm.creatures.values():
		counts[c.species] = int(counts.get(c.species, 0)) + 1
	print("[life_fauna] creatures=", fm.creature_count(), " per species=", counts)
	var cam: Node3D = game.freecam
	var shot_i := 0
	for sp in ["grazer", "crawler", "floater", "flyer"]:
		var best: Creature = null
		var bd := 1e9
		for c in fm.creatures.values():
			if c.species == sp and not c.dying:
				var d: float = c.position.distance_to(cam.global_position)
				if d < bd:
					bd = d
					best = c
		if best == null:
			print("[life_fauna] no ", sp)
			continue
		for k in 3:
			var up := best.position.normalized()
			var side := best.global_transform.basis.x
			var fwd := -best.global_transform.basis.z
			var off := (side * 3.2 + up * (1.6 if sp != "flyer" else 2.0) - fwd * 4.0) * (1.0 if sp != "flyer" else 3.0)
			if sp == "floater":
				off *= 1.6
			cam.global_position = best.position + off
			cam.look_at(best.position + up * (0.9 if sp != "floater" and sp != "flyer" else 0.0), up)
			await game.get_tree().create_timer(0.5).timeout
			if k == 0:
				print("[life_fauna] cam node pos=", cam.global_position, " viewport cam=", cam.get_viewport().get_camera_3d().get_path(), " cam gpos=", cam.get_viewport().get_camera_3d().global_position, " target=", best.position)
			var img: Image = cam.get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path("res://.previews/%s_%s_%d.png" % [tag, sp, k])
			img.save_png(path)
			shot_i += 1
		print("[life_fauna] shot ", sp, " at dist ", bd, " label=", best.label)
	print("[life_fauna] done shots=", shot_i)
