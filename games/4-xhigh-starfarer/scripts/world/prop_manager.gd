class_name PropManager
extends Node3D
## Everything that populates a planet surface: deterministic flora/rock scatter (generated on worker threads, drawn with
## MultiMesh), minable resource nodes, points of interest (outposts, monoliths, wrecks, towers), wildlife, weather, scanner.

const CELL := [128.0, 36.0]       # tier 0 = big props, tier 1 = ground cover / resources
const RING := [380.0, 95.0]
const MAX_INFLIGHT := 6
const MAX_APPLY_PER_FRAME := 2
const COLL_LATTICE := 10.0

var world: World
var planet: Planet = null
var field_root: Node3D
var sites_root: Node3D
var weather: WeatherFx
var cells: Array = [{}, {}]
var pending: Array = [{}, {}]
var results: Array = []
var mutex := Mutex.new()
var inflight := 0
var collider_hash := {}
var excl: Array = []                      # [dir(Vector3), radius_m]
var sites_by_planet := {}
var sites: Array = []
var res_nodes: Array = []
var mined := {}                           # planet seed -> {id: true}
var creatures: Array = []
var last_focus := Vector3(1e9, 0, 0)
var tier_timer := [0.0, 0.0]
var scan_t := 0.0
var mine_target: Dictionary = {}
var mine_prog := 0.0
var mine_sfx_t := 0.0
var beam: MeshInstance3D
var hint_text := ""
var spawn_cd := 0.0
var site_check_t := 0.0
var pad_node: Node3D
var start_pad_info: Dictionary = {}
var interact_site: Dictionary = {}
var rng := RandomNumberGenerator.new()
var wind_level := 0.0
var scan_ring: MeshInstance3D
var scan_ring_t := 99.0


func setup(w: World) -> void:
	world = w
	rng.randomize()
	weather = WeatherFx.new()
	w.add_child(weather)
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 1.0
	cm.radial_segments = 6
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.3, 0.95, 1.0)
	bm.emission_enabled = true
	bm.emission = Color(0.3, 0.95, 1.0)
	bm.emission_energy_multiplier = 4.0
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bm
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(beam)
	# scanner ring: expanding translucent sphere
	scan_ring = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	scan_ring.mesh = sm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_FRONT
	rm.albedo_color = Color(0.2, 0.8, 1.0, 0.12)
	rm.emission_enabled = true
	rm.emission = Color(0.2, 0.8, 1.0)
	rm.emission_energy_multiplier = 0.8
	scan_ring.material_override = rm
	scan_ring.visible = false
	scan_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(scan_ring)


func on_system_cleared() -> void:
	_unload_all()
	planet = null
	sites_by_planet.clear()
	sites.clear()
	mined.clear()
	start_pad_info = {}


# ----------------------------------------------------------------------------- activation
func _pick_planet(w: World) -> Planet:
	var p := w.nearest_planet as Planet
	if p == null or not p.is_landable():
		return null
	if w.cam_alt > 8000.0:
		return null
	return p


func _unload_all() -> void:
	for t in 2:
		for k in cells[t]:
			var c: Dictionary = cells[t][k]
			for n in c.nodes:
				if is_instance_valid(n):
					n.queue_free()
		cells[t].clear()
		pending[t].clear()
	collider_hash.clear()
	for r in res_nodes:
		if is_instance_valid(r.node):
			r.node.queue_free()
	res_nodes.clear()
	for c in creatures:
		if is_instance_valid(c):
			c.queue_free()
	creatures.clear()
	if is_instance_valid(field_root):
		field_root.queue_free()
	if is_instance_valid(sites_root):
		sites_root.queue_free()
	field_root = null
	sites_root = null
	sites = []
	pad_node = null
	mutex.lock()
	results.clear()
	mutex.unlock()


func _activate(p: Planet) -> void:
	_unload_all()
	planet = p
	if p == null:
		return
	field_root = Node3D.new()
	field_root.name = "Field"
	p.add_child(field_root)
	sites_root = Node3D.new()
	sites_root.name = "Sites"
	p.add_child(sites_root)
	sites = _sites_for(p)
	for s in sites:
		s.node = null
		s.beam = null
	excl.clear()
	for s in sites:
		excl.append([s.dir, s.clear])
	if start_pad_info.has("planet") and start_pad_info.planet == p.display_name:
		excl.append([start_pad_info.dir, 14.0])
	last_focus = Vector3(1e9, 0, 0)
	weather.configure(p.data)


# ----------------------------------------------------------------------------- sites
func _sites_for(p: Planet) -> Array:
	var key := "%s_%d" % [p.display_name, p.data.seed]
	if sites_by_planet.has(key):
		return sites_by_planet[key]
	var d := p.data
	var r := RandomNumberGenerator.new()
	r.seed = d.seed * 31 + 7
	var out: Array = []
	var types := ["outpost", "monolith", "wreck", "tower", "outpost", "wreck", "monolith", "tower", "outpost"]
	# first site on the home planet: near the landing area so it is visible at start
	var first_dir := Vector3.ZERO
	if p == world.home_planet and start_pad_info.has("dir"):
		var sd: Vector3 = start_pad_info.dir
		var t := sd.cross(Vector3.UP).normalized()
		first_dir = (sd * d.radius + t * 300.0).normalized()
	var tries := 0
	while out.size() < d.poi_count + 2 and tries < 400:
		tries += 1
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)).normalized()
		if out.is_empty() and first_dir != Vector3.ZERO:
			dir = first_dir
		var h := d.height_at(dir)
		if d.has_liquid() and h < d.sea_level + 6.0:
			continue
		var nrm := d.normal_at(dir, 4.0)
		var typ: String = types[out.size() % types.size()]
		var need := 0.965 if typ != "tower" else 0.93
		if nrm.dot(dir) < need and not (out.is_empty() and first_dir != Vector3.ZERO):
			continue
		var ok := true
		for s in out:
			if (s.dir as Vector3).angle_to(dir) * d.radius < 700.0:
				ok = false
		if not ok:
			continue
		var clear := 24.0 if typ == "outpost" else (14.0 if typ == "monolith" else (16.0 if typ == "wreck" else 9.0))
		var nm := ""
		match typ:
			"outpost": nm = "OUTPOST"
			"monolith": nm = "MONOLITH"
			"wreck": nm = "CRASHED SHIP"
			"tower": nm = "RADIO TOWER"
		out.append({"type": typ, "dir": dir, "clear": clear, "name": nm, "yaw": r.randf() * TAU, "used": false, "node": null, "beam": null, "h": h})
	sites_by_planet[key] = out
	return out


func _site_basis(s: Dictionary, nrm_blend := 0.6) -> Basis:
	var dir: Vector3 = s.dir
	var nrm := planet.data.normal_at(dir, 6.0).lerp(dir, 1.0 - nrm_blend).normalized()
	var t := nrm.cross(Vector3.RIGHT)
	if t.length() < 0.1:
		t = nrm.cross(Vector3.FORWARD)
	t = t.normalized().rotated(nrm, s.yaw)
	return Basis.looking_at(t, nrm)


func _site_model(typ: String) -> String:
	match typ:
		"outpost": return "outpost"
		"monolith": return "monolith"
		"wreck": return "wreck"
		_: return "radio_tower"


func _update_sites(focus_local: Vector3) -> void:
	for s in sites:
		var dir: Vector3 = s.dir
		var pos: Vector3 = dir * (planet.radius + float(s.h))
		var dist := focus_local.distance_to(pos)
		if s.beam == null and dist < 6000.0:
			var b := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.2
			cm.bottom_radius = 2.2
			cm.height = 260.0
			cm.radial_segments = 10
			b.mesh = cm
			var bm := StandardMaterial3D.new()
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.cull_mode = BaseMaterial3D.CULL_DISABLED
			var col := Color(0.3, 0.9, 1.0, 0.16)
			if s.type == "wreck":
				col = Color(1.0, 0.55, 0.2, 0.16)
			elif s.type == "monolith":
				col = Color(0.8, 0.4, 1.0, 0.16)
			bm.albedo_color = col
			b.material_override = bm
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sites_root.add_child(b)
			var bas := _site_basis(s, 0.0)
			b.transform = Transform3D(bas, pos + dir * 130.0)
			s.beam = b
		if s.node == null and dist < 650.0:
			var tint := {}
			var n := ModelLib.instance(_site_model(s.type), tint)
			sites_root.add_child(n)
			n.transform = Transform3D(_site_basis(s).scaled(Vector3.ONE * (1.0 if s.type != "tower" else 1.0)), pos + dir * (-0.3 if s.type != "monolith" else -0.5))
			s.node = n
		elif s.node != null and dist > 900.0:
			s.node.queue_free()
			s.node = null
		if s.beam != null and dist < 120.0:
			(s.beam as Node3D).visible = false
		elif s.beam != null:
			(s.beam as Node3D).visible = true


func poi_markers(w: World) -> Array:
	var out: Array = []
	if planet == null or sites.is_empty():
		return out
	var cp := w.cam.global_position
	var focus_local := _focus_local(w)
	for s in sites:
		var pos_l: Vector3 = (s.dir as Vector3) * (planet.radius + s.h)
		var dist := focus_local.distance_to(pos_l)
		if dist > 4500.0:
			continue
		var wp := planet.global_transform * (pos_l + (s.dir as Vector3) * 12.0)
		var sp := w.project(wp)
		var col := Color(0.4, 0.95, 1.0)
		if s.type == "wreck":
			col = Color(1.0, 0.6, 0.3)
		elif s.type == "monolith":
			col = Color(0.85, 0.5, 1.0)
		out.append({"p": Vector2(sp.x, sp.y), "vis": sp.z > 0.5, "label": s.name, "dist": dist, "col": col, "big": false, "target": false, "dir": Vector3.ZERO})
	if scan_t > 0.0:
		for r in res_nodes:
			if not is_instance_valid(r.node):
				continue
			var wp2 := planet.global_transform * ((r.pos as Vector3) + (r.pos as Vector3).normalized() * 2.0)
			var sp2 := w.project(wp2)
			var d2 := focus_local.distance_to(r.pos)
			out.append({"p": Vector2(sp2.x, sp2.y), "vis": sp2.z > 0.5, "label": r.type, "dist": d2, "col": r.color, "big": false, "target": false, "dir": Vector3.ZERO})
	return out


func _focus_local(w: World) -> Vector3:
	if w.on_foot and w.player.frame == planet:
		return w.player.lpos
	if w.ship.frame == planet:
		return w.ship.lpos
	return planet.cam_local


func start_pad(p: Planet, dir: Vector3, bas: Basis) -> void:
	start_pad_info = {"planet": p.display_name, "dir": dir, "basis": bas}
	_activate(p)
	_place_pad()


func _place_pad() -> void:
	if planet == null or not start_pad_info.has("dir"):
		return
	if start_pad_info.planet != planet.display_name:
		return
	var dir: Vector3 = start_pad_info.dir
	var h := planet.data.height_at(dir)
	var bas: Basis = start_pad_info.basis
	var nrm := planet.data.normal_at(dir, 5.0)
	var t := (-bas.z - nrm * (-bas.z).dot(nrm)).normalized()
	pad_node = ModelLib.instance("landing_pad")
	sites_root.add_child(pad_node)
	pad_node.transform = Transform3D(Basis.looking_at(t, nrm.lerp(dir, 0.5).normalized()), dir * (planet.radius + h - 0.15))


# ----------------------------------------------------------------------------- scatter
func _cell_ds(tier: int) -> float:
	return CELL[tier] / (planet.radius * 0.7854)


func _key(face: int, i: int, j: int) -> int:
	return (face << 40) | ((i + 8192) << 20) | (j + 8192)


func _wanted_cells(tier: int, focus: Vector3) -> Dictionary:
	var out := {}
	var ds := _cell_ds(tier)
	var cs: float = CELL[tier]
	var rg: float = RING[tier]
	var up := focus.normalized()
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var e1 := up.cross(ref).normalized()
	var e2 := up.cross(e1)
	var step := cs * 0.7
	var n := int(ceil(rg / step))
	for a in range(-n, n + 1):
		for b in range(-n, n + 1):
			var off := Vector2(a, b) * step
			if off.length() > rg + cs * 0.8:
				continue
			var d := (up * planet.radius + e1 * off.x + e2 * off.y).normalized()
			var fst: Array = TNoise.dir_to_face_st(d)
			var f: int = fst[0]
			var i := int(floor(float(fst[1]) / ds))
			var j := int(floor(float(fst[2]) / ds))
			out[_key(f, i, j)] = [f, i, j]
	return out


func _cell_center_dir(f: int, i: int, j: int, ds: float) -> Vector3:
	return TNoise.cube_to_sphere(TNoise.FACE_N[f] + TNoise.FACE_A[f] * ((i + 0.5) * ds) + TNoise.FACE_B[f] * ((j + 0.5) * ds))


func _update_tier(tier: int, focus: Vector3) -> void:
	var want := _wanted_cells(tier, focus)
	var ds := _cell_ds(tier)
	# unload far cells
	var rg: float = RING[tier]
	for k in cells[tier].keys():
		if not want.has(k):
			var c: Dictionary = cells[tier][k]
			var cd: Vector3 = c.center
			if (cd * planet.radius).distance_to(focus) > rg * 1.35:
				_free_cell(tier, k)
	# schedule new ones, closest first
	var todo: Array = []
	for k in want:
		if cells[tier].has(k) or pending[tier].has(k):
			continue
		var nd: Array = want[k]
		var cdir := _cell_center_dir(nd[0], nd[1], nd[2], ds)
		todo.append([(cdir * planet.radius).distance_to(focus), k, nd])
	todo.sort_custom(func(a, b): return a[0] < b[0])
	for t in todo:
		if inflight >= MAX_INFLIGHT:
			break
		var nd2: Array = t[2]
		pending[tier][t[1]] = true
		inflight += 1
		var args := {"data": planet.data, "tier": tier, "face": nd2[0], "i": nd2[1], "j": nd2[2], "ds": ds, "key": t[1],
			"excl": excl.duplicate(), "mined": (mined.get(planet.data.seed, {}) as Dictionary).duplicate(), "planet": planet.display_name}
		WorkerThreadPool.add_task(PropManager._gen_cell.bind(args, self))


static func _gen_cell(a: Dictionary, mgr: PropManager) -> void:
	var d: PlanetData = a.data
	var tier: int = a.tier
	var R := d.radius
	var ds: float = a.ds
	var f: int = a.face
	var ci: int = a.i
	var cj: int = a.j
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d_%d_%d_%d_%d" % [d.seed, f, ci, cj, tier])
	var N: Vector3 = TNoise.FACE_N[f]
	var A: Vector3 = TNoise.FACE_A[f]
	var B: Vector3 = TNoise.FACE_B[f]
	var s0 := ci * ds
	var t0 := cj * ds
	var area := pow(ds * R * 0.7854, 2.0)
	var excl: Array = a.excl
	var items: Array = []
	var res_items: Array = []
	var slope_tan_default := 0.7
	for si in d.flora.size():
		var spec: Dictionary = d.flora[si]
		if int(spec.tier) != tier:
			continue
		var expect: float = spec.d * area / 1000.0
		var n := int(expect)
		if rng.randf() < expect - n:
			n += 1
		for k in n:
			var s := s0 + rng.randf() * ds
			var t := t0 + rng.randf() * ds
			var dir := TNoise.cube_to_sphere(N + A * s + B * t)
			var clump: float = spec.clump
			if clump > 0.0:
				var m := TNoise.fbm(dir.x * R / 240.0 + si * 7.3, dir.y * R / 240.0, dir.z * R / 240.0, 2, 0.5, d.seed + 60 + si)
				var acc := TNoise.smooth(-0.22, 0.22, m)
				if rng.randf() > lerpf(1.0, acc, clump):
					continue
			var h := d.height_at(dir)
			if d.has_liquid() and h < d.sea_level + 1.2:
				continue
			var e := 3.0 / R
			var d2 := (dir + A.normalized() * e).normalized()
			var slope := absf(d.height_at(d2) - h) / 3.0
			var max_s := tan(acos(clampf(spec.slope, 0.3, 0.999)))
			if slope > max_s:
				continue
			var blocked := false
			for z in excl:
				if (z[0] as Vector3).angle_to(dir) * R < float(z[1]):
					blocked = true
					break
			if blocked:
				continue
			items.append({"si": si, "dir": dir, "h": h, "yaw": rng.randf() * TAU, "sc": rng.randf_range(spec.s0, spec.s1), "tilt": Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.07, 0.07)), "slope": slope})
	if tier == 1 and d.resources.size() > 0:
		var expect2 := 0.55 * area / 1000.0
		var n2 := int(expect2)
		if rng.randf() < expect2 - n2:
			n2 += 1
		for k in n2:
			var s := s0 + rng.randf() * ds
			var t := t0 + rng.randf() * ds
			var dir := TNoise.cube_to_sphere(N + A * s + B * t)
			var h := d.height_at(dir)
			if d.has_liquid() and h < d.sea_level + 1.5:
				continue
			var blocked2 := false
			for z in excl:
				if (z[0] as Vector3).angle_to(dir) * R < float(z[1]):
					blocked2 = true
			if blocked2:
				continue
			var id := "%d_%d_%d_%d" % [f, ci, cj, k]
			if (a.mined as Dictionary).has(id):
				continue
			var ri := rng.randi() % d.resources.size()
			res_items.append({"id": id, "dir": dir, "h": h, "yaw": rng.randf() * TAU, "ri": ri, "amt": rng.randi_range(2, 5)})
	var res := {"tier": tier, "key": a.key, "face": f, "i": ci, "j": cj, "items": items, "res": res_items, "ds": ds, "planet": a.planet}
	mgr.mutex.lock()
	mgr.results.append(res)
	mgr.mutex.unlock()


func _collect_results() -> void:
	var applied := 0
	while applied < MAX_APPLY_PER_FRAME:
		mutex.lock()
		var r: Dictionary = {}
		if not results.is_empty():
			r = results.pop_front()
		mutex.unlock()
		if r.is_empty():
			break
		inflight = maxi(inflight - 1, 0)
		pending[r.tier].erase(r.key)
		if planet == null or r.planet != planet.display_name:
			continue
		if cells[r.tier].has(r.key):
			continue
		_apply_cell(r)
		applied += 1


func _free_cell(tier: int, key: int) -> void:
	var c: Dictionary = cells[tier][key]
	for n in c.nodes:
		if is_instance_valid(n):
			n.queue_free()
	for lk in c.colliders:
		if collider_hash.has(lk):
			var arr: Array = collider_hash[lk]
			arr = arr.filter(func(e): return e[3] != key)
			if arr.is_empty():
				collider_hash.erase(lk)
			else:
				collider_hash[lk] = arr
	for rid in c.res_ids:
		for i in range(res_nodes.size() - 1, -1, -1):
			if res_nodes[i].id == rid:
				if is_instance_valid(res_nodes[i].node):
					res_nodes[i].node.queue_free()
				res_nodes.remove_at(i)
	cells[tier].erase(key)


func _apply_cell(r: Dictionary) -> void:
	var d := planet.data
	var R := d.radius
	var tier: int = r.tier
	var cell := {"nodes": [], "colliders": [], "res_ids": [], "center": _cell_center_dir(r.face, r.i, r.j, r.ds)}
	# group items by flora spec -> one MultiMesh each
	var groups := {}
	for it in r.items:
		if not groups.has(it.si):
			groups[it.si] = []
		groups[it.si].append(it)
	for si in groups:
		var spec: Dictionary = d.flora[si]
		var arr: Array = groups[si]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ModelLib.mesh(spec.m, spec.tint)
		mm.instance_count = arr.size()
		for i in arr.size():
			var it: Dictionary = arr[i]
			var dir: Vector3 = it.dir
			var up := dir
			var tt := up.cross(Vector3.RIGHT)
			if tt.length() < 0.1:
				tt = up.cross(Vector3.FORWARD)
			tt = tt.normalized().rotated(up, it.yaw)
			var bas := Basis.looking_at(tt, up)
			var tilt: Vector2 = it.tilt
			bas = bas * Basis(Vector3.RIGHT, tilt.x) * Basis(Vector3.FORWARD, tilt.y)
			var sc: float = it.sc
			var sv := Vector3(sc, sc, sc)
			if spec.m == "grass_tuft":
				sv = Vector3(sc * 1.2, sc * randf_range(0.8, 1.3), sc * 1.2)
			bas = bas.scaled(sv)
			var pos := dir * (R + float(it.h) + float(spec.lift) * sc)
			mm.set_instance_transform(i, Transform3D(bas, pos))
			if float(spec.cr) > 0.0:
				var lk := Vector3i((pos / COLL_LATTICE).floor())
				if not collider_hash.has(lk):
					collider_hash[lk] = []
				collider_hash[lk].append([pos, float(spec.cr) * sc, float(spec.ch) * sc, r.key])
				cell.colliders.append(lk)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = RING[tier] * 1.08
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (tier == 0 and float(spec.ch) > 0.0) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		field_root.add_child(mmi)
		cell.nodes.append(mmi)
	for ri in r.res:
		var rd: Dictionary = d.resources[ri.ri]
		var node := ModelLib.instance("ore_node", {"ore_glow": rd.color})
		var dir: Vector3 = ri.dir
		var pos := dir * (R + float(ri.h) - 0.1)
		var tt := dir.cross(Vector3.RIGHT).normalized().rotated(dir, ri.yaw)
		field_root.add_child(node)
		node.transform = Transform3D(Basis.looking_at(tt, dir).scaled(Vector3.ONE * 1.4), pos)
		cell.nodes.append(node)
		cell.res_ids.append(ri.id)
		res_nodes.append({"id": ri.id, "node": node, "pos": pos, "type": rd.name, "color": rd.color, "amt": ri.amt, "cell": r.key})
	cells[tier][r.key] = cell


# ----------------------------------------------------------------------------- collisions (called by Player)
func resolve(np: Vector3, ndir: Vector3, _airborne: bool) -> Vector3:
	if collider_hash.is_empty() or planet == null:
		return np
	var out := np
	var base := Vector3i((np / COLL_LATTICE).floor())
	var feet_r := np.length()
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var lk := base + Vector3i(dx, dy, dz)
				if not collider_hash.has(lk):
					continue
				for e in collider_hash[lk]:
					var cp: Vector3 = e[0]
					var cr: float = e[1] + 0.45
					var ch: float = e[2]
					var up := cp.normalized()
					var rel := out - cp
					var hh := rel.dot(up)
					if hh > ch or hh < -1.5:
						continue
					var lat := rel - up * hh
					var dl := lat.length()
					if dl < cr and dl > 0.0001:
						out += lat / dl * (cr - dl)
	return out


# ----------------------------------------------------------------------------- mining / scanning
func _mining_update(w: World, dt: float) -> void:
	hint_text = ""
	if not w.on_foot or planet == null or w.player.frame != planet:
		_stop_mining(w)
		return
	var cam := w.cam
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var best: Dictionary = {}
	var best_ang := 0.075
	for r in res_nodes:
		if not is_instance_valid(r.node):
			continue
		var wp: Vector3 = planet.global_transform * ((r.pos as Vector3) + (r.pos as Vector3).normalized() * 0.8)
		var to := wp - origin
		var dist := to.length()
		if dist > 34.0 or dist < 0.5:
			continue
		var ang := fwd.angle_to(to)
		var near_p := (planet.global_transform * (r.pos as Vector3)).length()
		if near_p > 26.0 and ang > 0.03:
			continue
		if ang < best_ang:
			best_ang = ang
			best = r
	var holding := Input.is_action_pressed("mine") and Game.state == Game.State.PLAYING
	if not best.is_empty():
		hint_text = "[Hold LMB] Mine %s" % best.type
	if holding and not best.is_empty():
		if mine_target.is_empty() or mine_target.id != best.id:
			mine_target = best
			mine_prog = 0.0
		mine_prog += dt / 1.3
		w.player.mining = true
		mine_sfx_t -= dt
		if mine_sfx_t <= 0.0:
			Sfx.play("zap", -8.0, randf_range(0.9, 1.3))
			mine_sfx_t = 0.22
		var tip: Vector3 = w.player.parts["HandR"].global_position if w.player.parts.has("HandR") and w.player.parts["HandR"] != null and w.cam_mode != World.CamMode.FOOT1 else (w.fp_tool.global_position + cam.global_transform.basis * Vector3(0, 0, -0.45))
		var tgt: Vector3 = planet.global_transform * ((mine_target.pos as Vector3) + (mine_target.pos as Vector3).normalized() * 0.8)
		_draw_beam(tip, tgt)
		(mine_target.node as Node3D).scale = Vector3.ONE * (1.0 - mine_prog * 0.5)
		if mine_prog >= 1.0:
			_collect(mine_target, w)
			mine_target = {}
			mine_prog = 0.0
			beam.visible = false
	else:
		_stop_mining(w)


func _stop_mining(w: World) -> void:
	if not mine_target.is_empty() and is_instance_valid(mine_target.node):
		(mine_target.node as Node3D).scale = Vector3.ONE
	mine_target = {}
	mine_prog = 0.0
	beam.visible = false
	if w.player != null:
		w.player.mining = false


func _draw_beam(a: Vector3, b: Vector3) -> void:
	beam.visible = true
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var y := d / l
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var flick := 0.8 + 0.5 * randf()
	beam.global_transform = Transform3D(Basis(x * flick, y * l, z * flick), (a + b) * 0.5)


func _collect(r: Dictionary, w: World) -> void:
	Game.add_resource(r.type, int(r.amt))
	Game.msg("+%d %s" % [int(r.amt), r.type], "good")
	Sfx.play("chime", -2.0)
	_burst((r.node as Node3D).global_position, r.color)
	if is_instance_valid(r.node):
		r.node.queue_free()
	var seed: int = planet.data.seed
	if not mined.has(seed):
		mined[seed] = {}
	mined[seed][r.id] = true
	res_nodes.erase(r)
	for t in 2:
		for k in cells[t]:
			var c: Dictionary = cells[t][k]
			c.res_ids.erase(r.id)


func _burst(pos: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 28
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = m
	p.mesh = qm
	world.add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func do_scan(w: World) -> void:
	if planet == null or not w.on_foot:
		Game.msg("Scanner: stand on a planet surface", "info")
		return
	scan_t = 14.0
	scan_ring_t = 0.0
	Sfx.play("scan", -4.0)
	var n := 0
	for r in res_nodes:
		if is_instance_valid(r.node):
			n += 1
	Game.msg("Scan pulse: %d resource deposits, %d points of interest nearby" % [n, sites.size()], "info")
	for s in sites:
		Game.discovered[s.name + planet.display_name] = true


func harvest_hint() -> String:
	if not interact_site.is_empty():
		return "[E] %s" % interact_site.prompt
	return hint_text


# ----------------------------------------------------------------------------- site interaction
func _site_interact_update(w: World) -> void:
	interact_site = {}
	if not w.on_foot or planet == null or w.player.frame != planet:
		return
	for s in sites:
		var pos: Vector3 = (s.dir as Vector3) * (planet.radius + s.h)
		var d := pos.distance_to(w.player.lpos)
		var reach := 12.0
		match s.type:
			"monolith": reach = 8.0
			"tower": reach = 8.0
			"wreck": reach = 11.0
			"outpost": reach = 14.0
		if d < reach:
			var prompt := ""
			match s.type:
				"outpost": prompt = "Use supply terminal (restore suit & jetpack)"
				"monolith": prompt = "Touch the monolith"
				"wreck": prompt = "Salvage the wreck"
				"tower": prompt = "Activate the radio tower"
			if s.used and s.type != "outpost":
				continue
			interact_site = {"site": s, "prompt": prompt}
			return


func interact(w: World) -> bool:
	if interact_site.is_empty():
		return false
	var s: Dictionary = interact_site.site
	match s.type:
		"outpost":
			w.player.refill()
			Game.msg("Supply terminal: suit, hazard protection and jetpack fully restored.", "good")
			Sfx.play("chime")
		"monolith":
			s.used = true
			Sfx.play("scan", -2.0)
			if w.bh != null:
				w.ship.target_body = w.bh
				Game.msg("The monolith hums. A vision: a singularity far from the sun — %s lies beyond it. Navigation marked." % w.bh.dest_name, "good")
			else:
				Game.msg("The monolith hums. Faint coordinates of distant stars flicker in your visor.", "good")
		"wreck":
			s.used = true
			var rd: Dictionary = planet.data.resources[0] if planet.data.resources.size() > 0 else {"name": "Ferrite Dust"}
			Game.add_resource(rd.name, 6)
			Game.add_resource("Ferrite Dust", 4)
			Game.msg("Salvaged +6 %s, +4 Ferrite Dust from the wreck." % rd.name, "good")
			Sfx.play("chime")
		"tower":
			s.used = true
			scan_t = 20.0
			Game.msg("Radio tower online: nearby points of interest and deposits revealed.", "good")
			Sfx.play("scan")
	return true


# ----------------------------------------------------------------------------- fauna
func _fauna_update(w: World, dt: float) -> void:
	if planet == null or planet.data.fauna.is_empty():
		return
	var focus := _focus_local(w)
	var player_on := w.on_foot
	for c in creatures.duplicate():
		if not is_instance_valid(c):
			creatures.erase(c)
			continue
		(c as Creature).tick(dt, w.player.lpos if player_on and w.player.frame == planet else Vector3(1e9, 0, 0), player_on)
		if ((c as Creature).lpos).distance_to(focus) > 240.0 and (c as Creature).kind != "flyer":
			creatures.erase(c)
			c.queue_free()
		elif (c as Creature).kind == "flyer" and ((c as Creature).center * planet.radius).distance_to(focus) > 320.0:
			creatures.erase(c)
			c.queue_free()
	spawn_cd -= dt
	if spawn_cd <= 0.0 and creatures.size() < 7 and w.cam_alt < 300.0:
		spawn_cd = 2.5
		var kinds: Array = planet.data.fauna
		var kind: String = kinds[rng.randi() % kinds.size()].replace("creature_", "")
		var up := focus.normalized()
		var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var e1 := up.cross(ref).normalized()
		var e2 := up.cross(e1)
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(70.0, 160.0)
		var dir := (up * planet.radius + (e1 * cos(ang) + e2 * sin(ang)) * dist).normalized()
		var h := planet.data.height_at(dir)
		if planet.data.has_liquid() and h < planet.data.sea_level + 1.0 and kind == "strider":
			return
		var tint := {}
		var pal: Dictionary = planet.data.pal
		var base: Color = pal.get("mid", Color(0.5, 0.4, 0.3))
		tint["creature_skin"] = Color.from_hsv(fposmod(base.h + rng.randf_range(-0.1, 0.1), 1.0), rng.randf_range(0.35, 0.8), rng.randf_range(0.35, 0.85))
		tint["creature_skin2"] = Color.from_hsv(rng.randf(), 0.25, 0.85)
		tint["creature_glow"] = Color.from_hsv(rng.randf(), 0.8, 1.0)
		tint["floater_body"] = Color.from_hsv(rng.randf(), 0.55, 0.85)
		tint["floater_tentacle"] = Color.from_hsv(rng.randf(), 0.5, 0.95)
		var cr := Creature.new()
		field_root.add_child(cr)
		cr.setup(kind, planet.data, dir * (planet.radius + h), rng.randi(), tint)
		creatures.append(cr)


# ----------------------------------------------------------------------------- main update (called by World each frame)
func update(w: World, dt: float) -> void:
	var p := _pick_planet(w)
	if p != planet:
		_activate(p)
		if planet != null:
			_place_pad()
	if planet == null:
		weather.update_weather(w, dt, null, Vector3.UP, false)
		wind_level = 0.0
		_audio(w, null)
		_stop_mining(w)
		return
	var focus := _focus_local(w)
	_update_sites(focus)
	# scatter only when we are low / on foot
	var low := w.cam_alt < 420.0
	if low:
		for t in 2:
			tier_timer[t] -= dt
			if focus.distance_to(last_focus) > CELL[1] * 0.35 or tier_timer[t] <= 0.0:
				_update_tier(t, focus)
				tier_timer[t] = 0.6
		if focus.distance_to(last_focus) > CELL[1] * 0.35:
			last_focus = focus
		_collect_results()
	_mining_update(w, dt)
	_site_interact_update(w)
	if Input.is_action_just_pressed("scan") and w.on_foot and Game.state == Game.State.PLAYING:
		do_scan(w)
	scan_t = maxf(scan_t - dt, 0.0)
	_scan_ring_update(w, dt)
	_fauna_update(w, dt)
	var up := w.cam_up
	weather.update_weather(w, dt, planet.data, up, w.cam_alt < 900.0)
	wind_level = weather.level
	_audio(w, planet)


func _scan_ring_update(w: World, dt: float) -> void:
	if scan_ring_t < 2.0 and w.on_foot:
		scan_ring_t += dt
		scan_ring.visible = true
		var rr := scan_ring_t * 90.0
		scan_ring.global_position = w.player.global_position
		scan_ring.scale = Vector3.ONE * maxf(rr, 0.1)
		var m := scan_ring.material_override as StandardMaterial3D
		m.albedo_color.a = 0.14 * (1.0 - scan_ring_t / 2.0)
	else:
		scan_ring.visible = false


func _audio(w: World, p: Planet) -> void:
	if p == null or p.data.atmo_height <= 0.0 or w.cam_alt > 6000.0:
		Sfx.set_loop("wind", -80.0)
		Sfx.set_loop("atmo_roar", -80.0)
		return
	var dens := p.atmosphere_density_at(maxf(w.cam_alt, 0.0))
	var spd := w.ship.speed if not w.on_foot else w.player.speed_h * 4.0
	var lvl := clampf(spd / 220.0, 0.0, 1.0)
	Sfx.set_loop("wind", -30.0 + dens * 10.0 + lvl * 14.0 + wind_level * 10.0, 0.8 + lvl * 0.5)
	if not w.on_foot and w.ship.entry_heat > 0.05:
		Sfx.set_loop("atmo_roar", -24.0 + w.ship.entry_heat * 16.0, 0.8 + w.ship.entry_heat * 0.4)
	else:
		Sfx.set_loop("atmo_roar", -80.0)
