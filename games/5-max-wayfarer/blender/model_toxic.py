"""Toxic swamp props (brief 2, section G): mushroom_giant, mushroom_small, spore_pod, tentacle_plant, toxic_crystal.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')


def surf_normal_top(prof, rr, th):
    """outward normal of the TOP surface of a lathe profile at radius rr, azimuth th (profile is top-pole -> rim -> underside)."""
    pr = list(reversed(prof))
    e = 0.08
    s = (prof_z(pr, rr + e, 'top') - prof_z(pr, max(0.0, rr - e), 'top')) / (rr + e - max(0.0, rr - e))
    return Vector((-s * math.cos(th), -s * math.sin(th), 1.0)).normalized()


def mini_mushroom(mb, base, h, r_cap, d, kind, seed, stem_r, cap_mat, stem_mat, under_mat, segs=9, spots=None, cl=None):
    """stem (swept tube) + lathe cap at its top.  d = growing direction.  kind: dome / flat / cone"""
    d = Vector(d).normalized()
    pts = turtle(Vector(base) + Vector((0, 0, -0.04)), d, h, n=3, bend=0.5, toward=(0, 0, 1), wobble=0.0, seed=seed)
    sweep(mb, pts, [stem_r * 1.55, stem_r * 1.05, stem_r * 0.92, stem_r * 0.9], segs=6, mat=stem_mat, cap_a=True, cap_b=False, smooth=True)
    tip = pts[-1]
    prof = {'dome': [(0, 0.50), (0.45, 0.45), (0.85, 0.24), (1.0, 0.0), (0.92, -0.07), (0.5, -0.04), (0.0, 0.0)],
            'flat': [(0, 0.24), (0.5, 0.21), (0.9, 0.07), (1.0, -0.02), (0.93, -0.08), (0.45, -0.05), (0.0, 0.0)],
            'cone': [(0, 0.95), (0.30, 0.78), (0.68, 0.38), (1.0, -0.04), (0.9, -0.13), (0.4, -0.06), (0.0, 0.0)]}[kind]
    prof = [(r * r_cap, z * r_cap) for (r, z) in prof]
    rings = lathe_rings(prof, c=(0, 0, 0), segs=segs, lobes=3 if kind != 'cone' else 0, lobe_amp=0.07, lobe_from=0.5, noise_amp=0.04, seed=seed)
    m = MB.xf(tip - d * 0.03, MB.aim(d))
    rings = [[m @ p for p in ring] for ring in rings]
    part = mb.grid(rings, closed=True, mat=cap_mat, smooth=True, cap_a=False, cap_b=False)
    for bi in range(3, len(part.bands)):
        mb.paint(part.bands[bi], under_mat)
    return tip, part


# ------------------------------------------------------------------------------------------------
def build_mushroom_giant():
    name = 'mushroom_giant'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(12)
    ZC = 8.7
    # stalk: thick, gently curved, flared base with buttress lobes, vertical ribs
    sp = catmull([(0, 0, -0.15), (0.05, 0.0, 1.3), (0.20, 0.10, 3.8), (-0.05, 0.18, 6.4), (0.0, 0.10, ZC + 0.55)], n=3)
    tr = trunk_radius(0.92, 0.74, flare=0.9, lobes=5, phase=0.3, power=0.9, decay=8.0, seed=3, gnarl=0.05)
    sweep(mb, sp, lambda u, th: tr(u, th) * (1.0 + 0.05 * math.cos(9 * th + u * 3.0)), segs=10, mat='Bark_Pale', cap_a=True, cap_b=True)
    top = at_height(sp, ZC)
    # pleated skirt (ring) hanging from the stalk below the cap
    zs = 7.0
    sc = at_height(sp, zs)
    skirt = [(0.76, zs + 0.22), (1.10, zs + 0.10), (1.60, zs - 0.30), (1.66, zs - 0.62), (1.45, zs - 0.58), (1.05, zs - 0.30), (0.76, zs - 0.12)]
    srings = lathe_rings(skirt, c=(sc.x, sc.y, 0), segs=20, lobes=0, noise_amp=0.05, seed=9, zig=(0.05, 0.9, 1.5, 2))
    mb.grid(srings, closed=True, mat='Bark_Pale', smooth=True, loop_rings=True)
    # cap (top: Foliage_B, underside gills: Glow_Main)
    prof = [(0.0, 3.0), (0.9, 2.95), (1.9, 2.66), (3.0, 2.05), (4.0, 1.25), (4.7, 0.52), (5.1, -0.05), (5.05, -0.50),
            (4.55, -0.64), (3.6, -0.52), (2.6, -0.30), (1.6, -0.05), (0.9, 0.12), (0.0, 0.25)]
    rings = lathe_rings(prof, c=(top.x, top.y, ZC), segs=26, lobes=7, lobe_amp=0.11, lobe_from=0.45, noise_amp=0.06, seed=2.0, ph=0.4, zig=(0.12, 0.9, 3.8, 8))
    part = mb.grid(rings, closed=True, mat='Foliage_B', smooth=True, cap_a=False, cap_b=False)
    for bi in range(7, len(part.bands)):
        mb.paint(part.bands[bi], 'Glow_Main')
    # pale spots on the cap
    spots = [(0.6, 0.2, 0.62), (1.7, 1.0, 0.50), (2.6, 2.3, 0.70), (3.4, 3.5, 0.48), (2.0, 4.4, 0.58), (3.0, 5.4, 0.64), (1.1, 3.2, 0.42), (3.9, 1.2, 0.44),
             (3.8, 4.4, 0.50), (0.9, 5.6, 0.40), (4.2, 2.6, 0.34), (2.4, 0.2, 0.42), (1.4, 2.0, 0.34), (4.3, 5.9, 0.34)]
    pr = list(reversed(prof))
    for i, (rr, th, sz) in enumerate(spots):
        zz = ZC + prof_z(pr, rr, 'top') - 0.02
        n = surf_normal_top(prof, rr, th)
        add_bm(mb, blob_bm(sz, 1, seed=40 + i, amp=0.12, amp2=0.0, sq=(1.0, 1.0, 0.38)), loc=(top.x + rr * math.cos(th), top.y + rr * math.sin(th), zz),
               rot=MB.aim(n), mat='Bark_Pale', smooth=True)
    # baby mushrooms at the foot
    for i, (x, y, h, rc, kind) in enumerate([(1.35, 0.55, 0.85, 0.50, 'dome'), (-1.2, 0.95, 0.60, 0.38, 'flat'), (0.35, -1.45, 1.1, 0.46, 'dome'), (-0.7, -1.1, 0.4, 0.28, 'flat')]):
        mini_mushroom(mb, (x, y, 0.0), h, rc, (x * 0.12, y * 0.12, 1.0), kind, 50 + i, 0.10, 'Foliage_B', 'Bark_Pale', 'Glow_Main', segs=9)
    return mb.finish("Body__" + name, coll, smooth_angle=38, weighted=False)


# ------------------------------------------------------------------------------------------------
def build_mushroom_small():
    name = 'mushroom_small'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    # (x, y, stem height, cap radius, azimuth, tilt, kind)
    spec = [(0.0, 0.0, 0.95, 0.43, 0.5, 0.10, 'dome'), (0.40, 0.22, 0.62, 0.31, 0.6, 0.30, 'flat'), (-0.38, 0.14, 0.78, 0.27, 2.9, 0.22, 'cone'),
            (0.12, -0.40, 0.42, 0.22, 4.9, 0.32, 'dome'), (-0.17, -0.32, 0.26, 0.16, 3.9, 0.35, 'flat')]
    for i, (x, y, h, rc, az, tilt, kind) in enumerate(spec):
        d = lean_rot(az, tilt) @ Vector((0, 0, 1))
        mini_mushroom(mb, (x, y, 0.0), h, rc, d, kind, 20 + i, 0.065 + 0.012 * (i == 0), 'Glow_Main', 'Bark_Pale', 'Bark_Pale', segs=9)
    # mossy lumps around the foot
    for i, (x, y, r, z) in enumerate([(0.22, -0.05, 0.20, 0.03), (-0.24, -0.1, 0.17, 0.02), (0.05, 0.3, 0.18, 0.02), (0.33, -0.28, 0.12, 0.02)]):
        cl.add(blob_bm(r, 1, seed=70 + i, amp=0.15, amp2=0.0, sq=(1.3, 1.3, 0.45)), 'Foliage_B', loc=(x, y, z), smooth=True, cull=False)
    return mb.finish("Body__" + name, coll, smooth_angle=45, weighted=False)


# ------------------------------------------------------------------------------------------------
def pod_bm_parts(mb, base, d, size, seed, glow_from=0.80):
    """bulb pod growing along d from `base`: ribbed body (Foliage_A) whose upper tip is Glow_Main, + 5 sepals; size = pod length"""
    prof = [(0.0, 0.0), (0.26, 0.03), (0.50, 0.22), (0.58, 0.48), (0.50, 0.76), (0.34, 0.98), (0.21, 1.14), (0.13, 1.25), (0.0, 1.30)]
    prof = [(r * size * 0.78, z * size * 0.82) for (r, z) in prof]
    rings = lathe_rings(prof, c=(0, 0, 0), segs=10, lobes=5, lobe_amp=0.13, lobe_from=0.0, noise_amp=0.03, seed=seed, ph=seed)
    m = MB.xf(base, MB.aim(d))
    rings = [[m @ p for p in ring] for ring in rings]
    part = mb.grid(rings, closed=True, mat='Foliage_A', smooth=True, cap_a=False, cap_b=False)
    for bi in range(5, len(part.bands)):
        mb.paint(part.bands[bi], 'Glow_Main')
    d = Vector(d).normalized()
    # sepals: leaf strips bending outwards from the shoulder of the pod
    bml = bmesh.new()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    ux = d.cross(ref).normalized()
    uy = d.cross(ux).normalized()
    for k in range(5):
        a = TAU * k / 5 + seed
        out = ux * math.cos(a) + uy * math.sin(a)
        p0 = Vector(base) + d * size * 0.56 + out * size * 0.40
        dd = (d * 0.55 + out * 0.85).normalized()
        spine = turtle(p0, dd, size * 0.62, n=3, bend=1.0, toward=-out * 0.3 + d * 0.9, wobble=0.0, seed=k)
        strip_bm(spine, [size * 0.17, size * 0.22, size * 0.14, 0.0], d.cross(out), bm=bml)
    add_bm(mb, bml, mat='Foliage_B', closed=False, smooth=True)


def build_spore_pod():
    name = 'spore_pod'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(31)
    # curved main stem arching out to the right
    sp = catmull([(0, 0, -0.06), (0.04, 0.0, 0.38), (0.18, 0.02, 0.72), (0.44, 0.0, 0.93), (0.64, 0.0, 1.03)], n=3)
    sweep(mb, sp, taper_radii(len(sp), 0.12, 0.075, 0.8), segs=7, mat='Foliage_B', cap_a=True, cap_b=False)
    d_end = (sp[-1] - sp[-3]).normalized()
    d_pod = (d_end + Vector((0.25, 0.0, 1.1))).normalized()
    pod_bm_parts(mb, sp[-1] - d_end * 0.04, d_pod, 0.86, 3.0)
    # glowing spore motes floating above the pod, on hair-thin filaments
    top = sp[-1] + d_pod * 0.86
    for i, (dx, dy, dz, r) in enumerate([(0.0, 0.0, 0.18, 0.13), (0.24, 0.12, 0.36, 0.085), (-0.2, 0.18, 0.42, 0.07), (0.1, -0.24, 0.56, 0.055), (-0.06, -0.1, 0.72, 0.04)]):
        add_bm(mb, blob_bm(r, 1, seed=i, amp=0.0, amp2=0.0), loc=top + Vector((dx, dy, dz)), mat='Glow_Main', smooth=True)
    # small second pod on a short stem
    sp2 = catmull([(-0.22, 0.30, -0.05), (-0.30, 0.38, 0.30), (-0.42, 0.50, 0.55)], n=2)
    sweep(mb, sp2, taper_radii(len(sp2), 0.07, 0.05), segs=6, mat='Foliage_B', cap_a=True, cap_b=False)
    pod_bm_parts(mb, sp2[-1], (-0.30, 0.35, 1.0), 0.50, 7.0)
    # ground leaves
    bml = bmesh.new()
    for i in range(6):
        az = TAU * i / 6 + 0.4
        o = Vector((math.cos(az), math.sin(az), 0))
        ln = rng.uniform(0.55, 0.95)
        spine = turtle(o * 0.10 + Vector((0, 0, 0.04)), o * 0.8 + Vector((0, 0, 0.6)), ln, n=3, bend=1.15, toward=(0, 0, -1), seed=i)
        strip_bm(spine, [0.10, 0.27, 0.20, 0.0], Vector((-o.y, o.x, 0)), bm=bml)
    add_bm(mb, bml, mat='Foliage_A', closed=False, smooth=True)
    cl.add(blob_bm(0.2, 1, seed=3, amp=0.12, amp2=0.0, sq=(1.3, 1.3, 0.55)), 'Foliage_B', loc=(0, 0, 0.03), smooth=True, cull=False)
    return mb.finish("Body__" + name, coll, smooth_angle=48, weighted=False)


# ------------------------------------------------------------------------------------------------
def build_tentacle_plant():
    name = 'tentacle_plant'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(8)
    # fleshy lumpy base
    cl.add(blob_bm(0.62, 2, seed=5, amp=0.20, amp2=0.05, sq=(1.0, 1.0, 0.62)), 'Foliage_B', loc=(0, 0, 0.14), smooth=True, cull=False)
    for i, (az, rr, r) in enumerate([(0.5, 0.62, 0.22), (2.2, 0.66, 0.2), (3.7, 0.6, 0.23), (5.2, 0.64, 0.18)]):
        cl.add(blob_bm(r, 1, seed=11 + i, amp=0.15, amp2=0.0, sq=(1.2, 1.2, 0.7)), 'Foliage_B', loc=(math.cos(az) * rr, math.sin(az) * rr, 0.06), smooth=True, cull=False)
    # (azimuth deg, length, radius at base, total bend, bend curve, start lean)
    spec = [(10, 3.0, 0.27, 2.4, 1.8, 0.55), (75, 2.2, 0.23, 1.5, 1.4, 0.75), (140, 2.7, 0.25, 2.9, 2.2, 0.45), (205, 1.7, 0.2, 1.0, 1.0, 0.95),
            (265, 2.4, 0.23, 2.1, 1.6, 0.6), (320, 1.4, 0.18, 2.6, 1.2, 0.8)]
    for i, (az, ln, r0, bend, bc, lean) in enumerate(spec):
        a = rad(az)
        out = Vector((math.cos(a), math.sin(a), 0))
        p0 = out * 0.26 + Vector((0, 0, 0.18))
        d0 = (out * lean + Vector((0, 0, 1.0))).normalized()
        n = 9
        pts = turtle(p0, d0, ln, n=n, bend=bend, toward=out * -0.35 + Vector((0, 0, -0.25)) if i % 2 == 0 else out * 0.55 + Vector((0, 0, -0.7)), wobble=0.07, seed=i * 5 + 3, bend_curve=bc)
        radii = [lerp(r0, 0.05, (j / n) ** 0.85) * (1.0 + 0.13 * math.cos(j * 2.1 + i)) for j in range(n + 1)]
        sweep(mb, pts, radii, segs=6, mat='Foliage_B', cap_a=True, cap_b=False)
        tp = pts[-1]
        dt = (pts[-1] - pts[-2]).normalized()
        add_bm(mb, blob_bm(0.115 - 0.01 * (i % 3), 1, seed=60 + i, amp=0.0, amp2=0.0, sq=(0.85, 0.85, 1.4)), loc=tp + dt * 0.04, rot=MB.aim(dt), mat='Glow_Main', smooth=True)
        # sucker nubs along the inner side
        for t in (0.42, 0.62, 0.80):
            j = int(t * n)
            nub = pts[j] + (Vector((0, 0, 0.0)) - out * 0.0) + ((pts[min(j + 1, n)] - pts[j]).cross(Vector((0, 0, 1))).normalized()) * (radii[j] * 0.95)
            add_bm(mb, blob_bm(radii[j] * 0.36, 1, seed=80 + j, amp=0.0, amp2=0.0), loc=nub, mat='Glow_Main', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=48, weighted=False)


# ------------------------------------------------------------------------------------------------
def crystal_glow(mb, cl, h, r, az, tilt, pos, seed, sides=6, tip=0.3, taper=0.82, skew=(0.0, 0.0), cut=None, stretch=1.0, shell='Crystal_Main', core='Glow_Main', core_k=(0.46, 0.80)):
    """translucent crystal shell (flat shaded) with a smaller glowing crystal inside (visible through the shell)"""
    R = lean_rot(az, tilt)
    bm = crystal_bm(h, r, sides=sides, tip=tip, seed=seed, taper=taper, skew=skew, jit=0.07, cut=cut, stretch=stretch)
    add_bm(mb, bm, loc=pos, rot=R, mat=shell, smooth=False)
    up = R @ Vector((0, 0, 1))
    cb = crystal_bm(h * core_k[1], r * core_k[0], sides=sides, tip=0.35, seed=seed + 100, taper=0.78, skew=(skew[0] * 0.4, skew[1] * 0.4), jit=0.05, stretch=stretch)
    add_bm(mb, cb, loc=Vector(pos) + up * h * 0.10, rot=R, mat=core, smooth=False)


def build_toxic_crystal():
    name = 'toxic_crystal'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    # rubble / slime base
    for i, (loc, sz, sd) in enumerate([((0.0, 0.0, 0.0), (1.35, 1.2, 0.40), 91), ((0.62, -0.5, 0.0), (0.6, 0.5, 0.30), 92), ((-0.55, 0.52, 0.0), (0.5, 0.45, 0.26), 93)]):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.6, 7, 0.95), (1.0, 5, 0.6)), jitter=0.2, sink=0.06)
        cl.add(b, 'Rock_B', loc=loc, rot=(0, 0, sd), smooth=False)
    add_bm(mb, blob_bm(0.55, 1, seed=3, amp=0.18, amp2=0.0, sq=(1.9, 1.5, 0.07)), loc=(0.0, 0.0, 0.0), mat='Glow_Main', smooth=True)
    # (height, radius, azimuth, tilt, offset radius, offset azimuth, sides, cut)
    spec = [(2.05, 0.30, 0.8, 0.10, 0.0, 0.0, 6, None), (1.45, 0.24, 2.4, 0.42, 0.34, 2.4, 6, (0.35, 0.1, -0.05)), (1.25, 0.22, 4.0, 0.50, 0.36, 4.1, 5, None),
            (0.95, 0.18, 5.4, 0.62, 0.40, 5.3, 6, (-0.3, 0.2, -0.04)), (0.75, 0.15, 1.5, 0.75, 0.42, 1.4, 5, None), (0.55, 0.12, 3.2, 0.95, 0.44, 3.2, 6, None),
            (0.5, 0.11, 0.1, 0.85, 0.46, 5.9, 5, None)]
    for i, (h, r, az, tilt, off, oaz, sides, cut) in enumerate(spec):
        pos = Vector((math.cos(oaz) * off, math.sin(oaz) * off, 0.04))
        crystal_glow(mb, cl, h, r, az, tilt, pos, 10 + i, sides=sides, tip=0.28 if cut is None else 0.14, skew=(0.45 * math.cos(az + 1.2), 0.45 * math.sin(az + 1.2)), cut=cut,
                     core_k=(0.45, 0.78))
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


BUILDERS = [('mushroom_giant', build_mushroom_giant), ('mushroom_small', build_mushroom_small), ('spore_pod', build_spore_pod),
            ('tentacle_plant', build_tentacle_plant), ('toxic_crystal', build_toxic_crystal)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
