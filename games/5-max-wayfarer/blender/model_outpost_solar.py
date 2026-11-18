"""outpost_solar - field of 8 tilted solar panels (2 rows x 4) on stands + battery box, ~8 x 6 m footprint.
Panels face +Y (Blender) = -Z (Godot), tilted 30 deg.  Origin = centre of the field at ground level; footings extend 0.8 m below.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Concrete', '#8B8E91', metal=0.0, rough=0.92)
mat('Solar_Cell', '#13203C', metal=0.55, rough=0.22)
mat('Solar_Grid', '#6C86AE', metal=0.6, rough=0.3)
COLL_NAME = "outpost_solar"
coll = fresh_collection(COLL_NAME)

TH = rad(30)
PW, PL = 1.75, 2.3           # panel width, length along the slope
U = Vector((1, 0, 0))
V = Vector((0, -math.cos(TH), math.sin(TH)))
N = Vector((0, math.sin(TH), math.cos(TH)))
RM = Matrix((U, V, N)).transposed()


def flat_quad(mb, pts, mat_, normal):
    vs = [mb.bm.verts.new(p) for p in pts]
    f = mb.bm.faces.new(vs)
    f.material_index = mb.mi(mat_)
    f.smooth = False
    f.normal_update()
    if f.normal.dot(normal) < 0:
        f.normal_flip()
    return f


def panel(mb, C):
    C = Vector(C)
    # cell plate + frame bars
    mb.rbox((PW - 0.10, PL - 0.10, 0.03), center=C, rot=RM, bevel=0.0, mat='Solar_Cell')
    for s in (-1, 1):
        mb.rbox((0.07, PL, 0.055), center=C + U * (s * (PW / 2 - 0.035)), rot=RM, bevel=0.008, bsegs=1, mat='Hull_Paint')
        mb.rbox((PW, 0.07, 0.055), center=C + V * (s * (PL / 2 - 0.035)), rot=RM, bevel=0.008, bsegs=1, mat='Hull_Paint')
    # thin grid lines just above the cells
    top = C + N * 0.0165
    nc, nr = 6, 10
    for i in range(1, nc):
        x = -(PW - 0.1) / 2 + (PW - 0.1) * i / nc
        a = top + U * x
        flat_quad(mb, [a - V * (PL / 2 - 0.05) - U * 0.006, a - V * (PL / 2 - 0.05) + U * 0.006,
                       a + V * (PL / 2 - 0.05) + U * 0.006, a + V * (PL / 2 - 0.05) - U * 0.006], 'Solar_Grid', N)
    for j in range(1, nr):
        y = -(PL - 0.1) / 2 + (PL - 0.1) * j / nr
        a = top + V * y
        flat_quad(mb, [a - U * (PW / 2 - 0.05) - V * 0.005, a + U * (PW / 2 - 0.05) - V * 0.005,
                       a + U * (PW / 2 - 0.05) + V * 0.005, a - U * (PW / 2 - 0.05) + V * 0.005], 'Solar_Grid', N)
    # junction box on the back + cable gland
    mb.rbox((0.22, 0.14, 0.09), center=C - N * 0.10 + V * 0.45, rot=RM, bevel=0.015, bsegs=1, mat='Hull_Dark')
    # stand: two front and two rear posts, torque beams, braces
    low = C - V * (PL / 2 - 0.25)
    high = C + V * (PL / 2 - 0.25)
    for s in (-1, 1):
        for base in (low, high):
            top_p = base + U * (s * 0.6) - N * 0.07
            mb.cyl(0.045, top_p.z - 0.15, center=(top_p.x, top_p.y, 0.15 + (top_p.z - 0.15) / 2), segs=8, mat='Metal')
            mb.rbox((0.30, 0.30, 0.95), center=(top_p.x, top_p.y, -0.32), bevel=0.04, bsegs=1, mat='Concrete')
            mb.rbox((0.18, 0.18, 0.025), center=(top_p.x, top_p.y, 0.175), bevel=0.0, mat='Hull_Dark')
    for base in (low, high):
        mb.rbox((PW - 0.1, 0.08, 0.07), center=base - N * 0.095, rot=RM, bevel=0.01, bsegs=1, mat='Hull_Dark')
    # diagonal brace on one side
    pa = low + U * 0.6 - N * 0.07
    pb = high + U * 0.6 - N * 0.07
    mb.tube([(pa.x, pa.y, 0.6), (pb.x, pb.y, pb.z - 0.35)], 0.022, segs=5, mat='Metal', cap_a=False, cap_b=False)


def battery_box(mb, c):
    cx, cy = c
    mb.rbox((2.4, 1.6, 0.9), center=(cx, cy, -0.35), bevel=0.04, bsegs=1, mat='Concrete')
    mb.rbox((1.8, 1.1, 1.3), center=(cx, cy, 0.7), bevel=0.07, bsegs=2, mat='Hull_Paint')
    mb.rbox((1.86, 1.16, 0.2), center=(cx, cy, 0.4), bevel=0.03, bsegs=1, mat='Hull_Accent')
    mb.rbox((1.95, 1.25, 0.10), center=(cx, cy, 1.40), bevel=0.03, bsegs=1, mat='Hull_Dark')
    for i in range(6):
        mb.rbox((1.2, 0.05, 0.05), center=(cx - 0.1, cy + 0.58, 0.85 + 0.12 * i), bevel=0.0, mat='Metal')
    for i, m_ in enumerate(('Emissive_Light', 'Emissive_Amber', 'Emissive_Light')):
        mb.cyl(0.035, 0.03, center=(cx + 0.65, cy + 0.575, 1.18 - 0.14 * i), segs=8, rot=(PI / 2, 0, 0), mat=m_)
    mb.rbox((0.30, 0.04, 0.2), center=(cx + 0.65, cy + 0.575, 0.7), bevel=0.01, bsegs=1, mat='Hull_Dark')
    for sx in (-1, 1):
        mb.cyl(0.07, 0.22, center=(cx + sx * 0.5, cy - 0.2, 1.57), segs=8, mat='Metal')
    mb.tube([(cx - 0.5, cy - 0.2, 1.65), (cx - 0.5, cy - 0.2, 1.9), (cx - 1.2, cy - 0.2, 1.9)], 0.04, segs=6, mat='Metal')
    # cable conduit from the field
    mb.tube([(cx - 0.9, cy - 0.2, 1.9), (-3.9, cy - 0.2, 1.9), (-3.9, cy - 0.2, 0.2)], 0.035, segs=5, mat='Rubber') if False else None


def build():
    mb = MB("outpost_solar")
    xs = [-2.925, -0.975, 0.975, 2.925]
    rows = [(1.5, 1.20), (-1.7, 1.20)]
    for (cy, cz) in rows:
        for x in xs:
            panel(mb, (x, cy, cz))
    # main support rails + cable trench
    for (cy, cz) in rows:
        pass
    mb.rbox((8.3, 0.5, 0.15), center=(0.0, -0.1, 0.075), bevel=0.02, bsegs=1, mat='Concrete')
    mb.rbox((8.3, 0.3, 0.08), center=(0.0, -0.1, 0.19), bevel=0.01, bsegs=1, mat='Hull_Dark')
    for x in (-3.9, -1.95, 0.0, 1.95, 3.9):
        mb.rbox((0.06, 0.32, 0.085), center=(x, -0.1, 0.235), bevel=0.0, mat='Metal')
    battery_box(mb, (5.6, 0.2))
    mb.tube([(4.7, 0.1, 0.12), (4.1, -0.1, 0.12), (3.9, -0.1, 0.12)], 0.05, segs=6, mat='Rubber')
    # weather mast
    mb.cyl(0.04, 3.2, center=(-4.9, 2.4, 1.6), segs=6, mat='Metal')
    mb.rbox((0.4, 0.4, 0.5), center=(-4.9, 2.4, -0.1), bevel=0.04, bsegs=1, mat='Concrete')
    for k in range(3):
        a = TAU * k / 3 + 0.5
        d = Vector((math.cos(a), math.sin(a), 0))
        mb.tube([(-4.9, 2.4, 3.1), (-4.9 + d.x * 0.32, 2.4 + d.y * 0.32, 3.1)], 0.012, segs=4, mat='Metal', cap_a=False, cap_b=False)
        mb.sphere(0.07, center=(-4.9 + d.x * 0.34, 2.4 + d.y * 0.34, 3.1), segs=8, mat='Hull_Accent', scale=(1, 1, 0.8))
    mb.cyl(0.06, 0.08, center=(-4.9, 2.4, 3.18), segs=8, mat='Hull_Dark')
    ob = mb.finish("outpost_solar", coll, smooth_angle=40, weighted=True)
    return ob


set_material_overrides({'Emissive_Light': dict(color='#C8FFD0', emit='#3CFF6A', emit_strength=3.0, rough=0.4)})
ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
restore_materials()
park(COLL_NAME)
