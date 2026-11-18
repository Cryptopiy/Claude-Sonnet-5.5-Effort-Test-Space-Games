extends RefCounted
## throwaway probe: why does the engine voice stay silent when set_engine() is called on an un-piloted, "landed=false" ship?
func run(game: Node) -> void:
	var tree: SceneTree = game.get_tree()
	var audio: Node = tree.root.get_node("Audio")
	var ev: AudioEngineVoice = audio.get("engine_voice")
	var ship: Node3D = Game.ship
	print("[dbg] mode=", Game.mode, " state=", Game.state, " ship=", ship, " is_landed=", ship.get("is_landed"), " piloted=", ship.get("piloted"))
	ship.set("is_landed", false)
	print("[dbg] after set: is_landed=", ship.get("is_landed"))
	for i in 40:
		audio.call("set_engine", 0.8, true, false, 0.5, 300.0)
		await tree.process_frame
		if i % 8 == 0:
			print("[dbg] i=%d ship.is_landed=%s ev._on=%s fresh=%s on_gain=%.3f thr=%.2f piloted=%s" % [i, str(ship.get("is_landed")), str(ev._on), str(Time.get_ticks_msec() - ev.last_call_ms < 450), ev._on_gain, ev.s_throttle, str(ship.get("piloted"))])
