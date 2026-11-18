import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "fuel_depot_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
TAU = math.tau
rnd = random.Random(61)


def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)


M = S.mats(ID, {
    "hull": dict(color=(0.52, 0.52, 0.50), metallic=0.1, roughness=0.45),
    "steel": dict(color=(0.30, 0.32, 0.36), metallic=0.7, roughness=0.4),
    "frame": "graphite",
    "accent": "orange",
    "yellow": "yellow",
    "base": dict(color=(0.17, 0.165, 0.155), metallic=0.0, roughness=0.92),
    "lamp": "window_warm",
})
b = S.MB(M)


def torus(mb, c, R, r, segs=24, tseg=6, mat="steel"):
    prof = []
    for k in range(tseg + 1):
        a = TAU * k / tseg
        prof.append((R + r * math.cos(a), r * math.sin(a)))
    mb.lathe(prof, segs=segs, c=c, mat=mat)


def band(mb, c, R, h, mat, segs=24, grow=0.03):
    mb.lathe([(R, 0), (R + grow, 0), (R + grow, h), (R, h), (R, 0)], segs=segs, c=c, mat=mat)


def valve_wheel(mb, p, axis="Y", r=0.18, mat="accent"):
    mb.cyl(p, 0.03, 0.03, 0.3, segs=6, axis=axis, mat="steel")
    mb.cyl(p + (V((0, 0.14, 0)) if axis == "Y" else V((0, 0, 0.14))), r, r, 0.03, segs=12, axis=axis, mat=mat)
    for k in range(3):
        a = k * math.pi / 3
        if axis == "Y":
            mb.box(p + V((0, 0.14, 0)), (r * 2, 0.04, 0.03), rot=(0, a, 0), mat=mat)
        else:
            mb.box(p + V((0, 0, 0.14)), (r * 2, 0.03, 0.04), rot=(0, 0, a), mat=mat)


# ================================================= slab ======================================================================
b.box((0, 0, -0.17), (17.4, 12.6, 0.66), mat="base", bevel=0.12)
b.box((0, 0, 0.13), (16.9, 12.1, 0.04), mat="frame", bevel=0.01) if False else None
for sy in (-1, 1):
    b.box((0, sy * 6.22, 0.2), (17.45, 0.1, 0.22), mat="yellow")
for sx in (-1, 1):
    b.box((sx * 8.72, 0, 0.2), (0.1, 12.65, 0.22), mat="yellow")


# ================================================= vertical tanks ==============================================================
def vtank(cx, cy, r=2.1, h=5.0, ladder_ang=-60.0, label_ang=70.0):
    z0 = 0.14
    c = V((cx, cy, z0))
    b.lathe([(0, 0), (r + 0.3, 0), (r + 0.3, 0.28), (r + 0.05, 0.42), (0, 0.42)], segs=28, c=c, mat="base")
    zb = z0 + 0.42
    b.lathe([(0, 0), (r, 0), (r, h), (r * 0.985, h + 0.12), (r * 0.78, h + 0.55), (r * 0.42, h + 0.82), (0, h + 0.9)], segs=28, c=V((cx, cy, zb)), mat="hull")
    band(b, V((cx, cy, zb + 0.25)), r, 0.5, "accent", segs=28, grow=0.025)
    band(b, V((cx, cy, zb + h - 0.75)), r, 0.5, "accent", segs=28, grow=0.025)
    for z in (1.4, 2.7, 3.9):
        band(b, V((cx, cy, zb + z)), r, 0.06, "steel", segs=28, grow=0.035)
    # roof details
    ztop = zb + h
    b.cyl((cx, cy, ztop + 0.98), 0.32, 0.32, 0.3, segs=12, mat="steel")
    b.cyl((cx, cy, ztop + 1.2), 0.4, 0.4, 0.07, segs=12, mat="frame")
    b.cyl((cx + 0.95, cy + 0.3, ztop + 0.7), 0.16, 0.16, 0.3, segs=10, mat="accent")
    b.sphere((cx + 0.95, cy + 0.3, ztop + 0.92), 0.17, u=10, v=6, mat="accent")
    b.cyl((cx - 0.9, cy - 0.5, ztop + 0.72), 0.3, 0.3, 0.12, segs=12, mat="steel")
    # guard rail ring around the top rim
    rr = r - 0.12
    torus(b, V((cx, cy, ztop + 1.05)), rr, 0.03, segs=28, tseg=5, mat="yellow")
    torus(b, V((cx, cy, ztop + 0.6)), rr, 0.025, segs=28, tseg=5, mat="yellow")
    for k in range(12):
        a = TAU * k / 12
        b.cyl((cx + rr * math.cos(a), cy + rr * math.sin(a), ztop + 0.54), 0.03, 0.03, 1.08, segs=5, mat="yellow")
    # side ladder with cage hoops
    la = ladder_ang * D2R
    nrm = V((math.cos(la), math.sin(la), 0))
    base_p = V((cx, cy, 0)) + nrm * (r + 0.28) + V((0, 0, 0.5))
    top_p = V((cx, cy, 0)) + nrm * (r + 0.28) + V((0, 0, ztop + 0.2))
    b.ladder(base_p, top_p, width=0.55, mat="yellow", rail=0.03, spacing=0.3, out=tuple(nrm), rung=0.02)
    for k in range(3, int((top_p.z - base_p.z) / 0.9)):
        zz = base_p.z + k * 0.9
        side = V((-nrm.y, nrm.x, 0))
        pts = [V((cx, cy, 0)) + nrm * (r + 0.28 + 0.5 * math.sin(math.pi * u / 6)) + side * (0.45 * math.cos(math.pi * u / 6)) + V((0, 0, zz)) for u in range(7)]
        b.pipe(pts, 0.016, segs=4, mat="yellow", bend=0.05, caps=False) if False else None
    # standoffs
    for zz in (1.2, 2.7, 4.2):
        b.beam(V((cx, cy, 0)) + nrm * r + V((0, 0, zz)), V((cx, cy, 0)) + nrm * (r + 0.28) + V((0, 0, zz)), 0.07, 0.07, mat="steel")
    # level gauge strip + panel
    ga = (ladder_ang + 85) * D2R
    g = V((cx, cy, 0)) + V((math.cos(ga), math.sin(ga), 0)) * (r + 0.03)
    b.box(g + V((0, 0, 2.8)), (0.1, 0.1, 3.6), rot=(0, 0, ga), mat="frame", bevel=0.01)
    b.box(g + V((math.cos(ga), math.sin(ga), 0)) * 0.03 + V((0, 0, 2.8)), (0.045, 0.045, 3.4), rot=(0, 0, ga), mat="lamp")
    # label diamond
    lg = label_ang * D2R
    lp = V((cx, cy, 0)) + V((math.cos(lg), math.sin(lg), 0)) * (r + 0.02) + V((0, 0, 3.0))
    b.box(lp, (0.9, 0.04, 0.9), rot=(0, math.radians(45), lg + math.pi / 2) if False else (math.radians(0), 0, 0), mat="yellow", bevel=0.01) if False else None
    rm = S.rot_to(V((math.cos(lg), math.sin(lg), 0)))
    b.box(lp, (0.8, 0.8, 0.05), rot=rm @ Matrix.Rotation(math.radians(45), 3, "Z"), mat="yellow", bevel=0.01)
    b.box(lp + V((math.cos(lg), math.sin(lg), 0)) * 0.03, (0.4, 0.4, 0.04), rot=rm @ Matrix.Rotation(math.radians(45), 3, "Z"), mat="frame")
    # outlet
    return c


vtank(-4.4, 2.3, ladder_ang=-120.0, label_ang=60.0)
vtank(0.8, 2.3, ladder_ang=-60.0, label_ang=120.0)
# catwalk between the tank tops
zc_top = 0.14 + 0.42 + 5.0
b.box((-1.8, 2.3, zc_top + 0.55), (1.6, 0.9, 0.08), mat="frame", bevel=0.01)
for sy in (-1, 1):
    b.pipe([V((-2.6, 2.3 + sy * 0.45, zc_top + 0.55)), V((-2.6, 2.3 + sy * 0.45, zc_top + 1.5)), V((-1.0, 2.3 + sy * 0.45, zc_top + 1.5)), V((-1.0, 2.3 + sy * 0.45, zc_top + 0.55))], 0.03, segs=6, mat="yellow", bend=0.05)
b.pipe([V((-3.4, 2.3, zc_top + 0.1)), V((-3.4, 2.3, zc_top + 0.7))], 0.03, segs=4, mat="yellow", bend=0.02) if False else None

# ================================================= horizontal tank ===============================================================
hx, hy, hr = -2.0, -3.2, 1.45
hz = 0.14 + 0.55 + hr
prof = [(0, -4.1), (0.8, -4.0), (1.2, -3.75), (1.4, -3.4), (hr, -3.0), (hr, 3.0), (1.4, 3.4), (1.2, 3.75), (0.8, 4.0), (0, 4.1)]
b.lathe(prof, segs=26, c=V((hx, hy, hz)), rot=(0, math.pi / 2, 0), mat="hull")
for off in (-2.4, 2.4):
    b.cyl((hx + off, hy, hz), hr + 0.03, hr + 0.03, 0.55, segs=26, axis="X", mat="accent")
for off in (-1.2, 0.0, 1.2):
    b.cyl((hx + off, hy, hz), hr + 0.04, hr + 0.04, 0.07, segs=26, axis="X", mat="steel")
for off in (-2.6, 0.0, 2.6):
    b.box((hx + off, hy, 0.14 + 0.32), (0.9, 2.2, 0.5), mat="base", bevel=0.05)
    b.box((hx + off, hy, 0.14 + 0.65), (0.45, 2.6, 0.34), mat="steel", bevel=0.05, bottom=(1.0, 0.85))
for off in (-1.4, 1.5):
    b.cyl((hx + off, hy, hz + hr + 0.14), 0.42, 0.42, 0.2, segs=14, mat="steel")
    b.cyl((hx + off, hy, hz + hr + 0.26), 0.5, 0.5, 0.06, segs=14, mat="frame")
    for k in range(6):
        a = TAU * k / 6
        b.cyl((hx + off + 0.42 * math.cos(a), hy + 0.42 * math.sin(a), hz + hr + 0.3), 0.035, 0.035, 0.06, segs=6, mat="steel")
b.cyl((hx + 0.0, hy + 0.3, hz + hr + 0.55), 0.1, 0.1, 0.8, segs=8, mat="yellow")
b.sphere((hx + 0.0, hy + 0.3, hz + hr + 1.0), 0.14, u=8, v=6, mat="accent")
# end ladder + small platform on top
b.ladder(V((hx + 3.55, hy + 1.0, 0.14)), V((hx + 3.0, hy + 0.3, hz + hr * 0.95)), width=0.5, mat="yellow", out=(1, 0, 0), spacing=0.3)
# hazard label strips
for sy in (-1, 1):
    b.box((hx, hy + sy * (hr + 0.02), hz + 0.1), (1.6, 0.05, 0.7), rot=(0, 0, 0), mat="yellow", bevel=0.01)
    b.box((hx, hy + sy * (hr + 0.05), hz + 0.1), (1.2, 0.04, 0.4), mat="frame")

# ================================================= pump house ===================================================================
px, py = 6.0, -2.2
b.box((px, py, 0.14 + 1.5), (4.2, 3.4, 3.0), mat="hull", bevel=0.1)
b.box((px, py, 0.14 + 3.1), (4.5, 3.7, 0.22), mat="steel", bevel=0.06)
b.box((px, py, 0.14 + 3.3), (3.2, 2.4, 0.14), mat="frame", bevel=0.03)
b.box((px, py + 1.71, 0.14 + 0.35), (4.1, 0.08, 0.5), mat="accent")
yf = py + 1.7
b.box((px - 1.0, yf + 0.03, 0.14 + 1.15), (1.3, 0.14, 2.3), mat="frame", bevel=0.04)
b.box((px - 1.0, yf + 0.11, 0.14 + 1.05), (1.1, 0.1, 2.1), mat="steel", bevel=0.03)
b.cyl((px - 1.0, yf + 0.17, 0.14 + 1.7), 0.14, 0.14, 0.05, segs=12, axis="Y", mat="lamp")
b.box((px - 0.65, yf + 0.18, 0.14 + 1.0), (0.06, 0.06, 0.3), mat="steel")
b.box((px - 1.0, yf + 0.2, 0.14 + 2.55), (0.6, 0.06, 0.12), mat="lamp")
b.box((px - 1.0, yf + 0.55, 0.14 + 0.0), (1.6, 0.9, 0.14), mat="frame", bevel=0.03)
b.vent((px + 0.7, yf + 0.05, 0.14 + 1.6), 1.3, 1.2, n=8, mat_slat="frame", mat_back="frame")
b.box((px + 1.3, yf + 0.05, 0.14 + 0.7), (0.5, 0.08, 0.6), mat="frame", bevel=0.03)
b.box((px + 1.3, yf + 0.1, 0.14 + 0.8), (0.3, 0.03, 0.2), mat="lamp")
# roof stack + vents
b.cyl((px + 1.3, py - 0.6, 0.14 + 4.6), 0.2, 0.15, 3.0, segs=10, mat="steel")
b.cyl((px + 1.3, py - 0.6, 0.14 + 6.12), 0.26, 0.26, 0.1, segs=10, mat="accent")
b.cyl((px - 1.2, py - 0.5, 0.14 + 3.8), 0.4, 0.4, 0.3, segs=12, mat="frame")
b.cyl((px - 1.2, py - 0.5, 0.14 + 3.98), 0.45, 0.45, 0.05, segs=12, mat="steel")
b.box((px - 0.2, py + 0.4, 0.14 + 3.7), (1.2, 0.8, 0.3), mat="steel", bevel=0.04)
# pipes entering the house
b.pipe([V((px - 3.4, -0.2, 0.7)), V((px - 2.3, -0.2, 0.7)), V((px - 2.3, py + 0.8, 0.7)), V((px - 2.1, py + 0.8, 0.7))], 0.17, segs=10, mat="yellow", bend=0.5)

# ================================================= manifold / piping ===========================================================
hdr_y = 0.35
b.pipe([V((-5.0, hdr_y, 0.62)), V((3.2, hdr_y, 0.62)), V((3.2, -0.2, 0.62)), V((px - 3.4, -0.2, 0.7))], 0.17, segs=10, mat="yellow", bend=0.55)
b.pipe([V((-5.0, hdr_y + 0.5, 0.62)), V((3.0, hdr_y + 0.5, 0.62)), V((3.0, 0.9, 0.62)), V((4.6, 0.9, 0.62))], 0.1, segs=8, mat="steel", bend=0.4)
# tank outlets
for tx in (-4.4, 0.8):
    b.pipe([V((tx, 0.2, 0.62)), V((tx, 0.2, 1.1)), V((tx, 2.3 - 2.1 - 0.35, 1.1)), V((tx, 2.3 - 2.1 + 0.02, 1.1))], 0.1, segs=8, mat="steel", bend=0.2)
    valve_wheel(b, V((tx + 0.0, 0.45, 0.62 + 0.0)), axis="Y", mat="accent")
# horizontal tank outlet
b.pipe([V((hx - 2.0, hy + hr - 0.1, 0.9)), V((hx - 2.0, hy + hr + 0.5, 0.9)), V((hx - 2.0, hdr_y - 0.5, 0.62)), V((hx - 2.0, hdr_y, 0.62))], 0.11, segs=8, mat="steel", bend=0.3)
valve_wheel(b, V((hx - 2.0, -0.6, 0.62)), axis="Y", mat="accent")
for x in (-4.4, -3.2, -1.0, 0.8, 2.2):
    b.cyl((x, hdr_y, 0.62), 0.24, 0.24, 0.1, segs=10, axis="X", mat="steel")
for x in (-4.0, -2.4, -0.4, 1.4, 2.8, 4.5):
    b.box((x, hdr_y + 0.2, 0.17), (0.4, 1.1, 0.34), mat="base", bevel=0.03)
# pressure gauges
for gx_ in (-1.0, 2.2):
    b.cyl((gx_, hdr_y, 0.9), 0.025, 0.025, 0.3, segs=6, mat="steel")
    b.cyl((gx_, hdr_y, 1.1), 0.15, 0.15, 0.06, segs=12, axis="Y", mat="frame")
    b.cyl((gx_, hdr_y + 0.04, 1.1), 0.12, 0.12, 0.02, segs=12, axis="Y", mat="lamp")

# ================================================= dispenser bay ================================================================
dx, dy = 5.4, 3.6
b.box((dx, dy, 0.14 + 0.06), (4.6, 3.4, 0.12), mat="frame", bevel=0.03)
for sx in (-1, 1):
    for sy in (-1, 1):
        b.cyl((dx + sx * 2.0, dy + sy * 1.4, 0.14 + 1.75), 0.11, 0.11, 3.5, segs=8, mat="steel")
b.box((dx, dy, 0.14 + 3.55), (4.8, 3.6, 0.2), mat="hull", bevel=0.05)
b.box((dx, dy, 0.14 + 3.43), (4.4, 3.2, 0.06), mat="frame")
b.box((dx, dy + 1.82, 0.14 + 3.55), (4.82, 0.08, 0.24), mat="accent")
for k in range(4):
    b.box((dx - 1.5 + k * 1.0, dy, 0.14 + 3.38), (0.6, 0.3, 0.05), mat="lamp")
# pump unit
b.box((dx, dy - 0.5, 0.14 + 0.95), (0.95, 0.65, 1.8), mat="hull", bevel=0.06)
b.box((dx, dy - 0.5, 0.14 + 1.9), (1.05, 0.75, 0.14), mat="accent", bevel=0.03)
b.box((dx, dy - 0.15, 0.14 + 1.3), (0.7, 0.05, 0.4), mat="frame", bevel=0.01)
b.box((dx, dy - 0.12, 0.14 + 1.3), (0.6, 0.03, 0.28), mat="lamp")
b.box((dx, dy - 0.15, 0.14 + 0.75), (0.6, 0.05, 0.4), mat="steel", bevel=0.02)
b.cyl((dx + 0.3, dy - 0.05, 0.14 + 0.8), 0.04, 0.04, 0.3, segs=6, mat="frame", rot=(0.4, 0, 0))
b.pipe([V((dx - 0.45, dy - 0.2, 0.14 + 1.0)), V((dx - 0.85, dy + 0.3, 0.14 + 0.7)), V((dx - 0.6, dy + 0.9, 0.14 + 0.2)), V((dx - 0.1, dy + 1.0, 0.14 + 0.15))], 0.045, segs=6, mat="rubber" if False else "frame", bend=0.3)
b.box((dx - 1.55, dy, 0.14 + 0.5), (0.25, 0.25, 1.0), mat="yellow", bevel=0.03)
for k in range(3):
    b.cyl((dx - 2.2 + k * 0.0, dy + 1.65 - k * 0.5, 0.14 + 0.45), 0.1, 0.1, 0.9, segs=8, mat="yellow")

# ================================================= misc ======================================================================
# floodlight mast
b.cyl((-8.0, 5.3, 0.14 + 3.0), 0.12, 0.09, 6.0, segs=8, mat="steel")
b.cyl((-8.0, 5.3, 0.4), 0.3, 0.3, 0.5, segs=8, mat="frame")
for k in range(3):
    a = -0.5 + k * 0.5
    b.box((-8.0 + 0.35 * math.sin(a * 2) , 5.3 + 0.35 * math.cos(a * 2), 6.0), (0.6, 0.25, 0.25), rot=(0, 0, a), mat="frame", bevel=0.02)
    b.box((-8.0 + 0.5 * math.sin(a * 2) , 5.3 + 0.5 * math.cos(a * 2), 6.0), (0.5, 0.05, 0.18), rot=(0, 0, a), mat="lamp")
b.cyl((8.0, -5.3, 0.14 + 2.2), 0.1, 0.08, 4.4, segs=8, mat="steel")
b.box((7.8, -5.3, 4.4), (0.6, 0.3, 0.25), rot=(0, 0.3, 0.0), mat="frame", bevel=0.02)
b.box((7.75, -5.3, 4.37), (0.5, 0.05, 0.18), rot=(0, 0.3, 0.0), mat="lamp")
# warning signs
for (x, y, ang) in ((-6.5, 5.9, 0.0), (2.5, 5.9, 0.0), (-8.3, -2.0, 90.0)):
    b.cyl((x, y, 0.14 + 0.8), 0.04, 0.04, 1.6, segs=6, mat="steel")
    rm = (0, 0, math.radians(ang))
    b.box((x, y, 0.14 + 1.55), (0.7, 0.05, 0.7), rot=(0, math.radians(0), math.radians(ang)) if False else rm, mat="yellow", bevel=0.01)
    b.box((x, y + 0.03, 0.14 + 1.55), (0.45, 0.04, 0.45), rot=rm, mat="frame")
# bollards at the slab front
for k in range(7):
    b.cyl((-7.5 + k * 2.5, 5.9, 0.14 + 0.35), 0.09, 0.09, 0.7, segs=8, mat="frame")
    b.cyl((-7.5 + k * 2.5, 5.9, 0.14 + 0.62), 0.1, 0.1, 0.12, segs=8, mat="yellow")
# fuel drums
for k in range(6):
    x = -7.2 + (k % 3) * 0.75
    y = -4.9 + (k // 3) * 0.75
    b.cyl((x, y, 0.14 + 0.45), 0.3, 0.3, 0.9, segs=12, mat="accent" if k % 2 == 0 else "hull")
    b.cyl((x, y, 0.14 + 0.5), 0.31, 0.31, 0.05, segs=12, mat="steel")
    b.cyl((x, y, 0.14 + 0.9), 0.27, 0.27, 0.03, segs=12, mat="frame")

depot = b.build(S.nm(ID, "Depot"), col, smooth=40)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (dx - 0.6, dy + 2.6, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (-1.8, 2.3, zc_top + 2.0), size=0.4)
objs = [depot, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [17.4, 1.0, 12.6], "offset_y": -0.5, "center": [0, 0.0, 0]},
    colliders=[{"shape": "cylinder", "radius": 2.2, "height": 6.4, "offset_y": 0.14, "center": [-4.4, 3.34, -2.3], "note": "tank 1"},
               {"shape": "cylinder", "radius": 2.2, "height": 6.4, "offset_y": 0.14, "center": [0.8, 3.34, -2.3], "note": "tank 2"},
               {"shape": "box", "size": [8.4, 3.0, 3.0], "offset_y": 0.14, "center": [-2.0, 1.6, 3.2], "note": "horizontal tank"},
               {"shape": "box", "size": [4.2, 3.2, 3.4], "offset_y": 0.14, "center": [6.0, 1.7, 2.2], "note": "pump house"}],
    nodes={"meshes": ["Depot"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Fuel depot (17.4 x 12.6 m slab): two 6.5 m vertical tanks with ladders/rails/catwalk, one horizontal tank, pump house (+X), yellow/steel pipe manifold, canopy dispenser bay (front-right) and drums. "
          "Front = Blender +Y = Godot -Z; Anchor_Door = stand point in front of the fuel dispenser; Anchor_Top above the tanks. Slab sinks to y=-0.5. Warm emissive lamps/gauges (material *_lamp).",
    preview_kw=dict(dist_mult=1.25),
)
print(entry["size"], entry["tris"])
