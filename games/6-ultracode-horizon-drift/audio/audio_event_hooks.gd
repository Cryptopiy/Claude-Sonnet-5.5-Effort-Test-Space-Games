class_name AudioEventHooks
extends RefCounted
## Wires the global Events bus (and a few telemetry probes) to sounds, so the game sounds alive even when a module never calls Audio directly.
## Direct Audio.sfx() calls and these hooks may overlap: per-sound cooldowns in AudioRecipes.META de-duplicate them.

var _m: Node                       # AudioManager
var _warp_token: int = 0
var _last_major_ms: int = -100000  # last "big" event sound (suppresses generic notification chimes right after it)
var _last_health: float = -1.0
var _bh_level: int = 0
var _tel_timer: float = 0.0
var _quiet_until_ms: int = 0       # no atmosphere whooshes right after a game start / warp arrival (the ship just "enters" the air it already sits in)
var connected: bool = false

func setup(manager: Node) -> void:
	_m = manager
	var ev := Events
	ev.notify.connect(_on_notify)
	ev.poi_discovered.connect(_on_poi_discovered)
	ev.game_started.connect(_on_game_started)
	ev.game_paused.connect(_on_game_paused)
	ev.returned_to_menu.connect(_on_returned_to_menu)
	ev.player_entered_ship.connect(_on_entered_ship)
	ev.player_exited_ship.connect(_on_exited_ship)
	ev.system_loaded.connect(_on_system_loaded)
	ev.ship_landed.connect(_on_ship_landed)
	ev.ship_took_off.connect(_on_ship_took_off)
	ev.ship_crashed.connect(_on_ship_crashed)
	ev.atmosphere_entered.connect(_on_atmo_entered)
	ev.atmosphere_left.connect(_on_atmo_left)
	ev.pulse_changed.connect(_on_pulse_changed)
	ev.gear_changed.connect(_on_gear_changed)
	ev.resource_collected.connect(_on_resource_collected)
	ev.scan_pulse.connect(_on_scan_pulse)
	ev.player_died.connect(_on_player_died)
	ev.nav_target_changed.connect(_on_nav_target)
	ev.warp_started.connect(_on_warp_started)
	ev.warp_finished.connect(_on_warp_finished)
	ev.blackhole_warning.connect(_on_blackhole_warning)
	ev.blackhole_entered.connect(_on_blackhole_entered)
	connected = true

func _major() -> void:
	_last_major_ms = Time.get_ticks_msec()

# ---------------------------------------------------------------------------------------------------------------------------------
# messaging
# ---------------------------------------------------------------------------------------------------------------------------------
const MAJOR_SOUNDS := ["warn_beep", "resource_collect", "discover", "landed", "crash", "gear_down", "gear_up", "pulse_on", "pulse_off", "scan_ping",
		"airlock", "blackhole_enter", "takeoff", "atmo_enter", "atmo_leave", "death", "hurt", "pickup"]

func _on_notify(text: String, kind: String) -> void:
	# generic toast chime, unless a dedicated sound just played for the same moment
	if Time.get_ticks_msec() - _last_major_ms < 450 or _m.call("recent_play", MAJOR_SOUNDS, 0.45):
		return
	match kind:
		"good":
			_m.call("play_sfx", "notify_good")
		"warn":
			_m.call("play_sfx", "notify_warn")
		"danger":
			_m.call("play_sfx", "notify_danger")
			_m.call("duck", 4.0, 0.5)
		"discover":
			_m.call("play_sfx", "discover")
			_major()
		_:
			_m.call("play_sfx", "notify")

func _on_poi_discovered(_poi_name: String) -> void:
	_m.call("play_sfx", "discover")
	_major()

# ---------------------------------------------------------------------------------------------------------------------------------
# game flow
# ---------------------------------------------------------------------------------------------------------------------------------
func _on_game_started() -> void:
	_quiet_until_ms = Time.get_ticks_msec() + 3500
	_m.call("reset_dynamic")
	_m.call("play_sfx", "ui_start")
	_last_health = -1.0

func _on_game_paused(paused: bool) -> void:
	_m.call("set_paused_mix", paused)
	_m.call("play_sfx", "ui_open" if paused else "ui_back")

func _on_returned_to_menu() -> void:
	_m.call("reset_dynamic")

func _on_system_loaded(_id: int) -> void:
	_quiet_until_ms = Time.get_ticks_msec() + 3500
	_set_bh(0, 99999.0)

func _on_entered_ship() -> void:
	_m.call("play_sfx", "airlock")
	_m.call("play_sfx", "door")
	_major()

func _on_exited_ship() -> void:
	_m.call("play_sfx", "airlock")
	_m.call("play_sfx", "door")
	_major()

func _on_player_died() -> void:
	_m.call("play_sfx", "death")
	_m.call("duck", 10.0, 2.0)
	_major()

func _on_nav_target(body_index: int) -> void:
	if body_index >= 0:
		_m.call("play_sfx", "interact")

# ---------------------------------------------------------------------------------------------------------------------------------
# ship
# ---------------------------------------------------------------------------------------------------------------------------------
func _on_ship_landed(_body: int) -> void:
	_m.call("play_sfx", "landed")
	_m.call("duck", 5.0, 0.7)
	_major()

func _on_ship_took_off() -> void:
	_m.call("play_sfx", "takeoff")
	_major()

func _on_ship_crashed(severity: float) -> void:
	var s: float = clampf(severity, 0.0, 1.0)
	_m.call("play_sfx", "crash", Vector3.INF, -12.0 * (1.0 - s))
	_m.call("duck", 8.0 + 8.0 * s, 1.0 + 1.5 * s)
	_major()

func _on_atmo_entered(_body: int) -> void:
	_atmo_whoosh("atmo_enter")

func _on_atmo_left(_body: int) -> void:
	_atmo_whoosh("atmo_leave")

## entry / exit rush: only for a ship that really flies through the boundary (not the "enter" event a landed ship fires at game start),
## louder the faster it goes
func _atmo_whoosh(sound: String) -> void:
	if Time.get_ticks_msec() < _quiet_until_ms or Game.mode != Game.Mode.SHIP:
		return
	var sh: Node = Game.ship
	if sh == null or not is_instance_valid(sh) or bool(sh.get("is_landed")):
		return
	var spd: float = float(Game.tel.get("speed", 0.0))
	if spd < 70.0:
		return
	_m.call("play_sfx", sound, Vector3.INF, lerpf(-14.0, 0.0, clampf((spd - 70.0) / 400.0, 0.0, 1.0)))

func _on_pulse_changed(active: bool) -> void:
	_m.call("play_sfx", "pulse_on" if active else "pulse_off")
	_major()

func _on_gear_changed(deployed: bool) -> void:
	_m.call("play_sfx", "gear_down" if deployed else "gear_up")
	_major()

func _on_scan_pulse(_origin: Vector3) -> void:
	_m.call("play_sfx", "scan_ping")
	_m.call("duck", 2.5, 0.8)
	_major()

func _on_resource_collected(resource_id: String, _amount: int) -> void:
	var pitch := 1.0
	match resource_id:
		"ferrite": pitch = 0.86
		"zyrite": pitch = 1.18
		"sodium": pitch = 1.0
		"voidstone": pitch = 0.7
	_m.call("play_sfx", "resource_collect", Vector3.INF, 0.0, pitch)
	_major()

# ---------------------------------------------------------------------------------------------------------------------------------
# warp / black hole
# ---------------------------------------------------------------------------------------------------------------------------------
func _on_warp_started(_system_id: int, kind: String) -> void:
	# The WarpEffect module normally plays charge / jump / tunnel itself (right after this signal). We only act as a fallback:
	# if no "warp_charge" was started 0.4 s later, we run the whole sequence ourselves.
	_warp_token += 1
	var token: int = _warp_token
	var t_start: float = _m.call("now_s")
	_major()
	_m.call("duck", 8.0, 2.5)
	var tw0: SceneTreeTimer = _m.get_tree().create_timer(0.4, true)
	tw0.timeout.connect(func() -> void:
		if token != _warp_token or bool(_m.call("played_since", "warp_charge", t_start)):
			return
		_m.call("play_sfx", "warp_charge")
		_m.call("set_loop_fallback", "warp_tunnel", true, 0.8)
		var tw: SceneTreeTimer = _m.get_tree().create_timer(1.7, true)
		tw.timeout.connect(func() -> void:
			if token != _warp_token:
				return
			_m.call("play_sfx", "warp_jump")
			_m.call("duck", 10.0, 2.5)))

func _on_warp_finished(_system_id: int) -> void:
	_quiet_until_ms = Time.get_ticks_msec() + 3500
	_warp_token += 1
	_m.call("set_loop_fallback", "warp_tunnel", false)
	_m.call("play_sfx", "warp_arrive")
	_set_bh(0, 99999.0)
	_major()

func _on_blackhole_entered() -> void:
	_m.call("play_sfx", "blackhole_enter")
	_major()

func _on_blackhole_warning(level: int, distance: float) -> void:
	_set_bh(level, distance)

func _set_bh(level: int, distance: float) -> void:
	var changed: bool = level != _bh_level
	_bh_level = level
	var rumble: float = 0.0
	match level:
		1: rumble = 0.22
		2: rumble = 0.5
		3: rumble = 0.85
		4: rumble = 1.0
	# the black-hole module drives these loops itself every frame; we only fill in when it does not
	_m.call("set_loop_fallback", "blackhole_rumble", level > 0, rumble)
	if level == 2 or level == 3:
		_m.call("set_loop_fallback", "alarm", true, 0.55 if level == 2 else 1.0)
	else:
		_m.call("set_loop_fallback", "alarm", false)
	if changed and level > 0:
		_m.call("play_sfx", "warn_beep")

# ---------------------------------------------------------------------------------------------------------------------------------
# telemetry probes (called from the manager at ~10 Hz)
# ---------------------------------------------------------------------------------------------------------------------------------
func probe(dt: float) -> void:
	_tel_timer += dt
	if _tel_timer < 0.1:
		return
	_tel_timer = 0.0
	if Game.state != Game.State.PLAYING:
		return
	var tel: Dictionary = Game.tel
	if tel.has("health"):
		var h: float = float(tel["health"])
		if _last_health >= 0.0 and h < _last_health - 0.015:
			_m.call("play_sfx", "hurt")
		_last_health = h
