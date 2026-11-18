class_name OceanSurface
extends Node3D
## OCEAN / LAVA / ACID surface sphere (module M2). Created by Planet (M1) when def.has_ocean:
##   var o := OceanSurface.new(); o.setup(planet, def, planet.sea_radius()); planet.add_child(o)
## One full-screen quad (shaders/ocean.gdshader) ray-traces the sea sphere analytically: precise at any distance, exact shoreline, wave normals evaluated on the
## camera-relative hit point, fresnel + sky reflection + sun glint, shallow/deep colour from the depth buffer, foam, underwater fog. Lava = emissive crust
## with glowing flows, acid = glowing green liquid. The sea radius follows planet.sea_radius() every frame (so M1 may change water_level at runtime).

var planet: Node3D
var def: BodyDef
var sea_radius: float = 0.0
var look: Dictionary = {}
var profile: Dictionary = {}
var _mat: ShaderMaterial
var _quad: MeshInstance3D
var _timer := 0.0

func setup(p_planet: Node3D, p_def: BodyDef, p_sea_radius: float) -> void:
	planet = p_planet
	def = p_def
	sea_radius = p_sea_radius

func _ready() -> void:
	if def == null:
		return
	process_priority = 160
	look = AtmosphereProfiles.get_ocean(def)
	profile = AtmosphereProfiles.get_profile(def.biome, def)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ocean.gdshader") as Shader
	_mat.render_priority = 10
	var kind_i := 0
	match String(look["kind"]):
		"lava": kind_i = 1
		"acid": kind_i = 2
	_mat.set_shader_parameter("kind", kind_i)
	_mat.set_shader_parameter("sea_r", maxf(sea_radius, 1.0))
	var sh: Color = look["shallow"]
	var dp: Color = look["deep"]
	var fm: Color = look["foam"]
	var ab: Vector3 = look["absorb"]
	_mat.set_shader_parameter("shallow_col", Vector3(sh.r, sh.g, sh.b))
	_mat.set_shader_parameter("deep_col", Vector3(dp.r, dp.g, dp.b))
	_mat.set_shader_parameter("foam_col", Vector3(fm.r, fm.g, fm.b))
	_mat.set_shader_parameter("absorb", ab)
	_mat.set_shader_parameter("clarity", float(look["clarity"]))
	_mat.set_shader_parameter("wave_amp", float(look["wave"]))
	_mat.set_shader_parameter("glow_amt", float(look["glow"]))
	_mat.set_shader_parameter("spec_amt", float(look["spec"]))
	_mat.set_shader_parameter("seed", float(SeedUtil.rand01(def.palette_seed, 61)) * 30.0 + 1.0)
	var zen: Color = profile["zenith"]
	var hor: Color = profile["horizon"]
	_mat.set_shader_parameter("sky_zenith", Vector3(zen.r, zen.g, zen.b))
	_mat.set_shader_parameter("sky_horizon", Vector3(hor.r, hor.g, hor.b))
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_quad = MeshInstance3D.new()
	_quad.name = "OceanQuad"
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.custom_aabb = AABB(Vector3(-1.0e7, -1.0e7, -1.0e7), Vector3(2.0e7, 2.0e7, 2.0e7))
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.ignore_occlusion_culling = true
	add_child(_quad)

func _process(dt: float) -> void:
	if _mat == null or planet == null or not is_instance_valid(planet):
		return
	var sr := sea_radius
	if planet.has_method("sea_radius"):
		sr = float(planet.call("sea_radius"))
	if sr <= 0.0:
		_quad.visible = false
		return
	if absf(sr - sea_radius) > 0.01:
		sea_radius = sr
		_mat.set_shader_parameter("sea_r", sr)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_quad.visible = false
		return
	var to_c: Vector3 = global_position - cam.global_position
	var dist := to_c.length()
	var vis := true
	if dist > sr:
		var ang := asin(clampf(sr / maxf(dist, 1.0), 0.0, 1.0))
		if ang < 0.0006:
			vis = false
		else:
			var fwd := -cam.global_transform.basis.z
			var cosa := fwd.dot(to_c / dist)
			var vp := get_viewport().get_visible_rect().size
			var aspect := vp.x / maxf(vp.y, 1.0)
			var half_v := deg_to_rad(cam.fov) * 0.5
			var half_d := atan(tan(half_v) * sqrt(1.0 + aspect * aspect))
			vis = acos(clampf(cosa, -1.0, 1.0)) < (half_d * 1.15 + ang)
	_quad.visible = vis
	if not vis:
		return
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 0.1
	var sky = Game.sky
	if sky != null and sky.get("env") != null:
		var e: Environment = sky.env
		var c: Color = e.ambient_light_color * e.ambient_light_energy
		_mat.set_shader_parameter("amb_color", Vector3(c.r, c.g, c.b))
		_mat.set_shader_parameter("sky_gain", clampf(float(sky.get("daylight")) * 1.0, 0.0, 1.0))
