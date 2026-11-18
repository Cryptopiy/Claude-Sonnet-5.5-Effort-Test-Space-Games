class_name AudioAmbience
extends RefCounted
## Planet ambience bed: per-biome mixes of looped layers (wind / rustle / crickets / rumble / crackle / bubbles / waves / crystal / hum ...),
## plus random one-shots (birds, frogs, ice creaks, geiger ticks ...) placed around the listener. Driven either by Audio.set_ambient()
## or - when nobody calls it - by an automatic context probe (Frame anchor, atmosphere density, sun elevation, weather, ship / on-foot mode).

# layer: [loop, base gain, wind gain, day multiplier, night multiplier]
# event: [sound, min interval s, max interval s, day probability, night probability, level dB, min dist m, max dist m, max height m]
const PROFILES := {
	"lush": {"wind": 0.35, "radius_events": 1.0,
		"layers": [["amb_wind_low", 0.10, 0.60, 1.0, 1.0], ["amb_wind_mid", 0.03, 0.45, 1.0, 0.8], ["amb_rustle", 0.10, 0.60, 1.0, 0.5], ["amb_crickets", 0.0, 0.0, 0.0, 1.0]],
		"events": [["bird", 3.5, 9.0, 1.0, 0.05, -12.0, 15.0, 70.0, 18.0], ["frog", 6.0, 14.0, 0.0, 0.8, -14.0, 10.0, 40.0, 1.0]]},
	"desert": {"wind": 0.60,
		"layers": [["amb_wind_low", 0.18, 0.80, 1.0, 1.0], ["amb_wind_mid", 0.10, 0.70, 1.0, 1.0], ["amb_howl", 0.0, 0.55, 1.0, 1.0], ["amb_crickets", 0.0, 0.0, 0.0, 0.25]],
		"events": []},
	"frozen": {"wind": 0.75,
		"layers": [["amb_wind_low", 0.22, 0.60, 1.0, 1.0], ["amb_howl", 0.14, 0.90, 1.0, 1.0], ["amb_wind_mid", 0.08, 0.60, 1.0, 1.0]],
		"events": [["ice_creak", 9.0, 24.0, 1.0, 1.0, -10.0, 20.0, 80.0, 3.0], ["crystal_chime", 14.0, 30.0, 0.7, 1.0, -18.0, 15.0, 60.0, 8.0]]},
	"volcanic": {"wind": 0.45,
		"layers": [["amb_rumble", 0.55, 0.0, 1.0, 1.0], ["amb_crackle", 0.40, 0.0, 1.0, 1.0], ["amb_wind_low", 0.08, 0.60, 1.0, 1.0], ["amb_howl", 0.0, 0.25, 1.0, 1.0]],
		"events": [["wind_gust", 14.0, 30.0, 1.0, 1.0, -14.0, 20.0, 60.0, 5.0]]},
	"toxic": {"wind": 0.30,
		"layers": [["amb_toxic", 0.50, 0.0, 1.0, 1.0], ["amb_bubbles", 0.32, 0.0, 1.0, 1.0], ["amb_wind_low", 0.07, 0.40, 1.0, 1.0]],
		"events": [["spore_pop", 2.0, 6.0, 1.0, 1.0, -14.0, 5.0, 30.0, 3.0]]},
	"barren": {"wind": 0.0, "layers": [], "events": []},
	"ocean": {"wind": 0.55,
		"layers": [["amb_waves", 0.55, 0.30, 1.0, 1.0], ["amb_wind_low", 0.10, 0.55, 1.0, 1.0], ["amb_wind_mid", 0.04, 0.45, 1.0, 1.0]],
		"events": [["bird_2", 7.0, 16.0, 1.0, 0.0, -14.0, 25.0, 90.0, 25.0]]},
	"exotic": {"wind": 0.30,
		"layers": [["amb_crystal", 0.60, 0.0, 1.0, 1.0], ["amb_hum", 0.16, 0.0, 1.0, 1.0], ["amb_wind_low", 0.05, 0.50, 1.0, 1.0]],
		"events": [["crystal_chime", 5.0, 12.0, 1.0, 1.0, -15.0, 12.0, 60.0, 10.0]]},
	"swamp": {"wind": 0.20,
		"layers": [["amb_wind_low", 0.10, 0.50, 1.0, 1.0], ["amb_bubbles", 0.22, 0.0, 1.0, 1.0], ["amb_crickets", 0.0, 0.0, 0.2, 0.9], ["amb_hum", 0.05, 0.0, 1.0, 1.0]],
		"events": [["frog", 2.5, 7.0, 0.5, 1.0, -13.0, 8.0, 40.0, 1.0]]},
	"radioactive": {"wind": 0.35,
		"layers": [["amb_hum", 0.28, 0.0, 1.0, 1.0], ["amb_wind_low", 0.10, 0.60, 1.0, 1.0], ["amb_howl", 0.03, 0.50, 1.0, 1.0]],
		"events": []},
	"gas": {"wind": 0.80,
		"layers": [["amb_rumble", 0.50, 0.0, 1.0, 1.0], ["amb_wind_low", 0.30, 0.60, 1.0, 1.0], ["amb_howl", 0.20, 0.60, 1.0, 1.0]],
		"events": []},
}

var _manager: Node
var _bank: AudioSoundBank
var voices: Dictionary = {}                # loop name -> AudioLoopVoice
var _ext_until_ms: int = 0
var _ext: Dictionary = {"biome": "", "wind": 0.0, "night": 0.0, "in_space": false}
var wind_override: float = 0.0
var wind_override_until_ms: int = 0
var _probe_t: float = 0.0
var _ctx: Dictionary = {}
var _ctx_store: Dictionary = {}            # backing store of _ctx (reused by every probe)
var _event_next: Dictionary = {}           # event key -> next time (ms)
var _rng := RandomNumberGenerator.new()
var _geiger_next_ms: int = 0
var _thunder_next_ms: int = 0
var current_biome: String = ""
var _targets: Dictionary = {}              # reused every frame (no per-frame allocation)
var rain_level: float = 0.0
var cabin_factor: float = 0.0              # 0 = outside (on foot) .. 1 = inside the ship cabin (muffled)
var enabled: bool = true

func _init(manager: Node, bank: AudioSoundBank) -> void:
	_manager = manager
	_bank = bank
	_rng.randomize()

func set_external(biome: String, wind: float, night: float, in_space: bool) -> void:
	_ext = {"biome": biome, "wind": clampf(wind, 0.0, 1.0), "night": clampf(night, 0.0, 1.0), "in_space": in_space}
	_ext_until_ms = Time.get_ticks_msec() + 700

func context() -> Dictionary:
	return _ctx

func _voice(loop_name: String) -> AudioLoopVoice:
	var v: AudioLoopVoice = voices.get(loop_name, null)
	if v == null:
		v = AudioLoopVoice.new(_manager, _bank, loop_name)
		v.attack = 1.2
		v.release = 1.0
		voices[loop_name] = v
	return v

# ---------------------------------------------------------------------------------------------------------------------------------
# context probing
# ---------------------------------------------------------------------------------------------------------------------------------
func _probe() -> void:
	var c: Dictionary = _ctx_store
	c["biome"] = ""
	c["wind"] = 0.0
	c["night"] = 0.0
	c["density"] = 0.0
	c["menu"] = false
	c["in_space"] = true
	c["on_foot"] = false
	c["cabin"] = 0.0
	c["radiation"] = 0.0
	c["rain"] = 0.0
	c["atmosphere"] = false
	c["up"] = Vector3.UP
	c["fpos"] = Vector3.ZERO
	if Game.state == Game.State.MENU:
		c["menu"] = true
		_ctx = c
		return
	var def: BodyDef = Frame.anchor_def()
	c["on_foot"] = Game.mode == Game.Mode.FOOT
	if Game.mode == Game.Mode.SHIP:
		c["cabin"] = 1.0
	var focus: Node3D = Frame.focus
	var up := Vector3.UP
	var fpos := Vector3.ZERO
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		fpos = focus.global_position
	if def != null:
		if fpos.length() > 1.0:
			up = fpos.normalized()
		var alt: float = fpos.length() - def.radius
		var dens: float = 0.0
		var pl: Node3D = Frame.anchor_node()
		if def.kind == BodyDef.Kind.GAS_GIANT:
			dens = smoothstep(maxf(def.atmo_height, 3000.0) * 3.0, 0.0, maxf(alt, 0.0))
		elif def.has_atmosphere and pl != null and pl.has_method("atmosphere_density_at"):
			dens = float(pl.call("atmosphere_density_at", fpos))
		elif def.has_atmosphere and def.atmo_height > 0.0:
			dens = clampf(1.0 - alt / def.atmo_height, 0.0, 1.0)
		c["density"] = dens
		c["atmosphere"] = def.has_atmosphere or def.kind == BodyDef.Kind.GAS_GIANT
		c["biome"] = def.biome
		c["radiation"] = def.radiation
		c["in_space"] = dens < 0.02 and not (def.biome == "barren" and Game.mode == Game.Mode.FOOT)
		# night from the sun's elevation above the local horizon
		var elev: float = Frame.sun_dir.dot(up)
		c["night"] = smoothstep(0.08, -0.22, elev)
		# wind
		var base: float = float((PROFILES.get(def.biome, PROFILES["barren"]) as Dictionary).get("wind", 0.0))
		var t: float = Universe.time
		var wob: float = 0.80 + 0.20 * sin(t * 0.021 + float(def.seed % 97)) * sin(t * 0.0073 + float(def.seed % 31))
		var weather_k: float = 0.55
		var wx: Node = Game.weather
		if wx != null and is_instance_valid(wx):
			for prop in ["intensity", "weather_intensity", "wind", "wind_strength", "strength", "level"]:
				var pv: Variant = wx.get(prop)
				if pv is float:
					weather_k = 0.35 + 0.65 * clampf(pv, 0.0, 1.0)
					if prop == "intensity" or prop == "weather_intensity":
						# WeatherFX.kind names the precipitation ("rain", "heavy rain", "snow", "dust storm" ...): only rain makes rain noise
						var kind_v: Variant = wx.get("kind")
						var is_rain: bool = (kind_v as String).find("rain") >= 0 if kind_v is String else def.biome in ["lush", "ocean", "swamp"]
						if is_rain:
							c["rain"] = clampf(((pv as float) - 0.2) / 0.5, 0.0, 1.0)
					break
		var w: float = base * wob * (0.55 + 0.45 * weather_k)
		# moving fast through the air (on foot sprinting, flying low) adds wind
		var spd: float = float(Game.tel.get("speed", 0.0))
		w += clampf(spd / 120.0, 0.0, 0.5) * dens * (0.5 if c["on_foot"] else 0.8)
		# thin air up high = softer wind
		c["wind"] = clampf(w, 0.0, 1.0) * dens
	elif Game.mode == Game.Mode.FOOT:
		c["in_space"] = false
	# external overrides
	if Time.get_ticks_msec() < _ext_until_ms:
		c["biome"] = _ext["biome"] if _ext["biome"] != "" else c["biome"]
		var bw: float = float((PROFILES.get(_ext["biome"], {}) as Dictionary).get("wind", 0.5))
		c["wind"] = clampf(float(_ext["wind"]) * clampf(bw / 0.5, 0.0, 1.6), 0.0, 1.0)
		c["night"] = _ext["night"]
		c["in_space"] = _ext["in_space"]
		c["density"] = 0.0 if _ext["in_space"] else maxf(float(c["density"]), 0.8)
	if Time.get_ticks_msec() < wind_override_until_ms:
		c["wind"] = maxf(float(c["wind"]), wind_override)
	_ctx = c
	# keep the listener anchor for one-shots
	_ctx["up"] = up
	_ctx["fpos"] = fpos

# ---------------------------------------------------------------------------------------------------------------------------------
# per-frame update
# ---------------------------------------------------------------------------------------------------------------------------------
func update(dt: float) -> void:
	if not enabled:
		return
	_probe_t -= dt
	if _probe_t <= 0.0:
		_probe_t = 0.08
		_probe()
	var c: Dictionary = _ctx
	if c.is_empty():
		return
	var biome: String = c.get("biome", "")
	var dens: float = c.get("density", 0.0)
	var night: float = c.get("night", 0.0)
	var wind: float = c.get("wind", 0.0)
	var cabin: float = c.get("cabin", 0.0)
	if biome != current_biome and biome != "":
		_prioritize_biome(biome)
	current_biome = biome
	cabin_factor += (cabin - cabin_factor) * (1.0 - exp(-4.0 * dt))
	var targets: Dictionary = _targets  # loop -> gain (cleared, not re-created)
	targets.clear()
	var planetary: float = clampf(dens * 1.4, 0.0, 1.0)         # how much of the planet bed is audible (thin air = quiet)
	var is_menu: bool = c.get("menu", false)
	var space_gain: float = 0.0
	if is_menu:
		space_gain = 0.9
	else:
		space_gain = 0.55 * (1.0 - planetary * 0.8)
		if c.get("on_foot", false) and dens < 0.1:
			space_gain *= 0.45
	targets["amb_space"] = space_gain
	if not is_menu:
		# a faint life-support hum when you are outside without much air, or always very low on foot
		var suit: float = 0.0
		if c.get("on_foot", false):
			suit = 0.35 + 0.65 * (1.0 - planetary)
		targets["amb_suit"] = suit
		var prof: Dictionary = PROFILES.get(biome, {})
		if not prof.is_empty() and dens > 0.01:
			var cabin_att: float = 1.0 - 0.55 * cabin_factor        # the cabin hull masks the outside bed
			for L in prof["layers"]:
				var g: float = (float(L[1]) + float(L[2]) * wind) * lerpf(float(L[3]), float(L[4]), night) * planetary * cabin_att
				targets[L[0]] = float(targets.get(L[0], 0.0)) + g
		var rain: float = float(c.get("rain", 0.0))
		if rain > 0.01:
			targets["amb_rain"] = rain * 0.8 * planetary * (1.0 - 0.5 * cabin_factor)
	# apply
	for k in targets:
		_voice(k).target = float(targets[k])
	for k in voices:
		if not targets.has(k):
			(voices[k] as AudioLoopVoice).target = 0.0
	for k in voices:
		(voices[k] as AudioLoopVoice).update(dt)
	if not is_menu and Game.state == Game.State.PLAYING:
		_update_events(c, planetary, wind, night)

## a new biome: make sure its loops / one-shots are the next things the synthesis thread builds (no-op when everything is built already)
func _prioritize_biome(biome: String) -> void:
	var prof: Dictionary = PROFILES.get(biome, {})
	if prof.is_empty():
		return
	var names: Array = []
	for L in prof["layers"]:
		names.append(L[0])
	for e in prof["events"]:
		var en: String = e[0]
		if AudioRecipes.VARIANTS.has(en):
			for vi in int(AudioRecipes.VARIANTS[en]):
				names.append("%s_%d" % [en, vi])
		else:
			names.append(en)
	_bank.prioritize(names)

func _update_events(c: Dictionary, planetary: float, wind: float, night: float) -> void:
	var biome: String = c.get("biome", "")
	var prof: Dictionary = PROFILES.get(biome, {})
	var now: int = Time.get_ticks_msec()
	if prof.is_empty() or planetary < 0.35 or c.get("cabin", 0.0) > 0.5:
		return
	var evs: Array = prof.get("events", [])
	for i in evs.size():
		var e: Array = evs[i]
		var key: String = "%s:%d" % [biome, i]
		if not _event_next.has(key):
			_event_next[key] = now + int(_rng.randf_range(float(e[1]) * 0.3, float(e[2])) * 1000.0)
			continue
		if now < int(_event_next[key]):
			continue
		_event_next[key] = now + int(_rng.randf_range(float(e[1]), float(e[2])) * 1000.0)
		var prob: float = lerpf(float(e[3]), float(e[4]), night)
		if _rng.randf() > prob:
			continue
		_play_around(String(e[0]), float(e[5]), float(e[6]), float(e[7]), float(e[8]))
	# distant thunder during heavy rain (2D: it is far away and mostly sub-bass anyway)
	var rain_now: float = c.get("rain", 0.0)
	if rain_now > 0.7 and now >= _thunder_next_ms:
		_thunder_next_ms = now + int(_rng.randf_range(16.0, 40.0) * 1000.0)
		if _rng.randf() < 0.8:
			_manager.call("play_sfx", "thunder_far", Vector3.INF, _rng.randf_range(-7.0, -1.0), _rng.randf_range(0.9, 1.1))
	# geiger counter: tick rate grows with radiation of the biome
	var rad: float = c.get("radiation", 0.0)
	if rad > 0.05 and now >= _geiger_next_ms:
		var mean_s: float = lerpf(1.4, 0.07, clampf(rad, 0.0, 1.0))
		_geiger_next_ms = now + int(-log(maxf(_rng.randf(), 0.001)) * mean_s * 1000.0)
		_manager.call("play_sfx", "geiger_tick", Vector3.INF, -4.0 + 8.0 * rad, 1.0)

func _play_around(sound: String, db: float, dmin: float, dmax: float, hmax: float) -> void:
	var cam: Camera3D = Game.active_camera()
	var up: Vector3 = _ctx.get("up", Vector3.UP)
	if cam == null:
		return
	var r := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	r -= up * r.dot(up)
	if r.length() < 0.01:
		r = up.cross(Vector3.RIGHT)
	r = r.normalized() * _rng.randf_range(dmin, dmax) + up * _rng.randf_range(0.5, maxf(hmax, 0.6))
	_manager.call("play_sfx", sound, cam.global_position + r, db, 1.0)

func stop_all_now() -> void:
	for k in voices:
		(voices[k] as AudioLoopVoice).stop_now()
