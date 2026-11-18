"""Frozen ("Glacial") props (brief 2, section E): tree_pine_snow, tree_pine_snow_b, ice_spire, ice_boulder, frost_shrub, snow_rock.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
SEL = globals().get('ONLY')


def tier_rings(c, R, H, segs=14, lobes=7, lobe_amp=0.16, seed=0, ph=0.0, droop=0.6, top_h=0.10):
    """drooping conifer skirt: pointed centre, scalloped rim whose lobes hang lower, thin edge; closed lathe (top surface + underside)"""
    top = [(0.0, top_h), (0.22, 0.0), (0.52, -0.34), (0.82, -0.70), (1.0, -0.90)]
    under = [(0.97, -1.04), (0.74, -0.80), (0.42, -0.52), (0.0, -0.45)]
    rings = []
    for (rf, zf) in top + under:
        ring = []
        for k in range(segs):
            th = TAU * k / segs + ph
            lob = math.cos(lobes * th)
            edge = smoothstep(0.45, 1.0, rf)
            rr = R * rf * (1.0 + lobe_amp * lob * edge) * (1.0 + 0.05 * nz(Vector((math.cos(th), math.sin(th), zf)), seed, 1.2))
            zz = H * zf - droop * H * 0.35 * max(0.0, lob) * edge
            ring.append(Vector(c) + Vector((rr * math.cos(th), rr * math.sin(th), zz)))
        rings.append(ring)
    return rings


def snowy_tier(mb, c, R, H, seed, mat, segs=14, lobes=7, lobe_amp=0.16, droop=0.6, snow_k=1.0, min_nz=0.42, ph=0.0, rcut=0.80):
    bm = rings_bm(tier_rings(c, R, H, segs=segs, lobes=lobes, lobe_amp=lobe_amp, seed=seed, ph=ph, droop=droop))
    snow = snow_cap_bm(bm, min_nz=min_nz, thick=(0.06 * R + 0.05) * snow_k, seed=seed, lumpy=0.45, grow=2.4)
    add_bm(mb, bm, mat=mat, smooth=True, closed=True)
    if snow is not None:
        cc = Vector(c)
        far = [f for f in snow.faces if (Vector((f.calc_center_median().x - cc.x, f.calc_center_median().y - cc.y, 0)).length > R * rcut * (1.0 + 0.16 * nz(f.calc_center_median(), seed, 1.4)))]
        if far:
            bmesh.ops.delete(snow, geom=far, context='FACES')
        add_bm(mb, snow, mat='Snow', smooth=True, closed=False)


def build_tree_pine_snow():
    name = 'tree_pine_snow'
    coll = fresh_collection(name)
    mb = MB(name)
    tp = catmull([(0, 0, -0.14), (0.02, 0.0, 2.0), (0.06, 0.04, 5.0), (0.04, 0.06, 8.0), (0.05, 0.05, 9.3)], n=3)
    sweep(mb, tp, trunk_radius(0.50, 0.12, flare=0.8, lobes=4, phase=0.4, seed=4, gnarl=0.05, decay=12.0), segs=7, mat='Bark', cap_a=True, cap_b=True)
    tiers = [(2.9, 3.1, 2.3, 'Foliage_A', 8), (4.5, 2.6, 2.1, 'Foliage_B', 7), (6.05, 2.1, 1.9, 'Foliage_A', 8), (7.5, 1.6, 1.7, 'Foliage_B', 7),
             (8.8, 1.1, 1.4, 'Foliage_A', 6)]
    for i, (z, R, H, m_, lobes) in enumerate(tiers):
        c = at_height(tp, z)
        snowy_tier(mb, (c.x, c.y, z), R, H, 3 + i, m_, segs=14, lobes=lobes, lobe_amp=0.17, droop=0.7, ph=i * 0.9, snow_k=0.8, min_nz=0.55, rcut=0.74)
    # leader spike with a snow tip
    c = at_height(tp, 9.3)
    spike = rings_bm(lathe_rings([(0.0, 1.45), (0.14, 1.05), (0.30, 0.55), (0.42, 0.10), (0.30, -0.05), (0.0, -0.05)], c=(c.x, c.y, 8.9), segs=8, noise_amp=0.05, seed=2))
    snow = snow_cap_bm(spike, min_nz=0.45, thick=0.09, seed=1, lumpy=0.3, grow=1.8)
    add_bm(mb, spike, mat='Foliage_A', smooth=True)
    if snow is not None:
        add_bm(mb, snow, mat='Snow', smooth=True, closed=False)
    return mb.finish("Body__" + name, coll, smooth_angle=50, weighted=False)


def build_tree_pine_snow_b():
    name = 'tree_pine_snow_b'
    coll = fresh_collection(name)
    mb = MB(name)
    tp = catmull([(0, 0, -0.12), (0.10, 0.04, 1.6), (0.24, 0.08, 3.4), (0.36, 0.10, 5.3)], n=3)
    sweep(mb, tp, trunk_radius(0.42, 0.12, flare=0.9, lobes=3, phase=0.9, seed=9, gnarl=0.06, decay=11.0), segs=7, mat='Bark', cap_a=True, cap_b=True)
    # squat fir: 4 star-shaped tiers wrapped in heavy snow
    tiers = [(1.95, 2.05, 1.7, 'Foliage_B', 6), (3.05, 1.75, 1.55, 'Foliage_A', 6), (4.1, 1.4, 1.4, 'Foliage_B', 5), (5.0, 0.98, 1.2, 'Foliage_A', 5)]
    for i, (z, R, H, m_, lobes) in enumerate(tiers):
        c = at_height(tp, z)
        snowy_tier(mb, (c.x + 0.04 * (i % 2), c.y, z), R, H, 21 + i, m_, segs=12, lobes=lobes, lobe_amp=0.26, droop=1.0, snow_k=1.5, min_nz=0.45, ph=0.6 + i * 1.3, rcut=0.84)
    c = at_height(tp, 5.3)
    spike = rings_bm(lathe_rings([(0.0, 0.95), (0.16, 0.65), (0.34, 0.22), (0.4, 0.0), (0.0, -0.04)], c=(c.x, c.y, 5.1), segs=7, noise_amp=0.06, seed=5))
    snow = snow_cap_bm(spike, min_nz=0.40, thick=0.13, seed=2, lumpy=0.3, grow=1.8)
    add_bm(mb, spike, mat='Foliage_B', smooth=True)
    if snow is not None:
        add_bm(mb, snow, mat='Snow', smooth=True, closed=False)
    # snow drift at the foot
    add_bm(mb, blob_bm(0.9, 2, seed=4, amp=0.2, amp2=0.0, sq=(1.0, 1.0, 0.22)), loc=(0.0, 0.0, 0.10), mat='Snow', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=50, weighted=False)


def build_ice_spire():
    name = 'ice_spire'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    # (height, radius, azimuth, tilt, offset radius, offset az, sides, tip)
    spec = [(5.1, 0.42, 0.7, 0.07, 0.0, 0.0, 5, 0.36), (3.8, 0.34, 2.3, 0.30, 0.50, 2.3, 6, 0.32), (3.2, 0.31, 4.3, 0.36, 0.55, 4.3, 5, 0.34),
            (2.3, 0.26, 5.6, 0.50, 0.62, 5.6, 6, 0.30), (2.0, 0.24, 1.2, 0.58, 0.62, 1.1, 5, 0.30), (1.3, 0.2, 3.4, 0.80, 0.70, 3.3, 6, 0.30),
            (1.0, 0.16, 0.2, 0.95, 0.74, 6.0, 5, 0.30), (0.8, 0.14, 4.9, 1.0, 0.78, 4.8, 6, 0.3)]
    for i, (h, r, az, tilt, off, oaz, sides, tip) in enumerate(spec):
        pos = Vector((math.cos(oaz) * off, math.sin(oaz) * off, -0.05))
        bm = crystal_bm(h, r, sides=sides, tip=tip, seed=40 + i, taper=0.86, skew=(0.20 * math.cos(az + 1.0), 0.20 * math.sin(az + 1.0)), jit=0.09)
        add_bm(mb, bm, loc=pos, rot=lean_rot(az, tilt), mat='Crystal_Main', smooth=False)
    # frozen base: snow drift lumps + a few frosted stones
    for i, (x, y, r, z, sq) in enumerate([(0.0, 0.0, 0.95, 0.0, (1.2, 1.1, 0.30)), (0.8, -0.55, 0.45, 0.0, (1.3, 1.0, 0.45)), (-0.75, 0.6, 0.5, 0.0, (1.2, 1.1, 0.4)), (0.1, 0.95, 0.35, 0.0, (1.3, 1.0, 0.4))]):
        add_bm(mb, blob_bm(r, 2, seed=60 + i, amp=0.18, amp2=0.0, sq=sq), loc=(x, y, z), mat='Snow', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_ice_boulder():
    name = 'ice_boulder'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(14)
    big = hull_rock_bm((2.15, 1.85, 1.75), seed=8, rings=((0.0, 7, 1.0), (0.42, 8, 1.06), (0.8, 7, 0.78), (1.0, 4, 0.34)), jitter=0.16, sink=0.06)
    chip_edges(big, rng, 5, 0.10, min_angle=0.55)
    add_bm(mb, big, loc=(0, 0, 0), rot=(0, 0, 0.4), mat='Crystal_Main', smooth=False)
    # denser inner core (visible through the translucent shell)
    core = hull_rock_bm((1.15, 1.0, 0.85), seed=18, rings=((0.0, 6, 1.0), (0.5, 7, 1.0), (1.0, 4, 0.4)), jitter=0.2, sink=0.0)
    add_bm(mb, core, loc=(0.0, 0.0, 0.40), rot=(0, 0, 1.0), mat='Crystal_Main', smooth=False)
    sm = hull_rock_bm((1.0, 0.85, 0.85), seed=28, rings=((0.0, 6, 1.0), (0.5, 7, 1.0), (1.0, 4, 0.45)), jitter=0.2, sink=0.05)
    add_bm(mb, sm, loc=(1.3, -0.65, 0.0), rot=(0.05, 0.1, 2.2), mat='Crystal_Main', smooth=False)
    # sharp shards growing out of the top and side
    for i, (h, r, az, tilt, pos) in enumerate([(1.05, 0.2, 0.9, 0.35, (-0.2, 0.15, 1.05)), (0.7, 0.15, 3.0, 0.6, (-0.55, 0.45, 0.9)), (0.62, 0.13, 5.2, 0.7, (0.5, 0.4, 0.95))]):
        add_bm(mb, crystal_bm(h, r, sides=5, tip=0.35, seed=70 + i, taper=0.8, jit=0.1), loc=pos, rot=lean_rot(az, tilt), mat='Crystal_Main', smooth=False)
    # snow flecks in the cracks at the foot
    for i, (x, y, r) in enumerate([(-1.0, -0.4, 0.34), (0.2, 1.0, 0.3), (1.0, 0.7, 0.26), (-0.3, -1.0, 0.3)]):
        add_bm(mb, blob_bm(r, 1, seed=80 + i, amp=0.15, amp2=0.0, sq=(1.3, 1.1, 0.35)), loc=(x, y, 0.0), mat='Snow', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_frost_shrub():
    name = 'frost_shrub'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(23)
    bml, bmt = bmesh.new(), bmesh.new()
    for i in range(30):
        az = TAU * i / 30 + rng.uniform(-0.2, 0.2)
        el = rad(rng.uniform(58, 88))
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        L = rng.uniform(0.62, 1.0) * (0.8 + 0.3 * math.sin(el))
        rr = rng.uniform(0.04, 0.26)
        base = Vector((math.cos(az) * rr, math.sin(az) * rr, 0.10))
        spine = turtle(base, d, L, n=3, bend=rng.uniform(0.3, 0.9), toward=(math.cos(az), math.sin(az), -0.3), seed=i)
        w = d.cross(Vector((0, 0, 1)))
        w = (w if w.length > 1e-3 else Vector((1, 0, 0))).normalized()
        wd = rng.uniform(0.12, 0.17)
        strip_bm(spine[:3], [wd * 0.8, wd, wd * 0.9], w, tip=False, bm=bml)
        strip_bm(spine[2:], [wd * 0.9, wd * 0.55, 0.0], w, tip=True, bm=bmt)
    add_bm(mb, bml, mat='Foliage_B', closed=False, smooth=True)
    add_bm(mb, bmt, mat='Snow', closed=False, smooth=True)
    # leafy frosted lumps in the middle (snow on top) so the shrub has body
    for i, (x, y, z, r) in enumerate([(0.0, 0.0, 0.42, 0.34), (0.30, 0.12, 0.30, 0.26), (-0.28, 0.16, 0.32, 0.27), (0.04, -0.30, 0.28, 0.25), (-0.12, 0.34, 0.26, 0.22)]):
        lb = blob_bm(r, 1, seed=100 + i, amp=0.18, amp2=0.0, sq=(1.1, 1.1, 0.9))
        lb.transform(MB.xf((x, y, z)))
        sn = snow_cap_bm(lb, min_nz=0.55, thick=0.07, seed=i, lumpy=0.3, grow=1.6)
        add_bm(mb, lb, mat='Foliage_B', smooth=False)
        if sn is not None:
            add_bm(mb, sn, mat='Snow', smooth=True, closed=False)
    add_bm(mb, blob_bm(0.50, 2, seed=8, amp=0.2, amp2=0.0, sq=(1.25, 1.25, 0.34)), loc=(0, 0, 0.05), mat='Snow', smooth=True)
    for i, (x, y, z, r) in enumerate([(0.22, 0.05, 0.28, 0.17), (-0.2, 0.14, 0.32, 0.15), (0.0, -0.24, 0.26, 0.14)]):
        add_bm(mb, blob_bm(r, 1, seed=90 + i, amp=0.15, amp2=0.0, sq=(1.1, 1.1, 0.6)), loc=(x, y, z), mat='Snow', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=60, weighted=False)


def build_snow_rock():
    name = 'snow_rock'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(77)
    # tall angular main rock + leaning companion, both capped with thick snow
    main = hull_rock_bm((2.05, 1.7, 1.95), seed=5, rings=((0.0, 7, 1.0), (0.4, 8, 1.08), (0.75, 7, 0.82), (1.0, 5, 0.5)), jitter=0.17, sink=0.08)
    chip_edges(main, rng, 4, 0.10, min_angle=0.5)
    patch_mats(main, 5, thresh=0.1)
    main.transform(MB.xf((0, 0, 0), (0, 0, 0.5)))
    snow = snow_cap_bm(main, min_nz=0.40, thick=0.26, seed=5, lumpy=0.4, grow=2.6)
    add_bm(mb, main, mat=['Rock_A', 'Rock_B'], smooth=False, closed=False)
    if snow is not None:
        add_bm(mb, snow, mat='Snow', smooth=True, closed=False)
    comp = hull_rock_bm((1.15, 0.95, 1.0), seed=15, rings=((0.0, 6, 1.0), (0.5, 7, 1.0), (1.0, 4, 0.5)), jitter=0.2, sink=0.06)
    patch_mats(comp, 15, thresh=0.0)
    comp.transform(MB.xf((1.15, -0.7, 0.0), (0.1, -0.1, 2.0)))
    snow2 = snow_cap_bm(comp, min_nz=0.40, thick=0.16, seed=6, lumpy=0.35, grow=2.2)
    add_bm(mb, comp, mat=['Rock_A', 'Rock_B'], smooth=False, closed=False)
    if snow2 is not None:
        add_bm(mb, snow2, mat='Snow', smooth=True, closed=False)
    # snow drift piled against one side
    add_bm(mb, blob_bm(0.9, 2, seed=11, amp=0.2, amp2=0.0, sq=(1.5, 0.9, 0.34)), loc=(-0.85, 0.75, 0.0), rot=(0, 0, 0.6), mat='Snow', smooth=True)
    add_bm(mb, blob_bm(0.45, 1, seed=12, amp=0.2, amp2=0.0, sq=(1.3, 1.0, 0.4)), loc=(0.2, -1.25, 0.0), mat='Snow', smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


BUILDERS = [('tree_pine_snow', build_tree_pine_snow), ('tree_pine_snow_b', build_tree_pine_snow_b), ('ice_spire', build_ice_spire),
            ('ice_boulder', build_ice_boulder), ('frost_shrub', build_frost_shrub), ('snow_rock', build_snow_rock)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
