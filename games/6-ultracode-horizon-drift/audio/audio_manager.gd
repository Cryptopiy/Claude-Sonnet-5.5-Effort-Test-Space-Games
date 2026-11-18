class_name AudioManager
extends Node
## AUDIO (module M8 owns audio/**). Autoload name: `Audio`. Everything is synthesised in code (audio/synth/*): no audio files.
## Other modules may call these functions at any time; they never error (silent when a sound is not built yet or no audio device exists).
##
## sfx(name, pos := Vector3.INF, volume_db := 0.0)   one-shot. pos = LOCAL-frame position for 3D sound (INF = 2D). Names in use:
##    "ui_click" "ui_open" "ui_back" "ui_warp_confirm" "notify" "pickup" "resource_collect" "scan_ping" "gear_down" "gear_up" "landed" "crash" "takeoff"
##    "pulse_on" "pulse_off" "airlock" "jump" "land_foot" "jetpack_puff" "warn_beep" "discover" "warp_charge" "warp_jump" "blackhole_enter" "door" "interact"
##    plus extras: "ui_hover" "ui_error" "ui_start" "notify_good" "notify_warn" "notify_danger" "hurt" "death" "atmo_enter" "atmo_leave" "warp_arrive"
##    and aliases / variant groups (see AudioRecipes.ALIASES / VARIANTS), e.g. "bird" picks one of 3 chirps.
## set_engine(throttle 0..1, boost, pulse, atmosphere_density 0..1, speed)  ship engine loop (call every frame while piloting; call set_engine(0,false,false,0,0) / stop_engine() when not)
## stop_engine()
## set_loop(name, on, volume := 1.0)   continuous layers: "mining_beam" "jetpack" "blackhole_rumble" "alarm" "warp_tunnel" "wind" (wind is driven by set_ambient)
## set_ambient(biome: String, wind: float 0..1, night: float 0..1, in_space: bool)   planet ambience bed (wind, insects/hum per biome); in_space = near-silent drone
## footstep(surface: String, sprint: bool)   surface = "grass" "sand" "rock" "snow" "metal" "ash" "mud" ... (aliases such as "dirt" "ice" "gravel" "dust" work too)
## set_master_volume(v: float 0..1)   (Game.settings["volume"])
##
## Extras (optional): duck(db, seconds)  set_paused_mix(bool)  atmosphere_density_at_focus()  status() -> Dictionary  force_build()  set_muted_output(bool)
##
## Output is muted automatically in windowless / test runs (--no-window / --headless) so automated runs never make noise on the user's machine
## (they may be screen-recording). Pass the user arg `--audio` to keep it audible, `--audio-build` to also synthesise the sounds while muted.

const MAX_2D := 18
const MAX_3D := 14
const BUS_DEFS := [["SFX", 0.0], ["UI", 0.0], ["Engine", -5.0], ["Ambience", -3.0]]

var bank: AudioSoundBank = null
var engine_voice: AudioEngineVoice = null
var ambience: AudioAmbience = null
var hooks: AudioEventHooks = null

var automation: bool = false          # windowless / scripted run
var output_muted: bool = false
var master_volume: float = 0.8
var calls: Dictionary = {}            # sfx name -> number of play_sfx requests that resulted in a sound (tests / debugging)
var missed: int = 0                   # requests dropped because the sound was not synthesised yet
var missed_names: Dictionary = {}     # sound name -> dropped requests (diagnostics)
var unknown_names: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _pool2d: Array[AudioStreamPlayer] = []
var _pool2d_t: Array[float] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool3d_t: Array[float] = []
var _loops: Dictionary = {}           # name -> AudioLoopVoice (set_loop)
var _last_play: Dictionary = {}       # name -> time (s)
var _loop_ext_s: Dictionary = {}      # loop name -> time (s) of the last call made by another module (hooks only act as a fallback)
var _last_step: Dictionary = {}       # surface -> last variant
var _ready_ok: bool = false
var _bus_idx: Dictionary = {}
var _settings_volume_seen: float = -1.0
var _duck_db: float = 0.0
var _duck_target: float = 0.0
var _duck_until: float = 0.0
var _paused_mix: bool = false
var _lp_engine: AudioEffectLowPassFilter = null
var _lp_amb: AudioEffectLowPassFilter = null
var _reverb: AudioEffectReverb = null
var _density_cache: float = 0.0
var _density_t: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 150
	_rng.randomize()
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var want_audio: bool = args.has("--audio") or args.has("--audio-build") or OS.get_environment("HORIZON_AUDIO") == "1"
	automation = args.has("--no-window") or args.has("--headless") or DisplayServer.get_name() == "headless"
	_setup_buses()
	bank = AudioSoundBank.new()
	engine_voice = AudioEngineVoice.new(self, bank)
	ambience = AudioAmbience.new(self, bank)
	hooks = AudioEventHooks.new()
	hooks.setup(self)
	if automation and not args.has("--audio"):
		set_muted_output(true)
		print("[Audio] windowless/test run: output muted (user arg --audio to hear it)")
	if (not automation) or args.has("--audio-build") or args.has("--audio"):
		bank.start_background()
	var gv: Variant = Game.settings.get("volume", 0.8)
	set_master_volume(float(gv))
	_settings_volume_seen = float(gv)
	_ready_ok = true

func _exit_tree() -> void:
	if bank != null:
		bank.shutdown()

# ---------------------------------------------------------------------------------------------------------------------------------
# buses
# ---------------------------------------------------------------------------------------------------------------------------------
func _setup_buses() -> void:
	for d in BUS_DEFS:
		var bname: String = d[0]
		var idx: int = AudioServer.get_bus_index(bname)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, "Master")
			AudioServer.set_bus_volume_db(idx, float(d[1]))
			match bname:
				"SFX":
					_reverb = AudioEffectReverb.new()
					_reverb.room_size = 0.42
					_reverb.damping = 0.65
					_reverb.wet = 0.09
					_reverb.dry = 1.0
					_reverb.spread = 1.0
					AudioServer.add_bus_effect(idx, _reverb)
				"Engine":
					_lp_engine = AudioEffectLowPassFilter.new()
					_lp_engine.cutoff_hz = 20000.0
					AudioServer.add_bus_effect(idx, _lp_engine)
				"Ambience":
					_lp_amb = AudioEffectLowPassFilter.new()
					_lp_amb.cutoff_hz = 20000.0
					AudioServer.add_bus_effect(idx, _lp_amb)
		_bus_idx[bname] = idx
	# master limiter so layered sounds can never clip
	var lim: AudioEffect = null
	if ClassDB.class_exists("AudioEffectHardLimiter"):
		lim = ClassDB.instantiate("AudioEffectHardLimiter")
		lim.set("ceiling_db", -1.0)
		lim.set("pre_gain_db", 0.0)
	elif ClassDB.class_exists("AudioEffectLimiter"):
		lim = ClassDB.instantiate("AudioEffectLimiter")
		lim.set("ceiling_db", -1.0)
	if lim != null and AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, lim)

func set_muted_output(m: bool) -> void:
	output_muted = m
	AudioServer.set_bus_mute(0, m)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	# perceptual taper: slider position squared
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume * master_volume, 0.000001)))

## temporarily lower engine + ambience (e.g. under a crash or a jump). db = how many dB to duck, seconds = hold time
func duck(db: float, seconds: float) -> void:
	_duck_target = -absf(db)
	_duck_until = _now() + seconds

func set_paused_mix(p: bool) -> void:
	_paused_mix = p

func force_build() -> void:
	bank.start_background()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------------------------------------------------------------------------------------------------------------------------------
# public API
# ---------------------------------------------------------------------------------------------------------------------------------
func sfx(sfx_name: String, pos: Vector3 = Vector3.INF, volume_db: float = 0.0) -> void:
	play_sfx(sfx_name, pos, volume_db, 1.0)

## like sfx() but with a pitch multiplier; returns true if a sound was actually started
func play_sfx(sfx_name: String, pos: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not _ready_ok:
		return false
	var n: String = AudioRecipes.resolve(sfx_name, _rng)
	if n == "":
		if not unknown_names.has(sfx_name):
			unknown_names[sfx_name] = 1
			print("[Audio] unknown sound name '", sfx_name, "' (ignored)")
		return false
	var meta: Dictionary = AudioRecipes.meta(n)
	var now: float = _now()
	var cd: float = float(meta["cd"])
	if cd > 0.0 and now - float(_last_play.get(n, -1000.0)) < cd:
		return false
	var st: AudioStreamWAV = bank.get_stream(n)
	if st == null:
		missed += 1
		missed_names[n] = int(missed_names.get(n, 0)) + 1
		return false
	_last_play[n] = now
	calls[n] = int(calls.get(n, 0)) + 1
	var db: float = float(meta["db"]) + volume_db
	var pv: float = float(meta["pv"])
	var p: float = pitch * (1.0 + _rng.randf_range(-pv, pv))
	var bus: String = meta["bus"]
	if pos.is_finite() and _ensure_3d_pool():
		_play_3d(st, bus, db, p, pos, float(meta["unit"]))
	else:
		_play_2d(st, bus, db, p)
	return true

func set_engine(throttle: float, boost: bool, pulse: bool, atmo_density: float, speed: float) -> void:
	if engine_voice != null:
		engine_voice.set_engine(throttle, boost, pulse, atmo_density, speed)

func stop_engine() -> void:
	if engine_voice != null:
		engine_voice.stop()

func set_loop(loop_name: String, on: bool, volume: float = 1.0) -> void:
	_loop_ext_s[loop_name] = _now()
	_set_loop_impl(loop_name, on, volume)

## used by the Events hooks: only acts when no other module controlled this loop during the last 1.5 s
func set_loop_fallback(loop_name: String, on: bool, volume: float = 1.0) -> void:
	if _now() - float(_loop_ext_s.get(loop_name, -1000.0)) < 1.5:
		return
	_set_loop_impl(loop_name, on, volume)

## true if any of these sounds started during the last `within_s` seconds (by anyone)
func recent_play(names: Array, within_s: float) -> bool:
	var now: float = _now()
	for n in names:
		if now - float(_last_play.get(n, -1000.0)) < within_s:
			return true
	return false

func played_since(sound: String, t0: float) -> bool:
	return float(_last_play.get(sound, -1000.0)) >= t0

func now_s() -> float:
	return _now()

func _set_loop_impl(loop_name: String, on: bool, volume: float) -> void:
	if not _ready_ok:
		return
	if loop_name == "wind":
		ambience.wind_override = clampf(volume, 0.0, 1.0) if on else 0.0
		ambience.wind_override_until_ms = Time.get_ticks_msec() + (900 if on else 0)
		return
	var v: AudioLoopVoice = _loops.get(loop_name, null)
	if v == null:
		if not on:
			return
		if not AudioRecipes.META.has(loop_name):
			if not unknown_names.has(loop_name):
				unknown_names[loop_name] = 1
				print("[Audio] unknown loop name '", loop_name, "' (ignored)")
			return
		v = AudioLoopVoice.new(self, bank, loop_name)
		match loop_name:
			"jetpack":
				v.attack = 14.0
				v.release = 7.0
			"mining_beam":
				v.attack = 18.0
				v.release = 9.0
			"alarm":
				v.attack = 30.0
				v.release = 6.0
			"warp_tunnel":
				v.attack = 1.5
				v.release = 1.6
			"blackhole_rumble":
				v.attack = 1.2
				v.release = 0.8
		_loops[loop_name] = v
	v.target = clampf(volume, 0.0, 1.5) if on else 0.0
	if loop_name == "jetpack":
		v.target_pitch = 0.85 + 0.35 * clampf(volume, 0.0, 1.0)
	elif loop_name == "alarm":
		v.target_pitch = 1.0 if volume < 0.8 else 1.18
	elif loop_name == "blackhole_rumble":
		v.target_pitch = 0.8 + 0.4 * clampf(volume, 0.0, 1.0)

func set_ambient(biome: String, wind: float, night: float, in_space: bool) -> void:
	if ambience != null:
		ambience.set_external(biome, wind, night, in_space)

func footstep(surface: String, sprint: bool = false) -> void:
	if not _ready_ok:
		return
	var s: String = RecipesWorld.surface_alias(surface)
	var v: int = _rng.randi() % 4
	if v == int(_last_step.get(s, -1)):
		v = (v + 1 + _rng.randi() % 3) % 4
	_last_step[s] = v
	play_sfx("step_%s_%d" % [s, v], Vector3.INF, 3.0 if sprint else 0.0, 1.06 if sprint else 1.0)

## clears every continuous layer (new game / back to menu)
func reset_dynamic() -> void:
	if engine_voice != null:
		engine_voice.stop_all_now()
	for k in _loops:
		(_loops[k] as AudioLoopVoice).stop_now()
	_duck_target = 0.0
	_duck_db = 0.0

## 0..1 atmosphere density at the current focus (ship / player / free cam) of the anchored planet
func atmosphere_density_at_focus() -> float:
	var now: float = _now()
	if now - _density_t < 0.05:
		return _density_cache
	_density_t = now
	var d := 0.0
	var def: BodyDef = Frame.anchor_def()
	var f: Node3D = Frame.focus
	if def != null and f != null and is_instance_valid(f) and f.is_inside_tree():
		var pl: Node3D = Frame.anchor_node()
		if pl != null and pl.has_method("atmosphere_density_at"):
			d = float(pl.call("atmosphere_density_at", f.global_position))
		elif def.has_atmosphere and def.atmo_height > 0.0:
			d = clampf(1.0 - (f.global_position.length() - def.radius) / def.atmo_height, 0.0, 1.0)
	_density_cache = d
	return d

func status() -> Dictionary:
	return {
		"ready": _ready_ok, "automation": automation, "muted": output_muted, "built": bank.ready_count() if bank else 0,
		"pending": bank.pending_count() if bank else 0, "missed": missed, "missed_names": missed_names.duplicate(), "calls": calls.duplicate(),
		"engine_on": engine_voice.is_running() if engine_voice else false, "biome": ambience.current_biome if ambience else "",
		"unknown": unknown_names.keys(),
	}

# ---------------------------------------------------------------------------------------------------------------------------------
# players
# ---------------------------------------------------------------------------------------------------------------------------------
func _play_2d(st: AudioStreamWAV, bus: String, db: float, pitch: float) -> void:
	var idx := -1
	var oldest := 1.0e30
	var oldest_i := 0
	for i in _pool2d.size():
		if not _pool2d[i].playing:
			idx = i
			break
		if _pool2d_t[i] < oldest:
			oldest = _pool2d_t[i]
			oldest_i = i
	if idx < 0:
		if _pool2d.size() < MAX_2D:
			var np := AudioStreamPlayer.new()
			add_child(np)
			_pool2d.append(np)
			_pool2d_t.append(0.0)
			idx = _pool2d.size() - 1
		else:
			idx = oldest_i
	var p: AudioStreamPlayer = _pool2d[idx]
	p.stream = st
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.play()
	_pool2d_t[idx] = _now()

func _ensure_3d_pool() -> bool:
	return Game.local_root != null and is_instance_valid(Game.local_root) and Game.local_root.is_inside_tree()

func _play_3d(st: AudioStreamWAV, bus: String, db: float, pitch: float, pos: Vector3, unit: float) -> void:
	var idx := -1
	var oldest := 1.0e30
	var oldest_i := 0
	# drop pool entries whose node vanished (scene reloaded)
	for i in range(_pool3d.size() - 1, -1, -1):
		if not is_instance_valid(_pool3d[i]):
			_pool3d.remove_at(i)
			_pool3d_t.remove_at(i)
	for i in _pool3d.size():
		if not _pool3d[i].playing:
			idx = i
			break
		if _pool3d_t[i] < oldest:
			oldest = _pool3d_t[i]
			oldest_i = i
	if idx < 0:
		if _pool3d.size() < MAX_3D:
			var np := AudioStreamPlayer3D.new()
			np.process_mode = Node.PROCESS_MODE_ALWAYS
			np.max_distance = 600.0
			np.attenuation_filter_cutoff_hz = 9000.0
			Game.local_root.add_child(np)
			np.add_to_group("frame_objects")          # Frame converts positions on frame switches / rebases
			_pool3d.append(np)
			_pool3d_t.append(0.0)
			idx = _pool3d.size() - 1
		else:
			idx = oldest_i
	var p: AudioStreamPlayer3D = _pool3d[idx]
	if p.get_parent() != Game.local_root:
		p.reparent(Game.local_root, false)
	p.stream = st
	p.bus = bus
	p.unit_size = unit
	p.volume_db = db
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.global_position = pos
	p.play()
	_pool3d_t[idx] = _now()

# ---------------------------------------------------------------------------------------------------------------------------------
# per-frame
# ---------------------------------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = minf(delta, 0.1)
	_sync_settings_volume()
	_update_buses(dt)
	if engine_voice != null:
		engine_voice.update(dt)
	if ambience != null:
		ambience.update(dt)
	for k in _loops:
		(_loops[k] as AudioLoopVoice).update(dt)
	if hooks != null:
		hooks.probe(dt)

func _sync_settings_volume() -> void:
	var gv: float = float(Game.settings.get("volume", master_volume))
	if absf(gv - _settings_volume_seen) > 0.0005:
		_settings_volume_seen = gv
		set_master_volume(gv)

func _update_buses(dt: float) -> void:
	if _now() > _duck_until:
		_duck_target = 0.0
	var rate: float = 14.0 if _duck_target < _duck_db else 1.6
	_duck_db += (_duck_target - _duck_db) * (1.0 - exp(-rate * dt))
	var pause_db: float = -12.0 if _paused_mix else 0.0
	var dens: float = atmosphere_density_at_focus() if Game.state == Game.State.PLAYING else 1.0
	var cabin: float = ambience.cabin_factor if ambience != null else 0.0
	var eng_cut: float = lerpf(3200.0, 16000.0, clampf(dens * 1.3, 0.0, 1.0))
	var amb_cut: float = lerpf(20000.0, 1700.0, cabin)
	if _paused_mix:
		eng_cut = 700.0
		amb_cut = 600.0
	if _lp_engine != null:
		_lp_engine.cutoff_hz += (eng_cut - _lp_engine.cutoff_hz) * (1.0 - exp(-4.0 * dt))
	if _lp_amb != null:
		_lp_amb.cutoff_hz += (amb_cut - _lp_amb.cutoff_hz) * (1.0 - exp(-4.0 * dt))
	var amb_db: float = -3.0 + _duck_db + pause_db - 5.0 * cabin
	var eng_db: float = -5.0 + _duck_db + pause_db
	var ei: int = int(_bus_idx.get("Engine", -1))
	var ai: int = int(_bus_idx.get("Ambience", -1))
	var si: int = int(_bus_idx.get("SFX", -1))
	if ei >= 0:
		AudioServer.set_bus_volume_db(ei, eng_db)
	if ai >= 0:
		AudioServer.set_bus_volume_db(ai, amb_db)
	if si >= 0:
		AudioServer.set_bus_volume_db(si, (-4.0 if _paused_mix else 0.0))
	if _reverb != null:
		var in_air: float = clampf(dens * 1.5, 0.0, 1.0)
		_reverb.wet = 0.03 + 0.08 * in_air
