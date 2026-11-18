class_name Planet
extends Node3D
## PLANET (module M1): cube-sphere quadtree terrain with threaded chunk generation, geomorphing, skirts, a collision patch and the public Planet API.
## A Planet is a Node3D whose transform is set by autoload/frame.gd every frame (identity when the local frame is anchored on it).
## Planet space = the planet's own coordinates (centre at the origin, +Y pole). In a body frame, local == planet space.
## All *_at(dir) functions take a unit direction in planet space and are thread-safe + deterministic (seeded).

const SPLIT_K := 2.4                 # a chunk of edge `size` splits when the camera is closer than SPLIT_K * size (to its bounding sphere)
const MERGE_HYST := 1.14
const UPLOAD_BUDGET_US := 2500       # main-thread time per frame spent turning finished chunk meshes into scene nodes
const LOD_INTERVAL := 0.045          # seconds between full LOD passes
const LOOKAHEAD_S := 0.9             # LOD also refines around the position the camera will reach in this many seconds (fast flight)
const NO_SEA := -1.0e9

class Chunk extends RefCounted:
	var face := 0
	var lvl := 0
	var ix := 0
	var iy := 0
	var size := 1.0
	var bound := 1.0
	var cdir := Vector3.UP
	var cpos := Vector3.ZERO
	var parent: Chunk = null
	var children: Array = []
	var state := 0                    # 0 none, 1 queued, 2 building, 3 ready
	var mi: MeshInstance3D = null
	var split_ready := false
	var covered := false
	var dead := false
	var morph_range := 1.0
	var prio := 0.0

class JobQueue extends RefCounted:
	var mutex := Mutex.new()
	var todo: Array = []              # chunks to build, WORST priority first (workers pop the best from the back)
	var done: Array = []              # [chunk, result] finished builds
	var workers := 0                  # running worker loops
	var cancelled := false

var def: BodyDef
var system: SystemDef
var radius: float = 1000.0          # base sphere radius (metres)
var water_level: float = NO_SEA     # metres above radius where the ocean surface is (-1e9 = no ocean); lava/acid for other ocean kinds
var gen: TerrainGen

var _mat: ShaderMaterial
var _terrain_root: Node3D
var _roots: Array = []
var _queue := JobQueue.new()
var _max_workers := 5
var _backlog: Array = []             # finished builds waiting for their upload slot
var _cam_prev := Vector3.ZERO
var _cam_vel := Vector3.ZERO         # smoothed camera velocity in planet space (m/s)
var _cam_pred := Vector3.ZERO        # where the camera will be in LOOKAHEAD_S
var _have_prev := false
var _todo_count := 0
var _collect_ms := 0.0
var _max_level := 6
var _lod_timer := 0.0
var _force_lod := true
var _last_cam_local := Vector3(1e9, 0, 0)
var _chunk_count := 0
var _shown_count := 0
var _is_ready := false
var _lod_ms := 0.0                   # duration of the last LOD pass (ms)
var _lod_ms_max := 0.0
var _builds_done := 0                # chunk meshes uploaded since start
var _log_every := -1.0               # --log-tel=<sec>: print chunk stats while the local frame is anchored on this planet
var _log_next := 0.0

# collision patch
var _col_body: StaticBody3D = null
var _col_dir := Vector3.ZERO
var _col_half := 0.0
var _col_busy := false
var _col_task := -1
var _col_result: Array = []
var _col_mutex := Mutex.new()
var _col_want_p := Vector3.ZERO
var _col_want_r := 60.0
var _col_want_time := -100.0

static var _detail_tex: ImageTexture = null
static var _grain_tex: ImageTexture = null

func setup(p_def: BodyDef, p_sys: SystemDef) -> void:
	def = p_def
	system = p_sys
	radius = p_def.radius
	gen = TerrainGen.new(p_def, PoiSites.for_body(p_def))
	water_level = gen.sea if gen.has_sea else NO_SEA
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--log-tel="):
			_log_every = float(String(a).substr(10))
	# deepest level: finest vertex spacing <= ~1.1 m
	var face_len := radius * PI * 0.5
	_max_level = clampi(int(ceil(log(face_len / (1.1 * float(TerrainMesher.GRID))) / log(2.0))), 3, 12)
	_max_workers = clampi(OS.get_processor_count() / 2 - 1, 3, 6)

func _ready() -> void:
	process_priority = 150          # after Frame (100): we read the final transforms of this frame
	_build_material()
	_terrain_root = Node3D.new()
	_terrain_root.name = "Terrain"
	add_child(_terrain_root)
	for f in 6:
		var c := _make_chunk(f, 0, 0, 0, null)
		_roots.append(c)
		_request(c)
	_add_children_modules()
	if _log_every > 0.0:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_is_ready = true

func _add_children_modules() -> void:
	if def.has_atmosphere:
		var a := AtmosphereEffect.new()
		a.name = "Atmosphere"
		a.setup(self, def)
		add_child(a)
		var cl := CloudLayer.new()
		cl.name = "Clouds"
		cl.setup(self, def)
		add_child(cl)
	if def.has_ocean and water_level > NO_SEA * 0.5:
		var o := OceanSurface.new()
		o.name = "Ocean"
		o.setup(self, def, sea_radius())
		add_child(o)
	if def.landable:
		var s := ScatterManager.new()
		s.name = "Scatter"
		s.setup(self, def)
		add_child(s)

func _exit_tree() -> void:
	_queue.cancelled = true
	for r in _roots:
		_kill(r)

# ---------------------------------------------------------------------------------------------------------------------
# material
# ---------------------------------------------------------------------------------------------------------------------
func _build_material() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/terrain.gdshader")
	var prof: Dictionary = gen.prof
	_mat.set_shader_parameter("detail_tex", _get_detail_tex())
	_mat.set_shader_parameter("grain_tex", _get_grain_tex())
	_mat.set_shader_parameter("dirt_color", prof.get("dirt", prof["rock2"]))
	_mat.set_shader_parameter("grain_amt", float(prof.get("grain", 0.5)))
	_mat.set_shader_parameter("beach_h", float(prof.get("beach_h", 0.0)) if gen.has_sea else 0.0)
	_mat.set_shader_parameter("beach_color", gen.c0)
	_mat.set_shader_parameter("ripple_amt", float(prof.get("ripple", 0.0)))
	_mat.set_shader_parameter("ripple_dir", gen.wind)
	_mat.set_shader_parameter("planet_radius", radius)
	_mat.set_shader_parameter("water_level", water_level)
	_mat.set_shader_parameter("rock_color", prof["rock"])
	_mat.set_shader_parameter("rock_color2", prof["rock2"])
	_mat.set_shader_parameter("rock_lo", prof["rock_lo"])
	_mat.set_shader_parameter("rock_hi", prof["rock_hi"])
	_mat.set_shader_parameter("rough_base", prof["rough"])
	_mat.set_shader_parameter("spec_base", prof["spec"])
	_mat.set_shader_parameter("emit_color", prof["emit"])
	_mat.set_shader_parameter("emit_energy", prof["emit_energy"])
	var dt: Array = prof["detail"]
	_mat.set_shader_parameter("scale_fine", 1.0 / float(dt[0]))
	_mat.set_shader_parameter("scale_mid", 1.0 / float(dt[1]))
	_mat.set_shader_parameter("nrm_fine", dt[2])
	_mat.set_shader_parameter("nrm_mid", dt[3])
	_mat.set_shader_parameter("color_var", dt[4])
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--terrain-debug="):
			_mat.set_shader_parameter("debug_mode", int(String(a).substr(16)))

static func _get_detail_tex() -> ImageTexture:
	if _detail_tex != null:
		return _detail_tex
	var sz := 256
	var nh := FastNoiseLite.new()
	nh.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nh.frequency = 0.012
	nh.fractal_type = FastNoiseLite.FRACTAL_FBM
	nh.fractal_octaves = 6
	nh.fractal_gain = 0.55
	nh.seed = 1234
	var nv := FastNoiseLite.new()
	nv.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nv.frequency = 0.01
	nv.fractal_type = FastNoiseLite.FRACTAL_FBM
	nv.fractal_octaves = 4
	nv.seed = 777
	var nc := FastNoiseLite.new()
	nc.noise_type = FastNoiseLite.TYPE_CELLULAR
	nc.frequency = 0.045
	nc.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	nc.cellular_jitter = 1.0
	nc.seed = 99
	var ih := nh.get_seamless_image(sz, sz, false, false, 0.15, true)
	var iv := nv.get_seamless_image(sz, sz, false, false, 0.15, true)
	var ic := nc.get_seamless_image(sz, sz, false, false, 0.1, true)
	ih.convert(Image.FORMAT_L8)
	iv.convert(Image.FORMAT_L8)
	ic.convert(Image.FORMAT_L8)
	var hd := ih.get_data()
	var vd := iv.get_data()
	var cd := ic.get_data()
	var out := PackedByteArray()
	out.resize(sz * sz * 4)
	var strength := 13.0
	for y in sz:
		var ym := ((y - 1 + sz) % sz) * sz
		var yp := ((y + 1) % sz) * sz
		var yy := y * sz
		for x in sz:
			var xm := (x - 1 + sz) % sz
			var xp := (x + 1) % sz
			var gx := (float(hd[yy + xm]) - float(hd[yy + xp])) / 255.0 * strength
			var gy := (float(hd[ym + x]) - float(hd[yp + x])) / 255.0 * strength
			var inv := 1.0 / sqrt(gx * gx + gy * gy + 1.0)
			var o := (yy + x) * 4
			out[o] = int(clampf(gx * inv * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			out[o + 1] = int(clampf(gy * inv * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			out[o + 2] = vd[yy + x]
			out[o + 3] = cd[yy + x]
	var img := Image.create_from_data(sz, sz, false, Image.FORMAT_RGBA8, out)
	img.generate_mipmaps()
	_detail_tex = ImageTexture.create_from_image(img)
	return _detail_tex

## high-frequency grain: r = fine speckle (grass / grit), g = medium speckle, b = crack / pebble network (0 on the cracks). Seamless, mip-mapped.
static func _get_grain_tex() -> ImageTexture:
	if _grain_tex != null:
		return _grain_tex
	var sz := 256
	var n1 := FastNoiseLite.new()
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.21
	n1.fractal_type = FastNoiseLite.FRACTAL_FBM
	n1.fractal_octaves = 2
	n1.seed = 4242
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.075
	n2.fractal_type = FastNoiseLite.FRACTAL_FBM
	n2.fractal_octaves = 3
	n2.seed = 313
	var n3 := FastNoiseLite.new()
	n3.noise_type = FastNoiseLite.TYPE_CELLULAR
	n3.frequency = 0.032
	n3.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n3.cellular_jitter = 1.0
	n3.seed = 7
	var i1 := n1.get_seamless_image(sz, sz, false, false, 0.15, true)
	var i2 := n2.get_seamless_image(sz, sz, false, false, 0.15, true)
	var i3 := n3.get_seamless_image(sz, sz, false, false, 0.1, true)
	i1.convert(Image.FORMAT_L8)
	i2.convert(Image.FORMAT_L8)
	i3.convert(Image.FORMAT_L8)
	var d1 := i1.get_data()
	var d2 := i2.get_data()
	var d3 := i3.get_data()
	var out := PackedByteArray()
	out.resize(sz * sz * 4)
	for k in sz * sz:
		# stretch the (low-contrast) noise to use the full range so the grain really shows
		out[k * 4] = int(clampf((float(d1[k]) / 255.0 - 0.5) * 1.9 + 0.5, 0.0, 1.0) * 255.0)
		out[k * 4 + 1] = int(clampf((float(d2[k]) / 255.0 - 0.5) * 1.7 + 0.5, 0.0, 1.0) * 255.0)
		out[k * 4 + 2] = d3[k]
		out[k * 4 + 3] = 255
	var img := Image.create_from_data(sz, sz, false, Image.FORMAT_RGBA8, out)
	img.generate_mipmaps()
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex

# ---------------------------------------------------------------------------------------------------------------------
# quadtree
# ---------------------------------------------------------------------------------------------------------------------
func _make_chunk(f: int, lvl: int, ix: int, iy: int, parent: Chunk) -> Chunk:
	var c := Chunk.new()
	c.face = f
	c.lvl = lvl
	c.ix = ix
	c.iy = iy
	c.parent = parent
	var cnt := float(1 << lvl)
	c.size = radius * PI * 0.5 / cnt
	c.cdir = TerrainMesher.cube_dir(f, -1.0 + (2.0 * float(ix) + 1.0) / cnt, -1.0 + (2.0 * float(iy) + 1.0) / cnt)
	c.cpos = c.cdir * (radius + gen.height(c.cdir))
	c.bound = c.size * 0.66
	c.morph_range = (SPLIT_K + 0.2) * c.size
	_chunk_count += 1
	return c

func _request(c: Chunk) -> void:
	if c.state == 0:
		c.state = 1
		_queue.mutex.lock()
		_queue.todo.append(c)
		_queue.mutex.unlock()

func _want_split(c: Chunk, cam: Vector3) -> bool:
	if c.lvl >= _max_level:
		return false
	var d := maxf(minf(cam.distance_to(c.cpos), _cam_pred.distance_to(c.cpos)) - c.bound, 0.0)
	var thr := SPLIT_K * c.size
	if not c.children.is_empty():
		thr *= MERGE_HYST
	if d >= thr:
		return false
	# horizon culling for the finest levels: chunks entirely behind the planet's horizon do not need more detail
	if c.size < 300.0:
		var rc := cam.length()
		var rp := c.cpos.length() + c.bound
		var r_occ := radius - 60.0
		if rc > r_occ:
			var th_h := acos(clampf(r_occ / rc, -1.0, 1.0)) + acos(clampf(r_occ / maxf(rp, r_occ), -1.0, 1.0))
			var th := acos(clampf(cam.normalized().dot(c.cdir), -1.0, 1.0)) - c.bound / r_occ
			if th > th_h + 0.01:
				return false
	return true

func _visit(c: Chunk, cam: Vector3) -> void:
	var want := _want_split(c, cam)
	if not want and not c.children.is_empty() and c.state != 3:
		want = true          # keep the children until our own mesh exists (no holes)
	if want:
		if c.children.is_empty():
			var h := 1 << (c.lvl + 1)
			for k in 4:
				var cx := c.ix * 2 + (k & 1)
				var cy := c.iy * 2 + (k >> 1)
				var ch := _make_chunk(c.face, c.lvl + 1, cx, cy, c)
				c.children.append(ch)
				_request(ch)
		var all := true
		for ch2 in c.children:
			_visit(ch2, cam)
			if not (ch2 as Chunk).covered:
				all = false
		c.split_ready = all
	else:
		c.split_ready = false
		if not c.children.is_empty():
			for ch3 in c.children:
				_kill(ch3)
			c.children.clear()
	c.covered = c.split_ready or c.state == 3

func _kill(c: Chunk) -> void:
	c.dead = true
	_chunk_count -= 1
	if c.mi != null and is_instance_valid(c.mi):
		c.mi.queue_free()
	c.mi = null
	for ch in c.children:
		_kill(ch)
	c.children.clear()

func _apply(c: Chunk, allowed: bool) -> void:
	var show_self := allowed and not c.split_ready and c.state == 3
	if c.mi != null:
		if c.mi.visible != show_self:
			c.mi.visible = show_self
	if show_self:
		_shown_count += 1
	var child_allowed := allowed and c.split_ready
	for ch in c.children:
		_apply(ch, child_allowed)

# ---------------------------------------------------------------------------------------------------------------------
# job pipeline: long-running worker loops pull the best chunk from a shared priority list (re-sorted after every LOD pass),
# finished meshes are turned into scene nodes on the main thread within a per-frame time budget.
# ---------------------------------------------------------------------------------------------------------------------
static func _worker(q: JobQueue, g: TerrainGen) -> void:
	while true:
		q.mutex.lock()
		if q.cancelled or q.todo.is_empty():
			q.workers -= 1
			q.mutex.unlock()
			return
		var c: Chunk = q.todo.pop_back()
		q.mutex.unlock()
		if c.dead:
			c.state = 4
			continue
		var res := TerrainMesher.build(g, c.face, c.lvl, c.ix, c.iy, c.morph_range)
		q.mutex.lock()
		q.done.append([c, res])
		q.mutex.unlock()

## main thread: drop dead chunks from the work list, order it by distance (nearest = built first) and make sure enough workers run
func _resort_and_feed(cam: Vector3) -> void:
	_queue.mutex.lock()
	var keys: Array = []
	var live: Array = []
	for c in _queue.todo:
		var ch: Chunk = c
		if ch.dead:
			continue
		var p := minf(cam.distance_to(ch.cpos), _cam_pred.distance_to(ch.cpos)) - ch.bound * 0.5
		if ch.parent == null:
			p = -1.0e12          # root faces first: the planet must exist
		keys.append(Vector2(-p, float(live.size())))      # sort ascending on -dist: farthest first, nearest last (pop_back)
		live.append(ch)
	keys.sort()
	var sorted: Array = []
	sorted.resize(live.size())
	for i in keys.size():
		sorted[i] = live[int((keys[i] as Vector2).y)]
	_queue.todo = sorted
	_todo_count = sorted.size()
	var need := mini(_max_workers - _queue.workers, sorted.size())
	_queue.workers += maxi(need, 0)
	_queue.mutex.unlock()
	for i in maxi(need, 0):
		WorkerThreadPool.add_task(_worker.bind(_queue, gen), false, "terrain chunks")

## main thread: pick up finished builds; returns true when new chunk nodes were added
func _collect() -> bool:
	_queue.mutex.lock()
	if not _queue.done.is_empty():
		_backlog.append_array(_queue.done)
		_queue.done = []
	_queue.mutex.unlock()
	if _backlog.is_empty():
		return false
	var t0 := Time.get_ticks_usec()
	var n := 0
	var changed := false
	while n < _backlog.size():
		if n >= 3 and Time.get_ticks_usec() - t0 > UPLOAD_BUDGET_US:
			break
		var it: Array = _backlog[n]
		n += 1
		var c: Chunk = it[0]
		var res = it[1]
		if res == null or c.dead:
			c.state = 4
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = res["mesh"]
		mi.material_override = _mat
		mi.position = res["centre"]
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if c.size < 2500.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_terrain_root.add_child(mi)
		c.mi = mi
		c.state = 3
		_builds_done += 1
		changed = true
	_backlog = _backlog.slice(n)
	_collect_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return changed

# ---------------------------------------------------------------------------------------------------------------------
# per-frame
# ---------------------------------------------------------------------------------------------------------------------
func _process(dt: float) -> void:
	if not _is_ready:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cam_world := cam.global_position
	_mat.set_shader_parameter("planet_center", global_position)
	_mat.set_shader_parameter("cam_pos", cam_world)
	var cam_local := global_transform.affine_inverse() * cam_world
	# camera velocity (planet space) -> LOD lookahead, so fast low flight never outruns the chunk builder
	if _have_prev and dt > 0.0001:
		var v := (cam_local - _cam_prev) / dt
		if v.length() > 6000.0:
			_cam_vel = Vector3.ZERO           # frame switch / teleport
		else:
			_cam_vel = _cam_vel.lerp(v, 1.0 - exp(-dt * 5.0))
	_cam_prev = cam_local
	_have_prev = true
	var alt := maxf(cam_local.length() - radius, 1.0)
	var ahead := _cam_vel * LOOKAHEAD_S
	var max_ahead := 80.0 + 3.0 * alt
	if ahead.length() > max_ahead:
		ahead = ahead.normalized() * max_ahead
	_cam_pred = cam_local + ahead
	_lod_timer -= dt
	var changed := _collect()
	var did_visit := false
	if _lod_timer <= 0.0 or _force_lod:
		_lod_timer = LOD_INTERVAL
		_force_lod = false
		var t_lod := Time.get_ticks_usec()
		for r in _roots:
			_visit(r, cam_local)
		_resort_and_feed(cam_local)
		_lod_ms = float(Time.get_ticks_usec() - t_lod) / 1000.0
		_lod_ms_max = maxf(_lod_ms_max, _lod_ms)
		did_visit = true
	if did_visit or changed:
		_shown_count = 0
		for r2 in _roots:
			_apply(r2, true)
		_last_cam_local = cam_local
	_update_collision()
	if _log_every > 0.0 and Frame.anchor == def.index:
		_log_next -= dt
		if _log_next <= 0.0:
			_log_next = _log_every
			var st := debug_stats()
			var vrid := get_viewport().get_viewport_rid()
			var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(vrid)
			var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			print("[TERRAIN] %s alt=%.0f chunks=%d shown=%d todo=%d backlog=%d lod_ms=%.2f/%.2f upload_ms=%.2f builds=%d fps=%d gpu_ms=%.2f cpu_ms=%.2f proc_ms=%.2f draws=%d tris=%dk v=%.0f per_level=%s" % [def.name, alt, st["chunks"], st["shown"], st["pending"], _backlog.size(), _lod_ms, _lod_ms_max, _collect_ms, _builds_done, Engine.get_frames_per_second(), gpu_ms, cpu_ms, proc_ms, draws, prims / 1000, _cam_vel.length(), str(st["shown_per_level"])])
			_lod_ms_max = 0.0

# ---------------------------------------------------------------------------------------------------------------------
# collision patch
# ---------------------------------------------------------------------------------------------------------------------
static func _col_job(owner_mutex: Mutex, out: Array, g: TerrainGen, dir0: Vector3, half: float, step: float) -> void:
	var res := TerrainMesher.build_collision(g, dir0, half, step)
	owner_mutex.lock()
	out.append(res)
	owner_mutex.unlock()

## Keep a physics collision patch around planet-space point p (call every frame while walking / flying low). Cheap when p barely moved.
func set_collision_focus(p: Vector3, patch_radius: float = 60.0) -> void:
	_col_want_p = p
	_col_want_r = clampf(patch_radius, 20.0, 400.0)
	_col_want_time = Time.get_ticks_msec() / 1000.0

func _update_collision() -> void:
	# result of a finished job
	_col_mutex.lock()
	var res: Array = _col_result.duplicate()
	_col_result.clear()
	_col_mutex.unlock()
	if not res.is_empty():
		_col_busy = false
		var r: Dictionary = res[res.size() - 1]
		var body := StaticBody3D.new()
		body.name = "CollisionPatch"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = r["shape"]
		body.add_child(cs)
		body.position = r["centre"]
		add_child(body)
		if _col_body != null and is_instance_valid(_col_body):
			_col_body.queue_free()
		_col_body = body
		_col_dir = r["dir"]
		_col_half = r["half"]
	var now := Time.get_ticks_msec() / 1000.0
	if now - _col_want_time > 3.0 or _col_busy:
		return
	var want_dir := _col_want_p.normalized()
	var need := _col_body == null
	if not need:
		var off := (want_dir - _col_dir).length() * radius
		need = off > _col_half * 0.32 or _col_half < _col_want_r * 0.9
	if need:
		_col_busy = true
		var half := _col_want_r
		var step := clampf(half / 52.0, 0.8, 4.0)
		WorkerThreadPool.add_task(_col_job.bind(_col_mutex, _col_result, gen, want_dir, half, step), false, "terrain collision")

## true when the collision patch around p exists (the player waits / falls back to analytic ground otherwise)
func is_collision_ready(p: Vector3) -> bool:
	if _col_body == null:
		return false
	var off := (p.normalized() - _col_dir).length() * radius
	return off < _col_half * 0.8

# ---------------------------------------------------------------------------------------------------------------------
# public API
# ---------------------------------------------------------------------------------------------------------------------
func biome() -> String:
	return def.biome

## terrain height in metres above `radius` (solid ground, includes flattening of POI sites). Not water.
func height_at(dir: Vector3) -> float:
	return gen.height(dir.normalized())

## radius of the solid ground along dir (planet space)
func terrain_radius_at(dir: Vector3) -> float:
	var d := dir.normalized()
	return radius + gen.height(d)

## radius of the ocean surface (water/lava/acid) or 0.0 if the planet has none
func sea_radius() -> float:
	return radius + water_level if water_level > NO_SEA * 0.5 else 0.0

## terrain normal in planet space (unit)
func normal_at(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1)
	var e := 0.9 / radius
	var pa := (d + t1 * e).normalized()
	var pb := (d - t1 * e).normalized()
	var pc := (d + t2 * e).normalized()
	var pd := (d - t2 * e).normalized()
	var va := pa * (radius + gen.height(pa))
	var vb := pb * (radius + gen.height(pb))
	var vc := pc * (radius + gen.height(pc))
	var vd := pd * (radius + gen.height(pd))
	var n := (va - vb).cross(vc - vd)
	if n.dot(d) < 0.0:
		n = -n
	return n.normalized()

## height of planet-space position p above the ground (negative = underground). Uses height_at.
func altitude_of(p: Vector3) -> float:
	return p.length() - terrain_radius_at(p.normalized())

## gravity acceleration vector at planet-space position p (towards the centre; weakens above the atmosphere)
func gravity_at(p: Vector3) -> Vector3:
	var alt := maxf(p.length() - radius, 0.0)
	var f := 1.0 / (1.0 + pow(alt / (radius * 1.5), 2.0))
	return -p.normalized() * def.gravity * f

## 0..1 atmosphere density at planet-space position p (1 at the ground, 0 above def.atmo_height)
func atmosphere_density_at(p: Vector3) -> float:
	if not def.has_atmosphere or def.atmo_height <= 0.0:
		return 0.0
	var alt := p.length() - radius
	return clampf(1.0 - alt / def.atmo_height, 0.0, 1.0)

## points of interest on this planet: Array of Dictionary {dir, radius, kind, name, seed, flat}  (see world/content/poi_sites.gd)
func get_pois() -> Array:
	return PoiSites.for_body(def)

## debug: number of live chunks / chunks currently drawn
func debug_stats() -> Dictionary:
	var per_level: Array = []
	per_level.resize(_max_level + 1)
	per_level.fill(0)
	var stack: Array = _roots.duplicate()
	while not stack.is_empty():
		var c: Chunk = stack.pop_back()
		if c.mi != null and c.mi.visible:
			per_level[c.lvl] += 1
		for ch in c.children:
			stack.append(ch)
	return {"chunks": _chunk_count, "shown": _shown_count, "pending": _todo_count + _backlog.size(), "inflight": _queue.workers, "max_level": _max_level, "shown_per_level": per_level,
		"lod_ms": _lod_ms, "lod_ms_max": _lod_ms_max, "builds": _builds_done}

## debug: is the ground direction `d` (unit, planet space) covered by a visible chunk (any level on its quadtree path)?
func debug_covered(d: Vector3) -> bool:
	var f := TerrainMesher.face_of(d)
	var uv := TerrainMesher.dir_to_uv(f, d)
	var node: Chunk = _roots[f]
	var lvl := 0
	while true:
		if node.mi != null and node.mi.visible:
			return true
		if node.children.is_empty():
			return false
		var cnt := float(1 << (lvl + 1))
		var bx := clampi(int((uv.x + 1.0) * 0.5 * cnt), 0, (1 << (lvl + 1)) - 1) - node.ix * 2
		var by := clampi(int((uv.y + 1.0) * 0.5 * cnt), 0, (1 << (lvl + 1)) - 1) - node.iy * 2
		var k := clampi(bx, 0, 1) | (clampi(by, 0, 1) << 1)
		node = node.children[k]
		lvl += 1
	return false

## debug: number of ground sample points (n points spread over rings of 4..400 m around planet-space point p) NOT covered by a visible chunk
func debug_holes(p: Vector3, n: int = 40) -> int:
	var up := p.normalized()
	var t1 := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := up.cross(t1)
	var holes := 0
	for i in n:
		var a := float(i) * 2.399963
		var r := 4.0 * pow(100.0, float(i) / float(maxi(n - 1, 1)))
		var q := (up * radius + (t1 * cos(a) + t2 * sin(a)) * r).normalized()
		if not debug_covered(q):
			holes += 1
	return holes

## debug: casts n rays (golden-spiral pattern) inside a cone of half-angle `half_deg` around `look` from planet-space camera position `cam`;
## returns Vector2i(rays that hit the planet sphere, hits whose ground column has NO visible chunk = holes). Works at any altitude.
func debug_view_holes(cam: Vector3, look: Vector3, half_deg: float, n: int = 120) -> Vector2i:
	var l := look.normalized()
	var t1 := l.cross(Vector3.UP if absf(l.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := l.cross(t1)
	var hits := 0
	var holes := 0
	var tmax := tan(deg_to_rad(half_deg))
	for i in n:
		var rr := sqrt((float(i) + 0.5) / float(n)) * tmax
		var a := float(i) * 2.399963
		var rd := (l + (t1 * cos(a) + t2 * sin(a)) * rr).normalized()
		# ray - sphere(radius) intersection
		var b := cam.dot(rd)
		var c := cam.length_squared() - radius * radius
		var disc := b * b - c
		if disc < 0.0:
			continue
		var tt := -b - sqrt(disc)
		if tt < 0.0:
			continue
		hits += 1
		var q := (cam + rd * tt).normalized()
		if not debug_covered(q):
			holes += 1
	return Vector2i(hits, holes)
