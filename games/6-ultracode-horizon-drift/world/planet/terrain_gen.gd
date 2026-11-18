class_name TerrainGen
extends RefCounted
## Deterministic, THREAD-SAFE terrain function of one planet (module M1): height (metres above the base radius) + vertex colour for a unit direction.
## Built once per Planet from its BodyDef; only reads immutable members afterwards (FastNoiseLite sampling is const), so worker threads can call it freely.
## Noise domain is the position on the sphere in metres (dir * radius), so features have the same metric size on every planet.

enum K { LUSH, DESERT, FROZEN, VOLCANIC, TOXIC, BARREN, OCEAN, EXOTIC, SWAMP, RADIOACTIVE }

var radius: float = 1000.0
var biome: String = "barren"
var kind: int = K.BARREN
var has_sea: bool = false
var sea: float = -1.0e9               # water level (m above radius), -1e9 = none
var amp: float = 1.0
var wind: Vector3 = Vector3.RIGHT
var prof: Dictionary = {}
var max_height: float = 600.0         # rough upper bound of |h| (for bounding volumes)

var n_cont: FastNoiseLite
var n_hills: FastNoiseLite
var n_ridge: FastNoiseLite
var n_det: FastNoiseLite
var n_det2: FastNoiseLite
var n_warp: FastNoiseLite
var n_cA: FastNoiseLite       # cellular distance (large)
var n_cAv: FastNoiseLite      # cellular cell value (large)
var n_cB: FastNoiseLite
var n_cBv: FastNoiseLite
var n_cC: FastNoiseLite
var n_cCv: FastNoiseLite
var n_cAe: FastNoiseLite      # cellular "distance to cell border" (0 at the border): fades features so they never end in a wall
var n_cBe: FastNoiseLite
var n_cCe: FastNoiseLite
var n_col: FastNoiseLite
var n_col2: FastNoiseLite
var n_aux1: FastNoiseLite
var n_aux2: FastNoiseLite
var n_aux3: FastNoiseLite
var n_mid: FastNoiseLite      # medium relief (~330 m wavelength): hills you can see from the ground
var n_esc: FastNoiseLite      # escarpment / cliff-step noise (~900 m)
var n_riv: FastNoiseLite      # river / gully lines (|noise| near 0)

var c0: Color
var c1: Color
var c2: Color
var c3: Color
var c4: Color
var c5: Color
var c6: Color

# POI flattening (copied on the main thread: PoiSites keeps a non-thread-safe cache)
var site_dir: PackedVector3Array = PackedVector3Array()
var site_rad: PackedFloat32Array = PackedFloat32Array()
var site_h: PackedFloat32Array = PackedFloat32Array()
var site_cos: PackedFloat32Array = PackedFloat32Array()
var site_blend: PackedFloat32Array = PackedFloat32Array()      # width (m) of the smooth transition from the flat site to the natural terrain (grows with the local relief: no cliffs)
var site_count: int = 0

static func _mk(seed_i: int, type: int, wavelength: float, fractal: int = FastNoiseLite.FRACTAL_NONE, octaves: int = 1, gain: float = 0.5, lac: float = 2.0) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.seed = seed_i & 0x3fffffff
	n.frequency = 1.0 / wavelength
	n.fractal_type = fractal
	if fractal != FastNoiseLite.FRACTAL_NONE:
		n.fractal_octaves = octaves
		n.fractal_gain = gain
		n.fractal_lacunarity = lac
	return n

static func _mkc(seed_i: int, wavelength: float, return_type: int, jitter: float = 0.9) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.seed = seed_i & 0x3fffffff
	n.frequency = 1.0 / wavelength
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = return_type
	n.cellular_jitter = jitter
	return n

func _init(def: BodyDef, sites: Array) -> void:
	radius = def.radius
	biome = def.biome
	prof = TerrainProfiles.get_profile(biome)
	match biome:
		"lush": kind = K.LUSH
		"desert": kind = K.DESERT
		"frozen": kind = K.FROZEN
		"volcanic": kind = K.VOLCANIC
		"toxic": kind = K.TOXIC
		"ocean": kind = K.OCEAN
		"exotic": kind = K.EXOTIC
		"swamp": kind = K.SWAMP
		"radioactive": kind = K.RADIOACTIVE
		_: kind = K.BARREN
	has_sea = def.has_ocean
	sea = float(prof["sea"]) if has_sea else -1.0e9
	var s: int = def.seed
	var rng := SeedUtil.rng(def.palette_seed, 11)
	amp = float(prof["amp"]) * rng.randf_range(0.85, 1.2)
	var wa := rng.randf() * TAU
	wind = Vector3(cos(wa), rng.randf_range(-0.3, 0.3), sin(wa)).normalized()
	var R := radius
	n_cont = _mk(SeedUtil.hash2(s, 1), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, R * 2.1, FastNoiseLite.FRACTAL_FBM, 3, 0.5)
	n_hills = _mk(SeedUtil.hash2(s, 2), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1150.0, FastNoiseLite.FRACTAL_FBM, 5, 0.5)
	n_ridge = _mk(SeedUtil.hash2(s, 3), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2900.0, FastNoiseLite.FRACTAL_RIDGED, 5, 0.55)
	n_det = _mk(SeedUtil.hash2(s, 4), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 70.0, FastNoiseLite.FRACTAL_FBM, 4, 0.5)
	n_det2 = _mk(SeedUtil.hash2(s, 5), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 7.0, FastNoiseLite.FRACTAL_FBM, 3, 0.5)
	n_warp = _mk(SeedUtil.hash2(s, 6), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 900.0)
	n_col = _mk(SeedUtil.hash2(s, 7), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 520.0, FastNoiseLite.FRACTAL_FBM, 3, 0.5)
	n_col2 = _mk(SeedUtil.hash2(s, 8), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 38.0, FastNoiseLite.FRACTAL_FBM, 2, 0.5)
	n_aux1 = _mk(SeedUtil.hash2(s, 9), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1500.0, FastNoiseLite.FRACTAL_FBM, 2, 0.5)
	n_aux2 = _mk(SeedUtil.hash2(s, 10), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3200.0)
	n_aux3 = _mk(SeedUtil.hash2(s, 11), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 600.0, FastNoiseLite.FRACTAL_RIDGED, 3, 0.5)
	n_mid = _mk(SeedUtil.hash2(s, 12), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 330.0, FastNoiseLite.FRACTAL_FBM, 3, 0.5)
	n_esc = _mk(SeedUtil.hash2(s, 13), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 900.0, FastNoiseLite.FRACTAL_FBM, 2, 0.5)
	n_riv = _mk(SeedUtil.hash2(s, 14), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 700.0)
	# cellular layers (craters / cones / pits): wavelength depends on the biome
	var wa_: float = 3300.0
	var wb_: float = 1000.0
	var wc_: float = 300.0
	match kind:
		K.VOLCANIC:
			wa_ = 2800.0
			wb_ = 650.0
			wc_ = 160.0
		K.TOXIC:
			wa_ = 700.0
			wb_ = 210.0
			wc_ = 80.0
		K.EXOTIC:
			wa_ = 900.0
			wb_ = 330.0
			wc_ = 120.0
		K.BARREN:
			wa_ = minf(3400.0, R * 0.65)
	n_cA = _mkc(SeedUtil.hash2(s, 21), wa_, FastNoiseLite.RETURN_DISTANCE)
	n_cAv = _mkc(SeedUtil.hash2(s, 21), wa_, FastNoiseLite.RETURN_CELL_VALUE)
	n_cB = _mkc(SeedUtil.hash2(s, 22), wb_, FastNoiseLite.RETURN_DISTANCE)
	n_cBv = _mkc(SeedUtil.hash2(s, 22), wb_, FastNoiseLite.RETURN_CELL_VALUE)
	n_cC = _mkc(SeedUtil.hash2(s, 23), wc_, FastNoiseLite.RETURN_DISTANCE)
	n_cCv = _mkc(SeedUtil.hash2(s, 23), wc_, FastNoiseLite.RETURN_CELL_VALUE)
	n_cAe = _mkc(SeedUtil.hash2(s, 21), wa_, FastNoiseLite.RETURN_DISTANCE2_SUB)
	n_cBe = _mkc(SeedUtil.hash2(s, 22), wb_, FastNoiseLite.RETURN_DISTANCE2_SUB)
	n_cCe = _mkc(SeedUtil.hash2(s, 23), wc_, FastNoiseLite.RETURN_DISTANCE2_SUB)
	# palette with a small per-planet variation (hue / value), derived from palette_seed
	var pal: Array = prof["pal"]
	var hue_shift := rng.randf_range(-0.035, 0.035)
	var val_mul := rng.randf_range(0.92, 1.08)
	var cols: Array = []
	for i in 7:
		var c: Color = pal[i]
		var hh := fposmod(c.h + hue_shift, 1.0)
		var cc := Color.from_hsv(hh, clampf(c.s * rng.randf_range(0.94, 1.06), 0.0, 1.0), clampf(c.v * val_mul, 0.0, 1.0))
		if c.s < 0.08:
			cc = Color(c.r * val_mul, c.g * val_mul, c.b * val_mul)
		cols.append(cc)
	c0 = cols[0]
	c1 = cols[1]
	c2 = cols[2]
	c3 = cols[3]
	c4 = cols[4]
	c5 = cols[5]
	c6 = cols[6]
	max_height = 700.0 * amp
	# --- POI sites
	for st in sites:
		if not bool(st.get("flat", false)):
			continue
		var d: Vector3 = (st["dir"] as Vector3).normalized()
		var r: float = float(st["radius"])
		site_dir.append(d)
		site_rad.append(r)
	site_count = site_dir.size()
	site_h.resize(site_count)
	site_blend.resize(site_count)
	site_cos.resize(site_count)
	for i in site_count:
		var dd := site_dir[i]
		# average of the unflattened terrain around the site centre
		var t1 := dd.cross(Vector3.UP if absf(dd.y) < 0.95 else Vector3.RIGHT).normalized()
		var t2 := dd.cross(t1)
		var rr := site_rad[i] * 0.8
		var hsum := _raw_height(dd)
		var cnt := 1.0
		for k in 6:
			var a := float(k) / 6.0 * TAU
			var q := (dd * R + (t1 * cos(a) + t2 * sin(a)) * rr).normalized()
			hsum += _raw_height(q)
			cnt += 1.0
		var target := hsum / cnt
		if has_sea:
			target = maxf(target, sea + 7.0)
		else:
			target = maxf(target, 1.0)
		site_h[i] = target
		# transition width: at least 1.4 r, wider where the natural relief around the site differs a lot from the flat target (slope stays <= ~14 deg)
		var dev := 0.0
		for ring in [1.5, 2.5, 4.0, 6.0]:
			for k2 in 8:
				var a2 := float(k2) / 8.0 * TAU
				var q2 := (dd * R + (t1 * cos(a2) + t2 * sin(a2)) * (site_rad[i] * float(ring))).normalized()
				dev = maxf(dev, absf(_raw_height(q2) - target))
		site_blend[i] = clampf(maxf(site_rad[i] * 1.4, dev * 4.0), site_rad[i] * 1.4, 240.0)
		site_cos[i] = cos(minf((site_rad[i] + site_blend[i]) / R, 1.0))

# ---------------------------------------------------------------------------------------------------------------------
# public
# ---------------------------------------------------------------------------------------------------------------------
func height(dir: Vector3) -> float:
	var h := _raw_height(dir)
	for i in site_count:
		var cd := dir.dot(site_dir[i])
		if cd < site_cos[i]:
			continue
		var dm := acos(minf(cd, 1.0)) * radius
		var r := site_rad[i]
		var w := 1.0 - smoothstep(r, r + site_blend[i], dm)
		if w > 0.0:
			h = lerpf(h, site_h[i], w)
	return h

func _site_boost(dir: Vector3) -> float:
	var b := 0.0
	for i in site_count:
		var cd := dir.dot(site_dir[i])
		if cd < 0.9:
			continue
		var dm := acos(minf(cd, 1.0)) * radius
		var r := site_rad[i]
		b = maxf(b, 1.0 - smoothstep(r * 1.6, r * 1.6 + 1100.0, dm))
	return b

func _raw_height(dir: Vector3) -> float:
	var p := dir * radius
	var h: float
	match kind:
		K.LUSH: h = _h_lush(p, dir)
		K.DESERT: h = _h_desert(p, dir)
		K.FROZEN: h = _h_frozen(p, dir)
		K.VOLCANIC: h = _h_volcanic(p, dir)
		K.TOXIC: h = _h_toxic(p, dir)
		K.OCEAN: h = _h_ocean(p, dir)
		K.EXOTIC: h = _h_exotic(p, dir)
		K.SWAMP: h = _h_swamp(p, dir)
		K.RADIOACTIVE: h = _h_radioactive(p, dir)
		_: h = _h_barren(p, dir)
	return h

# ---- small helpers -----------------------------------------------------------------------------------------------------
@warning_ignore("shadowed_global_identifier")
func _n(n: FastNoiseLite, p: Vector3) -> float:
	return n.get_noise_3d(p.x, p.y, p.z)

## cellular distance normalised to 0 (feature point) .. ~1 (cell border). FastNoiseLite returns about -0.82 .. -0.2.
func _cd(nz: FastNoiseLite, p: Vector3) -> float:
	return clampf((nz.get_noise_3d(p.x, p.y, p.z) + 0.82) / 0.62, 0.0, 1.3)

## 0 at the Voronoi cell border .. 1 well inside the cell
func _ce(nz: FastNoiseLite, p: Vector3) -> float:
	return smoothstep(0.0, 1.0, clampf((nz.get_noise_3d(p.x, p.y, p.z) + 1.0) / 0.3, 0.0, 1.0))

func _r01(v: float) -> float:
	return clampf(v * 0.5 + 0.5, 0.0, 1.0)

## smooth maximum (k = blend width)
func _smax(a: float, b: float, k: float) -> float:
	var hh := clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, hh) + k * hh * (1.0 - hh)

## crater profile: x = normalised distance from the crater centre (1.0 = rim crest), returns height in units of the crater depth
func _crater(x: float) -> float:
	if x > 1.6:
		return 0.0
	var bowl := 0.0
	if x < 1.0:
		var q := x / 1.0
		bowl = -(1.0 - q * q) * (1.0 - 0.35 * smoothstep(0.0, 0.35, q) * 0.0)
		bowl = maxf(bowl, -0.92 + 0.0)
	var rim := 0.22 * exp(-pow((x - 1.0) / 0.22, 2.0))
	var tail := 0.06 * exp(-pow((x - 1.25) / 0.4, 2.0))
	return bowl + rim + tail

func _crater_layer(nd: FastNoiseLite, nv: FastNoiseLite, ne: FastNoiseLite, p: Vector3, cell_wl: float, density_thr: float) -> float:
	var d := _cd(nd, p)       # 0 at the cell's feature point .. ~1 at the border
	var cv := nv.get_noise_3d(p.x, p.y, p.z)            # random in [-1,1] per cell
	if cv < density_thr:
		return 0.0
	var rd := 0.22 + 0.38 * (cv * 0.5 + 0.5)             # crater radius in cell-distance units (stays inside its Voronoi cell: no vertical walls)
	var depth := 0.13 * cell_wl * rd
	return _crater(d / rd) * depth * _ce(ne, p)

# ---------------------------------------------------------------------------------------------------------------------
# height functions per archetype
# ---------------------------------------------------------------------------------------------------------------------
func _finish_detail(h: float, p: Vector3, strength: float) -> float:
	return h + (n_det.get_noise_3d(p.x, p.y, p.z) * 4.2 + n_det2.get_noise_3d(p.x, p.y, p.z) * 0.55) * strength

func _h_lush(p: Vector3, dir: Vector3) -> float:
	var boost := _site_boost(dir)
	var cn := n_cont.get_noise_3d(p.x, p.y, p.z) * 1.55 + 0.16
	var c := cn + boost * 1.1
	var land := smoothstep(-0.12, 0.16, c)
	var hills := n_hills.get_noise_3d(p.x, p.y, p.z)
	var rid := _r01(n_ridge.get_noise_3d(p.x, p.y, p.z))
	var mtn := smoothstep(0.30, 0.95, cn)
	var mid := n_mid.get_noise_3d(p.x, p.y, p.z)
	# rolling hills: broad swells + medium knolls you can read from the ground
	var ground := 18.0 + hills * 46.0 + mid * 22.0 * (0.55 + 0.45 * land) + boost * 5.0
	# escarpments: stepped plateaus with steep (grey cliff) edges, only inland and away from the landing pad
	var esc := n_esc.get_noise_3d(p.x, p.y, p.z)
	var steps := smoothstep(0.20, 0.30, esc) * 30.0 + smoothstep(0.48, 0.58, esc) * 26.0
	ground += steps * smoothstep(0.12, 0.40, c) * (1.0 - clampf(boost * 1.6, 0.0, 1.0))
	# shallow river gullies
	var rv := absf(n_riv.get_noise_3d(p.x, p.y, p.z))
	ground -= (1.0 - smoothstep(0.012, 0.055, rv)) * 9.0 * smoothstep(0.2, 0.6, c) * (1.0 - clampf(boost * 1.6, 0.0, 1.0))
	var peaks := pow(rid, 2.0) * 470.0 * mtn + mtn * 60.0
	var h_land := (ground + peaks) * amp
	var seabed := -14.0 - (1.0 - smoothstep(-0.9, -0.1, c)) * 190.0 - (1.0 - land) * 20.0
	var h := lerpf(seabed, h_land, land)
	if not has_sea:
		h = _smax(h, 3.0 + hills * 9.0, 8.0)
	return _finish_detail(h, p, 0.25 + 0.75 * land)

func _h_ocean(p: Vector3, dir: Vector3) -> float:
	var boost := _site_boost(dir)
	var c := n_cont.get_noise_3d(p.x, p.y, p.z) * 1.7 - 0.30 + boost * 1.2
	var hills := n_hills.get_noise_3d(p.x, p.y, p.z)
	var isl := n_aux3.get_noise_3d(p.x, p.y, p.z)   # ridged: islands cluster
	var land := smoothstep(0.0, 0.28, c + 0.25 * hills)
	var rid := _r01(n_ridge.get_noise_3d(p.x, p.y, p.z))
	var h_land := 5.0 + hills * 9.0 + pow(rid, 1.5) * 55.0 * smoothstep(0.1, 0.6, c) + isl * 6.0
	var seabed := -9.0 - (1.0 - smoothstep(-0.8, 0.0, c)) * 150.0 - hills * 3.0
	var h := lerpf(seabed, h_land * amp, land)
	if not has_sea:
		h = _smax(h, 2.0, 6.0)
	return _finish_detail(h, p, 0.2 + 0.6 * land)

func _h_swamp(p: Vector3, dir: Vector3) -> float:
	var hills := n_hills.get_noise_3d(p.x, p.y, p.z)
	var pools := n_aux1.get_noise_3d(p.x, p.y, p.z)
	var hum := n_det.get_noise_3d(p.x, p.y, p.z)
	var h := 2.0 + hills * 5.5 + n_cont.get_noise_3d(p.x, p.y, p.z) * 14.0
	h += smoothstep(0.1, 0.5, pools) * -4.0 + hum * 1.4
	h += _site_boost(dir) * 5.0
	if not has_sea:
		h = _smax(h, 2.0, 3.0)
	return _finish_detail(h, p, 0.4)

func _h_desert(p: Vector3, dir: Vector3) -> float:
	# domain-warped, wind-stretched dunes
	var wq := p + Vector3(n_warp.get_noise_3d(p.x, p.y, p.z), _n(n_warp, p + Vector3(31.0, 17.0, 5.0)), _n(n_warp, p + Vector3(7.0, 41.0, 19.0))) * 260.0
	var along := wq.dot(wind)
	var q := wq + wind * (along * -0.62)                  # compress along the wind axis -> features are elongated 2.6x
	var big := _n(n_hills, q)                              # large dune bodies
	var crest := 1.0 - absf(_n(n_aux1, q * 1.8))          # sharp crest lines
	var dunes := big * 52.0 + pow(crest, 2.5) * 34.0 + _n(n_det, q * 0.3) * 9.0
	var med := _n(n_det, q * 0.55) * 4.5
	var mesa_n := _n(n_aux2, p + wind * 400.0) + n_hills.get_noise_3d(p.x, p.y, p.z) * 0.16
	var mesa_m := smoothstep(0.34, 0.44, mesa_n)           # plateaus
	var mesa_top := 52.0 + n_hills.get_noise_3d(p.x, p.y, p.z) * 5.0 + floorf(n_aux1.get_noise_3d(p.x, p.y, p.z) * 3.0 + 1.0) * 9.0
	var canyon_n := absf(_n(n_aux3, p * 0.5))
	var canyon := (1.0 - smoothstep(0.012, 0.06, canyon_n)) * 38.0 * (1.0 - mesa_m)
	var h := dunes + med
	h = lerpf(h, mesa_top + big * 3.0, mesa_m)
	var cliff_noise := _n(n_det, p * 3.0) * 6.0 * mesa_m * (1.0 - smoothstep(0.44, 0.6, mesa_n))
	h += cliff_noise
	h -= canyon * (1.0 - mesa_m * 0.0)
	h += n_ridge.get_noise_3d(p.x, p.y, p.z) * 22.0 * smoothstep(0.1, 0.7, n_cont.get_noise_3d(p.x, p.y, p.z))
	h *= amp
	h += _site_boost(dir) * 0.0
	return _finish_detail(h, p, 0.15)

func _h_frozen(p: Vector3, dir: Vector3) -> float:
	var plain := n_hills.get_noise_3d(p.x, p.y, p.z) * 28.0 + n_cont.get_noise_3d(p.x, p.y, p.z) * 36.0
	var mask := smoothstep(-0.05, 0.5, n_aux2.get_noise_3d(p.x, p.y, p.z))
	var rid := _r01(n_ridge.get_noise_3d(p.x, p.y, p.z))
	var ridges := pow(rid, 2.2) * 420.0 * mask
	var cr_n := absf(_n(n_aux3, p * 0.9 + Vector3(5, 9, 3)))
	var crev := (1.0 - smoothstep(0.012, 0.055, cr_n)) * 20.0 * (1.0 - mask * 0.7)
	var h := (plain + ridges) * amp - crev
	h += floorf(n_aux1.get_noise_3d(p.x, p.y, p.z) * 4.0) * 2.0 * 0.0
	if has_sea:
		h = _smax(h, 2.0, 4.0)
	return _finish_detail(h, p, 0.35)

func _h_volcanic(p: Vector3, dir: Vector3) -> float:
	var base := n_hills.get_noise_3d(p.x, p.y, p.z) * 22.0 + n_cont.get_noise_3d(p.x, p.y, p.z) * 30.0 + n_det.get_noise_3d(p.x, p.y, p.z) * 3.0
	var rid := _r01(n_ridge.get_noise_3d(p.x, p.y, p.z))
	base += pow(rid, 2.0) * 120.0 * smoothstep(0.0, 0.6, n_aux2.get_noise_3d(p.x, p.y, p.z))
	# volcanic cones from cellular cells
	var d := _cd(n_cA, p)
	var cv := n_cAv.get_noise_3d(p.x, p.y, p.z)
	var hcone := 0.0
	if cv > -0.25:
		var cone_h := 150.0 + 330.0 * (cv * 0.5 + 0.5)
		var t := clampf(1.0 - d / 0.62, 0.0, 1.0)
		hcone = (pow(t, 1.5) * cone_h - smoothstep(0.17, 0.0, d) * cone_h * 0.42) * _ce(n_cAe, p)        # + caldera
	var d2 := _cd(n_cB, p)
	var cv2 := n_cBv.get_noise_3d(p.x, p.y, p.z)
	var hsmall := 0.0
	if cv2 > 0.2:
		hsmall = (pow(clampf(1.0 - d2 / 0.5, 0.0, 1.0), 1.6) * (34.0 + 40.0 * cv2) - smoothstep(0.11, 0.0, d2) * 14.0) * _ce(n_cBe, p)
	# lava basins & rivers
	var basin_n := _n(n_aux1, p + Vector3(100, 0, 40))
	var basin := smoothstep(-0.12, -0.5, basin_n)
	var river_n := absf(_n(n_aux3, p * 0.8))
	var river := 1.0 - smoothstep(0.02, 0.07, river_n)
	var h := base * amp + hcone + hsmall
	h = lerpf(h, -22.0 + n_det.get_noise_3d(p.x, p.y, p.z) * 2.0, basin * (1.0 - smoothstep(60.0, 160.0, hcone)))
	h -= river * 26.0 * (1.0 - smoothstep(30.0, 120.0, hcone))
	if not has_sea:
		h = _smax(h, -2.0, 6.0)
	h += _site_boost(dir) * 0.0
	return _finish_detail(h, p, 0.45)

func _h_toxic(p: Vector3, dir: Vector3) -> float:
	var spore := n_hills.get_noise_3d(p.x, p.y, p.z) * 38.0 + n_cont.get_noise_3d(p.x, p.y, p.z) * 48.0
	# pits
	var d := _cd(n_cC, p)
	var cv := n_cCv.get_noise_3d(p.x, p.y, p.z)
	var pit := 0.0
	if cv > -0.1:
		pit = (-smoothstep(0.55, 0.12, d) * (3.0 + 4.0 * (cv * 0.5 + 0.5)) + exp(-pow((d - 0.62) / 0.12, 2.0)) * 0.9) * _ce(n_cCe, p)
	var d2 := _cd(n_cB, p)
	var cv2 := n_cBv.get_noise_3d(p.x, p.y, p.z)
	var bigpit := 0.0
	if cv2 > 0.0:
		bigpit = -smoothstep(0.6, 0.15, d2) * (10.0 + 12.0 * cv2) * _ce(n_cBe, p)
	# mounds
	var mound := pow(_r01(n_ridge.get_noise_3d(p.x, p.y, p.z)), 2.0) * 90.0 * smoothstep(0.0, 0.6, n_aux2.get_noise_3d(p.x, p.y, p.z))
	var h := (spore + mound) * amp + pit + bigpit
	if not has_sea:
		h = _smax(h, -1.0, 5.0)
	return _finish_detail(h, p, 0.4)

func _h_barren(p: Vector3, dir: Vector3) -> float:
	var h := n_hills.get_noise_3d(p.x, p.y, p.z) * 30.0 + n_cont.get_noise_3d(p.x, p.y, p.z) * 42.0
	var hl := _r01(n_ridge.get_noise_3d(p.x, p.y, p.z))
	h += pow(hl, 2.0) * 90.0 * smoothstep(0.0, 0.5, n_aux2.get_noise_3d(p.x, p.y, p.z))
	var wl_a: float = 1.0 / n_cA.frequency
	var wl_b: float = 1.0 / n_cB.frequency
	var wl_c: float = 1.0 / n_cC.frequency
	h += _crater_layer(n_cA, n_cAv, n_cAe, p, wl_a, -0.25)
	h += _crater_layer(n_cB, n_cBv, n_cBe, p, wl_b, -0.15)
	h += _crater_layer(n_cC, n_cCv, n_cCe, p, wl_c, -0.05)
	h += _crater_layer(n_cC, n_cCv, n_cCe, p * 3.3 + Vector3(11, 5, 3), wl_c / 3.3, 0.1)
	return _finish_detail(h * amp, p, 0.5)

func _h_exotic(p: Vector3, dir: Vector3) -> float:
	var wq := p + Vector3(n_warp.get_noise_3d(p.x, p.y, p.z), _n(n_warp, p + Vector3(13.0, 7.0, 29.0)), _n(n_warp, p + Vector3(3.0, 33.0, 11.0))) * 220.0
	var e := _n(n_hills, wq * 0.85) * 0.9 + n_cont.get_noise_3d(p.x, p.y, p.z) * 0.9
	var steps := 5.0
	var t := (e + 1.0) * 0.5 * steps
	var ft := floorf(t)
	var fr := t - ft
	var terr := ft + smoothstep(0.78, 0.97, fr)
	var h := terr * 34.0 - 40.0
	# crystal spikes / ridges
	var rid := _r01(n_ridge.get_noise_3d(p.x, p.y, p.z))
	h += pow(rid, 3.0) * 70.0 * smoothstep(0.1, 0.6, n_aux2.get_noise_3d(p.x, p.y, p.z))
	# craters/bowls from cells (soft)
	var d := _cd(n_cB, p)
	var cv := n_cBv.get_noise_3d(p.x, p.y, p.z)
	if cv > 0.35:
		h -= smoothstep(0.5, 0.1, d) * 26.0 * _ce(n_cBe, p)
	h += n_det.get_noise_3d(p.x, p.y, p.z) * 3.0
	h *= amp
	if has_sea:
		h = _smax(h, 2.0, 6.0)
	return _finish_detail(h, p, 0.2)

func _h_radioactive(p: Vector3, dir: Vector3) -> float:
	var h := n_hills.get_noise_3d(p.x, p.y, p.z) * 40.0 + n_cont.get_noise_3d(p.x, p.y, p.z) * 50.0
	h += pow(_r01(n_ridge.get_noise_3d(p.x, p.y, p.z)), 2.0) * 150.0 * smoothstep(0.0, 0.6, n_aux2.get_noise_3d(p.x, p.y, p.z))
	var cr_n := absf(n_aux3.get_noise_3d(p.x, p.y, p.z))
	h -= (1.0 - smoothstep(0.02, 0.09, cr_n)) * 14.0
	h += _crater_layer(n_cB, n_cBv, n_cBe, p, 1.0 / n_cB.frequency, 0.3) * 0.7
	return _finish_detail(h * amp, p, 0.4)

# ---------------------------------------------------------------------------------------------------------------------
# colour: returns sRGB colour, alpha = emission mask. `spacing` = vertex spacing in metres of the requesting LOD (fades fine noise at coarse LODs)
# ---------------------------------------------------------------------------------------------------------------------
func color_at(dir: Vector3, h: float, spacing: float) -> Color:
	var p := dir * radius
	var fine := clampf(38.0 / (spacing * 3.0) - 0.3, 0.0, 1.0)
	var m := n_col.get_noise_3d(p.x, p.y, p.z)
	var m2 := n_col2.get_noise_3d(p.x, p.y, p.z) * fine
	match kind:
		K.LUSH: return _c_lush(p, dir, h, m, m2, fine)
		K.OCEAN: return _c_ocean(p, dir, h, m, m2, fine)
		K.DESERT: return _c_desert(p, dir, h, m, m2, fine)
		K.FROZEN: return _c_frozen(p, dir, h, m, m2, fine)
		K.VOLCANIC: return _c_volcanic(p, dir, h, m, m2, fine, spacing)
		K.TOXIC: return _c_toxic(p, dir, h, m, m2, fine)
		K.EXOTIC: return _c_exotic(p, dir, h, m, m2, fine)
		K.SWAMP: return _c_swamp(p, dir, h, m, m2, fine)
		K.RADIOACTIVE: return _c_radioactive(p, dir, h, m, m2, fine)
	return _c_barren(p, dir, h, m, m2, fine)

func _c_lush(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	var hh := h - sea if has_sea else h
	# c0 sand, c1 dark grass, c2 light grass, c3 forest, c4 rock/highland, c5 snow, c6 dry grass
	if hh < -1.0:
		var depth := clampf(-hh / 45.0, 0.0, 1.0)
		return c0.darkened(0.12).lerp(Color(0.10, 0.30, 0.36), depth * 0.85)
	var col := c1.lerp(c2, clampf(0.5 + 0.9 * m + 0.5 * m2, 0.0, 1.0))
	var fo := n_aux1.get_noise_3d(p.x, p.y, p.z)
	var mm := n_mid.get_noise_3d(p.x, p.y, p.z)
	col = col.lerp(c3, smoothstep(-0.10, 0.30, fo + mm * 0.25 + m2 * 0.25) * 0.85)        # forest floor: dark green blobs
	col = col.lerp(c6, smoothstep(0.28, 0.62, m * 0.6 + m2 * 0.55 - fo * 0.2) * 0.65)      # dry meadow patches
	# hill crests are a touch paler (sun-bleached grass), gullies darker
	col = col.lerp(c2.lightened(0.18), smoothstep(30.0, 90.0, hh) * 0.25 * smoothstep(-0.2, 0.5, mm))
	if not has_sea:
		col = col.lerp(c0, 1.0 - smoothstep(0.8, 3.2, hh + m2 * 1.2 + m * 0.8))      # (with a sea the shader paints the beach per pixel)
	col = col.lerp(c4, smoothstep(210.0, 380.0, hh + m * 90.0))
	col = col.lerp(c5, smoothstep(520.0, 650.0, hh + m * 70.0 + m2 * 20.0))
	var pol := smoothstep(0.88, 0.97, absf(dir.y) + m * 0.04)
	col = col.lerp(c5, pol)
	col.a = 0.0
	return col

func _c_ocean(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 beach sand, c1 dark grass, c2 grass, c3 shallows/coral, c4 deep, c5 rock, c6 sand2
	var hh := h - sea if has_sea else h
	if hh < 0.0:
		var depth := clampf(-hh / 40.0, 0.0, 1.0)
		var sh := c0.lerp(c3, smoothstep(0.0, 6.0, -hh))
		var col2 := sh.lerp(c4, smoothstep(5.0, 40.0, -hh))
		col2 = col2.lerp(c3.lightened(0.1), (0.5 + 0.5 * m2) * (1.0 - depth) * 0.35)
		col2.a = 0.0
		return col2
	var col := c1.lerp(c2, clampf(0.5 + 0.8 * m + 0.3 * m2, 0.0, 1.0))
	if not has_sea:
		col = col.lerp(c0, 1.0 - smoothstep(1.8, 7.0, hh + m2 * 1.5))
	col = col.lerp(c5, smoothstep(30.0, 60.0, hh + m * 12.0))
	col.a = 0.0
	return col

func _c_desert(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 orange sand, c1 red sand, c2 pale sand, c3 red strata, c4 ochre strata, c5 dark strata, c6 bright dune crest
	var col := c0.lerp(c1, clampf(0.5 + 0.9 * m, 0.0, 1.0))
	col = col.lerp(c2, smoothstep(0.0, 0.8, n_aux1.get_noise_3d(p.x, p.y, p.z) * 0.8 + m2 * 0.25) * 0.7)
	col = col.lerp(c6, smoothstep(0.35, 0.9, _n(n_det, p * 0.5)) * 0.18)
	# mesa strata (bands by height)
	var strata := 0.5 + 0.5 * sin(h * 0.55 + m * 3.0)
	var is_mesa := smoothstep(30.0, 60.0, h)
	var scol := c3.lerp(c4, strata).lerp(c5, smoothstep(0.7, 1.0, 0.5 + 0.5 * sin(h * 0.19 + 1.7)) * 0.7)
	col = col.lerp(scol, is_mesa)
	var low := smoothstep(-12.0, -45.0, h)       # canyon floors: darker
	col = col.lerp(c5, low * 0.6)
	col.a = 0.0
	return col

func _c_frozen(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 snow, c1 pale ice, c2 deep ice, c3 dark rock, c4 light snow blue, c5 mid ice, c6 white
	var col := c0.lerp(c4, clampf(0.5 + 0.6 * m + 0.4 * m2, 0.0, 1.0))
	col = col.lerp(c1, smoothstep(0.2, 0.7, n_aux1.get_noise_3d(p.x, p.y, p.z)) * 0.5)
	# glacier ice patches
	col = col.lerp(c5, smoothstep(0.3, 0.8, -n_hills.get_noise_3d(p.x, p.y, p.z) + m2 * 0.3) * 0.45)
	var cr_n := absf(_n(n_aux3, p * 0.9 + Vector3(5, 9, 3)))
	var crev := 1.0 - smoothstep(0.012, 0.06, cr_n)
	col = col.lerp(c2, crev * (0.45 + 0.4 * smoothstep(-0.1, 0.4, n_aux1.get_noise_3d(p.x, p.y, p.z))))        # crevasse tint (varies, no uniform outlines)
	col = col.lerp(c3, smoothstep(180.0, 300.0, h + m * 60.0) * 0.8)
	col.a = 0.0
	if has_sea and h < sea + 1.5:
		col = col.lerp(c2, 0.8)
	return col

func _c_volcanic(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float, spacing: float) -> Color:
	# c0 basalt black, c1 ash grey, c2 reddish cone rock, c3 obsidian, c4 deep lava bed, c5 pale ash, c6 lava glow
	var col := c0.lerp(c1, clampf(0.5 + 0.9 * m + 0.4 * m2, 0.0, 1.0))
	col = col.lerp(c3, smoothstep(0.3, 0.8, n_aux1.get_noise_3d(p.x, p.y, p.z)) * 0.7)
	col = col.lerp(c2, smoothstep(0.1, 0.8, n_aux2.get_noise_3d(p.x, p.y, p.z)) * smoothstep(40.0, 200.0, h) * 0.7)
	col = col.lerp(c5, smoothstep(0.5, 0.95, m2 + m * 0.4) * 0.35)
	col = col.lerp(c5, smoothstep(300.0, 420.0, h))
	var emit := 0.0
	var lvl := sea if has_sea else -12.0
	# glowing cracks: thin ridged veins, stronger in the lowlands
	var cr := absf(_n(n_aux3, p * 1.7 + Vector3(2, 4, 8)))
	var crack := 1.0 - smoothstep(0.0, 0.035 + 0.02 * (spacing / 30.0), cr)
	crack *= smoothstep(-0.12, 0.30, n_aux1.get_noise_3d(p.x, p.y, p.z) + m2 * 0.15)        # veins only in some regions (no endless drawn rings)
	var lowland := 1.0 - smoothstep(10.0, 90.0, h)
	emit = crack * lowland * 0.9
	# lava banks & rivers
	var river_n := absf(_n(n_aux3, p * 0.8))
	var river := 1.0 - smoothstep(0.02, 0.06, river_n)
	if h < lvl + 3.0:
		var bed := smoothstep(lvl + 3.0, lvl - 6.0, h)
		col = col.lerp(c4, bed)
		emit = maxf(emit, bed)
	elif river > 0.0:
		emit = maxf(emit, river * 0.5 * (1.0 - smoothstep(20.0, 80.0, h)))
	col.a = clampf(emit, 0.0, 1.0)
	return col

func _c_toxic(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 purple, c1 olive green, c2 acid yellow, c3 dark pit, c4 magenta fungus, c5 green moss, c6 glow
	var col := c0.lerp(c4, clampf(0.4 + 0.8 * m, 0.0, 1.0) * 0.6)
	col = col.lerp(c1, smoothstep(0.1, 0.7, n_aux1.get_noise_3d(p.x, p.y, p.z) + m2 * 0.3) * 0.5)
	col = col.lerp(c5, smoothstep(0.3, 0.8, m2 * 0.7 + m * 0.4) * 0.3)
	col = col.lerp(c2, smoothstep(0.55, 0.9, n_aux2.get_noise_3d(p.x, p.y, p.z) + m2 * 0.25) * 0.4)
	var d := _cd(n_cC, p)
	var cv := n_cCv.get_noise_3d(p.x, p.y, p.z)
	if cv > -0.1:
		col = col.lerp(c3, smoothstep(0.7, 0.15, d) * 0.85 * clampf(fine + 0.3, 0.0, 1.0))
	var lvl := sea if has_sea else -1.5
	var emit := smoothstep(0.80, 0.94, _n(n_aux3, p * 1.4) * 0.5 + 0.5 + m2 * 0.04) * 0.7
	if h < lvl + 1.5:
		col = col.lerp(c3, 0.6)
		emit = maxf(emit, 0.4)
	col.a = emit
	return col

func _c_barren(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 regolith, c1 dark regolith, c2 bright rim dust, c3 crater floor, c4 brown tint, c5 mid grey, c6 bright
	var col := c0.lerp(c1, clampf(0.5 + 0.8 * m + 0.4 * m2, 0.0, 1.0))
	col = col.lerp(c4, smoothstep(0.1, 0.7, n_aux1.get_noise_3d(p.x, p.y, p.z)) * 0.35)
	var d := _cd(n_cB, p)
	var cv := n_cBv.get_noise_3d(p.x, p.y, p.z)
	if cv > -0.15:
		var x := d / (0.22 + 0.38 * (cv * 0.5 + 0.5))
		var eb := _ce(n_cBe, p)
		col = col.lerp(c3, smoothstep(0.85, 0.3, x) * 0.5 * eb)
		col = col.lerp(c2, exp(-pow((x - 1.05) / 0.25, 2.0)) * 0.55 * eb)
	var da := _cd(n_cA, p)
	var cva := n_cAv.get_noise_3d(p.x, p.y, p.z)
	if cva > -0.25:
		var xa := da / (0.22 + 0.38 * (cva * 0.5 + 0.5))
		var ea := _ce(n_cAe, p)
		col = col.lerp(c3, smoothstep(0.85, 0.2, xa) * 0.55 * ea)
		col = col.lerp(c2, exp(-pow((xa - 1.05) / 0.25, 2.0)) * 0.5 * ea)
		# ejecta rays
	col = col.lerp(c5, smoothstep(0.5, 0.9, m2) * 0.25)
	col.a = 0.0
	return col

func _c_exotic(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 magenta, c1 cyan, c2 violet, c3 gold, c4 dark violet, c5 pink, c6 glow cyan
	var t := (h + 40.0) / 34.0
	var band := fposmod(t, 1.0)
	var idx := floorf(t)
	var pick := fposmod(idx + floorf(n_aux1.get_noise_3d(p.x, p.y, p.z) * 4.0 + 2.0), 4.0)
	var cc: Color = c0
	if pick < 1.0:
		cc = c0
	elif pick < 2.0:
		cc = c1
	elif pick < 3.0:
		cc = c2
	else:
		cc = c5
	var col := c4.lerp(cc, 0.9 + 0.1 * m2)
	col = col.lerp(c4, smoothstep(0.85, 1.0, band) * 0.12)
	col = col.lerp(c3, smoothstep(0.55, 0.85, n_aux1.get_noise_3d(p.x, p.y, p.z) * 0.6 + m * 0.4) * 0.6)
	var cr := absf(_n(n_aux3, p * 1.3))
	var vein := 1.0 - smoothstep(0.0, 0.05, cr)
	col = col.lerp(c6, vein * 0.8)
	col.a = clampf(vein * 0.85 + smoothstep(0.7, 0.9, m2) * 0.0, 0.0, 1.0)
	return col

func _c_swamp(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 olive, c1 mud, c2 moss, c3 murky bed, c4 yellow-grass, c5 brown, c6 glow
	var hh := h - sea if has_sea else h
	if hh < 0.0:
		return c3.lerp(c1, 0.5)
	var col := c0.lerp(c2, clampf(0.5 + 0.9 * m, 0.0, 1.0))
	col = col.lerp(c1, smoothstep(0.0, 0.5, m2 * 0.7 + n_aux1.get_noise_3d(p.x, p.y, p.z) * 0.5) * 0.7)
	col = col.lerp(c4, smoothstep(0.4, 0.85, m * 0.6 + m2 * 0.5) * 0.4)
	col = col.lerp(c1, 1.0 - smoothstep(0.0, 1.8, hh))
	col.a = smoothstep(0.7, 0.95, n_aux3.get_noise_3d(p.x, p.y, p.z) * 0.5 + 0.5) * 0.25
	return col

func _c_radioactive(p: Vector3, dir: Vector3, h: float, m: float, m2: float, fine: float) -> Color:
	# c0 yellow-green, c1 grey-brown, c2 bright yellow, c3 dark, c4 tan, c5 olive, c6 glow
	var col := c1.lerp(c0, clampf(0.45 + 0.9 * m, 0.0, 1.0))
	col = col.lerp(c4, smoothstep(0.1, 0.7, n_aux1.get_noise_3d(p.x, p.y, p.z)) * 0.5)
	col = col.lerp(c2, smoothstep(0.55, 0.9, m2 + m * 0.5) * 0.45)
	var cr := absf(n_aux3.get_noise_3d(p.x, p.y, p.z))
	var crack := 1.0 - smoothstep(0.02, 0.09, cr)
	col = col.lerp(c3, crack * 0.8)
	col.a = clampf(crack * 0.75 + smoothstep(0.78, 0.95, _n(n_aux2, p * 3.0) * 0.5 + 0.5) * 0.4, 0.0, 1.0)
	return col
