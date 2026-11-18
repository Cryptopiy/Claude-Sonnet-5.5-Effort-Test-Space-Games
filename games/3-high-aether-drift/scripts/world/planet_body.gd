class_name PlanetBody
extends Node3D
## One planet or moon: terrain (GPU displaced cube-sphere LOD), atmosphere glow, clouds, liquid ocean, props.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const ATMO_SHADER := preload("res://shaders/atmosphere.gdshader")
const CLOUD_SHADER := preload("res://shaders/clouds.gdshader")
const LIQUID_SHADER := preload("res://shaders/liquid.gdshader")
const GAS_SHADER := preload("res://shaders/gas_giant.gdshader")
const RING_SHADER := preload("res://shaders/rings.gdshader")

var data: PlanetData
var index: int = -1
var upos: Array = [0.0, 0.0, 0.0]  # centre in universe coordinates (doubles)
var vel_u: Vector3 = Vector3.ZERO
var spin_angle: float = 0.0
var sun_world: Vector3 = Vector3.UP
var terrain_mat: ShaderMaterial
var atmo_mat: ShaderMaterial
var cloud_mat: ShaderMaterial
var liquid_mat: ShaderMaterial
var gas_mat: ShaderMaterial
var ring_mat: ShaderMaterial
var lod: TerrainLod
var atmo_mesh: MeshInstance3D
var cloud_mesh: MeshInstance3D
var liquid_mesh: MeshInstance3D
var ring_mesh: MeshInstance3D
var props: PropField = null
var fauna: Fauna = null
var height_bound: float = 300.0
var cloud_alt: float = 400.0
var _lod_timer: float = 0.0
var cloud_drift: float = 0.0
var near_camera: bool = false
var is_gas: bool = false


func setup(d: PlanetData, idx: int) -> void:
	data = d
	index = idx
	name = d.name
	is_gas = d.kind == "gas"
	var R := d.radius
	if is_gas:
		_build_gas()
	else:
		_build_rocky()
	if d.has_atmo:
		_build_atmosphere()
	if d.cloud_cover > 0.02:
		_build_clouds()


func _build_rocky() -> void:
	var d := data
	var t := d.terrain
	height_bound = t.amp * 1.7 + absf(t.crater) * 2.0 + t.dune + 30.0
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("t_seed", t.seed)
	m.set_shader_parameter("t_freq", t.freq)
	m.set_shader_parameter("t_amp", t.amp)
	m.set_shader_parameter("t_ridge", t.ridge)
	m.set_shader_parameter("t_mask", t.mask)
	m.set_shader_parameter("t_terr", t.terr)
	m.set_shader_parameter("t_steps", t.steps)
	m.set_shader_parameter("t_dune", t.dune)
	m.set_shader_parameter("t_crater", t.crater)
	m.set_shader_parameter("t_cden", t.cden)
	m.set_shader_parameter("t_off", t.off)
	m.set_shader_parameter("t_site", Vector4(t.site_dir.x, t.site_dir.y, t.site_dir.z, t.site_h))
	m.set_shader_parameter("t_site_r", Vector3(t.site_r_in, t.site_r_out, t.radius))
	m.set_shader_parameter("t_site_on", 1.0 if t.has_site else 0.0)
	var L := d.look
	m.set_shader_parameter("col_low", L["low"])
	m.set_shader_parameter("col_mid", L["mid"])
	m.set_shader_parameter("col_high", L["high"])
	m.set_shader_parameter("col_rock", L["rock"])
	m.set_shader_parameter("col_beach", L["beach"])
	m.set_shader_parameter("snow_line", L["snow"])
	m.set_shader_parameter("sea_level", t.sea_level)
	m.set_shader_parameter("lava_amt", L["lava_amt"])
	m.set_shader_parameter("spec_amt", L["spec"])
	m.set_shader_parameter("rock_bias", L["rock_bias"])
	m.set_shader_parameter("color_var", L["color_var"])
	terrain_mat = m
	lod = TerrainLod.new()
	lod.name = "Terrain"
	add_child(lod)
	lod.setup(d.radius, m, height_bound)
	# liquid ocean
	if d.liquid != "":
		var lm := ShaderMaterial.new()
		lm.shader = LIQUID_SHADER
		match d.liquid:
			"water":
				lm.set_shader_parameter("shallow_col", Color(0.12, 0.55, 0.62))
				lm.set_shader_parameter("deep_col", Color(0.02, 0.12, 0.3))
				lm.set_shader_parameter("clarity", 0.06)
			"toxic":
				lm.set_shader_parameter("shallow_col", Color(0.45, 0.75, 0.15))
				lm.set_shader_parameter("deep_col", Color(0.18, 0.28, 0.06))
				lm.set_shader_parameter("clarity", 0.12)
				lm.set_shader_parameter("roughness_v", 0.3)
			"lava":
				lm.set_shader_parameter("emit_amt", 1.0)
				lm.set_shader_parameter("flow_speed", 0.05)
		liquid_mat = lm
		var sm := SphereMesh.new()
		var rr := d.radius + t.sea_level
		sm.radius = rr
		sm.height = rr * 2.0
		sm.radial_segments = 384
		sm.rings = 192
		liquid_mesh = MeshInstance3D.new()
		liquid_mesh.mesh = sm
		liquid_mesh.material_override = lm
		liquid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		liquid_mesh.name = "Liquid"
		add_child(liquid_mesh)
	if d.landable:
		props = PropField.new()
		props.name = "Props"
		add_child(props)
		props.setup(self)
		if not d.fauna.is_empty():
			fauna = Fauna.new()
			fauna.name = "Fauna"
			add_child(fauna)
			fauna.setup(self)


func _build_gas() -> void:
	var d := data
	var sm := SphereMesh.new()
	sm.radius = d.radius
	sm.height = d.radius * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	var m := ShaderMaterial.new()
	m.shader = GAS_SHADER
	m.set_shader_parameter("c0", d.gas_colors[0])
	m.set_shader_parameter("c1", d.gas_colors[1])
	m.set_shader_parameter("c2", d.gas_colors[2])
	m.set_shader_parameter("c3", d.gas_colors[3])
	m.set_shader_parameter("g_seed", float(d.seed % 97))
	gas_mat = m
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m
	mi.name = "GasSurface"
	add_child(mi)
	height_bound = 0.0
	if d.rings:
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("ring_col", d.gas_colors[2].lerp(Color(0.8, 0.7, 0.55), 0.5))
		rm.set_shader_parameter("r_in", 1.35 / 2.6)
		rm.set_shader_parameter("body_r", 1.0 / 2.6)
		ring_mat = rm
		ring_mesh = MeshInstance3D.new()
		ring_mesh.mesh = _disc_mesh(96)
		ring_mesh.material_override = rm
		ring_mesh.scale = Vector3.ONE * d.radius * 2.6
		ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring_mesh.name = "Rings"
		add_child(ring_mesh)


static func _disc_mesh(seg: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	for i in seg:
		var a := TAU * i / seg
		verts.append(Vector3(cos(a), 0.0, sin(a)))
	for i in seg:
		idx.append_array([0, 1 + (i + 1) % seg, 1 + i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.custom_aabb = AABB(Vector3(-1, -0.1, -1), Vector3(2, 0.2, 2))
	return am


func _build_atmosphere() -> void:
	var d := data
	var shell_r := d.radius * (1.0 + d.atm_scale)
	var sm := SphereMesh.new()
	sm.radius = shell_r
	sm.height = shell_r * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	var m := ShaderMaterial.new()
	m.shader = ATMO_SHADER
	m.set_shader_parameter("atm_color", d.atm_color)
	m.set_shader_parameter("planet_r", d.radius)
	m.set_shader_parameter("atm_r", shell_r)
	m.set_shader_parameter("scale_h", d.radius * 0.05)
	m.set_shader_parameter("intensity", 1.6 if is_gas else 1.25)
	atmo_mat = m
	atmo_mesh = MeshInstance3D.new()
	atmo_mesh.mesh = sm
	atmo_mesh.material_override = m
	atmo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	atmo_mesh.name = "Atmosphere"
	add_child(atmo_mesh)


func _build_clouds() -> void:
	var d := data
	cloud_alt = d.radius * 0.075 + (absf(d.terrain.sea_level) if d.terrain != null and d.terrain.sea_level > -50000.0 else 0.0) * 0.0
	var rr := d.radius + cloud_alt
	var sm := SphereMesh.new()
	sm.radius = rr
	sm.height = rr * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	var m := ShaderMaterial.new()
	m.shader = CLOUD_SHADER
	m.set_shader_parameter("cloud_color", d.cloud_color)
	m.set_shader_parameter("coverage", d.cloud_cover)
	m.set_shader_parameter("planet_r", d.radius)
	m.set_shader_parameter("cl_seed", float(d.seed % 53))
	cloud_mat = m
	cloud_mesh = MeshInstance3D.new()
	cloud_mesh.mesh = sm
	cloud_mesh.material_override = m
	cloud_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_mesh.name = "Clouds"
	add_child(cloud_mesh)


func set_sun(dir_world: Vector3) -> void:
	sun_world = dir_world
	if terrain_mat:
		terrain_mat.set_shader_parameter("sun_dir", dir_world)
	if gas_mat:
		gas_mat.set_shader_parameter("sun_dir", dir_world)
	if atmo_mat:
		atmo_mat.set_shader_parameter("sun_dir", dir_world)
	if cloud_mat:
		cloud_mat.set_shader_parameter("sun_dir", dir_world)
	if ring_mat:
		ring_mat.set_shader_parameter("sun_dir", (global_transform.basis.inverse() * dir_world).normalized())


## cam_world: camera position in the origin frame. Called every frame by the Universe.
func update_visuals(cam_world: Vector3, dt: float, atmo_fade: float) -> void:
	var local := to_local(cam_world)
	var dist := local.length()
	near_camera = dist < data.radius * 3.0
	if atmo_mat:
		atmo_mat.set_shader_parameter("inside_fade", atmo_fade)
	if cloud_mat:
		cloud_drift += dt * 0.004
		cloud_mat.set_shader_parameter("drift", cloud_drift)
	if lod:
		_lod_timer -= dt
		var every := 0.08 if dist < data.radius * 2.0 else (0.25 if dist < data.radius * 12.0 else 1.0)
		if _lod_timer <= 0.0 or lod.leaves.is_empty():
			_lod_timer = every
			lod.update_lod(local)
	if props:
		props.update_field(local, dt)
	if fauna:
		fauna.update_fauna(local, dt)


func ground_radius(dir_local: Vector3) -> float:
	return data.radius + data.terrain.ground(dir_local)


func altitude_local(p_local: Vector3) -> float:
	var l := p_local.length()
	if is_gas:
		return l - data.radius
	return l - ground_radius(p_local / l)
