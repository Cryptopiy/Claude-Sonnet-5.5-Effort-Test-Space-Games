class_name PlanetTerrain
extends Node3D
## Cube-sphere quadtree of GPU-displaced chunks. Heights are evaluated in the vertex shader
## (shaders/terrain.gdshader); the CPU never touches vertex data, so LOD changes are free.

const N := 32
static var _grid_mesh: ArrayMesh

var data: PlanetData
var mat: ShaderMaterial
var water_mat: ShaderMaterial
var leaves: Dictionary = {}
var water_leaves: Dictionary = {}
var max_level := 8
var water_max_level := 4
var k_split := 2.0
var _last_cam := Vector3(1e30, 0, 0)
var chunk_count := 0
var shadows_near_level := 5


static func grid_mesh() -> ArrayMesh:
	if _grid_mesh:
		return _grid_mesh
	var n := N
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in n + 1:
		for i in n + 1:
			verts.append(Vector3(float(i) / n, 0.0, float(j) / n))
			uvs.append(Vector2(float(i) / n, float(j) / n))
			cols.append(Color(0, 0, 0, 1))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			idx.append_array([a, c, b, b, c, d])
	# skirts (double sided so winding does not matter)
	var edges: Array = []
	var e0: Array = []
	var e1: Array = []
	var e2: Array = []
	var e3: Array = []
	for i in n + 1:
		e0.append(i)
		e1.append(n * (n + 1) + i)
		e2.append(i * (n + 1))
		e3.append(i * (n + 1) + n)
	edges = [e0, e1, e2, e3]
	for e in edges:
		var base := verts.size()
		for i in n + 1:
			var src: int = e[i]
			verts.append(verts[src])
			uvs.append(uvs[src])
			cols.append(Color(1, 0, 0, 1))
		for i in n:
			var a2: int = e[i]
			var b2: int = e[i + 1]
			var s_a := base + i
			var s_b := base + i + 1
			idx.append_array([a2, s_a, b2, b2, s_a, s_b])
			idx.append_array([a2, b2, s_a, b2, s_b, s_a])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.custom_aabb = AABB(Vector3(-100000, -100000, -100000), Vector3(200000, 200000, 200000))
	_grid_mesh = m
	return m


func setup(d: PlanetData, terrain_mat: ShaderMaterial, liquid_mat: ShaderMaterial) -> void:
	data = d
	mat = terrain_mat
	water_mat = liquid_mat
	# finest chunk edge about 30 m
	max_level = clampi(int(ceil(log(1.5708 * d.radius / 30.0) / log(2.0))), 3, 12)
	water_max_level = clampi(int(ceil(log(1.5708 * d.radius / 600.0) / log(2.0))), 2, 6)


func _wanted(cam: Vector3, max_lv: int, k: float) -> Dictionary:
	var out := {}
	var stack: Array = []
	var R := data.radius
	for f in 6:
		stack.append([f, 0, 0, 0])
	while not stack.is_empty():
		var nd: Array = stack.pop_back()
		var f: int = nd[0]
		var lv: int = nd[1]
		var ix: int = nd[2]
		var iy: int = nd[3]
		var size := 2.0 / float(1 << lv)
		var s0 := -1.0 + ix * size
		var t0 := -1.0 + iy * size
		var split := false
		if lv < max_lv:
			var c: Vector3 = TNoise.cube_to_sphere(TNoise.FACE_N[f] + TNoise.FACE_A[f] * (s0 + size * 0.5) + TNoise.FACE_B[f] * (t0 + size * 0.5))
			var m := size * R * 0.7854
			var d := (cam - c * R).length() - m * 0.75
			split = d < m * k
		if split:
			var h := lv + 1
			var x2 := ix * 2
			var y2 := iy * 2
			stack.append([f, h, x2, y2])
			stack.append([f, h, x2 + 1, y2])
			stack.append([f, h, x2, y2 + 1])
			stack.append([f, h, x2 + 1, y2 + 1])
		else:
			out[(f << 40) | (lv << 32) | (ix << 16) | iy] = [f, lv, ix, iy]
	return out


func update_lod(cam_local: Vector3, force := false) -> void:
	if not force and cam_local.distance_to(_last_cam) < 3.0:
		return
	_last_cam = cam_local
	var want := _wanted(cam_local, max_level, k_split)
	_sync(leaves, want, mat, false)
	if data.has_liquid():
		var wwant := _wanted(cam_local, water_max_level, 2.2)
		_sync(water_leaves, wwant, water_mat, true)
	chunk_count = leaves.size()


func _sync(cur: Dictionary, want: Dictionary, material: ShaderMaterial, is_water: bool) -> void:
	for key in cur.keys():
		if not want.has(key):
			var mi: MeshInstance3D = cur[key]
			mi.queue_free()
			cur.erase(key)
	for key in want:
		if cur.has(key):
			continue
		var nd: Array = want[key]
		cur[key] = _make_chunk(nd[0], nd[1], nd[2], nd[3], material, is_water)


func _make_chunk(f: int, lv: int, ix: int, iy: int, material: ShaderMaterial, is_water: bool) -> MeshInstance3D:
	var size := 2.0 / float(1 << lv)
	var s0 := -1.0 + ix * size
	var t0 := -1.0 + iy * size
	var n: Vector3 = TNoise.FACE_N[f]
	var a: Vector3 = TNoise.FACE_A[f]
	var b: Vector3 = TNoise.FACE_B[f]
	var mi := MeshInstance3D.new()
	mi.mesh = grid_mesh()
	mi.material_override = material
	var c: Vector3 = TNoise.cube_to_sphere(n + a * (s0 + size * 0.5) + b * (t0 + size * 0.5))
	var edge := size * data.radius * 0.7854
	var ext := edge * 0.9 + data.h_ref * 2.5 + 40.0
	mi.custom_aabb = AABB(c * data.radius - Vector3(ext, ext, ext), Vector3(ext, ext, ext) * 2.0)
	if is_water or lv < max_level - shadows_near_level:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.set_instance_shader_parameter("chunk_a", Vector4(n.x, n.y, n.z, size))
	mi.set_instance_shader_parameter("chunk_b", Vector4(a.x, a.y, a.z, s0))
	mi.set_instance_shader_parameter("chunk_c", Vector4(b.x, b.y, b.z, t0))
	return mi
