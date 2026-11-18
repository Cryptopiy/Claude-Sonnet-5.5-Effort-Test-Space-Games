class_name ScatterManager
extends Node3D
## FLORA / ROCK / RESOURCE / POI scattering for ONE planet (module M7a). Created by Planet (M1): `var s := ScatterManager.new(); s.setup(planet, def); planet.add_child(s)`.
##
## * Deterministic cell-based scatter around the viewer: cells live on a cube-sphere grid (ScatterGrid), three layers (detail 32 m / mid 80 m / far 200 m cells).
##   Every cell is built on a worker thread (ScatterBuilder) from (def.seed, layer, cell key) -> same planet, same world, every visit.
##   Instances are placed on planet.terrain_radius_at(dir), aligned to planet.normal_at(dir), never underwater, never on POI footprints.
##   Each (cell, species) is ONE MultiMeshInstance3D of the Blender model (ModelLib.merged_mesh, per-planet tinted), thinned with distance.
## * Simple colliders (StaticBody3D, layer 2) only for instances within ~60 m of the focus. Resource nodes (ResourceNode, group "resource_node", layer 3)
##   within ~650 m. POIs (PoiSites) are instantiated as PoiStructure nodes (colliders + interactables + behaviours) when the focus gets near.
## * Only active while the frame is anchored on this planet and the focus is within ~2.5 km of the ground (otherwise nothing exists: zero cost).
##
## Public API: setup(planet, def), stats() -> Dictionary, get_scan_targets(p, radius) -> Array, revealed_markers() -> Array, poi_node(index) -> Node3D

const TICK := 0.2
const MAX_INFLIGHT := 3
const BUILD_BUDGET_US := 2200
const COLLIDER_RANGE := 60.0
const MAX_BODIES := 320
const RES_RANGE := 400.0
const RES_CELLS_PER_FRAME := 2
const ENUM_STEP: Array = [6.0, 14.0, 45.0]
const FREE_PER_FRAME := 10
const INACTIVE_FREE_AFTER := 4.0
const MAX_ALT := 2600.0
const SHADOW_RANGE := 210.0       # cells nearer than this (to their nearest edge) cast shadows

class Cell extends RefCounted:
	var layer: int = 0
	var key: int = 0
	var cancelled: bool = false
	var state: int = 0            # 0 queued, 1 building, 2 ready
	var origin: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.UP
	var prio: float = 0.0
	var groups: Array = []        # [{mmi, mm, n, id, xf, thin, far_beyond, vrange, col}]
	var nodes: Array = []         # ResourceNode (resource cells)
	var specs: Array = []

var planet: Node3D
var def: BodyDef

var _builder: ScatterBuilder
var _species: Array = []
var _palette: Dictionary = {}
var _variant_name: String = ""
var _noises: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _cells: Array = [{}, {}, {}]
var _res_cells: Dictionary = {}
var _pending: Array = []
var _inflight := 0
var _task_ids: Array = []
var _threads: Array[Thread] = []       # dedicated builder threads: the global WorkerThreadPool is saturated by terrain jobs right after a spawn
var _job_sem := Semaphore.new()
var _jobs: Array = []
var _quit := false
var _done: Array = []
var _mutex := Mutex.new()
var _free_queue: Array = []
var _res_spawn: Array = []
var _last_enum: Array = [Vector3(1e9, 0, 0), Vector3(1e9, 0, 0), Vector3(1e9, 0, 0), Vector3(1e9, 0, 0)]
var _center_cache: Array = [{}, {}, {}]
var _tick_acc := 0.0
var _active := false
var _inactive_time := 0.0
var _focus_p := Vector3.ZERO
var _alt := 0.0
var _have_focus := false
var _bodies: Dictionary = {}
var _body_root: Node3D
var _shape_cache: Dictionary = {}
var _collider_last := Vector3(1e9, 0, 0)
var _poi_nodes: Dictionary = {}       # poi index -> PoiStructure
var _poi_pos: Dictionary = {}         # poi index -> Vector3 (ground position, planet space)
var _markers: Dictionary = {}         # poi index -> PoiMarker
var _pois: Array = []
var _discovered: Dictionary = {}
var _prewarm: Array = []
var _ramping: Array = []
var _stat_built := 0
var _stat_build_ms := 0.0
var _force_enum := true
var _ready_done := false

func setup(p_planet: Node3D, p_def: BodyDef) -> void:
	planet = p_planet
	def = p_def

func _ready() -> void:
	name = "ScatterManager"
	if def == null or not def.landable:
		set_process(false)
		return
	_pois = PoiSites.for_body(def)
	_init_tables()
	_body_root = Node3D.new()
	_body_root.name = "Colliders"
	add_child(_body_root)
	_ensure_threads()
	if not Events.game_started.is_connected(_on_game_started):
		Events.game_started.connect(_on_game_started)
	_ready_done = true

func _on_game_started() -> void:
	PoiSites.clear_revealed()

func _exit_tree() -> void:
	for c in _all_cells():
		c.cancelled = true
	_quit = true
	for t in _threads:
		_job_sem.post()
	for t in _threads:
		t.wait_to_finish()
	_threads.clear()
	for t in _task_ids:
		WorkerThreadPool.wait_for_task_completion(t)
	_task_ids.clear()

# =====================================================================================================================
# per-planet tables
# =====================================================================================================================
func _init_tables() -> void:
	var prof := FloraTables.profile(def.biome)
	var ps := def.palette_seed
	var variants: Array = prof["variants"]
	var palettes: Array = prof["palettes"]
	var vi := int(absi(SeedUtil.hash2(ps, 17))) % variants.size()
	var pi := int(absi(SeedUtil.hash2(ps, 29))) % palettes.size()
	# the planet the game starts on is the hero of the first impression: the natural (unshifted) palette and a variant with proper vegetation
	var is_start: bool = Universe.system != null and Universe.system.start_body == def.index and Universe.system.bodies.size() > def.index and Universe.system.bodies[def.index].seed == def.seed
	if is_start:
		pi = 0
		for k in variants.size():
			if bool((variants[k] as Dictionary).get("hero", false)):
				vi = k
				break
	var mult: Dictionary = variants[vi]["mult"]
	_variant_name = String(variants[vi]["name"])
	var pal: Dictionary = palettes[pi].duplicate(true)
	# small continuous hue jitter so no two planets share exactly the same greens
	var jit := (SeedUtil.rand01(ps, 41) - 0.5) * 0.05
	for k in ["leaf", "glow"]:
		var a: Array = pal[k]
		a[0] = float(a[0]) + jit
	_palette = pal
	var layer_lists: Array = [[], [], []]
	var all_ids: Dictionary = {}
	for e in prof["species"]:
		var id: String = e["id"]
		all_ids[id] = true
		var sp: Dictionary = (e as Dictionary).duplicate(true)
		var g: String = sp["g"]
		var rnd := SeedUtil.rand01(ps, SeedUtil.hash2(id.hash(), int(sp["layer"])))
		var d_eff := float(sp["d"]) * float(mult.get(g, 1.0)) * lerpf(0.6, 1.5, rnd)
		sp["d_eff"] = d_eff
		sp["foot_m"] = ScatterModels.hextent(id) * 0.8
		var mf := ModelLib.manifest(id)
		var tris := float(mf.get("tris", 1500))
		if tris > 3500.0:
			sp["d_eff"] = float(sp["d_eff"]) * clampf(pow(3500.0 / tris, 0.6), 0.45, 1.0)
			if not sp.has("thin"):
				sp["thin"] = 0.1
		if not sp.has("range"):
			var lr: float = FloraTables.LAYERS[int(sp["layer"])]["range"]
			sp["range"] = clampf(ScatterModels.height_of(id) * 70.0, 110.0, lr)
		if g in ["bush", "flower", "rock", "ground"] and int(sp["layer"]) < 2:
			sp["start_boost"] = 1.1
		# a bit of per-planet size variation for the big things
		if g in ["tree", "special"]:
			var sz := lerpf(0.88, 1.2, SeedUtil.rand01(ps, 53))
			sp["s"] = [float(sp["s"][0]) * sz, float(sp["s"][1]) * sz]
		layer_lists[int(sp["layer"])].append(sp)
	_species = layer_lists
	ScatterModels.prime(all_ids.keys())
	ScatterModels.prime(["res_ore_ferrite", "res_fuel_crystal", "res_bulb_plant", "res_warp_crystal"])
	for p in _pois:
		ScatterModels.prime([String(p.get("model", ""))] if String(p.get("model", "")) != "" else [])
	# noise fields (read-only after this point -> safe to share with workers)
	var sd := def.seed
	_noises = {
		"big": _make_noise(sd + 11, 1.0 / 650.0, 3),
		"mid": _make_noise(sd + 23, 1.0 / 150.0, 3),
		"fine": _make_noise(sd + 37, 1.0 / 32.0, 2),
	}
	_builder = ScatterBuilder.new()
	_builder.setup(planet, def, _species, _noises, _pois)
	_builder.res_rate = 0.2
	_prewarm = []
	for ll in 3:
		for sp2 in layer_lists[ll]:
			_prewarm.append([String(sp2["id"]), float(sp2["range"])])

func _make_noise(sd: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sd
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n

## planet-tinted mesh of `id` whose materials fade out towards `vr` metres (one material set per (model, range))
func _mesh_for(id: String, vr: float = 0.0) -> ArrayMesh:
	var mk := "%s|%d" % [id, int(vr)]
	if _mesh_cache.has(mk):
		return _mesh_cache[mk]
	var m := ScatterModels.tinted_mesh(id, _palette, vr)
	_mesh_cache[mk] = m
	if m != null:
		var t := ScatterModels.request_lods(id, ModelLib.merged_mesh(id))
		if t >= 0:
			_task_ids.append(t)
	return m

## decimated mesh of `id` for LOD level 1/2 (null while the background decimation is not finished, or when the model is too small to have one)
func _lod_mesh_for(id: String, level: int, vr: float = 0.0) -> ArrayMesh:
	var key := "%s|%d|L%d" % [id, int(vr), level]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	if not ScatterModels.lods_ready(id):
		return null
	var base := _mesh_for(id, vr)
	var m: ArrayMesh = null
	if base != null:
		m = ScatterModels.lod_variant(base, id, level)
	_mesh_cache[key] = m
	return m

# =====================================================================================================================
# main loop
# =====================================================================================================================
func _all_cells() -> Array:
	var out: Array = []
	for l in 3:
		out.append_array((_cells[l] as Dictionary).values())
	out.append_array(_res_cells.values())
	return out

func _process(dt: float) -> void:
	if not _ready_done:
		return
	_update_focus()
	_drain_results()
	_free_some()
	_spawn_resource_nodes()
	_launch_workers()
	if not _ramping.is_empty():
		_step_ramps(dt)
	_tick_acc += dt
	if _tick_acc >= TICK:
		_tick_acc = 0.0
		_tick()
	if not _prewarm.is_empty() and _active:
		var pe: Array = _prewarm.pop_back()
		_mesh_for(String(pe[0]), float(pe[1]))

func _update_focus() -> void:
	_have_focus = false
	var f := Frame.focus
	if f == null or not is_instance_valid(f) or not f.is_inside_tree() or planet == null or not planet.is_inside_tree():
		return
	if Frame.anchor != def.index:
		return
	_focus_p = planet.to_local(f.global_position)
	var fd := _focus_p.normalized()
	_alt = _focus_p.length() - planet.call("terrain_radius_at", fd)
	_have_focus = true

func _tick() -> void:
	var was_active := _active
	_active = _have_focus and _alt < MAX_ALT
	if not _active:
		_inactive_time += TICK
		if _inactive_time > INACTIVE_FREE_AFTER and (was_active or _has_anything()):
			_unload_all()
		return
	_inactive_time = 0.0
	if not was_active:
		_force_enum = true
	var fp := _focus_p
	for layer in 3:
		var moved := fp.distance_to(_last_enum[layer])
		if _force_enum or moved > float(ENUM_STEP[layer]):
			_last_enum[layer] = fp
			_enumerate_layer(layer, fp)
	if _force_enum or fp.distance_to(_last_enum[3]) > 25.0:
		_last_enum[3] = fp
		_enumerate_resources(fp)
	_force_enum = false
	_update_visibility(fp)
	_update_colliders(fp)
	_update_pois(fp)

func _has_anything() -> bool:
	return not _all_cells().is_empty() or not _poi_nodes.is_empty() or not _bodies.is_empty() or not _markers.is_empty()

func _unload_all() -> void:
	for c in _all_cells():
		_release_cell(c)
	for l in 3:
		(_cells[l] as Dictionary).clear()
	_res_cells.clear()
	_pending.clear()
	_res_spawn.clear()
	for k in _bodies.keys():
		var b: Node = _bodies[k]
		if is_instance_valid(b):
			b.queue_free()
	_bodies.clear()
	for k in _poi_nodes.keys():
		var n: Node = _poi_nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_poi_nodes.clear()
	for k in _markers.keys():
		var m: Node = _markers[k]
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	for l in 3:
		_last_enum[l] = Vector3(1e9, 0, 0)
	_last_enum[3] = Vector3(1e9, 0, 0)
	_collider_last = Vector3(1e9, 0, 0)

# =====================================================================================================================
# cell enumeration
# =====================================================================================================================
func _center_of(grid_layer: int, key: int) -> Vector3:
	var cache: Dictionary = _center_cache[grid_layer]
	var c: Variant = cache.get(key)
	if c != null:
		return c
	var n: int = _builder.n_cells[grid_layer]
	var v := ScatterGrid.center_dir(ScatterGrid.key_face(key, n), ScatterGrid.key_i(key, n), ScatterGrid.key_j(key, n), n)
	cache[key] = v
	return v

## returns key -> distance (m, 3D, focus to the cell centre on the ground) of every cell of grid `grid_layer` that could be within range_m (+ half a cell)
func _enumerate(grid_layer: int, range_m: float, fp: Vector3) -> Dictionary:
	var out: Dictionary = {}
	var L: Dictionary = FloraTables.LAYERS[grid_layer]
	var cell: float = L["cell"]
	var n: int = _builder.n_cells[grid_layer]
	var R := def.radius
	var alt := maxf(_alt, 0.0)
	var hr2 := range_m * range_m - alt * alt
	if hr2 <= 0.0:
		return out
	var hr := sqrt(hr2) + cell * 0.75
	var fdir := fp.normalized()
	var c := ScatterGrid.dir_to_cell(fdir, n)
	var kk := int(ceil(hr / (cell * 0.78))) + 1
	var lim := (hr + cell) * (hr + cell)
	var cell2 := cell * cell * 0.5
	var edge: Array = []
	for dj in range(-kk, kk + 1):
		for di in range(-kk, kk + 1):
			if float(di * di + dj * dj) * cell2 > lim:
				continue
			var ii := c.y + di
			var jj := c.z + dj
			if ii < 0 or ii >= n or jj < 0 or jj >= n:
				edge.append(Vector2i(ii, jj))
				continue
			var key := ScatterGrid.make_key(c.x, ii, jj, n)
			var cd := _center_of(grid_layer, key)
			var gd := acos(clampf(fdir.dot(cd), -1.0, 1.0)) * R
			var d3 := sqrt(gd * gd + alt * alt)
			if d3 - cell * 0.72 < range_m:
				out[key] = d3
	# cells across a cube-face seam: sample the extended face plane at half-cell steps and map the points back to real cells
	for e in edge:
		for sy in 2:
			for sx in 2:
				var a := (float(e.x) + 0.25 + 0.5 * float(sx)) / float(n) * 2.0 - 1.0
				var b := (float(e.y) + 0.25 + 0.5 * float(sy)) / float(n) * 2.0 - 1.0
				if absf(a) > 1.9 or absf(b) > 1.9:
					continue
				var u := tan(a * PI * 0.25)
				var v := tan(b * PI * 0.25)
				var d := (ScatterGrid.FACE_N[c.x] + ScatterGrid.FACE_U[c.x] * u + ScatterGrid.FACE_V[c.x] * v).normalized()
				var cc := ScatterGrid.dir_to_cell(d, n)
				var key2 := ScatterGrid.make_key(cc.x, cc.y, cc.z, n)
				if out.has(key2):
					continue
				var cd2 := _center_of(grid_layer, key2)
				var gd2 := acos(clampf(fdir.dot(cd2), -1.0, 1.0)) * R
				var d32 := sqrt(gd2 * gd2 + alt * alt)
				if d32 - cell * 0.72 < range_m:
					out[key2] = d32
	return out

func _enumerate_layer(layer: int, fp: Vector3) -> void:
	var L: Dictionary = FloraTables.LAYERS[layer]
	if (_species[layer] as Array).is_empty():
		return
	var range_load: float = L["range"]
	var keep := _enumerate(layer, range_load + float(L["cell"]) * 0.6 + 35.0, fp)
	var cells: Dictionary = _cells[layer]
	for key in keep:
		var d: float = keep[key]
		if cells.has(key):
			(cells[key] as Cell).prio = d
			continue
		if d - float(L["cell"]) * 0.72 >= range_load:
			continue
		var c := Cell.new()
		c.layer = layer
		c.key = key
		c.prio = d
		cells[key] = c
		_pending.append(c)
	for key in cells.keys():
		if not keep.has(key):
			_release_cell(cells[key])
			cells.erase(key)

func _enumerate_resources(fp: Vector3) -> void:
	var keep := _enumerate(_builder.res_layer, RES_RANGE + 60.0, fp)
	for key in keep:
		var d: float = keep[key]
		if _res_cells.has(key):
			(_res_cells[key] as Cell).prio = d
			continue
		if d - 58.0 >= RES_RANGE:
			continue
		var c := Cell.new()
		c.layer = 9
		c.key = key
		c.prio = d
		_res_cells[key] = c
		_pending.append(c)
	for key in _res_cells.keys():
		if not keep.has(key):
			_release_cell(_res_cells[key])
			_res_cells.erase(key)

func _release_cell(c: Cell) -> void:
	c.cancelled = true
	_free_queue.append(c)

func _free_some() -> void:
	var n := 0
	while n < FREE_PER_FRAME and not _free_queue.is_empty():
		var c: Cell = _free_queue.pop_back()
		for g in c.groups:
			var mmi: Node = g["mmi"]
			if is_instance_valid(mmi):
				mmi.queue_free()
		c.groups.clear()
		for nd in c.nodes:
			if is_instance_valid(nd):
				(nd as Node).queue_free()
		c.nodes.clear()
		n += 1

# =====================================================================================================================
# worker threads
# =====================================================================================================================
func _ensure_threads() -> void:
	if not _threads.is_empty():
		return
	_quit = false
	for i in 2:
		var th := Thread.new()
		th.start(_thread_loop)
		_threads.append(th)

func _launch_workers() -> void:
	if _pending.is_empty() or _inflight >= MAX_INFLIGHT:
		return
	_ensure_threads()
	_pending.sort_custom(func(a: Cell, b: Cell) -> bool: return a.prio < b.prio)
	while _inflight < MAX_INFLIGHT and not _pending.is_empty():
		var c: Cell = _pending.pop_front()
		if c.cancelled:
			continue
		c.state = 1
		_inflight += 1
		_mutex.lock()
		_jobs.append(c)
		_mutex.unlock()
		_job_sem.post()

func _thread_loop() -> void:
	while true:
		_job_sem.wait()
		if _quit:
			return
		_mutex.lock()
		var job: Cell = null
		if not _jobs.is_empty():
			job = _jobs.pop_front()
		_mutex.unlock()
		if job != null:
			_worker(job)

func _worker(c: Cell) -> void:
	var res: Dictionary = {}
	var t0 := Time.get_ticks_usec()
	if not c.cancelled:
		if c.layer == 9:
			res = _builder.build_resources(c.key, c)
		else:
			res = _builder.build_cell(c.layer, c.key, c)
	res["cell"] = c
	res["ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	_mutex.lock()
	_done.append(res)
	_mutex.unlock()

func _drain_results() -> void:
	var t0 := Time.get_ticks_usec()
	while true:
		_mutex.lock()
		var res: Dictionary = {}
		var have := false
		if not _done.is_empty():
			res = _done.pop_front()
			have = true
		_mutex.unlock()
		if not have:
			break
		_inflight = maxi(_inflight - 1, 0)
		var c: Cell = res["cell"]
		if not c.cancelled and (res.has("groups") or res.has("nodes")):
			_stat_built += 1
			_stat_build_ms += float(res["ms"])
			if c.layer == 9:
				_finish_res_cell(c, res)
			else:
				_finish_cell(c, res)
		if Time.get_ticks_usec() - t0 > BUILD_BUDGET_US:
			break
	# forget finished tasks
	if _task_ids.size() > 12:
		var keep: Array = []
		for t in _task_ids:
			if WorkerThreadPool.is_task_completed(t):
				WorkerThreadPool.wait_for_task_completion(t)
			else:
				keep.append(t)
		_task_ids = keep

func _finish_cell(c: Cell, res: Dictionary) -> void:
	c.state = 2
	c.origin = res["origin"]
	c.dir = res["dir"]
	var L: Dictionary = FloraTables.LAYERS[c.layer]
	for g in res["groups"]:
		var sp: Dictionary = (_species[c.layer] as Array)[int(g["sp"])]
		var vr_g: float = float(sp.get("range", L["range"]))
		var mesh := _mesh_for(String(g["id"]), vr_g)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = int(g["n"])
		mm.buffer = g["xf"]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = c.origin
		mmi.custom_aabb = g["aabb"]
		var casts: bool = bool(sp.get("shadow", true)) and c.layer == 1
		var near_c := _focus_p.distance_to(c.origin) - float(L["cell"]) * 0.72 < SHADOW_RANGE
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (casts and near_c) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		var spec := ScatterModels.collider_spec(String(g["id"]))
		var thin_default: float = 0.35 if c.layer == 1 else (0.5 if c.layer == 2 else 0.3)
		c.groups.append({
			"mmi": mmi, "mm": mm, "n": int(g["n"]), "id": String(g["id"]), "xf": g["xf"],
			"thin": float(sp.get("thin", thin_default)),
			"far_beyond": float(sp.get("far_beyond", 0.0)),
			"vrange": float(sp.get("range", L["range"])),
			"col": String(spec["shape"]) != "none" and String(spec["shape"]) != "",
			"vis": true,
			"ramp": 0.0,
			"lod": 0,
			"l1": clampf(ScatterModels.height_of(String(g["id"])) * 14.0, 45.0, 190.0),
			"l2": clampf(ScatterModels.height_of(String(g["id"])) * 40.0, 130.0, 480.0),
			"can_shadow": casts,
			"sh_on": casts and near_c,
		})
	_ramping.append(c)
	_apply_visibility(c, _focus_p)

func _finish_res_cell(c: Cell, res: Dictionary) -> void:
	c.state = 2
	c.specs = res["nodes"]
	for s in c.specs:
		if Game.depleted_nodes.has(String(s["id"])):
			continue
		_res_spawn.append([c, s])

func _spawn_resource_nodes() -> void:
	var n := 0
	while n < RES_CELLS_PER_FRAME and not _res_spawn.is_empty():
		var e: Array = _res_spawn.pop_front()
		var c: Cell = e[0]
		if c.cancelled:
			continue
		var s: Dictionary = e[1]
		var rn := ResourceNode.new()
		rn.setup(String(s["res"]), String(s["id"]), int(s["seed"]), float(s["scale"]))
		var up: Vector3 = s["up"]
		var ref := Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.UP
		var t1 := up.cross(ref).normalized()
		var t2 := up.cross(t1)
		var yaw: float = s["yaw"]
		var zv := t1 * cos(yaw) + t2 * sin(yaw)
		var xv := up.cross(zv)
		rn.transform = Transform3D(Basis(xv, up, zv), (s["pos"] as Vector3) - up * 0.05)
		add_child(rn)
		c.nodes.append(rn)
		n += 1

# =====================================================================================================================
# visibility / LOD thinning
# =====================================================================================================================
func _update_visibility(fp: Vector3) -> void:
	for l in 3:
		for c in (_cells[l] as Dictionary).values():
			if (c as Cell).state == 2:
				_apply_visibility(c, fp)
	var rr := _res_cells
	for c in rr.values():
		var cc: Cell = c
		for nd in cc.nodes:
			if is_instance_valid(nd):
				(nd as ResourceNode).set_near(fp.distance_squared_to((nd as Node3D).position) < 2025.0)

func _step_ramps(dt: float) -> void:
	var keep: Array = []
	for c in _ramping:
		var cc: Cell = c
		if cc.cancelled:
			continue
		var done := true
		for g in cc.groups:
			var r: float = minf(float(g["ramp"]) + dt / 0.9, 1.0)
			g["ramp"] = r
			if r < 1.0:
				done = false
		_apply_visibility(cc, _focus_p)
		if not done:
			keep.append(cc)
	_ramping = keep

func _apply_visibility(c: Cell, fp: Vector3) -> void:
	var d := fp.distance_to(c.origin)
	var L: Dictionary = FloraTables.LAYERS[c.layer]
	var half := float(L["cell"]) * 0.72
	for g in c.groups:
		var vr: float = g["vrange"]
		var far_beyond: float = g["far_beyond"]
		var mmi: MultiMeshInstance3D = g["mmi"]
		if not is_instance_valid(mmi):
			continue
		var vis := (d - half) < vr and (far_beyond <= 0.0 or (d + half) > far_beyond)
		if vis != bool(g["vis"]):
			g["vis"] = vis
			mmi.visible = vis
		if not vis:
			continue
		# density thinning with distance; the last 20 % of the range fades to nothing so nothing pops out at the visibility limit
		var t := clampf((d - vr * 0.22) / (vr * 0.78), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var frac := lerpf(1.0, float(g["thin"]), t)
		var te := clampf((d - vr * 0.8) / (vr * 0.2), 0.0, 1.0)
		frac *= 1.0 - te * te * (3.0 - 2.0 * te)
		var ramp: float = g["ramp"]
		var cnt := clampi(int(ceil(float(g["n"]) * frac * ramp)), 0, int(g["n"]))
		if frac > 0.05 and ramp >= 1.0:
			cnt = maxi(cnt, 1)
		var mm: MultiMesh = g["mm"]
		if mm.visible_instance_count != cnt:
			mm.visible_instance_count = cnt
		# shadows only for nearby cells (the far shadow splits would render every tree again for nothing)
		if bool(g["can_shadow"]):
			var sh_on: bool = g["sh_on"]
			var near_sh := (d - half) < (SHADOW_RANGE + (22.0 if sh_on else 0.0))
			if near_sh != sh_on:
				g["sh_on"] = near_sh
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near_sh else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# mesh LOD by the distance of the cell centre (with hysteresis)
		var lod: int = g["lod"]
		var l1: float = g["l1"]
		var l2: float = g["l2"]
		var want := lod
		if lod == 0:
			if d > l1 + 8.0:
				want = 1
		elif lod == 1:
			if d < l1 - 8.0:
				want = 0
			elif d > l2 + 10.0:
				want = 2
		elif d < l2 - 10.0:
			want = 1
		if want != lod:
			var gid := String(g["id"])
			var lm: ArrayMesh = _lod_mesh_for(gid, want, vr) if want > 0 else _mesh_for(gid, vr)
			if lm != null:
				mm.mesh = lm
				g["lod"] = want
			elif want > 0 and ScatterModels.lods_ready(gid):
				g["lod"] = want	  # nothing to decimate for this model: stop asking

# =====================================================================================================================
# colliders
# =====================================================================================================================
func _update_colliders(fp: Vector3) -> void:
	if fp.distance_to(_collider_last) < 2.5 and not _bodies.is_empty():
		return
	_collider_last = fp
	var want: Dictionary = {}
	var r2 := COLLIDER_RANGE * COLLIDER_RANGE
	var keep2 := (COLLIDER_RANGE + 22.0) * (COLLIDER_RANGE + 22.0)
	for l in 3:
		var half: float = float(FloraTables.LAYERS[l]["cell"]) * 0.75 + COLLIDER_RANGE + 25.0
		for c in (_cells[l] as Dictionary).values():
			var cell: Cell = c
			if cell.state != 2 or cell.origin.distance_to(fp) > half:
				continue
			var gi := 0
			for g in cell.groups:
				if bool(g["col"]) and bool(g["vis"]):
					var xf: PackedFloat32Array = g["xf"]
					var n: int = g["n"]
					for i in n:
						var o := i * 16
						var pos := Vector3(xf[o + 3], xf[o + 7], xf[o + 11]) + cell.origin
						var d2 := pos.distance_squared_to(fp)
						if d2 < keep2:
							var bkey := "%d:%d:%d:%d" % [l, cell.key, gi, i]
							want[bkey] = [cell, g, i, d2 < r2]
				gi += 1
	# drop bodies that left the keep radius
	for k in _bodies.keys():
		if not want.has(k):
			var b: Node = _bodies[k]
			if is_instance_valid(b):
				b.queue_free()
			_bodies.erase(k)
	var created := 0
	for k in want:
		if _bodies.has(k) or not bool(want[k][3]):
			continue
		if _bodies.size() >= MAX_BODIES or created >= 40:
			break
		var e: Array = want[k]
		var cell2: Cell = e[0]
		var g2: Dictionary = e[1]
		var i2: int = e[2]
		var xf2: PackedFloat32Array = g2["xf"]
		var o2 := i2 * 16
		var bx := Vector3(xf2[o2 + 0], xf2[o2 + 4], xf2[o2 + 8])
		var by := Vector3(xf2[o2 + 1], xf2[o2 + 5], xf2[o2 + 9])
		var bz := Vector3(xf2[o2 + 2], xf2[o2 + 6], xf2[o2 + 10])
		var sc := by.length()
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.transform = Transform3D(Basis(bx / sc, by / sc, bz / sc), Vector3(xf2[o2 + 3], xf2[o2 + 7], xf2[o2 + 11]) + cell2.origin)
		ScatterModels.add_shapes(body, String(g2["id"]), sc, _shape_cache)
		_body_root.add_child(body)
		_bodies[k] = body
		created += 1

# =====================================================================================================================
# points of interest
# =====================================================================================================================
func _ground_pos(i: int) -> Vector3:
	if _poi_pos.has(i):
		return _poi_pos[i]
	var d: Vector3 = _pois[i]["dir"]
	var p := d * float(planet.call("terrain_radius_at", d))
	_poi_pos[i] = p
	return p

func _update_pois(fp: Vector3) -> void:
	var poi_range := clampf(900.0 + 4.0 * maxf(_alt, 0.0), 900.0, 5200.0)
	var made := 0
	for i in _pois.size():
		var p: Dictionary = _pois[i]
		var gp := _ground_pos(i)
		var d := fp.distance_to(gp)
		var kind := String(p["kind"])
		# structure
		if d < poi_range:
			if not _poi_nodes.has(i) and made < 1 and not _is_underwater(i):
				var node := PoiStructure.new()
				node.setup(p, planet, def)
				node.transform = PoiStructure.compute_transform(p, planet)
				node.name = "Poi_%d_%s" % [i, kind]
				add_child(node)
				_poi_nodes[i] = node
				made += 1
		elif _poi_nodes.has(i) and d > poi_range * 1.25 + 80.0:
			var n: Node = _poi_nodes[i]
			if is_instance_valid(n):
				n.queue_free()
			_poi_nodes.erase(i)
		# discovery (not for the start pad)
		if kind != "landing_pad" and d < 150.0 and not _discovered.has(i):
			_discovered[i] = true
			if kind != "container":
				Events.poi_discovered.emit(String(p["name"]))
		# marker beam + label: landing pads always, others once revealed (map markers)
		var want_marker := kind == "landing_pad" or PoiSites.is_revealed(p)
		if want_marker and d < 9000.0 and _alt < MAX_ALT:
			if not _markers.has(i):
				var mk := PoiMarker.new()
				mk.setup(String(p["name"]), _marker_color(kind), 150.0 if kind == "landing_pad" else 260.0)
				var up: Vector3 = p["dir"]
				mk.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), gp)
				add_child(mk)
				_markers[i] = mk
		elif _markers.has(i) and (d > 9500.0 or not want_marker):
			var m: Node = _markers[i]
			if is_instance_valid(m):
				m.queue_free()
			_markers.erase(i)

func _is_underwater(i: int) -> bool:
	if String(_pois[i]["kind"]) == "landing_pad":
		return false
	var sr: float = planet.call("sea_radius")
	return sr > 0.0 and _ground_pos(i).length() < sr + 0.3

func _marker_color(kind: String) -> Color:
	match kind:
		"landing_pad": return Color(0.35, 0.9, 1.0)
		"beacon", "ruin": return Color(0.75, 0.45, 1.0)
		"wreck": return Color(1.0, 0.55, 0.25)
		"container": return Color(0.45, 1.0, 0.55)
		"outpost", "tower", "depot", "solar": return Color(1.0, 0.85, 0.35)
	return Color(0.8, 0.9, 1.0)

# =====================================================================================================================
# public helpers
# =====================================================================================================================
func poi_node(index: int) -> Node3D:
	return _poi_nodes.get(index)

## [{pos: Vector3 (planet space), label: String, kind: "poi"|"resource"}] within `radius` of planet-space point p (for the scanner)
func get_scan_targets(p: Vector3, radius: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("resource_node"):
		var nd := n as ResourceNode
		if nd == null or nd.get_parent() != self:
			continue
		if nd.position.distance_to(p) <= radius:
			out.append({"pos": nd.position, "label": nd.get_scan_label(), "kind": "resource"})
	for i in _pois.size():
		var gp := _ground_pos(i)
		if gp.distance_to(p) <= radius and String(_pois[i]["kind"]) != "landing_pad":
			out.append({"pos": gp, "label": String(_pois[i]["name"]), "kind": "poi"})
	return out

## revealed POIs (map markers) as [{pos, label, kind}] anywhere on the planet
func revealed_markers() -> Array:
	var out: Array = []
	for i in _pois.size():
		var p: Dictionary = _pois[i]
		if PoiSites.is_revealed(p) or String(p["kind"]) == "landing_pad":
			out.append({"pos": _ground_pos(i), "label": String(p["name"]), "kind": String(p["kind"])})
	return out

func stats() -> Dictionary:
	var inst := 0
	var mmis := 0
	var cells := 0
	var tris := 0.0
	var by_id: Dictionary = {}
	for l in 3:
		for c in (_cells[l] as Dictionary).values():
			var cc: Cell = c
			if cc.state != 2:
				continue
			cells += 1
			for g in cc.groups:
				if bool(g["vis"]):
					mmis += 1
					var vc := int((g["mm"] as MultiMesh).visible_instance_count)
					inst += vc
					var tr := float(ModelLib.manifest(String(g["id"])).get("tris", 1000))
					tris += float(vc) * tr
					var rec: Array = by_id.get(g["id"], [0, 0.0])
					rec[0] += vc
					rec[1] += float(vc) * tr / 1000.0
					by_id[g["id"]] = rec
	var nodes := 0
	for c in _res_cells.values():
		nodes += (c as Cell).nodes.size()
	return {
		"active": _active, "alt": _alt, "variant": _variant_name, "cells": cells, "multimeshes": mmis, "instances": inst, "bodies": _bodies.size(),
		"res_nodes": nodes, "pois": _poi_nodes.size(), "markers": _markers.size(), "pending": _pending.size(), "inflight": _inflight,
		"built": _stat_built, "avg_build_ms": _stat_build_ms / maxf(float(_stat_built), 1.0),
		"tris_k": int(tris / 1000.0), "by_id": by_id,
	}
