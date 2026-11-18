class_name ModelLib
extends RefCounted
## Loads the Blender-made .glb models from res://assets/models/ (+ the manifest_*.json metadata). All 3D models in the game come through here.
## Missing models never crash the game: a coloured placeholder box is returned (and one warning printed).

const DIR := "res://assets/models/"

static var _scenes: Dictionary = {}
static var _manifest: Dictionary = {}
static var _manifest_loaded := false
static var _merged: Dictionary = {}
static var _warned: Dictionary = {}

static func path_of(id: String) -> String:
	return DIR + id + ".glb"

static func has(id: String) -> bool:
	return ResourceLoader.exists(path_of(id))

static func _load_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("manifest_") and f.ends_with(".json"):
			var txt := FileAccess.get_file_as_string(DIR + f)
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary and parsed.has("models"):
				for m in parsed["models"]:
					if m is Dictionary and m.has("id"):
						_manifest[m["id"]] = m

## manifest entry for a model id ({} if unknown). Keys per docs/MODELS_SPEC.md: size, base_y, collider, tris, biomes, nodes, notes...
static func manifest(id: String) -> Dictionary:
	_load_manifest()
	return _manifest.get(id, {})

static func all_ids() -> Array:
	_load_manifest()
	return _manifest.keys()

static func ids_of_kind(kind: String) -> Array:
	_load_manifest()
	var out: Array = []
	for k in _manifest:
		if _manifest[k].get("kind", "") == kind:
			out.append(k)
	return out

static func ids_for_biome(biome: String, kind: String = "") -> Array:
	_load_manifest()
	var out: Array = []
	for k in _manifest:
		var m: Dictionary = _manifest[k]
		if kind != "" and m.get("kind", "") != kind:
			continue
		var bl: Array = m.get("biomes", [])
		if biome in bl or "any" in bl:
			out.append(k)
	out.sort()
	return out

## fresh instance of the model (Node3D root with the exported node hierarchy). Placeholder box if missing.
static func instantiate(id: String) -> Node3D:
	var ps = _scenes.get(id)
	if ps == null and not _scenes.has(id):
		if has(id):
			ps = load(path_of(id))
		_scenes[id] = ps
	if ps is PackedScene:
		var n := (ps as PackedScene).instantiate() as Node3D
		if n != null:
			return n
	if not _warned.has(id):
		_warned[id] = true
		push_warning("ModelLib: model '%s' missing - using placeholder" % id)
	return _placeholder(id)

static func _placeholder(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sz := Vector3(1.0, 1.0, 1.0)
	var mf := manifest(id)
	if mf.has("size"):
		sz = Vector3(mf["size"][0], mf["size"][1], mf["size"][2])
	bm.size = sz
	mi.mesh = bm
	mi.position.y = sz.y * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.from_hsv(float(id.hash() % 360) / 360.0, 0.5, 0.8)
	mi.material_override = m
	root.add_child(mi)
	return root

## All MeshInstance3D parts of a model merged into ONE ArrayMesh (node transforms baked in, materials kept per surface).
## Use for MultiMesh scattering. Cached. Returns null only if nothing could be built.
static func merged_mesh(id: String) -> ArrayMesh:
	if _merged.has(id):
		return _merged[id]
	var root := instantiate(id)
	var out := ArrayMesh.new()
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var xf: Transform3D = it[1]
		var nxf := xf
		if n is Node3D and n != root:
			nxf = xf * (n as Node3D).transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(si)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var tv := PackedVector3Array()
				tv.resize(verts.size())
				for i in verts.size():
					tv[i] = nxf * verts[i]
				arrays[Mesh.ARRAY_VERTEX] = tv
				if arrays[Mesh.ARRAY_NORMAL] != null:
					var nr: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var tn := PackedVector3Array()
					tn.resize(nr.size())
					var nb := nxf.basis.inverse().transposed()
					for i in nr.size():
						tn[i] = (nb * nr[i]).normalized()
					arrays[Mesh.ARRAY_NORMAL] = tn
				arrays[Mesh.ARRAY_TANGENT] = null
				var si_out := out.get_surface_count()
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var mat := mi.get_active_material(si)
				if mat != null:
					out.surface_set_material(si_out, mat)
		for c in n.get_children():
			stack.append([c, nxf])
	root.free()
	if out.get_surface_count() == 0:
		return null
	_merged[id] = out
	return out

## find a named node inside an instantiated model (recursive); null if absent
static func find_node(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
