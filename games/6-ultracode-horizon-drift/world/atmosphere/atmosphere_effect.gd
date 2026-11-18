class_name AtmosphereEffect
extends Node3D
## ATMOSPHERE post-process (module M2). Created by Planet (M1) when def.has_atmosphere: `var a := AtmosphereEffect.new(); a.setup(planet, def); planet.add_child(a)`.
## Two full-screen quads (drawn after every other transparent object, centred on this node = planet centre):
##   * mul pass  : multiplies the image by the per-channel transmittance of the atmosphere along the view ray (clipped by the depth buffer / ocean / ground),
##   * add pass  : adds the analytic single-scattering radiance (Rayleigh + Mie, planet shadow with penumbra, per-biome colours / glow / night glow).
## => blue sky + orange sunsets, aerial perspective on terrain, limb glow from space, atmosphere fading into the stars at altitude.
## Also usable by GasGiant (pass any Node3D + BodyDef; radius / atmo_height are read from the def).

const SUN_INTENSITY := 16.0
static var _shader_add: Shader = null
static var _shader_mul: Shader = null

var planet: Node3D
var def: BodyDef
var profile: Dictionary = {}
var coef: Dictionary = {}
var radius: float = 9000.0
var atmo_h: float = 4000.0
var dens_boost: float = 1.0                  # extra Mie density (set by SkyController from weather / gas-giant depth)
var _mat_add: ShaderMaterial
var _mat_mul: ShaderMaterial
var _quad_add: MeshInstance3D
var _quad_mul: MeshInstance3D
var _sea_r: float = -1.0
var _ready_done := false

func setup(p_planet: Node3D, p_def: BodyDef) -> void:
	planet = p_planet
	def = p_def

func _ready() -> void:
	if def == null:
		return
	add_to_group("atmosphere_effect")
	process_priority = 150          # after Frame (100): transforms of this frame are already final when we read them
	radius = def.radius
	atmo_h = maxf(def.atmo_height, 500.0)
	profile = AtmosphereProfiles.get_profile(def.biome, def)
	coef = AtmosphereProfiles.coefficients(profile, atmo_h)
	_build()
	_ready_done = true

static func _shaders() -> void:
	if _shader_add == null:
		_shader_add = load("res://shaders/atmosphere_add.gdshader") as Shader
		_shader_mul = load("res://shaders/atmosphere_mul.gdshader") as Shader

func _build() -> void:
	_shaders()
	_mat_add = ShaderMaterial.new()
	_mat_add.shader = _shader_add
	_mat_add.render_priority = 125
	_mat_mul = ShaderMaterial.new()
	_mat_mul.shader = _shader_mul
	_mat_mul.render_priority = 124
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	var big := AABB(Vector3(-1.0e7, -1.0e7, -1.0e7), Vector3(2.0e7, 2.0e7, 2.0e7))
	_quad_mul = MeshInstance3D.new()
	_quad_mul.name = "AtmoMul"
	_quad_mul.mesh = q
	_quad_mul.material_override = _mat_mul
	_quad_mul.custom_aabb = big
	_quad_mul.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad_mul.ignore_occlusion_culling = true
	add_child(_quad_mul)
	_quad_add = MeshInstance3D.new()
	_quad_add.name = "AtmoAdd"
	_quad_add.mesh = q
	_quad_add.material_override = _mat_add
	_quad_add.custom_aabb = big
	_quad_add.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad_add.ignore_occlusion_culling = true
	add_child(_quad_add)
	var sl: Color = def_star_light()
	var col: Color = sl
	var base := Vector3(col.r, col.g, col.b) * SUN_INTENSITY * float(profile["sun_gain"])
	var glow: Color = profile["glow"]
	var ng: Color = profile["night_glow"]
	var mc := {
		"planet_radius": radius, "atmo_top": float(coef["top"]), "h_rayleigh": float(coef["h_r"]), "h_mie": float(coef["h_m"]),
		"beta_r": coef["beta_r"], "beta_m": coef["beta_m"], "beta_m_ext": coef["beta_m_ext"], "mie_g": float(profile["mie_g"]),
		"star_light": base, "glow_color": Vector3(glow.r, glow.g, glow.b), "glow_amount": float(profile["glow_amount"]),
		"glow_h": atmo_h * float(profile["glow_h"]), "night_glow": Vector3(ng.r, ng.g, ng.b), "sea_radius": 0.0, "sun_ang": 0.03, "dens_boost": 1.0,
		"sky_tint": profile["sky_tint"], "sky_sat": float(profile["sky_sat"]), "light_boost": AtmosphereProfiles.LIGHT_BOOST,
	}
	for k in mc:
		_mat_add.set_shader_parameter(k, mc[k])
		_mat_mul.set_shader_parameter(k, mc[k])

func def_star_light() -> Color:
	if Universe.system != null and Universe.system.star != null:
		var c: Color = Universe.system.star.light_color
		return c
	return Color(1.0, 0.95, 0.85)

## top of the integration shell above the base radius (m)
func shell_radius() -> float:
	return radius + float(coef.get("top", atmo_h * 1.6))

func _set_both(name: StringName, v: Variant) -> void:
	_mat_add.set_shader_parameter(name, v)
	_mat_mul.set_shader_parameter(name, v)

func _process(_dt: float) -> void:
	if not _ready_done or planet == null or not is_instance_valid(planet):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_quad_add.visible = false
		_quad_mul.visible = false
		return
	# --- visibility: only when the atmosphere shell is (partly) on screen and bigger than ~1 pixel -------------------------------------------------
	var to_c: Vector3 = global_position - cam.global_position
	var dist := to_c.length()
	var r_top := shell_radius()
	var vis := true
	if dist > r_top:
		var ang := asin(clampf(r_top / maxf(dist, 1.0), 0.0, 1.0))
		if ang < 0.0007:
			vis = false
		else:
			var fwd := -cam.global_transform.basis.z
			var cosa := fwd.dot(to_c / dist)
			var vp := get_viewport().get_visible_rect().size
			var aspect := vp.x / maxf(vp.y, 1.0)
			var half_v := deg_to_rad(cam.fov) * 0.5
			var half_d := atan(tan(half_v) * sqrt(1.0 + aspect * aspect))
			vis = acos(clampf(cosa, -1.0, 1.0)) < (half_d * 1.15 + ang)
	_quad_add.visible = vis
	_quad_mul.visible = vis
	if not vis:
		return
	# --- dynamic uniforms ----------------------------------------------------------------------------------------------------------------------------
	var sea := 0.0
	if planet.has_method("sea_radius"):
		sea = float(planet.call("sea_radius"))
	if absf(sea - _sea_r) > 0.01:
		_sea_r = sea
		_set_both(&"sea_radius", sea)
	var star_d := (Frame.star_local - cam.global_position).length()
	var sr: float = 48000.0
	if Universe.system != null and Universe.system.star != null:
		sr = Universe.system.star.radius
	_set_both(&"sun_ang", clampf(sr / maxf(star_d, 1.0), 0.002, 0.2))
	var boost := dens_boost
	if Game.weather != null and is_instance_valid(Game.weather) and "fog_boost" in Game.weather:
		boost *= maxf(1.0, float(Game.weather.get("fog_boost")))
	_set_both(&"dens_boost", boost)

## world-space helpers for SkyController: planet-relative position of the camera
func rel_pos(world_pos: Vector3) -> Vector3:
	return world_pos - global_position
