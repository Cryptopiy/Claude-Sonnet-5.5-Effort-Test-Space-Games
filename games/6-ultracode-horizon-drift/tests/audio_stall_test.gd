extends RefCounted
## AUDIO stall / leak test (module M8): does building the sound bank on its worker thread hitch the main thread, and does steady playback leak?
## Run it twice and compare the printed frame-time statistics (the terrain is streaming in during the first seconds in both runs, so only the DIFFERENCE is audio):
##   ... -GodotArgs "--resolution 640x360 -- --autostart --preset=air:1:900 --audio-build --test=res://tests/audio_stall_test.gd"     (bank builds in the background)
##   ... -GodotArgs "--resolution 640x360 -- --autostart --preset=air:1:900 --test=res://tests/audio_stall_test.gd"                   (default muted run: nothing is built)
## Phase A = frames while the bank is still building (or the first 14 s), phase B = 8 s afterwards (engine + ambience + one-shots running).
## Checks that no frame in phase B exceeds 80 ms and that the object / node counts do not grow in phase B (no per-frame node or resource allocation).

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if not c:
		_fails += 1
	print(("PASS " if c else "FAIL ") + m)

func _stats(label: String, d: PackedFloat32Array) -> Dictionary:
	if d.is_empty():
		print("[stall] %s: no frames" % label)
		return {"max": 0.0, "p99": 0.0}
	var s := d.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	var p95: float = s[int(float(s.size() - 1) * 0.95)]
	var p99: float = s[int(float(s.size() - 1) * 0.99)]
	print("[stall] %-26s frames=%4d mean=%5.1f ms  p95=%5.1f  p99=%5.1f  max=%6.1f ms" % [label, s.size(), sum / float(s.size()), p95, p99, s[s.size() - 1]])
	return {"max": s[s.size() - 1], "p99": p99}

func run(game: Node) -> void:
	var tree: SceneTree = game.get_tree()
	var audio: Node = tree.root.get_node("Audio")
	var bank: AudioSoundBank = audio.get("bank")
	print("[stall] bank started=%s (build thread %s)" % [str(bank.is_started()), "running" if bank.is_started() else "not started: muted default run"])
	var a := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	var t_begin := Time.get_ticks_msec()
	await tree.process_frame
	while Time.get_ticks_msec() - t_begin < 14000 and (not bank.is_started() or not bank.is_complete()):
		await tree.process_frame
		var now := Time.get_ticks_usec()
		a.append(float(now - last) / 1000.0)
		last = now
	print("[stall] phase A ended after %.1f s (bank complete=%s, %d sounds)" % [(Time.get_ticks_msec() - t_begin) / 1000.0, str(bank.is_complete()), bank.ready_count()])
	_stats("A: while building", a)
	# phase B: everything audible at once
	var b := PackedFloat32Array()
	var ev_calls := 0
	var objs0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var t_b := Time.get_ticks_msec()
	last = Time.get_ticks_usec()
	var frame := 0
	while Time.get_ticks_msec() - t_b < 8000:
		await tree.process_frame
		var now2 := Time.get_ticks_usec()
		b.append(float(now2 - last) / 1000.0)
		last = now2
		frame += 1
		audio.call("set_engine", 0.7, frame % 600 > 300, false, 0.6, 250.0)
		audio.call("set_ambient", "lush", 0.6, 0.0, false)
		if frame % 45 == 0:
			audio.call("footstep", "grass", false)
			audio.call("sfx", "ui_click")
			ev_calls += 2
		if frame % 200 == 0:
			audio.call("sfx", "scan_ping", Vector3(4, 1, -6))
	var st_b := _stats("B: steady playback", b)
	var objs1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	print("[stall] objects %d -> %d, nodes %d -> %d, static memory %.1f MB -> %.1f MB, played %d one-shots" % [objs0, objs1, nodes0, nodes1, mem0 / 1048576.0, mem1 / 1048576.0, ev_calls])
	_ok(float(st_b["max"]) < 80.0, "no frame hitch above 80 ms while only audio runs (max %.1f ms)" % float(st_b["max"]))
	_ok(objs1 - objs0 <= 24, "object count stable in steady playback (+%d)" % (objs1 - objs0))
	_ok(nodes1 - nodes0 <= 14, "node count stable in steady playback (+%d: 3D voice pool fills up to its cap, nothing else grows)" % (nodes1 - nodes0))
	_ok(mem1 - mem0 < 24 * 1048576, "static memory does not balloon in steady playback (+%.1f MB)" % ((mem1 - mem0) / 1048576.0))
	print("[stall] RESULT fails=%d" % _fails)
