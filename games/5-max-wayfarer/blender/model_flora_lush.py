"""Lush world flora (brief 2, section A): tree_lush_a/b/c, bush_lush, fern, flower_cluster, grass_tuft.
Each builder (re)creates its own collection and one mesh object 'Body' (parked as Body__<name>).  Re-runnable; build a subset with
    ONLY = ['tree_lush_a']   (set before exec-ing this file).
Origin = ground contact at the bottom centre, +Z up, a few cm of roots below z=0."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')


def leaf_blob(cl, c, r, seed, sq=(1, 1, 1), subdiv=3, amp=0.28, amp2=0.09, freq=1.5, freq2=3.4, mat='Foliage_A', smooth=True, cull=True):
    """lumpy leaf mass added through a Cluster (buried faces are culled)"""
    bm = blob_bm(r, subdiv, seed=seed, amp=amp, amp2=amp2, freq=freq, freq2=freq2, sq=sq)
    return cl.add(bm, mat, loc=c, smooth=smooth, cull=cull)


def trunk_radius(r_base, r_top, flare=1.0, lobes=4, phase=0.0, power=0.85, decay=11.0, seed=0, gnarl=0.07):
    def f(u, th):
        rt = lerp(r_base, r_top, u ** power)
        lobe = max(0.0, math.cos(lobes * (th - phase))) ** 1.5
        fl = 1.0 + flare * math.exp(-u * decay) * (0.25 + 0.75 * lobe)
        g = 1.0 + gnarl * nz(Vector((math.cos(th) * 0.9, math.sin(th) * 0.9, u * 4.0)), seed, 1.0)
        return rt * fl * g
    return f


def at_height(tp, z):
    """point on the polyline tp at height z"""
    for i in range(len(tp) - 1):
        if tp[i].z <= z <= tp[i + 1].z:
            t = (z - tp[i].z) / max(1e-6, tp[i + 1].z - tp[i].z)
            return tp[i].lerp(tp[i + 1], t)
    return tp[-1] if z > tp[-1].z else tp[0]


def build_tree_lush_a():
    name = 'tree_lush_a'
    coll = fresh_collection(name)
    mb = MB(name)
    # trunk: gnarly, S-curved, tapering, flared roots (a few cm below the ground)
    tp = catmull([(0, 0, -0.12), (0.02, -0.02, 0.5), (0.12, -0.08, 1.0), (-0.15, 0.10, 2.0), (0.10, 0.20, 3.1), (0.32, 0.08, 4.0), (0.45, -0.02, 4.7)], n=3)
    sweep(mb, tp, trunk_radius(0.40, 0.21, flare=1.0, lobes=4, phase=0.5, seed=2, gnarl=0.09), segs=10, mat='Bark', cap_a=True, cap_b=True)
    # four big branches (height on trunk 0..1, azimuth, elevation, length, start radius, bend up)
    specs = [
        (0.58, 15, 34, 3.3, 0.20, 0.9),
        (0.68, 125, 40, 3.1, 0.19, 0.8),
        (0.52, 240, 30, 3.4, 0.21, 1.0),
        (0.84, 330, 48, 2.7, 0.16, 0.8),
    ]
    ends = []
    for (u, az, el, ln, r0, bend) in specs:
        k = u * (len(tp) - 1)
        i0 = int(k)
        p0 = tp[i0].lerp(tp[min(i0 + 1, len(tp) - 1)], k - i0)
        d = Vector((math.cos(rad(az)) * math.cos(rad(el)), math.sin(rad(az)) * math.cos(rad(el)), math.sin(rad(el))))
        pts = turtle(p0 - d * 0.12, d, ln, n=4, bend=bend, toward=(0, 0, 1), wobble=0.14, seed=int(az))
        sweep(mb, pts, taper_radii(len(pts), r0, 0.07, 0.8), segs=6, mat='Bark', cap_a=True, cap_b=True)
        ends.append(pts[-1])
    # crown: 7 lumpy blobs (top + around the branch ends); A = lighter, B = darker inner/lower masses
    tc = tp[-1]
    cl = Cluster(mb)
    leaf_blob(cl, (tc.x + 0.1, tc.y, 7.0), 2.0, 3, sq=(1.0, 1.0, 0.9))
    blob_r = [1.85, 1.7, 1.95, 1.6]
    blob_m = ['Foliage_A', 'Foliage_B', 'Foliage_A', 'Foliage_B']
    for i, e in enumerate(ends):
        leaf_blob(cl, (e.x * 1.08, e.y * 1.08, e.z + 0.45), blob_r[i], 10 + i, sq=(1.0, 1.0, 0.8), mat=blob_m[i])
    leaf_blob(cl, (tc.x - 1.0, tc.y + 0.6, 5.5), 1.5, 30, sq=(1.0, 1.0, 0.85), mat='Foliage_B')
    leaf_blob(cl, (tc.x + 1.9, tc.y - 1.6, 6.9), 1.2, 41, sq=(1.0, 1.0, 0.85), mat='Foliage_A')
    return mb.finish("Body__" + name, coll, smooth_angle=40, weighted=False)


UMB = [(0.00, -0.02), (0.30, -0.03), (0.62, -0.10), (0.88, -0.24), (1.00, -0.34), (0.97, -0.20), (0.80, 0.02), (0.55, 0.20), (0.28, 0.30), (0.00, 0.33)]


def umbrella_rings(c, R, seed, segs=14, lobes=7, lobe_amp=0.10, noise_amp=0.07, prof=UMB, h=1.0):
    """umbrella / parasol canopy as rings of a closed lathe (scalloped drooping rim). R = rim radius, h scales the thickness."""
    rings = []
    for (rr, zz) in prof:
        ring = []
        for k in range(segs):
            th = TAU * k / segs
            lob = 1.0 + lobe_amp * math.cos(lobes * th + seed) * smoothstep(0.45, 1.0, rr)
            nv = 1.0 + noise_amp * nz(Vector((math.cos(th) * 1.2, math.sin(th) * 1.2, zz * 2.0)), seed, 1.0)
            r_ = rr * R * lob * nv
            ring.append(Vector(c) + Vector((r_ * math.cos(th), r_ * math.sin(th), zz * R * h)))
        rings.append(ring)
    return rings


def build_tree_lush_b():
    name = 'tree_lush_b'
    coll = fresh_collection(name)
    mb = MB(name)
    # tall slender, slightly leaning trunk
    tp = catmull([(0, 0, -0.12), (0.03, 0.0, 0.8), (0.10, 0.04, 2.6), (0.32, 0.10, 5.8), (0.66, 0.14, 9.2), (1.00, 0.12, 12.2), (1.22, 0.08, 13.35)], n=3)
    sweep(mb, tp, trunk_radius(0.30, 0.08, flare=0.7, lobes=3, phase=1.0, seed=5, gnarl=0.05, decay=14.0), segs=8, mat='Bark', cap_a=True, cap_b=True)
    cl = Cluster(mb)
    tiers = [(7.0, 3.4, 'Foliage_A', 0.4), (10.1, 2.65, 'Foliage_B', 1.9), (13.0, 1.85, 'Foliage_A', 3.3)]
    for ti, (z, R, m_, sd) in enumerate(tiers):
        tc = at_height(tp, z)
        c = (tc.x, tc.y, z)
        cl.add(rings_bm(umbrella_rings(c, R, sd, segs=14, lobes=7)), m_, cull=False)
        # struts from the trunk up to the underside of the umbrella
        for a in range(3):
            az = rad(70 + a * 120 + sd * 20)
            d = Vector((math.cos(az), math.sin(az), 0))
            p0 = at_height(tp, z - 1.1)
            pts = catmull([p0, p0 + d * R * 0.30 + Vector((0, 0, 0.45)), Vector(c) + d * R * 0.62 + Vector((0, 0, -0.055 * R))], n=2)
            sweep(mb, pts, taper_radii(len(pts), 0.10, 0.05), segs=4, mat='Bark', cap_a=True, cap_b=True)
        # leafy lumps on top of the tier
        for li in range(3):
            az = rad(40 + li * 120 + sd * 33)
            rr = R * (0.30 + 0.13 * li)
            zs = z + 0.28 * R
            leaf_blob(cl, (c[0] + rr * math.cos(az), c[1] + rr * math.sin(az), zs - 0.10 * R), R * 0.20, 70 + ti * 5 + li, subdiv=2, amp=0.25, amp2=0.0, freq=1.6,
                      sq=(1.15, 1.15, 0.7), mat=m_)
    tt = at_height(tp, 13.55)
    leaf_blob(cl, (tt.x, tt.y, 13.62), 0.62, 99, subdiv=2, amp=0.2, amp2=0.0, sq=(1, 1, 1.1), mat='Foliage_A')
    return mb.finish("Body__" + name, coll, smooth_angle=40, weighted=False)


PARA = [(0.00, -0.04), (0.25, -0.05), (0.55, -0.09), (0.82, -0.19), (0.97, -0.32), (1.00, -0.38), (0.96, -0.35), (0.82, -0.12), (0.55, 0.04), (0.28, 0.12), (0.00, 0.15)]


def build_tree_lush_c():
    name = 'tree_lush_c'
    coll = fresh_collection(name)
    mb = MB(name)
    ZC = 6.4                      # canopy centre height
    R = 5.2
    # thick short alien trunk with a bulging base, curved
    tp = catmull([(0, 0, -0.12), (0.02, 0.0, 0.8), (0.18, 0.05, 2.4), (0.26, 0.10, 4.2), (0.08, 0.06, 6.3)], n=3)
    sweep(mb, tp, trunk_radius(0.95, 0.58, flare=0.9, lobes=5, phase=0.3, seed=7, gnarl=0.08, decay=9.0, power=0.9), segs=12, mat='Bark', cap_a=True, cap_b=True)
    top = tp[-1]
    c = (top.x, top.y, ZC)
    # big flat parasol canopy: drooping scalloped rim
    umb = umbrella_rings(c, R, 4.0, segs=16, lobes=8, lobe_amp=0.09, noise_amp=0.06, prof=PARA)
    mb.grid(umb, closed=True, mat='Foliage_A', smooth=True, cap_a=False, cap_b=False)
    # radial ribs under the canopy
    for a in range(6):
        az = rad(a * 60 + 10)
        d = Vector((math.cos(az), math.sin(az), 0))
        pts = [Vector((top.x, top.y, ZC - 0.5)) + d * 0.2]
        for f in (0.30, 0.58, 0.85):
            pts.append(Vector((top.x, top.y, ZC + R * prof_z(PARA, f, 'under') - 0.08)) + d * R * f)
        pts = catmull(pts, n=2)
        sweep(mb, pts, taper_radii(len(pts), 0.17, 0.07), segs=4, mat='Bark', cap_a=True, cap_b=True)
    # hanging vines + pods under the rim
    rng = random.Random(8)
    for i in range(11):
        az = TAU * i / 11 + rng.uniform(-0.15, 0.15)
        f = rng.uniform(0.76, 0.98)
        d = Vector((math.cos(az), math.sin(az), 0))
        p0 = Vector((top.x, top.y, ZC + R * prof_z(PARA, f, 'under') + 0.05)) + d * R * f
        ln = rng.uniform(1.4, 3.2)
        pts = turtle(p0, (0, 0, -1), ln, n=4, bend=rng.uniform(0.2, 0.7), toward=d * -1 + Vector((0, 0, -0.2)), wobble=0.12, seed=i)
        sweep(mb, pts, taper_radii(len(pts), 0.07, 0.04), segs=4, mat='Foliage_B', cap_a=False, cap_b=True)
        if i % 2 == 0:
            e = pts[-1]
            add_bm(mb, blob_bm(0.26, 2, seed=i, amp=0.10, amp2=0.0, sq=(0.8, 0.8, 1.45)), loc=e + Vector((0, 0, -0.30)), mat='Foliage_Flower', smooth=True)
    # blossoms on top of the canopy
    for i in range(9):
        az = TAU * i / 9 + rng.uniform(-0.3, 0.3)
        f = rng.uniform(0.12, 0.74)
        zt = ZC + R * prof_z(PARA, f, 'top')
        dz = (prof_z(PARA, f + 0.03, 'top') - prof_z(PARA, f - 0.03, 'top')) / 0.06
        d = Vector((math.cos(az), math.sin(az), 0))
        cc = Vector((top.x, top.y, zt + 0.05)) + d * R * f
        nrm = (Vector((0, 0, 1)) - d * dz).normalized()
        bmf, core, pet = flower_bm(cc, nrm, radius=rng.uniform(0.55, 0.78), petals=8, seed=i, cup=0.28, core_r=0.34)
        cs = set(core)
        for f in bmf.faces:
            f.material_index = 0 if f in cs else 1
        add_bm(mb, bmf, mat=['Foliage_B', 'Foliage_Flower'], smooth=True, closed=False)
    return mb.finish("Body__" + name, coll, smooth_angle=40, weighted=False)


def build_bush_lush():
    name = 'bush_lush'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    # twigs (3) poking out between the leaf masses
    for a in (30, 150, 270):
        d = Vector((math.cos(rad(a)), math.sin(rad(a)), 0))
        pts = turtle(d * 0.05 + Vector((0, 0, -0.04)), d * 0.5 + Vector((0, 0, 1)), 0.55, n=2, bend=0.3, toward=(0, 0, 1), wobble=0.0, seed=a)
        sweep(mb, pts, [0.035, 0.028, 0.018], segs=4, mat='Bark', cap_a=False, cap_b=True)
    spec = [  # centre, radius, mat
        ((0.0, 0.0, 0.85), 0.58, 'Foliage_A'),
        ((0.55, 0.15, 0.50), 0.46, 'Foliage_B'),
        ((-0.50, 0.30, 0.52), 0.48, 'Foliage_A'),
        ((0.05, -0.55, 0.48), 0.46, 'Foliage_A'),
        ((-0.25, 0.65, 0.42), 0.38, 'Foliage_B'),
        ((0.50, -0.45, 0.42), 0.36, 'Foliage_B'),
        ((-0.15, -0.05, 1.12), 0.36, 'Foliage_A'),
    ]
    for i, (c, r, m_) in enumerate(spec):
        leaf_blob(cl, c, r, 50 + i, subdiv=2, amp=0.25, amp2=0.0, freq=1.6, sq=(1.0, 1.0, 0.88), mat=m_)
    return mb.finish("Body__" + name, coll, smooth_angle=45, weighted=False)


def frond_bm(base, direction, length, width, n=10, bend=1.2, droop_to=(0, 0, -1), bm=None, rib=0.022):
    """serrated fern frond: midrib strip + leaflet triangles on both sides; the spine curves over towards `droop_to`"""
    bm = bm or bmesh.new()
    pts = turtle(base, direction, length, n=n, bend=bend, toward=droop_to, wobble=0.0, bend_curve=1.25)
    d0 = Vector(direction).normalized()
    side = d0.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    sp = [Vector(p) for p in pts]
    strip_bm(sp, [rib * (1.0 - 0.6 * i / n) for i in range(n + 1)], side, tip=True, bm=bm)
    for i in range(n):
        a, b = sp[i], sp[i + 1]
        t_ = (b - a).normalized()
        u = (i + 0.5) / n
        w = max(0.02, width * (math.sin(math.pi * min(1.0, u * 1.08 + 0.06)) ** 0.7) * (1.0 - 0.25 * u))
        mid = (a + b) * 0.5
        for sgn in (-1, 1):
            tip = mid + side * sgn * w + t_ * (length / n) * 0.75 + Vector((0, 0, -w * 0.15))
            va, vb, vt = bm.verts.new(a), bm.verts.new(b), bm.verts.new(tip)
            try:
                f = bm.faces.new((va, vb, vt) if sgn > 0 else (vb, va, vt))
                f.smooth = True
            except ValueError:
                pass
    return bm


def build_fern():
    name = 'fern'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(9)
    bm = bmesh.new()
    n = 9
    for i in range(n):
        az = TAU * i / n + rng.uniform(-0.2, 0.2)
        el = rng.uniform(60, 80)
        d = Vector((math.cos(az) * math.cos(rad(el)), math.sin(az) * math.cos(rad(el)), math.sin(rad(el))))
        L = rng.uniform(1.25, 1.6)
        frond_bm(Vector((math.cos(az) * 0.04, math.sin(az) * 0.04, 0.06)), d, L, rng.uniform(0.20, 0.26), n=10, bend=rng.uniform(0.9, 1.3), bm=bm)
    add_bm(mb, bm, mat='Foliage_A', closed=False, smooth=True)
    add_bm(mb, blob_bm(0.12, 2, seed=3, amp=0.15, amp2=0.0, sq=(1, 1, 0.8)), loc=(0, 0, 0.04), mat='Foliage_B', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=60, weighted=False)


def build_flower_cluster():
    name = 'flower_cluster'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(14)
    heads = [(0.0, 0.0, 0.58), (0.20, 0.10, 0.46), (-0.18, 0.12, 0.50), (0.05, -0.22, 0.42), (-0.12, -0.12, 0.34)]
    for i, (hx, hy, hz) in enumerate(heads):
        base = Vector((hx * 0.18, hy * 0.18, -0.02))
        top = Vector((hx, hy, hz))
        mid = base.lerp(top, 0.55) + Vector((hx * 0.1 + rng.uniform(-0.03, 0.03), hy * 0.1 + rng.uniform(-0.03, 0.03), 0.0))
        pts = catmull([base, mid, top], n=2)
        sweep(mb, pts, taper_radii(len(pts), 0.022, 0.014), segs=4, mat='Foliage_B', cap_a=False, cap_b=True)
        nrm = Vector((hx * 0.6 + rng.uniform(-0.2, 0.2), hy * 0.6 + rng.uniform(-0.2, 0.2), 1.0)).normalized()
        bmf, core, pet = flower_bm(top + nrm * 0.02, nrm, radius=0.17 + 0.03 * rng.random(), petals=8, seed=i, cup=0.40)
        cs = set(core)
        for f in bmf.faces:
            f.material_index = 0 if f in cs else 1
        add_bm(mb, bmf, mat=['Foliage_B', 'Foliage_Flower'], smooth=True, closed=False)
    bml = bmesh.new()
    for i in range(4):
        az = TAU * i / 4 + 0.6
        d = Vector((math.cos(az), math.sin(az), 0))
        spine = turtle(d * 0.03, d * 0.7 + Vector((0, 0, 0.55)), 0.34, n=3, bend=1.0, toward=(0, 0, -1))
        w = Vector((-d.y, d.x, 0))
        strip_bm(spine, [0.05, 0.085, 0.06, 0.0], w, bm=bml)
    add_bm(mb, bml, mat='Foliage_A', closed=False, smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=60, weighted=False)


def build_grass_tuft():
    name = 'grass_tuft'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(3)
    bm = bmesh.new()
    n = 11
    for i in range(n):
        az = TAU * i / n + rng.uniform(-0.25, 0.25)
        rr = rng.uniform(0.0, 0.07)
        base = Vector((math.cos(az) * rr, math.sin(az) * rr, 0.0))
        h = rng.uniform(0.55, 0.85) if i > 2 else rng.uniform(0.82, 0.95)
        lean = Vector((math.cos(az + rng.uniform(-0.3, 0.3)), math.sin(az + rng.uniform(-0.3, 0.3)), 0))
        blade_bm(base, lean, h, rng.uniform(0.07, 0.10), bend=rng.uniform(0.5, 0.95), segs=3, bm=bm)
    add_bm(mb, bm, mat='Foliage_A', closed=False, smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=80, weighted=False)


BUILDERS = [('tree_lush_a', build_tree_lush_a), ('tree_lush_b', build_tree_lush_b), ('tree_lush_c', build_tree_lush_c),
            ('bush_lush', build_bush_lush), ('fern', build_fern), ('flower_cluster', build_flower_cluster), ('grass_tuft', build_grass_tuft)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
