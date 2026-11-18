"""Irradiated props (brief 2, section I): crystal_cluster_a, crystal_cluster_b, crystal_cluster_c, rad_fungus.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')


def glow_crystal(mb, h, r, az, tilt, pos, seed, sides=6, tip=0.3, taper=0.84, skew=(0.0, 0.0), cut=None, stretch=1.0, core_k=(0.46, 0.80), base_cap=True):
    """translucent flat-shaded shell (Crystal_Main) with a smaller glowing crystal (Glow_Main) buried inside it"""
    R = lean_rot(az, tilt)
    add_bm(mb, crystal_bm(h, r, sides=sides, tip=tip, seed=seed, taper=taper, skew=skew, jit=0.08, cut=cut, stretch=stretch, base_cap=base_cap), loc=pos, rot=R, mat='Crystal_Main', smooth=False)
    up = R @ Vector((0, 0, 1))
    cb = crystal_bm(h * core_k[1], r * core_k[0], sides=sides, tip=0.38, seed=seed + 100, taper=0.78, skew=(skew[0] * 0.3, skew[1] * 0.3), jit=0.05, stretch=stretch, base_cap=False)
    add_bm(mb, cb, loc=Vector(pos) + up * h * 0.10, rot=R, mat='Glow_Main', smooth=False, closed=False)


def rubble(mb, cl, items, mat='Rock_B'):
    for i, (loc, sz, sd) in enumerate(items):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.6, 7, 0.95), (1.0, 5, 0.6)), jitter=0.2, sink=0.07)
        cl.add(b, mat, loc=loc, rot=(0, 0, sd), smooth=False, cull=False)


def place(spec, mb, tipk=0.28, skew_k=0.3):
    for i, row in enumerate(spec):
        h, r, az, tilt, off, oaz, sides = row[:7]
        cut = row[7] if len(row) > 7 else None
        pos = Vector((math.cos(oaz) * off, math.sin(oaz) * off, -0.03))
        glow_crystal(mb, h, r, az, tilt, pos, 10 + i * 3, sides=sides, tip=tipk if cut is None else 0.12, skew=(skew_k * math.cos(az + 1.0), skew_k * math.sin(az + 1.0)), cut=cut)


def build_crystal_cluster_a():
    name = 'crystal_cluster_a'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rubble(mb, cl, [((0, 0, 0), (1.5, 1.3, 0.34), 21), ((0.85, -0.6, 0), (0.6, 0.5, 0.28), 22), ((-0.8, 0.7, 0), (0.55, 0.5, 0.26), 23)])
    spec = [(3.05, 0.36, 0.6, 0.07, 0.0, 0.0, 6), (2.3, 0.28, 2.0, 0.34, 0.46, 2.0, 6), (2.55, 0.30, 3.6, 0.30, 0.50, 3.6, 6), (1.95, 0.26, 5.0, 0.42, 0.5, 5.0, 5),
            (1.45, 0.2, 0.9, 0.60, 0.56, 0.9, 6, (0.4, 0.1, -0.05)), (1.1, 0.18, 2.8, 0.72, 0.6, 2.8, 5), (0.8, 0.15, 4.3, 0.85, 0.66, 4.4, 6), (0.7, 0.13, 5.8, 0.92, 0.62, 5.8, 5)]
    place(spec, mb)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_crystal_cluster_b():
    name = 'crystal_cluster_b'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(44)
    rubble(mb, cl, [((0, 0, 0), (2.1, 1.8, 0.28), 31), ((1.0, 0.8, 0), (0.7, 0.6, 0.22), 32), ((-1.1, -0.4, 0), (0.8, 0.6, 0.22), 33)])
    # wide low bed of many small crystals fanning out
    spec = [(1.25, 0.2, 0.4, 0.12, 0.0, 0.0, 6), (0.95, 0.17, 1.9, 0.38, 0.35, 1.9, 5), (1.0, 0.18, 3.3, 0.40, 0.4, 3.3, 6), (0.85, 0.16, 4.9, 0.45, 0.4, 4.9, 5)]
    n = 11
    for i in range(n):
        a = TAU * i / n + rng.uniform(-0.25, 0.25)
        off = rng.uniform(0.62, 1.15)
        h = rng.uniform(0.38, 0.8)
        spec.append((h, rng.uniform(0.09, 0.14), a + rng.uniform(-0.3, 0.3), rng.uniform(0.35, 0.95), off, a, rng.choice((5, 6)), (0.3, 0.1, -0.03) if i % 4 == 0 else None))
    place(spec, mb, tipk=0.30, skew_k=0.25)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_crystal_cluster_c():
    name = 'crystal_cluster_c'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rubble(mb, cl, [((0, 0, 0), (1.7, 1.4, 0.4), 41), ((0.9, -0.7, 0), (0.7, 0.55, 0.3), 42), ((-0.85, 0.6, 0), (0.6, 0.5, 0.26), 43)])
    # tall, slender towers with a twin, a broken one and a few shards
    spec = [(4.6, 0.36, 1.0, 0.05, 0.0, 0.0, 6), (3.6, 0.28, 2.6, 0.20, 0.45, 2.6, 6), (3.0, 0.26, 4.4, 0.24, 0.5, 4.4, 5, (0.45, 0.2, -0.06)), (2.2, 0.2, 5.6, 0.34, 0.5, 5.6, 6),
            (1.6, 0.18, 0.4, 0.5, 0.55, 0.4, 5), (1.2, 0.15, 3.5, 0.62, 0.6, 3.5, 6), (0.8, 0.12, 1.6, 0.85, 0.62, 1.6, 5)]
    place(spec, mb, tipk=0.2, skew_k=0.22)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_rad_fungus():
    name = 'rad_fungus'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(5)
    # short gnarled stump with a splintered top
    sp = catmull([(0, 0, -0.08), (0.02, 0.0, 0.28), (-0.03, 0.02, 0.60)], n=2)
    tr = trunk_radius(0.30, 0.25, flare=0.7, lobes=4, phase=0.5, seed=3, gnarl=0.12, decay=7.0)
    sweep(mb, sp, tr, segs=8, mat='Bark', cap_a=True, cap_b=True)
    top = sp[-1]
    for i, (az, h, r) in enumerate([(0.2, 0.34, 0.08), (1.7, 0.2, 0.07), (3.0, 0.3, 0.08), (4.4, 0.16, 0.06)]):
        add_bm(mb, crystal_bm(h, r, sides=4, tip=0.75, seed=3 + i, taper=0.6, jit=0.15), loc=top + Vector((math.cos(az) * 0.17, math.sin(az) * 0.17, -0.10)), rot=lean_rot(az, 0.2), mat='Bark', smooth=False)
    # shelf brackets spiralling up the stump (full flattened discs whose inner half is buried in the trunk)
    prof = [(0.0, 0.07), (0.55, 0.05), (1.0, -0.02), (0.55, -0.06), (0.0, -0.04)]
    shelves = [(0.15, 0.2, 0.37, 0.10), (0.27, 2.3, 0.33, -0.12), (0.37, 4.2, 0.30, 0.14), (0.47, 0.9, 0.28, -0.08), (0.55, 3.2, 0.24, 0.1), (0.07, 5.3, 0.27, 0.06), (0.43, 5.7, 0.2, 0.2)]
    for i, (z, az, R, tilt) in enumerate(shelves):
        pr = [(r * R, zz * R * 2.0) for (r, zz) in prof]
        rings = lathe_rings(pr, c=(0, 0, 0), segs=8, lobes=3, lobe_amp=0.10, lobe_from=0.4, noise_amp=0.05, seed=i * 1.7)
        c = Vector((math.cos(az) * 0.27, math.sin(az) * 0.27, z))
        m = MB.xf(c, lean_rot(az + 1.5, tilt))
        rings = [[m @ p for p in ring] for ring in rings]
        mb.grid(rings, closed=True, mat='Glow_Main', smooth=True, cap_a=False, cap_b=False)
    # glowing spore buds around the foot
    for i, (x, y, r) in enumerate([(0.38, 0.12, 0.07), (-0.34, 0.3, 0.06), (0.1, -0.4, 0.075), (-0.3, -0.25, 0.05), (0.3, -0.3, 0.045)]):
        add_bm(mb, blob_bm(r, 1, seed=3 + i, amp=0.1, amp2=0.0, sq=(1.0, 1.0, 1.3)), loc=(x, y, 0.04), mat='Glow_Main', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=48, weighted=False)


BUILDERS = [('crystal_cluster_a', build_crystal_cluster_a), ('crystal_cluster_b', build_crystal_cluster_b), ('crystal_cluster_c', build_crystal_cluster_c),
            ('rad_fungus', build_rad_fungus)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
