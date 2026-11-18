class_name TerrainParams
extends RefCounted
## CPU mirror of shaders/terrain.gdshader's height function (and noise.gdshaderinc).
## The planet surface is a cube-sphere; the shader displaces the mesh on the GPU while this class answers
## "how high is the ground here?" for the player, the ship and prop placement.

var seed: int = 1
var freq: float = 3.0
var amp: float = 200.0
var ridge: float = 0.4
var mask: float = 0.6
var terr: float = 0.0
var steps: float = 6.0
var dune: float = 0.0
var crater: float = 0.0
var cden: float = 5.0
var off: Vector3 = Vector3.ZERO
var site_dir: Vector3 = Vector3.UP
var site_h: float = 0.0
var site_r_in: float = 45.0
var site_r_out: float = 120.0
var radius: float = 4000.0
var sea_level: float = -100000.0  # metres above radius; -100000 = no sea
var has_site: bool = true

const CUBE_WARP := 0.78539816


static func cube_point(face: int, a: float, b: float) -> Vector3:
	a = tan(a * CUBE_WARP)
	b = tan(b * CUBE_WARP)
	match face:
		0: return Vector3(1.0, b, -a)
		1: return Vector3(-1.0, b, a)
		2: return Vector3(a, 1.0, -b)
		3: return Vector3(a, -1.0, b)
		4: return Vector3(a, b, 1.0)
		_: return Vector3(-a, b, -1.0)


static func face_dir(face: int, a: float, b: float) -> Vector3:
	return cube_point(face, a, b).normalized()


## Inverse of face_dir: returns [face, a, b]
static func dir_to_face(d: Vector3) -> Array:
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	var face := 0
	var a := 0.0
	var b := 0.0
	if ax >= ay and ax >= az:
		if d.x > 0.0:
			face = 0; a = -d.z / ax; b = d.y / ax
		else:
			face = 1; a = d.z / ax; b = d.y / ax
	elif ay >= az:
		if d.y > 0.0:
			face = 2; a = d.x / ay; b = -d.z / ay
		else:
			face = 3; a = d.x / ay; b = d.z / ay
	else:
		if d.z > 0.0:
			face = 4; a = d.x / az; b = d.y / az
		else:
			face = 5; a = -d.x / az; b = d.y / az
	return [face, atan(a) / CUBE_WARP, atan(b) / CUBE_WARP]


# ---------------------------------------------------------------- noise (mirror of noise.gdshaderinc)
static func _hash(x: int, y: int, z: int, sd: int) -> int:
	var h: int = ((x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (sd * 2654435761)) & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x7feb352d) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x846ca68b) & 0xFFFFFFFF
	h ^= h >> 16
	return h


static func _gd(h: int, x: float, y: float, z: float) -> float:
	return (x if (h >> 5) & 1 != 0 else -x) + (y if (h >> 6) & 1 != 0 else -y) + (z if (h >> 7) & 1 != 0 else -z)


static func gnoise(px: float, py: float, pz: float, sd: int) -> float:
	var fx := floorf(px)
	var fy := floorf(py)
	var fz := floorf(pz)
	var x := px - fx
	var y := py - fy
	var z := pz - fz
	var ux := x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
	var uy := y * y * y * (y * (y * 6.0 - 15.0) + 10.0)
	var uz := z * z * z * (z * (z * 6.0 - 15.0) + 10.0)
	var ix := int(fx)
	var iy := int(fy)
	var iz := int(fz)
	var n000 := _gd(_hash(ix, iy, iz, sd), x, y, z)
	var n100 := _gd(_hash(ix + 1, iy, iz, sd), x - 1.0, y, z)
	var n010 := _gd(_hash(ix, iy + 1, iz, sd), x, y - 1.0, z)
	var n110 := _gd(_hash(ix + 1, iy + 1, iz, sd), x - 1.0, y - 1.0, z)
	var n001 := _gd(_hash(ix, iy, iz + 1, sd), x, y, z - 1.0)
	var n101 := _gd(_hash(ix + 1, iy, iz + 1, sd), x - 1.0, y, z - 1.0)
	var n011 := _gd(_hash(ix, iy + 1, iz + 1, sd), x, y - 1.0, z - 1.0)
	var n111 := _gd(_hash(ix + 1, iy + 1, iz + 1, sd), x - 1.0, y - 1.0, z - 1.0)
	var a := lerpf(lerpf(n000, n100, ux), lerpf(n010, n110, ux), uy)
	var b := lerpf(lerpf(n001, n101, ux), lerpf(n011, n111, ux), uy)
	return lerpf(a, b, uz) * 0.8


static func fbm(px: float, py: float, pz: float, sd: int, oct: int) -> float:
	var s := 0.0
	var a := 0.5
	var norm := 0.0
	for i in oct:
		s += a * gnoise(px, py, pz, sd + i)
		norm += a
		a *= 0.5
		var nx := 0.8 * py + 0.6 * pz
		var ny := -0.8 * px + 0.36 * py - 0.48 * pz
		var nz := -0.6 * px - 0.48 * py + 0.64 * pz
		px = nx * 2.02 + 11.3
		py = ny * 2.02 + 5.7
		pz = nz * 2.02 + 3.1
	return s / norm


static func crater_field(d: Vector3, dens: float, sd: int) -> float:
	var q := d * dens
	var icx := floorf(q.x)
	var icy := floorf(q.y)
	var icz := floorf(q.z)
	var res := 0.0
	for z in range(-1, 2):
		for y in range(-1, 2):
			for x in range(-1, 2):
				var cx := icx + x
				var cy := icy + y
				var cz := icz + z
				var h := _hash(int(cx), int(cy), int(cz), sd)
				if (h & 255) > 120:
					continue
				var h2 := _hash(int(cx), int(cy), int(cz), sd + 1)
				var ctr := Vector3(cx + 0.2 + 0.6 * float((h >> 8) & 255) / 255.0,
						cy + 0.2 + 0.6 * float((h >> 16) & 255) / 255.0,
						cz + 0.2 + 0.6 * float((h >> 24) & 255) / 255.0)
				var rad := 0.18 + 0.32 * float(h2 & 255) / 255.0
				var dd := q.distance_to(ctr) / rad
				var k := rad / 0.35
				if dd < 1.0:
					res -= (1.0 - dd * dd) * k
				elif dd < 1.5:
					res += 0.32 * k * smoothstep(1.0, 1.12, dd) * (1.0 - smoothstep(1.12, 1.5, dd))
	return res


## Height of the ground above `radius` at unit direction d (metres).
func height(d: Vector3) -> float:
	var px := d.x * freq + off.x
	var py := d.y * freq + off.y
	var pz := d.z * freq + off.z
	var n := fbm(px, py, pz, seed, 7)
	var rn := 1.0 - absf(fbm(px * 1.35 + 7.7, py * 1.35 + 1.3, pz * 1.35 + 4.1, seed + 11, 6))
	rn = rn * rn * 1.9 - 0.45
	var mk := 1.0
	if mask > 0.0:
		mk = lerpf(1.0, smoothstep(-0.25, 0.25, fbm(px * 0.4 + 3.1, py * 0.4 + 8.2, pz * 0.4 + 1.7, seed + 23, 3)), mask)
	var base := lerpf(n * 0.4, lerpf(n, rn, ridge), mk)
	var h := base * amp
	if terr > 0.0:
		var t := h / amp * steps
		var tq := (floorf(t) + smoothstep(0.3, 0.7, t - floorf(t))) / steps
		h = lerpf(h, tq * amp, terr)
	if dune > 0.0:
		var s := (px * 0.62 + py * 0.21 + pz * 0.75) * 6.0 + n * 5.0
		h += dune * (1.0 - absf(sin(s))) * (1.0 - mk * 0.8)
	if crater != 0.0:
		h += crater * crater_field(d, cden, seed + 101)
	if has_site:
		var w := 1.0 - smoothstep(site_r_in, site_r_out, d.distance_to(site_dir) * radius)
		h = lerpf(h, site_h, w)
	return h


## Height including the sea (walkable surface; water is a flat sphere).
func ground(d: Vector3) -> float:
	return maxf(height(d), sea_level)


## Surface normal (unit, planet-local) at direction d using finite differences of the height field.
func normal_at(d: Vector3, eps_m: float = 1.5) -> Vector3:
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1).normalized()
	var e := eps_m / radius
	var d1 := (d + t1 * e).normalized()
	var d2 := (d + t2 * e).normalized()
	var p0 := d * (radius + ground(d))
	var p1 := d1 * (radius + ground(d1))
	var p2 := d2 * (radius + ground(d2))
	var n := (p1 - p0).cross(p2 - p0).normalized()
	if n.dot(d) < 0.0:
		n = -n
	return n
