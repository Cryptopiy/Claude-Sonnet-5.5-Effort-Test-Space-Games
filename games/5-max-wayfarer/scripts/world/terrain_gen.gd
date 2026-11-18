class_name TerrainGen
extends RefCounted
## Planet terrain function + chunk mesh builder. Everything here is read-only after construction so it can be
## called from worker threads. Heights are metres above the base sphere (radius R).

const N: int = 32                      # cells per chunk side
const GRID: int = N + 3                # samples incl. one border sample on every side (for normals)
const NW: int = 16                     # water mesh cells per chunk side
const MAX_OCT: int = 7

const FACE_N := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const FACE_U := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
const FACE_V := [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0)]

var body: BodyData
var R: float = 3000.0
var max_level: int = 7
var prof: Dictionary
var tm: Dictionary
var seed_i: int = 1

# resolved terrain numbers
var amp_cont: float
var amp_hill: float
var amp_mount: float
var cont_bias: float
var detail_amp: float
var terrace: float
var terrace_step: float
var dune_amp: float
var dune_wl: float
var crater_str: float
var ridge_pow: float
var mount_t: float
var sea_h: float = -1e9
var lava_h: float = -1e9
var lake_h: float = -1e9
var has_sea: bool = false
var has_lava: bool = false
var has_lake: bool = false
var H: float = 100.0
var ref_h: float = 0.0

# noise (index = octave count)
var _n_cont: Array = []
var _n_hill: Array = []
var _n_ridge: Array = []
var _n_detail: Array = []
var _n_crater: Array = []
var _n_mmask: FastNoiseLite
var _n_tint: FastNoiseLite
var _n_tint2: FastNoiseLite
var _n_warp: FastNoiseLite
var _n_vein: FastNoiseLite
var _n_patch: FastNoiseLite
var _wl_cont: float
var _wl_hill: float
var _wl_mount: float
var _wl_detail: float
var _wl_crater: float
var _level_oct: Array = []             # per level: PackedInt32Array [cont, hill, ridge, detail, crater]
var _level_spacing: PackedFloat32Array = PackedFloat32Array()
var _level_size: PackedFloat32Array = PackedFloat32Array()

# cones (volcanoes)
var _cone_dirs: PackedVector3Array = PackedVector3Array()
var _cone_h: PackedFloat32Array = PackedFloat32Array()
var _cone_w: PackedFloat32Array = PackedFloat32Array()
# flat zones (outposts)
var _z_dir: PackedVector3Array = PackedVector3Array()
var _z_cos: PackedFloat32Array = PackedFloat32Array()
var _z_rin: PackedFloat32Array = PackedFloat32Array()
var _z_rout: PackedFloat32Array = PackedFloat32Array()
var _z_h: PackedFloat32Array = PackedFloat32Array()

# palette
var _pa_t: PackedFloat32Array = PackedFloat32Array()
var _pa_c: PackedColorArray = PackedColorArray()
var _pb_t: PackedFloat32Array = PackedFloat32Array()
var _pb_c: PackedColorArray = PackedColorArray()
var _rock_col: Color
var _rock_lo: float = 0.2
var _rock_hi: float = 0.5
var _snow_line: float = 9.0
var _veg_slope: float = 0.3
var _veg_from: float = 0.0
var _veg_to: float = 0.5
var _banded: bool = false
var _glow_veins: bool = false
var _ice: bool = false
var _lava_col: Color = Color(1.0, 0.3, 0.05)

var _idx_main: PackedInt32Array = PackedInt32Array()
var _idx_water: PackedInt32Array = PackedInt32Array()

func _init(b: BodyData) -> void:
	body = b
	R = b.radius
	prof = b.profile
	tm = prof["tm"]
	seed_i = b.seed_i
	amp_cont = tm["amp_cont"]
	amp_hill = tm["amp_hill"]
	amp_mount = tm["amp_mount"]
	cont_bias = tm["cont_bias"]
	detail_amp = tm["detail_amp"]
	terrace = tm["terrace"]
	terrace_step = tm["terrace_step"]
	dune_amp = tm["dune_amp"]
	dune_wl = tm["dune_wl"]
	crater_str = tm["crater"]
	ridge_pow = tm["ridge_pow"]
	mount_t = (1.0 - float(tm["mount_cover"])) * 1.3 - 0.65
	has_sea = tm["has_sea"]
	has_lava = tm["has_lava"]
	has_lake = tm["has_lake"]
	sea_h = tm["sea"]
	lava_h = tm["lava"]
	lake_h = tm["lake"]
	H = tm["H"]
	ref_h = sea_h if has_sea else 0.0
	_wl_cont = tm["wl_cont"]
	_wl_hill = tm["wl_hill"]
	_wl_mount = tm["wl_mount"]
	_wl_detail = tm["detail_wl"]
	_wl_crater = tm["crater_wl"] if tm["crater_wl"] > 1.0 else 900.0
	# max level: finest chunk ~ 45-70 m
	var face_arc: float = PI * 0.5 * R
	max_level = clampi(int(ceil(log(face_arc / 56.0) / log(2.0))), 4, 9)
	_build_noise()
	_build_levels(face_arc)
	_build_palette()
	_build_cones()
	_build_indices()
	_place_outposts()

# ---------------------------------------------------------------------------------------------------------
func _mk(type: int, wl: float, oct: int, sd: int, fractal: int = FastNoiseLite.FRACTAL_FBM, gain: float = 0.5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.seed = sd
	n.frequency = 1.0 / maxf(wl, 0.01)
	n.fractal_type = fractal if oct > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = maxi(oct, 1)
	n.fractal_lacunarity = 2.0
	n.fractal_gain = gain
	return n

func _build_noise() -> void:
	var s: int = seed_i * 131 + 17
	_n_cont = [null]
	_n_hill = [null]
	_n_ridge = [null]
	_n_detail = [null]
	_n_crater = [null]
	for o in range(1, MAX_OCT + 2):
		_n_cont.append(_mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, _wl_cont, o, s + 1))
		_n_hill.append(_mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, _wl_hill, o, s + 2))
		_n_ridge.append(_mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, _wl_mount, o, s + 3, FastNoiseLite.FRACTAL_RIDGED, 0.55))
		_n_detail.append(_mk(FastNoiseLite.TYPE_SIMPLEX, _wl_detail, o, s + 4, FastNoiseLite.FRACTAL_FBM, 0.5))
		var cn := FastNoiseLite.new()
		cn.noise_type = FastNoiseLite.TYPE_CELLULAR
		cn.seed = s + 5
		cn.frequency = 1.0 / _wl_crater
		cn.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		cn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		cn.cellular_jitter = 1.0
		cn.fractal_type = FastNoiseLite.FRACTAL_NONE
		_n_crater.append(cn)
	_n_mmask = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, _wl_mount * 2.2, 2, s + 6)
	_n_tint = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, R * 0.42, 2, s + 7)
	_n_tint2 = _mk(FastNoiseLite.TYPE_SIMPLEX, 38.0, 3, s + 8)
	_n_warp = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 260.0, 2, s + 9)
	_n_vein = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 55.0, 2, s + 10, FastNoiseLite.FRACTAL_RIDGED, 0.5)
	_n_patch = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 140.0, 2, s + 11)

func _build_levels(face_arc: float) -> void:
	_level_oct.clear()
	_level_spacing.resize(max_level + 2)
	_level_size.resize(max_level + 2)
	for L in range(0, max_level + 2):
		var size: float = face_arc / float(1 << L)
		var sp: float = size / float(N)
		_level_size[L] = size
		_level_spacing[L] = sp
		var floor_wl: float = 2.4 * sp
		var oc := PackedInt32Array()
		oc.append(_oct_for(_wl_cont, floor_wl, 5))
		oc.append(_oct_for(_wl_hill, floor_wl, 5))
		oc.append(_oct_for(_wl_mount, floor_wl, 6))
		oc.append(_oct_for(_wl_detail, floor_wl, 4))
		oc.append(1)
		_level_oct.append(oc)

func _oct_for(wl0: float, floor_wl: float, cap: int) -> int:
	if wl0 < floor_wl:
		return 0
	var k: int = int(floor(log(wl0 / floor_wl) / log(2.0))) + 1
	return clampi(k, 1, cap)

func _build_palette() -> void:
	for st in prof["pal_a"]:
		_pa_t.append(float(st[0]))
		_pa_c.append(st[1])
	for st in prof["pal_b"]:
		_pb_t.append(float(st[0]))
		_pb_c.append(st[1])
	_rock_col = (prof["rock"] as Color).srgb_to_linear()
	var rs: Array = prof["rock_slope"]
	_rock_lo = float(rs[0])
	_rock_hi = float(rs[1])
	_snow_line = float(prof["snow_line"])
	_veg_slope = float(prof.get("veg_max_slope", 0.3))
	_veg_from = float(prof.get("veg_from", 0.0))
	_veg_to = float(prof.get("veg_to", 0.5))
	_banded = bool(prof.get("banded", false))
	_glow_veins = bool(prof.get("glow_veins", false))
	_ice = bool(prof.get("ice", false))
	if prof.has("lava_color"):
		_lava_col = prof["lava_color"]

func _build_cones() -> void:
	var n: int = int(tm["cones"])
	var r := U.rng(seed_i * 977 + 5)
	for i in n:
		_cone_dirs.append(U.rand_unit(r))
		_cone_h.append(float(tm["cone_h"]) * r.randf_range(0.6, 1.25))
		_cone_w.append(float(tm["cone_w"]) * r.randf_range(0.7, 1.3))

func _build_indices() -> void:
	_idx_main.resize(N * N * 6 + 4 * N * 6)
	var k: int = 0
	var rowv: int = N + 1
	for j in N:
		for i in N:
			var a: int = j * rowv + i
			var b: int = a + 1
			var c: int = a + rowv
			var d: int = c + 1
			_idx_main[k] = a
			_idx_main[k + 1] = c
			_idx_main[k + 2] = b
			_idx_main[k + 3] = b
			_idx_main[k + 4] = c
			_idx_main[k + 5] = d
			k += 6
	# skirts: CCW circulation around the chunk; skirt vertex block follows the grid vertices
	var base: int = rowv * rowv
	for e in 4 * N:
		var e0: int = _skirt_edge_vertex(e)
		var e1: int = _skirt_edge_vertex(e + 1)
		var s0: int = base + e
		var s1: int = base + ((e + 1) % (4 * N))
		_idx_main[k] = e0
		_idx_main[k + 1] = e1
		_idx_main[k + 2] = s0
		_idx_main[k + 3] = e1
		_idx_main[k + 4] = s1
		_idx_main[k + 5] = s0
		k += 6
	# water grid
	var rw: int = NW + 1
	_idx_water.resize(NW * NW * 6)
	k = 0
	for j in NW:
		for i in NW:
			var a2: int = j * rw + i
			var b2: int = a2 + 1
			var c2: int = a2 + rw
			var d2: int = c2 + 1
			_idx_water[k] = a2
			_idx_water[k + 1] = c2
			_idx_water[k + 2] = b2
			_idx_water[k + 3] = b2
			_idx_water[k + 4] = c2
			_idx_water[k + 5] = d2
			k += 6

## index (0..4N) around the perimeter -> grid vertex index. Order: bottom (+U), right (+V), top (-U), left (-V)
func _skirt_edge_vertex(e: int) -> int:
	var rowv: int = N + 1
	var m: int = e % (4 * N)
	if m < N:
		return m                              # j=0, i=m
	if m < 2 * N:
		return (m - N) * rowv + N             # i=N, j=m-N
	if m < 3 * N:
		return N * rowv + (N - (m - 2 * N))   # j=N, i=N-(m-2N)
	return (N - (m - 3 * N)) * rowv           # i=0, j=N-(m-3N)

# ---------------------------------------------------------------------------------------------------------
## terrain height (metres above base sphere) for a unit direction. `level` selects octave counts (LOD).
func height(dir: Vector3, level: int) -> float:
	var h: float = height_raw(dir, level)
	if _z_dir.size() > 0 and _level_spacing[level] < 18.0:
		for i in _z_dir.size():
			var zd: Vector3 = _z_dir[i]
			if dir.dot(zd) > _z_cos[i]:
				var d: float = (dir - zd).length() * R
				if d < _z_rout[i]:
					var w: float = 1.0 - U.smooth(_z_rin[i], _z_rout[i], d)
					h = lerpf(h, _z_h[i], w)
	return h

func height_exact(dir: Vector3) -> float:
	return height(dir, max_level)

func height_raw(dir: Vector3, level: int) -> float:
	var p: Vector3 = dir * R
	var oc: PackedInt32Array = _level_oct[level]
	var c: float = cont_bias
	var o0: int = oc[0]
	if o0 > 0:
		c += (_n_cont[o0] as FastNoiseLite).get_noise_3dv(p)
	var h: float = c * amp_cont
	var o1: int = oc[1]
	if o1 > 0:
		var land: float = 0.55 + 0.45 * clampf(c * 2.5, -1.0, 1.0)
		h += (_n_hill[o1] as FastNoiseLite).get_noise_3dv(p) * amp_hill * land
	var o2: int = oc[2]
	if o2 > 0 and amp_mount > 0.0:
		var mm: float = _n_mmask.get_noise_3dv(p)
		var mask: float = U.smooth(mount_t - 0.22, mount_t + 0.22, mm)
		if mask > 0.002:
			var rr: float = ((_n_ridge[o2] as FastNoiseLite).get_noise_3dv(p) + 1.0) * 0.5
			rr = pow(clampf(rr, 0.0, 1.0), ridge_pow)
			h += mask * rr * amp_mount * (0.5 + 0.5 * clampf(c * 3.0 + 0.5, 0.0, 1.0))
	if crater_str > 0.0:
		h += _craters(p, level)
	if _cone_dirs.size() > 0:
		h += _cones(dir)
	var o3: int = oc[3]
	if o3 > 0:
		h += (_n_detail[o3] as FastNoiseLite).get_noise_3dv(p) * detail_amp
	if terrace > 0.0:
		var q: float = h / terrace_step
		var fq: float = q - floor(q)
		var stepped: float = (floor(q) + U.smooth(0.15, 0.85, fq)) * terrace_step
		h = lerpf(h, stepped, terrace)
	if dune_amp > 0.0 and _level_spacing[level] < dune_wl * 0.35:
		var wq: float = _n_warp.get_noise_3dv(p) * 2.2
		var s1: float = sin((p.x * 0.8 + p.z * 0.6) / dune_wl * TAU + wq * 3.0)
		h += (1.0 - absf(s1)) * dune_amp * U.smooth(-0.4, 0.5, c + 0.1)
	if has_lava and h < lava_h:
		h = lava_h
	elif has_lake and h < lake_h:
		h = lake_h
	return h

func _craters(p: Vector3, level: int) -> float:
	var out: float = 0.0
	var oc: FastNoiseLite = _n_crater[1]
	var d1: float = (oc.get_noise_3dv(p) + 1.0) * 0.5      # 0 at cell centre .. ~1 at far
	var rad1: float = 0.34
	if d1 < rad1 * 1.5:
		var t: float = d1 / rad1
		var bowl: float = -(1.0 - t * t) if t < 1.0 else 0.0
		var rim: float = exp(-pow((t - 1.05) * 4.5, 2.0))
		out += (bowl * 0.9 + rim * 0.35) * amp_mount * 0.9 * crater_str
	if _level_spacing[level] < 60.0:
		var p2: Vector3 = p * 3.1 + Vector3(17.0, 3.0, 9.0)
		var d2: float = (oc.get_noise_3dv(p2) + 1.0) * 0.5
		var rad2: float = 0.30
		if d2 < rad2 * 1.5:
			var t2: float = d2 / rad2
			var bowl2: float = -(1.0 - t2 * t2) if t2 < 1.0 else 0.0
			var rim2: float = exp(-pow((t2 - 1.05) * 4.5, 2.0))
			out += (bowl2 * 0.8 + rim2 * 0.3) * amp_mount * 0.28 * crater_str
	return out

func _cones(dir: Vector3) -> float:
	var out: float = 0.0
	for i in _cone_dirs.size():
		var cd: Vector3 = _cone_dirs[i]
		var w: float = _cone_w[i]
		if dir.dot(cd) > cos(minf(w * 1.2 / R, 1.5)):
			var d: float = (dir - cd).length() * R
			if d < w:
				var t: float = d / w
				var prof_h: float = pow(1.0 - t, 1.5) * _cone_h[i]
				var cal: float = 1.0 - U.smooth(0.0, 0.16, t)
				out += prof_h - cal * _cone_h[i] * 0.34
	return out

func _place_outposts() -> void:
	var r := U.rng(seed_i * 53 + 3)
	_z_dir.clear()
	_z_cos.clear()
	_z_rin.clear()
	_z_rout.clear()
	_z_h.clear()
	for o in body.outposts:
		var best: Vector3 = o["dir"]
		var best_score: float = -1e9
		var chosen: bool = false
		for attempt in 60:
			var dd: Vector3 = o["dir"] if attempt == 0 else U.rand_unit(r)
			if absf(dd.y) > 0.8:
				continue
			var hh: float = height_raw(dd, max_level)
			var up: Vector3 = dd
			var t1: Vector3 = U.any_perp(up)
			var t2: Vector3 = up.cross(t1)
			var off: float = 45.0 / R
			var hx1: float = height_raw((dd + t1 * off).normalized(), max_level)
			var hx2: float = height_raw((dd - t1 * off).normalized(), max_level)
			var hz1: float = height_raw((dd + t2 * off).normalized(), max_level)
			var hz2: float = height_raw((dd - t2 * off).normalized(), max_level)
			var rough: float = absf(hx1 - hx2) + absf(hz1 - hz2) + absf(hx1 + hx2 - 2.0 * hh) + absf(hz1 + hz2 - 2.0 * hh)
			var ok: bool = true
			if has_sea and hh < sea_h + 5.0:
				ok = false
			if has_lava and hh < lava_h + 12.0:
				ok = false
			if has_lake and hh < lake_h + 4.0:
				ok = false
			var score: float = -rough
			if ok and score > best_score:
				best_score = score
				best = dd
				chosen = true
				if rough < 6.0:
					break
		if not chosen:
			best = o["dir"]
		o["dir"] = best
		var fh: float = height_raw(best, max_level)
		o["flat_h"] = fh
		_z_dir.append(best)
		var ang: float = (float(o["r_out"]) + 4.0) / R
		_z_cos.append(cos(ang))
		_z_rin.append(float(o["r_in"]))
		_z_rout.append(float(o["r_out"]))
		_z_h.append(fh)

# ---------------------------------------------------------------------------------------------------------
func chunk_size(level: int) -> float:
	return _level_size[level]

func face_dir(face: int, u: float, v: float) -> Vector3:
	var n: Vector3 = FACE_N[face]
	var uu: Vector3 = FACE_U[face]
	var vv: Vector3 = FACE_V[face]
	return (n + uu * tan(u * PI * 0.25) + vv * tan(v * PI * 0.25)).normalized()

func chunk_center_dir(face: int, level: int, ix: int, iy: int) -> Vector3:
	var cells: float = float(1 << level)
	var u: float = -1.0 + 2.0 * (float(ix) + 0.5) / cells
	var v: float = -1.0 + 2.0 * (float(iy) + 0.5) / cells
	return face_dir(face, u, v)

func _pal(ts: PackedFloat32Array, cs: PackedColorArray, s: float) -> Color:
	var n: int = ts.size()
	if s <= ts[0]:
		return cs[0]
	for i in range(1, n):
		if s <= ts[i]:
			var f: float = (s - ts[i - 1]) / (ts[i] - ts[i - 1])
			return cs[i - 1].lerp(cs[i], f)
	return cs[n - 1]

## shading: returns linear colour (a = emission mask); m[0] = sheen/wet mask, m[1] = vegetation mask
func _shade(h: float, slope: float, p: Vector3, m: PackedFloat32Array, fine: bool) -> Color:
	var s: float = (h - ref_h) / H
	var tn: float = _n_tint.get_noise_3dv(p) * 0.5 + 0.5
	var wmix: float = U.smooth(0.35, 0.65, tn)
	var col: Color = _pal(_pa_t, _pa_c, s).lerp(_pal(_pb_t, _pb_c, s), wmix)
	var vn: float = 0.5
	if fine:
		vn = _n_tint2.get_noise_3dv(p) * 0.5 + 0.5
		var vv: float = 0.86 + 0.28 * vn
		col = Color(col.r * vv, col.g * vv, col.b * vv, 1.0)
	m[0] = 0.0
	m[1] = 0.0
	var emis: float = 0.0
	# vegetation / ground cover mask
	var veg: float = (1.0 - U.smooth(_veg_slope * 0.6, _veg_slope, slope)) * U.smooth(_veg_from, _veg_from + 0.03, s) * (1.0 - U.smooth(_veg_to * 0.7, _veg_to, s))
	m[1] = veg
	if _banded:
		var band: float = sin(h * 0.19 + _n_warp.get_noise_3dv(p) * 5.0) * 0.5 + 0.5
		var bf: float = 0.84 + 0.30 * band
		col = Color(col.r * bf, col.g * bf * (0.96 + 0.08 * band), col.b * bf * (0.9 + 0.2 * band), 1.0)
	# bare-soil patches inside vegetated areas (breaks up the flat ground colour)
	if veg > 0.25 and fine:
		var dpatch: float = (_n_patch.get_noise_3dv(p * 0.37 + Vector3(11.0, 5.0, 3.0)) + 1.0) * 0.5
		var dirt: float = U.smooth(0.60, 0.78, dpatch) * veg
		var dirt_col: Color = Color(_rock_col.r * 1.35 + 0.05, _rock_col.g * 1.15 + 0.03, _rock_col.b * 0.9 + 0.02, 1.0)
		col = col.lerp(dirt_col, dirt * 0.65)
		# lighter / darker meadow patches
		var mp: float = (_n_patch.get_noise_3dv(p * 0.91 + Vector3(2.0, 9.0, 7.0)) + 1.0) * 0.5
		var mpf: float = 0.84 + 0.32 * mp
		col = Color(col.r * mpf, col.g * mpf, col.b * mpf, 1.0)
	# rock on steep slopes
	var rk: float = U.smooth(_rock_lo, _rock_hi, slope)
	if rk > 0.0:
		var rv: float = 0.85 + 0.3 * (_n_tint2.get_noise_3dv(p * 1.7) * 0.5 + 0.5) if fine else 1.0
		col = col.lerp(Color(_rock_col.r * rv, _rock_col.g * rv, _rock_col.b * rv, 1.0), rk)
	# snow
	if _snow_line < 5.0:
		var sn: float = U.smooth(_snow_line, _snow_line + 0.14, s + 0.07 * (tn - 0.5) - slope * 0.55)
		if sn > 0.0:
			col = col.lerp(Color(0.80, 0.84, 0.92, 1.0).srgb_to_linear().lerp(Color(0.9, 0.95, 1.0), 0.6), sn)
			m[0] = maxf(m[0], sn * 0.5)
	if has_sea:
		var wet: float = 1.0 - U.smooth(0.0, 0.05, s)
		m[0] = maxf(m[0], wet)
	if _ice:
		var lowmask: float = 1.0 - U.smooth(0.02, 0.2, s)
		m[0] = maxf(m[0], lowmask * (1.0 - slope * 2.0))
	if has_lake and h <= lake_h + 0.05:
		m[0] = 1.0
		col = col.lerp(Color(0.55, 0.78, 1.0).srgb_to_linear(), 0.55)
	# lava
	if has_lava:
		var lv: float = 1.0 - U.smooth(lava_h + 0.2, lava_h + 14.0, h)
		if lv > 0.0:
			emis = maxf(emis, lv)
			col = col.lerp(Color(0.05, 0.03, 0.02, 1.0), lv * 0.6)
	if _glow_veins:
		var vein: float = (_n_vein.get_noise_3dv(p) + 1.0) * 0.5
		var vm: float = U.smooth(0.72, 0.88, vein) * (1.0 - U.smooth(0.2, 0.6, slope))
		emis = maxf(emis, vm * 0.65)
	return Color(col.r, col.g, col.b, emis)

# ---------------------------------------------------------------------------------------------------------
## Build one chunk. Returns a Dictionary of packed arrays (no scene objects -> thread safe).
func build_chunk(face: int, level: int, ix: int, iy: int, want_collider: bool, want_props: bool) -> Dictionary:
	var nrm: Vector3 = FACE_N[face]
	var fu: Vector3 = FACE_U[face]
	var fv: Vector3 = FACE_V[face]
	var cells: float = float(1 << level)
	var u0: float = -1.0 + 2.0 * float(ix) / cells
	var v0: float = -1.0 + 2.0 * float(iy) / cells
	var du: float = 2.0 / cells / float(N)
	var ta := PackedFloat32Array()
	var tb := PackedFloat32Array()
	ta.resize(GRID)
	tb.resize(GRID)
	for i in GRID:
		ta[i] = tan((u0 + float(i - 1) * du) * PI * 0.25)
		tb[i] = tan((v0 + float(i - 1) * du) * PI * 0.25)
	var cdir: Vector3 = chunk_center_dir(face, level, ix, iy)
	var center: Vector3 = cdir * R
	var pos := PackedVector3Array()
	var dirs := PackedVector3Array()
	var hs := PackedFloat32Array()
	pos.resize(GRID * GRID)
	dirs.resize(GRID * GRID)
	hs.resize(GRID * GRID)
	var min_h: float = 1e9
	var max_h: float = -1e9
	for j in GRID:
		var vb: Vector3 = nrm + fv * tb[j]
		for i in GRID:
			var d: Vector3 = (vb + fu * ta[i]).normalized()
			var h: float = height(d, level)
			var idx: int = j * GRID + i
			dirs[idx] = d
			hs[idx] = h
			pos[idx] = d * (R + h)
			if i > 0 and i < GRID - 1 and j > 0 and j < GRID - 1:
				if h < min_h:
					min_h = h
				if h > max_h:
					max_h = h
	var rowv: int = N + 1
	var nv: int = rowv * rowv + 4 * N
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nv)
	norms.resize(nv)
	cols.resize(nv)
	uvs.resize(nv)
	var mk := PackedFloat32Array([0.0, 0.0])
	var fine: bool = _level_spacing[level] < 40.0
	var spacing: float = _level_spacing[level]
	for j in rowv:
		for i in rowv:
			var gi: int = (j + 1) * GRID + (i + 1)
			var pc: Vector3 = pos[gi]
			var tu: Vector3 = pos[gi + 1] - pos[gi - 1]
			var tv: Vector3 = pos[gi + GRID] - pos[gi - GRID]
			var nn: Vector3 = tu.cross(tv).normalized()
			var vi: int = j * rowv + i
			verts[vi] = pc - center
			norms[vi] = nn
			var slope: float = 1.0 - nn.dot(dirs[gi])
			cols[vi] = _shade(hs[gi], slope, dirs[gi] * R, mk, fine)
			uvs[vi] = Vector2(mk[0], mk[1])
	# skirts
	var skirt: float = maxf(spacing * 1.6, 1.2)
	for e in 4 * N:
		var src: int = _skirt_edge_vertex(e)
		var si: int = rowv * rowv + e
		var sd: Vector3 = ((verts[src] + center).normalized())
		verts[si] = verts[src] - sd * skirt
		norms[si] = norms[src]
		cols[si] = cols[src]
		uvs[si] = uvs[src]
	var out: Dictionary = {
		"face": face, "level": level, "ix": ix, "iy": iy, "center": center, "cdir": cdir,
		"verts": verts, "norms": norms, "cols": cols, "uvs": uvs, "indices": _idx_main,
		"min_h": min_h, "max_h": max_h, "size": _level_size[level],
	}
	# water
	if has_sea and min_h < sea_h + 1.5:
		var rw: int = NW + 1
		var wv := PackedVector3Array()
		var wn := PackedVector3Array()
		wv.resize(rw * rw)
		wn.resize(rw * rw)
		var dw: float = 2.0 / cells / float(NW)
		for j in rw:
			var vv: float = v0 + float(j) * dw
			var vbw: Vector3 = nrm + fv * tan(vv * PI * 0.25)
			for i in rw:
				var uu: float = u0 + float(i) * dw
				var d2: Vector3 = (vbw + fu * tan(uu * PI * 0.25)).normalized()
				wv[j * rw + i] = d2 * (R + sea_h) - center
				wn[j * rw + i] = d2
		out["water"] = {"verts": wv, "norms": wn, "indices": _idx_water}
	# collision faces (finest level only)
	if want_collider:
		var faces := PackedVector3Array()
		faces.resize(N * N * 6)
		var k: int = 0
		for j in N:
			for i in N:
				var a: Vector3 = verts[j * rowv + i]
				var b: Vector3 = verts[j * rowv + i + 1]
				var c: Vector3 = verts[(j + 1) * rowv + i]
				var d3: Vector3 = verts[(j + 1) * rowv + i + 1]
				faces[k] = a
				faces[k + 1] = c
				faces[k + 2] = b
				faces[k + 3] = b
				faces[k + 4] = c
				faces[k + 5] = d3
				k += 6
		out["faces"] = faces
	if want_props:
		_scatter_props(out, face, level, ix, iy, center, want_collider)
	return out

# ---------------------------------------------------------------------------------------------------------
## Props are scattered on a fixed spatial grid ("prop cells") independent of chunk LOD, so a prop never changes
## position when a chunk is refined. Prop cell level = max_level + 1.
func _scatter_props(out: Dictionary, face: int, level: int, ix: int, iy: int, center: Vector3, want_colls: bool) -> void:
	var flora: Array = prof.get("flora", [])
	if flora.is_empty():
		return
	var pl: int = max_level + 1
	var sub: int = 1 << (pl - level)
	var cx0: int = ix * sub
	var cy0: int = iy * sub
	var pcells: float = float(1 << pl)
	var buckets: Array = []
	for e in flora.size():
		buckets.append(PackedFloat32Array())
	var colls: Array = []
	var cell_size: float = _level_size[pl]
	var cell_area: float = cell_size * cell_size
	var near_level: bool = level >= max_level
	var mk := PackedFloat32Array([0.0, 0.0])
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(flora.size())
	for cy in sub:
		for cx in sub:
			var gx: int = cx0 + cx
			var gy: int = cy0 + cy
			var cell_seed: int = U.hash3(seed_i * 31 + face, gx, gy)
			for e in flora.size():
				var fl: Dictionary = flora[e]
				if bool(fl.get("near_only", false)) and not near_level:
					continue
				var dens: float = float(fl["density"])
				var expect: float = dens * cell_area
				var eseed: int = U.hash2(cell_seed, e + 7)
				var cnt: int = int(floor(expect))
				if U.hf(eseed) < expect - float(cnt):
					cnt += 1
				if cnt <= 0:
					continue
				for k in cnt:
					var s2: int = U.hash2(eseed, k * 3 + 1)
					var fu_: float = U.hf(s2)
					var fv_: float = U.hf(s2 + 11)
					var uu: float = -1.0 + 2.0 * (float(gx) + fu_) / pcells
					var vv: float = -1.0 + 2.0 * (float(gy) + fv_) / pcells
					var dd: Vector3 = face_dir(face, uu, vv)
					var in_zone: bool = false
					for zi in _z_dir.size():
						if dd.dot(_z_dir[zi]) > _z_cos[zi] and (dd - _z_dir[zi]).length() * R < _z_rout[zi] + 5.0:
							in_zone = true
							break
					if in_zone:
						continue
					var hh: float = height(dd, max_level)
					var p: Vector3 = dd * R
					var s: float = (hh - ref_h) / H
					var sr: Array = fl["s"]
					if s < float(sr[0]) or s > float(sr[1]):
						continue
					if has_sea and hh < sea_h + 1.2:
						continue
					if has_lava and hh < lava_h + 10.0:
						continue
					if has_lake and hh < lake_h + 1.0:
						continue
					# slope from 2 extra samples
					var t1: Vector3 = U.any_perp(dd)
					var off: float = 2.5 / R
					var h1: float = height((dd + t1 * off).normalized(), max_level)
					var h2: float = height((dd + dd.cross(t1) * off).normalized(), max_level)
					var gx_: float = (h1 - hh) / 2.5
					var gz_: float = (h2 - hh) / 2.5
					var slope: float = 1.0 - 1.0 / sqrt(1.0 + gx_ * gx_ + gz_ * gz_)
					if slope > float(fl["slope_max"]):
						continue
					var veg_need: float = float(fl.get("veg", 0.0))
					var patch: float = (_n_patch.get_noise_3dv(p) + 1.0) * 0.5
					if veg_need > 0.0:
						var sh := _shade(hh, slope, p, mk, false)
						if mk[1] < veg_need * 0.6:
							continue
						if patch < 0.22 + veg_need * 0.25 and U.hf(s2 + 23) > patch * 2.0:
							continue
					# thin by random acceptance for density clustering
					var scl: Array = fl["scale"]
					var sc: float = lerpf(float(scl[0]), float(scl[1]), U.hf(s2 + 31))
					var yaw: float = U.hf(s2 + 41) * TAU
					var up: Vector3 = (dd * 1.0 + Vector3(-gx_, 0.0, -gz_) * 0.0).normalized()
					var nl: Vector3 = (dd - t1 * gx_ * 0.35 - dd.cross(t1) * gz_ * 0.35).normalized()
					var up2: Vector3 = dd.lerp(nl, 0.5).normalized()
					var fwd: Vector3 = U.any_perp(up2).rotated(up2, yaw)
					var bas: Basis = U.basis_from_up(up2, fwd).scaled(Vector3(sc, sc * (0.9 + 0.2 * U.hf(s2 + 53)), sc))
					var lp: Vector3 = dd * (R + hh) - center
					var arr: PackedFloat32Array = buckets[e]
					arr.append_array(PackedFloat32Array([
						bas.x.x, bas.y.x, bas.z.x, lp.x,
						bas.x.y, bas.y.y, bas.z.y, lp.y,
						bas.x.z, bas.y.z, bas.z.z, lp.z]))
					buckets[e] = arr
					counts[e] += 1
					if want_colls and bool(fl.get("collide", false)):
						colls.append([lp, e, sc, up2])
	var plist: Array = []
	for e in flora.size():
		if counts[e] > 0:
			plist.append({"entry": e, "count": counts[e], "xf": buckets[e]})
	out["props"] = plist
	out["colls"] = colls
