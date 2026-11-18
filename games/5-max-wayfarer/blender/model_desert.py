"""Desert ("Arid") props (brief 2, section D): cactus_a, cactus_b, dead_tree, desert_shrub, mesa_rock, rock_arch.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')
RA, RB = 'Rock_A', 'Rock_B'


def flower_on(mb, c, nrm, r, seed, petals=6, cup=0.5, core='Foliage_B'):
    bmf, cores, pet = flower_bm(c, nrm, radius=r, petals=petals, seed=seed, cup=cup, core_r=0.34)
    cs = set(cores)
    for f in bmf.faces:
        f.material_index = 0 if f in cs else 1
    return add_bm(mb, bmf, mat=[core, 'Foliage_Flower'], smooth=True, closed=False)


def build_cactus_a():
    name = 'cactus_a'
    coll = fresh_collection(name)
    mb = MB(name)
    # saguaro trunk, ribbed, rounded top; total height 4.5 m
    n_body = 9
    body = [Vector((0.05 * math.sin(i * 0.8), 0.04 * math.cos(i * 0.6), -0.12 + (4.5 - 0.34 + 0.12) * i / (n_body - 1))) for i in range(n_body)]
    rr = dome_radii(n_body, 0.47, 0.34, n_dome=4, power=0.8)
    path = dome_path(body, 0.34, n_dome=4)
    sweep(mb, path, ribbed(rr, ribs=8, amp=0.17, phase=0.2), segs=16, mat='Foliage_A', cap_a=True, cap_b=True, smooth=False)
    top = path[-1]

    def arm(z0, az, reach, rise, r_arm, ph):
        d = Vector((math.cos(rad(az)), math.sin(rad(az)), 0))
        ctrl = [Vector((0, 0, z0)), d * 0.55 + Vector((0, 0, z0)), d * (reach - 0.1) + Vector((0, 0, z0 + 0.10)), d * reach + Vector((0, 0, z0 + 0.50)),
                d * reach + Vector((0, 0, z0 + 0.5 + rise * 0.55)), d * reach + Vector((0, 0, z0 + 0.5 + rise))]
        pts = catmull(ctrl, n=2)
        pts = dome_path(pts, r_arm, n_dome=3)
        radii = dome_radii(len(pts) - 3, r_arm, r_arm * 0.92, n_dome=3)
        sweep(mb, pts, ribbed(radii, ribs=6, amp=0.17, phase=ph), segs=12, mat='Foliage_A', cap_a=True, cap_b=True, smooth=False)
        return pts[-1]
    t1 = arm(1.9, 25, 1.0, 1.55, 0.25, 0.0)
    t2 = arm(2.75, 205, 0.9, 1.0, 0.22, 0.5)
    # flowers on the tips
    for i, p in enumerate((top, t1, t2)):
        flower_on(mb, p + Vector((0, 0, -0.04)), Vector((0, 0, 1)), 0.2 if i == 0 else 0.15, 5 + i, petals=6, cup=0.6)
    return mb.finish("Body__" + name, coll, smooth_angle=35, weighted=False)


def pad_chain(rng, base, az0, count, hs0, max_top=1.45):
    """prickly-pear pads: each new pad grows from the rim of one of the last pads. returns [(centre, up, normal, half sizes (thin, wide, tall))]"""
    up = Vector((0.12 * math.cos(az0 + 1.5), 0.12 * math.sin(az0 + 1.5), 1.0)).normalized()
    nrm = Vector((math.cos(az0), math.sin(az0), 0))
    nrm = (nrm - up * nrm.dot(up)).normalized()
    hs = Vector(hs0)
    pads = [(Vector(base) + up * hs.z * 0.75, up, nrm, hs)]
    tries = 0
    while len(pads) < count and tries < 80:
        tries += 1
        pc, pu, pn, ph = pads[rng.randrange(0, len(pads)) if rng.random() < 0.6 else len(pads) - 1]
        wide = pu.cross(pn).normalized()
        ang = rng.choice((-1, 1)) * rng.uniform(0.35, 1.25)
        dirp = (pu * math.cos(ang) + wide * math.sin(ang)).normalized()
        rr = 1.0 / math.sqrt((math.cos(ang) / ph.z) ** 2 + (math.sin(ang) / ph.y) ** 2)
        rim = pc + dirp * rr
        cu = (dirp + Vector((0, 0, 0.5))).normalized()
        cn = Quaternion(cu, rng.uniform(-1.4, 1.4)) @ pn
        cn = (cn - cu * cn.dot(cu)).normalized()
        ch = ph * rng.uniform(0.84, 0.96)
        cc = rim + cu * ch.z * 0.72
        if cc.z + ch.z > max_top:
            continue
        pads.append((cc, cu, cn, ch))
    return pads


def build_cactus_b():
    name = 'cactus_b'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(15)
    # barrel cactus: ribbed squashed dome
    rings = []
    for k in range(7):
        phi = rad(-62 + (90 + 62) * k / 6)
        rings.append((0.47 * math.cos(phi), 0.34 + 0.38 * math.sin(phi)))
    rings[-1] = (0.0, rings[-1][1])
    segs, ribs = 12, 6
    bx, by = 0.55, -0.30
    rg = [[Vector((bx, by, -0.03))] * segs]
    for (r_, z) in rings:
        ring = []
        for k in range(segs):
            th = TAU * k / segs
            rr_ = r_ * (1 + 0.15 * math.cos(ribs * th))
            ring.append(Vector((bx + rr_ * math.cos(th), by + rr_ * math.sin(th), z)))
        rg.append(ring)
    cl.add(rings_bm(rg), 'Foliage_A', smooth=False)
    flower_on(mb, Vector((bx, by, 0.70)), Vector((0, 0, 1)), 0.17, 3, petals=7, cup=0.5)
    # prickly pear: flat oval pads standing on their edges, each new pad grows from the rim of its parent (deterministic fan)
    hs0 = Vector((0.095, 0.40, 0.36))
    up0 = Vector((0.10, 0.0, 1.0)).normalized()
    n0 = Vector((0.25, -1.0, 0.0))
    n0 = (n0 - up0 * n0.dot(up0)).normalized()
    pads = [(Vector((-0.55, 0.20, 0.0)) + up0 * hs0.z * 0.8, up0, n0, hs0)]
    chain = [(0, -0.85, 0.9, 0.94), (0, 0.75, -0.9, 0.94), (2, 0.35, 1.2, 0.9), (1, -0.35, -1.1, 0.9)]
    for (pi, ang, rotn, sc) in chain:
        pc, pu, pn, ph = pads[pi]
        wide = pu.cross(pn).normalized()
        dirp = (pu * math.cos(ang) + wide * math.sin(ang)).normalized()
        rr = 1.0 / math.sqrt((math.cos(ang) / ph.z) ** 2 + (math.sin(ang) / ph.y) ** 2)
        cu = (dirp + Vector((0, 0, 0.55))).normalized()
        cn = Quaternion(cu, rotn) @ pn
        cn = (cn - cu * cn.dot(cu)).normalized()
        ch = ph * sc
        pads.append((pc + dirp * rr + cu * ch.z * 0.50, cu, cn, ch))
    for i, (c, u_, n_, hs) in enumerate(pads):
        y_ = u_.cross(n_).normalized()
        R = Matrix((n_, y_, u_)).transposed()
        cl.add(blob_bm(1.0, 2, seed=30 + i, amp=0.05, amp2=0.0, sq=hs), 'Foliage_A', loc=c, rot=R, smooth=True)
    for i in (3, 4):
        c, u_, n_, hs = pads[i]
        flower_on(mb, c + u_ * hs.z * 0.92 + n_ * 0.03, u_ + n_ * 0.2, 0.12, 10 + i, petals=6, cup=0.5)
    return mb.finish("Body__" + name, coll, smooth_angle=35, weighted=False)


def grow(mb, p0, d0, length, r0, r1, depth, rng, maxdepth=3, kids=2, spread=0.65, bend_up=0.25, segs=6, wob=0.25, top_cap=True):
    n = max(3, int(length / 0.55) + 1)
    tgt = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.0))
    pts = turtle(p0, d0, length, n=n, bend=rng.uniform(0.2, 0.9), toward=tgt, wobble=wob, seed=rng.randint(0, 9999))
    sweep(mb, pts, taper_radii(len(pts), r0, r1, 0.9), segs=segs, mat='Bark', cap_a=(depth > 0), cap_b=top_cap)
    if depth < maxdepth:
        for k in range(kids):
            t = rng.uniform(0.40, 0.85) if k else rng.uniform(0.75, 0.98)
            idx = max(1, min(len(pts) - 2, int(t * (len(pts) - 1))))
            d = (pts[idx + 1] - pts[idx]).normalized()
            # child direction: rotate d around a random perpendicular axis, keep a bit upward
            ax = d.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.6)))).normalized()
            nd = (Quaternion(ax, spread * rng.uniform(0.7, 1.3)) @ d + Vector((0, 0, bend_up))).normalized()
            rc = lerp(r0, r1, idx / (len(pts) - 1)) * 0.78
            grow(mb, pts[idx], nd, length * rng.uniform(0.50, 0.72), rc, max(0.022, rc * 0.35), depth + 1, rng, maxdepth, kids, spread, bend_up, max(4, segs - 1), wob, top_cap)


def build_dead_tree():
    name = 'dead_tree'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(41)
    # twisted trunk with root flare and twisted ridges
    tp = turtle((0, 0, -0.12), (0.05, 0.0, 1.0), 2.5, n=8, bend=0.5, toward=(0.5, 0.3, 1.0), wobble=0.10, seed=4)
    sweep(mb, tp, trunk_radius(0.44, 0.24, flare=0.9, lobes=3, phase=0.3, seed=6, gnarl=0.10, decay=10.0, twist=2.2), segs=9, mat='Bark', cap_a=True, cap_b=True, twist=0.0)
    top = tp[-1]
    d_top = (tp[-1] - tp[-2]).normalized()
    # main limbs from the top, forks, twigs
    grow(mb, top, (d_top + Vector((-0.65, 0.2, 0.15))).normalized(), 2.1, 0.20, 0.07, 1, rng, maxdepth=3, kids=2, spread=0.6, segs=6)
    grow(mb, top, (d_top + Vector((0.55, -0.35, 0.10))).normalized(), 1.9, 0.19, 0.07, 1, rng, maxdepth=3, kids=2, spread=0.6, segs=6)
    grow(mb, top, (d_top + Vector((0.1, 0.55, 0.4))).normalized(), 1.1, 0.13, 0.05, 1, rng, maxdepth=2, kids=2, spread=0.5, segs=5)
    grow(mb, at_height(tp, 2.2), (-0.7, -0.45, 0.55), 1.7, 0.14, 0.05, 1, rng, maxdepth=2, kids=2, spread=0.6, segs=5)
    # lower side branches (broken stubs and one longer limb)
    for (z, az, ln, r0) in ((1.2, 70, 1.3, 0.12), (1.9, 250, 1.0, 0.10), (0.8, 170, 0.55, 0.09)):
        p = at_height(tp, z)
        d = Vector((math.cos(rad(az)), math.sin(rad(az)), 0.45)).normalized()
        grow(mb, p - d * 0.1, d, ln, r0, max(0.04, r0 * 0.4), 1, rng, maxdepth=1 if ln > 1 else 0, kids=1, spread=0.7, segs=5)
    return mb.finish("Body__" + name, coll, smooth_angle=45, weighted=False)


def build_desert_shrub():
    name = 'desert_shrub'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(23)
    bm = bmesh.new()
    for i in range(46):
        az = rng.uniform(0, TAU)
        el = rad(rng.uniform(8, 82))
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        L = rng.uniform(0.48, 0.88) * (0.75 + 0.35 * math.sin(el))
        base = Vector((math.cos(az) * 0.05, math.sin(az) * 0.05, 0.10 + rng.uniform(0, 0.08)))
        spine = turtle(base, d, L, n=3, bend=rng.uniform(0.2, 0.9), toward=(0, 0, -1))
        w = d.cross(Vector((0, 0, 1)))
        if w.length < 1e-3:
            w = Vector((1, 0, 0))
        strip_bm(spine, [0.055, 0.045, 0.028, 0.0], w.normalized(), bm=bm)
    add_bm(mb, bm, mat='Foliage_B', closed=False, smooth=True)
    add_bm(mb, blob_bm(0.22, 2, seed=8, amp=0.18, amp2=0.0, sq=(1.0, 1.0, 0.8)), loc=(0, 0, 0.22), mat='Foliage_B', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=60, weighted=False)


def build_mesa_rock():
    name = 'mesa_rock'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(6)
    layers = [(1.0, 4.5, 3.3, 1), (1.05, 2.95, 2.8, 0), (1.0, 2.35, 2.3, 1), (1.35, 2.85, 2.65, 0), (0.8, 2.1, 2.05, 1), (1.25, 2.55, 2.4, 0),
              (0.9, 1.85, 1.8, 1), (1.15, 2.1, 2.0, 0), (0.85, 2.55, 2.45, 1)]
    segs = 11
    z = -0.1
    rings = [[Vector((0, 0, z - 0.1))] * segs]
    layer_of_band = [0]
    ox = oy = 0.0
    for li, (h, rb, rt, mi_) in enumerate(layers):
        for (rr0, zz) in ((rb, z), (rt, z + h)):
            ring = []
            for k in range(segs):
                th = TAU * (k + 0.18 * math.sin(li * 2.1 + k * 1.7)) / segs
                nv = 1.0 + 0.20 * nz(Vector((math.cos(th) * 1.4, math.sin(th) * 1.4, li * 3.7)), 6.0, 1.0) + 0.05 * rng.uniform(-1, 1)
                ring.append(Vector((ox + rr0 * nv * math.cos(th), oy + rr0 * nv * math.sin(th), zz)))
            rings.append(ring)
        layer_of_band += [li, li]       # wall band of layer li, then ledge band (belongs to this layer's top)
        z += h
        ox += rng.uniform(-0.22, 0.22)
        oy += rng.uniform(-0.22, 0.22)
    rings.append([Vector((ox, oy, z))] * segs)      # flat top
    part = mb.grid(rings, closed=True, mat=RA, smooth=False, cap_a=False, cap_b=False)
    # band i is between ring i and i+1: ring 0 = bottom pole, then (bottom, top) per layer
    for bi, band in enumerate(part.bands):
        # bands: 0 = pole->first ring (underground fan), then wall0, ledge0, wall1, ledge1 ..., last = top cap
        if bi == 0:
            li = 0
        elif bi >= len(part.bands) - 1:
            li = len(layers) - 1
        else:
            li = (bi - 1) // 2
        m_ = layers[min(li, len(layers) - 1)][3]
        mb.paint([f for f in band if f is not None], RB if m_ else RA)
    # rubble at the foot
    for i, (ang, dist, sz) in enumerate([(0.4, 4.3, (1.5, 1.2, 1.0)), (2.3, 4.5, (1.1, 0.9, 0.8)), (3.9, 4.2, (1.7, 1.3, 1.1)), (5.3, 4.4, (1.0, 0.9, 0.7))]):
        b = hull_rock_bm(sz, seed=60 + i, rings=((0.0, 6, 1.0), (0.55, 7, 1.0), (1.0, 5, 0.55)), jitter=0.2, sink=0.1)
        patch_mats(b, 60 + i, thresh=0.0)
        cl.add(b, [RA, RB], loc=(math.cos(ang) * dist, math.sin(ang) * dist, 0), rot=(0, 0, ang * 2), smooth=False, cull=False)
    return mb.finish("Body__" + name, coll, smooth_angle=30, weighted=False)


def build_rock_arch():
    name = 'rock_arch'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(77)
    half = 4.1
    ctrl = [(-half - 0.3, 0.0, -0.4), (-half, 0.0, 1.6), (-half + 0.05, 0.0, 4.0), (-half + 0.8, 0.0, 6.3), (-half + 2.3, 0.0, 8.0), (0.0, 0.0, 8.7),
            (half - 2.3, 0.0, 8.0), (half - 0.8, 0.0, 6.3), (half - 0.05, 0.0, 4.0), (half, 0.0, 1.6), (half + 0.3, 0.0, -0.4)]
    pts = catmull(ctrl, n=3)
    n = len(pts)

    def prof(u, th):
        w = abs(u - 0.5) * 2.0                              # 1 at the feet, 0 at the crown
        base = lerp(1.05, 1.95, smoothstep(0.30, 1.0, w))   # thick pillars, slimmer crown
        bumps = 1.0 + 0.30 * fbm(Vector((math.cos(th) * 1.1, math.sin(th) * 1.1, u * 5.0)), 3.0, 1.0, 2)
        ledges = 1.0 + 0.07 * math.cos(u * 36.0)
        return base * bumps * ledges * (1.0 + 0.14 * math.cos(2 * th - 1.0))
    part = sweep(mb, pts, prof, segs=8, mat=RA, cap_a=True, cap_b=True, squash=0.9, smooth=False)
    for bi, band in enumerate(part.bands):
        if (bi // 3) % 2 == 1:
            mb.paint([f for f in band if f is not None], RB)
    # talus boulders at both feet
    for i, (x, y, sz) in enumerate([(-half - 1.4, 0.8, (1.7, 1.4, 1.1)), (-half + 1.5, -1.1, (1.2, 1.0, 0.8)), (half + 1.6, -0.6, (1.9, 1.5, 1.2)), (half - 1.4, 1.2, (1.1, 0.9, 0.7))]):
        b = hull_rock_bm(sz, seed=90 + i, rings=((0.0, 6, 1.0), (0.55, 7, 1.0), (1.0, 5, 0.55)), jitter=0.2, sink=0.12)
        patch_mats(b, 90 + i, thresh=0.0)
        cl.add(b, [RA, RB], loc=(x, y, 0), rot=(0, 0, i * 1.7), smooth=False, cull=False)
    return mb.finish("Body__" + name, coll, smooth_angle=35, weighted=False)


BUILDERS = [('cactus_a', build_cactus_a), ('cactus_b', build_cactus_b), ('dead_tree', build_dead_tree), ('desert_shrub', build_desert_shrub),
            ('mesa_rock', build_mesa_rock), ('rock_arch', build_rock_arch)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
