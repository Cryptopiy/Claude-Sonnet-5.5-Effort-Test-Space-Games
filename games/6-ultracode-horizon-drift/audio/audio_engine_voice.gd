class_name AudioEngineVoice
extends RefCounted
## Layered ship engine: rumble (sub-bass) + roar (mid noise) + whine (turbine tone) + boost scream + pulse-drive hum + air rush.
## `set_engine()` stores targets; `update(dt)` smooths them, mixes the layers and maps throttle/boost/pulse/speed/density to gain + pitch.
## If nobody calls set_engine() (module forgot) a fallback reads Game.tel / the ship so the ship still sounds alive.

const LAYERS := ["eng_rumble", "eng_roar", "eng_whine", "eng_boost", "eng_pulse", "eng_wind"]

var layers: Dictionary = {}
var fallback_enabled: bool = true
var using_fallback: bool = false
var last_call_ms: int = -100000

# raw targets (from set_engine / fallback)
var _on: bool = false
var _throttle: float = 0.0
var _boost: float = 0.0
var _pulse: float = 0.0
var _dens: float = 0.0
var _speed: float = 0.0
# smoothed
var _on_gain: float = 0.0
var s_throttle: float = 0.0
var s_boost: float = 0.0
var s_pulse: float = 0.0
var s_dens: float = 0.0
var s_speed: float = 0.0
var _manager: Node

func _init(owner_node: Node, bank: AudioSoundBank) -> void:
	_manager = owner_node
	for l in LAYERS:
		var v := AudioLoopVoice.new(owner_node, bank, l)
		v.attack = 6.0
		v.release = 2.0
		layers[l] = v

func set_engine(throttle: float, boost: bool, pulse: bool, atmo_density: float, speed: float) -> void:
	last_call_ms = Time.get_ticks_msec()
	using_fallback = false
	_on = true
	_throttle = clampf(throttle, 0.0, 1.0)
	_boost = 1.0 if boost else 0.0
	_pulse = 1.0 if pulse else 0.0
	_dens = clampf(atmo_density, 0.0, 1.0)
	_speed = maxf(speed, 0.0)

func stop() -> void:
	_on = false
	last_call_ms = Time.get_ticks_msec()
	using_fallback = false

func is_running() -> bool:
	return _on_gain > 0.02

func _pull_fallback() -> void:
	_on = false
	if Game.state != Game.State.PLAYING and Game.state != Game.State.PAUSED:
		return
	if Game.mode != Game.Mode.SHIP or Game.ship == null or not is_instance_valid(Game.ship):
		return
	if bool(Game.ship.get("is_landed")):
		return
	var pil: Variant = Game.ship.get("piloted")
	if pil != null and not bool(pil):
		return                 # nobody is flying: an unmanned ship makes no engine noise
	using_fallback = true
	_on = true
	var tel: Dictionary = Game.tel
	var vel: Variant = Game.ship.get("velocity")
	var spd: float = float(tel.get("speed", (vel as Vector3).length() if vel is Vector3 else 0.0))
	var thr: float = float(tel.get("throttle", clampf(Input.get_action_strength("move_forward") + 0.25, 0.0, 1.0)))
	_throttle = clampf(thr, 0.0, 1.0)
	_boost = 1.0 if bool(tel.get("boost", Input.is_action_pressed("sprint"))) else 0.0
	_pulse = 1.0 if bool(tel.get("pulse", false)) else 0.0
	_dens = _manager.call("atmosphere_density_at_focus")
	_speed = spd

func update(dt: float) -> void:
	var fresh: bool = Time.get_ticks_msec() - last_call_ms < 450
	if not fresh:
		if fallback_enabled:
			_pull_fallback()
		else:
			_on = false
	var run: bool = _on
	var sh: Node = Game.ship
	if sh != null and is_instance_valid(sh) and bool(sh.get("is_landed")):
		# engines are off while landed (even if the ship keeps reporting) EXCEPT while spooling up for take-off (ship.fx_spool 0..1):
		# then the rumble / whine rise with the spool so the player hears the engines light before the ship lifts off
		var spool_in: float = clampf(float(sh.get("fx_spool")), 0.0, 1.0)
		run = Game.mode == Game.Mode.SHIP and spool_in > 0.03
		if run:
			_throttle = maxf(_throttle, 0.10 + 0.55 * spool_in)
			_dens = maxf(_dens, 0.0)
	_on_gain += ((1.0 if run else 0.0) - _on_gain) * (1.0 - exp(-(3.5 if run else 1.6) * dt))
	if _on_gain < 0.01 and not run:
		_on_gain = 0.0
	s_throttle += (_throttle - s_throttle) * (1.0 - exp(-3.0 * dt))
	s_boost += (_boost - s_boost) * (1.0 - exp(-5.0 * dt))
	s_pulse += (_pulse - s_pulse) * (1.0 - exp(-1.8 * dt))
	s_dens += (_dens - s_dens) * (1.0 - exp(-2.5 * dt))
	s_speed += (_speed - s_speed) * (1.0 - exp(-2.5 * dt))
	var on_g: float = _on_gain
	var sag: float = 0.55 + 0.45 * on_g             # pitch sags as the engine spools down
	var thr: float = s_throttle
	var b: float = s_boost
	var p: float = s_pulse
	var d: float = s_dens
	var sp: float = clampf(s_speed / 500.0, 0.0, 1.0)
	var calm: float = 1.0 - 0.7 * p                  # pulse drive hides the combustion layers

	var l: AudioLoopVoice = layers["eng_rumble"]
	l.target = on_g * (0.40 + 0.60 * thr) * (1.0 - 0.35 * p)
	l.target_pitch = sag * (0.74 + 0.45 * thr + 0.18 * b)

	l = layers["eng_roar"]
	l.target = on_g * (0.04 + 0.62 * thr) * (0.45 + 0.55 * d) * (1.0 + 0.5 * b) * calm
	l.target_pitch = sag * (0.85 + 0.35 * thr + 0.1 * b)

	l = layers["eng_whine"]
	l.target = on_g * (0.12 + 0.50 * thr) * (1.0 + 0.3 * b) * calm
	l.target_pitch = sag * (0.8 + 0.5 * thr + 0.25 * b + 0.2 * sp)

	l = layers["eng_boost"]
	l.target = on_g * b * (0.35 + 0.55 * thr) * calm
	l.target_pitch = sag * (0.90 + 0.15 * thr)

	l = layers["eng_pulse"]
	l.target = on_g * p * 0.95
	l.target_pitch = 0.75 + 0.55 * sqrt(clampf(s_speed / 40000.0, 0.0, 1.0))

	l = layers["eng_wind"]
	l.target = on_g * pow(clampf(s_speed / 450.0, 0.0, 1.0), 1.3) * pow(d, 0.6) * 0.9
	l.target_pitch = 0.8 + 0.6 * clampf(s_speed / 700.0, 0.0, 1.0)

	for key in layers:
		(layers[key] as AudioLoopVoice).update(dt)

func stop_all_now() -> void:
	_on = false
	_on_gain = 0.0
	for key in layers:
		(layers[key] as AudioLoopVoice).stop_now()
