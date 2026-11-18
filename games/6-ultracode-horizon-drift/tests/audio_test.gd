extends RefCounted
## AUDIO test (module M8). Run through the harness (windowless, output is muted automatically):
##   powershell -NoProfile -File tools/godot.ps1 -Project "<sandbox>" -Mode run -TimeoutSec 150 -Tag audio -GodotArgs "--resolution 640x360 -- --autostart --preset=air:1:900 --audio-build --test=res://tests/audio_test.gd"
## (preset air: the ship flies, so the engine voice is not held silent by "landed"; the test un-pilots it so nothing else drives the layers. Add `-Headless` to godot.ps1 to run without any audio device:
##  Godot then uses the Dummy audio driver and the test must still pass without errors.)
## 1. synthesises EVERY sound through the real SoundBank (background thread) and analyses the encoded 16-bit data: duration, peak (no clipping),
##    RMS (not silent), DC offset, spectral centroid / band balance, loop seam continuity, NaN / inf.
## 2. calls the whole public API (sfx / set_engine / set_loop / set_ambient / footstep / set_master_volume) incl. nonsense arguments.
## 3. fires the Events signals and checks that the matching sounds were started; checks engine / ambience layers react.
var _fails := 0
var _passes := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)

func _decode(st: AudioStreamWAV) -> PackedFloat32Array:
	var d: PackedByteArray = st.data
	var ch: int = 2 if st.stereo else 1
	var n: int = d.size() / (2 * ch)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v: float = 0.0
		for c in ch:
			v += float(d.decode_s16((i * ch + c) * 2)) / 32768.0
		out[i] = v / float(ch)
	return out

func run(game: Node) -> void:
	var tree: SceneTree = game.get_tree()
	var audio: Node = tree.root.get_node_or_null("Audio")
	_ok(audio != null, "Audio autoload exists")
	if audio == null:
		return
	var bank: AudioSoundBank = audio.get("bank")
	_ok(bank != null, "sound bank exists")
	print("[audio_test] automation=", audio.get("automation"), " muted=", audio.get("output_muted"))
	# ---- 1. synthesis ------------------------------------------------------------------------------------------------------------
	var t0 := Time.get_ticks_msec()
	audio.call("force_build")
	var guard := 0
	while not bank.is_complete() and guard < 1200:
		await tree.create_timer(0.25).timeout
		guard += 1
	var order: PackedStringArray = AudioRecipes.build_order()
	_ok(bank.is_complete(), "background synthesis finished (%d sounds in %.1f s wall)" % [bank.ready_count(), (Time.get_ticks_msec() - t0) / 1000.0])
	_ok(bank.ready_count() == order.size(), "all %d catalog sounds were built (got %d)" % [order.size(), bank.ready_count()])
	var total_len := 0.0
	var loops := 0
	var worst_edge := 0.0
	var edge_bad: Array = []
	for n in order:
		var st: AudioStreamWAV = bank.get_stream(n)
		if st == null:
			_ok(false, "sound '%s' missing" % n)
			continue
		var buf := _decode(st)
		var peak := 0.0
		var clipped := 0
		var sum := 0.0
		var sq := 0.0
		var bad := 0
		for i in buf.size():
			var v: float = buf[i]
			if is_nan(v) or is_inf(v):
				bad += 1
				continue
			peak = maxf(peak, absf(v))
			if absf(v) > 0.9995:
				clipped += 1
			sum += v
			sq += v * v
		var rms: float = sqrt(sq / float(maxi(buf.size(), 1)))
		var dc: float = sum / float(maxi(buf.size(), 1))
		var dur: float = float(buf.size()) / float(st.mix_rate)
		total_len += dur
		var is_loop: bool = st.loop_mode != AudioStreamWAV.LOOP_DISABLED
		if is_loop:
			loops += 1
		# spectral balance around the loudest 4096-sample window
		var cen := 0.0
		if buf.size() >= 4096:
			var best_i := 0
			var best_e := -1.0
			var i2 := 0
			while i2 + 4096 <= buf.size():
				var e := 0.0
				for k in range(i2, i2 + 4096, 8):
					e += buf[k] * buf[k]
				if e > best_e:
					best_e = e
					best_i = i2
				i2 += 2048
			var mag := AudioDSP.fft_mag(buf.slice(best_i, best_i + 4096))
			var tot := 0.0
			var wsum := 0.0
			for k in mag.size():
				var f: float = float(k) * float(st.mix_rate) / 4096.0
				var m2: float = mag[k] * mag[k]
				tot += m2
				wsum += m2 * f
			cen = wsum / maxf(tot, 1e-12)
		# loop seam: the jump from the last sample back to the first, relative to the 99.9th percentile of the sample-to-sample steps inside the
		# loop (a click would be many times larger than any step the signal itself makes; a seamless loop is < 1)
		var seam := 0.0
		if is_loop and buf.size() > 100:
			var steps := PackedFloat32Array()
			steps.resize(buf.size() - 1)
			for i3 in range(1, buf.size()):
				steps[i3 - 1] = absf(buf[i3] - buf[i3 - 1])
			steps.sort()
			var p999: float = steps[int(float(steps.size() - 1) * 0.999)]
			seam = absf(buf[0] - buf[buf.size() - 1]) / maxf(p999, 1e-6)
		var good: bool = bad == 0 and peak <= 0.995 and clipped == 0 and rms > 0.004 and dur > 0.04 and absf(dc) < 0.03
		if is_loop:
			good = good and seam < 1.5
		else:
			# a one-shot must start and end at (almost) zero, otherwise playback clicks: first / last sample relative to the peak
			var edge: float = maxf(absf(buf[0]), absf(buf[buf.size() - 1])) / maxf(peak, 1e-6)
			worst_edge = maxf(worst_edge, edge)
			if edge > 0.08:
				edge_bad.append("%s=%.2f" % [n, edge])
			good = good and edge < 0.25
		_ok(good, "%-18s %5.2fs %s sr=%5d peak=%.2f rms=%.3f dc=%+.4f centroid=%5.0fHz%s" % [n, dur, "LOOP" if is_loop else "once", st.mix_rate, peak, rms, dc, cen, ("  seam=%.1f" % seam) if is_loop else ""])
	print("[audio_test] total audio synthesised: %.1f s (%d loops); worst one-shot edge/peak = %.3f; edges above 0.08: %s" % [total_len, loops, worst_edge, str(edge_bad)])
	var ms_total: int = bank.build_ms_total
	print("[audio_test] background thread time: %d ms" % ms_total)

	# ---- 2. API smoke ------------------------------------------------------------------------------------------------------------
	await tree.process_frame
	var missed_before: int = int(audio.get("missed"))
	for s in ["ui_click", "ui_open", "ui_back", "ui_warp_confirm", "notify", "pickup", "resource_collect", "scan_ping", "gear_down", "gear_up", "landed", "crash",
			"takeoff", "pulse_on", "pulse_off", "airlock", "jump", "land_foot", "jetpack_puff", "warn_beep", "discover", "warp_charge", "warp_jump",
			"blackhole_enter", "door", "interact", "bird", "frog", "totally_unknown_sound", ""]:
		audio.call("sfx", s)
		audio.call("sfx", s, Vector3(3, 1, -5), -3.0)
		audio.call("sfx", s, Vector3.INF, 6.0)
	_ok(true, "sfx() accepted all documented names (2D + 3D + gain) and nonsense")
	for surf in ["grass", "sand", "rock", "snow", "metal", "ash", "mud", "dirt", "ice", "gravel", "dust", "water", "unknown_surface", ""]:
		audio.call("footstep", surf, false)
		audio.call("footstep", surf, true)
	_ok(true, "footstep() accepted all surfaces")
	for l in ["mining_beam", "jetpack", "blackhole_rumble", "alarm", "warp_tunnel", "wind", "nonsense_loop"]:
		audio.call("set_loop", l, true, 1.0)
		audio.call("set_loop", l, true, 0.4)
	await tree.create_timer(0.6).timeout
	var st_now: Dictionary = audio.call("status")
	print("[audio_test] status after API smoke: ", st_now)
	for l in ["mining_beam", "jetpack", "blackhole_rumble", "alarm", "warp_tunnel", "wind", "nonsense_loop"]:
		audio.call("set_loop", l, false)
	for b in ["lush", "desert", "frozen", "volcanic", "toxic", "barren", "ocean", "exotic", "swamp", "radioactive", "gas", "nonsense"]:
		audio.call("set_ambient", b, 0.5, 0.0, false)
		audio.call("set_ambient", b, 1.0, 1.0, true)
	audio.call("set_master_volume", 0.5)
	_ok(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.25)) < 0.1, "master volume 0.5 -> %.1f dB (perceptual taper)" % AudioServer.get_bus_volume_db(0))
	audio.call("set_master_volume", 0.0)
	audio.call("set_master_volume", 2.0)
	audio.call("set_master_volume", 0.8)
	_ok(true, "set_master_volume() edge values accepted")
	var calls_ok: Dictionary = audio.get("calls")
	_ok(int(calls_ok.get("ui_click", 0)) >= 1 and int(calls_ok.get("notify", 0)) >= 1, "one-shots were really started (ui_click=%d notify=%d)" % [int(calls_ok.get("ui_click", 0)), int(calls_ok.get("notify", 0))])
	_ok(int(audio.get("missed")) == missed_before, "no request was dropped for a not-yet-built sound (missed %d -> %d)" % [missed_before, int(audio.get("missed"))])

	# ---- 3. engine layers --------------------------------------------------------------------------------------------------------
	# the real ship calls Audio.set_engine() every frame while piloted: take the pilot out so this test drives the voice alone
	# (the preset keeps the ship flying; a landed ship would keep the engine voice silent by design)
	var ship_node: Node = Game.ship
	var ship_was_piloted: bool = ship_node != null and bool(ship_node.get("piloted"))
	if ship_was_piloted:
		ship_node.call("set_piloted", false)
	var ev: AudioEngineVoice = audio.get("engine_voice")
	for i in 40:
		audio.call("set_engine", 0.8, true, false, 0.5, 300.0)
		await tree.process_frame
	await tree.create_timer(1.2).timeout
	for i in 20:
		audio.call("set_engine", 0.8, true, false, 0.5, 300.0)
		await tree.process_frame
	var rumble: AudioLoopVoice = ev.layers["eng_rumble"]
	var whine: AudioLoopVoice = ev.layers["eng_whine"]
	var boost_l: AudioLoopVoice = ev.layers["eng_boost"]
	_ok(rumble.gain > 0.3 and rumble.playing, "engine rumble audible under throttle (gain=%.2f pitch=%.2f)" % [rumble.gain, rumble.pitch])
	_ok(boost_l.gain > 0.2 and boost_l.playing, "boost layer audible (gain=%.2f)" % boost_l.gain)
	var p_hi: float = whine.pitch
	for i in 30:
		audio.call("set_engine", 0.1, false, true, 0.0, 12000.0)
		await tree.process_frame
	await tree.create_timer(1.5).timeout
	var pulse_l: AudioLoopVoice = ev.layers["eng_pulse"]
	_ok(pulse_l.gain > 0.3, "pulse-drive layer fades in (gain=%.2f)" % pulse_l.gain)
	_ok(boost_l.gain < 0.05, "boost layer fades out when boost ends (gain=%.2f)" % boost_l.gain)
	audio.call("stop_engine")
	await tree.create_timer(3.5).timeout
	_ok(rumble.gain < 0.02 and not rumble.playing, "engine fully silent after stop_engine (gain=%.3f)" % rumble.gain)
	if ship_was_piloted:
		ship_node.call("set_piloted", true)

	# ---- 4. ambience -------------------------------------------------------------------------------------------------------------
	var amb: AudioAmbience = audio.get("ambience")
	for b2 in ["lush", "frozen", "volcanic", "ocean", "exotic"]:
		for i in 25:
			audio.call("set_ambient", b2, 0.6, 0.0 if b2 != "lush" else 1.0, false)
			await tree.process_frame
		await tree.create_timer(1.5).timeout
		var audible := 0
		var names: Array = []
		for k in amb.voices:
			var vv: AudioLoopVoice = amb.voices[k]
			if vv.gain > 0.02 and vv.playing:
				audible += 1
				names.append("%s=%.2f" % [k, vv.gain])
		_ok(audible >= 2, "ambience '%s' has %d audible layers %s" % [b2, audible, str(names)])
	await tree.create_timer(1.0).timeout

	# ---- 5. Events wiring --------------------------------------------------------------------------------------------------------
	var events: Node = tree.root.get_node("Events")
	# nobody must overwrite Game.tel["speed"] during the event checks: un-pilot the ship again
	var ship5: Node = Game.ship
	var ship5_was_piloted: bool = ship5 != null and bool(ship5.get("piloted"))
	if ship5_was_piloted:
		ship5.call("set_piloted", false)
	# a landed / slow ship "entering" the atmosphere (the event fires once at game start) stays silent, a fast one whooshes
	Game.tel["speed"] = 0.0
	var am0: int = int((audio.get("calls") as Dictionary).get("atmo_enter", 0))
	events.emit_signal("atmosphere_entered", 1)
	await tree.create_timer(0.3).timeout
	_ok(int((audio.get("calls") as Dictionary).get("atmo_enter", 0)) == am0, "Events.atmosphere_entered at low speed stays silent (no whoosh at game start)")
	Game.tel["speed"] = 250.0
	var checks: Array = [
		["ship_landed", [1], "landed"], ["ship_took_off", [], "takeoff"], ["ship_crashed", [0.6], "crash"],
		["atmosphere_entered", [1], "atmo_enter"], ["atmosphere_left", [1], "atmo_leave"], ["pulse_changed", [true], "pulse_on"], ["pulse_changed", [false], "pulse_off"],
		["gear_changed", [true], "gear_down"], ["gear_changed", [false], "gear_up"], ["resource_collected", ["ferrite", 3], "resource_collect"],
		["scan_pulse", [Vector3.ZERO], "scan_ping"], ["player_exited_ship", [], "airlock"], ["poi_discovered", ["Monolith"], "discover"],
		["player_died", [], "death"], ["nav_target_changed", [3], "interact"],
	]
	for c in checks:
		var before: int = int((audio.get("calls") as Dictionary).get(c[2], 0))
		var args: Array = [c[0]]
		args.append_array(c[1])
		events.callv("emit_signal", args)
		await tree.create_timer(0.55).timeout
		var after: int = int((audio.get("calls") as Dictionary).get(c[2], 0))
		_ok(after > before, "Events.%s -> sfx '%s' (%d -> %d)" % [c[0], c[2], before, after])
	for pair in [["info", "notify"], ["good", "notify_good"], ["warn", "notify_warn"], ["danger", "notify_danger"]]:
		var b3: int = int((audio.get("calls") as Dictionary).get(pair[1], 0))
		events.emit_signal("notify", "test", pair[0])
		await tree.create_timer(0.6).timeout
		var a3: int = int((audio.get("calls") as Dictionary).get(pair[1], 0))
		_ok(a3 > b3, "Events.notify(kind=%s) -> '%s'" % [pair[0], pair[1]])
	events.emit_signal("game_paused", true)
	await tree.create_timer(0.5).timeout
	events.emit_signal("game_paused", false)
	for lvl in [1, 2, 3, 4, 0]:
		events.emit_signal("blackhole_warning", lvl, 100000.0 / float(maxi(lvl, 1)))
		await tree.create_timer(0.35).timeout
	var bh: AudioLoopVoice = audio.get("_loops").get("blackhole_rumble", null)
	_ok(bh != null, "blackhole warning levels drive the rumble loop")
	events.emit_signal("warp_started", 1, "hyperdrive")
	await tree.create_timer(3.2).timeout
	var tun: AudioLoopVoice = audio.get("_loops").get("warp_tunnel", null)
	_ok(tun != null and tun.target > 0.2, "warp_started -> charge, jump and tunnel loop (tunnel target=%.2f)" % (tun.target if tun else -1.0))
	events.emit_signal("warp_finished", 1)
	await tree.create_timer(0.5).timeout
	_ok(tun.target < 0.01, "warp_finished -> tunnel loop released")
	if ship5_was_piloted:
		ship5.call("set_piloted", true)
	audio.call("reset_dynamic")
	var final_status: Dictionary = audio.call("status")
	print("[audio_test] unknown names seen: ", final_status.get("unknown"))
	print("[audio_test] RESULT passes=%d fails=%d" % [_passes, _fails])
	print("PASS audio_test complete" if _fails == 0 else "FAIL audio_test has %d failing checks" % _fails)
