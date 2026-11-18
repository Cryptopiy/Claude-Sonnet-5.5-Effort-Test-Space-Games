extends RefCounted
## Measures the REAL mixer output per bus (peak meters + AudioEffectCapture RMS) for typical gameplay scenes, so the level balance can be tuned
## without listening. Run it with the Dummy audio driver (nothing is audible, the master bus is unmuted so the limiter can be measured):
##   powershell -NoProfile -File tools/godot.ps1 -Project "<sandbox>" -Mode run -TimeoutSec 240 -Tag mix -GodotArgs "--audio-driver Dummy --resolution 640x360 -- --autostart --preset=air:1:900 --audio-build --test=res://tests/audio_mix_test.gd"
## Without the Dummy driver the master stays muted (no noise on the user's machine) and only the per-bus numbers are meaningful.
## The ship is frozen (process disabled) so that only this test drives the engine layers.
## Reported: PEAK (dBFS, TRUE sample peak per bus after its own volume; the AudioServer peak meters under-report short sounds with the Dummy driver) and RMS (dBFS, captured at the end of each bus chain, bus volume applied).

const BUSES := ["SFX", "UI", "Engine", "Ambience", "Master"]

var _peak: Dictionary = {}
var _energy: Dictionary = {}
var _frames: Dictionary = {}
var _caps: Dictionary = {}

func _install_captures() -> void:
	for b in BUSES:
		var i: int = AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 0.5
		AudioServer.add_bus_effect(i, cap)      # last effect of the chain (after the limiter on Master)
		_caps[b] = cap

func _reset() -> void:
	for b in BUSES:
		_peak[b] = -99.0
		_energy[b] = 0.0
		_frames[b] = 0
		var cap: AudioEffectCapture = _caps.get(b, null)
		if cap != null:
			cap.clear_buffer()

func _sample() -> void:
	for b in BUSES:
		var i: int = AudioServer.get_bus_index(b)
		var cap: AudioEffectCapture = _caps.get(b, null)
		if cap != null:
			var n: int = cap.get_frames_available()
			if n > 0:
				var buf: PackedVector2Array = cap.get_buffer(n)
				var e := 0.0
				var pk := 0.0
				for v in buf:
					e += 0.5 * (v.x * v.x + v.y * v.y)
					pk = maxf(pk, maxf(absf(v.x), absf(v.y)))
				_energy[b] = float(_energy[b]) + e
				_frames[b] = int(_frames[b]) + n
				# true sample peak (captured before the bus volume stage -> add the bus volume; the master is measured post limiter)
				var vol_db: float = AudioServer.get_bus_volume_db(i) if b != "Master" else 0.0
				_peak[b] = maxf(float(_peak[b]), linear_to_db(maxf(pk, 1e-6)) + vol_db)

func _rms_db(b: String) -> float:
	var n: int = int(_frames.get(b, 0))
	if n <= 0:
		return -99.0
	var r: float = sqrt(float(_energy[b]) / float(n))
	var i: int = AudioServer.get_bus_index(b)
	var vol_db: float = AudioServer.get_bus_volume_db(i) if b != "Master" else 0.0     # captured before the bus volume stage
	return linear_to_db(maxf(r, 1e-6)) + vol_db

func _measure(tree: SceneTree, seconds: float, label: String) -> void:
	_reset()
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await tree.process_frame
		_sample()
	print("[mix] %-34s PEAK sfx=%6.1f ui=%6.1f eng=%6.1f amb=%6.1f MASTER=%6.1f | RMS sfx=%6.1f ui=%6.1f eng=%6.1f amb=%6.1f MASTER=%6.1f" % [label,
		_peak["SFX"], _peak["UI"], _peak["Engine"], _peak["Ambience"], _peak["Master"],
		_rms_db("SFX"), _rms_db("UI"), _rms_db("Engine"), _rms_db("Ambience"), _rms_db("Master")])

## wait until the one-shot buses are quiet again (previous sound tails must not pollute the next measurement)
func _wait_quiet(tree: SceneTree) -> void:
	var t := 0.0
	while t < 8.0:
		await tree.create_timer(0.2).timeout
		t += 0.2
		var q := true
		for b in ["SFX", "UI"]:
			var i: int = AudioServer.get_bus_index(b)
			if AudioServer.get_bus_peak_volume_left_db(i, 0) > -70.0:
				q = false
		if q:
			return

func _drive(tree: SceneTree, audio: Node, frames: int, thr: float, boost: bool, pulse: bool, dens: float, speed: float, biome: String, wind: float, in_space: bool) -> void:
	for i in frames:
		audio.call("set_engine", thr, boost, pulse, dens, speed)
		if biome != "" or in_space:
			audio.call("set_ambient", biome, wind, 0.0, in_space)
		await tree.process_frame

func run(game: Node) -> void:
	var tree: SceneTree = game.get_tree()
	var audio: Node = tree.root.get_node("Audio")
	if Game.ship != null:
		Game.ship.process_mode = Node.PROCESS_MODE_DISABLED
	(audio.get("engine_voice") as AudioEngineVoice).fallback_enabled = false      # only this test drives the engine
	audio.call("force_build")
	var bank: AudioSoundBank = audio.get("bank")
	while not bank.is_complete():
		await tree.create_timer(0.25).timeout
	print("[mix] sounds ready: ", bank.ready_count(), "  driver=", AudioServer.get_driver_name())
	var safe_to_unmute: bool = AudioServer.get_driver_name() == "Dummy"
	if safe_to_unmute:
		audio.call("set_muted_output", false)
	else:
		print("[mix] NOTE: output driver is not Dummy, master stays muted -> Master columns read silence")
	print("[mix] limiter effects on master: ", AudioServer.get_bus_effect_count(0), "  (", AudioServer.get_bus_effect(0, 0) if AudioServer.get_bus_effect_count(0) > 0 else null, ")")
	_install_captures()
	audio.call("set_master_volume", 1.0)
	await tree.create_timer(0.5).timeout
	await _measure(tree, 0.6, "silence (menu-less, no ship)")
	# --- engine (ambience off: space) ---------------------------------------------------------------------------------------------
	await _drive(tree, audio, 120, 0.0, false, false, 0.0, 0.0, "", 0.0, true)
	await _measure(tree, 1.5, "engine idle (space)")
	await _drive(tree, audio, 120, 0.6, false, false, 0.0, 150.0, "", 0.0, true)
	await _measure(tree, 1.5, "engine cruise 60% (space)")
	await _drive(tree, audio, 120, 1.0, true, false, 0.0, 450.0, "", 0.0, true)
	await _measure(tree, 1.5, "engine full + boost (space)")
	await _drive(tree, audio, 120, 1.0, true, false, 0.6, 500.0, "lush", 0.5, false)
	await _measure(tree, 1.5, "engine full + boost (atmosphere)")
	await _drive(tree, audio, 150, 0.3, false, true, 0.0, 20000.0, "", 0.0, true)
	await _measure(tree, 1.5, "pulse drive cruise")
	audio.call("stop_engine")
	await tree.create_timer(4.0).timeout
	# --- ambience (on foot: no cabin muffling; the same beds heard from inside the ship are ~12 dB lower) ----------------------------------
	var saved_mode: int = Game.mode
	Game.mode = Game.Mode.FOOT
	for b in ["lush", "desert", "frozen", "volcanic", "toxic", "ocean", "exotic", "swamp", "radioactive", "barren"]:
		for i in 100:
			audio.call("set_ambient", b, 0.5, 0.0, false)
			await tree.process_frame
		await _measure(tree, 1.2, "ambience %s wind .5 day" % b)
	for i in 100:
		audio.call("set_ambient", "frozen", 1.0, 0.0, false)
		await tree.process_frame
	await _measure(tree, 1.2, "ambience frozen wind 1.0 (storm)")
	for i in 100:
		audio.call("set_ambient", "lush", 0.4, 1.0, false)
		await tree.process_frame
	await _measure(tree, 1.2, "ambience lush NIGHT")
	for i in 100:
		audio.call("set_ambient", "", 0.0, 0.0, true)
		await tree.process_frame
	await _measure(tree, 1.2, "space drone (on foot)")
	Game.mode = saved_mode
	for i in 100:
		audio.call("set_ambient", "lush", 0.5, 0.0, false)
		await tree.process_frame
	await _measure(tree, 1.2, "ambience lush wind .5 day IN THE SHIP CABIN")
	Game.mode = Game.Mode.FOOT
	# --- one-shots on top of an ambient bed ---------------------------------------------------------------------------------------
	for i in 80:
		audio.call("set_ambient", "lush", 0.5, 0.0, false)
		await tree.process_frame
	for s in ["ui_click", "ui_hover", "ui_open", "notify", "notify_good", "notify_warn", "notify_danger", "pickup", "resource_collect", "discover", "scan_ping", "gear_down",
			"landed", "land_foot", "jump", "jetpack_puff", "airlock", "door", "warn_beep", "pulse_on", "pulse_off", "takeoff", "crash", "warp_charge", "warp_jump",
			"warp_arrive", "blackhole_enter", "atmo_enter", "atmo_leave", "hurt", "death", "ui_warp_confirm", "ui_start"]:
		await _wait_quiet(tree)
		for k in 20:
			audio.call("set_ambient", "lush", 0.5, 0.0, false)
			await tree.process_frame
		audio.call("sfx", s)
		await _measure(tree, 1.2, "sfx %s (+lush bed)" % s)
	for surf in ["grass", "sand", "rock", "snow", "metal", "ash", "mud", "water"]:
		await _wait_quiet(tree)
		audio.call("footstep", surf, false)
		await _measure(tree, 0.45, "footstep %s" % surf)
	await _wait_quiet(tree)
	audio.call("footstep", "rock", true)
	await _measure(tree, 0.45, "footstep rock (sprint)")
	for l in ["mining_beam", "jetpack", "alarm", "blackhole_rumble", "warp_tunnel"]:
		audio.call("set_loop", l, true, 1.0)
		await tree.create_timer(1.2).timeout
		await _measure(tree, 0.8, "loop %s" % l)
		audio.call("set_loop", l, false)
		await tree.create_timer(1.0).timeout
	# --- scenes (what the player hears most of the time) ---------------------------------------------------------------------------
	Game.mode = saved_mode
	await _drive(tree, audio, 100, 0.55, false, false, 0.5, 220.0, "lush", 0.5, false)
	await _measure(tree, 1.5, "SCENE flying low over lush (cabin)")
	Game.mode = Game.Mode.FOOT
	audio.call("set_loop", "mining_beam", true, 1.0)
	for i in 100:
		audio.call("set_ambient", "desert", 0.6, 0.0, false)
		await tree.process_frame
	audio.call("footstep", "sand", false)
	await _measure(tree, 1.5, "SCENE desert + mining beam")
	audio.call("set_loop", "mining_beam", false)
	# ducking: crash over an engine at cruise
	Game.mode = saved_mode
	await _drive(tree, audio, 100, 0.6, false, false, 0.5, 220.0, "lush", 0.5, false)
	var ei: int = AudioServer.get_bus_index("Engine")
	var before_db: float = AudioServer.get_bus_volume_db(ei)
	audio.call("sfx", "crash")
	audio.call("duck", 12.0, 1.5)
	await _measure(tree, 0.6, "DUCK engine under crash")
	print("[mix] engine bus volume: %.1f dB -> %.1f dB (ducked)" % [before_db, AudioServer.get_bus_volume_db(ei)])
	await _drive(tree, audio, 200, 0.6, false, false, 0.5, 220.0, "lush", 0.5, false)
	print("[mix] engine bus volume after release: %.1f dB" % AudioServer.get_bus_volume_db(ei))
	# --- master taper -------------------------------------------------------------------------------------------------------------
	for v in [1.0, 0.8, 0.5, 0.25, 0.1, 0.0]:
		audio.call("set_master_volume", v)
		print("[mix] master slider %.2f -> %6.1f dB" % [v, AudioServer.get_bus_volume_db(0)])
	audio.call("set_master_volume", 1.0)
	# --- worst cases --------------------------------------------------------------------------------------------------------------
	await _drive(tree, audio, 80, 1.0, true, false, 0.8, 600.0, "volcanic", 1.0, false)
	audio.call("set_loop", "alarm", true, 1.0)
	audio.call("set_loop", "blackhole_rumble", true, 1.0)
	audio.call("set_loop", "jetpack", true, 1.0)
	audio.call("sfx", "crash")
	audio.call("sfx", "warp_jump")
	audio.call("sfx", "blackhole_enter")
	await _measure(tree, 2.0, "WORST CASE everything at once")
	audio.call("reset_dynamic")
	Game.mode = saved_mode
	print("[mix] done")
