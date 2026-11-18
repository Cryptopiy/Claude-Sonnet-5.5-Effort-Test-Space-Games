class_name Models
extends RefCounted
## Model library: loads the Blender-made GLBs from res://assets/models, reads manifest.json (collision hints),
## merges meshes for instancing and applies per-biome tints. Falls back to simple generated meshes if a model is missing.

const DIR := "res://assets/models/"

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false
static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}

static func manifest() -> Dictionary:
	if not _manifest_loaded:
		_manifest_loaded = true
		var path: String = DIR + "manifest.json"
		if FileAccess.file_exists(path):
			var txt: String = FileAccess.get_file_as_string(path)
			var j: Variant = JSON.parse_string(txt)
			if j is Dictionary:
				_manifest = j
	return _manifest

static func has_model(model_name: String) -> bool:
	return ResourceLoader.exists(DIR + model_name + ".glb")

static func collision_hint(model_name: String) -> Dictionary:
	var m: Dictionary = manifest()
	if m.has(model_name):
		var e: Dictionary = m[model_name]
		if e.has("collision"):
			return e["collision"]
	return _default_collision(model_name)

static func model_size(model_name: String) -> Vector3:
	var m: Dictionary = manifest()
	if m.has(model_name):
		var s: Array = m[model_name].get("size", [1, 1, 1])
		return Vector3(float(s[0]), float(s[1]), float(s[2]))
	return Vector3(2, 3, 2)

static func _default_collision(n: String) -> Dictionary:
	match n:
		"landing_pad":
			return {"shape": "cylinder", "radius": 8.0, "height": 1.2, "offset": [0, -0.6, 0]}
		"outpost_hab":
			return {"shape": "box", "size": [8.0, 4.0, 8.0], "offset": [0, 2.0, 0]}
		"outpost_tower":
			return {"shape": "cylinder", "radius": 1.0, "height": 18.0, "offset": [0, 9.0, 0]}
		"outpost_container", "outpost_container_b":
			return {"shape": "box", "size": [2.5, 2.6, 6.0], "offset": [0, 1.3, 0]}
		"outpost_tank":
			return {"shape": "cylinder", "radius": 2.2, "height": 6.0, "offset": [0, 3.0, 0]}
		"outpost_solar":
			return {"shape": "box", "size": [8.0, 1.6, 5.0], "offset": [0, 0.8, 0]}
		"beacon_pylon":
			return {"shape": "cylinder", "radius": 0.6, "height": 7.0, "offset": [0, 3.5, 0]}
		"monolith":
			return {"shape": "box", "size": [2.2, 7.0, 0.9], "offset": [0, 3.5, 0]}
		"crate_supply":
			return {"shape": "box", "size": [1.2, 1.0, 1.2], "offset": [0, 0.5, 0]}
		"wreck_ship":
			return {"shape": "box", "size": [3.0, 2.0, 9.0], "offset": [0, 1.0, 0]}
	if n.begins_with("tree") or n.contains("pine") or n.contains("mushroom_giant") or n.contains("cactus_a") or n.contains("dead_tree") or n.contains("charred"):
		return {"shape": "cylinder", "radius": 0.45, "height": 5.0, "offset": [0, 2.5, 0]}
	if n.contains("rock") or n.contains("boulder") or n.contains("spire") or n.contains("crystal") or n.contains("ice"):
		return {"shape": "sphere", "radius": 1.1, "offset": [0, 0.9, 0]}
	return {"shape": "none"}

## instantiate a model scene (unmodified), or a placeholder if missing
static func instantiate(model_name: String) -> Node3D:
	var path: String = DIR + model_name + ".glb"
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		if ps:
			var n: Node = ps.instantiate()
			if n is Node3D:
				return n as Node3D
	var mi := MeshInstance3D.new()
	mi.mesh = _fallback_mesh(model_name)
	return mi

## all MeshInstance3D below node, with transforms relative to `root`
static func _collect_meshes(n: Node, root: Node3D, xf: Transform3D, out: Array) -> void:
	var t: Transform3D = xf
	if n is Node3D and n != root:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.visible and not String(mi.name).begins_with("Cockpit_Interior"):
			out.append([mi, t])
	for c in n.get_children():
		_collect_meshes(c, root, t, out)

static func _tinted_material(src: Material, tints: Dictionary, tint_key: String) -> Material:
	if not (src is BaseMaterial3D):
		return src
	var bm := src as BaseMaterial3D
	var nm: String = bm.resource_name
	var kind: String = ""
	if nm.begins_with("Foliage"):
		kind = "foliage"
	elif nm.begins_with("Crystal"):
		kind = "crystal"
	elif nm.begins_with("Glow") and nm != "Glow_Lava":
		kind = "glow"
	elif nm.begins_with("Rock") or nm.begins_with("Stone"):
		kind = "rock"
	elif nm.begins_with("Bark") or nm.begins_with("Wood"):
		kind = "wood"
	if kind == "" or tints.is_empty():
		return src
	var tint: Color = Color.WHITE
	match kind:
		"foliage":
			tint = tints.get(tint_key, tints.get("foliage", Color(0.4, 0.6, 0.25)))
		"crystal", "glow":
			tint = tints.get(tint_key, tints.get("glow_a", tints.get("ice", Color(0.6, 0.9, 1.0))))
		"rock":
			tint = tints.get("rock", Color(0.6, 0.58, 0.55))
		"wood":
			tint = tints.get("wood", Color(0.5, 0.4, 0.32))
	var key: String = "%s|%s|%s" % [bm.get_instance_id(), kind, tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: BaseMaterial3D = bm.duplicate()
	var orig: Color = bm.albedo_color
	var v: float = maxf(orig.v, 0.05)
	match kind:
		"foliage":
			var k: float = clampf(v / 0.62, 0.45, 1.4)
			m.albedo_color = Color(tint.r * k, tint.g * k, tint.b * k, orig.a)
		"rock":
			var k2: float = clampf(v / 0.5, 0.4, 1.5)
			m.albedo_color = Color(tint.r * k2, tint.g * k2, tint.b * k2, orig.a)
		"wood":
			m.albedo_color = Color(orig.r * tint.r * 1.8, orig.g * tint.g * 1.8, orig.b * tint.b * 1.8, orig.a)
		"crystal":
			m.albedo_color = Color(tint.r, tint.g, tint.b, orig.a)
			if m.emission_enabled:
				m.emission = tint
		"glow":
			m.albedo_color = Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35, orig.a)
			m.emission_enabled = true
			m.emission = tint
	_mat_cache[key] = m
	return m

## Merged ArrayMesh of a model (all surfaces, transforms baked, materials tinted).
static func get_mesh(model_name: String, tints: Dictionary, tint_key: String) -> Mesh:
	var tkey: String = tint_key + (tints.get(tint_key, Color.WHITE) as Color).to_html() + (tints.get("rock", Color.WHITE) as Color).to_html()
	var key: String = model_name + "|" + tkey
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var path: String = DIR + model_name + ".glb"
	var out_mesh: ArrayMesh = null
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		if ps:
			var root: Node = ps.instantiate()
			if root is Node3D:
				var lst: Array = []
				_collect_meshes(root, root as Node3D, Transform3D.IDENTITY, lst)
				out_mesh = ArrayMesh.new()
				for e in lst:
					var mi: MeshInstance3D = e[0]
					var xf: Transform3D = e[1]
					var me: Mesh = mi.mesh
					for s in me.get_surface_count():
						var arrays: Array = me.surface_get_arrays(s)
						var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						var nv: int = verts.size()
						var nv_arr: Variant = arrays[Mesh.ARRAY_NORMAL]
						var b: Basis = xf.basis
						var nb: Basis = b.inverse().transposed()
						for i in nv:
							verts[i] = xf * verts[i]
						arrays[Mesh.ARRAY_VERTEX] = verts
						if nv_arr is PackedVector3Array:
							var nn: PackedVector3Array = nv_arr
							for i in nn.size():
								nn[i] = (nb * nn[i]).normalized()
							arrays[Mesh.ARRAY_NORMAL] = nn
						arrays[Mesh.ARRAY_TANGENT] = null
						var prim: int = me.surface_get_primitive_type(s)
						var idx: int = out_mesh.get_surface_count()
						out_mesh.add_surface_from_arrays(prim, arrays)
						var mat: Material = mi.get_active_material(s)
						if mat == null:
							mat = me.surface_get_material(s)
						if mat != null:
							out_mesh.surface_set_material(idx, _tinted_material(mat, tints, tint_key))
				if out_mesh.get_surface_count() == 0:
					out_mesh = null
			root.free()
	if out_mesh == null:
		out_mesh = _fallback_mesh(model_name)
		_apply_fallback_color(out_mesh, model_name, tints, tint_key)
	_mesh_cache[key] = out_mesh
	return out_mesh

# ---------------------------------------------------------------------------------------------------------
static func _apply_fallback_color(m: ArrayMesh, n: String, tints: Dictionary, tint_key: String) -> void:
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		if mat is StandardMaterial3D:
			var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			if sm.resource_name == "foliage":
				var t: Color = tints.get(tint_key, tints.get("foliage", Color(0.35, 0.6, 0.25)))
				sm.albedo_color = t
			elif sm.resource_name == "rock":
				sm.albedo_color = tints.get("rock", Color(0.55, 0.52, 0.5)) * 0.8
			elif sm.resource_name == "glow":
				var gt: Color = tints.get(tint_key, tints.get("glow_a", Color(0.5, 1.0, 0.5)))
				sm.albedo_color = gt * 0.5
				sm.emission_enabled = true
				sm.emission = gt
				sm.emission_energy_multiplier = 2.0
			m.surface_set_material(s, sm)

static func _mat(nm: String, c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = nm
	m.albedo_color = c
	m.roughness = rough
	return m

static func _add_prim(st_mesh: ArrayMesh, prim_mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	var arrays: Array = prim_mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in v.size():
		v[i] = xf * v[i]
		nrm[i] = (xf.basis * nrm[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TANGENT] = null
	var idx: int = st_mesh.get_surface_count()
	st_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st_mesh.surface_set_material(idx, mat)

static func _cyl(m: ArrayMesh, r: float, h: float, pos: Vector3, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	_add_prim(m, c, Transform3D(Basis.IDENTITY, pos), mat)

static func _box(m: ArrayMesh, size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	_add_prim(m, b, Transform3D(Basis.IDENTITY, pos), mat)

static func _fallback_mesh(n: String) -> ArrayMesh:
	var key: String = "fb|" + n
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := ArrayMesh.new()
	var bark := _mat("wood", Color(0.30, 0.22, 0.15))
	var leaf := _mat("foliage", Color(0.3, 0.6, 0.25))
	var rock := _mat("rock", Color(0.5, 0.48, 0.46))
	var glow := _mat("glow", Color(0.5, 1.0, 0.5))
	var metal := _mat("metal", Color(0.62, 0.64, 0.68), 0.4)
	var dark := _mat("dark", Color(0.14, 0.15, 0.17), 0.5)
	var warm := _mat("warm", Color(0.92, 0.5, 0.15), 0.55)
	if n == "landing_pad":
		_cyl(m, 8.0, 1.2, Vector3(0, -0.6, 0), metal)
		_cyl(m, 6.0, 0.06, Vector3(0, 0.03, 0), dark)
		_cyl(m, 7.6, 0.05, Vector3(0, 0.02, 0), warm)
	elif n == "outpost_hab":
		var dome := SphereMesh.new()
		dome.radius = 4.0
		dome.height = 4.0
		dome.is_hemisphere = true
		_add_prim(m, dome, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), metal)
		_cyl(m, 4.2, 0.8, Vector3(0, 0.0, 0), dark)
	elif n == "outpost_tower":
		_box(m, Vector3(1.0, 18.0, 1.0), Vector3(0, 9.0, 0), metal)
		_box(m, Vector3(3.0, 0.4, 3.0), Vector3(0, 17.5, 0), dark)
	elif n.begins_with("outpost_container"):
		_box(m, Vector3(2.5, 2.6, 6.0), Vector3(0, 1.3, 0), warm if n == "outpost_container" else metal)
	elif n == "outpost_tank":
		_cyl(m, 2.0, 6.0, Vector3(0, 3.0, 0), metal)
	elif n == "outpost_solar":
		_box(m, Vector3(8.0, 0.2, 5.0), Vector3(0, 1.4, 0), dark)
	elif n == "beacon_pylon":
		_cyl(m, 0.5, 7.0, Vector3(0, 3.5, 0), metal)
		_cyl(m, 0.9, 0.9, Vector3(0, 7.3, 0), glow)
	elif n == "monolith":
		_box(m, Vector3(2.2, 7.0, 0.9), Vector3(0, 3.5, 0), dark)
	elif n == "crate_supply":
		_box(m, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0), warm)
	elif n == "wreck_ship":
		_box(m, Vector3(3.0, 2.0, 9.0), Vector3(0, 1.0, 0), dark)
	elif n == "ship_explorer":
		_box(m, Vector3(2.4, 1.8, 12.0), Vector3(0, 0, 0), metal)
		_box(m, Vector3(11.0, 0.3, 3.5), Vector3(0, -0.2, 2.0), warm)
		_box(m, Vector3(1.4, 0.9, 2.5), Vector3(0, 1.1, -3.0), dark)
	elif n == "astronaut":
		var cap := CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.5
		_add_prim(m, cap, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), _mat("suit", Color(0.9, 0.9, 0.92), 0.6))
		var hd := SphereMesh.new()
		hd.radius = 0.28
		hd.height = 0.56
		_add_prim(m, hd, Transform3D(Basis.IDENTITY, Vector3(0, 1.62, 0)), warm)
	elif n.contains("grass"):
		for i in 5:
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.05
			c.height = 0.7
			c.radial_segments = 3
			c.rings = 1
			var a: float = float(i) / 5.0 * TAU
			_add_prim(m, c, Transform3D(Basis(Vector3(0, 0, 1), sin(a) * 0.25) * Basis(Vector3(0, 1, 0), a), Vector3(cos(a) * 0.1, 0.35, sin(a) * 0.1)), leaf)
	elif n.contains("tree") or n.contains("pine") or n.contains("dead") or n.contains("charred"):
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.22
		trunk.bottom_radius = 0.38
		trunk.height = 5.0
		trunk.radial_segments = 8
		_add_prim(m, trunk, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 0)), bark)
		if not (n.contains("dead") or n.contains("charred")):
			if n.contains("pine"):
				for i in 3:
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0
					cone.bottom_radius = 2.2 - i * 0.55
					cone.height = 3.0
					cone.radial_segments = 8
					_add_prim(m, cone, Transform3D(Basis.IDENTITY, Vector3(0, 3.6 + i * 1.7, 0)), leaf)
			else:
				var crown := SphereMesh.new()
				crown.radius = 2.6
				crown.height = 4.4
				crown.radial_segments = 10
				crown.rings = 6
				_add_prim(m, crown, Transform3D(Basis.IDENTITY, Vector3(0, 6.2, 0)), leaf)
	elif n.contains("mushroom"):
		var st := CylinderMesh.new()
		st.top_radius = 0.35
		st.bottom_radius = 0.55
		st.height = 4.0
		_add_prim(m, st, Transform3D(Basis.IDENTITY, Vector3(0, 2.0, 0)), bark)
		var cap := SphereMesh.new()
		cap.radius = 2.8
		cap.height = 2.8
		cap.is_hemisphere = true
		_add_prim(m, cap, Transform3D(Basis.IDENTITY, Vector3(0, 3.8, 0)), glow)
	elif n.contains("cactus"):
		var cb := CapsuleMesh.new()
		cb.radius = 0.45
		cb.height = 3.6
		_add_prim(m, cb, Transform3D(Basis.IDENTITY, Vector3(0, 1.8, 0)), leaf)
		var arm := CapsuleMesh.new()
		arm.radius = 0.25
		arm.height = 1.6
		_add_prim(m, arm, Transform3D(Basis(Vector3(0, 0, 1), 0.9), Vector3(0.7, 2.2, 0)), leaf)
	elif n.contains("crystal") or n.contains("spire") or n.contains("ice"):
		for i in 4:
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.0
			c2.bottom_radius = 0.5 + 0.1 * i
			c2.height = 2.2 + i * 0.9
			c2.radial_segments = 5
			var a2: float = float(i) * 1.7
			_add_prim(m, c2, Transform3D(Basis(Vector3(0, 0, 1), sin(a2) * 0.25), Vector3(cos(a2) * 0.6, (2.2 + i * 0.9) * 0.5, sin(a2) * 0.6)), glow)
	elif n.contains("bush") or n.contains("shrub") or n.contains("fern") or n.contains("flower") or n.contains("frost") or n.contains("pod") or n.contains("tentacle") or n.contains("fungus"):
		var b := SphereMesh.new()
		b.radius = 0.8
		b.height = 1.2
		b.radial_segments = 8
		b.rings = 4
		_add_prim(m, b, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), leaf if not n.contains("pod") and not n.contains("fungus") else glow)
	else:
		var r := SphereMesh.new()
		r.radius = 1.2
		r.height = 1.9
		r.radial_segments = 8
		r.rings = 5
		_add_prim(m, r, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.75, 0.9)), Vector3(0, 0.8, 0)), rock)
	_mesh_cache[key] = m
	return m
