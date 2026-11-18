extends RefCounted
## Integration test with the REAL ship / player / world: flies a short scripted route and logs what the audio manager does.
##   powershell -NoProfile -File tools/godot.ps1 -Project "<sandbox>" -Mode run -TimeoutSec 120 -Tag audioship -GodotArgs "--resolution 640x360 -- --autostart --preset=air:1:900 --audio-build --test=res://tests/audio_ship_test.gd"
var _fails := 0

func _ok(c: bool, m: String) -> void:
	if not c:
		_fails += 1
	print(("PASS " if c else "FAIL ") + m)

func _tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await Engine.get_main_loop().create_timer(0.15).timeout
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)

func run(game: Node) -> void:
	var tree: SceneTree = game.get_tree()
	var audio: Node = tree.root.get_node("Audio")
	var bank: AudioSoundBank = audio.get("bank")
	var guard := 0
	while not bank.is_complete() and guard < 300:
		await tree.create_timer(0.25).timeout
		guard += 1
	var ev: AudioEngineVoice = audio.get("engine_voice")
	Events.notify.connect(func(t: String, k: String) -> void: print("[toast] ", k, ": ", t))
	Events.pulse_changed.connect(func(a: bool) -> void: print("[event] pulse_changed ", a))
	Events.gear_changed.connect(func(a: bool) -> void: print("[event] gear_changed ", a))
	print("[ship_test] sounds ready=", bank.ready_count(), " mode=", game.get("mode"), " anchor=", Frame.anchor)
	await tree.create_timer(1.5).timeout
	_ok(ev.is_running(), "engine running while flying (on_gain=%.2f, fallback=%s)" % [ev._on_gain, str(ev.using_fallback)])
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 6:
		await tree.create_timer(0.7).timeout
		var r: AudioLoopVoice = ev.layers["eng_rumble"]
		var w: AudioLoopVoice = ev.layers["eng_whine"]
		var b: AudioLoopVoice = ev.layers["eng_boost"]
		var rush: AudioLoopVoice = ev.layers["eng_wind"]
		print("[ship_test] t=%d speed=%.0f thr=%.2f boost=%.2f dens=%.2f | rumble g=%.2f p=%.2f | whine g=%.2f p=%.2f | boost g=%.2f | rush g=%.2f" % [i, ev.s_speed, ev.s_throttle, ev.s_boost, ev.s_dens, r.gain, r.pitch, w.gain, w.pitch, b.gain, rush.gain])
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await tree.create_timer(0.5).timeout
	await _tap("pulse_drive")
	await tree.create_timer(0.3).timeout
	print("[ship_test] tel pulse=", Game.tel.get("pulse"), " speed=", Game.tel.get("speed"), " fuel=", Game.ship_fuel)
	Input.action_press("move_forward")
	await tree.create_timer(2.5).timeout
	print("[ship_test] after pulse key: status=", audio.call("status"))
	await _tap("landing_gear")
	await tree.create_timer(1.0).timeout
	Input.action_release("move_forward")
	await tree.create_timer(1.0).timeout
	var st: Dictionary = audio.call("status")
	print("[ship_test] final status: ", st)
	var calls: Dictionary = st["calls"]
	_ok(int(calls.get("gear_down", 0)) + int(calls.get("gear_up", 0)) >= 1, "gear key -> gear sound via Events (gear_down=%d gear_up=%d)" % [int(calls.get("gear_down", 0)), int(calls.get("gear_up", 0))])
	_ok(int(calls.get("pulse_on", 0)) >= 1, "pulse key -> pulse_on sound (%d)" % int(calls.get("pulse_on", 0)))
	_ok(not ev.layers.is_empty() and (ev.layers["eng_rumble"] as AudioLoopVoice).playing, "rumble layer is playing")
	print("[ship_test] RESULT fails=", _fails)
