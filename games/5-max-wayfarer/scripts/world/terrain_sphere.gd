class_name TerrainSphere
extends Node3D
## Cube-sphere quadtree terrain with threaded chunk generation, skirts, per-chunk colliders (finest level only),
## water meshes, and instanced props. All coordinates are planet-local.

const SPLIT_FACTOR: float = 2.7
const MERGE_FACTOR: float = 3.15
const MAX_INFLIGHT: int = 7
const CHUNK_CAP: int = 460
var idle_trim: bool = false   # set by Planet for planets the viewer is not close to

class Chunk:
	extends RefCounted
	var key: int = 0
	var face: int = 0
	var level: int = 0
	var ix: int = 0
	var iy: int = 0
	var state: int = 0            # 0 none, 1 pending, 2 ready
	var node: Node3D = null
	var mesh_inst: MeshInstance3D = null
	var water_inst: MeshInstance3D = null
	var body: StaticBody3D = null
	var prop_body: StaticBody3D = null
	var is_split: bool = false
	var shown: bool = false
	var last_used: int = 0
	var cdir: Vector3 = Vector3.UP
	var size: float = 100.0
	var h_mid: float = 0.0
	var dist: float = 0.0
	var has_collider: bool = false
	var res_list: Array = []

var gen: TerrainGen
var data: BodyData
var terrain_mat: Material
var water_mat: Material
var layer_mask: int = 1
var cast_shadows: bool = true
var chunks: Dictionary = {}
var _jobs: Array = []
var _want: Array = []
var _vis_prev: Dictionary = {}
var _vis_new: Dictionary = {}
var _frame: int = 0
var _cam: Vector3 = Vector3(0, 1e6, 0)
var _tints: Dictionary = {}
var _flora: Array = []
var _flora_mesh: Array = []
var enable_props: bool = true
var enable_colliders: bool = true
var split_scale: float = 1.0
var stat_ready: int = 0
var stat_visible: int = 0
var last_update_cost_us: int = 0

static func make_key(face: int, level: int, ix: int, iy: int) -> int:
	return (level << 48) | (face << 44) | (ix << 22) | iy

func setup(b: BodyData, g: TerrainGen, tmat: Material, wmat: Material, lmask: int) -> void:
	data = b
	gen = g
	terrain_mat = tmat
	water_mat = wmat
	layer_mask = lmask
	_tints = b.profile.get("tint", {})
	_flora = b.profile.get("flora", [])
	for e in _flora.size():
		_flora_mesh.append(null)
	for f in 6:
		var c := _get_chunk(f, 0, 0, 0, null)
		_want.append(c)
	_dispatch()

func _get_chunk(face: int, level: int, ix: int, iy: int, parent: Chunk) -> Chunk:
	var key: int = make_key(face, level, ix, iy)
	var c: Chunk = chunks.get(key)
	if c != null:
		return c
	c = Chunk.new()
	c.key = key
	c.face = face
	c.level = level
	c.ix = ix
	c.iy = iy
	c.cdir = gen.chunk_center_dir(face, level, ix, iy)
	c.size = gen.chunk_size(level)
	c.h_mid = parent.h_mid if parent != null else 0.0
	c.last_used = _frame
	chunks[key] = c
	return c

# ---------------------------------------------------------------------------------------------------------
## Called ~10x per second with the camera position in planet-local coordinates.
func update_lod(cam_local: Vector3, ahead: Vector3 = Vector3.ZERO) -> void:
	var t0: int = Time.get_ticks_usec()
	_frame += 1
	_cam = cam_local
	_vis_new.clear()
	_want.clear()
	for f in 6:
		var rc: Chunk = chunks.get(make_key(f, 0, 0, 0))
		if rc != null:
			_visit(rc)
	# apply visibility
	for k in _vis_prev.keys():
		if not _vis_new.has(k):
			var c: Chunk = chunks.get(k)
			if c != null:
				_set_shown(c, false)
	for k in _vis_new.keys():
		var c2: Chunk = _vis_new[k]
		if not c2.shown:
			_set_shown(c2, true)
	var tmp: Dictionary = _vis_prev
	_vis_prev = _vis_new
	_vis_new = tmp
	stat_visible = _vis_prev.size()
	# prefetch: request the chunks the viewer will need in ~1 s (fast low flight) without showing them
	if ahead.length_squared() > 900.0:
		_cam = cam_local + ahead
		for f2 in 6:
			var rc2: Chunk = chunks.get(make_key(f2, 0, 0, 0))
			if rc2 != null:
				_prefetch(rc2)
		_cam = cam_local
	_dispatch()
	if _frame % 20 == 0 and chunks.size() > CHUNK_CAP:
		# the cache ages out faster the more it has grown (a fast low flight creates chunks quicker than a 30 s lifetime frees them)
		var over: float = float(chunks.size()) / float(CHUNK_CAP)
		_evict(400 if over < 1.6 else (150 if over < 2.6 else 50))
	elif idle_trim and _frame % 4 == 0 and chunks.size() > _vis_prev.size() + 24:
		_evict(6)
	last_update_cost_us = Time.get_ticks_usec() - t0

func _visit(c: Chunk) -> void:
	c.last_used = _frame
	var pos: Vector3 = c.cdir * (gen.R + c.h_mid)
	var dist: float = maxf(_cam.distance_to(pos) - c.size * 0.62, 0.0)
	c.dist = dist
	var thresh: float = c.size * (MERGE_FACTOR if c.is_split else SPLIT_FACTOR) * split_scale
	var want_split: bool = c.level < gen.max_level and dist < thresh
	if want_split:
		var all_ready: bool = true
		var kids: Array = []
		for dy in 2:
			for dx in 2:
				var k: Chunk = _get_chunk(c.face, c.level + 1, c.ix * 2 + dx, c.iy * 2 + dy, c)
				kids.append(k)
				if k.state != 2:
					all_ready = false
					if k.state == 0:
						k.dist = dist
						_want.append(k)
		if all_ready:
			c.is_split = true
			for k2 in kids:
				_visit(k2)
			return
	else:
		c.is_split = false
	if c.state == 2:
		_vis_new[c.key] = c
	elif c.state == 0:
		_want.append(c)

func _prefetch(c: Chunk) -> void:
	c.last_used = _frame
	var pos: Vector3 = c.cdir * (gen.R + c.h_mid)
	var dist: float = maxf(_cam.distance_to(pos) - c.size * 0.62, 0.0)
	if c.level < gen.max_level and dist < c.size * SPLIT_FACTOR * split_scale:
		var all_ready: bool = true
		var kids: Array = []
		for dy in 2:
			for dx in 2:
				var k: Chunk = _get_chunk(c.face, c.level + 1, c.ix * 2 + dx, c.iy * 2 + dy, c)
				kids.append(k)
				if k.state != 2:
					all_ready = false
					if k.state == 0:
						k.dist = dist + 50.0
						_want.append(k)
		if all_ready:
			for k2 in kids:
				_prefetch(k2)

func _set_shown(c: Chunk, on: bool) -> void:
	c.shown = on
	if on and not c.res_list.is_empty():
		for r in c.res_list:
			if not bool(r["done"]) and Game.collected_items.has(String(r["key"])):
				r["done"] = true
				(r["mm"] as MultiMesh).set_instance_transform(int(r["idx"]), Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), r["pos"]))
	if c.node != null:
		c.node.visible = on
	if c.body != null:
		c.body.collision_layer = 1 if on else 0
	if c.prop_body != null:
		c.prop_body.collision_layer = 2 if on else 0

func _dispatch() -> void:
	if _want.is_empty() or _jobs.size() >= MAX_INFLIGHT:
		return
	_want.sort_custom(func(a: Chunk, b: Chunk) -> bool: return a.dist < b.dist)
	for c in _want:
		if _jobs.size() >= MAX_INFLIGHT:
			break
		if c.state != 0:
			continue
		c.state = 1
		var want_coll: bool = enable_colliders and c.level >= gen.max_level
		var want_props: bool = enable_props and c.level >= gen.max_level - 2 and not _flora.is_empty()
		var job: Dictionary = {"key": c.key, "result": null}
		var id: int = WorkerThreadPool.add_task(_run_job.bind(job, c.face, c.level, c.ix, c.iy, want_coll, want_props), false, "chunk")
		job["id"] = id
		_jobs.append(job)

func _run_job(job: Dictionary, face: int, level: int, ix: int, iy: int, want_coll: bool, want_props: bool) -> void:
	job["result"] = gen.build_chunk(face, level, ix, iy, want_coll, want_props)

## Poll finished jobs; call every frame.
func process_jobs(budget_us: int = 3500) -> void:
	if _jobs.is_empty():
		return
	var start: int = Time.get_ticks_usec()
	var i: int = _jobs.size() - 1
	while i >= 0:
		var job: Dictionary = _jobs[i]
		if WorkerThreadPool.is_task_completed(job["id"]):
			WorkerThreadPool.wait_for_task_completion(job["id"])
			_jobs.remove_at(i)
			_finish(job)
			if Time.get_ticks_usec() - start > budget_us:
				break
		i -= 1

func _finish(job: Dictionary) -> void:
	var c: Chunk = chunks.get(job["key"])
	var d: Dictionary = job["result"]
	if c == null or d == null:
		return
	c.h_mid = (float(d["min_h"]) + float(d["max_h"])) * 0.5
	var node := Node3D.new()
	node.position = d["center"]
	node.visible = false
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = d["verts"]
	arrays[Mesh.ARRAY_NORMAL] = d["norms"]
	arrays[Mesh.ARRAY_COLOR] = d["cols"]
	arrays[Mesh.ARRAY_TEX_UV] = d["uvs"]
	arrays[Mesh.ARRAY_INDEX] = d["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	mi.layers = layer_mask
	mi.set_instance_shader_parameter("chunk_center", d["center"])
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows and c.level >= gen.max_level - 2) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	c.mesh_inst = mi
	if d.has("water"):
		var w: Dictionary = d["water"]
		var wa: Array = []
		wa.resize(Mesh.ARRAY_MAX)
		wa[Mesh.ARRAY_VERTEX] = w["verts"]
		wa[Mesh.ARRAY_NORMAL] = w["norms"]
		wa[Mesh.ARRAY_INDEX] = w["indices"]
		var wm := ArrayMesh.new()
		wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wa)
		var wi := MeshInstance3D.new()
		wi.mesh = wm
		wi.material_override = water_mat
		wi.layers = layer_mask
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wi.set_instance_shader_parameter("chunk_center", d["center"])
		node.add_child(wi)
		c.water_inst = wi
	if d.has("faces"):
		var sb := StaticBody3D.new()
		sb.collision_layer = 0
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(d["faces"])
		cs.shape = shape
		sb.add_child(cs)
		node.add_child(sb)
		c.body = sb
		c.has_collider = true
	if d.has("props"):
		_build_props(c, node, d)
	add_child(node)
	c.node = node
	c.state = 2
	stat_ready += 1
	# make newly built chunk visible right away if the quadtree already selected it
	if _vis_prev.has(c.key):
		_set_shown(c, true)

func _flora_mesh_for(e: int) -> Mesh:
	var m: Mesh = _flora_mesh[e]
	if m == null:
		var fl: Dictionary = _flora[e]
		m = Models.get_mesh(String(fl["model"]), _tints, String(fl.get("tint", "foliage")))
		_flora_mesh[e] = m
	return m

func _build_props(c: Chunk, node: Node3D, d: Dictionary) -> void:
	var plist: Array = d["props"]
	for pr in plist:
		var e: int = int(pr["entry"])
		var fl: Dictionary = _flora[e]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _flora_mesh_for(e)
		mm.instance_count = int(pr["count"])
		mm.buffer = pr["xf"]
		if fl.has("resource"):
			var xfa: PackedFloat32Array = pr["xf"]
			for ri in int(pr["count"]):
				var lp0 := Vector3(xfa[ri * 12 + 3], xfa[ri * 12 + 7], xfa[ri * 12 + 11])
				var wp0: Vector3 = node.position + lp0
				var key: String = "%d_%d_%d_%d" % [data.seed_i, roundi(wp0.x * 2.0), roundi(wp0.y * 2.0), roundi(wp0.z * 2.0)]
				var done0: bool = Game.collected_items.has(key)
				var rec: Dictionary = {"pos": lp0, "mm": mm, "idx": ri, "done": done0, "key": key, "kind": String(fl["resource"]), "label": String(fl.get("label", "Resource"))}
				if done0:
					mm.set_instance_transform(ri, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), lp0))
				c.res_list.append(rec)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.layers = layer_mask
		var msize: Vector3 = Models.model_size(String(fl["model"]))
		var big: float = maxf(msize.y, maxf(msize.x, msize.z))
		var vis: float = clampf(big * 70.0, 70.0, 520.0)
		if String(fl["model"]).contains("grass"):
			vis = 85.0
		mmi.visibility_range_end = vis
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (big > 2.5 and cast_shadows and c.level >= gen.max_level - 1) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
	var colls: Array = d.get("colls", [])
	if not colls.is_empty():
		var pb := StaticBody3D.new()
		pb.collision_layer = 0
		pb.collision_mask = 0
		for cd in colls:
			var lp: Vector3 = cd[0]
			var e2: int = int(cd[1])
			var sc: float = float(cd[2])
			var up: Vector3 = cd[3]
			var hint: Dictionary = Models.collision_hint(String(_flora[e2]["model"]))
			var shp: String = String(hint.get("shape", "none"))
			if shp == "none":
				continue
			var off: Array = hint.get("offset", [0, 0, 0])
			var cs := CollisionShape3D.new()
			match shp:
				"cylinder":
					var s := CylinderShape3D.new()
					s.radius = float(hint["radius"]) * sc
					s.height = float(hint["height"]) * sc
					cs.shape = s
				"sphere":
					var s2 := SphereShape3D.new()
					s2.radius = float(hint["radius"]) * sc
					cs.shape = s2
				"capsule":
					var s3 := CapsuleShape3D.new()
					s3.radius = float(hint["radius"]) * sc
					s3.height = float(hint["height"]) * sc
					cs.shape = s3
				"box":
					var sz: Array = hint["size"]
					var s4 := BoxShape3D.new()
					s4.size = Vector3(float(sz[0]), float(sz[1]), float(sz[2])) * sc
					cs.shape = s4
				_:
					continue
			var bas: Basis = U.basis_from_up(up)
			cs.transform = Transform3D(bas, lp + up * float(off[1]) * sc)
			pb.add_child(cs)
		node.add_child(pb)
		c.prop_body = pb

## Drops cached chunks that were not touched for `min_age` LOD updates. The default keeps a warm cache around the viewer;
## an inactive (far away) planet is trimmed hard so its mesh instances do not pile up across a long flight.
func _evict(min_age: int = 400) -> void:
	var removable: Array = []
	for k in chunks.keys():
		var c: Chunk = chunks[k]
		if (c.state == 2 or c.state == 0) and c.last_used < _frame - min_age and not c.shown:
			removable.append(c)
	removable.sort_custom(func(a: Chunk, b: Chunk) -> bool: return a.last_used < b.last_used)
	var n_remove: int = removable.size() if min_age < 400 else mini(removable.size(), chunks.size() - CHUNK_CAP + 40)
	for i in n_remove:
		var c: Chunk = removable[i]
		if c.node != null:
			c.node.queue_free()
		chunks.erase(c.key)

# ---------------------------------------------------------------------------------------------------------
func ground_height(dir: Vector3) -> float:
	return gen.height_exact(dir)

## true if the finest chunk below this direction has been built (colliders available)
func collider_ready_at(dir: Vector3) -> bool:
	var cn: Vector3 = dir
	var best: Chunk = null
	for c in _vis_prev.values():
		var cc: Chunk = c
		if cc.level == gen.max_level and cc.has_collider and cc.cdir.dot(cn) > cos(cc.size / gen.R * 0.8):
			best = cc
			break
	return best != null

## resource nodes (flora entries flagged with "resource") near a planet-local position
func find_resources(local_pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in _vis_prev.values():
		var ch: Chunk = c
		if ch.res_list.is_empty():
			continue
		if ch.node == null or ch.cdir.dot(local_pos.normalized()) < cos((radius + ch.size) / gen.R):
			continue
		for r in ch.res_list:
			if bool(r["done"]):
				continue
			var wp: Vector3 = ch.node.position + (r["pos"] as Vector3)
			if wp.distance_to(local_pos) < radius:
				out.append({"pos": wp, "label": String(r["label"]), "kind": "resource", "res": r})
	return out

## mark a resource record (from find_resources) as mined
func collect_resource(rec: Dictionary) -> void:
	rec["done"] = true
	Game.collected_items[String(rec["key"])] = true
	(rec["mm"] as MultiMesh).set_instance_transform(int(rec["idx"]), Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), rec["pos"]))

func pending_jobs() -> int:
	return _jobs.size()

func free_all() -> void:
	for j in _jobs:
		WorkerThreadPool.wait_for_task_completion(j["id"])
	_jobs.clear()

func _exit_tree() -> void:
	# quitting with chunk jobs in flight: let them finish before this node (and its generator) goes away
	free_all()
