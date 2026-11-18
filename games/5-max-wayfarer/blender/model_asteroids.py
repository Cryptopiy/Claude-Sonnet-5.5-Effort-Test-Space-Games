"""Brief 3 space objects: asteroid_a (elongated, ridged), asteroid_b (round, pitted), asteroid_c (two lobes + crack).  ~30 m, flat shaded
Rock_A / Rock_B (tinted by the game), cube-sphere base mesh (9 x 9 x 6 quads = 972 tris) displaced radially by noise + craters + cuts, plus a few
chunks stuck on.  Origin = centre of the rock.  ONLY=[names] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')
RA, RB = 'Rock_A', 'Rock_B'


def cube_sphere_bm(n):
    """6 grids of n x n quads on a cube, projected onto the unit sphere (verts shared across the cube edges), triangulated"""
    bm = bmesh.new()
    vm = {}

    def vert(p):
        key = (round(p[0] * n), round(p[1] * n), round(p[2] * n))
        if key not in vm:
            vm[key] = bm.verts.new(Vector(p).normalized())
        return vm[key]
    axes = [((1, 0, 0), (0, 1, 0), (0, 0, 1)), ((-1, 0, 0), (0, 0, 1), (0, 1, 0)), ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
            ((0, -1, 0), (1, 0, 0), (0, 0, 1)), ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (0, 1, 0), (1, 0, 0))]
    for (a, u, v) in axes:
        a, u, v = Vector(a), Vector(u), Vector(v)
        for i in range(n):
            for j in range(n):
                pts = []
                for (ii, jj) in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)):
                    p = a + u * (-1 + 2.0 * ii / n) + v * (-1 + 2.0 * jj / n)
                    pts.append(vert(p))
                try:
                    bm.faces.new(pts)
                except ValueError:
                    pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def crater(d, c, ang_r, depth, rim=0.28):
    """radial offset of a crater centred on direction c with angular radius ang_r"""
    t = math.acos(max(-1.0, min(1.0, d.dot(c)))) / ang_r
    if t >= 1.6:
        return 0.0
    o = 0.0
    if t < 1.0:
        o -= depth * (1.0 - t * t) ** 0.8
    o += depth * rim * math.exp(-((t - 1.08) / 0.22) ** 2)
    return o


def displace(bm, fn, flatten_cuts=()):
    bm.verts.index_update()
    lows = {}
    for v in bm.verts:
        d = v.co.normalized()
        r, r0 = fn(d)
        for (n, h) in flatten_cuts:
            dn = d.dot(n)
            if dn > 1e-3:
                r = min(r, h / dn)
        v.co = d * r
        lows[v.index] = (r < r0 * 0.93)
    bm.verts.index_update()
    return lows


def paint_rock(bm, lows, seed):
    bm.verts.index_update()
    for f in bm.faces:
        c = f.calc_center_median()
        low = sum(1 for v in f.verts if lows.get(v.index, False)) >= 2
        f.material_index = 1 if (low or nz(c, seed, 0.09) > 0.22) else 0


def add_chunks(mb, bm_main_fn, specs, seed):
    """small angular rocks half buried in the surface at the given directions: (dir, size, sd)"""
    for (dv, sz, sd) in specs:
        d = Vector(dv).normalized()
        r, _ = bm_main_fn(d)
        b = hull_rock_bm((sz, sz * 0.85, sz * 0.8), seed=sd, rings=((0.0, 5, 1.0), (0.55, 6, 1.0), (1.0, 4, 0.5)), jitter=0.22, sink=0.0)
        for v in b.verts:
            v.co.z -= sz * 0.18
        patch_mats(b, sd, thresh=0.0)
        rot = MB.aim(d)
        add_bm(mb, b, loc=d * (r - sz * 0.05), rot=rot, mat=[RA, RB], smooth=False)


def build(name, fn, cuts, chunks, seed, n=9):
    coll = fresh_collection(name)
    mb = MB(name)
    bm = cube_sphere_bm(n)
    lows = displace(bm, fn, cuts)
    paint_rock(bm, lows, seed)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='SHORT_EDGE')
    add_bm(mb, bm, mat=[RA, RB], smooth=False, closed=True)
    add_chunks(mb, fn, chunks, seed)
    ob = mb.finish(name, coll, smooth_angle=5, weighted=False)
    return ob


def rdir(rng):
    return rnd_dir(rng)


# ---- A: elongated, bent potato with a ridge and a few big craters ------------------------------------------------------
def build_a():
    rng = random.Random(11)
    cr = [(rdir(rng), rng.uniform(0.28, 0.5), rng.uniform(1.6, 2.8)) for _ in range(7)]
    cr[0] = (Vector((0.15, -0.9, 0.35)).normalized(), 0.55, 3.2)
    cr[1] = (Vector((-0.5, 0.5, 0.7)).normalized(), 0.42, 2.6)

    def fn(d):
        r0 = 1.0 / math.sqrt((d.x / 17.0) ** 2 + (d.y / 8.0) ** 2 + (d.z / 7.0) ** 2)
        # banana bend + neck pinch
        r = r0 * (1.0 + 0.16 * fbm(d, 3.0, 1.3, 3)) * (1.0 - 0.10 * math.exp(-(d.x / 0.18) ** 2))
        r += 1.7 * math.exp(-(d.y / 0.17) ** 2) * max(0.0, d.z) * (1.0 - 0.6 * abs(d.x))
        for (c, a, dp) in cr:
            r += crater(d, c, a, dp)
        return r, r0
    chunks = [((0.9, 0.2, 0.15), 3.6, 5), ((-0.8, -0.4, -0.3), 3.0, 6), ((0.1, 0.9, -0.1), 2.4, 7)]
    return build('asteroid_a', fn, [], chunks, 11)


# ---- B: round, heavily pitted ------------------------------------------------------------------------------------------
def build_b():
    rng = random.Random(23)
    cr = [(rdir(rng), rng.uniform(0.2, 0.45), rng.uniform(1.4, 3.0)) for _ in range(15)]
    cr[0] = (Vector((0.3, -0.8, 0.45)).normalized(), 0.62, 4.0)
    cr[1] = (Vector((-0.7, 0.2, -0.4)).normalized(), 0.5, 3.4)

    def fn(d):
        r0 = 14.0 * (1.0 + 0.05 * (d.x * 0.5 - d.z * 0.3))
        r = r0 * (1.0 + 0.07 * fbm(d, 9.0, 1.7, 3))
        for (c, a, dp) in cr:
            r += crater(d, c, a, dp, 0.3)
        return r, r0
    chunks = [((0.2, 0.95, 0.2), 3.2, 8), ((-0.9, -0.3, 0.3), 2.6, 9), ((0.6, -0.3, -0.8), 3.0, 10)]
    return build('asteroid_b', fn, [], chunks, 23)


# ---- C: two lobes with a deep crack and fractured flat facets ----------------------------------------------------------
def build_c():
    rng = random.Random(37)
    cr = [(rdir(rng), rng.uniform(0.25, 0.4), rng.uniform(1.4, 2.4)) for _ in range(5)]
    c1, R1 = Vector((-7.0, 0.0, 0.0)), 11.0
    c2, R2 = Vector((8.5, 0.0, 0.0)), 9.0
    crack_n = Vector((0.94, 0.1, 0.32)).normalized()
    crack_d = 1.2

    def sph_r(d, c, R):
        b = d.dot(c)
        disc = b * b - c.dot(c) + R * R
        return b + math.sqrt(max(disc, 0.0))

    def fn(d):
        r1, r2 = sph_r(d, c1, R1), sph_r(d, c2, R2)
        k = 3.0
        h = max(k - abs(r1 - r2), 0.0) / k
        r0 = max(r1, r2) + h * h * k * 0.25
        r = r0 * (1.0 + 0.09 * fbm(d, 5.0, 1.5, 3))
        p = d * r
        dist = p.dot(crack_n) - crack_d
        r -= 5.0 * math.exp(-(dist / 1.5) ** 2) * (1.0 - 0.35 * abs(d.z))
        for (c, a, dp) in cr:
            r += crater(d, c, a, dp)
        return r, r0
    cuts = [(Vector((-0.6, 0.7, 0.4)).normalized(), 9.6), (Vector((-0.3, -0.75, 0.55)).normalized(), 9.0), (Vector((0.75, 0.35, -0.55)).normalized(), 7.6)]
    chunks = [((0.4, 0.9, 0.2), 3.0, 12), ((-0.9, -0.1, 0.5), 2.8, 13), ((0.5, -0.6, -0.6), 2.4, 14)]
    return build('asteroid_c', fn, cuts, chunks, 37)


BUILDERS = [('asteroid_a', build_a), ('asteroid_b', build_b), ('asteroid_c', build_c)]
for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n, budget=1200)
        park(_n)
        print('built', _n)
