"""Dead moon / airless props (brief 2, section H): moon_rock_a, moon_rock_b, probe_wreck.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')


def sink_to(ob, zmin_target):
    zmin = min(v.co.z for v in ob.data.vertices)
    for v in ob.data.vertices:
        v.co.z += zmin_target - zmin
    ob.data.update()


def build_moon_rock_a():
    name = 'moon_rock_a'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(8)
    # sharp, angular regolith rock: convex hull of a few point rings (big flat facets), chipped edges
    b = hull_rock_bm((1.75, 1.45, 1.5), seed=14, rings=((0.0, 6, 1.0), (0.33, 7, 1.12), (0.7, 6, 0.78), (1.0, 3, 0.30)), jitter=0.26, ztop_jit=0.14, sink=0.06, shear=0.20)
    chip_edges(b, rng, 7, 0.10, min_angle=0.5)
    cl.add(b, 'Rock_A', rot=(0, 0, 0.4), smooth=False)
    for i, (loc, sz, sd, rz) in enumerate([((1.05, -0.65, 0.0), (0.75, 0.6, 0.55), 15, 1.1), ((-0.95, 0.75, 0.0), (0.55, 0.45, 0.4), 16, 2.4)]):
        s = hull_rock_bm(sz, seed=sd, rings=((0.0, 5, 1.0), (0.5, 6, 1.0), (1.0, 3, 0.35)), jitter=0.28, sink=0.05, shear=0.15)
        chip_edges(s, rng, 2, 0.06, min_angle=0.5)
        cl.add(s, 'Rock_A', loc=loc, rot=(0, 0, rz), smooth=False)
    return mb.finish("Body__" + name, coll, smooth_angle=2, weighted=False)


def shard_bm(L, H, T, seed):
    """thin wedge / plate shard standing on its base: base rectangle (L x T) narrowing to a ragged top edge at height H"""
    rng = random.Random(seed * 5 + 1)
    pts = [(-L / 2, -T / 2, 0), (-L * 0.45, T / 2, 0), (L / 2, -T * 0.4, 0), (L * 0.42, T / 2, 0),
           (rng.uniform(-L * 0.25, 0.0), -T * 0.12, H), (rng.uniform(L * 0.05, L * 0.28), T * 0.10, H * rng.uniform(0.72, 0.9)), (rng.uniform(-L * 0.4, -L * 0.25), 0.0, H * 0.55)]
    return hull_bm(pts)


def build_moon_rock_b():
    name = 'moon_rock_b'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(21)
    # flat shard-like rock: big wedge plate leaning, a second plate leaning against it, a flat slab and loose splinters
    s1 = shard_bm(2.5, 1.45, 0.55, 3)
    chip_edges(s1, rng, 3, 0.08, min_angle=0.5)
    cl.add(s1, 'Rock_A', loc=(0, 0, 0.0), rot=(0.30, -0.18, 0.5), smooth=False)
    s2 = shard_bm(1.7, 1.05, 0.42, 4)
    chip_edges(s2, rng, 2, 0.06, min_angle=0.5)
    cl.add(s2, 'Rock_A', loc=(0.85, -0.85, 0.0), rot=(-0.34, 0.25, 2.5), smooth=False)
    s3 = shard_bm(1.2, 0.55, 0.34, 5)
    cl.add(s3, 'Rock_A', loc=(-0.95, -0.55, 0.0), rot=(0.1, 0.15, 4.3), smooth=False)
    s4 = shard_bm(0.8, 0.4, 0.22, 6)
    cl.add(s4, 'Rock_A', loc=(0.1, 0.9, 0.0), rot=(0.2, -0.25, 1.2), smooth=False)
    ob = mb.finish("Body__" + name, coll, smooth_angle=2, weighted=False)
    sink_to(ob, -0.07)
    return ob


def build_probe_wreck():
    name = 'probe_wreck'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(3)
    Rb = Euler((0.14, -0.20, 0.45), 'XYZ').to_matrix()
    bc = Vector((0.0, 0.0, 0.52))

    def loc(p):
        return bc + Rb @ Vector(p)
    # boxy bus (half sunk, tilted), scorched lower half
    mb.rbox((1.25, 1.0, 0.85), center=bc, rot=Rb, bevel=0.05, mat='Metal')
    mb.paint_where(lambda c, f: c.z < 0.46, 'Hull_Dark', only_mats=['Metal'])
    mb.rbox((1.05, 0.80, 0.05), center=loc((0, 0, 0.44)), rot=Rb, bevel=0.015, mat='Hull_Dark')
    mb.rbox((0.55, 0.05, 0.42), center=loc((0.2, -0.51, 0.05)), rot=Rb, bevel=0.012, mat='Hull_Dark')
    mb.rbox((0.34, 0.05, 0.55), center=loc((-0.3, 0.51, 0.0)), rot=Rb, bevel=0.012, mat='Hull_Dark')
    mb.rbox((0.05, 0.6, 0.35), center=loc((0.63, 0.0, 0.1)), rot=Rb, bevel=0.012, mat='Hull_Dark')
    mb.cyl(0.30, 0.34, center=loc((0.1, 0.0, -0.52)), segs=10, r2=0.15, mat='Hull_Dark', rot=Rb)
    mb.sphere(0.05, center=loc((0.42, -0.30, 0.50)), segs=8, mat='Emissive_Light')
    # big dish leaning on the ground, torn rim, three feed struts (one snapped) + feed horn
    dc = Vector((-1.35, 0.15, 0.68))
    axis = Vector((-0.55, 0.1, 0.85)).normalized()
    Md = MB.xf(dc, MB.aim(axis))
    prof = [(0.0, 0.0, 'Metal'), (0.30, 0.04, 'Metal'), (0.62, 0.15, 'Metal'), (0.92, 0.34, 'Metal'), (1.16, 0.60, 'Metal'), (1.18, 0.56, 'Hull_Dark'),
            (0.92, 0.27, 'Hull_Dark'), (0.55, 0.06, 'Hull_Dark'), (0.0, -0.07, 'Hull_Dark')]
    part = mb.lathe_mats(prof, segs=14, m=Md)
    # dent: push a few front vertices of the dish inwards, tear one rim vertex
    for v in part.verts:
        p = Md.inverted() @ v.co
        d = math.hypot(p.x - 0.55, p.y + 0.35)
        if d < 0.45:
            v.co = Md @ Vector((p.x, p.y, p.z - 0.10 * (1 - d / 0.45)))
    for k in (0, 2):
        a = TAU * (k + 0.3) / 3
        p0 = Md @ Vector((1.12 * math.cos(a), 1.12 * math.sin(a), 0.56))
        p1 = Md @ Vector((0.0, 0.0, 0.85))
        mb.tube([p0, p0.lerp(p1, 0.55 if k == 0 else 0.5)], 0.03, segs=5, mat='Metal')
    a = TAU * (1 + 0.3) / 3
    p0 = Md @ Vector((1.12 * math.cos(a), 1.12 * math.sin(a), 0.56))
    mb.tube([p0, p0 + Vector((0.2, 0.1, 0.35)), p0 + Vector((0.45, 0.0, 0.45))], 0.03, segs=5, mat='Metal')
    mb.cyl(0.07, 0.30, center=Md @ Vector((0.0, 0.0, 0.88)), segs=8, mat='Hull_Dark', rot=MB.aim(axis))
    # mast with a kink, cross bar, small whip
    p0 = loc((0.35, 0.2, 0.42))
    p1 = p0 + Vector((0.05, 0.05, 1.25))
    p2 = p1 + Vector((0.4, 0.1, 0.8))
    mb.tube([p0 - Vector((0, 0, 0.1)), p0, p1, p2], [0.07, 0.055, 0.045, 0.028], segs=7, mat='Metal')
    mb.cyl(0.02, 0.85, center=p1 + Vector((0.05, 0.0, 0.35)), segs=5, mat='Metal', rot=(0, math.pi / 2, 0.35))
    mb.cyl(0.012, 0.5, center=p2 + Vector((0.18, 0.05, 0.22)), segs=4, mat='Hull_Dark', rot=(0.1, 0.5, 0))
    mb.sphere(0.09, center=p2, segs=8, mat='Hull_Dark')
    # solar array: boom, panel, bent second panel (hinged), ribs
    a0 = loc((0.55, 0.3, 0.1))
    R1 = Euler((0.0, 0.22, 0.28), 'XYZ').to_matrix()
    c1 = Vector((1.75, 0.95, 0.52))
    mb.tube([a0, a0.lerp(c1, 0.5) + Vector((0, 0, 0.1)), c1 - R1 @ Vector((0.7, 0, 0))], 0.04, segs=5, mat='Metal')
    mb.rbox((1.4, 0.78, 0.05), center=c1, rot=R1, bevel=0.012, mat='Hull_Dark')
    for xo in (-0.46, 0.0, 0.46):
        mb.rbox((0.035, 0.80, 0.062), center=c1 + R1 @ Vector((xo, 0, 0.0)), rot=R1, bevel=0.008, mat='Metal')
    mb.rbox((1.42, 0.035, 0.062), center=c1 + R1 @ Vector((0, -0.38, 0)), rot=R1, bevel=0.008, mat='Metal')
    hinge = c1 + R1 @ Vector((0.7, 0, 0))
    R2 = R1 @ Matrix.Rotation(-0.95, 3, 'Y')
    c2 = hinge + R2 @ Vector((0.5, 0, 0))
    mb.rbox((1.0, 0.78, 0.05), center=c2, rot=R2, bevel=0.012, mat='Hull_Dark')
    for xo in (-0.3, 0.1):
        mb.rbox((0.035, 0.80, 0.062), center=c2 + R2 @ Vector((xo, 0, 0.0)), rot=R2, bevel=0.008, mat='Metal')
    # scattered plates + a half buried fuel tank
    for i, (x, y, sx, sy, rz, m_) in enumerate([(1.0, -1.35, 0.55, 0.38, 0.6, 'Metal'), (-0.2, -1.5, 0.42, 0.3, 2.1, 'Hull_Dark'), (2.4, -0.4, 0.5, 0.32, 4.0, 'Metal'), (-0.6, 1.4, 0.4, 0.3, 1.2, 'Hull_Dark')]):
        mb.rbox((sx, sy, 0.035), center=(x, y, 0.03), rot=(rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), rz), bevel=0.01, mat=m_)
    mb.sphere(0.30, center=(0.95, 1.2, 0.08), segs=10, mat='Metal')
    mb.cyl(0.06, 0.12, center=(0.95, 1.2, 0.36), segs=6, mat='Hull_Dark')
    ob = mb.finish("Body__" + name, coll, smooth_angle=38, weighted=False)
    return ob


BUILDERS = [('moon_rock_a', build_moon_rock_a), ('moon_rock_b', build_moon_rock_b), ('probe_wreck', build_probe_wreck)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
