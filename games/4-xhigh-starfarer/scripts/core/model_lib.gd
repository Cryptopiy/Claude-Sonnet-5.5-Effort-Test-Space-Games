class_name ModelLib
extends RefCounted
## Cached access to the Blender-made GLB models: scenes, tinted meshes for MultiMesh use.

const EMISSION_SCALE := 0.32
const EMISSION_SCALE_BY_NAME := {"engine_glow": 0.1, "jet_glow": 0.1, "light_white": 0.15, "lamp_white": 0.09, "light_red": 0.3, "light_green": 0.3, "lamp_red": 0.3, "screen_blue": 0.1, "tool_screen": 0.2}


const MATERIAL_TWEAKS := {"hull_white": [0.12, 0.5], "hull_dark": [0.55, 0.45], "hull_trim": [0.5, 0.4], "metal_gray": [0.35, 0.55], "hab_white": [0.1, 0.55], "hab_gray": [0.3, 0.5], "hab_orange": [0.1, 0.55]}


static func tweak(mat: BaseMaterial3D) -> void:
	if MATERIAL_TWEAKS.has(mat.resource_name):
		var t: Array = MATERIAL_TWEAKS[mat.resource_name]
		mat.metallic = t[0]
		mat.roughness = t[1]


static func emission_scale(mname: String) -> float:
	return EMISSION_SCALE_BY_NAME.get(mname, EMISSION_SCALE)
static var _scenes := {}
static var _meshes := {}


static func scene(name_: String) -> PackedScene:
	if not _scenes.has(name_):
		_scenes[name_] = load("res://assets/models/%s.glb" % name_)
	return _scenes[name_]


static func first_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for c in root.get_children():
		var r := first_mesh_instance(c)
		if r != null:
			return r
	return null


static func tint_key(tint: Dictionary) -> String:
	var s := ""
	for k in tint:
		s += "%s=%s;" % [k, (tint[k] as Color).to_html(false)]
	return s


## ArrayMesh of the model's (first) mesh with materials re-coloured by material name.
static func mesh(name_: String, tint: Dictionary = {}) -> Mesh:
	var key := name_ + "|" + tint_key(tint)
	if _meshes.has(key):
		return _meshes[key]
	var inst := scene(name_).instantiate()
	var mi := first_mesh_instance(inst)
	var m: Mesh = mi.mesh.duplicate()
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		if src == null:
			continue
		var mat := src.duplicate() as BaseMaterial3D
		if mat == null:
			continue
		if mat.emission_enabled:
			mat.emission_energy_multiplier *= emission_scale(mat.resource_name)
		tweak(mat)
		var mname := mat.resource_name
		if tint.has(mname):
			var c: Color = tint[mname]
			mat.albedo_color = c
			if mat.emission_enabled:
				mat.emission = Color(c.r, c.g, c.b).lerp(mat.emission, 0.15)
		m.surface_set_material(i, mat)
	inst.free()
	_meshes[key] = m
	return m


## instance a full scene (all nodes) with tinted materials; caller owns the node
static func instance(name_: String, tint: Dictionary = {}) -> Node3D:
	var inst: Node3D = scene(name_).instantiate()
	_tone_emission(inst)
	if not tint.is_empty():
		_tint_tree(inst, tint)
	return inst


static func _tone_emission(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and not mi.mesh.has_meta("toned"):
			var m: Mesh = mi.mesh.duplicate()
			for i in m.get_surface_count():
				var src := m.surface_get_material(i)
				if src is BaseMaterial3D and (src as BaseMaterial3D).emission_enabled:
					var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
					mat.emission_energy_multiplier *= EMISSION_SCALE
					m.surface_set_material(i, mat)
			m.set_meta("toned", true)
			mi.mesh = m
	for c in n.get_children():
		_tone_emission(c)


static func _tint_tree(n: Node, tint: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var m: Mesh = mi.mesh.duplicate()
			for i in m.get_surface_count():
				var src := m.surface_get_material(i)
				if src is BaseMaterial3D:
					var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
					if tint.has(mat.resource_name):
						var c: Color = tint[mat.resource_name]
						mat.albedo_color = c
						if mat.emission_enabled:
							mat.emission = Color(c.r, c.g, c.b)
					m.surface_set_material(i, mat)
			mi.mesh = m
	for c in n.get_children():
		_tint_tree(c, tint)
