extends RefCounted
## Atmospheric entry test: dive into Verdant's atmosphere at ~1.1 km/s; prints heat / speed / state and takes screenshots.
## godot ... -- --autostart --preset=air:1:4600 --test=res://tests/ship_entry.gd

func run(game: Node) -> void:
	var ship: Ship = game.ship
	var up := ship.global_position.normalized()
	var dive := (-up * 0.55 + (-ship.global_transform.basis.z) * 0.83).normalized()
	ship.global_transform.basis = Basis.looking_at(dive, up)
	ship.velocity = dive * 1150.0
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var shots := [0.5, 1.5, 2.5, 3.5]
	var t := 0.0
	var max_heat := 0.0
	var saw_state := false
	var si := 0
	while t < 6.0:
		await game.get_tree().process_frame
		t += game.get_process_delta_time()
		max_heat = maxf(max_heat, ship.heat)
		if str(Game.tel.get("state", "")) == "ATMOSPHERIC ENTRY":
			saw_state = true
		if si < shots.size() and t >= shots[si]:
			var img := game.get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://.previews/entry_%d.png" % si))
			print("[entry] t=%.1f heat=%.2f speed=%.0f alt=%.0f state=%s hull=%.2f" % [t, ship.heat, Game.tel.get("speed", 0.0), Game.tel.get("altitude", 0.0), Game.tel.get("state", ""), Game.ship_hull])
			si += 1
		if ship.is_landed:
			break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	print("[entry] max_heat=%.2f saw_ATMOSPHERIC_ENTRY=%s" % [max_heat, str(saw_state)])
	print("PASS entry" if max_heat > 0.5 and saw_state else "FAIL entry")
