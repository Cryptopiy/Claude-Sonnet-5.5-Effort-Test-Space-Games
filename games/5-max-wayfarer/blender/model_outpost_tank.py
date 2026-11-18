"""outpost_tank - three cylindrical storage tanks (4 m dia x ~6 m) with top catwalk, ladders, pipes and a pump house.
Origin = centre of the middle tank at ground level; foundation extends 0.8 m below.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Concrete', '#8B8E91', metal=0.0, rough=0.92)
mat('Pipe_Steel', '#9AA0A6', metal=0.9, rough=0.4)
COLL_NAME = "outpost_tank"
coll = fresh_collection(COLL_NAME)

TX = (-5.0, 0.0, 5.0)
CAT_Z = 6.75


def tank(mb, cx):
    prof = [(0.0, 0.40, 'Hull_Dark'), (1.72, 0.40, 'Hull_Dark'), (2.0, 0.66, 'Hull_Accent'), (2.0, 1.55, 'Hull_Accent'),
            (2.0, 1.75, 'Hull_Dark'), (2.0, 3.15, 'Hull_Paint'), (2.0, 3.55, 'Hull_Accent'), (2.0, 4.45, 'Hull_Paint'),
            (2.0, 4.63, 'Hull_Dark'), (2.0, 5.60, 'Hull_Paint'), (1.88, 5.95, 'Hull_Paint'), (1.45, 6.22, 'Hull_Paint'),
            (0.0, 6.40, 'Hull_Paint')]
    mb.lathe_mats(prof, 20, MB.xf((cx, 0, 0)), cap_a=True, cap_b=False)
    # concrete ring foundation
    mb.cyl(2.35, 1.2, center=(cx, 0, -0.2), segs=20, mat='Concrete')
    # manway, vent, relief valve on the dome
    mb.cyl(0.50, 0.22, center=(cx + 0.9, 0.5, 6.30), segs=12, mat='Hull_Dark', bevel=0.02, bsegs=1)
    mb.cyl(0.40, 0.08, center=(cx + 0.9, 0.5, 6.44), segs=12, mat='Metal')
    mb.rbox((0.3, 0.06, 0.05), center=(cx + 0.9, 0.5, 6.50), bevel=0.01, bsegs=1, mat='Hull_Accent')
    mb.tube([(cx - 0.8, -0.5, 6.25), (cx - 0.8, -0.5, 7.0), (cx - 0.55, -0.5, 7.25)], 0.07, segs=8, mat='Pipe_Steel')
    mb.cyl(0.14, 0.10, center=(cx - 0.8, -0.5, 6.3), segs=10, mat='Hull_Accent')
    # level gauge on the wall (+Y side)
    mb.rbox((0.14, 0.10, 3.2), center=(cx, 2.12, 3.1), bevel=0.02, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.07, 0.06, 2.6), center=(cx, 2.19, 3.1), bevel=0.0, mat='Emissive_Light')
    for z in (1.6, 4.6):
        mb.rbox((0.22, 0.14, 0.12), center=(cx, 2.05, z), bevel=0.02, bsegs=1, mat='Metal')
    # base nameplate / hazard marking
    mb.rbox((0.9, 0.04, 0.5), center=(cx, 2.02, 1.0), bevel=0.01, bsegs=1, mat='Hull_Dark')
    for k in range(3):
        mb.rbox((0.7, 0.03, 0.06), center=(cx, 2.045, 1.12 - 0.13 * k), bevel=0.0, mat='Hull_Paint')


def catwalk(mb):
    x0, x1 = -6.2, 6.4
    # deck with grating bars, supports
    mb.rbox((x1 - x0, 1.0, 0.09), center=((x0 + x1) / 2, 0, CAT_Z), bevel=0.02, bsegs=1, mat='Hull_Dark')
    for i in range(int((x1 - x0) / 0.8)):
        mb.rbox((0.06, 0.9, 0.04), center=(x0 + 0.4 + 0.8 * i, 0, CAT_Z + 0.06), bevel=0.0, mat='Metal')
    for y in (-0.5, 0.5):
        mb.rbox((x1 - x0, 0.07, 0.2), center=((x0 + x1) / 2, y, CAT_Z - 0.1), bevel=0.01, bsegs=1, mat='Metal')
    railing(mb, [(x0, -0.5, CAT_Z + 0.04), (x1, -0.5, CAT_Z + 0.04)], h=1.05, spacing=1.6, mat='Hull_Accent')
    railing(mb, [(x0, 0.5, CAT_Z + 0.04), (x1, 0.5, CAT_Z + 0.04)], h=1.05, spacing=1.6, mat='Hull_Accent')
    # end rails
    for x in (x0,):
        mb.tube([(x, -0.5, CAT_Z + 0.55), (x, 0.5, CAT_Z + 0.55)], 0.022, segs=5, mat='Hull_Accent')
        mb.tube([(x, -0.5, CAT_Z + 1.05), (x, 0.5, CAT_Z + 1.05)], 0.022, segs=5, mat='Hull_Accent')
    # support columns between and beside the tanks
    for x in (-2.5, 2.5, 6.0):
        mb.cyl(0.12, CAT_Z - 0.0, center=(x, -0.0, CAT_Z / 2), segs=8, mat='Hull_Dark')
        mb.rbox((0.7, 0.7, 0.2), center=(x, 0, -0.1), bevel=0.03, bsegs=1, mat='Concrete')
        for sy in (-1, 1):
            mb.tube([(x, sy * 0.12, CAT_Z - 0.2), (x, sy * 0.45, CAT_Z - 0.35)], 0.04, segs=5, mat='Metal')
        mb.rbox((0.6, 0.12, 0.12), center=(x, 0, CAT_Z - 0.2), bevel=0.01, bsegs=1, mat='Hull_Dark')
    # tank-top posts
    for cx in TX:
        mb.cyl(0.10, 0.5, center=(cx, 0.0, 6.55), segs=8, mat='Hull_Dark')
        mb.rbox((0.7, 0.16, 0.14), center=(cx, 0.0, CAT_Z - 0.1), bevel=0.02, bsegs=1, mat='Hull_Dark')


def ladders(mb):
    """caged ladder at the +X end of the catwalk"""
    xl = 6.75
    zt = CAT_Z + 1.0
    ladder(mb, (xl, -0.25, 0.4), (xl, -0.25, zt), width=0.5, spacing=0.3, side=(0, 1, 0), r_rail=0.028)
    for z in np_range(2.0, CAT_Z - 0.2, 1.15):
        arc = []
        for u in (-1.0, -0.7, -0.35, 0.0, 0.35, 0.7, 1.0):
            arc.append((xl + 0.46 * math.sqrt(max(0.0, 1 - u * u)), -0.25 + 0.38 * u, z))
        mb.tube(arc, 0.014, segs=4, mat='Metal', cap_a=False, cap_b=False)
    for u in (-0.7, 0.7):
        mb.tube([(xl + 0.46 * math.sqrt(1 - u * u), -0.25 + 0.38 * u, 2.0), (xl + 0.46 * math.sqrt(1 - u * u), -0.25 + 0.38 * u, CAT_Z - 0.3)],
                0.012, segs=4, mat='Metal', cap_a=False, cap_b=False)
    for z in (1.0, 3.5, 6.0):
        mb.tube([(xl - 0.05, -0.25 - 0.2, z), (xl - 0.45, -0.25 - 0.2, z)], 0.02, segs=5, mat='Metal', cap_a=False, cap_b=False)
        mb.tube([(xl - 0.05, -0.25 + 0.2, z), (xl - 0.45, -0.25 + 0.2, z)], 0.02, segs=5, mat='Metal', cap_a=False, cap_b=False)


def np_range(a, b, step):
    out = []
    v = a
    while v < b:
        out.append(v)
        v += step
    return out


def pipes(mb):
    ym = 3.05
    mb.tube([(-6.8, ym, 0.75), (9.5, ym, 0.75)], 0.20, segs=8, mat='Pipe_Steel')
    for cx in TX:
        mb.tube([(cx, ym, 0.75), (cx, 2.0, 0.75)], 0.14, segs=8, mat='Pipe_Steel')
        mb.cyl(0.27, 0.12, center=(cx, 2.35, 0.75), segs=10, rot=(PI / 2, 0, 0), mat='Hull_Accent')
        mb.cyl(0.27, 0.12, center=(cx, 2.82, 0.75), segs=10, rot=(PI / 2, 0, 0), mat='Hull_Accent')
        # valve with hand-wheel
        mb.rbox((0.30, 0.30, 0.32), center=(cx, 2.6, 0.75), bevel=0.04, bsegs=1, mat='Hull_Dark')
        mb.cyl(0.04, 0.35, center=(cx, 2.6, 1.0), segs=6, mat='Metal')
        mb.torus(0.17, 0.025, center=(cx, 2.6, 1.2), segs=10, tsegs=4, mat='Hull_Accent')
        mb.rbox((0.34, 0.03, 0.03), center=(cx, 2.6, 1.2), bevel=0.0, mat='Hull_Accent')
        mb.rbox((0.03, 0.34, 0.03), center=(cx, 2.6, 1.2), bevel=0.0, mat='Hull_Accent')
    for x in (-3.6, -1.4, 1.4, 3.6, 7.0):
        mb.rbox((0.16, 0.16, 0.7), center=(x, ym, 0.38), bevel=0.02, bsegs=1, mat='Hull_Dark')
        mb.rbox((0.26, 0.3, 0.06), center=(x, ym, 0.78), bevel=0.01, bsegs=1, mat='Metal')
        mb.rbox((0.4, 0.4, 0.12), center=(x, ym, 0.02), bevel=0.02, bsegs=1, mat='Concrete')
    for x in (-4.0, -1.0, 1.0, 4.0):
        mb.cyl(0.25, 0.10, center=(x, ym, 0.75), segs=10, rot=(0, PI / 2, 0), mat='Hull_Accent')
    # pipe to the pump house and a vertical stack from the manifold
    mb.tube([(9.5, ym, 0.75), (9.5, 1.2, 0.75), (9.9, 0.2, 0.75)], 0.17, segs=8, mat='Pipe_Steel')
    mb.tube([(-6.8, ym, 0.75), (-7.2, ym, 0.75), (-7.2, ym, 3.2)], 0.12, segs=8, mat='Pipe_Steel')
    mb.cyl(0.18, 0.12, center=(-7.2, ym, 3.3), segs=10, mat='Hull_Accent')


def pump_house(mb):
    px = 11.8
    mb.rbox((4.2, 3.4, 2.6), center=(px, 0, 1.3), bevel=0.10, bsegs=1, mat='Hull_Paint')
    mb.rbox((4.6, 3.8, 0.16), center=(px, 0, 2.68), bevel=0.04, bsegs=1, mat='Hull_Dark')
    mb.rbox((4.22, 3.42, 0.26), center=(px, 0, 0.9), bevel=0.04, bsegs=1, mat='Hull_Accent')
    mb.rbox((4.4, 3.6, 0.22), center=(px, 0, 0.11), bevel=0.04, bsegs=1, mat='Hull_Dark')
    # double door (+Y), window, louvres, roof stack
    mb.rbox((1.7, 0.10, 2.1), center=(px - 0.9, 1.72, 1.2), bevel=0.03, bsegs=1, mat='Hull_Dark')
    for sx in (-1, 1):
        mb.rbox((0.8, 0.06, 1.9), center=(px - 0.9 + sx * 0.41, 1.78, 1.2), bevel=0.02, bsegs=1, mat='Metal')
    mb.rbox((0.25, 0.05, 0.08), center=(px - 0.9, 1.84, 1.2), bevel=0.01, bsegs=1, mat='Hull_Accent')
    mb.rbox((0.9, 0.10, 0.6), center=(px + 1.2, 1.72, 1.6), bevel=0.04, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.74, 0.05, 0.44), center=(px + 1.2, 1.78, 1.6), bevel=0.02, bsegs=1, mat='Emissive_Window')
    for i in range(6):
        mb.rbox((0.05, 1.0, 0.05), center=(px + 2.14, 0.0, 1.1 + 0.14 * i), bevel=0.0, mat='Metal')
    mb.cyl(0.35, 0.9, center=(px + 1.2, -0.6, 3.15), segs=14, mat='Hull_Dark', bevel=0.02, bsegs=1)
    mb.cyl(0.46, 0.08, center=(px + 1.2, -0.6, 3.62), segs=14, mat='Hull_Accent')
    mb.rbox((1.2, 0.9, 0.5), center=(px - 1.0, -0.5, 3.0), bevel=0.05, bsegs=1, mat='Hull_Paint')
    mb.cyl(0.3, 0.05, center=(px - 1.0, -0.5, 3.27), segs=14, mat='Hull_Dark')
    # lamp
    mb.rbox((0.16, 0.12, 0.12), center=(px - 2.0, 1.78, 2.35), bevel=0.02, bsegs=1, mat='Hull_Dark')
    mb.cyl(0.05, 0.05, center=(px - 2.0, 1.86, 2.35), segs=8, rot=(PI / 2, 0, 0), mat='Emissive_Light')
    # foundation slab under the pump house
    mb.rbox((4.8, 4.0, 0.9), center=(px, 0, -0.4), bevel=0.05, bsegs=1, mat='Concrete')
    # step
    mb.rbox((1.8, 0.7, 0.2), center=(px - 0.9, 2.2, 0.1), bevel=0.03, bsegs=1, mat='Hull_Dark')


def build():
    mb = MB("outpost_tank")
    # common slab below the tanks
    mb.rbox((16.4, 6.4, 0.9), center=(0.6, 0, -0.35), bevel=0.06, bsegs=1, mat='Concrete')
    for cx in TX:
        tank(mb, cx)
    catwalk(mb)
    ladders(mb)
    pipes(mb)
    pump_house(mb)
    ob = mb.finish("outpost_tank", coll, smooth_angle=40, weighted=True)
    return ob


set_material_overrides({'Emissive_Light': dict(color='#D8FFF0', emit='#6BFFC8', emit_strength=2.4, rough=0.4)})
ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
restore_materials()
park(COLL_NAME)
