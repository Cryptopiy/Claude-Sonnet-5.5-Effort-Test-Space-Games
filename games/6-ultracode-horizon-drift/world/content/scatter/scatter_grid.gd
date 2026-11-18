class_name ScatterGrid
extends RefCounted
## Cube-sphere cell grid used by the scatter system (module M7a). Pure static math, thread-safe.
## A cell = (face 0..5, i, j) on an n x n grid per face. Cell keys are unique ints per grid size (layer).
## The tan() warp makes the cells almost equal-angle, so every cell is roughly cell_size x cell_size metres on the ground.

const FACE_N: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const FACE_U: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
const FACE_V: Array[Vector3] = [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0)]

## number of cells along one face edge for a planet of `radius` and a wanted cell edge length
static func cells_per_face(radius: float, cell_size: float) -> int:
	return maxi(4, int(round(PI * 0.5 * radius / cell_size)))

static func make_key(face: int, i: int, j: int, n: int) -> int:
	return (face * n + j) * n + i

static func key_face(key: int, n: int) -> int:
	return key / (n * n)

static func key_i(key: int, n: int) -> int:
	return key % n

static func key_j(key: int, n: int) -> int:
	return (key / n) % n

## direction (unit) for the point (fx, fy) in [0,1] inside the cell
static func point_dir(face: int, i: int, j: int, n: int, fx: float, fy: float) -> Vector3:
	var a := (float(i) + fx) / float(n) * 2.0 - 1.0
	var b := (float(j) + fy) / float(n) * 2.0 - 1.0
	var u := tan(a * PI * 0.25)
	var v := tan(b * PI * 0.25)
	return (FACE_N[face] + FACE_U[face] * u + FACE_V[face] * v).normalized()

static func center_dir(face: int, i: int, j: int, n: int) -> Vector3:
	return point_dir(face, i, j, n, 0.5, 0.5)

## solid angle (steradians) of the cell
static func cell_solid_angle(face: int, i: int, j: int, n: int) -> float:
	var a := (float(i) + 0.5) / float(n) * 2.0 - 1.0
	var b := (float(j) + 0.5) / float(n) * 2.0 - 1.0
	var u := tan(a * PI * 0.25)
	var v := tan(b * PI * 0.25)
	var k := PI * 0.25 * 2.0 / float(n)
	return k * k * (1.0 + u * u) * (1.0 + v * v) / pow(1.0 + u * u + v * v, 1.5)

## returns Vector3i(face, i, j) of the cell containing direction d
static func dir_to_cell(d: Vector3, n: int) -> Vector3i:
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	var f := 0
	if ax >= ay and ax >= az:
		f = 0 if d.x > 0.0 else 1
	elif ay >= az:
		f = 2 if d.y > 0.0 else 3
	else:
		f = 4 if d.z > 0.0 else 5
	var s := d.dot(FACE_N[f])
	var u := d.dot(FACE_U[f]) / s
	var v := d.dot(FACE_V[f]) / s
	var a := atan(u) * 4.0 / PI
	var b := atan(v) * 4.0 / PI
	var i := clampi(int(floor((a + 1.0) * 0.5 * float(n))), 0, n - 1)
	var j := clampi(int(floor((b + 1.0) * 0.5 * float(n))), 0, n - 1)
	return Vector3i(f, i, j)

## direction displaced from `base` by a tangent-plane offset (t1 * x + t2 * y metres) on a sphere of radius r
static func offset_dir(base: Vector3, t1: Vector3, t2: Vector3, x: float, y: float, r: float) -> Vector3:
	return (base * r + t1 * x + t2 * y).normalized()

## two orthonormal tangent vectors for a unit direction
static func tangents(d: Vector3) -> Array[Vector3]:
	var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var t1 := ref.cross(d).normalized()
	var t2 := d.cross(t1).normalized()
	return [t1, t2]

## rotate unit direction `d` by arc length `dist` metres towards `bearing` (angle around d in the tangent frame) on radius r
static func walk(d: Vector3, bearing: float, dist: float, r: float) -> Vector3:
	var t := tangents(d)
	var dirv: Vector3 = t[0] * cos(bearing) + t[1] * sin(bearing)
	var ang := dist / r
	return (d * cos(ang) + dirv * sin(ang)).normalized()

## great-circle ground distance in metres between two unit directions on radius r
static func ground_dist(a: Vector3, b: Vector3, r: float) -> float:
	return acos(clampf(a.dot(b), -1.0, 1.0)) * r
