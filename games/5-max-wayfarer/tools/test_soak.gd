extends Node
# Memory soak test (run it HEADLESS through tools/run_godot.ps1 - no GPU, memory-capped): visits every landable world on foot,
# sweeps the day, then flies fast and low over a planet, and prints the memory in use so that leaks / runaway allocations show up.
var main: Node
var world: SpaceWorld
var pc: PlayerController
var peak_mb: int = 0
var flight_s: float = 14.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--flight="):
			flight_s = float(a.substr(9))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	pc = main.pc
	_run()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _stats(tag: String) -> void:
	var mb: int = int(OS.get_static_memory_usage() / 1048576)
	peak_mb = maxi(peak_mb, mb)
	var info: String = ""
	if world.frame_idx >= 0:
		var pl: Planet = world.planets[world.frame_idx]
		info = "%s chunks=%d visible=%d jobs=%d" % [pl.data.name, pl.terrain.chunks.size(), pl.terrain.stat_visible, pl.terrain.pending_jobs()]
	print("[%s] mem=%dMB peak=%dMB nodes=%d  frame=%d  %s" % [tag, mb, peak_mb, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), world.frame_idx, info])

func _run() -> void:
	await _wait(1.0)
	main._on_start_game()
	await _wait(2.0)
	_stats("start")
	for idx in world.sys.bodies.size():
		var b: BodyData = world.sys.bodies[idx]
		if not b.landable:
			continue
		world.time = 0.0
		pc.spawn_landed(idx, 0, false)
		await _wait(2.5)
		_stats("landed " + b.name)
		var t0: float = world.time
		for i in 48:
			world.time = t0 + b.spin_period * float(i) / 48.0
			await get_tree().process_frame
		await _wait(1.0)
		_stats("day swept " + b.name)
	# fast low flight over Eden: the terrain streams a lot of chunks (look-ahead prefetch)
	pc.spawn_flying_near(2, 350.0)
	await _wait(1.5)
	var t_end: float = Time.get_ticks_msec() + flight_s * 1000.0
	var step: int = 0
	while float(Time.get_ticks_msec()) < t_end:
		var ship: Ship = pc.ship
		if ship.state == Ship.State.FLYING and world.frame_idx >= 0:
			var up: Vector3 = ship.position.normalized()
			var side: Vector3 = up.cross(Vector3(0.3, 0.1, 1.0).normalized()).normalized()
			ship.velocity = side * 190.0 - up * clampf((world.altitude - 120.0) * 0.1, -30.0, 30.0)
		await get_tree().process_frame
		step += 1
		if step % 120 == 0:
			_stats("flight alt=%d" % int(world.altitude))
	_stats("end")
	print("SOAK DONE peak=%dMB" % peak_mb)
	get_tree().quit()
