class_name TNoise
extends RefCounted
## CPU twin of shaders/inc/tnoise.gdshaderinc. Integer-hash gradient (Perlin) noise.
## Any change here MUST be mirrored in the shader include so GPU terrain and CPU collisions agree.

const M := 0xFFFFFFFF


static func _h(x: int) -> int:
	x = (((x >> 16) ^ x) * 73244475) & M
	x = (((x >> 16) ^ x) * 73244475) & M
	return (x >> 16) ^ x


static func _g(h: int, dx: float, dy: float, dz: float) -> float:
	var k := h & 15
	var u := dx if k < 8 else dy
	var v: float
	if k < 4:
		v = dy
	elif k == 12 or k == 14:
		v = dx
	else:
		v = dz
	return (u if (k & 1) == 0 else -u) + (v if (k & 2) == 0 else -v)


static func perlin(px: float, py: float, pz: float, seed: int) -> float:
	var fx := floorf(px)
	var fy := floorf(py)
	var fz := floorf(pz)
	var wx := px - fx
	var wy := py - fy
	var wz := pz - fz
	var ix := int(fx) & M
	var iy := int(fy) & M
	var iz := int(fz) & M
	var s := (seed * 668265261) & M
	var hx0 := _h((ix + s) & M)
	var hx1 := _h((ix + 1 + s) & M)
	var y1 := (iy + 1) & M
	var z1 := (iz + 1) & M
	var h00 := _h((hx0 + iy) & M)
	var h10 := _h((hx1 + iy) & M)
	var h01 := _h((hx0 + y1) & M)
	var h11 := _h((hx1 + y1) & M)
	var n000 := _g(_h((h00 + iz) & M), wx, wy, wz)
	var n100 := _g(_h((h10 + iz) & M), wx - 1.0, wy, wz)
	var n010 := _g(_h((h01 + iz) & M), wx, wy - 1.0, wz)
	var n110 := _g(_h((h11 + iz) & M), wx - 1.0, wy - 1.0, wz)
	var n001 := _g(_h((h00 + z1) & M), wx, wy, wz - 1.0)
	var n101 := _g(_h((h10 + z1) & M), wx - 1.0, wy, wz - 1.0)
	var n011 := _g(_h((h01 + z1) & M), wx, wy - 1.0, wz - 1.0)
	var n111 := _g(_h((h11 + z1) & M), wx - 1.0, wy - 1.0, wz - 1.0)
	var ux := wx * wx * wx * (wx * (wx * 6.0 - 15.0) + 10.0)
	var uy := wy * wy * wy * (wy * (wy * 6.0 - 15.0) + 10.0)
	var uz := wz * wz * wz * (wz * (wz * 6.0 - 15.0) + 10.0)
	var a := lerpf(lerpf(n000, n100, ux), lerpf(n010, n110, ux), uy)
	var b := lerpf(lerpf(n001, n101, ux), lerpf(n011, n111, ux), uy)
	return lerpf(a, b, uz)


static func fbm(px: float, py: float, pz: float, oct: int, gain: float, seed: int) -> float:
	var a := 1.0
	var s := 0.0
	var n := 0.0
	for i in oct:
		s += a * perlin(px, py, pz, seed)
		n += a
		a *= gain
		px = px * 2.03 + 17.1
		py = py * 2.03 + 31.7
		pz = pz * 2.03 + 9.3
	if n == 0.0:
		return 0.0
	return s / n


static func ridged(px: float, py: float, pz: float, oct: int, seed: int) -> float:
	var a := 0.5
	var s := 0.0
	var n := 0.0
	for i in oct:
		var v := 1.0 - clampf(absf(perlin(px, py, pz, seed)) * 1.6, 0.0, 1.0)
		s += a * v * v
		n += a
		a *= 0.5
		px = px * 2.07 + 11.3
		py = py * 2.07 + 5.9
		pz = pz * 2.07 + 23.1
	if n == 0.0:
		return 0.0
	return s / n


static func craters(px: float, py: float, pz: float, seed: int) -> float:
	var bx := int(floorf(px - 0.5))
	var by := int(floorf(py - 0.5))
	var bz := int(floorf(pz - 0.5))
	var s := (seed * 668265261) & M
	var h := 0.0
	for k in 8:
		var cx := bx + (k & 1)
		var cy := by + ((k >> 1) & 1)
		var cz := bz + ((k >> 2) & 1)
		var hh := _h((_h((_h(((cx & M) + s) & M) + (cy & M)) & M) + (cz & M)) & M)
		var jx := float(hh & 255) * (0.6 / 255.0) + 0.2
		var jy := float((hh >> 8) & 255) * (0.6 / 255.0) + 0.2
		var jz := float((hh >> 16) & 255) * (0.6 / 255.0) + 0.2
		var rad := 0.12 + 0.18 * float((hh >> 24) & 255) / 255.0
		var dx := px - (float(cx) + jx)
		var dy := py - (float(cy) + jy)
		var dz := pz - (float(cz) + jz)
		var d := sqrt(dx * dx + dy * dy + dz * dz) / rad
		if d < 1.6:
			var bowl := 0.0
			if d < 1.0:
				bowl = -(1.0 - d * d)
			var t := (d - 1.0) / 0.22
			var rim := exp(-t * t) * 0.30
			h += (bowl * 0.9 + rim) * (rad / 0.3)
	return h


static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Cube-face mapping (shared with shaders/terrain.gdshader)
const FACE_N := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const FACE_A := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
const FACE_B := [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0)]


static func cube_to_sphere(c: Vector3) -> Vector3:
	var c2 := c * c
	return Vector3(
		c.x * sqrt(1.0 - 0.5 * (c2.y + c2.z) + c2.y * c2.z / 3.0),
		c.y * sqrt(1.0 - 0.5 * (c2.z + c2.x) + c2.z * c2.x / 3.0),
		c.z * sqrt(1.0 - 0.5 * (c2.x + c2.y) + c2.x * c2.y / 3.0))


## Inverse of the face mapping: given a unit direction find (face, s, t). Used for chunk lookups.
static func dir_to_face_st(d: Vector3) -> Array:
	# choose the dominant axis, then solve s,t by a couple of Newton-free fixed point iterations on the cube point
	var ad := d.abs()
	var f := 0
	if ad.x >= ad.y and ad.x >= ad.z:
		f = 0 if d.x > 0.0 else 1
	elif ad.y >= ad.z:
		f = 2 if d.y > 0.0 else 3
	else:
		f = 4 if d.z > 0.0 else 5
	var n: Vector3 = FACE_N[f]
	var a: Vector3 = FACE_A[f]
	var b: Vector3 = FACE_B[f]
	# gnomonic initial guess
	var k := d.dot(n)
	var c := d / k
	var s := c.dot(a)
	var t := c.dot(b)
	# refine so that cube_to_sphere(n + s a + t b) == d (a few damped iterations)
	for i in 6:
		var cur := cube_to_sphere(n + a * s + b * t)
		var err := d - cur
		# approximate Jacobian by identity on the tangent plane (good enough, mapping is near-isometric)
		s += err.dot(a) * 0.9
		t += err.dot(b) * 0.9
	return [f, s, t]
