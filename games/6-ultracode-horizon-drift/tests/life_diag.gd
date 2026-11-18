extends RefCounted
## Life diagnostics: prints weather / fauna state every second and saves screenshots.
## --test=res://tests/life_diag.gd --tag=x [--secs=12] [--shots=4,8,12] [--look=<pitch deg>]
func run(game: Node) -> void:
	var tag := "diag"
	var secs := 12
	var look := 999.0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--tag="):
			tag = s.substr(6)
		elif s.begins_with("--secs="):
			secs = int(s.substr(7))
		elif s.begins_with("--look="):
			look = float(s.substr(7))
	var tree: SceneTree = game.get_tree()
	var w: WeatherFX = Game.weather
	var fa: FaunaManager = Game.fauna
	for i in secs:
		await tree.create_timer(1.0).timeout
		var cam := Game.active_camera()
		var fp := Vector3.ZERO
		if Frame.focus != null:
			fp = Frame.focus.global_position
		var near := 0
		var nearest := 1e9
		for c in fa.creatures.values():
			var d: float = (c as Node3D).position.distance_to(fp)
			nearest = minf(nearest, d)
			if d < 150.0:
				near += 1
		if i == 0:
			print("[life_diag] weather enabled=", w.enabled, " state=", Game.state, " sys=", Universe.system != null, " cam=", cam, " world=", is_instance_valid(Game.world),
				" proc=", w.is_processing(), " layers=", w._layers.size(), " prof=", w._profile, " force=", w._force, " tree_paused=", tree.paused)
		var alt := 0.0
		var pl := Frame.anchor_node() as Planet
		var sea := 0.0
		var gr := 0.0
		if pl != null:
			alt = pl.altitude_of(fp)
			sea = pl.sea_radius()
			gr = pl.terrain_radius_at(fp.normalized())
		print("[life_diag] sea=%.1f focus_r=%.1f ground_r=%.1f R=%.1f" % [sea, fp.length(), gr, pl.radius if pl != null else 0.0])
		print("[life_diag] t=%d anchor=%d alt=%.0f weather=%s int=%.2f fog=%.2f wind=%.1f creatures=%d near150=%d nearest=%.0f fps=%d" % [
			i + 1, Frame.anchor, alt, w.kind, w.intensity, w.fog_boost, w.wind.length(), fa.creature_count(), near, nearest, Engine.get_frames_per_second()])
		if look < 900.0 and cam != null and i == 2:
			cam.rotation_degrees.x = look
	print("[life_diag] done")
