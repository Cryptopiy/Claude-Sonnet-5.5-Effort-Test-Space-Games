class_name Planet
extends Body
## A planet or moon: chunked terrain, liquid sphere, atmosphere shell, cloud layer (or a gas giant with rings).

var terrain: PlanetTerrain
var terrain_mat: ShaderMaterial
var liquid_mat: ShaderMaterial
var atmo_mi: MeshInstance3D
var atmo_mat: ShaderMaterial
var cloud_mi: MeshInstance3D
var cloud_mat: ShaderMaterial
var ring_mi: MeshInstance3D
var ring_mat: ShaderMaterial
var gas_mat: ShaderMaterial
var props: Node3D                      # PropField, created lazily by the world
var cloud_alt := 500.0
var lod_enabled := true
var cam_local := Vector3.ZERO
var last_visual_update := -1
var landing_dir := Vector3.UP


func build(d: PlanetData) -> void:
	data = d
	kind = "gas" if d.is_gas() else "planet"
	radius = d.radius
	display_name = d.name
	if d.is_gas():
		_build_gas()
	else:
		_build_rocky()
		frame_alt = maxf(d.atmo_height * 1.25, 1800.0)
	if d.atmo_height > 0.0:
		_build_atmosphere()
	if d.cloud_cover > 0.02 and not d.is_gas():
		_build_clouds()


func _build_rocky() -> void:
	terrain_mat = PlanetMaterials.terrain(data)
	if data.has_liquid():
		liquid_mat = PlanetMaterials.liquid(data)
	terrain = PlanetTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(data, terrain_mat, liquid_mat)
	terrain.update_lod(Vector3(data.radius * 50.0, 0, 0), true)


func _build_gas() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = data.radius
	sm.height = data.radius * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	mi.mesh = sm
	gas_mat = PlanetMaterials.gas(data)
	mi.material_override = gas_mat
	add_child(mi)
	if data.has_rings:
		var rm := _ring_mesh(data.radius * data.ring_inner, data.radius * data.ring_outer)
		ring_mi = MeshInstance3D.new()
		ring_mi.mesh = rm
		ring_mat = ShaderMaterial.new()
		ring_mat.shader = load("res://shaders/ring.gdshader")
		ring_mat.set_shader_parameter("planet_r", data.radius)
		ring_mat.set_shader_parameter("inner", data.ring_inner)
		ring_mat.set_shader_parameter("outer", data.ring_outer)
		ring_mat.set_shader_parameter("ring_col", data.ring_color)
		ring_mat.set_shader_parameter("seed", data.seed)
		ring_mi.material_override = ring_mat
		ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring_mi)


static func _ring_mesh(r0: float, r1: float) -> ArrayMesh:
	var seg := 160
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var a := TAU * i / seg
		var c := cos(a)
		var s := sin(a)
		verts.append(Vector3(c * r0, 0, s * r0))
		verts.append(Vector3(c * r1, 0, s * r1))
		uvs.append(Vector2(0, float(i) / seg))
		uvs.append(Vector2(1, float(i) / seg))
	for i in seg:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _build_atmosphere() -> void:
	atmo_mat = PlanetMaterials.atmosphere(data)
	atmo_mi = MeshInstance3D.new()
	var sm := SphereMesh.new()
	var rt := (data.radius + data.atmo_height) * 1.035
	sm.radius = rt
	sm.height = rt * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	atmo_mi.mesh = sm
	atmo_mi.material_override = atmo_mat
	atmo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(atmo_mi)


func _build_clouds() -> void:
	cloud_alt = minf(data.atmo_height * 0.24, 640.0) + 160.0
	cloud_mat = PlanetMaterials.clouds(data)
	cloud_mat.set_shader_parameter("planet_r", data.radius + cloud_alt)
	cloud_mi = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = data.radius + cloud_alt
	sm.height = sm.radius * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	cloud_mi.mesh = sm
	cloud_mi.material_override = cloud_mat
	cloud_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud_mi)


## per-frame visual update (LOD + light uniforms). cam_world is the camera's render-space position.
func update_visuals(cam_world: Vector3, sun_dir_world: Vector3, sun_col: Color, sun_int: float, full: bool) -> void:
	cam_local = rot.transposed() * (cam_world - global_position)
	var dist := cam_local.length()
	if terrain != null:
		if dist < data.radius * 60.0:
			terrain.update_lod(cam_local)
	if full:
		for m in [terrain_mat, gas_mat]:
			if m != null:
				m.set_shader_parameter("sun_dir_world", sun_dir_world)
				m.set_shader_parameter("sun_light_col", sun_col)
				m.set_shader_parameter("sun_light_energy", sun_int * 0.075)
		if atmo_mat != null:
			atmo_mat.set_shader_parameter("sun_dir_w", sun_dir_world)
			atmo_mat.set_shader_parameter("sun_col", sun_col)
			atmo_mat.set_shader_parameter("sun_int", sun_int * 0.42)
		if cloud_mat != null:
			cloud_mat.set_shader_parameter("sun_dir_w", sun_dir_world)
			cloud_mat.set_shader_parameter("sun_col", sun_col)
		if ring_mat != null:
			ring_mat.set_shader_parameter("sun_local", rot.transposed() * sun_dir_world)
			ring_mat.set_shader_parameter("sun_col", sun_col)

