class_name ScatterModels
extends RefCounted
## Model helpers for the scatter system (M7a): normalised collider specs from the manifests, footprints, and per-planet tinted MultiMesh meshes.
## Main-thread only except the read-only spec getters after prime().

static var _specs: Dictionary = {}
static var _extents: Dictionary = {}

## make sure the manifest cache is loaded on the main thread before any worker reads it
static func prime(ids: Array) -> void:
	for id in ids:
		collider_spec(id)
		extent(id)

## Normalised collider: {shape: "none"|"cylinder"|"sphere"|"box", r, h, size: Vector3, center: Vector3, legs: Array(optional)}
## centre = middle of the shape in model space (y up, origin at the ground contact).
static func collider_spec(id: String) -> Dictionary:
	if _specs.has(id):
		return _specs[id]
	var mf := ModelLib.manifest(id)
	var c: Dictionary = mf.get("collider", {})
	var shape: String = str(c.get("shape", "none"))
	var spec: Dictionary = {"shape": shape, "r": 0.0, "h": 0.0, "size": Vector3.ZERO, "center": Vector3.ZERO}
	var off := float(c.get("offset_y", 0.0))
	match shape:
		"cylinder":
			spec["r"] = float(c.get("radius", 0.5))
			spec["h"] = float(c.get("height", 1.0))
			spec["center"] = Vector3(0, off + float(spec["h"]) * 0.5, 0)
		"sphere":
			spec["r"] = float(c.get("radius", 0.5))
			spec["center"] = Vector3(0, off + float(spec["r"]), 0)
		"box":
			var sz: Array = c.get("size", [1, 1, 1])
			spec["size"] = Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
			spec["center"] = Vector3(0, off + float((spec["size"] as Vector3).y) * 0.5, 0)
	if c.has("center"):
		var cc: Array = c["center"]
		spec["center"] = Vector3(float(cc[0]), float(cc[1]), float(cc[2]))
	# hand-tuned specials
	if id == "icicle_arch_a":
		spec["shape"] = "legs"
		spec["legs"] = [Vector3(-3.9, 3.0, 0.0), Vector3(3.9, 3.0, 0.0)]
		spec["r"] = 1.7
		spec["h"] = 6.0
	elif id == "mesa_rock_a":
		spec["r"] = 5.6
	elif id == "acid_pool_rim_a" or id == "coral_rock_a":
		pass
	_specs[id] = spec
	return spec

## largest horizontal half-extent x scale 1 (metres) -- used for exclusion and AABB padding
static func extent(id: String) -> float:
	if _extents.has(id):
		return _extents[id]
	var mf := ModelLib.manifest(id)
	var sz: Array = mf.get("size", [1.0, 1.0, 1.0])
	var e := maxf(maxf(float(sz[0]), float(sz[2])) * 0.5, float(sz[1]) * 0.5)
	_extents[id] = e
	return e

## largest horizontal half-extent of the model (metres at scale 1)
static func hextent(id: String) -> float:
	var mf := ModelLib.manifest(id)
	var sz: Array = mf.get("size", [1.0, 1.0, 1.0])
	return maxf(float(sz[0]), float(sz[2])) * 0.5

static func height_of(id: String) -> float:
	var mf := ModelLib.manifest(id)
	var sz: Array = mf.get("size", [1.0, 1.0, 1.0])
	return float(sz[1])

## add the collision shape(s) of `id` (scaled by s) to `body`. Returns the number of shapes added.
static func add_shapes(body: CollisionObject3D, id: String, s: float, shape_cache: Dictionary = {}) -> int:
	var spec := collider_spec(id)
	var shape_kind: String = spec["shape"]
	if shape_kind == "none":
		return 0
	var q := roundf(s * 10.0)
	var key := "%s|%d" % [id, int(q)]
	var shapes: Array = []
	if shape_cache.has(key):
		shapes = shape_cache[key]
	else:
		var sc := q / 10.0 if q > 0.0 else s
		match shape_kind:
			"cylinder":
				var cs := CylinderShape3D.new()
				cs.radius = float(spec["r"]) * sc
				cs.height = float(spec["h"]) * sc
				shapes.append([cs, (spec["center"] as Vector3) * sc])
			"sphere":
				var ss := SphereShape3D.new()
				ss.radius = float(spec["r"]) * sc
				shapes.append([ss, (spec["center"] as Vector3) * sc])
			"box":
				var bs := BoxShape3D.new()
				bs.size = (spec["size"] as Vector3) * sc
				shapes.append([bs, (spec["center"] as Vector3) * sc])
			"legs":
				for leg in spec["legs"]:
					var ls := CylinderShape3D.new()
					ls.radius = float(spec["r"]) * sc
					ls.height = float(spec["h"]) * sc
					shapes.append([ls, (leg as Vector3) * sc])
		shape_cache[key] = shapes
	for e in shapes:
		var cshape := CollisionShape3D.new()
		cshape.shape = e[0]
		cshape.position = e[1]
		body.add_child(cshape)
	return shapes.size()

# ---------------------------------------------------------------------------------------------------------------------
# tinting
# ---------------------------------------------------------------------------------------------------------------------
static func _shift(c: Color, adj: Array) -> Color:
	var h := c.h + float(adj[0])
	h = h - floorf(h)
	return Color.from_hsv(h, clampf(c.s * float(adj[1]), 0.0, 1.0), clampf(c.v * float(adj[2]), 0.0, 4.0), c.a)

## planet-specific copy of the model's merged MultiMesh mesh: tintable materials re-coloured with the palette
## (pal = {"leaf": [dh,ds,dv], "glow": [...], "rock": [...]}), per-instance colours enabled.
## fade_far > 0: the materials dither / fade out between 0.8 x fade_far and fade_far metres from the camera (no pop-in at the visibility limit).
static func tinted_mesh(id: String, pal: Dictionary, fade_far: float = 0.0) -> ArrayMesh:
	var src := ModelLib.merged_mesh(id)
	if src == null:
		return null
	var mesh := src.duplicate() as ArrayMesh
	var tw: Variant = ModelLib.manifest(id).get("tintable")
	var tint_words: Array = tw if tw is Array else []
	for si in mesh.get_surface_count():
		var m := mesh.surface_get_material(si)
		if m == null:
			continue
		var nm := m.duplicate() as StandardMaterial3D
		if nm == null:
			continue
		var mname := String(nm.resource_name).to_lower()
		var cls := -1
		for w in tint_words:
			var ws := String(w).to_lower()
			if mname.contains(ws):
				cls = FloraTables.tint_class(ws)
				break
		if cls >= 0:
			var key := "leaf" if cls == 0 else ("glow" if cls == 1 else "rock")
			var adj: Array = pal.get(key, [0.0, 1.0, 1.0])
			nm.albedo_color = _shift(nm.albedo_color, adj)
			if nm.emission_enabled:
				nm.emission = _shift(nm.emission, adj)
		nm.vertex_color_use_as_albedo = true
		mesh.surface_set_material(si, nm)
	return mesh

# ---------------------------------------------------------------------------------------------------------------------
# mesh LOD: decimated index buffers (ImporterMesh / meshoptimizer on a worker thread). The scatter manager swaps a MultiMesh's mesh for the
# LOD1 / LOD2 version once its cell is far enough away (the vertex buffers are shared, only the index buffer differs).
# ---------------------------------------------------------------------------------------------------------------------
const LOD_KEEP: Array = [0.3, 0.11]

static var _lod_idx: Dictionary = {}       # id -> Array[2] (lod1, lod2) of Array[PackedInt32Array per surface] (empty array = keep the original)
static var _lod_busy: Dictionary = {}
static var _lod_mutex: Mutex = Mutex.new()

static func total_tris(m: ArrayMesh) -> int:
	var t := 0
	for si in m.get_surface_count():
		var a := m.surface_get_arrays(si)
		var ix: Variant = a[Mesh.ARRAY_INDEX]
		if ix != null and (ix as PackedInt32Array).size() > 0:
			t += (ix as PackedInt32Array).size() / 3
		else:
			t += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t

static func lods_ready(id: String) -> bool:
	_lod_mutex.lock()
	var r := _lod_idx.has(id)
	_lod_mutex.unlock()
	return r

## main thread: start the background decimation of `src` (once per id). Returns the WorkerThreadPool task id or -1.
static func request_lods(id: String, src: ArrayMesh) -> int:
	if src == null:
		return -1
	_lod_mutex.lock()
	var skip := _lod_idx.has(id) or _lod_busy.has(id)
	if not skip:
		_lod_busy[id] = true
	_lod_mutex.unlock()
	if skip:
		return -1
	var surfaces: Array = []
	var tris := 0
	for si in src.get_surface_count():
		var arrs := src.surface_get_arrays(si)
		var ix: Variant = arrs[Mesh.ARRAY_INDEX]
		tris += (ix as PackedInt32Array).size() / 3 if ix != null else 0
		surfaces.append(arrs)
	if tris < 450:
		# too small to be worth it
		_lod_mutex.lock()
		_lod_idx[id] = [[], []]
		_lod_busy.erase(id)
		_lod_mutex.unlock()
		return -1
	return WorkerThreadPool.add_task(_lod_worker.bind(id, surfaces), false, "scatter_lod")

static func _lod_worker(id: String, surfaces: Array) -> void:
	var res: Array = [[], []]
	var im := ImporterMesh.new()
	var simplifiable: Array = []
	for si in surfaces.size():
		var arrs: Array = surfaces[si]
		var ix: Variant = arrs[Mesh.ARRAY_INDEX]
		simplifiable.append(ix != null and (ix as PackedInt32Array).size() >= 90)
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrs, [], {}, null, "s%d" % si)
	im.generate_lods(25.0, 60.0, [])
	for k in 2:
		var per_surface: Array = []
		for si in surfaces.size():
			var ix: Variant = (surfaces[si] as Array)[Mesh.ARRAY_INDEX]
			var full := (ix as PackedInt32Array).size() if ix != null else 0
			var best := PackedInt32Array()
			if bool(simplifiable[si]):
				var want := float(full) * float(LOD_KEEP[k])
				var n_l := im.get_surface_lod_count(si)
				for l in n_l:
					var li := im.get_surface_lod_indices(si, l)
					if li.size() >= 3 and li.size() < full:
						best = li
						if float(li.size()) <= want * 1.25:
							break
			per_surface.append(best)
		res[k] = per_surface
	_lod_mutex.lock()
	_lod_idx[id] = res
	_lod_busy.erase(id)
	_lod_mutex.unlock()

## LOD copy of `base` (the planet-tinted full mesh of `id`) for level 1 or 2; null when the decimation is not ready or nothing could be removed.
static func lod_variant(base: ArrayMesh, id: String, level: int) -> ArrayMesh:
	_lod_mutex.lock()
	var rec: Variant = _lod_idx.get(id)
	_lod_mutex.unlock()
	if rec == null or level < 1 or level > 2:
		return null
	var per_surface: Array = (rec as Array)[level - 1]
	if per_surface.is_empty():
		return null
	var out := ArrayMesh.new()
	var changed := false
	for si in base.get_surface_count():
		var arrays := base.surface_get_arrays(si)
		if si < per_surface.size() and (per_surface[si] as PackedInt32Array).size() >= 3:
			arrays[Mesh.ARRAY_INDEX] = per_surface[si]
			changed = true
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, base.surface_get_material(si))
	return out if changed else null
