"""Volcanic ("Scorched") props (brief 2, section F): obsidian_spire, lava_rock, charred_tree, vent_cone.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
import itertools
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')


def build_obsidian_spire():
    name = 'obsidian_spire'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(19)
    # rubble + cooled lava skirt at the foot
    for i, (loc, sz, sd) in enumerate([((0.0, 0.0, 0.0), (2.2, 1.9, 0.5), 11), ((1.35, -0.7, 0.0), (0.9, 0.8, 0.45), 12), ((-1.2, 0.8, 0.0), (0.85, 0.75, 0.4), 13), ((0.2, 1.4, 0.0), (0.7, 0.6, 0.35), 14)]):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 7, 1.0), (0.6, 8, 0.9), (1.0, 5, 0.55)), jitter=0.2, sink=0.08)
        cl.add(b, 'Rock_B', loc=loc, rot=(0, 0, sd), smooth=False)
    # (height, half width, azimuth, tilt, offset radius, offset azimuth, flatness, cut)
    spec = [(6.1, 0.50, 0.9, 0.06, 0.0, 0.0, 1.7, None), (4.5, 0.42, 2.2, 0.26, 0.55, 2.2, 1.8, (0.5, 0.1, -0.08)), (3.7, 0.38, 4.1, 0.34, 0.60, 4.1, 1.6, None),
            (3.0, 0.32, 5.4, 0.40, 0.70, 5.5, 1.9, (-0.4, 0.3, -0.05)), (2.3, 0.28, 1.6, 0.5, 0.78, 1.4, 1.7, None), (1.8, 0.24, 3.2, 0.62, 0.85, 3.3, 1.6, None),
            (1.2, 0.2, 0.2, 0.85, 0.95, 6.0, 1.8, None), (0.9, 0.17, 4.7, 0.95, 1.0, 4.8, 1.5, None)]
    for i, (h, r, az, tilt, off, oaz, flat, cut) in enumerate(spec):
        pos = Vector((math.cos(oaz) * off, math.sin(oaz) * off, 0.0))
        bm = crystal_bm(h, r, sides=4, tip=0.40 if cut is None else 0.16, seed=50 + i, taper=0.72, skew=(0.35 * math.cos(az + 2.0), 0.35 * math.sin(az + 2.0)), jit=0.14,
                        cut=cut, stretch=flat)
        add_bm(mb, bm, loc=pos, rot=lean_rot(az, tilt, spin=az * 1.3), mat='Obsidian', smooth=False)
    # a few glints of lava in the cracks between the shards
    for i, (x, y, r) in enumerate([(0.45, 0.2, 0.17), (-0.4, -0.35, 0.14), (0.15, -0.55, 0.12)]):
        add_bm(mb, blob_bm(r, 1, seed=3 + i, amp=0.1, amp2=0.0, sq=(1.4, 1.0, 0.25)), loc=(x, y, 0.02), mat='Glow_Lava', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def clip_hull(P_pts, planes, signs, gap):
    """convex piece of the point cloud's hull: keep (n.x - d) * sign >= gap/2 for every plane (bisect of a hull mesh, then re-hull)"""
    bm = hull_bm(P_pts)
    for (n, d), s_ in zip(planes, signs):
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        co = n * (d + s_ * gap * 0.5)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n * s_, clear_inner=True)
        if len(bm.verts) < 4:
            bm.free()
            return None
    pts = [v.co.copy() for v in bm.verts]
    bm.free()
    if len(pts) < 4:
        return None
    try:
        out = hull_bm(pts)
    except Exception:
        return None
    return out if len(out.faces) >= 4 else None


def build_lava_rock():
    name = 'lava_rock'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(61)
    base = hull_rock_bm((2.2, 1.95, 1.85), seed=9, rings=((0.0, 8, 1.0), (0.38, 9, 1.08), (0.72, 8, 0.86), (1.0, 5, 0.46)), jitter=0.13, sink=0.05)
    pts = [v.co.copy() for v in base.verts]
    base.free()
    cen = Vector((0.0, 0.0, 0.85))
    planes = []
    for n in (Vector((0.85, 0.35, 0.45)), Vector((-0.30, 0.90, 0.35)), Vector((0.25, -0.55, 0.85)), Vector((-0.8, -0.3, 0.55))):
        n = n.normalized()
        d = n.dot(cen + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(-0.1, 0.2))))
        planes.append((n, d))
    k = 0
    for signs in itertools.product((1, -1), repeat=len(planes)):
        piece = clip_hull(pts, planes, signs, 0.13)
        if piece is None:
            continue
        # skip slivers
        vol = abs(sum(f.calc_area() for f in piece.faces))
        if vol < 0.35:
            piece.free()
            continue
        c = sum((v.co for v in piece.verts), Vector()) / len(piece.verts)
        # small shift outward + tiny rotation about the piece centre (the crust has shifted a little)
        sh = (c - cen).normalized() * rng.uniform(0.008, 0.03)
        rot = Euler((rng.uniform(-0.035, 0.035), rng.uniform(-0.035, 0.035), rng.uniform(-0.05, 0.05)), 'XYZ').to_matrix().to_4x4()
        piece.transform(Matrix.Translation(c + sh) @ rot @ Matrix.Translation(-c))
        for f in piece.faces:
            f.material_index = 0
        add_bm(mb, piece, mat='Rock_B' if k % 2 == 0 else 'Rock_A', smooth=False, closed=True)
        k += 1
    # glowing lava core filling the cracks (slightly smaller than the rock; only visible through the gaps)
    core = hull_bm([Vector((p.x * 0.90, p.y * 0.90, (p.z - 0.85) * 0.90 + 0.85)) for p in pts])
    add_bm(mb, core, mat='Glow_Lava', smooth=False, closed=True)
    # loose chips at the foot
    for i, (loc, sz, sd) in enumerate([((1.45, 0.5, 0.0), (0.6, 0.5, 0.4), 71), ((-1.3, -0.5, 0.0), (0.55, 0.5, 0.35), 72), ((0.4, -1.35, 0.0), (0.5, 0.45, 0.3), 73)]):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.6, 7, 0.95), (1.0, 5, 0.55)), jitter=0.2, sink=0.05)
        add_bm(mb, b, loc=loc, rot=(0, 0, sd), mat='Rock_B', smooth=False)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_charred_tree():
    name = 'charred_tree'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(33)
    tp = catmull([(0, 0, -0.14), (0.03, 0.0, 1.2), (-0.06, 0.08, 2.6), (0.02, 0.14, 3.7)], n=3)

    def rf(u, th):
        rb = lerp(0.56, 0.30, u ** 0.8)
        fl = 1.0 + 0.9 * math.exp(-u * 12.0) * (0.3 + 0.7 * max(0.0, math.cos(5 * th + 0.4)) ** 1.5)
        rib = 1.0 + 0.17 * math.cos(7 * th + u * 2.0) + 0.08 * math.cos(3 * th - u * 3.0)
        g = 1.0 + 0.10 * nz(Vector((math.cos(th), math.sin(th), u * 5.0)), 7, 1.2)
        return rb * fl * rib * g
    sweep(mb, tp, rf, segs=10, mat='Bark', cap_a=True, cap_b=True)
    top = tp[-1]
    # splintered top: jagged spikes around the broken end
    for i, (az, h, r) in enumerate([(0.3, 1.25, 0.12), (1.5, 0.75, 0.11), (2.7, 1.0, 0.12), (3.9, 0.55, 0.10), (5.0, 0.9, 0.11), (0.9, 0.4, 0.08)]):
        d = Vector((math.cos(az), math.sin(az), 0))
        rr = 0.23 if i < 5 else 0.1
        add_bm(mb, crystal_bm(h, r, sides=4, tip=0.8, seed=5 + i, taper=0.55, jit=0.15), loc=top + d * rr + Vector((0, 0, -0.18)), rot=lean_rot(az, 0.22), mat='Bark', smooth=False)
    # glowing embers inside the broken top
    add_bm(mb, blob_bm(0.17, 1, seed=3, amp=0.12, amp2=0.0, sq=(1.2, 1.2, 0.6)), loc=top + Vector((0, 0, 0.0)), mat='Glow_Lava', smooth=True)

    def limb(z, az, el, ln, r0, bend, broken=True, seed=0):
        p0 = at_height(tp, z)
        d = Vector((math.cos(rad(az)) * math.cos(rad(el)), math.sin(rad(az)) * math.cos(rad(el)), math.sin(rad(el))))
        pts = turtle(p0 - d * 0.1, d, ln, n=4, bend=bend, toward=(0, 0, 1) if bend > 0 else (0, 0, -1), wobble=0.12, seed=seed)
        sweep(mb, pts, taper_radii(len(pts), r0, r0 * (0.62 if broken else 0.3), 0.9), segs=7, mat='Bark', cap_a=True, cap_b=True)
        return pts
    l1 = limb(2.5, 35, 38, 1.9, 0.19, 0.5, seed=1)
    limb(1.5, 200, 28, 1.25, 0.16, -0.2, seed=2)
    l3 = limb(3.1, 290, 52, 1.5, 0.14, 0.6, seed=3)
    limb(2.0, 120, 20, 0.7, 0.13, 0.0, seed=4)
    # a thin burnt twig growing from the first limb
    q = l1[2]
    tw = turtle(q, (0.2, 0.7, 0.9), 0.9, n=3, bend=0.4, toward=(0, 0, 1), seed=6)
    sweep(mb, tw, taper_radii(len(tw), 0.07, 0.025), segs=5, mat='Bark', cap_a=True, cap_b=True)
    # ember spots pressed into the bark + glowing roots at the foot
    for i, (z, az, r) in enumerate([(0.5, 0.4, 0.14), (0.9, 2.4, 0.11), (1.5, 4.2, 0.10), (1.9, 1.2, 0.12), (2.5, 3.1, 0.09), (3.0, 5.3, 0.10), (3.4, 0.2, 0.08), (0.3, 3.6, 0.12)]):
        c = at_height(tp, z)
        u = (z + 0.14) / (tp[-1].z + 0.14)
        rr = rf(u, az) * 0.9
        d = Vector((math.cos(az), math.sin(az), 0))
        add_bm(mb, blob_bm(r, 1, seed=30 + i, amp=0.15, amp2=0.0, sq=(1.0, 0.45, 1.5)), loc=Vector((c.x, c.y, z)) + d * rr, rot=MB.aim(d), mat='Glow_Lava', smooth=True)
    add_bm(mb, blob_bm(0.3, 1, seed=9, amp=0.15, amp2=0.0, sq=(1.5, 1.2, 0.3)), loc=(0.25, -0.35, 0.02), mat='Glow_Lava', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=50, weighted=False)


def build_vent_cone():
    name = 'vent_cone'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    prof = [(0.0, -0.12), (2.50, -0.12), (2.22, 0.28), (1.86, 0.80), (1.56, 1.40), (1.40, 1.95), (1.35, 2.40), (1.40, 2.64), (1.22, 2.56), (1.04, 2.34), (0.88, 2.20), (0.0, 2.14)]
    rings = lathe_rings(prof, c=(0, 0, 0), segs=16, lobes=6, lobe_amp=0.12, lobe_from=0.3, noise_amp=0.05, seed=4.0, ph=0.5)
    part = mb.grid(rings, closed=True, mat='Rock_B', smooth=True, cap_a=False, cap_b=False)
    for bi in (3, 5):
        mb.paint(part.bands[bi], 'Rock_A')
    mb.paint(part.bands[len(part.bands) - 1], 'Glow_Lava')
    mb.bm.normal_update()
    surf = Surf(bm=mb.bm)
    # lava tongues running down the flanks (raised glowing ribbons that follow the real surface)
    for i, (th, r_end, w) in enumerate([(0.3, 2.15, 0.34), (1.9, 1.75, 0.28), (3.3, 2.3, 0.36), (4.8, 1.85, 0.30)]):
        pts = []
        for j in range(7):
            rr = lerp(1.32, r_end, j / 6)
            a = th + 0.10 * math.sin(j * 1.3 + i)
            pts.append(Vector((rr * math.cos(a), rr * math.sin(a), 0.0)))
        strip_on_surface(mb, surf, pts, lambda t, w=w: w * (0.5 + 0.9 * math.sin(math.pi * min(1.0, 0.15 + 0.85 * t))) * (1.0 - 0.7 * t * t), 'Glow_Lava', lift=0.045,
                         direction=(0, 0, -1), start_off=4.0, step=0.14, rows=3)
    # jagged crown stones around the crater rim
    for i in range(6):
        a = TAU * i / 6 + 0.3
        b = hull_rock_bm((0.55, 0.5, 0.34 + 0.1 * (i % 3)), seed=40 + i, rings=((0.0, 5, 1.0), (0.6, 6, 0.8), (1.0, 4, 0.4)), jitter=0.2, sink=0.05)
        cl.add(b, 'Rock_A' if i % 2 else 'Rock_B', loc=(1.38 * math.cos(a), 1.38 * math.sin(a), 2.52), rot=(0.0, 0.0, a), smooth=False, cull=False)
    # boulders / ash blocks at the foot
    for i, (x, y, sz, sd) in enumerate([(2.7, 0.6, (0.9, 0.8, 0.6), 51), (-2.2, 1.6, (0.8, 0.7, 0.55), 52), (0.8, -2.7, (0.9, 0.7, 0.5), 53), (-1.5, -2.1, (0.6, 0.55, 0.4), 54)]):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.6, 7, 0.95), (1.0, 5, 0.55)), jitter=0.2, sink=0.08)
        cl.add(b, 'Rock_B', loc=(x, y, -0.05), rot=(0, 0, sd), smooth=False, cull=False)
    return mb.finish("Body__" + name, coll, smooth_angle=44, weighted=False)


BUILDERS = [('obsidian_spire', build_obsidian_spire), ('lava_rock', build_lava_rock), ('charred_tree', build_charred_tree), ('vent_cone', build_vent_cone)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
