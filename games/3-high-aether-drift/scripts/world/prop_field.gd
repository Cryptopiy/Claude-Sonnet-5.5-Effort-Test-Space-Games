class_name PropField
extends Node3D
## Streams flora / rocks / resources around the viewer on a cube-sphere cell grid (threaded placement, MultiMesh
## rendering), keeps simple circle colliders for the on-foot controller and builds the outpost + points of interest.

const CELL_M := 100.0
const LOAD_K := 3
const VIEW_END := 330.0
const MAX_JOBS := 3

var planet: PlanetBody
var data: PlanetData
var tp: TerrainParams
var n_cells: int = 80
var cell_size: float = 100.0
var cells: Dictionary = {}  # key -> Dictionary(nodes, colliders, res)
var _pending: Dictionary = {}
var _results: Array = []
var _mutex := Mutex.new()
var _jobs: int = 0
var collected: Dictionary = {}
var defs: Array = []
var _tint_cache: Dictionary = {}
var center_key: int = -1
var site_node: Node3D = null
var poi_nodes: Array = []
var site_res: Array = []  # {node, pos(local), kind}
var _sites_built: bool = false
var enabled: bool = true
var last_player_local: Vector3 = Vector3.ZERO
var _quit: bool = false
var _task_ids: Array = []


func setup(p: PlanetBody) -> void:
	planet = p
	data = p.data
	tp = data.terrain
	n_cells = maxi(int(ceil(data.radius * 1.5708 / CELL_M)), 8)
	cell_size = data.radius * 1.5708 / n_cells
	defs = data.props.duplicate()
	# every rocky planet has harvestable resources
	defs.append({"mesh": "resource_crystal", "dens": 0.00016, "s": [0.9, 1.5], "slope": 0.5, "col": 0.8, "shadow": false, "res": "crystal", "y": -0.05})
	defs.append({"mesh": "ore_node", "dens": 0.00011, "s": [0.9, 1.5], "slope": 0.5, "col": 1.1, "shadow": true, "res": "ore", "y": -0.2})


func _exit_tree() -> void:
	_quit = true
	for id in _task_ids:
		WorkerThreadPool.wait_for_task_completion(id)
	_task_ids.clear()


func _material_for(def: Dictionary) -> Material:
	var key: String = def["mesh"] + str(def.get("tint", ""))
	if _tint_cache.has(key):
		return _tint_cache[key]
	var mesh := Assets.mesh(def["mesh"])
	var mat: Material = null
	if mesh and mesh.get_surface_count() > 0:
		var base: Material = mesh.surface_get_material(0)
		if def.has("res") and base is BaseMaterial3D:
			var m := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
			var rc: Color = data.resource_color if def["res"] == "crystal" else data.resource_color.lerp(Color(1, 0.8, 0.3), 0.5)
			if def["res"] == "crystal":
				m.albedo_color = rc
				m.emission_enabled = true
				m.emission = rc
				m.emission_energy_multiplier = 2.2
			else:
				m.emission_enabled = true
				m.emission = rc
				m.emission_energy_multiplier = 2.0
			mat = m
		elif def.has("tint") and base is BaseMaterial3D:
			var m2 := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
			var c: Color = data.look.get(def["tint"], Color.WHITE)
			match def["tint"]:
				"rock":
					m2.albedo_color = Color(c.r * 1.0, c.g * 1.0, c.b * 1.0)
				"grass":
					m2.albedo_color = Color(c.r * 1.0, c.g * 1.0, c.b * 1.0)
				_:
					m2.albedo_color = c
			mat = m2
	_tint_cache[key] = mat
	return mat


# ------------------------------------------------------------------ cell addressing
func cell_key(face: int, i: int, j: int) -> int:
	return (face * n_cells + j) * n_cells + i


func _cell_of_dir(d: Vector3) -> Array:
	var f := TerrainParams.dir_to_face(d)
	var i := clampi(int(floorf((f[1] + 1.0) * 0.5 * n_cells)), 0, n_cells - 1)
	var j := clampi(int(floorf((f[2] + 1.0) * 0.5 * n_cells)), 0, n_cells - 1)
	return [f[0], i, j]


func update_field(player_local: Vector3, dt: float) -> void:
	if not enabled:
		return
	var alt := player_local.length() - data.radius
	if alt > 1500.0:
		_release_far(player_local)
		return
	last_player_local = player_local
	var d := player_local.normalized()
	var c := _cell_of_dir(d)
	var face: int = c[0]
	var ci: int = c[1]
	var cj: int = c[2]
	var a_c := -1.0 + (ci + 0.5) * 2.0 / n_cells
	var b_c := -1.0 + (cj + 0.5) * 2.0 / n_cells
	var wanted: Dictionary = {}
	var order: Array = []
	for dj in range(-LOAD_K, LOAD_K + 1):
		for di in range(-LOAD_K, LOAD_K + 1):
			var dd := TerrainParams.face_dir(face, a_c + di * 2.0 / n_cells, b_c + dj * 2.0 / n_cells)
			var cc := _cell_of_dir(dd)
			var key := cell_key(cc[0], cc[1], cc[2])
			if not wanted.has(key):
				wanted[key] = cc
				order.append([absf(di) + absf(dj), key, cc])
	order.sort_custom(func(x, y): return x[0] < y[0])
	for o in order:
		var key: int = o[1]
		if cells.has(key) or _pending.has(key):
			continue
		if _jobs >= MAX_JOBS:
			break
		_start_job(key, o[2])
	# unload far cells
	for key in cells.keys():
		if not wanted.has(key):
			var cdata: Dictionary = cells[key]
			var cd: Vector3 = cdata["center"]
			if cd.angle_to(d) * data.radius > cell_size * (LOAD_K + 2.5):
				_free_cell(key)
	_apply_results(2)
	_update_sites(player_local)


func _release_far(player_local: Vector3) -> void:
	_apply_results(1)
	if cells.size() > 0 and player_local.length() - data.radius > 3500.0:
		for key in cells.keys():
			_free_cell(key)
	if site_node and player_local.distance_to(site_node.position) > 9000.0:
		_clear_sites()


func _free_cell(key: int) -> void:
	var cdata: Dictionary = cells[key]
	for n in cdata["nodes"]:
		if is_instance_valid(n):
			n.queue_free()
	cells.erase(key)


func _start_job(key: int, cc: Array) -> void:
	_pending[key] = true
	_jobs += 1
	_task_ids.append(WorkerThreadPool.add_task(_gen_cell.bind(key, cc[0], cc[1], cc[2]), false, "cell"))


func _apply_results(max_n: int) -> void:
	var batch: Array = []
	_mutex.lock()
	while batch.size() < max_n and _results.size() > 0:
		batch.append(_results.pop_front())
	_mutex.unlock()
	for r in batch:
		var key: int = r["key"]
		_pending.erase(key)
		_jobs -= 1
		if cells.has(key):
			continue
		_build_cell(r)


# ------------------------------------------------------------------ worker thread: placement
func _gen_cell(key: int, face: int, ci: int, cj: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.seed) + "_" + str(key)) & 0x7fffffff
	var a0 := -1.0 + ci * 2.0 / n_cells
	var b0 := -1.0 + cj * 2.0 / n_cells
	var step := 2.0 / n_cells
	var center := TerrainParams.face_dir(face, a0 + step * 0.5, b0 + step * 0.5)
	var site_dist := center.distance_to(tp.site_dir) * data.radius
	var out := {"key": key, "center": center, "groups": []}
	var R := data.radius
	var sea := tp.sea_level
	var cl_f := R / 200.0
	for pi in defs.size():
		var def: Dictionary = defs[pi]
		if _quit:
			break
		var area := cell_size * cell_size
		var dens: float = def["dens"]
		var cl := TerrainParams.fbm(center.x * cl_f, center.y * cl_f, center.z * cl_f, tp.seed + pi * 13, 2)
		var dm := clampf(0.55 + 1.9 * cl, 0.05, 2.2)
		if def.has("res"):
			dm = 1.0
		var expected := dens * area * dm
		var cnt := int(expected)
		if rng.randf() < expected - cnt:
			cnt += 1
		if cnt <= 0:
			continue
		var smin: float = def["s"][0]
		var smax: float = def["s"][1]
		var slope_max: float = def["slope"]
		var yoff: float = def.get("y", 0.0)
		var alt_min: float = def["alt"][0] if def.has("alt") else 2.0
		var buf := PackedFloat32Array()
		var cols := PackedFloat32Array()
		var res_info: Array = []
		var count := 0
		for k in cnt:
			var u := rng.randf()
			var v := rng.randf()
			var yaw := rng.randf() * TAU
			var sc := rng.randf_range(smin, smax)
			var d := TerrainParams.face_dir(face, a0 + u * step, b0 + v * step)
			# keep clear of the outpost
			if site_dist < 150.0:
				var sdist := d.distance_to(tp.site_dir) * R
				if sdist < 85.0:
					continue
			var iid := key * 64 + pi * 8 + k
			if def.has("res") and collected.has(iid):
				continue
			var h := tp.height(d)
			if sea > -50000.0:
				if h < sea + alt_min:
					continue
			var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var d2 := (d + t1 * (2.0 / R)).normalized()
			var h2 := tp.height(d2)
			var sl := absf(h2 - h) / 2.0
			if sl > slope_max * 2.2:
				continue
			var up := d
			var tx := t1.rotated(up, yaw)
			var basis := Basis(tx * sc, up * sc, tx.cross(up) * sc)
			var pos := d * (R + h + yoff * sc)
			buf.append_array([basis.x.x, basis.y.x, basis.z.x, pos.x, basis.x.y, basis.y.y, basis.z.y, pos.y, basis.x.z, basis.y.z, basis.z.z, pos.z])
			if def["col"] > 0.0:
				cols.append_array([pos.x, pos.y, pos.z, def["col"] * sc])
			if def.has("res"):
				res_info.append([count, pos, iid])
			count += 1
		if count > 0:
			out["groups"].append({"pi": pi, "buf": buf, "cols": cols, "count": count, "res": res_info})
	_mutex.lock()
	_results.append(out)
	_mutex.unlock()


# ------------------------------------------------------------------ main thread: build nodes
func _build_cell(r: Dictionary) -> void:
	var nodes: Array = []
	var colliders := PackedFloat32Array()
	var resl: Array = []
	for g in r["groups"]:
		var def: Dictionary = defs[g["pi"]]
		var mesh := Assets.mesh(def["mesh"])
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = g["count"]
		mm.buffer = g["buf"]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := _material_for(def)
		if mat:
			mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if def["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = VIEW_END if def["mesh"] != "rock_arch" and def["mesh"] != "tree_broad" else VIEW_END * 1.5
		mmi.visibility_range_end_margin = 40.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.custom_aabb = AABB(r["center"] * data.radius - Vector3.ONE * cell_size * 1.2, Vector3.ONE * cell_size * 2.4)
		add_child(mmi)
		nodes.append(mmi)
		if g["cols"].size() > 0:
			colliders.append_array(g["cols"])
		for ri in g["res"]:
			resl.append({"mmi": mmi, "idx": ri[0], "pos": ri[1], "id": ri[2], "kind": def["res"]})
	cells[r["key"]] = {"nodes": nodes, "colliders": colliders, "res": resl, "center": r["center"]}


# ------------------------------------------------------------------ gameplay queries
## Push-out vector (planet-local) for a capsule/sphere at p with given radius; ignores the vertical axis.
func collide(p_local: Vector3, radius: float) -> Vector3:
	var push := Vector3.ZERO
	var up := p_local.normalized()
	for key in cells:
		var cdata: Dictionary = cells[key]
		var cen: Vector3 = cdata["center"] * data.radius
		if cen.distance_to(p_local) > cell_size * 1.3:
			continue
		var cols: PackedFloat32Array = cdata["colliders"]
		var n := cols.size() / 4
		for i in n:
			var c := Vector3(cols[i * 4], cols[i * 4 + 1], cols[i * 4 + 2])
			var rr := cols[i * 4 + 3] + radius
			var dv := p_local - c
			dv -= up * dv.dot(up)
			var dl := dv.length()
			if dl < rr and absf((p_local - c).dot(up)) < 12.0:
				push += dv / maxf(dl, 0.001) * (rr - dl)
	# structures
	if site_node and site_node.visible:
		var sp: Vector3 = site_node.position
		var dv2 := p_local - sp
		dv2 -= up * dv2.dot(up)
		# the habitat dome (centre of the outpost)
		var dl2 := dv2.length()
		if dl2 < 6.6 + radius and absf((p_local - sp).dot(up)) < 7.0:
			push += dv2 / maxf(dl2, 0.001) * (6.6 + radius - dl2)
	return push


func nearest_resource(origin_local: Vector3, dir_local: Vector3, max_dist: float, tol: float = 2.2) -> Dictionary:
	var best := {}
	var best_t := 1e9
	for key in cells:
		var cdata: Dictionary = cells[key]
		if (cdata["center"] * data.radius).distance_to(origin_local) > cell_size * 1.6 + max_dist:
			continue
		for r in cdata["res"]:
			if r["id"] < 0:
				continue
			var p: Vector3 = r["pos"]
			var t := (p - origin_local).dot(dir_local)
			if t < 0.0 or t > max_dist:
				continue
			var perp := (origin_local + dir_local * t).distance_to(p + (p.normalized()) * 0.6)
			if perp < tol and t < best_t:
				best_t = t
				best = r
	for sr in site_res:
		if sr["id"] < 0:
			continue
		var p2: Vector3 = sr["pos"]
		var t2 := (p2 - origin_local).dot(dir_local)
		if t2 < 0.0 or t2 > max_dist:
			continue
		var perp2 := (origin_local + dir_local * t2).distance_to(p2 + p2.normalized() * 0.6)
		if perp2 < tol and t2 < best_t:
			best_t = t2
			best = sr
	return best


func resources_near(p_local: Vector3, radius: float) -> Array:
	var out: Array = []
	for key in cells:
		var cdata: Dictionary = cells[key]
		if (cdata["center"] * data.radius).distance_to(p_local) > cell_size * 1.6 + radius:
			continue
		for r in cdata["res"]:
			if r["id"] >= 0 and (r["pos"] as Vector3).distance_to(p_local) < radius:
				out.append(r)
	for sr in site_res:
		if sr["id"] >= 0 and (sr["pos"] as Vector3).distance_to(p_local) < radius:
			out.append(sr)
	return out


func remove_resource(r: Dictionary) -> void:
	collected[r["id"]] = true
	if r.has("node"):
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
		r["id"] = -1
		return
	var mmi: MultiMeshInstance3D = r["mmi"]
	if is_instance_valid(mmi):
		var z := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), r["pos"])
		mmi.multimesh.set_instance_transform(r["idx"], z)
	r["id"] = -1


# ------------------------------------------------------------------ outpost + points of interest
func _surface_xf(d: Vector3, yaw: float, y_off: float = 0.0) -> Transform3D:
	var up := d
	var t := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized().rotated(up, yaw)
	var basis := Basis(t, up, t.cross(up))
	return Transform3D(basis, d * (data.radius + tp.ground(d) + y_off))


func _update_sites(player_local: Vector3) -> void:
	var site_pos := tp.site_dir * (data.radius + tp.site_h)
	var near := player_local.distance_to(site_pos) < 6000.0
	if near and site_node == null:
		_build_site()
	elif not near and site_node != null and player_local.distance_to(site_pos) > 9000.0:
		_clear_sites()
	if site_node:
		site_node.visible = true
	# points of interest (monolith / beacon / supply crates), always placed at fixed seeded directions
	if poi_nodes.is_empty() and near:
		for p in data.poi_dirs:
			var d: Vector3 = p["dir"]
			var h := tp.ground(d)
			if tp.sea_level > -50000.0 and h < tp.sea_level + 3.0:
				continue
			var node: Node3D
			match p["type"]:
				"monolith": node = Assets.instance("monolith")
				"beacon": node = Assets.instance("beacon")
				_: node = Assets.instance("crate")
			node.transform = _surface_xf(d, hash(str(d)) % 6, -0.6 if p["type"] == "monolith" else 0.0)
			add_child(node)
			node.set_meta("poi", p["type"])
			poi_nodes.append(node)
			if p["type"] == "supply":
				for k in 3:
					var c := Assets.instance("crate")
					var dd := (d + Vector3(sin(k * 2.1), cos(k * 1.7), sin(k * 3.3)) * (3.0 + k) / data.radius).normalized()
					c.transform = _surface_xf(dd, k * 1.3)
					add_child(c)
					poi_nodes.append(c)


func _build_site() -> void:
	site_node = Node3D.new()
	site_node.name = "Outpost"
	var d := tp.site_dir
	site_node.transform = Transform3D(_surface_xf(d, 0.0).basis, d * (data.radius + tp.site_h))
	add_child(site_node)
	var pad := Assets.instance("landing_pad")
	pad.position = Vector3(0, 0.0, -34.0)
	site_node.add_child(pad)
	var outpost := Assets.instance("outpost")
	outpost.position = Vector3(0, 0.0, 6.0)
	site_node.add_child(outpost)
	for k in 5:
		var cr := Assets.instance("crate")
		cr.position = Vector3(-13.0 + k * 1.9, 0.0, 16.0 - (k % 2) * 1.5)
		cr.rotation.y = k * 0.7
		site_node.add_child(cr)
	var sol := Assets.instance("solar_array")
	sol.position = Vector3(20, 0, 6)
	sol.rotation.y = 0.5
	site_node.add_child(sol)
	# a few harvestable crystals/ore near the pad so a fresh landing always has something to do
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed
	var cmat := _material_for({"mesh": "resource_crystal", "res": "crystal"})
	var omat := _material_for({"mesh": "ore_node", "res": "ore"})
	for k in 8:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(32.0, 75.0)
		var off := Vector3(cos(ang), 0, sin(ang)) * dist
		var wp := site_node.transform * off
		var dd := wp.normalized()
		var is_cr := k % 3 != 2
		var nd := Assets.instance("resource_crystal" if is_cr else "ore_node")
		var xf := _surface_xf(dd, rng.randf() * TAU, 0.0)
		nd.transform = xf
		nd.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
		for mi in Assets.all_meshes(nd):
			(mi as MeshInstance3D).material_override = cmat if is_cr else omat
		add_child(nd)
		var iid := 900000 + k
		if collected.has(iid):
			nd.queue_free()
			continue
		site_res.append({"node": nd, "pos": xf.origin, "id": iid, "kind": "crystal" if is_cr else "ore"})


func _clear_sites() -> void:
	if site_node:
		site_node.queue_free()
		site_node = null
	for n in poi_nodes:
		if is_instance_valid(n):
			n.queue_free()
	poi_nodes.clear()
	for sr in site_res:
		if is_instance_valid(sr["node"]):
			sr["node"].queue_free()
	site_res.clear()


func pad_transform_local() -> Transform3D:
	## Where the ship should be parked at the landing pad (planet-local)
	var d := tp.site_dir
	var xf := _surface_xf(d, 0.0)
	var base := Transform3D(xf.basis, d * (data.radius + tp.site_h))
	return base * Transform3D(Basis.IDENTITY, Vector3(0, 0.35, -34.0))
