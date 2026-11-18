class_name TerrainMesher
extends RefCounted
## Cube-sphere mapping + thread-safe chunk mesh builder (module M1).
## A chunk = (face, level, ix, iy): a GRID x GRID quad patch of the cube face, projected onto the sphere ("spherified cube") and displaced by TerrainGen.height.
## Vertices are stored relative to the chunk centre (chunk node transform = centre), skirts hide LOD cracks, CUSTOM0 holds the geomorph target (xyz) + morph range (w).

const GRID := 32                   # cells per chunk edge (33 x 33 vertices)

## cube-face point (u, v in [-1,1]) -> unit direction (spherified cube mapping: much more uniform cells than plain normalisation)
static func cube_dir(face: int, u: float, v: float) -> Vector3:
	var x: float
	var y: float
	var z: float
	match face:
		0:
			x = 1.0
			y = v
			z = u
		1:
			x = -1.0
			y = v
			z = -u
		2:
			x = u
			y = 1.0
			z = v
		3:
			x = u
			y = -1.0
			z = -v
		4:
			x = -u
			y = v
			z = 1.0
		_:
			x = u
			y = v
			z = -1.0
	var x2 := x * x
	var y2 := y * y
	var z2 := z * z
	return Vector3(
		x * sqrt(maxf(1.0 - y2 * 0.5 - z2 * 0.5 + y2 * z2 / 3.0, 0.0)),
		y * sqrt(maxf(1.0 - x2 * 0.5 - z2 * 0.5 + x2 * z2 / 3.0, 0.0)),
		z * sqrt(maxf(1.0 - x2 * 0.5 - y2 * 0.5 + x2 * y2 / 3.0, 0.0)))

## unit direction -> (face, u, v) (inverse of cube_dir is not needed analytically: we use the plain cube projection to find the face,
## the node lookup only needs approximate (face, u, v)).
static func face_of(d: Vector3) -> int:
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	if ax >= ay and ax >= az:
		return 0 if d.x > 0.0 else 1
	if ay >= ax and ay >= az:
		return 2 if d.y > 0.0 else 3
	return 4 if d.z > 0.0 else 5

## unit direction + its face -> (u, v) on that face (inverse of cube_dir, fixed-point iteration from the plain cube projection)
static func dir_to_uv(face: int, d: Vector3) -> Vector2:
	var m := maxf(maxf(absf(d.x), absf(d.y)), absf(d.z))
	var q := d / maxf(m, 1.0e-9)
	var uv: Vector2
	var tgt: Vector2
	match face:
		0: tgt = Vector2(q.z, q.y)
		1: tgt = Vector2(-q.z, q.y)
		2: tgt = Vector2(q.x, q.z)
		3: tgt = Vector2(q.x, -q.z)
		4: tgt = Vector2(-q.x, q.y)
		_: tgt = Vector2(q.x, q.y)
	uv = tgt
	for it in 6:
		var c := cube_dir(face, uv.x, uv.y)
		var mm := maxf(maxf(absf(c.x), absf(c.y)), absf(c.z))
		var qq := c / maxf(mm, 1.0e-9)
		var cur: Vector2
		match face:
			0: cur = Vector2(qq.z, qq.y)
			1: cur = Vector2(-qq.z, qq.y)
			2: cur = Vector2(qq.x, qq.z)
			3: cur = Vector2(qq.x, -qq.z)
			4: cur = Vector2(-qq.x, qq.y)
			_: cur = Vector2(qq.x, qq.y)
		uv += (tgt - cur)
	return uv

## Build one chunk. Returns {mesh: ArrayMesh, centre: Vector3, lo: float, hi: float}  (thread-safe, pure function of its inputs).
static func build(gen: TerrainGen, face: int, lvl: int, ix: int, iy: int, morph_range: float) -> Dictionary:
	var n := GRID
	var np := n + 3
	var R := gen.radius
	var cnt := 1 << lvl
	var du := 2.0 / float(cnt) / float(n)
	var u0 := -1.0 + 2.0 * float(ix) / float(cnt)
	var v0 := -1.0 + 2.0 * float(iy) / float(cnt)
	var cdir := cube_dir(face, u0 + float(n) * 0.5 * du, v0 + float(n) * 0.5 * du)
	var centre := cdir * R
	# --- heights + positions on the extended grid (1 ring outside, for border-consistent normals)
	var dirs := PackedVector3Array()
	dirs.resize(np * np)
	var hs := PackedFloat32Array()
	hs.resize(np * np)
	var pos := PackedVector3Array()
	pos.resize(np * np)
	var lo := 1.0e9
	var hi := -1.0e9
	for j in np:
		var v := v0 + float(j - 1) * du
		for i in np:
			var d := cube_dir(face, u0 + float(i - 1) * du, v)
			var h := gen.height(d)
			var k := j * np + i
			dirs[k] = d
			hs[k] = h
			pos[k] = d * (R + h) - centre
			if h < lo:
				lo = h
			if h > hi:
				hi = h
	# approximate vertex spacing (metres) for colour LOD
	var spacing := (pos[np + 1 + 1] - pos[np + 1]).length()
	var nv := (n + 1) * (n + 1)
	var skirt_n := 4 * (n + 1)
	var verts := PackedVector3Array()
	verts.resize(nv + skirt_n)
	var norms := PackedVector3Array()
	norms.resize(nv + skirt_n)
	var cols := PackedColorArray()
	cols.resize(nv + skirt_n)
	var uvs := PackedVector2Array()
	uvs.resize(nv + skirt_n)
	var cust := PackedFloat32Array()
	cust.resize((nv + skirt_n) * 4)
	# --- interior vertices
	for j in n + 1:
		for i in n + 1:
			var ek := (j + 1) * np + (i + 1)
			var vi := j * (n + 1) + i
			var p0 := pos[ek]
			verts[vi] = p0
			var tu := pos[ek + 1] - pos[ek - 1]
			var tv := pos[ek + np] - pos[ek - np]
			var nr := tu.cross(tv)
			if nr.dot(dirs[ek]) < 0.0:
				nr = -nr
			norms[vi] = nr.normalized()
			cols[vi] = gen.color_at(dirs[ek], hs[ek], spacing)
			uvs[vi] = Vector2(hs[ek], 0.0)
			# geomorph target: odd vertices move to the parent-resolution surface
			var tgt := p0
			var oi := i & 1
			var oj := j & 1
			if oi == 1 and oj == 0:
				tgt = (pos[ek - 1] + pos[ek + 1]) * 0.5
			elif oi == 0 and oj == 1:
				tgt = (pos[ek - np] + pos[ek + np]) * 0.5
			elif oi == 1 and oj == 1:
				tgt = (pos[ek - np - 1] + pos[ek + np + 1]) * 0.5
			var dl := tgt - p0
			var ci := vi * 4
			cust[ci] = dl.x
			cust[ci + 1] = dl.y
			cust[ci + 2] = dl.z
			cust[ci + 3] = morph_range
	# --- skirts: 4 edges, each n+1 vertices copied from the border and pushed towards the planet centre
	var skirt_depth := maxf(spacing * 1.4, 0.6) + spacing * float(n) * 0.012
	var edge_idx: Array = []          # per edge: PackedInt32Array of border vertex indices
	for e in 4:
		var arr := PackedInt32Array()
		for t in n + 1:
			var vi2: int
			match e:
				0: vi2 = t                                # j = 0
				1: vi2 = n * (n + 1) + t                  # j = n
				2: vi2 = t * (n + 1)                      # i = 0
				_: vi2 = t * (n + 1) + n                  # i = n
			arr.append(vi2)
		edge_idx.append(arr)
	var si := nv
	var skirt_first: Array = []
	for e in 4:
		skirt_first.append(si)
		var arr2: PackedInt32Array = edge_idx[e]
		for t in n + 1:
			var b := arr2[t]
			var bp := verts[b]
			var up := (bp + centre).normalized()
			verts[si] = bp - up * skirt_depth
			norms[si] = norms[b]
			cols[si] = cols[b]
			uvs[si] = uvs[b]
			var cb := b * 4
			var cs := si * 4
			cust[cs] = cust[cb]
			cust[cs + 1] = cust[cb + 1]
			cust[cs + 2] = cust[cb + 2]
			cust[cs + 3] = cust[cb + 3]
			si += 1
	# --- indices (front faces are clockwise in Godot: cross(b-a, c-a) points INTO the surface)
	var idx := PackedInt32Array()
	idx.resize(n * n * 6 + 4 * n * 12)
	var w := n + 1
	# determine orientation from the centre quad
	var qa := verts[(n / 2) * w + n / 2]
	var qb := verts[(n / 2) * w + n / 2 + 1]
	var qc := verts[(n / 2 + 1) * w + n / 2 + 1]
	var flip := (qb - qa).cross(qc - qa).dot(cdir) > 0.0
	var o := 0
	for j in n:
		for i in n:
			var a := j * w + i
			var b2 := a + 1
			var c := a + w
			var d2 := c + 1
			if flip:
				idx[o] = a
				idx[o + 1] = c
				idx[o + 2] = d2
				idx[o + 3] = a
				idx[o + 4] = d2
				idx[o + 5] = b2
			else:
				idx[o] = a
				idx[o + 1] = d2
				idx[o + 2] = c
				idx[o + 3] = a
				idx[o + 4] = b2
				idx[o + 5] = d2
			o += 6
	# skirt triangles, both windings (cheap, avoids per-edge orientation logic)
	for e in 4:
		var arr3: PackedInt32Array = edge_idx[e]
		var s0: int = skirt_first[e]
		for t in n:
			var t0 := arr3[t]
			var t1 := arr3[t + 1]
			var s_a := s0 + t
			var s_b := s0 + t + 1
			idx[o] = t0
			idx[o + 1] = t1
			idx[o + 2] = s_b
			idx[o + 3] = t0
			idx[o + 4] = s_b
			idx[o + 5] = s_a
			idx[o + 6] = t0
			idx[o + 7] = s_b
			idx[o + 8] = t1
			idx[o + 9] = t0
			idx[o + 10] = s_a
			idx[o + 11] = s_b
			o += 12
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = cust
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return {"mesh": mesh, "centre": centre, "lo": lo, "hi": hi}

## Collision patch: a (2*half/step)^2 grid of triangles around `dir0` on the terrain surface. Returns {shape, centre}.
static func build_collision(gen: TerrainGen, dir0: Vector3, half: float, step: float) -> Dictionary:
	var R := gen.radius
	var cells := clampi(int(ceil(2.0 * half / step)), 8, 220)
	var st := 2.0 * half / float(cells)
	var up := dir0.normalized()
	var t1 := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := up.cross(t1)
	var base := up * R
	var w := cells + 1
	var pts := PackedVector3Array()
	pts.resize(w * w)
	for j in w:
		for i in w:
			var q := base + t1 * (float(i) * st - half) + t2 * (float(j) * st - half)
			var d := q.normalized()
			pts[j * w + i] = d * (R + gen.height(d)) - base
	var faces := PackedVector3Array()
	faces.resize(cells * cells * 6)
	var o := 0
	for j in cells:
		for i in cells:
			var a := pts[j * w + i]
			var b := pts[j * w + i + 1]
			var c := pts[(j + 1) * w + i]
			var d2 := pts[(j + 1) * w + i + 1]
			faces[o] = a
			faces[o + 1] = c
			faces[o + 2] = d2
			faces[o + 3] = a
			faces[o + 4] = d2
			faces[o + 5] = b
			o += 6
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return {"shape": shape, "centre": base, "dir": up, "half": half}
