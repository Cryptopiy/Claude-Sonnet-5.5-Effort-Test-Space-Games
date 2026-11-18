class_name SfxManager
extends Node
## Plays the synthesized sounds: continuous loops follow the game state (engine, pulse drive, wind, rain, jetpack,
## black hole rumble + alarm), one-shots react to game events (footsteps, landing, messages, UI).

var streams: Dictionary = {}
var _task_id: int = -1
var _loops: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _ready_streams: bool = false
var _build_result: Dictionary = {}
var _mutex := Mutex.new()
var world: SpaceWorld
var pc: PlayerController
var weather: WeatherFx
var _last_warn: float = 0.0
var _gear_prev: float = 1.0
var _heat_prev: float = 0.0
var _landed_prev: bool = false
var _pulse_prev: bool = false

func setup(w: SpaceWorld, p: PlayerController, wx: WeatherFx) -> void:
	world = w
	pc = p
	weather = wx
	_task_id = WorkerThreadPool.add_task(_build, false, "sfx synth")
	for i in 10:
		var pl := AudioStreamPlayer.new()
		pl.bus = "Master"
		add_child(pl)
		_pool.append(pl)
	Game.sfx.connect(_on_sfx)
	Game.message.connect(_on_message)
	Game.discovery.connect(func(_t: String) -> void: play("chime", -4.0))
	p.astro.footstep.connect(_on_step)
	p.astro.landed_hard.connect(func(_s: float) -> void: play("thud", -4.0, 0.9))

func _build() -> void:
	var d: Dictionary = SfxSynth.build_all()
	_mutex.lock()
	_build_result = d
	_mutex.unlock()

func _exit_tree() -> void:
	# quitting while the synthesis task still runs would free this node under the worker thread
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

func _process(delta: float) -> void:
	if not _ready_streams:
		if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
			WorkerThreadPool.wait_for_task_completion(_task_id)
			_task_id = -1
			_mutex.lock()
			streams = _build_result
			_mutex.unlock()
			_make_loops()
			_ready_streams = true
		return
	_update_loops(delta)

func _make_loops() -> void:
	for nm in ["engine", "pulse", "wind", "rain", "rumble", "alarm", "jet"]:
		var pl := AudioStreamPlayer.new()
		pl.stream = streams[nm]
		pl.bus = "Master"
		pl.volume_db = -80.0
		add_child(pl)
		pl.play()
		_loops[nm] = pl

func _set_loop(nm: String, vol: float, pitch: float = 1.0) -> void:
	var pl: AudioStreamPlayer = _loops[nm]
	var db: float = -80.0 if vol <= 0.001 else linear_to_db(clampf(vol, 0.0, 1.0))
	pl.volume_db = lerpf(pl.volume_db, db, 0.25)
	pl.pitch_scale = lerpf(pl.pitch_scale, pitch, 0.2)

func _update_loops(delta: float) -> void:
	if Game.paused:
		for k in _loops.keys():
			(_loops[k] as AudioStreamPlayer).volume_db = -80.0
		return
	var ship: Ship = pc.ship
	var on_ship: bool = pc.mode == PlayerController.Mode.SHIP
	var th: float = clampf(ship.thrust_vis, 0.0, 1.6)
	var eng: float = 0.0
	var eng_pitch: float = 1.0
	if on_ship and Game.in_game:
		eng = 0.10 + 0.55 * clampf(th, 0.0, 1.0)
		if ship.state == Ship.State.LANDED:
			eng = 0.06
		eng_pitch = 0.78 + 0.5 * clampf(th, 0.0, 1.0) + (0.25 if ship.boosting else 0.0)
	elif not Game.in_game:
		eng = 0.12
	_set_loop("engine", eng * 0.7, eng_pitch)
	var pul: float = clampf(ship.pulse_speed / Ship.PULSE_SPEED, 0.0, 1.0)
	_set_loop("pulse", pul * 0.7 if ship.pulse_on else 0.0, 0.8 + 0.6 * pul)
	var wind: float = 0.0
	if world.frame_idx >= 0:
		var spd: float = ship.velocity.length() if on_ship else pc.astro.speed_h * 4.0
		wind = clampf(world.air * (0.18 + spd / 260.0) + weather.intensity * 0.35 * world.air, 0.0, 0.9)
		if on_ship and ship.heat > 0.05:
			wind = clampf(wind + ship.heat * 0.7, 0.0, 1.0)
	_set_loop("wind", wind * 0.8, 0.8 + 0.5 * wind)
	var rain: float = weather.intensity * world.air if weather.kind == "rain" else 0.0
	if weather.kind == "snow" or weather.kind == "ash" or weather.kind == "dust":
		rain = 0.0
	_set_loop("rain", rain * 0.55)
	_set_loop("jet", 0.6 if (not on_ship and pc.astro.jetting) else 0.0, 1.0)
	var zone: int = int(world.bh_info.get("zone", 0))
	var dist: float = float(world.bh_info.get("dist", 1e9))
	var rum: float = 0.0
	if zone > 0:
		rum = clampf(1.0 - dist / 140000.0, 0.0, 1.0)
		rum = rum * rum * 1.4
	_set_loop("rumble", rum, 0.9 + 0.3 * rum)
	_set_loop("alarm", 0.32 if zone >= 3 else 0.0)
	# event one-shots derived from state changes
	if on_ship:
		if absf(ship.gear - _gear_prev) > 0.0005 and absf(ship.gear - _gear_prev) < 0.5:
			if int(_gear_prev * 20.0) != int(ship.gear * 20.0) and not _servo_busy:
				_servo_busy = true
				play("servo", -6.0)
				get_tree().create_timer(0.9).timeout.connect(func() -> void: _servo_busy = false)
		var landed: bool = ship.state == Ship.State.LANDED
		if landed and not _landed_prev:
			play("thud", -2.0, 0.8)
		_landed_prev = landed
		if ship.pulse_on and not _pulse_prev:
			play("pulse_on", -3.0)
		_pulse_prev = ship.pulse_on
	_gear_prev = ship.gear

var _servo_busy: bool = false

func play(nm: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _ready_streams or not streams.has(nm):
		return
	var pl: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	pl.stream = streams[nm]
	pl.volume_db = vol_db
	pl.pitch_scale = pitch
	pl.play()

func _on_sfx(nm: String, vol_db: float, pitch: float) -> void:
	play(nm, vol_db, pitch)

func _on_message(_text: String, _secs: float, kind: String) -> void:
	if kind == "warn":
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		if now - _last_warn > 2.5:
			_last_warn = now
			play("beep", -4.0)
	elif kind == "good":
		play("pickup", -6.0)

func _on_step(strong: bool) -> void:
	var kind: int = 0
	if world.frame_idx >= 0:
		match String(world.planets[world.frame_idx].data.profile.get("ground", "grass")):
			"grass": kind = 0
			"sand", "regolith": kind = 1
			"snow", "mud": kind = 2
			_: kind = 3
	play("step%d" % kind, -9.0 + (3.0 if strong else 0.0), randf_range(0.85, 1.15))
