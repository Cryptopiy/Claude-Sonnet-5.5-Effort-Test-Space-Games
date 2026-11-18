extends RefCounted
## probes: (1) jump right after sprint, (2) time until the collision patch is ready after a teleport
var g: Node
func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout
func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	await _wait(1.0)
	# --- jump probe
	for trial in 3:
		Input.action_press("move_up")
		await _wait(0.12)
		Input.action_release("move_up")
		var mx := 0.0
		var t := 0.0
		while t < 1.4:
			await g.get_tree().process_frame
			t += g.get_process_delta_time()
			mx = maxf(mx, float(Game.tel.get("altitude", 0.0)))
		print("[probe2] jump trial ", trial, " max alt ", mx, " grounded=", p._grounded, " crouch=", p._crouching, " jump_buffer=", p._jump_buffer, " coyote=", p._coyote, " fuel=", p.vitals.jetpack, " exhausted=", p.vitals.exhausted)
		await _wait(0.5)
	# --- teleport probe
	var dirs := [Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(-0.3, 0.2, -0.9).normalized(), Vector3(0.7, -0.6, 0.4).normalized()]
	for d in dirs:
		var gr := planet.terrain_radius_at(d)
		p.spawn_at(d * (gr + 3.0), d, d.cross(Vector3.RIGHT) if absf(d.x) < 0.9 else d.cross(Vector3.UP))
		var t0 := Time.get_ticks_msec()
		var ready_t := -1.0
		var land_t := -1.0
		while Time.get_ticks_msec() - t0 < 8000:
			await g.get_tree().process_frame
			var tt := (Time.get_ticks_msec() - t0) / 1000.0
			if ready_t < 0.0 and planet.is_collision_ready(p.global_position):
				ready_t = tt
			if land_t < 0.0 and absf(float(Game.tel.get("altitude", 9.0))) < 0.3:
				land_t = tt
				break
		print("[probe2] teleport ", d, " ready after ", ready_t, " s, landed after ", land_t, " s, alt=", Game.tel.get("altitude"))
