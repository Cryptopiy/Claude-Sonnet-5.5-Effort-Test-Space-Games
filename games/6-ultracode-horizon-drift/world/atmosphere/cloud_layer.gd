class_name CloudLayer
extends Node3D
## CLOUD LAYER shell (module M2). Created by Planet (M1) for atmospheric planets: `var c := CloudLayer.new(); c.setup(planet, def); planet.add_child(c)`.
## A sphere mesh at radius + alt (alt ~ 0.4 * atmosphere height) with shaders/cloud.gdshader: drifting fbm clouds lit by the sun, fading out near the camera.
## Per-biome cloud look (cover / colour / darkness / emissive underlight for volcanic + exotic) comes from AtmosphereProfiles.

var planet: Node3D
var def: BodyDef
var shell_radius: float = 0.0
var _mat: ShaderMaterial
var _mi: MeshInstance3D
var _profile: Dictionary = {}
var _amb_timer := 0.0

func setup(p_planet: Node3D, p_def: BodyDef) -> void:
	planet = p_planet
	def = p_def

func _ready() -> void:
	if def == null:
		return
	process_priority = 160
	_profile = AtmosphereProfiles.get_profile(def.biome, def)
	var cl: Dictionary = _profile["cloud"]
	if float(cl["cover"]) <= 0.01:
		return
	shell_radius = def.radius + maxf(def.atmo_height, 1500.0) * float(cl["alt"])
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/cloud.gdshader") as Shader
	_mat.render_priority = 20
	var s := float(SeedUtil.rand01(def.palette_seed, 51)) * 40.0 + 1.0
	var bright: Color = cl["bright"]
	var shade: Color = cl["shade"]
	var emit: Color = cl["emit"]
	_mat.set_shader_parameter("shell_r", shell_radius)
	_mat.set_shader_parameter("cover", float(cl["cover"]))
	_mat.set_shader_parameter("soft", float(cl["soft"]))
	_mat.set_shader_parameter("cloud_scale", float(cl["scale"]))
	_mat.set_shader_parameter("speed", float(cl["speed"]))
	_mat.set_shader_parameter("opacity", float(cl["opacity"]))
	_mat.set_shader_parameter("dark", float(cl["dark"]))
	_mat.set_shader_parameter("col_bright", Vector3(bright.r, bright.g, bright.b))
	_mat.set_shader_parameter("col_shade", Vector3(shade.r, shade.g, shade.b))
	_mat.set_shader_parameter("col_emit", Vector3(emit.r, emit.g, emit.b))
	_mat.set_shader_parameter("seed", s)
	_mat.set_shader_parameter("fade_near", maxf(60.0, def.atmo_height * 0.05))
	_mat.set_shader_parameter("fade_far", maxf(500.0, def.atmo_height * 0.35))
	var sm := SphereMesh.new()
	sm.radius = shell_radius * 1.003
	sm.height = shell_radius * 2.006
	sm.radial_segments = 128
	sm.rings = 64
	_mi = MeshInstance3D.new()
	_mi.name = "Clouds"
	_mi.mesh = sm
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.custom_aabb = AABB(Vector3(-shell_radius, -shell_radius, -shell_radius) * 1.05, Vector3(shell_radius, shell_radius, shell_radius) * 2.1)
	add_child(_mi)

func _process(dt: float) -> void:
	if _mat == null:
		return
	# ambient tint for the shaded sides follows the sky controller's ambient colour (night => dark clouds)
	_amb_timer -= dt
	if _amb_timer > 0.0:
		return
	_amb_timer = 0.1
	var sky = Game.sky
	if sky != null and sky.get("env") != null:
		var e: Environment = sky.env
		var c: Color = e.ambient_light_color * e.ambient_light_energy
		_mat.set_shader_parameter("amb_color", Vector3(c.r, c.g, c.b))
