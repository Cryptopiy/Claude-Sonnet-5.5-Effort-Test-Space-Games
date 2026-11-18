class_name PlanetMaterials
extends RefCounted
## Builds the ShaderMaterials for a planet from its PlanetData.

static var _terrain_shader: Shader
static var _liquid_shader: Shader
static var _atmo_shader: Shader
static var _cloud_shader: Shader
static var _gas_shader: Shader


static func _sh(path: String) -> Shader:
	return load(path) as Shader


static func terrain(d: PlanetData) -> ShaderMaterial:
	if _terrain_shader == null:
		_terrain_shader = _sh("res://shaders/terrain.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _terrain_shader
	var tu := d.terrain_uniforms()
	for k in tu:
		m.set_shader_parameter(k, tu[k])
	var pal := d.pal
	for k in ["shore", "low", "mid", "high", "peak", "slope", "acc", "deep"]:
		if pal.has(k):
			m.set_shader_parameter("col_" + k, pal[k])
	m.set_shader_parameter("h_ref", d.h_ref)
	m.set_shader_parameter("snow_line", d.snow_line)
	m.set_shader_parameter("sea_h", d.sea_level if d.has_liquid() else -1.0e9)
	m.set_shader_parameter("patch_strength", d.patch_strength)
	m.set_shader_parameter("grain", d.grain)
	m.set_shader_parameter("detail_tex", Textures.detail_texture())
	match d.biome:
		PlanetData.Biome.FROZEN:
			m.set_shader_parameter("ice_gloss", 1.0)
		PlanetData.Biome.VOLCANIC:
			m.set_shader_parameter("vein_color", Color(1.0, 0.38, 0.05))
			m.set_shader_parameter("vein_strength", 3.0)
			m.set_shader_parameter("vein_h_max", 260.0)
		PlanetData.Biome.TOXIC:
			m.set_shader_parameter("vein_color", Color(0.45, 1.0, 0.2))
			m.set_shader_parameter("vein_strength", 0.9)
			m.set_shader_parameter("vein_h_max", 60.0)
		PlanetData.Biome.EXOTIC:
			m.set_shader_parameter("vein_color", Color(0.2, 1.0, 0.9))
			m.set_shader_parameter("vein_strength", 1.6)
			m.set_shader_parameter("vein_h_max", 200.0)
	return m


static func liquid(d: PlanetData) -> ShaderMaterial:
	if _liquid_shader == null:
		_liquid_shader = _sh("res://shaders/liquid.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _liquid_shader
	m.set_shader_parameter("planet_r", d.radius)
	m.set_shader_parameter("sea_level", d.sea_level)
	m.set_shader_parameter("kind", int(d.liquid))
	m.set_shader_parameter("col_shallow", d.liquid_color)
	m.set_shader_parameter("col_deep", d.liquid_deep)
	m.set_shader_parameter("detail_tex", Textures.detail_texture())
	return m


static func atmosphere(d: PlanetData) -> ShaderMaterial:
	if _atmo_shader == null:
		_atmo_shader = _sh("res://shaders/atmosphere.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _atmo_shader
	m.set_shader_parameter("planet_r", d.radius)
	m.set_shader_parameter("atmo_h", d.atmo_height)
	m.set_shader_parameter("beta_r", d.atmo_beta)
	m.set_shader_parameter("beta_m", d.atmo_mie)
	m.set_shader_parameter("density", d.atmo_density)
	return m


static func clouds(d: PlanetData) -> ShaderMaterial:
	if _cloud_shader == null:
		_cloud_shader = _sh("res://shaders/clouds.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _cloud_shader
	m.set_shader_parameter("planet_r", d.radius)
	m.set_shader_parameter("t_seed", d.seed + 91)
	m.set_shader_parameter("cover", d.cloud_cover)
	m.set_shader_parameter("cloud_col", d.cloud_color)
	return m


static func gas(d: PlanetData) -> ShaderMaterial:
	if _gas_shader == null:
		_gas_shader = _sh("res://shaders/gas_giant.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _gas_shader
	m.set_shader_parameter("seed", d.seed)
	for i in 5:
		m.set_shader_parameter("c%d" % i, d.gas_colors[i % d.gas_colors.size()])
	return m
