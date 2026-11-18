class_name SkyController
extends Node
## SKY / ENVIRONMENT / SUN LIGHT (module M2).
## Owns the WorldEnvironment (procedural star sky = shaders/sky.gdshader, glow, tonemap, SSAO, ambient colour) and the DirectionalLight3D "sun".
## Every frame it works out, for the camera's current surroundings:
##   * the sun's visible fraction (disc overlap with every body = horizon + eclipses, soft because the star is a big disc),
##   * the atmospheric transmittance of the sunlight (per channel => orange/red sunsets, white noon, nothing in space),
##   * the ambient colour / energy (sky colour by day + twilight, blue-ish moon/star light at night, near-black hard light in space),
## and publishes the global shader params  sun_color / sun_energy / night_amount  (sun_dir + sky_basis are set by Frame).

const SUN_ENERGY_SCALE := 2.0

var env: Environment
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ShaderMaterial

## state published for other modules
var sun_color_now: Color = Color(1, 1, 1)
var sun_energy_now: float = 1.0
var night_now: float = 0.0
var daylight: float = 1.0               # 0 = night .. 1 = full day at the camera
var sun_elevation_deg: float = 90.0     # at the camera, over the local horizon (planet frames only)
var sun_visible: float = 1.0            # 0..1 visible fraction of the star's disc
var in_atmosphere: float = 0.0          # 0..1 how much atmosphere surrounds the camera (density at the camera)

var _sys_key: int = -999
var _prof_key: int = -999
var _prof: Dictionary = {}
var _coef: Dictionary = {}
var _amb_col: Color = Color(0.1, 0.1, 0.12)
var _amb_energy: float = 1.0
var _sky_amb_sent: Color = Color(-1, -1, -1)
var _sky_timer: float = 0.0
var _aurora_t: float = 0.0
var _exposure: float = 1.0
var _star_vis_sent: float = -1.0

func _ready() -> void:
	process_priority = 150           # after Frame (100): bodies / sun direction of this frame are final
	_build_environment()
	_build_sun()

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _amb_col
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	# Bloom: only genuinely HDR things (star, lava, engine flames, sun glints) bleed. A low threshold + big blur levels turned the star and every
	# sunlit planet into a white wash (see architect shots), so: high threshold, modest intensity, mostly small/medium radii.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.7
	env.glow_hdr_scale = 1.6
	env.glow_hdr_luminance_cap = 12.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.55)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	env.set_glow_level(5, 0.12)
	env.set_glow_level(6, 0.0)
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.0
	env.ssao_power = 1.6
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.2
	env.ssil_enabled = false
	env.fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 650.0
	sun.directional_shadow_split_1 = 0.04
	sun.directional_shadow_split_2 = 0.14
	sun.directional_shadow_split_3 = 0.40
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.9
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.0
	add_child(sun)

# ---------------------------------------------------------------------------------------------------------------------------------------------
func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam.global_position
	if Frame.focus != null and is_instance_valid(Frame.focus) and Frame.focus.is_inside_tree():
		return Frame.focus.global_position
	return Vector3.ZERO

func _update_system_look() -> void:
	var key := Universe.current_id
	if key == _sys_key or Universe.system == null:
		return
	_sys_key = key
	var gs := Universe.current_star()
	var s := Universe.system.seed
	var gal := -gs.pos
	gal.y = 0.0
	if gal.length() < 1.0:
		gal = Vector3.RIGHT
	sky_mat.set_shader_parameter("gal_center", gal.normalized())
	sky_mat.set_shader_parameter("neb_seed", float(SeedUtil.rand01(s, 41)) * 50.0 + 1.0)
	sky_mat.set_shader_parameter("neb_a", Color.from_hsv(SeedUtil.rand01(s, 42), 0.55 + 0.3 * SeedUtil.rand01(s, 43), 0.95))
	sky_mat.set_shader_parameter("neb_b", Color.from_hsv(fposmod(SeedUtil.rand01(s, 42) + 0.25 + 0.3 * SeedUtil.rand01(s, 44), 1.0), 0.6, 0.95))
	_sky_amb_sent = Color(-1, -1, -1)

func _profile_for(def: BodyDef) -> void:
	if def == null:
		_prof_key = -999
		_prof = {}
		return
	var key := def.index + 1000 * Universe.current_id
	if key == _prof_key:
		return
	_prof_key = key
	if def.has_atmosphere and def.atmo_height > 0.0:
		_prof = AtmosphereProfiles.get_profile(def.biome, def)
		_coef = AtmosphereProfiles.coefficients(_prof, maxf(def.atmo_height, 500.0))
		_sky_amb_sent = Color(-1, -1, -1)
	else:
		_prof = {}

func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11

func _process(dt: float) -> void:
	if sun == null:
		return
	if Universe.system == null or Universe.system.star == null:
		sun.light_energy = 0.0
		return
	_update_system_look()
	var star: StarDef = Universe.system.star
	var cam_pos := _camera_pos()
	var sd: Vector3 = Frame.sun_dir
	var def: BodyDef = Frame.anchor_def()
	_profile_for(def)
	var have_atmo := not _prof.is_empty()

	# --- sun visibility (horizon + eclipses) ---------------------------------------------------------------------------------------------------
	var star_vec := Frame.star_local - cam_pos
	var star_d := maxf(star_vec.length(), 1.0)
	var a_s := asin(clampf(star.radius / star_d, 0.001, 0.9))
	var vis := 1.0
	var nodes := Universe.body_nodes
	for i in nodes.size():
		var n: Node3D = nodes[i] as Node3D
		if n == null or not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var bd: BodyDef = Universe.system.bodies[i]
		if bd.is_black_hole():
			continue
		var v: Vector3 = n.global_position - cam_pos
		var dist := v.length()
		var rb := bd.radius
		if dist <= rb * 1.0002 or dist > star_d:
			continue
		var a_b := asin(clampf(rb / dist, 0.0, 1.0))
		var theta := acos(clampf((v / dist).dot(sd), -1.0, 1.0))
		if theta > a_b + a_s:
			continue
		vis *= AtmosphereProfiles.disc_visible(theta, a_s, a_b)
	sun_visible = vis

	# --- atmosphere around the camera --------------------------------------------------------------------------------------------------------
	var t_rgb := Vector3.ONE
	var up := Vector3.UP
	var elev_s := 1.0           # sin(sun elevation over the local horizon)
	var alt := 1.0e9
	in_atmosphere = 0.0
	if def != null:
		up = cam_pos.normalized() if cam_pos.length() > 1.0 else Vector3.UP
		elev_s = clampf(sd.dot(up), -1.0, 1.0)
		alt = cam_pos.length() - def.radius
		if have_atmo:
			t_rgb = AtmosphereProfiles.sun_transmittance(_prof, _coef, def.radius, cam_pos, sd)
			in_atmosphere = clampf(exp(-maxf(alt, 0.0) / float(_coef["h_r"])), 0.0, 1.0)
	sun_elevation_deg = rad_to_deg(asin(elev_s)) if def != null else 90.0

	# --- the sun light ---------------------------------------------------------------------------------------------------------------------------
	var tmax := maxf(t_rgb.x, maxf(t_rgb.y, t_rgb.z))
	var tcol := Vector3(t_rgb.x, t_rgb.y, t_rgb.z) / maxf(tmax, 1e-4)
	var lc := star.light_color
	sun_color_now = Color(lc.r * tcol.x, lc.g * tcol.y, lc.b * tcol.z)
	sun_energy_now = star.light_energy * SUN_ENERGY_SCALE * vis * tmax
	var d := sd
	var up_ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	sun.global_transform = Transform3D(Basis.looking_at(-d, up_ref), Vector3.ZERO)
	sun.light_color = sun_color_now
	sun.light_energy = sun_energy_now
	sun.shadow_enabled = sun_energy_now > 0.01
	RenderingServer.global_shader_parameter_set("sun_color", sun_color_now)
	RenderingServer.global_shader_parameter_set("sun_energy", sun_energy_now)

	# --- day / night / ambient ------------------------------------------------------------------------------------------------------------------
	var amb_col: Color
	var amb_e: float
	var night := 0.0
	if def != null and have_atmo:
		var twi := smoothstep(-0.22, 0.12, elev_s)                       # twilight keeps the sky bright a while after sunset
		daylight = twi
		night = 1.0 - smoothstep(-0.16, 0.03, elev_s)
		var dusk := smoothstep(-0.18, 0.0, elev_s) * (1.0 - smoothstep(0.0, 0.30, elev_s))
		var c_day: Color = _prof["amb_day"]
		var c_dusk: Color = _prof["amb_dusk"]
		var c_night: Color = _prof["amb_night"]
		var c: Color = c_night.lerp(c_day, twi)
		c = c.lerp(c_dusk, dusk * 0.65)
		# star colour tints the day ambient (red dwarf => warmer shadows)
		c = c * Color(lerpf(1.0, lc.r, 0.5), lerpf(1.0, lc.g, 0.5), lerpf(1.0, lc.b, 0.5))
		var e_day: float = float(_prof["amb_energy"]) * (0.55 + 0.45 * star.light_energy)
		var e_night: float = float(_prof["amb_night_energy"])
		amb_e = lerpf(e_night, e_day, twi)
		# thin out with altitude: the sky stops lighting the shadows once we leave the atmosphere
		var dens := sqrt(in_atmosphere)
		amb_col = Color(0.12, 0.13, 0.16).lerp(c, dens)
		amb_e = lerpf(0.9, amb_e, dens)
		_exposure = float(_prof["exposure"])
	elif def != null:
		# airless world: hard light, a trace of fill from the sky of stars / earthshine
		daylight = smoothstep(-0.06, 0.05, elev_s) * vis
		night = 1.0 - smoothstep(-0.05, 0.04, elev_s)
		amb_col = Color(0.12, 0.125, 0.15)
		amb_e = 1.0
		_exposure = 1.0
	else:
		daylight = 1.0
		night = 0.0
		amb_col = Color(0.12, 0.125, 0.15)
		amb_e = 1.0
		_exposure = 1.0
	night_now = night
	var star_vis := 1.0 - smoothstep(0.30, 0.85, daylight * sqrt(in_atmosphere)) if have_atmo else 1.0
	RenderingServer.global_shader_parameter_set("night_amount", night)
	var k := clampf(dt * 6.0, 0.0, 1.0)
	_amb_col = _amb_col.lerp(amb_col, k)
	_amb_energy = lerpf(_amb_energy, amb_e, k)
	env.ambient_light_color = _amb_col
	env.ambient_light_energy = _amb_energy
	env.tonemap_exposure = lerpf(env.tonemap_exposure, _exposure, k)

	# --- sky shader uniforms (throttled: every change re-renders the small reflection cubemap) ----------------------------------------
	_sky_timer -= dt
	var au := float(_prof.get("aurora", 0.0)) if have_atmo else 0.0
	if _sky_timer <= 0.0:
		_sky_timer = 0.25 if au <= 0.0 else 0.1
		var sky_amb := _amb_col * _amb_energy * 0.5
		if absf(sky_amb.r - _sky_amb_sent.r) + absf(sky_amb.g - _sky_amb_sent.g) + absf(sky_amb.b - _sky_amb_sent.b) > 0.01 or au > 0.0:
			_sky_amb_sent = sky_amb
			sky_mat.set_shader_parameter("amb_color", Vector3(sky_amb.r, sky_amb.g, sky_amb.b))
		if absf(star_vis - _star_vis_sent) > 0.02:
			_star_vis_sent = star_vis
			sky_mat.set_shader_parameter("star_vis", star_vis)
		_aurora_t += 0.1 if au > 0.0 else 0.0
		sky_mat.set_shader_parameter("aurora", au)
		if au > 0.0:
			sky_mat.set_shader_parameter("aurora_time", _aurora_t)
			sky_mat.set_shader_parameter("up_local", up)
			var ca: Color = _prof["aurora_a"]
			var cb: Color = _prof["aurora_b"]
			sky_mat.set_shader_parameter("aurora_a", ca)
			sky_mat.set_shader_parameter("aurora_b", cb)
