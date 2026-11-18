"""landing_pad - round ship landing platform, 16 m diameter. Top surface at z=0 (Godot y=0), body down to z=-1.2.
Origin = pad centre on the top surface. Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Pad_Plate', '#6B7078', metal=0.35, rough=0.75)
mat('Pad_Side', '#4A4E55', metal=0.5, rough=0.7)
mat('Pad_Marking', '#DCDFE2', metal=0.1, rough=0.6)
mat('Hazard_Yellow', '#F2BE1A', metal=0.1, rough=0.55)
mat('Hazard_Black', '#26272B', metal=0.2, rough=0.7)
mat('Pad_Seam', '#2A2C31', metal=0.4, rough=0.7)
COLL_NAME = "landing_pad"
coll = fresh_collection(COLL_NAME)

R, H, RIN, NSEG = 8.0, 1.2, 6.25, 96


def area2(pl):
    return sum(pl[i][0] * pl[(i + 1) % len(pl)][1] - pl[(i + 1) % len(pl)][0] * pl[i][1] for i in range(len(pl)))


def ship_glyph(scale=0.55):
    half = [(0, 7.0), (0.6, 6.88), (1.05, 6.5), (1.45, 5.7), (1.72, 4.6), (1.85, 4.1), (3.1, 3.25), (3.15, 2.5), (1.85, 2.4),
            (1.85, 1.4), (3.4, -0.45), (4.5, -1.5), (5.5, -2.5), (6.35, -3.0), (6.5, -4.4), (6.2, -5.1), (3.4, -5.5), (1.5, -5.7),
            (1.4, -6.3), (0, -6.3)]
    cy = 0.35
    right = [(x * scale, (y - cy) * scale) for (x, y) in half]
    left = [(-x, y) for (x, y) in reversed(right[1:-1])]
    pts = right + left            # nose -> right side -> tail -> left side (clockwise seen from +Z)
    if area2(pts) > 0:
        pts.reverse()
    return pts


def pad_body(mb):
    prof = [(RIN, 0.0, 'Pad_Plate'),
            (6.68, 0.0, 'Pad_Plate'),
            (6.70, -0.012, 'Hazard_Black'),
            (7.38, -0.012, 'Hazard_Black'),
            (7.40, 0.0, 'Pad_Plate'),
            (7.72, 0.0, 'Pad_Plate'),
            (8.00, -0.24, 'Pad_Side'),
            (8.00, -0.95, 'Pad_Side'),
            (7.88, -1.20, 'Pad_Side'),
            (0.0, -1.20, 'Pad_Side')]
    part = mb.lathe_mats(prof, NSEG, cap_a=False, cap_b=False)
    # rim chamfer in a contrasting colour band
    return part


def top_disc(mb, part):
    """flat disc (r < RIN) as a polygon with the ship glyph cut out; glyph floor 25 mm lower"""
    bm = mb.bm
    glyph = ship_glyph()
    outer_v = part.R[0][:NSEG]
    outer = [(v.co.x, v.co.y) for v in outer_v]
    gv_top = [bm.verts.new(Vector((x, y, 0.0))) for (x, y) in glyph]
    gv_bot = [bm.verts.new(Vector((x, y, -0.025))) for (x, y) in glyph]
    allv = list(outer_v) + gv_top
    polys = [[Vector((x, y, 0)) for (x, y) in outer], [Vector((x, y, 0)) for (x, y) in glyph]]
    # outer must be CCW, hole CW
    assert area2(outer) > 0 and area2(glyph) < 0
    mi = mb.mi('Pad_Plate')
    for tri in mgeo.tessellate_polygon(polys):
        t = list(tri)
        a, b, c = [allv[i].co for i in t]
        if (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y) < 0:
            t.reverse()
        try:
            f = bm.faces.new([allv[i] for i in t])
            f.material_index = mi
            f.smooth = False
        except ValueError:
            pass
    # glyph floor
    mm = mb.mi('Pad_Marking')
    gl_ccw = list(reversed(range(len(glyph))))
    for tri in mgeo.tessellate_polygon([[Vector((glyph[i][0], glyph[i][1], 0)) for i in gl_ccw]]):
        idx = [gl_ccw[i] for i in tri]
        a, b, c = [gv_bot[i].co for i in idx]
        if (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y) < 0:
            idx.reverse()
        try:
            f = bm.faces.new([gv_bot[i] for i in idx])
            f.material_index = mm
            f.smooth = False
        except ValueError:
            pass
    # glyph walls (face into the hole)
    mw = mb.mi('Pad_Seam')
    n = len(glyph)
    for i in range(n):
        j = (i + 1) % n
        try:
            f = bm.faces.new([gv_top[i], gv_bot[i], gv_bot[j], gv_top[j]])
            f.material_index = mw
            f.smooth = False
        except ValueError:
            pass


def flat_ring(mb, r0, r1, z, mat_, segs=NSEG):
    ring0 = [Vector((r0 * math.cos(TAU * k / segs), r0 * math.sin(TAU * k / segs), z)) for k in range(segs)]
    ring1 = [Vector((r1 * math.cos(TAU * k / segs), r1 * math.sin(TAU * k / segs), z)) for k in range(segs)]
    part = mb.grid([ring0, ring1], closed=True, mat=mat_, smooth=False, outward=False)
    for f in part.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    return part


def hazard_ring(mb):
    n = 48
    y_ = mb.mi('Hazard_Yellow')
    r0, r1 = 6.72, 7.36
    for k in range(n):
        a0 = TAU * k / n
        w = TAU / n * 0.5
        sh = TAU / n * 0.55
        pts = [(r0, a0), (r1, a0 + sh), (r1, a0 + sh + w), (r0, a0 + w)]
        vs = [mb.bm.verts.new(Vector((r * math.cos(a), r * math.sin(a), -0.008))) for (r, a) in pts]
        try:
            f = mb.bm.faces.new(vs)
        except ValueError:
            continue
        f.material_index = y_
        f.smooth = False
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()


def edge_lights(mb):
    th = rad(45)
    for k in range(12):
        a = TAU * (k + 0.5) / 12
        er = Vector((math.cos(a), math.sin(a), 0))
        et = Vector((-math.sin(a), math.cos(a), 0))
        ez = Vector((0, 0, 1))
        rr = 7.86
        c = er * rr + ez * (-0.24 * (rr - 7.72) / 0.28)
        nrm = (er * math.sin(th) + ez * math.cos(th)).normalized()
        slope = (er * math.cos(th) - ez * math.sin(th)).normalized()
        Rm = Matrix((et, slope, nrm)).transposed()
        mb.rbox((0.62, 0.24, 0.05), center=c + nrm * 0.005, rot=Rm, bevel=0.012, bsegs=1, mat='Metal')
        mb.rbox((0.50, 0.15, 0.03), center=c + nrm * 0.022, rot=Rm, bevel=0.008, bsegs=1,
                mat='Emissive_Amber' if k % 2 == 0 else 'Emissive_Light')


def pylon(mb, ang_deg, rr=7.5):
    a = rad(ang_deg)
    c = Vector((rr * math.cos(a), rr * math.sin(a), 0))
    Rz = Matrix.Rotation(a, 3, 'Z')
    mb.rbox((0.62, 0.62, 0.26), center=c + Vector((0, 0, 0.11)), rot=Rz, bevel=0.05, bsegs=2, mat='Hull_Dark')
    mb.cyl(0.095, 1.35, center=c + Vector((0, 0, 0.92)), segs=14, mat='Metal', bevel=0.01, bsegs=1)
    mb.cyl(0.14, 0.10, center=c + Vector((0, 0, 0.42)), segs=14, mat='Hull_Accent', bevel=0.01, bsegs=1)
    mb.rbox((0.34, 0.34, 0.30), center=c + Vector((0, 0, 1.78)), rot=Rz, bevel=0.05, bsegs=2, mat='Hull_Dark')
    # lens band + top
    mb.cyl(0.205, 0.10, center=c + Vector((0, 0, 1.78)), segs=20, mat='Emissive_Light', bevel=0.012, bsegs=1)
    mb.cyl(0.24, 0.06, center=c + Vector((0, 0, 1.97)), segs=20, mat='Hull_Accent', bevel=0.012, bsegs=1)
    mb.sphere(0.085, center=c + Vector((0, 0, 2.06)), segs=12, mat='Emissive_Amber')
    for sx in (-1, 1):
        mb.rbox((0.09, 0.09, 0.5), center=c + Rz @ Vector((sx * 0.20, 0.0, 0.40)), rot=Rz, bevel=0.02, bsegs=1, mat='Hull_Dark')


def service_hatch(mb, ang_deg=-90.0, rr=5.35):
    a = rad(ang_deg)
    c = Vector((rr * math.cos(a), rr * math.sin(a), 0))
    Rz = Matrix.Rotation(a + PI / 2, 3, 'Z')          # local +Y points outward from the centre
    # raised platform with chamfer, step towards the rim
    mb.rbox((1.9, 1.9, 0.30), center=c + Rz @ Vector((0, 0, 0.0)), rot=Rz, bevel=0.07, bsegs=2, mat='Pad_Side')
    mb.rbox((1.9, 0.62, 0.17), center=c + Rz @ Vector((0, 1.22, -0.03)), rot=Rz, bevel=0.05, bsegs=2, mat='Pad_Side')
    mb.rbox((1.9, 0.62, 0.012), center=c + Rz @ Vector((0, 1.22, 0.058)), rot=Rz, bevel=0.0, mat='Hazard_Yellow')
    # hatch lid, frame, hinges, handle
    mb.rbox((1.45, 1.45, 0.07), center=c + Rz @ Vector((0, 0, 0.16)), rot=Rz, bevel=0.03, bsegs=2, mat='Metal')
    mb.rbox((1.20, 1.20, 0.05), center=c + Rz @ Vector((0, 0, 0.20)), rot=Rz, bevel=0.025, bsegs=2, mat='Hull_Dark')
    for i in range(5):
        mb.rbox((1.0, 0.045, 0.03), center=c + Rz @ Vector((0, -0.4 + 0.2 * i, 0.235)), rot=Rz, bevel=0.01, bsegs=1, mat='Metal')
    for sx in (-1, 1):
        mb.cyl(0.04, 0.22, center=c + Rz @ Vector((sx * 0.45, -0.72, 0.19)), segs=10, rot=Rz @ Matrix.Rotation(PI / 2, 3, 'Y'), mat='Metal')
    mb.rbox((0.30, 0.07, 0.05), center=c + Rz @ Vector((0, 0.5, 0.26)), rot=Rz, bevel=0.015, bsegs=1, mat='Hull_Accent')
    mb.rbox((0.06, 0.06, 0.05), center=c + Rz @ Vector((0.65, 0.65, 0.25)), rot=Rz, bevel=0.01, bsegs=1, mat='Emissive_Amber')


def build():
    mb = MB("landing_pad")
    part = pad_body(mb)
    top_disc(mb, part)
    hazard_ring(mb)
    # panel rings (thin dark seams) outside the glyph
    for r_ in (4.35, 5.3, 6.0):
        flat_ring(mb, r_ - 0.018, r_ + 0.018, 0.004, 'Pad_Seam')
    flat_ring(mb, 3.97, 4.03, 0.004, 'Pad_Marking')
    flat_ring(mb, 6.215, 6.29, 0.004, 'Pad_Seam')
    edge_lights(mb)
    for ang in (90, 210, 330):
        pylon(mb, ang)
    service_hatch(mb)
    ob = mb.finish("landing_pad", coll, smooth_angle=40, weighted=True)
    return ob


ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
park(COLL_NAME)
