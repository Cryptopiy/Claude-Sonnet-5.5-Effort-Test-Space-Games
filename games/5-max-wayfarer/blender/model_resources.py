"""Resource nodes (brief 2, section C): resource_sodium, resource_ferrite, resource_carbon.  Fixed colours (Res_*), readable from afar.
Origin = ground contact at the bottom centre.  Re-runnable: ONLY=[...] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

nature_palette()
mat('Res_Ferrite_Fleck', '#E9A36B', metal=1.0, rough=0.22)          # bright shiny flecks (fixed colour)
SEL = globals().get('ONLY')


def leaning(phi, tilt):
    """rotation (3x3) that tilts +Z by `tilt` towards azimuth phi"""
    return Matrix.Rotation(phi, 3, 'Z') @ Matrix.Rotation(tilt, 3, 'X') @ Matrix.Rotation(-phi, 3, 'Z')


def build_resource_sodium():
    name = 'resource_sodium'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(7)
    # small rubble base (tinted rock) so the crystals sit in the ground
    for i, (loc, sz, sd) in enumerate([((0.0, 0.0, 0.0), (0.95, 0.85, 0.30), 71), ((0.42, -0.30, 0.0), (0.42, 0.38, 0.22), 72), ((-0.38, 0.36, 0.0), (0.36, 0.32, 0.2), 73)]):
        b = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.6, 7, 0.95), (1.0, 5, 0.6)), jitter=0.2, sink=0.05)
        cl.add(b, 'Rock_B', loc=loc, rot=(0, 0, sd), smooth=False)
    # (height, radius, azimuth, tilt, offset radius)
    crystals = [(1.30, 0.16, 0.4, 0.07, 0.00), (0.98, 0.13, 1.9, 0.36, 0.24), (1.08, 0.14, 3.4, 0.30, 0.26), (0.88, 0.12, 4.8, 0.40, 0.24),
                (0.66, 0.095, 0.95, 0.78, 0.38), (0.58, 0.09, 2.7, 0.86, 0.40), (0.52, 0.085, 5.7, 0.80, 0.36)]
    for i, (h, r, az, tilt, off) in enumerate(crystals):
        bm = crystal_bm(h, r, sides=6, tip=0.30, seed=20 + i, taper=0.84, skew=(0.25 * math.cos(az), 0.25 * math.sin(az)), jit=0.08)
        c = Vector((math.cos(az + 1.0) * off, math.sin(az + 1.0) * off, 0.02))
        cl.add(bm, 'Res_Sodium', loc=c, rot=leaning(az, tilt), smooth=False, cull=False)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def vein_path(rng, d, n=9, step=0.17, spread=0.45):
    d = Vector(d).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    p = u * rng.uniform(-spread, spread) + v * rng.uniform(-spread, spread)
    th = rng.uniform(0, TAU)
    pts = []
    for i in range(n):
        pts.append(Vector(p))
        p = p + (u * math.cos(th) + v * math.sin(th)) * step
        th += rng.uniform(-0.7, 0.7)
    return pts


def build_resource_ferrite():
    name = 'resource_ferrite'
    coll = fresh_collection(name)
    mb = MB(name)
    rng = random.Random(5)
    body = rock_bm((1.55, 1.3, 1.1), seed=11, subdiv=3, amp=0.26, freq=1.2, cuts=5, cut_lo=0.62, cut_hi=0.86, bottom=0.45, sink=0.06)
    patch_mats(body, 11, thresh=0.05)
    add_bm(mb, body, mat=['Rock_B', 'Rock_A'], smooth=False)
    mb.bm.normal_update()
    surf = Surf(bm=mb.bm)
    # ore veins: raised ribbons that follow the rock surface (seen from above and from the sides)
    for d, n in (((0, 0, -1), 9), ((0, 0, -1), 7), ((-1, 0.3, -0.2), 7), ((0.5, 1, -0.2), 6)):
        pts = vein_path(rng, d, n=n, step=0.17, spread=0.36)
        strip_on_surface(mb, surf, pts, lambda t: 0.10 + 0.17 * math.sin(math.pi * min(1.0, t * 1.05)), 'Res_Ferrite', lift=0.012, direction=d, start_off=3.0,
                         step=0.13, height=0.07, rows=3)
    # shiny flecks sitting on the surface
    for i in range(9):
        dv = rnd_dir(rng, -0.1, 1.0)
        h = surf.cast(dv * 3.0 + Vector((0, 0, 0.5)), -dv + Vector((0, 0, -0.17)), 8.0)
        if not h:
            continue
        loc, nrm = h
        fl = hull_bm([(1, 0, 0), (-1, 0, 0), (0, 1.1, 0), (0, -1.1, 0), (0, 0, 1.4), (0, 0, -0.6)])
        s_ = rng.uniform(0.028, 0.055)
        for v in fl.verts:
            v.co *= s_
        rot = Vector((0, 0, 1)).rotation_difference(nrm.normalized()).to_matrix()
        add_bm(mb, fl, loc=loc + nrm.normalized() * 0.012, rot=rot, mat='Res_Ferrite_Fleck', smooth=False)
    # ore nuggets at the foot / on top
    for i, (loc, sz, sd, rz) in enumerate([((0.78, 0.35, -0.02), (0.36, 0.30, 0.26), 81, 0.5), ((-0.72, -0.4, -0.02), (0.30, 0.26, 0.22), 82, 2.2),
                                           ((-0.1, 0.05, 1.0), (0.34, 0.28, 0.22), 84, 1.0)]):
        nug = hull_rock_bm(sz, seed=sd, rings=((0.0, 6, 1.0), (0.55, 7, 1.0), (1.0, 5, 0.5)), jitter=0.2, sink=0.03)
        add_bm(mb, nug, loc=loc, rot=(0, 0, rz), mat='Res_Ferrite', smooth=False)
    return mb.finish("Body__" + name, coll, smooth_angle=5, weighted=False)


def build_resource_carbon():
    name = 'resource_carbon'
    coll = fresh_collection(name)
    mb = MB(name)
    cl = Cluster(mb)
    rng = random.Random(9)
    # big central bulb + 4 smaller bulbs on short curved stems
    cl.add(blob_bm(0.40, 2, seed=3, amp=0.10, amp2=0.0, freq=1.4, sq=(1.0, 1.0, 0.85)), 'Res_Carbon', loc=(0, 0, 0.34), smooth=True)
    bulbs = [(0.62, 0.20, 0.30), (-0.50, 0.42, 0.26), (-0.20, -0.62, 0.28), (0.40, -0.50, 0.22)]
    for i, (bx, by, br) in enumerate(bulbs):
        base = Vector((bx * 0.35, by * 0.35, 0.05))
        top = Vector((bx, by, br * 0.95))
        mid = base.lerp(top, 0.5) + Vector((0, 0, 0.18))
        sweep(mb, catmull([base, mid, top], n=1), taper_radii(3, 0.11, 0.06), segs=4, mat='Res_Carbon', cap_a=True, cap_b=False)
        cl.add(blob_bm(br, 2, seed=10 + i, amp=0.10, amp2=0.0, freq=1.5, sq=(1.0, 1.0, 0.85)), 'Res_Carbon', loc=top, smooth=True)
    # tall bud with a glowing green tip on the central bulb
    stalk = catmull([(0, 0, 0.55), (0.04, 0.02, 0.85), (-0.03, 0.05, 1.08)], n=1)
    sweep(mb, stalk, [0.07, 0.05, 0.04], segs=5, mat='Res_Carbon', cap_a=False, cap_b=True)
    cl.add(blob_bm(0.11, 1, seed=5, amp=0.08, amp2=0.0, sq=(1.0, 1.0, 1.3)), 'Res_Carbon_Tip', loc=(-0.03, 0.05, 1.18), smooth=True, cull=False)
    # small glowing nubs on the side bulbs
    for i, (bx, by, br) in enumerate(bulbs[:2]):
        cl.add(blob_bm(0.055, 1, seed=20 + i, amp=0.0, amp2=0.0), 'Res_Carbon_Tip', loc=(bx, by, br * 0.95 + br * 0.9), smooth=True, cull=False)
    # curved leaf blades drooping around
    bml = bmesh.new()
    for i in range(5):
        az = TAU * i / 5 + 0.3
        d = Vector((math.cos(az), math.sin(az), 0))
        spine = turtle(d * 0.30 + Vector((0, 0, 0.10)), d * 0.9 + Vector((0, 0, 0.45)), 0.85, n=3, bend=0.8, toward=(0, 0, -1))
        strip_bm(spine, [0.14, 0.24, 0.15, 0.0], Vector((-d.y, d.x, 0)), bm=bml)
    add_bm(mb, bml, mat='Res_Carbon', closed=False, smooth=True)
    return mb.finish("Body__" + name, coll, smooth_angle=45, weighted=False)


BUILDERS = [('resource_sodium', build_resource_sodium), ('resource_ferrite', build_resource_ferrite), ('resource_carbon', build_resource_carbon)]

for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        nature_check(_n)
        park(_n)
