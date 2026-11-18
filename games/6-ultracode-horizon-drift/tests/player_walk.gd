extends RefCounted
## M4: long walks on the real terrain. (a) sprint 70 s from the spawn (collision patch must follow, no sinking, no frozen frames),
## (b) cross the north pole on foot (up vector must stay smooth, no singularity), (c) bump into props (walk straight into trees/rocks).
## usage: --preset=foot:1 --test=res://tests/player_walk.gd [--timescale=2]
var g: Node

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _walk(p: Player, planet: Planet, seconds: float, label: String, turn_when_swimming: bool) -> void:
	var t := 0.0
	var next_log := 0.0
	var min_alt := 1.0e9
	var max_alt := -1.0e9
	var max_up_step := 0.0
	var frozen := 0
	var frames := 0
	var not_ready := 0
	var prev_up := p.global_transform.basis.y
	var start := p.global_position
	var swim_frames := 0
	var stuck := 0
	var last_pos := p.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	while t < seconds:
		await g.get_tree().process_frame
		var dt: float = g.get_process_delta_time()
		t += dt
		frames += 1
		var alt := float(Game.tel.get("altitude", 0.0))
		if not p._swimming:
			min_alt = minf(min_alt, alt)
			max_alt = maxf(max_alt, alt)
		else:
			swim_frames += 1
		var u := p.global_transform.basis.y
		max_up_step = maxf(max_up_step, acos(clampf(u.dot(prev_up), -1.0, 1.0)))
		prev_up = u
		if float(Game.tel.get("speed", 0.0)) < 1.0:
			frozen += 1
		if not planet.is_collision_ready(p.global_position):
			not_ready += 1
		if turn_when_swimming and p._swimming:
			p.debug_look(0.8 * dt, 0.0)       # steer away from the sea (rate limited)
		if t >= next_log:
			next_log += 5.0
			var moved := p.global_position.distance_to(last_pos)
			last_pos = p.global_position
			print("[walk:%s] t=%4.1f alt=%6.2f speed=%4.1f state=%s ready=%s dist_from_start=%.0f r=%.1f" % [label, t, alt, float(Game.tel.get("speed", 0.0)), str(Game.tel.get("foot_state", "")), str(planet.is_collision_ready(p.global_position)), p.global_position.distance_to(start), p.global_position.length()])
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("[walk:%s] DONE frames=%d frozen=%d not_ready=%d swim=%d min_alt(walking)=%.2f max_alt=%.2f max_up_step=%.5f rad moved=%.0f m" % [label, frames, frozen, not_ready, swim_frames, min_alt, max_alt, max_up_step, p.global_position.distance_to(start)])
	print("%s walk never below ground (%.2f)" % ["PASS" if min_alt > -0.35 else "FAIL", min_alt])
	print("%s up vector smooth (%.5f)" % ["PASS" if max_up_step < 0.004 else "FAIL", max_up_step])

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	await _wait(1.0)
	# (a) straight sprint from the pad (skipped with --poleonly)
	if not OS.get_cmdline_user_args().has("--poleonly"):
		await _walk(p, planet, 60.0, "a", true)
	# (b) over the north pole: start 250 m before it, walking toward it
	var pole := Vector3.UP
	var start_dir := (pole + Vector3(1, 0, 0) * (250.0 / planet.radius)).normalized()
	var gr := planet.terrain_radius_at(start_dir)
	var fwd := (pole - start_dir * start_dir.dot(pole)).normalized()
	p.spawn_at(start_dir * (gr + 1.0), start_dir, fwd)
	await _wait(1.0)
	await _walk(p, planet, 40.0, "pole", true)
	var up_err: float = acos(clampf(p.global_transform.basis.y.dot(p.global_position.normalized()), -1.0, 1.0))
	print("%s up vector radial after pole crossing (%.5f rad)" % ["PASS" if up_err < 0.002 else "FAIL", up_err])
