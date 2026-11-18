class_name TerrainLod
extends Node3D
## Quadtree level-of-detail for one cube-sphere planet. Every patch is the same 49x49 grid mesh; the vertex shader
## (terrain.gdshader) places it on the sphere and displaces it, so no CPU mesh generation is ever needed.

const GRID := 48
const MAX_LEVEL := 9
const SPLIT_RATIO := 0.3

static var _patch_mesh: ArrayMesh = null

var planet_radius: float = 4000.0
var height_bound: float = 400.0
var material: ShaderMaterial
var leaves: Dictionary = {}  # key -> MeshInstance3D
var _pool: Array = []
var _wanted: Dictionary = {}
var _cam: Vector3 = Vector3.ZERO
var _cam_len: float = 0.0
var _cam_dir: Vector3 = Vector3.UP
var _horizon: float = 3.0
var patch_count: int = 0
var max_level_used: int = 0


static func get_patch_mesh() -> ArrayMesh:
	if _patch_mesh != null:
		return _patch_mesh
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := GRID + 1
	for j in n:
		for i in n:
			verts.append(Vector3(float(i) / GRID, float(j) / GRID, 0.0))
	for j in GRID:
		for i in GRID:
			var v00 := i + j * n
			var v10 := v00 + 1
			var v01 := v00 + n
			var v11 := v01 + 1
			idx.append_array([v00, v01, v11, v00, v11, v10])
	# skirts: duplicate the border vertices pulled toward the planet centre (z flag = 1), both windings
	var base := verts.size()
	var edge_ids: Array = []
	for e in 4:
		var ids := PackedInt32Array()
		for k in n:
			match e:
				0: ids.append(k)  # j = 0
				1: ids.append(GRID * n + k)  # j = GRID
				2: ids.append(k * n)  # i = 0
				3: ids.append(k * n + GRID)  # i = GRID
		edge_ids.append(ids)
	for e in 4:
		var ids: PackedInt32Array = edge_ids[e]
		var sk := PackedInt32Array()
		for k in n:
			var v: Vector3 = verts[ids[k]]
			verts.append(Vector3(v.x, v.y, 1.0))
			sk.append(verts.size() - 1)
		for k in GRID:
			var a := ids[k]
			var b := ids[k + 1]
			var c := sk[k + 1]
			var d := sk[k]
			idx.append_array([a, b, c, a, c, d, a, c, b, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	_patch_mesh = ArrayMesh.new()
	_patch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_patch_mesh.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	return _patch_mesh


func setup(radius: float, mat: ShaderMaterial, hbound: float) -> void:
	planet_radius = radius
	material = mat
	height_bound = hbound


func update_lod(cam_local: Vector3) -> void:
	_cam = cam_local
	_cam_len = cam_local.length()
	_cam_dir = cam_local / maxf(_cam_len, 0.001)
	var r_low := planet_radius - height_bound * 0.6
	var ang_cam := acos(clampf(r_low / maxf(_cam_len, r_low), 0.0, 1.0))
	var ang_peak := acos(clampf(r_low / (planet_radius + height_bound), 0.0, 1.0))
	_horizon = ang_cam + ang_peak
	if _cam_len < r_low * 1.0:
		_horizon = 4.0
	_wanted.clear()
	max_level_used = 0
	for f in 6:
		_visit(f, 0, 0, 0)
	for k in leaves.keys():
		if not _wanted.has(k):
			var mi: MeshInstance3D = leaves[k]
			mi.visible = false
			_pool.append(mi)
			leaves.erase(k)
	for k in _wanted:
		if not leaves.has(k):
			var w: Array = _wanted[k]
			leaves[k] = _make_patch(w[0], w[1], w[2], w[3])
	while _pool.size() > 24:
		(_pool.pop_back() as MeshInstance3D).queue_free()
	patch_count = leaves.size()


func _visit(face: int, level: int, ix: int, iy: int) -> void:
	var s := 2.0 / float(1 << level)
	var a0 := -1.0 + ix * s
	var b0 := -1.0 + iy * s
	var dc := TerrainParams.face_dir(face, a0 + s * 0.5, b0 + s * 0.5)
	var pw := s * planet_radius * 0.7854
	var patch_ang := pw * 0.9 / planet_radius + 0.03
	if _horizon < 3.0 and dc.angle_to(_cam_dir) > _horizon + patch_ang:
		return
	var dist := maxf(_cam.distance_to(dc * planet_radius) - pw * 0.72, 1.0)
	if level < MAX_LEVEL and pw > dist * SPLIT_RATIO:
		for cy in 2:
			for cx in 2:
				_visit(face, level + 1, ix * 2 + cx, iy * 2 + cy)
		return
	_wanted[face | (level << 3) | (ix << 8) | (iy << 20)] = [face, level, ix, iy, a0, b0, s]
	max_level_used = maxi(max_level_used, level)


func _make_patch(face: int, level: int, ix: int, iy: int) -> MeshInstance3D:
	var w: Array = _wanted[face | (level << 3) | (ix << 8) | (iy << 20)]
	var a0: float = w[4]
	var b0: float = w[5]
	var s: float = w[6]
	var mi: MeshInstance3D
	if _pool.size() > 0:
		mi = _pool.pop_back()
	else:
		mi = MeshInstance3D.new()
		mi.mesh = get_patch_mesh()
		mi.material_override = material
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
	mi.visible = true
	mi.set_instance_shader_parameter("patch_info", Vector4(a0, b0, s, float(face)))
	# bounding box in planet-local space: sample the patch corners/mid-points at inner and outer radius
	var lo := Vector3(1e20, 1e20, 1e20)
	var hi := Vector3(-1e20, -1e20, -1e20)
	var r_in := planet_radius - height_bound - s * planet_radius * 0.05
	var r_out := planet_radius + height_bound
	for sj in 3:
		for si in 3:
			var d := TerrainParams.face_dir(face, a0 + s * 0.5 * si, b0 + s * 0.5 * sj)
			for r in [r_in, r_out]:
				var p: Vector3 = d * r
				lo = lo.min(p)
				hi = hi.max(p)
	var pad := Vector3.ONE * (s * planet_radius * 0.02 + 2.0)
	mi.custom_aabb = AABB(lo - pad, hi - lo + pad * 2.0)
	return mi
