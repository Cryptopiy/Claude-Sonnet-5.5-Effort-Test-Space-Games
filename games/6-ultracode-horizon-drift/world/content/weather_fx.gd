class_name WeatherFX
extends Node3D
## WEATHER PARTICLES (module m7b_life).  One instance (Game.weather) follows the active camera.
## Per-biome particle weather built from camera-wrapped MultiMesh lattices animated entirely in the vertex shader (shaders/weather_particles.gdshader):
## rain (lush / ocean / swamp), dust storms (desert), snow + blizzard gusts (frozen), ash + embers (volcanic), drifting spores + caustic mist (toxic),
## glowing motes (exotic), isotopes (radioactive), faint space dust in space.  Nothing on airless bodies.
## Intensity cycles smoothly with Universe.time and the planet seed, fades with altitude (zero above the atmosphere), the wind is horizontal with respect to the
## local "up" (planet radial direction).  A depth-aware tinted fog quad makes storms readable even without the sky module's help.
##
## Public API:  fog_boost (>= 1.0 Mie-density multiplier read by M2's AtmosphereEffect: 1 = clear air, up to ~4 in a dust storm),  fog_amount (0..1 haze strength),  fog_color,
##              intensity (0..1 strongest precipitation),  kind (String: "clear","rain","snow","blizzard","dust storm","ash","spores","motes"),
##              wind (Vector3, LOCAL space m/s), set_debug(intensity: float, biome: String = "")  (test hook; also --weather=<0..1> / --weather-biome=<id> user args)

const PARTICLE_SHADER := "res://shaders/weather_particles.gdshader"
const FOG_SHADER := "res://shaders/weather_fog.gdshader"

var fog_boost: float = 1.0
var fog_amount: float = 0.0
var fog_color: Color = Color(0.7, 0.7, 0.7)
var intensity: float = 0.0
var kind: String = "clear"
var wind: Vector3 = Vector3.ZERO
var enabled: bool = true

var _layers: Dictionary = {}          # "profile/layer id" -> runtime dict
var _profile: String = "none"
var _channels: Dictionary = {}
var _fog_mi: MeshInstance3D
var _fog_mat: ShaderMaterial
var _fog_amount: float = 0.0
var _fog_density_cur: float = 0.0
var _fog_col_cur: Color = Color(0.7, 0.7, 0.7)
var _last_cam: Vector3 = Vector3.ZERO
var _have_last: bool = false
var _cam_vel: Vector3 = Vector3.ZERO
var _shader_normal: Shader
var _shader_add: Shader
var _force: float = -1.0
var _force_biome: String = ""
var _wind_ang: float = 0.0
var _wind_speed: float = 0.0
var _sun_cache: float = 1.0
var debug_fog_color: Color = Color(0, 0, 0, 0)      # test hook: alpha > 0 replaces the fog colour (e.g. magenta to see where the fog quad draws)

func _ready() -> void:
	process_priority = 50           # after gameplay (camera moved), before Frame (100)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--weather="):
			_force = float(s.substr(10))
		elif s.begins_with("--weather-biome="):
			_force_biome = s.substr(16)
	var src := FileAccess.get_file_as_string(PARTICLE_SHADER)
	_shader_normal = Shader.new()
	_shader_normal.code = src
	_shader_add = Shader.new()
	_shader_add.code = src.replace("blend_mix", "blend_add")
	_make_fog_quad()
	Frame.frame_changed.connect(func(_o: int, _n: int) -> void: _have_last = false)
	Frame.origin_shifted.connect(func(shift: Vector3) -> void: _last_cam += shift)

## test hook: force precipitation intensity (0..1, <0 = natural weather) and optionally the biome profile
func set_debug(p_intensity: float, p_biome: String = "") -> void:
	_force = p_intensity
	_force_biome = p_biome

# =====================================================================================================================
# frame update
# =====================================================================================================================
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var cam: Camera3D = Game.active_camera() if is_instance_valid(Game.world) else null
	if cam == null or not enabled or Game.state != Game.State.PLAYING or Universe.system == null:
		_fade_everything(dt)
		return
	var cam_pos := cam.global_position
	# camera velocity (world / local space), robust against teleports + frame shifts
	if _have_last and dt > 0.0:
		var v := (cam_pos - _last_cam) / dt
		if v.length() > 4000.0:
			v = _cam_vel
		_cam_vel = _cam_vel.lerp(v, 1.0 - exp(-dt * 25.0))
	else:
		_cam_vel = Vector3.ZERO
	_last_cam = cam_pos
	_have_last = true

	# ---- where are we? -------------------------------------------------------------------------------------------
	var def: BodyDef = Frame.anchor_def()
	var up := Vector3.UP
	var alt := 1.0e9
	var profile := "none"
	var seed_v := 1
	var atmo_h := 4000.0
	var underwater := false
	if def != null:
		up = cam_pos.normalized()
		seed_v = def.seed
		atmo_h = maxf(def.atmo_height, 2500.0)
		var pl := Frame.anchor_node() as Planet
		if pl != null:
			alt = pl.altitude_of(cam_pos)
			var sea := pl.sea_radius()
			underwater = sea > 0.0 and cam_pos.length() < sea - 0.5
		else:
			alt = cam_pos.length() - def.radius
		if def.kind == BodyDef.Kind.GAS_GIANT:
			profile = "space"
		elif not def.has_atmosphere:
			profile = "none"
		else:
			profile = def.biome
			if alt > atmo_h * 1.25:
				profile = "space"
	else:
		profile = "space"
		seed_v = Universe.system.seed
	if _force_biome != "":
		profile = _force_biome
	if underwater:
		profile = "none"
	_profile = profile

	# ---- altitude / time-of-day factors --------------------------------------------------------------------------
	var ceiling := clampf(atmo_h * 0.55, 700.0, 2600.0)
	var alt_f := 1.0
	if profile == "space":
		alt_f = 1.0 if def == null else smoothstep(1.25, 1.6, alt / atmo_h)
		if def != null and def.kind == BodyDef.Kind.GAS_GIANT:
			alt_f = 1.0
	elif profile != "none":
		alt_f = 1.0 - smoothstep(0.3, 1.0, alt / ceiling)
	if _force_biome != "":
		alt_f = 1.0
	var sun_day := 1.0
	if def != null:
		sun_day = smoothstep(-0.18, 0.3, up.dot(Frame.sun_dir))
	_sun_cache = lerpf(_sun_cache, sun_day, 1.0 - exp(-dt * 2.0))
	var light := lerpf(0.07, 1.0, _sun_cache)

	# ---- weather channels + wind ---------------------------------------------------------------------------------
	var t := Universe.time
	var prof := WeatherProfiles.get_profile(profile)
	var ramp := smoothstep(40.0, 220.0, Game.playing_time)
	_channels = _compute_channels(profile, t, seed_v, ramp)
	var storm: float = float(_channels.get("storm", 0.0))
	var wind_pair: Array = prof["wind"]
	var g := 0.5 + 0.5 * sin(t * 0.61 + float(seed_v & 255)) * sin(t * 0.173 + 1.3)
	_wind_speed = lerpf(float(wind_pair[0]), float(wind_pair[1]), storm) * (0.78 + 0.44 * g)
	_wind_ang = float(seed_v % 6283) * 0.001 + t * 0.004
	var east := Vector3.UP.cross(up)
	if east.length() < 0.2:
		east = Vector3.RIGHT.cross(up)
	east = east.normalized()
	var north := up.cross(east).normalized()
	var axes := Basis(east, up, north)
	var wind_w := Vector3(cos(_wind_ang), 0.0, sin(_wind_ang)) * _wind_speed
	wind = axes * wind_w

	# ---- layers ---------------------------------------------------------------------------------------------------
	var strongest := 0.0
	var strongest_chan := ""
	var cfgs: Array = prof["layers"]
	for cfg in cfgs:
		var key := profile + "/" + String(cfg["id"])
		if not _layers.has(key):
			_layers[key] = _make_layer(key, profile, cfg)
	for key in _layers:
		var L: Dictionary = _layers[key]
		var cfg: Dictionary = L["cfg"]
		var target := 0.0
		if L["profile"] == profile:
			var chv: float = float(_channels.get(cfg["chan"], 0.0))
			target = clampf(chv * float(cfg.get("scale", 1.0)), 0.0, 1.0) * alt_f
			if chv * alt_f > strongest and cfg["chan"] != "ambient" and cfg["chan"] != "space":
				strongest = chv * alt_f
				strongest_chan = cfg["chan"]
		L["fade"] = move_toward(float(L["fade"]), target, dt * 0.5) if target < float(L["fade"]) else move_toward(float(L["fade"]), target, dt * 0.35)
		var mmi: MultiMeshInstance3D = L["node"]
		var fade: float = L["fade"]
		mmi.visible = fade > 0.003
		if not mmi.visible:
			continue
		mmi.global_position = cam_pos
		var mat: ShaderMaterial = L["mat"]
		mat.set_shader_parameter("intensity", fade)
		mat.set_shader_parameter("axes", axes)
		mat.set_shader_parameter("cam_vel", _cam_vel)
		var vel := Vector3(wind_w.x * float(cfg.get("wind", 0.0)), -float(cfg.get("fall", 0.0)), wind_w.z * float(cfg.get("wind", 0.0)))
		mat.set_shader_parameter("velocity", vel)
		if float(cfg.get("glow", 0.0)) <= 0.0:
			mat.set_shader_parameter("light", light)

	intensity = strongest
	kind = _kind_of(strongest_chan, strongest)

	# ---- fog -------------------------------------------------------------------------------------------------------
	var fog_target := 0.0
	var fog_cfg: Dictionary = prof["fog"]
	if not fog_cfg.is_empty():
		fog_target = clampf(float(fog_cfg["base"]) + float(_channels.get(fog_cfg["chan"], 0.0)) * float(fog_cfg["scale"]), 0.0, 1.0) * alt_f
		fog_color = fog_cfg["color"]
		_fog_density_cur = float(fog_cfg["density"])
		_fog_col_cur = fog_color
	fog_amount = move_toward(fog_amount, fog_target, dt * 0.15)
	fog_boost = 1.0 + float(fog_cfg.get("boost", 0.0)) * fog_amount if not fog_cfg.is_empty() else 1.0
	_update_fog(cam_pos, light, up)

func _fade_everything(dt: float) -> void:
	for key in _layers:
		var L: Dictionary = _layers[key]
		L["fade"] = 0.0
		(L["node"] as MultiMeshInstance3D).visible = false
	fog_amount = 0.0
	fog_boost = 1.0
	intensity = 0.0
	kind = "clear"
	if _fog_mi != null:
		_fog_mi.visible = false
	_have_last = false

func _kind_of(chan: String, strength: float) -> String:
	if strength < 0.08:
		return "clear"
	match chan:
		"rain": return "heavy rain" if strength > 0.7 else "rain"
		"snow": return "snow"
		"blizzard": return "blizzard"
		"dust": return "dust storm"
		"ash": return "ash fall"
		"embers": return "embers"
		"spores": return "spore drift"
		"mist": return "caustic mist"
		"motes": return "glowing motes"
	return "clear"

# =====================================================================================================================
# channels: smooth deterministic cycles (value noise in Universe.time, seeded per planet)
# =====================================================================================================================
static func _cycle(t: float, seed_v: int, period: float, salt: int) -> float:
	var x := t / period
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	var a := SeedUtil.rand01(seed_v + salt * 7919, i)
	var b := SeedUtil.rand01(seed_v + salt * 7919, i + 1)
	return lerpf(a, b, f)

func _compute_channels(profile: String, t: float, seed_v: int, ramp: float) -> Dictionary:
	var c1 := _cycle(t, seed_v, 260.0, 11)
	var c2 := _cycle(t, seed_v, 95.0, 23)
	var c3 := _cycle(t, seed_v, 40.0, 37)
	var ch: Dictionary = {"ambient": 1.0, "space": 1.0}
	match profile:
		"lush":
			ch["rain"] = smoothstep(0.52, 0.80, c1) * 0.72 * ramp
			ch["storm"] = ch["rain"]
		"ocean":
			ch["rain"] = smoothstep(0.42, 0.78, c1) * (0.65 + 0.35 * c3) * ramp
			ch["storm"] = ch["rain"]
		"swamp":
			ch["rain"] = smoothstep(0.35, 0.72, c1) * 0.55 * ramp
			ch["storm"] = ch["rain"] * 0.6
		"desert":
			var d := smoothstep(0.46, 0.80, c1) * (0.8 + 0.2 * c3) * ramp
			ch["dust"] = d
			ch["storm"] = d
			ch["ambient"] = 0.22 + 0.25 * c2
		"frozen":
			var sn := (0.38 + 0.62 * smoothstep(0.15, 0.7, c1)) * clampf(ramp + 0.35, 0.0, 1.0)
			var bz := smoothstep(0.62, 0.9, c2 * 0.55 + c1 * 0.45) * ramp
			ch["snow"] = sn
			ch["blizzard"] = bz
			ch["storm"] = maxf(bz, sn * 0.35)
		"volcanic":
			ch["ash"] = (0.42 + 0.58 * c1) * clampf(ramp + 0.4, 0.0, 1.0)
			ch["embers"] = 0.45 + 0.55 * c2
			ch["storm"] = ch["ash"] * 0.6
		"toxic":
			ch["spores"] = 0.6 + 0.4 * c1
			ch["mist"] = 0.15 + 0.85 * smoothstep(0.3, 0.8, c2)
			ch["storm"] = ch["mist"] * 0.5
		"exotic":
			ch["motes"] = 0.7 + 0.3 * c1
			ch["storm"] = 0.0
		"radioactive":
			ch["ash"] = 0.35 + 0.4 * c1
			ch["motes"] = 0.6 + 0.4 * c2
			ch["storm"] = 0.2
		"space":
			ch["space"] = 1.0
			ch["storm"] = 0.0
		_:
			ch["storm"] = 0.0
	if _force >= 0.0 and profile != "space":
		for k in ["rain", "dust", "snow", "blizzard", "ash", "embers", "spores", "mist", "motes"]:
			if ch.has(k):
				ch[k] = maxf(float(ch[k]), _force)
		ch["storm"] = maxf(float(ch.get("storm", 0.0)), _force)
	return ch

# =====================================================================================================================
# layer / fog construction
# =====================================================================================================================
func _make_layer(key: String, profile: String, cfg: Dictionary) -> Dictionary:
	var n: int = int(cfg["count"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = n
	var r := RandomNumberGenerator.new()
	r.seed = hash(key) & 0x7fffffff
	for i in n:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(r.randf(), r.randf(), r.randf(), float(i) / float(n)))   # w = visibility rank (evenly spread => intensity == fraction shown)
		mm.set_instance_color(i, Color(r.randf(), r.randf(), r.randf(), r.randf()))
	var box: Vector3 = cfg["box"]
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = key.replace("/", "_")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(-box * 0.75, box * 1.5)
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visible = false
	var mat := ShaderMaterial.new()
	var additive: bool = float(cfg.get("glow", 0.0)) > 0.0 and profile != "space"
	mat.shader = _shader_add if additive else _shader_normal
	mat.render_priority = 60
	mat.set_shader_parameter("box_size", box)
	mat.set_shader_parameter("flutter", float(cfg.get("flutter", 0.0)))
	mat.set_shader_parameter("flutter_freq", float(cfg.get("ff", 1.0)))
	mat.set_shader_parameter("size", float(cfg["size"]))
	mat.set_shader_parameter("streak_time", float(cfg.get("streak", 0.0)))
	mat.set_shader_parameter("max_len", float(cfg.get("max_len", 2.0)))
	mat.set_shader_parameter("color_a", cfg["a"])
	mat.set_shader_parameter("color_b", cfg["b"])
	mat.set_shader_parameter("glow", float(cfg.get("glow", 0.0)))
	mat.set_shader_parameter("soft", float(cfg.get("soft", 1.0)))
	mat.set_shader_parameter("twinkle", float(cfg.get("twinkle", 0.0)))
	mat.set_shader_parameter("near_fade_a", float(cfg.get("near_a", 1.5)))
	mat.set_shader_parameter("near_fade_b", float(cfg.get("near_b", 4.5)))
	mmi.material_override = mat
	add_child(mmi)
	return {"node": mmi, "mat": mat, "cfg": cfg, "fade": 0.0, "profile": profile}

func _make_fog_quad() -> void:
	_fog_mi = MeshInstance3D.new()
	_fog_mi.name = "WeatherFog"
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_fog_mi.mesh = q
	_fog_mi.custom_aabb = AABB(Vector3(-1.0e7, -1.0e7, -1.0e7), Vector3(2.0e7, 2.0e7, 2.0e7))      # same setup as the atmosphere post-process quads
	_fog_mi.ignore_occlusion_culling = true
	_fog_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = load(FOG_SHADER)
	_fog_mat.render_priority = 50
	_fog_mi.material_override = _fog_mat
	_fog_mi.visible = false
	add_child(_fog_mi)

func _update_fog(cam_pos: Vector3, light: float, up: Vector3) -> void:
	if _fog_mi == null:
		return
	var a := fog_amount
	_fog_amount = lerpf(_fog_amount, a, 0.2)
	_fog_mi.visible = _fog_amount > 0.01
	if not _fog_mi.visible:
		return
	_fog_mat.set_shader_parameter("fog_color", debug_fog_color if debug_fog_color.a > 0.0 else _fog_col_cur)
	_fog_mat.set_shader_parameter("density", _fog_density_cur * (0.15 + 0.85 * _fog_amount))
	_fog_mat.set_shader_parameter("amount", clampf(_fog_amount * 1.6, 0.0, 1.0))
	_fog_mat.set_shader_parameter("light", light)
	_fog_mat.set_shader_parameter("sun_world", Frame.sun_dir)
