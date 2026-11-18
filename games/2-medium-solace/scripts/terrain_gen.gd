class_name TerrainGen
extends RefCounted
## Thread-safe planet terrain: height field, vertex colours, tile meshes and prop placement.

const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]

var R := 2000.0
var seed_ := 1
var def: Dictionary
var T: Dictionary
var C: Dictionary
var has_sea := false
var sea := 0.0
var floor_depth := 4.0
var has_lava := false
var lava_h := 0.0
var h_lo := -50.0
var h_hi := 150.0
var flats: Array = []   # {dir, h, r0, r1, pad_r, pad_h}

var n_base: FastNoiseLite
var n_ridge: FastNoiseLite
var n_mask: FastNoiseLite
var n_crater: FastNoiseLite
var n_detail: FastNoiseLite
var n_col: FastNoiseLite
var f_base := 0.0
var f_ridge := 0.0
var f_mask := 0.0
var f_crater := 0.0
var f_col := 0.004
var a_base := 0.0
var a_ridge := 0.0
var a_crater := 0.0
var a_detail := 1.0
var lift := 0.0
var terrace := 0.0

static func face_dir(face: int, u: float, v: float) -> Vector3:
	var f: Array = FACES[face]
	return (f[0] + f[1] * u + f[2] * v).normalized()

func _mk(type: int, octaves: int, off: int, gain := 0.5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.seed = seed_ + off
	n.frequency = 1.0
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
		n.fractal_gain = gain
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n

func setup(radius: float, p_def: Dictionary, p_seed: int) -> void:
	R = radius
	def = p_def
	seed_ = p_seed
	T = def["terrain"]
	C = def["colors"]
	a_base = T.get("base_a", 20.0)
	f_base = 1.0 / T.get("base_wl", 600.0)
	a_ridge = T.get("ridge_a", 0.0)
	f_ridge = 1.0 / T.get("ridge_wl", 400.0)
	f_mask = 1.0 / T.get("mask_wl", 1200.0)
	a_crater = T.get("crater_a", 0.0)
	f_crater = 1.0 / T.get("crater_wl", 500.0)
	a_detail = T.get("detail_a", 1.0)
	lift = T.get("lift", 0.0)
	terrace = T.get("terrace", 0.0)
	has_sea = T.has("sea")
	sea = T.get("sea", 0.0)
	has_lava = T.has("lava")
	lava_h = T.get("lava", 0.0)
	n_base = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 5, 1)
	n_ridge = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4, 2)
	n_mask = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2, 3)
	n_crater = _mk(FastNoiseLite.TYPE_CELLULAR, 1, 4)
	n_crater.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	n_detail = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3, 5)
	n_col = _mk(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2, 6)
	h_lo = lift - a_base
	h_hi = lift + a_base + a_ridge
	if has_lava:
		h_lo = lava_h
	if a_crater > 0.0:
		h_lo = lift - a_base - a_crater

func height(d: Vector3) -> float:
	var p := d * R
	var h := n_base.get_noise_3dv(p * f_base) * a_base + lift
	if a_ridge > 0.0:
		var m := smoothstep(-0.15, 0.45, n_mask.get_noise_3dv(p * f_mask))
		var r := 1.0 - absf(n_ridge.get_noise_3dv(p * f_ridge))
		h += r * r * a_ridge * m
	if a_crater > 0.0:
		var c := n_crater.get_noise_3dv(p * f_crater)
		var bowl := smoothstep(-1.0, -0.35, c)
		h += a_crater * (bowl - 1.0)
		h += a_crater * 0.35 * exp(-pow((c + 0.28) * 7.0, 2.0))
	if terrace > 0.0:
		var q := floorf(h / terrace)
		var fr := h / terrace - q
		h = (q + smoothstep(0.3, 0.7, fr)) * terrace
	h += n_detail.get_noise_3dv(p * 0.05) * a_detail
	if has_lava:
		h = maxf(h, lava_h - 6.0)
	for fl in flats:
		var chord := (d - (fl["dir"] as Vector3)).length() * R
		if chord < fl["r1"]:
			var w := smoothstep(fl["r0"], fl["r1"], chord)
			h = lerpf(fl["h"], h, w)
			if chord < fl["pad_r"]:
				h = fl["h"] + fl["pad_h"]
	if has_sea:
		h = maxf(h, sea - floor_depth)
	return h

func ground_radius(d: Vector3) -> float:
	var h := height(d)
	if has_sea:
		h = maxf(h, sea)
	return R + h

func color_at(h: float, slope_dot: float, p: Vector3) -> Color:
	var t := clampf((h - h_lo) / maxf(h_hi - h_lo, 1.0), 0.0, 1.0)
	var c: Color
	if has_sea:
		c = (C["low"] as Color).lerp(C["mid"], smoothstep(sea + 1.5, sea + 7.0, h))
		c = c.lerp(C["high"], smoothstep(0.62, 0.92, t))
	else:
		c = (C["low"] as Color).lerp(C["mid"], smoothstep(0.0, 0.5, t))
		c = c.lerp(C["high"], smoothstep(0.5, 0.95, t))
	var alt := smoothstep(-0.2, 0.4, n_col.get_noise_3dv(p * f_col))
	c = c.lerp(C["alt"], alt * 0.55)
	var rock := smoothstep(0.90, 0.72, slope_dot)
	c = c.lerp(C["rock"], rock)
	var a := 1.0
	if has_lava:
		a = smoothstep(lava_h - 4.0, lava_h + 2.0, h)
		# keep rim dark, lava pools glow
	return Color(c.r, c.g, c.b, a)

## Builds all arrays for a terrain tile. Safe to call from worker threads.
func build_tile(face: int, depth: int, ix: int, iy: int, N: int) -> Dictionary:
	var s := 2.0 / float(1 << depth)
	var u0 := -1.0 + ix * s
	var v0 := -1.0 + iy * s
	var step := s / float(N)
	var origin := face_dir(face, u0 + s * 0.5, v0 + s * 0.5) * R
	var M := N + 3
	var pos := PackedVector3Array()
	pos.resize(M * M)
	var hs := PackedFloat32Array()
	hs.resize(M * M)
	for j in M:
		for i in M:
			var d := face_dir(face, u0 + (i - 1) * step, v0 + (j - 1) * step)
			var h := height(d)
			if has_sea:
				h = maxf(h, sea) if false else h
			hs[j * M + i] = h
			pos[j * M + i] = d * (R + h)
	var W := N + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(W * W)
	norms.resize(W * W)
	cols.resize(W * W)
	for j in W:
		for i in W:
			var gi := (j + 1) * M + (i + 1)
			var du := pos[gi + 1] - pos[gi - 1]
			var dv := pos[gi + M] - pos[gi - M]
			var nrm := du.cross(dv).normalized()
			var pp := pos[gi]
			var up := pp.normalized()
			verts[j * W + i] = pp - origin
			norms[j * W + i] = nrm
			cols[j * W + i] = color_at(hs[gi], nrm.dot(up), pp)
	var idx := PackedInt32Array()
	for j in N:
		for i in N:
			var a := j * W + i
			var b := a + 1
			var c := a + W
			var d2 := c + 1
			idx.append_array([a, c, b, b, c, d2])
	# skirts
	var border: Array = []
	for i in W: border.append(i)
	for j in range(1, W): border.append(j * W + N)
	for i in range(N - 1, -1, -1): border.append(N * W + i)
	for j in range(N - 1, 0, -1): border.append(j * W)
	var skirt := (s * R * 0.85) * 0.10 + 1.0
	var base := verts.size()
	for bi in border.size():
		var vi: int = border[bi]
		var up2 := (verts[vi] + origin).normalized()
		verts.append(verts[vi] - up2 * skirt)
		norms.append(norms[vi])
		cols.append(cols[vi])
	var bn: int = border.size()
	for k in bn:
		var e0: int = border[k]
		var e1: int = border[(k + 1) % bn]
		var s0 := base + k
		var s1 := base + (k + 1) % bn
		idx.append_array([e0, e1, s1, e0, s1, s0])
	return {"verts": verts, "norms": norms, "cols": cols, "idx": idx, "origin": origin}

# ---------------------------------------------------------------- props
static func hh(x: int) -> int:
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	return x ^ (x >> 16)

func rnd(i: int, j: int, f: int, k: int) -> float:
	return float(hh(hh(hh(seed_ * 31 + f * 7919 + k * 104729) + i + 100000) + j + 100000) & 0xFFFFFF) / 16777216.0

const CELL := 7.0

## Returns {"mm": [PackedFloat32Array per flora type], "res": Array[{id,pos,col}]}
func gen_props(center: Vector3, collected: Dictionary) -> Dictionary:
	var flora: Array = def["flora"]
	var out: Array = []
	for t in flora.size():
		out.append(PackedFloat32Array())
	var res: Array = []
	var nc := int(ceil(PI * 0.5 * R / CELL))
	var cell_area := CELL * CELL
	var maxd := 0.0
	for fl in flora:
		maxd = maxf(maxd, fl["dist"])
	var w_uv := maxd / R * 1.5
	for f in 6:
		var fa: Array = FACES[f]
		var dn: float = center.dot(fa[0])
		if dn < 0.3:
			continue
		var c: Vector3 = center / dn
		var u: float = c.dot(fa[1])
		var v: float = c.dot(fa[2])
		var i0 := maxi(int((u - w_uv + 1.0) * 0.5 * nc), 0)
		var i1 := mini(int((u + w_uv + 1.0) * 0.5 * nc), nc - 1)
		var j0 := maxi(int((v - w_uv + 1.0) * 0.5 * nc), 0)
		var j1 := mini(int((v + w_uv + 1.0) * 0.5 * nc), nc - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var cu := -1.0 + 2.0 * (float(i) + 0.5) / nc
				var cv := -1.0 + 2.0 * (float(j) + 0.5) / nc
				var cdir := face_dir(f, cu, cv)
				if (cdir - center).length() * R > maxd + 12.0:
					continue
				for t in flora.size():
					var fl: Dictionary = flora[t]
					var prob: float = fl["dens"] * cell_area / 1000.0
					var cnt := int(prob)
					if rnd(i, j, f, t * 5) < prob - cnt:
						cnt += 1
					for q in cnt:
						var ju := (rnd(i, j, f, t * 5 + 1 + q * 11) - 0.5) / nc * 2.0
						var jv := (rnd(i, j, f, t * 5 + 2 + q * 11) - 0.5) / nc * 2.0
						var dir := face_dir(f, cu + ju, cv + jv)
						var dist := (dir - center).length() * R
						if dist > fl["dist"]:
							continue
						var hgt := height(dir)
						if hgt < fl["min_h"]:
							continue
						if has_sea and hgt < sea + 0.5:
							continue
						if has_lava and hgt < lava_h + 3.0:
							continue
						var dir2 := face_dir(f, cu + ju + 3.0 / R, cv + jv)
						var slope := absf(height(dir2) - hgt) / 3.0
						if slope > fl["slope"] * 1.6:
							continue
						var sc: float = lerpf(fl["smin"], fl["smax"], rnd(i, j, f, t * 5 + 3 + q * 11))
						var yaw := rnd(i, j, f, t * 5 + 4 + q * 11) * TAU
						var up := dir
						var ref := Vector3(0, 1, 0) if absf(up.y) < 0.95 else Vector3(1, 0, 0)
						var rx := ref.cross(up).normalized()
						var rz := rx.cross(up).normalized()
						var b := Basis(rx, up, rz).rotated(up, yaw).scaled(Vector3(sc, sc, sc))
						var o := dir * (R + hgt - 0.12 * sc)
						var arr: PackedFloat32Array = out[t]
						arr.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z])
						out[t] = arr
	# collectible resources: sparse, deterministic
	var rc := 0
	for f in 6:
		var fa2: Array = FACES[f]
		var dn2: float = center.dot(fa2[0])
		if dn2 < 0.3:
			continue
		var c2: Vector3 = center / dn2
		var u2: float = c2.dot(fa2[1])
		var v2: float = c2.dot(fa2[2])
		var wr := 150.0 / R * 1.5
		var i0b := maxi(int((u2 - wr + 1.0) * 0.5 * nc), 0)
		var i1b := mini(int((u2 + wr + 1.0) * 0.5 * nc), nc - 1)
		var j0b := maxi(int((v2 - wr + 1.0) * 0.5 * nc), 0)
		var j1b := mini(int((v2 + wr + 1.0) * 0.5 * nc), nc - 1)
		for j in range(j0b, j1b + 1):
			for i in range(i0b, i1b + 1):
				if rnd(i, j, f, 97) > 0.0035:
					continue
				var key := f * 100000000 + i * 10000 + j
				if collected.has(key):
					continue
				var cu2 := -1.0 + 2.0 * (float(i) + 0.5) / nc
				var cv2 := -1.0 + 2.0 * (float(j) + 0.5) / nc
				var dir3 := face_dir(f, cu2, cv2)
				if (dir3 - center).length() * R > 150.0:
					continue
				var h3 := height(dir3)
				if (has_sea and h3 < sea + 0.5) or (has_lava and h3 < lava_h + 3.0):
					continue
				res.append({"id": key, "pos": dir3 * (R + h3 + 0.2), "dir": dir3})
	return {"mm": out, "res": res}
