extends Node
# Logic smoke test (run it HEADLESS through tools/run_godot.ps1 - no GPU, memory-capped): starts the real main scene, then loads
# a series of generated systems (orbital points of interest, gas giants, black holes ...) and prints a summary together with the
# memory in use, so leaks show up as growing numbers. Script errors show up in the log.
var main: Node
var world: SpaceWorld
var only: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--systems="):
			for t in a.substr(10).split(","):
				only.append(int(t))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	_run()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _mem() -> String:
	return "mem=%dMB nodes=%d objs=%d" % [int(OS.get_static_memory_usage() / 1048576), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))]

func _chunks() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var total: int = 0
	for p in world.planets:
		var pl: Planet = p
		if pl.terrain != null:
			total += pl.terrain.chunks.size()
			if pl.terrain.chunks.size() > 60:
				parts.append("%s:%d" % [pl.data.name, pl.terrain.chunks.size()])
	return "chunks=%d (%s)" % [total, ", ".join(parts)]

func _run() -> void:
	await _wait(1.0)
	main._on_start_game()
	await _wait(2.0)
	print("home: bodies=%d pois=%d  %s  %s" % [world.sys.bodies.size(), _count_pois(world.sys), _mem(), _chunks()])
	var picks: Array = [1, 17, 120, 333, 640, 901, 1288, 1500, 1777, 2100, 2333, 2599]
	var g: Galaxy = Galaxy.get_galaxy()
	for s in g.bh_systems.slice(1, 6):
		picks.append(s)
	if not only.is_empty():
		picks = only
	for idx in picks:
		print("-> jumping to system ", idx)
		main._transport(int(idx), "warp")
		await _wait(1.5)
		var sys: SystemData = world.sys
		print("system %d %s class %s: bodies=%d landable=%d pois=%d bh=%s  %s  %s" % [idx, sys.name, sys.star_class, sys.bodies.size(), sys.landable_bodies().size(), _count_pois(sys), str(sys.has_black_hole), _mem(), _chunks()])
	print("SMOKE DONE")
	get_tree().quit()

func _count_pois(sys: SystemData) -> int:
	var n: int = 0
	for b in sys.bodies:
		n += (b as BodyData).pois.size()
	return n
