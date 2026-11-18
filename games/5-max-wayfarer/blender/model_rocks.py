"""Generic rocks (brief 2, section B): rock_a, rock_b, rock_c, rock_d, boulder_big.  Rock_A / Rock_B (tinted by the game per planet).
Origin = ground contact at the bottom centre (a few cm of the base sink below z=0).  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')
RA, RB = 'Rock_A', 'Rock_B'


def build_rock_a():
    name = 'rock_a'
    coll = fresh_collection(name)
    mb = MB(name)
    bm = rock_bm((2.15, 1.95, 1.8), seed=4, subdiv=3, amp=0.30, freq=1.1, cuts=4, cut_lo=0.60, cut_hi=0.85, bottom=0.5, sink=0.08, zbias=(-0.6, 1.0))
    patch_mats(bm, 4, thresh=0.16, freq=0.8)
    add_bm(mb, bm, mat=[RA, RB], smooth=False)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_rock_b():
    name = 'rock_b'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(12)
    cl = Cluster(mb)
    # angular slab, leaning: flat top + bottom prism, chipped edges
    slab = block_bm((2.7, 1.55, 1.15), seed=6, n=6, taper=0.88, jit=0.14, sink=0.0, skew=(0.12, 0.04))
    chip_edges(slab, rng, 6, 0.10, min_angle=0.5)
    patch_mats(slab, 6, thresh=0.1)
    cl.add(slab, [RA, RB], loc=(0, 0, 0.0), rot=(0.14, -0.16, 0.45), smooth=False)
    s2 = block_bm((1.5, 0.95, 0.75), seed=16, n=6, taper=0.85, jit=0.15, sink=0.0, skew=(0.1, 0.0))
    chip_edges(s2, rng, 3, 0.07, min_angle=0.5)
    patch_mats(s2, 16, thresh=0.0)
    cl.add(s2, [RA, RB], loc=(1.05, -0.85, 0.0), rot=(-0.2, 0.25, 1.9), smooth=False, keep=False)
    # lowest point -> z = -0.08 (done below by shifting the finished mesh)
    ob = mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)
    zmin = min(v.co.z for v in ob.data.vertices)
    for v in ob.data.vertices:
        v.co.z += -0.08 - zmin
    ob.data.update()
    return ob


def build_rock_c():
    name = 'rock_c'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(21)
    big = rock_bm((1.95, 1.75, 1.6), seed=7, subdiv=3, amp=0.18, cuts=6, cut_lo=0.68, cut_hi=0.9, bottom=0.5, sink=0.08, zbias=(-0.6, 1.0))
    patch_mats(big, 7, thresh=0.16, freq=0.8)
    cl.add(big, [RA, RB], loc=(-0.2, 0.1, 0), smooth=False)
    med = hull_rock_bm((1.35, 1.15, 1.30), seed=8, rings=((0.0, 7, 1.0), (0.5, 8, 1.05), (1.0, 5, 0.5)), jitter=0.2, sink=0.06)
    chip_edges(med, rng, 3, 0.07)
    patch_mats(med, 8, thresh=-0.05)
    cl.add(med, [RA, RB], loc=(1.45, 0.55, 0), rot=(0, 0, 0.7), smooth=False)
    small = hull_rock_bm((0.95, 0.85, 0.8), seed=9, rings=((0.0, 6, 1.0), (0.55, 7, 1.0), (1.0, 5, 0.55)), jitter=0.22, sink=0.05)
    patch_mats(small, 9, thresh=0.0)
    cl.add(small, [RA, RB], loc=(-0.55, -1.15, 0), rot=(0, 0, 2.1), smooth=False)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_rock_d():
    name = 'rock_d'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(33)
    h, r0, sides = 3.5, 0.98, 7
    levels = [(0.0, 1.0), (0.10, 1.10), (0.30, 0.86), (0.48, 0.72), (0.62, 0.56), (0.78, 0.38), (0.92, 0.17), (1.0, 0.0)]
    a0 = rng.uniform(0, TAU)
    rings = [[Vector((0.05, 0.0, -0.14))] * sides]
    for (zf, rf) in levels:
        z = zf * h - 0.06
        cx = 0.55 * zf ** 2 * 1.0 + rng.uniform(-0.04, 0.04)
        cy = 0.18 * zf + rng.uniform(-0.04, 0.04)
        ring = []
        for k in range(sides):
            a = a0 + TAU * (k + (rng.uniform(-0.18, 0.18) if rf > 0 else 0)) / sides
            rr = r0 * rf * (1 + rng.uniform(-0.20, 0.20) * (1 if rf > 0 else 0))
            ring.append(Vector((cx + rr * math.cos(a), cy + rr * math.sin(a), z)))
        rings.append(ring)
    bm = rings_bm(rings)
    for f in bm.faces:
        c = f.calc_center_median()
        f.material_index = 1 if (c.z < 0.9 or nz(c, 3, 1.6) > 0.18) else 0
    cl = Cluster(mb)
    cl.add(bm, [RA, RB], smooth=False, cull=False)
    # two small boulders at the foot
    for i, (loc, sz, sd) in enumerate([((0.95, -0.55, 0), (0.95, 0.85, 0.7), 41), ((-0.85, 0.7, 0), (0.8, 0.7, 0.6), 42)]):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.55, 7, 1.0), (1.0, 5, 0.55)), jitter=0.2, sink=0.05)
        patch_mats(b, sd, thresh=0.0)
        cl.add(b, [RA, RB], loc=loc, rot=(0, 0, sd), smooth=False)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_boulder_big():
    name = 'boulder_big'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(55)

    def blk(size, seed, loc, rot, mat_, n=8, taper=0.84, skew=(0, 0), sub=True, tilt=(0.0, 0.0)):
        b = block_bm(size, seed=seed, n=n, taper=taper, jit=0.16, skew=skew)
        if sub:
            # one subdivision of the side faces + rugged noise (keeps top / bottom flat)
            sides = [e for e in b.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.2]
            bmesh.ops.subdivide_edges(b, edges=sides, cuts=1, use_grid_fill=True)
            top = max(v.co.z for v in b.verts)
            for v in b.verts:
                if -0.01 < v.co.z < top - 0.01 and v.co.z > 0.01:
                    d = nz(v.co, seed, 0.55) * 0.20
                    v.co.x += v.co.x * d * 0.35
                    v.co.y += v.co.y * d * 0.35
        chip_edges(b, rng, 4, 0.16)
        for f in b.faces:
            f.material_index = mat_
        cl.add(b, [RA, RB], loc=loc, rot=(tilt[0], tilt[1], rot[2]), smooth=False, cull=True)
    blk((7.2, 6.0, 2.9), 1, (0, 0, 0), (0, 0, 0.2), 0, n=9)
    blk((5.5, 4.6, 2.5), 2, (-0.5, 0.3, 2.5), (0, 0, 0.9), 1, n=8, skew=(0.04, 0.02), tilt=(0.05, -0.06))
    blk((3.8, 3.3, 1.5), 3, (-0.8, 0.5, 4.5), (0, 0, 0.4), 0, n=7, taper=0.9, sub=False, tilt=(-0.04, 0.05))
    # ledges / buttresses around the foot
    blk((3.0, 2.2, 1.6), 4, (3.2, -2.0, 0), (0, 0, 0.5), 1, n=6, sub=False)
    blk((2.4, 2.0, 1.2), 5, (-3.3, 1.6, 0), (0, 0, 2.0), 1, n=6, sub=False)
    blk((2.8, 2.0, 1.9), 6, (2.6, 2.4, 2.2), (0, 0, 1.2), 0, n=6, sub=False, taper=0.8)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


BUILDERS = [('rock_a', build_rock_a), ('rock_b', build_rock_b), ('rock_c', build_rock_c), ('rock_d', build_rock_d), ('boulder_big', build_boulder_big)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
