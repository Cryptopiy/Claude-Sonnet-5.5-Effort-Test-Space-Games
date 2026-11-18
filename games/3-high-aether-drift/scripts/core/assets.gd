class_name Assets
extends RefCounted
## Loads the Blender-made .glb models (assets/models) and hands out instances / shared meshes.

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}


static func scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load("res://assets/models/%s.glb" % model)
	return _scenes[model]


static var _toned: Dictionary = {}


static func instance(model: String) -> Node3D:
	var s := scene(model)
	if s == null:
		push_error("Missing model: " + model)
		return Node3D.new()
	var n := s.instantiate() as Node3D
	_tone_emission(n)
	return n


## The glTF emission strengths are authored for a bloom-free viewer; calm them a little once per material.
static func _tone_emission(n: Node) -> void:
	for mi in all_meshes(n):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is BaseMaterial3D and not _toned.has(m.get_instance_id()):
				_toned[m.get_instance_id()] = true
				var bm := m as BaseMaterial3D
				if bm.emission_enabled:
					bm.emission_energy_multiplier *= 0.4


## First MeshInstance3D mesh found in the model (for MultiMeshes).
static func mesh(model: String) -> Mesh:
	if _meshes.has(model):
		return _meshes[model]
	var inst := instance(model)
	var mi := find_mesh_instance(inst)
	var m: Mesh = mi.mesh if mi else null
	_meshes[model] = m
	inst.free()
	return m


static func find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := find_mesh_instance(c)
		if r:
			return r
	return null


static func all_meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		all_meshes(c, out)
	return out


static func make_double_sided_and_fix(n: Node) -> void:
	# glTF alpha materials import fine; nothing needed today, kept as a hook for per-model fixes
	pass
