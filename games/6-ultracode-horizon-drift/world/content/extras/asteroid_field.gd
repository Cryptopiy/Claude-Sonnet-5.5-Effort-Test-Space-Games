class_name AsteroidField
extends Node3D
## One asteroid field / belt / planetary ring-debris region (module m7b_life).
## Rocks are NOT nodes: they live in 3 MultiMeshes (one per asteroid model) around a movable anchor that is registered with Frame.register_space_object, so
## everything stays precise near the viewer.  A rock's identity is a pure function of (field seed, grid cell) -> deterministic, no state.
## While the focus is inside / near the region, the cells within `view_r` are (re)scanned incrementally (a few slabs per frame) whenever the focus moved far enough,
## rocks fade in by scale toward the view radius (no pop), and the MultiMesh buffers are swapped atomically together with the anchor.
##   kind "belt":    Gaussian torus around the star-centred circle  (p.r0, p.w half-width, p.h half-thickness)
##   kind "ring":    flat disc in the equatorial plane of a body (p.rin, p.rout, p.h)          (field axes = the body's spin frame)
##   kind "cluster": spherical blob (p.rad)

const STRIDE := 12
const SLABS_PER_FRAME := 3

var kind: String = "belt"
var field_seed: int = 1
var center_fn: Callable                 # (t: float) -> DVec : origin of field space in absolute coordinates
var axes: Basis = Basis.IDENTITY        # field-space axes in absolute space (columns)
var shape: Dictionary = {}
var cell: float = 600.0
var view_r: float = 7000.0
var base_p: float = 0.22
var scale_min: float = 0.3
var scale_max: float = 2.3
var cap: int = 900                      # instances per rock type
var label: String = "Asteroid field"

var _meshes: Array = []
var _mmis: Array = []
var _bufs: Array = []
var _counts: Array = [0, 0, 0]
var _anchor: Array = [0.0, 0.0, 0.0]    # field-space anchor (doubles)
var _identity: bool = true
var _cache: Dictionary = {}
var _built: bool = false
var _last_fs: Array = [0.0, 0.0, 0.0]
var _job: Dictionary = {}
var _cool: float = 0.0
var active: bool = false

const EMPTY := []

func setup(p_kind: String, p_seed: int, p_center: Callable, p_axes: Basis, p_shape: Dictionary) -> void:
	kind = p_kind
	field_seed = p_seed
	center_fn = p_center
	axes = p_axes
	_identity = p_axes.is_equal_approx(Basis.IDENTITY)
	shape = p_shape
	name = "Field_%s_%d" % [p_kind, p_seed & 0xffff]
	for i in 3:
		var id: String = "asteroid_" + String(["a", "b", "c"][i])
		var m := ModelLib.merged_mesh(id) if ModelLib.has(id) else null
		if m == null:
			m = _fallback_mesh(i)
		_meshes.append(m)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = cap
		mm.visible_instance_count = 0
		var buf := PackedFloat32Array()
		buf.resize(cap * STRIDE)
		_bufs.append(buf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Rocks_" + str(i)
		mmi.custom_aabb = AABB(Vector3.ONE * -(view_r + 500.0), Vector3.ONE * 2.0 * (view_r + 500.0))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visible = false
		add_child(mmi)
		_mmis.append(mmi)

## procedural stand-in when the Blender asteroid models are missing
static func _fallback_mesh(idx: int) -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 30.0
	sm.height = 50.0 + 12.0 * idx
	sm.radial_segments = 14
	sm.rings = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.29, 0.27)
	mat.roughness = 0.95
	sm.material = mat
	return sm

# ---------------------------------------------------------------------------------------------------------------------
# registration helpers (absolute position of the MultiMesh anchor)
# ---------------------------------------------------------------------------------------------------------------------
func anchor_pos_fn(t: float) -> DVec:
	var c: DVec = center_fn.call(t)
	var fx: float = _anchor[0]
	var fy: float = _anchor[1]
	var fz: float = _anchor[2]
	if _identity:
		return DVec.new(c.x + fx, c.y + fy, c.z + fz)
	return DVec.new(c.x + axes.x.x * fx + axes.y.x * fy + axes.z.x * fz,
		c.y + axes.x.y * fx + axes.y.y * fy + axes.z.y * fz,
		c.z + axes.x.z * fx + axes.y.z * fy + axes.z.z * fz)

func _to_fs(c: DVec, p: DVec) -> Array:
	var dx := p.x - c.x
	var dy := p.y - c.y
	var dz := p.z - c.z
	if _identity:
		return [dx, dy, dz]
	return [axes.x.x * dx + axes.x.y * dy + axes.x.z * dz, axes.y.x * dx + axes.y.y * dy + axes.y.z * dz, axes.z.x * dx + axes.z.y * dy + axes.z.z * dz]

# ---------------------------------------------------------------------------------------------------------------------
# density / cell contents
# ---------------------------------------------------------------------------------------------------------------------
func density(x: float, y: float, z: float) -> float:
	match kind:
		"belt":
			var r := sqrt(x * x + z * z)
			var dr := (r - float(shape["r0"])) / float(shape["w"])
			var dy := y / float(shape["h"])
			return exp(-(dr * dr + dy * dy))
		"ring":
			var r2 := sqrt(x * x + z * z)
			var rin: float = shape["rin"]
			var rout: float = shape["rout"]
			var span := rout - rin
			var e := smoothstep(rin, rin + span * 0.12, r2) * (1.0 - smoothstep(rout - span * 0.12, rout, r2))
			var dy2 := y / float(shape["h"])
			return e * exp(-dy2 * dy2)
		"cluster":
			var rr := sqrt(x * x + y * y + z * z) / float(shape["rad"])
			return exp(-rr * rr * 1.6)
	return 0.0

func _near_region(fs: Array) -> bool:
	var x: float = fs[0]
	var y: float = fs[1]
	var z: float = fs[2]
	match kind:
		"belt":
			var r := sqrt(x * x + z * z)
			return absf(r - float(shape["r0"])) < 2.6 * float(shape["w"]) + view_r and absf(y) < 2.6 * float(shape["h"]) + view_r
		"ring":
			var r2 := sqrt(x * x + z * z)
			return r2 > float(shape["rin"]) - view_r and r2 < float(shape["rout"]) + view_r and absf(y) < 2.6 * float(shape["h"]) + view_r
		"cluster":
			return sqrt(x * x + y * y + z * z) < 2.2 * float(shape["rad"]) + view_r
	return false

## rocks of one cell as flat doubles [x, y, z, scale, type, ax, ay, az, angle] * n  (cached; empty array if none)
func _cell_rocks(ix: int, iy: int, iz: int) -> Array:
	var ck := Vector3i(ix, iy, iz)
	var hit = _cache.get(ck)
	if hit != null:
		return hit
	var out: Array = EMPTY
	var d := density((ix + 0.5) * cell, (iy + 0.5) * cell, (iz + 0.5) * cell)
	if d > 0.02:
		var h := SeedUtil.hash3(field_seed, ix, SeedUtil.hash2(iy, iz))
		var clump := 0.35 + 0.65 * SeedUtil.rand01(SeedUtil.hash3(field_seed ^ 0x77, int(floor(ix / 9.0)), int(floor(iz / 9.0))), 3)
		var prob := base_p * d * clump
		var n := 0
		if SeedUtil.rand01(h, 1) < prob:
			n = 1
			if SeedUtil.rand01(h, 2) < prob * 0.5:
				n = 2
		if n > 0:
			out = []
			for k in n:
				var hk := SeedUtil.hash2(h, k + 11)
				var s := lerpf(scale_min, scale_max, pow(SeedUtil.rand01(hk, 7), 2.0))
				if SeedUtil.rand01(hk, 12) < 0.035:
					s *= 2.0      # a few hero boulders
				var ax := SeedUtil.rand01(hk, 8) * 2.0 - 1.0
				var ay := SeedUtil.rand01(hk, 9) * 2.0 - 1.0
				var az := SeedUtil.rand01(hk, 10) * 2.0 - 1.0
				out.append_array([(ix + SeedUtil.rand01(hk, 1)) * cell, (iy + SeedUtil.rand01(hk, 2)) * cell, (iz + SeedUtil.rand01(hk, 3)) * cell, s,
					float(int(SeedUtil.rand01(hk, 4) * 3.0)), ax, ay, az, SeedUtil.rand01(hk, 5) * TAU])
	_cache[ck] = out
	return out

# ---------------------------------------------------------------------------------------------------------------------
# per-frame update (called by SystemExtras)
# ---------------------------------------------------------------------------------------------------------------------
func update(dt: float, focus_abs: DVec, t: float) -> void:
	var c: DVec = center_fn.call(t)
	var fs := _to_fs(c, focus_abs)
	if not _near_region(fs):
		if active:
			active = false
			_job.clear()
			_built = false
			for m in _mmis:
				(m as MultiMeshInstance3D).visible = false
		return
	active = true
	_cool -= dt
	if _job.is_empty():
		var moved := 1.0e18
		if _built:
			var dx: float = fs[0] - float(_last_fs[0])
			var dy: float = fs[1] - float(_last_fs[1])
			var dz: float = fs[2] - float(_last_fs[2])
			moved = sqrt(dx * dx + dy * dy + dz * dz)
		if (not _built or moved > cell * 0.5) and _cool <= 0.0:
			_begin_job(fs)
	if not _job.is_empty():
		_step_job()

func _begin_job(fs: Array) -> void:
	var anchor := [round(float(fs[0]) / 1000.0) * 1000.0, round(float(fs[1]) / 1000.0) * 1000.0, round(float(fs[2]) / 1000.0) * 1000.0]
	var bufs: Array = []
	for i in 3:
		var b := PackedFloat32Array()
		b.resize(cap * STRIDE)
		bufs.append(b)
	var r_cells := int(ceil(view_r / cell))
	var i0 := int(floor(float(fs[0]) / cell))
	_job = {"fs": fs, "anchor": anchor, "bufs": bufs, "counts": [0, 0, 0], "ix": i0 - r_cells, "ix_end": i0 + r_cells, "i0": i0,
		"j0": int(floor(float(fs[1]) / cell)), "k0": int(floor(float(fs[2]) / cell)), "rc": r_cells}

func _step_job() -> void:
	var fs: Array = _job["fs"]
	var anchor: Array = _job["anchor"]
	var bufs: Array = _job["bufs"]
	var counts: Array = _job["counts"]
	var rc: int = _job["rc"]
	var j0: int = _job["j0"]
	var k0: int = _job["k0"]
	var fx: float = fs[0]
	var fy: float = fs[1]
	var fz: float = fs[2]
	for s in SLABS_PER_FRAME:
		var ix: int = _job["ix"]
		if ix > int(_job["ix_end"]):
			_finish_job()
			return
		_job["ix"] = ix + 1
		var cxm := (ix + 0.5) * cell - fx
		for iy in range(j0 - rc, j0 + rc + 1):
			var cym := (iy + 0.5) * cell - fy
			if cxm * cxm + cym * cym > (view_r + cell) * (view_r + cell):
				continue
			for iz in range(k0 - rc, k0 + rc + 1):
				var czm := (iz + 0.5) * cell - fz
				if cxm * cxm + cym * cym + czm * czm > (view_r + cell) * (view_r + cell):
					continue
				var rocks: Array = _cell_rocks(ix, iy, iz)
				if rocks.is_empty():
					continue
				var n := int(float(rocks.size()) / 9.0)
				for q in n:
					var o := q * 9
					var rx: float = rocks[o]
					var ry: float = rocks[o + 1]
					var rz: float = rocks[o + 2]
					var dx := rx - fx
					var dy := ry - fy
					var dz := rz - fz
					var dist := sqrt(dx * dx + dy * dy + dz * dz)
					if dist > view_r:
						continue
					var fade := smoothstep(view_r, view_r * 0.7, dist)
					if fade <= 0.01:
						continue
					var ty: int = int(rocks[o + 4])
					var cnt: int = counts[ty]
					if cnt >= cap:
						continue
					counts[ty] = cnt + 1
					var sc: float = float(rocks[o + 3]) * fade
					var axis := Vector3(rocks[o + 5], rocks[o + 6], rocks[o + 7])
					if axis.length_squared() < 0.0001:
						axis = Vector3.UP
					var bs := Basis(axis.normalized(), float(rocks[o + 8])).scaled(Vector3(sc, sc, sc))
					var rel := Vector3(rx - float(anchor[0]), ry - float(anchor[1]), rz - float(anchor[2]))
					if not _identity:
						rel = axes * rel
						bs = axes * bs
					var b: PackedFloat32Array = bufs[ty]
					var bo := cnt * STRIDE
					b[bo] = bs.x.x
					b[bo + 1] = bs.y.x
					b[bo + 2] = bs.z.x
					b[bo + 3] = rel.x
					b[bo + 4] = bs.x.y
					b[bo + 5] = bs.y.y
					b[bo + 6] = bs.z.y
					b[bo + 7] = rel.y
					b[bo + 8] = bs.x.z
					b[bo + 9] = bs.y.z
					b[bo + 10] = bs.z.z
					b[bo + 11] = rel.z
	if _cache.size() > 40000:
		_cache.clear()

func _finish_job() -> void:
	var bufs: Array = _job["bufs"]
	var counts: Array = _job["counts"]
	_anchor = _job["anchor"]
	_last_fs = _job["fs"]
	for i in 3:
		var mm := (_mmis[i] as MultiMeshInstance3D).multimesh
		mm.buffer = bufs[i]
		mm.visible_instance_count = int(counts[i])
		(_mmis[i] as MultiMeshInstance3D).visible = int(counts[i]) > 0
	_counts = counts
	_built = true
	_cool = 0.15
	_job.clear()

func rock_count() -> int:
	return int(_counts[0]) + int(_counts[1]) + int(_counts[2])
