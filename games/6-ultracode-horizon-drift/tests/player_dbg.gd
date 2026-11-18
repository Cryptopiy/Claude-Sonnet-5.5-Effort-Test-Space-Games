extends RefCounted
var g: Node
func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	await g.get_tree().create_timer(1.5).timeout
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t := 0.0
	var last_log := 0.0
	var frozen_frames := 0
	var total := 0
	var worst_dt := 0.0
	while t < 14.0:
		await g.get_tree().process_frame
		var dt := g.get_process_delta_time()
		t += dt
		total += 1
		worst_dt = maxf(worst_dt, dt)
		if Game.tel["speed"] < 1.0:
			frozen_frames += 1
		if t - last_log > 1.0:
			last_log = t
			print("t=%.1f ready=%s speed=%.1f alt=%.2f unready_t=%.2f fps=%d" % [t, str(planet.is_collision_ready(p.global_position)), Game.tel["speed"], Game.tel["altitude"], p._unready_t, Engine.get_frames_per_second()])
	print("frozen frames: ", frozen_frames, " of ", total, " worst dt ", worst_dt)
