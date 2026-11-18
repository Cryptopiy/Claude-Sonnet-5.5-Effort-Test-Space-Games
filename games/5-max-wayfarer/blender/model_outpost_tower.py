"""outpost_tower - ~18 m lattice communications tower with dish, antennae, ladder, red lamp on top (separate node Light_Top)
and an equipment hut at the base.  Origin = tower centre at ground level; the foundation extends 0.8 m below.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Concrete', '#8B8E91', metal=0.0, rough=0.92)
COLL_NAME = "outpost_tower"
coll = fresh_collection(COLL_NAME)

Z_TOP = 15.2


def a_of(z):
    return 1.5 - 1.0 * (z / Z_TOP)


LEVELS = [0.0, 2.9, 5.8, 8.7, 11.6, 14.2, Z_TOP]
CORN = [(1, 1), (-1, 1), (-1, -1), (1, -1)]


def corner(i, z):
    sx, sy = CORN[i]
    a = a_of(z)
    return Vector((sx * a, sy * a, z))


def lattice(mb):
    # legs: painted in alternating segments
    for i in range(4):
        pts = [corner(i, -0.6)] + [corner(i, z) for z in LEVELS]
        mb.tube([pts[0], pts[1]], 0.11, segs=8, mat='Metal', cap_a=True, cap_b=False)
        for k in range(len(LEVELS) - 1):
            m_ = 'Hull_Accent' if k % 2 == 0 else 'Hull_Paint'
            mb.tube([corner(i, LEVELS[k]), corner(i, LEVELS[k + 1])], 0.100 - 0.012 * (LEVELS[k] / Z_TOP), segs=8, mat=m_,
                    cap_a=False, cap_b=False)
        for z in LEVELS[1:-1]:
            mb.sphere(0.115 - 0.012 * (z / Z_TOP), center=corner(i, z), segs=8, mat='Metal')
    # horizontal rings + X bracing
    for z in LEVELS[1:]:
        for i in range(4):
            mb.tube([corner(i, z), corner((i + 1) % 4, z)], 0.045, segs=5, mat='Metal', cap_a=False, cap_b=False)
    for k in range(len(LEVELS) - 1):
        z0, z1 = LEVELS[k], LEVELS[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            mb.tube([corner(i, z0), corner(j, z1)], 0.034, segs=5, mat='Metal', cap_a=False, cap_b=False)
            mb.tube([corner(j, z0), corner(i, z1)], 0.034, segs=5, mat='Metal', cap_a=False, cap_b=False)


def platform(mb, z, extra=0.45):
    a = a_of(z) + extra
    mb.rbox((2 * a, 2 * a, 0.08), center=(0, 0, z), bevel=0.015, bsegs=1, mat='Hull_Dark')
    for k in range(7):
        mb.rbox((2 * a - 0.1, 0.04, 0.03), center=(0, -a + 0.2 + k * (2 * a - 0.4) / 6, z + 0.05), bevel=0.0, mat='Metal')
    railing(mb, [(-a, -a, z + 0.04), (a, -a, z + 0.04), (a, a, z + 0.04), (-a, a, z + 0.04)], h=1.05, spacing=1.15, closed=True)
    for sx in (-1, 1):
        mb.rbox((0.08, 2 * a, 0.14), center=(sx * a, 0, z + 0.09), bevel=0.0, mat='Hull_Accent')
        mb.rbox((2 * a, 0.08, 0.14), center=(0, sx * a, z + 0.09), bevel=0.0, mat='Hull_Accent')


def build():
    mb = MB("outpost_tower")
    # --- foundation: slab under tower and hut, footings under the legs
    mb.slab(rrect_pts(8.8, 4.6, 0.6, 3), 0.8, mat='Concrete', z0=-0.8, bevel=0.0, m=Matrix.Translation((1.9, 0, 0)))
    for i in range(4):
        c = corner(i, 0.0)
        mb.rbox((0.8, 0.8, 0.75), center=(c.x, c.y, -0.02), bevel=0.05, bsegs=1, mat='Concrete')
        for k in range(4):
            ox = 0.28 * (1 if k % 2 else -1)
            oy = 0.28 * (1 if k // 2 else -1)
            mb.cyl(0.035, 0.28, center=(c.x + ox, c.y + oy, 0.46), segs=6, mat='Metal')
    lattice(mb)
    platform(mb, 8.7)
    platform(mb, 14.2)
    # --- ladder on the +Y face with stand-off brackets
    zb, zt = 0.6, 14.2
    lad_off = 0.32
    yb, yt = a_of(zb) + lad_off, a_of(zt) + lad_off
    ladder(mb, (0, yb, zb), (0, yt, zt), width=0.5, spacing=0.3, side=(1, 0, 0), r_rail=0.028)
    for z in (1.5, 4.4, 7.3, 10.2, 13.1):
        y_ = a_of(z) + lad_off
        for s_ in (-0.25, 0.25):
            mb.tube([(s_, y_, z), (s_, a_of(z), z)], 0.02, segs=5, mat='Metal', cap_a=False, cap_b=False)
    # --- dish on the -Y side
    zd = 11.6
    base = Vector((0, -(a_of(zd) + 0.1), zd))
    ax = Vector((0.15, -1.0, 0.18)).normalized()
    ctr = base + Vector((0, -1.15, 0.0))
    for sx in (-0.5, 0.5):
        mb.tube([Vector((sx, -a_of(zd), zd - 0.35)), ctr + Vector((sx * 0.4, 0.15, -0.25))], 0.04, segs=6, mat='Metal')
    mb.tube([Vector((0, -a_of(zd), zd + 0.45)), ctr + Vector((0, 0.15, 0.25))], 0.04, segs=6, mat='Metal')
    mb.hemi(1.05, center=ctr, segs=24, rings=6, mat='Hull_Paint', scale=(1, 1, 0.34), rot=MB.aim(ax))
    mb.torus(1.04, 0.03, center=ctr, segs=24, tsegs=5, rot=MB.aim(ax), mat='Hull_Accent')
    mb.tube([ctr, ctr + ax * 0.75], 0.025, segs=6, mat='Metal')
    mb.sphere(0.07, center=ctr + ax * 0.75, segs=8, mat='Hull_Dark')
    mb.cyl(0.18, 0.30, center=ctr + ax * -0.1 + Vector((0, 0.15, 0)), segs=10, mat='Hull_Dark')
    # --- yagi + panel antennas + whips
    zy = 12.9
    for k, ln in enumerate((1.7, 1.45, 1.25, 1.1)):
        mb.tube([(0.75 + 0.4 * k, -ln / 2 + 0.0, zy), (0.75 + 0.4 * k, ln / 2, zy)], 0.014, segs=4, mat='Metal', cap_a=True, cap_b=True)
    mb.tube([(a_of(zy), 0, zy), (2.5, 0, zy)], 0.03, segs=5, mat='Metal')
    for ang in (0, 120, 240):
        a_ = rad(ang + 30)
        c = Vector((0.55 * math.cos(a_), 0.55 * math.sin(a_), 16.2))
        mb.rbox((0.34, 0.1, 1.5), center=c, rot=Matrix.Rotation(a_ - PI / 2, 3, 'Z'), bevel=0.03, bsegs=1, mat='Hull_Paint')
        mb.rbox((0.30, 0.04, 0.2), center=c + Vector((0, 0, 0.55)) + Vector((math.cos(a_), math.sin(a_), 0)) * 0.05,
                rot=Matrix.Rotation(a_ - PI / 2, 3, 'Z'), bevel=0.0, mat='Hull_Accent')
    a14 = a_of(14.2) + 0.35
    for i, (sx, sy) in enumerate(CORN):
        h = (3.4, 2.4, 3.0, 2.0)[i]
        mb.tube([(sx * a14, sy * a14, 14.2 + 0.04), (sx * a14, sy * a14, 14.2 + h)], 0.018, segs=5, mat='Metal')
        mb.sphere(0.03, center=(sx * a14, sy * a14, 14.2 + h), segs=6, mat='Hull_Accent')
    # --- mast and lamp mount
    mb.tube([(0, 0, Z_TOP - 0.1), (0, 0, 17.85)], 0.11, segs=10, mat='Metal', cap_a=False, cap_b=True)
    for z in (15.9, 16.6):
        mb.cyl(0.17, 0.12, center=(0, 0, z), segs=12, mat='Hull_Accent', bevel=0.012, bsegs=1)
    mb.cyl(0.4, 0.06, center=(0, 0, 17.1), segs=16, mat='Hull_Dark')
    mb.cyl(0.18, 0.12, center=(0, 0, 17.9), segs=14, mat='Hull_Dark', bevel=0.015, bsegs=1)
    # --- equipment hut
    hx = 3.9
    mb.rbox((3.2, 2.8, 2.5), center=(hx, 0, 1.25), bevel=0.10, bsegs=2, mat='Hull_Paint')
    mb.rbox((3.6, 3.2, 0.16), center=(hx, 0, 2.58), bevel=0.04, bsegs=1, mat='Hull_Dark')
    mb.rbox((3.22, 2.82, 0.22), center=(hx, 0, 0.92), bevel=0.04, bsegs=1, mat='Hull_Accent')
    mb.rbox((3.3, 2.9, 0.20), center=(hx, 0, 0.1), bevel=0.04, bsegs=1, mat='Hull_Dark')
    # door (+Y face) with frame, window, vents
    mb.rbox((1.15, 0.10, 2.05), center=(hx - 0.7, 1.40, 1.13), bevel=0.03, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.95, 0.06, 1.85), center=(hx - 0.7, 1.455, 1.13), bevel=0.02, bsegs=1, mat='Metal')
    mb.rbox((0.22, 0.05, 0.08), center=(hx - 0.35, 1.5, 1.1), bevel=0.01, bsegs=1, mat='Hull_Accent')
    mb.rbox((0.7, 0.10, 0.5), center=(hx + 0.85, 1.40, 1.55), bevel=0.04, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.56, 0.05, 0.36), center=(hx + 0.85, 1.45, 1.55), bevel=0.02, bsegs=1, mat='Emissive_Window')
    for i in range(5):
        mb.rbox((0.6, 0.05, 0.05), center=(hx + 0.85, -1.42, 1.0 + 0.13 * i), bevel=0.0, mat='Metal')
    # roof equipment
    mb.rbox((1.1, 0.8, 0.5), center=(hx + 0.6, 0.2, 2.9), bevel=0.05, bsegs=1, mat='Hull_Paint')
    mb.cyl(0.28, 0.05, center=(hx + 0.6, 0.2, 3.17), segs=16, mat='Hull_Dark')
    mb.cyl(0.05, 0.1, center=(hx + 0.6, 0.2, 3.2), segs=8, mat='Metal')
    mb.cyl(0.12, 0.5, center=(hx - 0.9, -0.6, 2.9), segs=10, mat='Metal')
    mb.cyl(0.18, 0.06, center=(hx - 0.9, -0.6, 3.17), segs=10, mat='Hull_Dark')
    # conduits from hut to tower
    mb.tube([(hx - 1.6, 0.3, 1.9), (2.4, 0.3, 1.9), (2.0, 0.3, 1.4), (1.6, 0.3, 0.45), (0.9, 0.3, 0.3)], 0.07, segs=7, mat='Hull_Accent')
    mb.tube([(hx - 1.6, -0.1, 1.7), (2.3, -0.1, 1.7), (1.9, -0.1, 1.2), (1.5, -0.1, 0.35), (0.9, -0.1, 0.22)], 0.05, segs=6, mat='Metal')
    mb.rbox((0.5, 0.4, 0.5), center=(1.9, 0.0, 0.4), bevel=0.04, bsegs=1, mat='Hull_Dark')
    ob = mb.finish("outpost_tower", coll, smooth_angle=40, weighted=True)
    # separate blinking lamp node
    ml = MB("Light_Top")
    ml.hemi(0.17, center=(0, 0, 17.96), segs=14, rings=5, mat='Emissive_Light', lat0=-0.15)
    lt = ml.finish("Light_Top", coll, smooth_angle=70, weighted=False)
    set_origin(lt, (0, 0, 18.0))
    parent_keep(lt, ob)
    return ob


# red lamp: this model's Emissive_Light is red (restored afterwards; the export script sets it again)
set_material_overrides({'Emissive_Light': dict(color='#FF9A8A', emit='#FF1A0A', emit_strength=6.0, rough=0.4)})
ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
restore_materials()
park(COLL_NAME)
