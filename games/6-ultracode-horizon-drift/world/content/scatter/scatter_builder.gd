class_name ScatterBuilder
extends RefCounted
## Worker-thread side of the scatter system (M7a): builds the instance buffers of ONE cell (all species of one layer) or the resource-node
## specs of one resource cell. Everything here is deterministic from (def.seed, layer, cell key, species index) and only reads
## planet.terrain_radius_at / normal_at (thread-safe by the Planet contract), so the same planet always scatters identically.

const COS_MARGIN := 2.0       # extra metres of clearance around POI footprints

var planet: Node3D
var R: float = 1000.0                       # base radius
var sea_h: float = -1.0e9                   # sea surface height above R (-1e9 = none)
var has_sea := false
var seed_value: int = 0
var n_cells: Array[int] = []                # per layer: cells per face edge
var species: Array = []                     # per layer: Array of species Dictionary (variant multipliers applied: "d_eff")
var noises: Dictionary = {}                 # "big" | "mid" | "fine" -> FastNoiseLite (read-only)
var poi_dirs: PackedVector3Array = PackedVector3Array()
var poi_ang: PackedFloat32Array = PackedFloat32Array()     # exclusion angle (radians) per POI
var poi_ang_small: PackedFloat32Array = PackedFloat32Array() # same for ground cover (grass / flowers / ferns may grow right up to the buildings)
var start_dir: Vector3 = Vector3.UP
var res_weights: Dictionary = {}
var res_rate: float = 0.5                   # expected resource clusters per resource cell
var res_cell: float = 80.0
var res_layer: int = 1

func setup(p_planet: Node3D, def: BodyDef, p_species: Array, p_noises: Dictionary, pois: Array) -> void:
	planet = p_planet
	R = def.radius
	var wl: Variant = p_planet.get("water_level")
	if wl != null and float(wl) > -1.0e8:
		has_sea = true
		sea_h = float(wl)
	seed_value = def.seed
	species = p_species
	noises = p_noises
	for L in FloraTables.LAYERS:
		n_cells.append(ScatterGrid.cells_per_face(R, float(L["cell"])))
	for p in pois:
		poi_dirs.append(p["dir"])
		var foot := float(p.get("foot", p["radius"])) + COS_MARGIN
		poi_ang.append(foot / R)
		poi_ang_small.append((clampf(float(p.get("foot", p["radius"])) * 0.55, 5.5, foot) + COS_MARGIN * 0.5) / R)
	start_dir = PoiSites.start_dir(def)
	res_weights = FloraTables.resource_weights(def.biome)

func _smooth(x: float, a: float, b: float) -> float:
	if b == a:
		return 1.0 if x >= a else 0.0
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _mask(sp: Dictionary, p: Vector3) -> float:
	var m = sp.get("mask")
	if m == null:
		return 1.0
	var nz: FastNoiseLite = noises[m[0]]
	var v := nz.get_noise_3d(p.x, p.y, p.z) * 0.5 + 0.5
	return _smooth(v, float(m[1]), float(m[2]))

func _excluded(d: Vector3, extra_m: float, small: bool = false) -> bool:
	for k in poi_dirs.size():
		var dd: float = d.dot(poi_dirs[k])
		if dd < 0.9992:
			continue
		if dd > cos((poi_ang_small[k] if small else poi_ang[k]) + extra_m / R):
			return true
	return false

## ---- vegetation / rocks ----------------------------------------------------------------------------------------------------------
## returns {"layer", "key", "origin": Vector3, "groups": [{"sp": int, "id": String, "n": int, "xf": PackedFloat32Array(16 per instance), "aabb": AABB}]}
func build_cell(layer: int, key: int, req: RefCounted) -> Dictionary:
	var n := n_cells[layer]
	var face := ScatterGrid.key_face(key, n)
	var ci := ScatterGrid.key_i(key, n)
	var cj := ScatterGrid.key_j(key, n)
	var cdir := ScatterGrid.center_dir(face, ci, cj, n)
	var cr: float = planet.terrain_radius_at(cdir)
	var origin: Vector3 = cdir * cr
	var area := ScatterGrid.cell_solid_angle(face, ci, cj, n) * R * R
	var edge := sqrt(area)
	var out_groups: Array = []
	var specs: Array = species[layer]
	for si in specs.size():
		if req.get("cancelled"):
			return {}
		var sp: Dictionary = specs[si]
		var d_eff: float = sp["d_eff"]
		if d_eff <= 0.0:
			continue
		var lam := d_eff * area / 1000.0
		var m := maxi(1, int(ceil(sqrt(lam * 1.2))))
		m = mini(m, 48)
		var p_acc := minf(lam / float(m * m), 1.0)
		var rng := SeedUtil.rng(SeedUtil.hash3(seed_value, layer * 1000003 + key, si + 1))
		var smin: float = sp["s"][0]
		var smax: float = sp["s"][1]
		var slope_cos := cos(deg_to_rad(float(sp["slope"])))
		var hmin: float = sp["hmin"]
		var hmax: float = sp["hmax"]
		var align: float = sp["align"]
		var sink: float = sp["sink"]
		var colv: float = sp.get("col", 0.15)
		var lift: Variant = sp.get("lift")
		var tilt: float = deg_to_rad(float(sp.get("tilt", 0.0)))
		var foot_extra: float = float(sp["foot_m"])
		var start_boost: float = float(sp.get("start_boost", 0.0))
		var small_foot: bool = String(sp["g"]) in ["ground", "flower"]
		var insts: Array = []     # [dir, r_ground, normal, scale, yaw, color_factor...]
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		var raw: Array = []
		for sy in m:
			for sx in m:
				var fx := (float(sx) + 0.15 + rng.randf() * 0.7) / float(m)
				var fy := (float(sy) + 0.15 + rng.randf() * 0.7) / float(m)
				var r_acc := rng.randf()
				var r_s := rng.randf()
				var r_yaw := rng.randf()
				var r_c1 := rng.randf()
				var r_c2 := rng.randf()
				var r_t1 := rng.randf()
				var r_t2 := rng.randf()
				var dir := ScatterGrid.point_dir(face, ci, cj, n, fx, fy)
				var pw := dir * R
				var pa := p_acc * _mask(sp, pw)
				if start_boost > 0.0:
					var dd := acos(clampf(dir.dot(start_dir), -1.0, 1.0)) * R
					pa *= 1.0 + start_boost * (1.0 - _smooth(dd, 45.0, 170.0))
				if r_acc >= pa:
					continue
				if _excluded(dir, foot_extra * lerpf(smin, smax, 0.5), small_foot):
					continue
				var rg: float = planet.terrain_radius_at(dir)
				var hs: float = rg - R - (sea_h if has_sea else 0.0)
				if has_sea:
					if hs < hmin or hs > hmax:
						continue
				elif hmax < 1.0e8 and rg - R > hmax:
					continue
				var nrm: Vector3 = planet.normal_at(dir)
				if nrm.dot(dir) < slope_cos:
					continue
				var sc := lerpf(smin, smax, r_s * r_s * 0.5 + r_s * 0.5)
				var up_v := dir.lerp(nrm, align).normalized()
				if tilt > 0.0:
					var side := up_v.cross(Vector3.RIGHT if absf(up_v.x) < 0.9 else Vector3.UP).normalized()
					up_v = up_v.rotated(side.rotated(up_v, r_t1 * TAU), (r_t2 - 0.5) * 2.0 * tilt).normalized()
				var ref := Vector3.RIGHT if absf(up_v.x) < 0.9 else Vector3.UP
				var t1 := up_v.cross(ref).normalized()
				var t2 := up_v.cross(t1)
				var yaw := r_yaw * TAU
				var zv := t1 * cos(yaw) + t2 * sin(yaw)
				var xv := up_v.cross(zv)
				var lift_m := 0.0
				if lift != null:
					lift_m = lerpf(float(lift[0]), float(lift[1]), r_t1)
				var pos: Vector3 = dir * (rg - sink * sc + lift_m)
				var rel: Vector3 = pos - origin
				raw.append([rel, xv * sc, up_v * sc, zv * sc, sc, r_c1, r_c2])
				mn = mn.min(rel)
				mx = mx.max(rel)
		if raw.is_empty():
			continue
		# deterministic shuffle so that "first N instances" thinning is spatially uniform
		var cnt := raw.size()
		for k in range(cnt - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = raw[k]
			raw[k] = raw[j]
			raw[j] = tmp
		var buf := PackedFloat32Array()
		buf.resize(cnt * 16)
		var ext := ScatterModels.extent(sp["id"]) * smax * 1.15 + 1.0
		for k in cnt:
			var e: Array = raw[k]
			var rel: Vector3 = e[0]
			var bx: Vector3 = e[1]
			var by: Vector3 = e[2]
			var bz: Vector3 = e[3]
			var o := k * 16
			buf[o + 0] = bx.x; buf[o + 1] = by.x; buf[o + 2] = bz.x; buf[o + 3] = rel.x
			buf[o + 4] = bx.y; buf[o + 5] = by.y; buf[o + 6] = bz.y; buf[o + 7] = rel.y
			buf[o + 8] = bx.z; buf[o + 9] = by.z; buf[o + 10] = bz.z; buf[o + 11] = rel.z
			var v := 1.0 + colv * (float(e[5]) * 2.0 - 1.0) * 0.55
			var hshift := colv * (float(e[6]) * 2.0 - 1.0) * 0.18
			buf[o + 12] = clampf(v * (1.0 + hshift), 0.2, 1.8)
			buf[o + 13] = clampf(v, 0.2, 1.8)
			buf[o + 14] = clampf(v * (1.0 - hshift), 0.2, 1.8)
			buf[o + 15] = 1.0
		out_groups.append({"sp": si, "id": sp["id"], "n": cnt, "xf": buf, "aabb": AABB(mn - Vector3(ext, ext, ext), (mx - mn) + Vector3(ext, ext, ext) * 2.0)})
	return {"layer": layer, "key": key, "origin": origin, "dir": cdir, "groups": out_groups}

## ---- resource nodes ---------------------------------------------------------------------------------------------------------------
## returns {"layer": 9, "key", "nodes": [{"res": "ferrite", "pos": Vector3, "up": Vector3, "scale": float, "id": String, "seed": int, "yaw": float}]}
func build_resources(key: int, req: RefCounted) -> Dictionary:
	var layer := res_layer
	var n := n_cells[layer]
	var face := ScatterGrid.key_face(key, n)
	var ci := ScatterGrid.key_i(key, n)
	var cj := ScatterGrid.key_j(key, n)
	var rng := SeedUtil.rng(SeedUtil.hash3(seed_value, 77777 + key, 5))
	var nodes: Array = []
	var ids := ["ferrite", "zyrite", "sodium", "voidstone"]
	var weights: Array = []
	for rid in ids:
		weights.append(float(res_weights.get(rid, 1.0)))
	var count := 0
	var r0 := rng.randf()
	var cd0 := ScatterGrid.center_dir(face, ci, cj, n)
	var rate := res_rate
	if acos(clampf(cd0.dot(start_dir), -1.0, 1.0)) * R < 150.0:
		rate = 1.0     # the area around the start pad is generous
	# clusters of one kind: 0..2 per cell
	var n_clusters := 0
	if r0 < rate:
		n_clusters = 1
	if r0 < rate * 0.25:
		n_clusters = 2
	for c in n_clusters:
		if req.get("cancelled"):
			return {}
		var kind_i := SeedUtil.pick_weighted(rng, weights)
		var rid: String = ids[kind_i]
		var fx := 0.1 + rng.randf() * 0.8
		var fy := 0.1 + rng.randf() * 0.8
		var d0 := ScatterGrid.point_dir(face, ci, cj, n, fx, fy)
		var k_nodes := 1
		match rid:
			"ferrite": k_nodes = 1 + rng.randi_range(0, 2)
			"zyrite": k_nodes = 1 + rng.randi_range(0, 2)
			"sodium": k_nodes = 2 + rng.randi_range(0, 2)
			_: k_nodes = 1
		var ang0 := rng.randf() * TAU
		for q in k_nodes:
			var dir := d0
			if q > 0:
				dir = ScatterGrid.walk(d0, ang0 + float(q) * 2.2, 3.5 + rng.randf() * 3.0, R)
			if _excluded(dir, 3.0):
				continue
			var rg: float = planet.terrain_radius_at(dir)
			var hs: float = rg - R - (sea_h if has_sea else 0.0)
			if has_sea and hs < 0.9:
				continue
			var nrm: Vector3 = planet.normal_at(dir)
			if nrm.dot(dir) < cos(deg_to_rad(36.0)):
				continue
			var sd := SeedUtil.hash3(seed_value, key * 8 + c * 4 + q, 4242)
			nodes.append({"res": rid, "pos": dir * rg, "up": dir.lerp(nrm, 0.6).normalized(), "scale": 0.85 + rng.randf() * 0.5, "id": "%d:r%d:%d:%d" % [seed_value, key, c, q], "seed": sd, "yaw": rng.randf() * TAU})
	return {"layer": 9, "key": key, "nodes": nodes}
