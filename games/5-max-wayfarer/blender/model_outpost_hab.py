"""outpost_hab - habitat module: capsule dome on a rim base, airlock door facing +Y (Godot -Z), amber windows, roof vents/antenna,
utility pipes, front step.  Origin = ground-contact centre; the foundation extends 0.8 m below.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Concrete', '#8B8E91', metal=0.0, rough=0.92)
mat('Pipe_Steel', '#9AA0A6', metal=0.9, rough=0.4)
COLL_NAME = "outpost_hab"
coll = fresh_collection(COLL_NAME)

L_, D_, H_, ZB = 4.0, 2.45, 3.9, 0.5      # dome half length, half depth, height above the base, base z


def dome_ring(x, nexp=2.5, n_up=26, seam=0.0):
    f = max(0.0, 1 - abs(x / L_) ** 2.7) ** (1 / 2.7)
    pts = []
    if f < 1e-4:
        return [Vector((x, 0.0, ZB))] * (n_up + 1)
    for j in range(n_up):
        th = PI * j / (n_up - 1)
        y = D_ * f * spow(math.cos(th), 2.0 / nexp)
        z = ZB + H_ * f * (math.sin(th) ** (2.0 / nexp))
        pts.append(Vector((x, y, z)))
    # flat base closes the ring (one extra point keeps the base strip subdivided)
    pts.append(Vector((x, 0.0, ZB)))
    if seam:
        c = Vector((x, 0.0, ZB + 0.5))
        pts = [c + (p - c) * (1 - seam) if p.z > ZB + 1e-6 else p for p in pts]
    return pts


def dome(mb):
    seams = (-3.1, -1.55, 1.55, 3.1)
    xs = []
    n = 14
    for i in range(n + 1):
        u = math.sin(PI / 2 * i / n)
        xs.append(-L_ + L_ * (1 - math.cos(PI / 2 * i / n)) * 0 + 0.0)
    xs = [-L_ * math.cos(PI / 2 * i / 12) for i in range(0, 12)] if False else None
    # x stations: dense towards the rounded ends
    pos = [-L_ + L_ * (1 - math.cos(PI / 2 * i / 7)) for i in range(0, 8)]            # -4 .. 0 (approach 0)
    xs = sorted(set([round(v, 4) for v in pos[:-1]] + [round(-v, 4) for v in pos[:-1]] + [0.0]))
    ys = [(x, 0.0) for x in xs if all(abs(x - s) > 0.3 for s in seams)]
    for s in seams:
        ys += [(s - 0.03, 0.0), (s, 0.014), (s + 0.03, 0.0)]
    ys.sort(key=lambda t: t[0])
    rings = [dome_ring(x, seam=sh) for (x, sh) in ys]
    part = mb.loft(rings, mat='Hull_Paint', cap_a=False, cap_b=False)
    dark = mb.mi('Hull_Dark')
    for bi in range(len(part.bands)):
        if ys[bi][1] > 0 or ys[bi + 1][1] > 0:
            for f in part.bands[bi]:
                if f is not None:
                    f.material_index = dark
    # orange skirt band along the bottom (first / last ring column)
    acc = mb.mi('Hull_Accent')
    for bi in range(len(part.bands)):
        for k in (0, 24):
            f = part.bands[bi][k]
            if f is not None and f.material_index == mb.mi('Hull_Paint'):
                f.material_index = acc
    return part


def hab_surface(mb_part):
    return Surf(faces=mb_part.faces)


def place_on(mb, surf, origin, direction, size, mat_, lift=0.0, bevel=0.03, rot_extra=None):
    h = surf.cast(origin, direction)
    if not h:
        return None
    p, n = h
    R = MB.aim(n)
    mb.rbox(size, center=p + n * (size[2] / 2 + lift), rot=R, bevel=bevel, bsegs=1, mat=mat_)
    return p, n


def build():
    mb = MB("outpost_hab")
    # --- foundation and rim base
    mb.slab(rrect_pts(9.3, 6.0, 1.4, 4), 0.9, mat='Concrete', z0=-0.8, bevel=0.0)
    mb.slab(rrect_pts(8.55, 5.3, 1.25, 4), 0.5, mat='Hull_Dark', z0=0.0, bevel=0.0)
    mb.slab(rrect_pts(8.62, 5.38, 1.28, 4), 0.09, mat='Hull_Accent', z0=0.18, bevel=0.0)
    dpart = dome(mb)
    surf = Surf(faces=dpart.faces)
    # --- airlock tunnel (axis +Y), flange, door with lit frame, porthole
    ac = (0.0, 0.0, 1.75)
    mb.cyl(1.2, 1.85, center=(0, 2.85, 1.75), segs=24, rot=(PI / 2, 0, 0), mat='Hull_Paint', bevel=0.04, bsegs=1)
    mb.cyl(1.28, 0.16, center=(0, 3.62, 1.75), segs=24, rot=(PI / 2, 0, 0), mat='Hull_Accent', bevel=0.03, bsegs=1)
    mb.cyl(1.30, 0.12, center=(0, 2.35, 1.75), segs=24, rot=(PI / 2, 0, 0), mat='Hull_Dark', bevel=0.02, bsegs=1)
    mb.cyl(1.02, 0.12, center=(0, 3.64, 1.75), segs=24, rot=(PI / 2, 0, 0), mat='Hull_Dark', bevel=0.02, bsegs=1)       # door
    mb.torus(1.08, 0.05, center=(0, 3.73, 1.75), segs=32, tsegs=5, rot=(PI / 2, 0, 0), mat='Emissive_Light')            # lit frame
    mb.torus(0.88, 0.02, center=(0, 3.715, 1.75), segs=28, tsegs=4, rot=(PI / 2, 0, 0), mat='Metal')                    # inner seam
    mb.cyl(0.30, 0.06, center=(0, 3.73, 2.25), segs=16, rot=(PI / 2, 0, 0), mat='Emissive_Window')                       # porthole
    mb.torus(0.32, 0.035, center=(0, 3.73, 2.25), segs=16, tsegs=5, rot=(PI / 2, 0, 0), mat='Metal')
    mb.torus(0.20, 0.03, center=(0, 3.74, 1.40), segs=14, tsegs=5, rot=(PI / 2, 0, 0), mat='Metal')                      # handle wheel
    mb.rbox((0.42, 0.05, 0.04), center=(0, 3.74, 1.40), bevel=0.0, mat='Metal')
    mb.rbox((0.04, 0.05, 0.42), center=(0, 3.74, 1.40), bevel=0.0, mat='Metal')
    mb.rbox((0.06, 0.04, 1.5), center=(0, 3.70, 1.75), bevel=0.0, mat='Hull_Paint')                                      # door seam
    for k in range(10):                                                                                                  # flange bolts
        a = TAU * k / 10 + 0.15
        mb.cyl(0.04, 0.05, center=(1.19 * math.cos(a), 3.72, 1.75 + 1.19 * math.sin(a)), segs=6, rot=(PI / 2, 0, 0), mat='Metal')
    for sx in (-1, 1):
        mb.rbox((0.10, 0.10, 0.5), center=(sx * 0.95, 3.66, 1.0), bevel=0.02, bsegs=1, mat='Hull_Accent')                 # hazard posts
        mb.rbox((0.10, 0.10, 0.5), center=(sx * 0.95, 3.66, 2.5), bevel=0.02, bsegs=1, mat='Hull_Accent')
    # --- porch and steps
    mb.rbox((2.5, 1.2, 0.14), center=(0, 4.35, 0.43), bevel=0.03, bsegs=1, mat='Hull_Dark')
    for sx in (-1, 1):
        mb.rbox((0.12, 1.2, 0.36), center=(sx * 1.1, 4.35, 0.18), bevel=0.02, bsegs=1, mat='Hull_Dark')
    mb.rbox((2.5, 0.60, 0.26), center=(0, 5.25, 0.13), bevel=0.04, bsegs=1, mat='Hull_Dark')
    for i in range(5):
        mb.rbox((2.3, 0.04, 0.02), center=(0, 4.0 + 0.2 * i, 0.51), bevel=0.0, mat='Metal')
    railing(mb, [(-1.2, 3.75, 0.5), (-1.2, 4.9, 0.5)], h=0.95, spacing=1.2, rails=(0.5, 0.95))
    railing(mb, [(1.2, 3.75, 0.5), (1.2, 4.9, 0.5)], h=0.95, spacing=1.2, rails=(0.5, 0.95))
    # --- windows (frame + glowing pane) on the front, one on the +X end
    for x in (-3.15, -2.05, 2.05, 3.15):
        h = place_on(mb, surf, (x, 10.0, 2.35), (0, -1, 0), (1.0, 0.62, 0.14), 'Hull_Dark', lift=-0.03, bevel=0.04)
        if h:
            p, n = h
            mb.rbox((0.84, 0.46, 0.05), center=p + n * 0.125, rot=MB.aim(n), bevel=0.02, bsegs=1, mat='Emissive_Window')
    h = surf.cast((10.0, 0.0, 2.2), (-1, 0, 0))
    if h:
        p, n = h
        mb.cyl(0.42, 0.14, center=p + n * 0.02, segs=20, rot=MB.aim(n), mat='Hull_Dark', bevel=0.02, bsegs=1)
        mb.cyl(0.33, 0.05, center=p + n * 0.10, segs=20, rot=MB.aim(n), mat='Emissive_Window')
    # --- roof: vents, hatch, antenna
    for (x, y) in ((-2.3, -0.6), (1.7, -1.1), (2.9, 0.5)):
        h = surf.cast((x, y, 10.0), (0, 0, -1))
        if h:
            p, n = h
            mb.cyl(0.26, 0.18, center=p + Vector((0, 0, 0.0)), segs=14, mat='Hull_Dark', bevel=0.02, bsegs=1)
            mb.cyl(0.17, 0.55, center=p + Vector((0, 0, 0.30)), segs=12, mat='Metal', bevel=0.01, bsegs=1)
            mb.cyl(0.30, 0.08, center=p + Vector((0, 0, 0.62)), segs=14, mat='Hull_Dark', bevel=0.02, bsegs=1)
            mb.cyl(0.18, 0.10, center=p + Vector((0, 0, 0.72)), r2=0.04, segs=12, mat='Hull_Accent')
    h = surf.cast((0.4, 0.3, 10.0), (0, 0, -1))
    if h:
        p, n = h
        mb.cyl(0.62, 0.12, center=p + Vector((0, 0, 0.0)), segs=24, mat='Hull_Dark', bevel=0.02, bsegs=1)
        mb.cyl(0.50, 0.08, center=p + Vector((0, 0, 0.08)), segs=24, mat='Metal', bevel=0.015, bsegs=1)
        mb.rbox((0.34, 0.07, 0.06), center=p + Vector((0, 0, 0.16)), bevel=0.02, bsegs=1, mat='Hull_Accent')
    h = surf.cast((-1.0, -0.2, 10.0), (0, 0, -1))
    if h:
        p, n = h
        mb.cyl(0.10, 0.30, center=p + Vector((0, 0, 0.1)), segs=10, mat='Hull_Dark')
        mb.tube([p + Vector((0, 0, 0.2)), p + Vector((0, 0, 2.5))], 0.035, segs=7, mat='Metal')
        mb.rbox((1.1, 0.05, 0.05), center=p + Vector((0, 0, 1.9)), bevel=0.0, mat='Metal')
        mb.rbox((0.7, 0.05, 0.05), center=p + Vector((0, 0, 1.55)), bevel=0.0, mat='Metal')
        mb.hemi(0.34, center=p + Vector((0.0, 0.1, 2.25)), segs=16, rings=4, mat='Hull_Paint', scale=(1, 1, 0.4),
                rot=Matrix.Rotation(rad(-50), 3, 'X'))
        mb.sphere(0.05, center=p + Vector((0, 0, 2.55)), segs=8, mat='Emissive_Light')
    # --- utility pipes + tank on the back (-Y) side
    mb.tube([(-3.75, -2.85, 0.95), (3.75, -2.85, 0.95)], 0.14, segs=10, mat='Pipe_Steel')
    mb.tube([(-3.75, -2.85, 1.35), (3.0, -2.85, 1.35), (3.0, -3.5, 1.35), (3.0, -3.5, -0.35)], 0.10, segs=8, mat='Pipe_Steel')
    for x in (-3.2, -1.4, 0.6, 2.4):
        mb.cyl(0.19, 0.10, center=(x, -2.85, 0.95), segs=12, rot=(0, PI / 2, 0), mat='Hull_Accent')
    mb.cyl(0.20, 0.12, center=(0.6, -2.85, 1.25), segs=10, mat='Metal')
    mb.torus(0.15, 0.025, center=(0.6, -2.85, 1.36), segs=12, tsegs=5, mat='Hull_Accent')
    mb.cyl(0.62, 2.4, center=(-1.6, -3.7, 0.72), segs=20, rot=(0, PI / 2, 0), mat='Hull_Paint', bevel=0.06, bsegs=1)
    for x in (-2.5, -0.7):
        mb.rbox((0.16, 0.9, 0.32), center=(x, -3.7, 0.1), bevel=0.03, bsegs=1, mat='Hull_Dark')
        mb.torus(0.63, 0.04, center=(x, -3.7, 0.72), segs=16, tsegs=4, rot=(0, PI / 2, 0), mat='Hull_Accent')
    mb.tube([(-1.6, -3.1, 1.0), (-1.6, -2.85, 0.95)], 0.07, segs=8, mat='Pipe_Steel')
    # generator box with grille and status light
    mb.rbox((1.5, 0.9, 1.1), center=(3.4, -3.4, 0.35), bevel=0.06, bsegs=2, mat='Hull_Dark')
    for i in range(6):
        mb.rbox((1.1, 0.04, 0.05), center=(3.4, -2.93, 0.2 + 0.14 * i), bevel=0.0, mat='Metal')
    mb.rbox((0.12, 0.05, 0.08), center=(4.0, -2.93, 0.78), bevel=0.01, bsegs=1, mat='Emissive_Light')
    ob = mb.finish("outpost_hab", coll, smooth_angle=40, weighted=True)
    return ob


# warm-white Emissive_Light for this model (airlock frame)
set_material_overrides({'Emissive_Light': dict(color='#C8FFF0', emit='#7DFFD0', emit_strength=3.0, rough=0.4)})
ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
restore_materials()
park(COLL_NAME)
