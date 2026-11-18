import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "outpost_hab_b"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
RX = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))     # local (x,y,z) -> world (Y, Z, X): extrude profile along world X

M = S.mats(ID, {
    "hull": "white",
    "hull2": dict(color=(0.36, 0.38, 0.41), metallic=0.2, roughness=0.5),
    "frame": "graphite",
    "accent": "orange",
    "base": "dconcrete",
    "window": "window_warm",
    "solar": "solar",
})
Mblink = S.mats(ID, {"blink": "emit_red"})
b = S.MB(M)
rnd = random.Random(11)


def panels(mb, origin, along, up, na, nv, normal, **kw):
    origin = Vector(origin)
    u, v = Vector(along), Vector(up)
    if u.cross(v).dot(Vector(normal)) < 0:
        origin = origin + u
        u = -u
        # keep na columns
    mb.wall_panels(origin, u, v, na, nv, **kw)


def section(cx, length, hw, h, mat="hull", ch=0.55):
    pts = [(-hw, 0.2), (hw, 0.2), (hw, h - ch), (hw - ch, h), (-hw + ch, h), (-hw, h - ch)]
    b.prism(pts, -length / 2, length / 2, mat=mat, loc=(cx, 0, 0), rot=RX)


def window_front(cx, z, w, h, y, side=1, strip=False):
    b.box((cx, side * (y + 0.02), z), (w + 0.18, 0.1, h + 0.18), mat="frame", bevel=0.05)
    b.box((cx, side * (y + 0.06), z), (w, 0.08, h), mat="window", bevel=0.03)


HW = 2.8
ZB = 0.35   # floor / plinth top
# ---- foundation plinth ---------------------------------------------------------------------------------------------
b.box((0, 0, (ZB - 0.55) / 2), (25.4, 6.9, ZB + 0.55), mat="base", bevel=0.12)
b.box((0, 0, ZB - 0.04), (25.0, 6.6, 0.1), mat="frame", bevel=0.03)
for sy in (-1, 1):
    b.box((0, sy * 3.47, 0.08), (25.45, 0.04, 0.2), mat="accent")

mods = [(-8.1, 7.0, 3.5), (0.0, 6.0, 4.2), (8.1, 7.0, 3.3)]
# ---- modules ------------------------------------------------------------------------------------------------------------
for k, (cx, ln, h) in enumerate(mods):
    section(cx, ln, HW, h, "hull")
    # skirt + roof band
    b.box((cx, HW - 0.02, 0.38), (ln - 0.05, 0.1, 0.3), mat="frame", bevel=0.02)
    b.box((cx, -HW + 0.02, 0.38), (ln - 0.05, 0.1, 0.3), mat="frame", bevel=0.02)
    # accent stripe belt
    b.box((cx, HW + 0.01, 0.8), (ln - 0.05, 0.05, 0.14), mat="accent")
    b.box((cx, -HW - 0.01, 0.8), (ln - 0.05, 0.05, 0.14), mat="accent")
    # wall panels (front & back)
    npanel = int(ln / 1.17)
    panels(b, (cx - ln / 2 + 0.15, HW, 1.0), (ln - 0.3, 0, 0), (0, 0, h - 1.55), npanel, 2, (0, 1, 0), gap=0.06, t=0.035,
           mats_=("hull", "hull2"), seed=k * 7 + 1)
    panels(b, (cx - ln / 2 + 0.15, -HW, 1.0), (ln - 0.3, 0, 0), (0, 0, h - 1.55), npanel, 2, (0, -1, 0), gap=0.06, t=0.035,
           mats_=("hull", "hull2"), seed=k * 7 + 2)
    # roof slab + edge
    b.box((cx, 0, h + 0.05), (ln - 0.2, 2 * HW - 1.9, 0.1), mat="hull2", bevel=0.03)
    # end caps (panel lines on the end walls)
    for sx in (-1, 1):
        if (k == 0 and sx == 1) or (k == 2 and sx == -1) or (k == 1):
            continue
        x_end = cx + sx * ln / 2
        panels(b, (x_end + sx * 0.0, -HW + 0.4, 0.8), (0, 2 * HW - 0.8, 0), (0, 0, h - 1.2), 3, 2, (sx, 0, 0), gap=0.06, t=0.035,
               mats_=("hull", "hull2"), seed=40 + k)
    # structural ribs across the roof
    for i in range(int(ln / 1.75)):
        x = cx - ln / 2 + 0.9 + i * 1.75
        b.box((x, 0, h + 0.13), (0.1, 2 * HW - 1.9, 0.07), mat="frame")

# ---- connectors -----------------------------------------------------------------------------------------------------------
for cx in (-3.8, 3.8):
    b.cyl((cx, 0, 1.6), 1.2, 1.2, 1.7, segs=16, axis="X", mat="hull2")
    for dx in (-0.6, 0.6):
        b.cyl((cx + dx, 0, 1.6), 1.28, 1.28, 0.14, segs=16, axis="X", mat="frame")
    b.cyl((cx, 0, 1.6), 1.25, 1.25, 0.12, segs=16, axis="X", mat="accent")
    window_front(cx, 1.65, 0.8, 0.45, 1.12)
    b.box((cx, 0, 2.95), (1.0, 0.8, 0.25), mat="frame", bevel=0.05)       # roof duct

# ---- module 1: living (windows, roof solar, side door) ---------------------------------------------------------------------
cx1, ln1, h1 = mods[0]
for i in range(3):
    wx = cx1 - 2.1 + i * 2.1
    window_front(wx, 2.15, 1.5, 0.8, HW, side=1)
    window_front(wx, 2.15, 1.5, 0.8, HW, side=-1)
# end door (left end)
xe = cx1 - ln1 / 2
b.box((xe - 0.05, 0.0, 1.5), (0.14, 1.7, 2.3), mat="frame", bevel=0.04)
b.box((xe - 0.12, -0.42, 1.4), (0.1, 0.72, 2.0), mat="hull2", bevel=0.03)
b.box((xe - 0.12, 0.42, 1.4), (0.1, 0.72, 2.0), mat="hull2", bevel=0.03)
b.box((xe - 0.16, 0.0, 2.85), (0.1, 0.9, 0.15), mat="window", bevel=0.02)
b.box((xe - 0.5, 0.0, 0.2), (1.0, 2.4, 0.3), mat="frame", bevel=0.03)
b.box((xe - 1.1, 0.0, 0.05), (0.7, 2.2, 0.15), mat="frame", bevel=0.03)
# roof solar panels (tilted)
for i in range(2):
    sx = cx1 - 1.7 + i * 3.4
    b.box((sx, 0.0, h1 + 0.75), (3.0, 3.6, 0.07), rot=(math.radians(-14), 0, 0), mat="solar", bevel=0.02)
    b.box((sx, 0.0, h1 + 0.72), (3.1, 3.7, 0.05), rot=(math.radians(-14), 0, 0), mat="frame")
    for t_ in (-1, 1):
        b.cyl((sx + t_ * 1.2, -1.3, h1 + 0.35), 0.05, 0.05, 0.7, segs=6, mat="frame")
        b.cyl((sx + t_ * 1.2, 1.3, h1 + 0.1), 0.05, 0.05, 0.2, segs=6, mat="frame")
    for j in range(1, 6):
        b.box((sx - 1.5 + j * 0.5, 0.0, h1 + 0.79), (0.025, 3.6, 0.02), rot=(math.radians(-14), 0, 0), mat="frame")
    for j in range(1, 4):
        yy = -1.8 + j * 0.9
        b.box((sx, yy * math.cos(math.radians(14)), h1 + 0.79 + yy * -math.sin(math.radians(14)) * -1), (3.0, 0.025, 0.02),
              rot=(math.radians(-14), 0, 0), mat="frame")

# ---- module 2: hub (door, ramp, observation windows, mast) --------------------------------------------------------------------
cx2, ln2, h2 = mods[1]
yf = HW
b.box((cx2, yf + 0.04, 0.2 + 1.35), (2.7, 0.16, 2.8), mat="frame", bevel=0.05)                  # door frame
b.box((cx2 - 0.5, yf + 0.13, 0.2 + 1.2), (0.92, 0.1, 2.4), mat="hull2", bevel=0.03)
b.box((cx2 + 0.5, yf + 0.13, 0.2 + 1.2), (0.92, 0.1, 2.4), mat="hull2", bevel=0.03)
b.box((cx2, yf + 0.2, 0.2 + 1.2), (0.05, 0.05, 2.4), mat="frame")
for sx in (-1, 1):
    b.cyl((cx2 + sx * 0.5, yf + 0.2, 1.9), 0.17, 0.17, 0.06, segs=14, axis="Y", mat="window")
for i in range(6):
    b.box((cx2 - 1.0 + i * 0.4, yf + 0.14, 2.75), (0.22, 0.05, 0.13), mat="accent")
b.box((cx2, yf + 0.55, 3.08), (2.8, 1.0, 0.14), mat="frame", bevel=0.04)                     # canopy
b.box((cx2, yf + 0.55, 3.18), (2.4, 0.8, 0.06), mat="hull2")
for sx in (-1, 1):
    b.box((cx2 + sx * 1.3, yf + 0.55, 2.6), (0.1, 0.9, 0.9), mat="frame", bevel=0.03)
b.box((cx2, yf + 0.9, 2.97), (1.6, 0.05, 0.08), mat="window")                                  # lit canopy edge
# ramp
b.prism([(3.5, 0.35), (6.4, 0.0), (6.4, -0.3), (3.5, -0.3)], -1.4, 1.4, mat="frame", rot=RX)
b.prism([(3.5, 0.37), (6.4, 0.02), (6.4, 0.0), (3.5, 0.35)], -1.25, 1.25, mat="accent", rot=RX)
for sx in (-1, 1):
    b.rail((cx2 + sx * 1.4, 3.5, 0.35), (cx2 + sx * 1.4, 6.3, 0.02), height=0.95, posts=4, mat="frame", r=0.03)
# observation window band
window_front(cx2 - 1.55, 3.45, 1.9, 0.5, yf)
window_front(cx2 + 1.55, 3.45, 1.9, 0.5, yf)
window_front(cx2, 3.45, 1.0, 0.5, yf)
# back door
b.box((cx2, -yf - 0.04, 1.4), (1.8, 0.14, 2.3), mat="frame", bevel=0.04)
b.box((cx2 - 0.4, -yf - 0.12, 1.3), (0.7, 0.1, 2.0), mat="hull2", bevel=0.03)
b.box((cx2 + 0.4, -yf - 0.12, 1.3), (0.7, 0.1, 2.0), mat="hull2", bevel=0.03)
b.box((cx2, -yf - 0.7, 0.18), (2.0, 1.2, 0.3), mat="frame", bevel=0.03)
# roof mast
mxx, myy = cx2 + 1.2, -0.8
b.cyl((mxx, myy, h2 + 0.3), 0.4, 0.3, 0.4, segs=10, mat="frame", bevel=0.03)
b.cyl((mxx, myy, h2 + 2.6), 0.11, 0.06, 4.4, segs=8, mat="hull2")
for z in (1.2, 2.2, 3.1):
    b.cyl((mxx, myy, h2 + z), 0.14, 0.14, 0.1, segs=8, mat="accent" if z > 2 else "frame")
b.box((mxx, myy, h2 + 4.0), (1.4, 0.05, 0.05), mat="frame")
b.box((mxx, myy, h2 + 3.7), (1.0, 0.05, 0.05), mat="frame")
b.cyl((mxx, myy, h2 + 5.4), 0.015, 0.008, 1.6, segs=5, mat="frame")
tip = Vector((mxx, myy, h2 + 6.25))
# roof dish
dn = Vector((-0.6, 0.55, 0.55)).normalized()
rm = S.rot_to(dn)
dc = Vector((cx2 - 1.4, 0.3, h2 + 0.95))
b.cyl((dc.x, dc.y, h2 + 0.3), 0.1, 0.08, 0.8, segs=8, mat="frame")
b.lathe([(0, 0.0), (0.7, 0.25), (0.78, 0.28), (0.76, 0.3), (0.64, 0.27), (0, 0.05)], segs=18, c=dc, rot=rm, mat="hull")
b.cyl(dc + dn * 0.4, 0.03, 0.03, 0.7, segs=6, mat="frame", rot=rm)
b.sphere(dc + dn * 0.78, 0.07, u=8, v=6, mat="frame")

# ---- module 3: storage / power (cargo door, tank, stack, units) ---------------------------------------------------------------
cx3, ln3, h3 = mods[2]
b.box((cx3 - 1.4, yf + 0.04, 0.2 + 1.45), (3.6, 0.16, 3.0), mat="frame", bevel=0.05)
b.box((cx3 - 1.4, yf + 0.13, 0.2 + 1.35), (3.2, 0.1, 2.7), mat="hull2", bevel=0.03)
for i in range(9):
    b.box((cx3 - 1.4, yf + 0.2, 0.55 + i * 0.28), (3.2, 0.04, 0.05), mat="frame")
for i in range(8):
    b.box((cx3 - 2.8 + i * 0.4, yf + 0.18, 0.65), (0.2, 0.05, 0.55), rot=(0, 0, 0), mat="accent" if i % 2 == 0 else "frame")
b.box((cx3 - 1.4, yf + 0.22, 3.05), (1.0, 0.06, 0.1), mat="window")
b.box((cx3 - 1.4, yf + 1.25, 0.06), (4.0, 2.4, 0.12), mat="frame", bevel=0.03)                # loading pad
b.prism([(yf + 2.4, 0.12), (yf + 4.2, 0.0), (yf + 4.2, -0.3), (yf + 2.4, -0.3)], -2.0, 2.0, mat="frame", loc=(cx3 - 1.4, 0, 0), rot=RX)
# generator / vent side
b.vent((cx3 + 2.3, yf + 0.04, 1.4), 1.6, 1.4, n=8, mat_slat="frame", mat_back="frame")
b.box((cx3 + 2.3, yf + 0.04, 2.35), (1.8, 0.1, 0.06), mat="accent")
window_front(cx3 + 2.4, 2.45, 0.7, 0.4, yf)
# end door (right end)
xe = cx3 + ln3 / 2
b.box((xe + 0.05, 0.0, 1.5), (0.14, 1.7, 2.3), mat="frame", bevel=0.04)
b.box((xe + 0.12, -0.42, 1.4), (0.1, 0.72, 2.0), mat="hull2", bevel=0.03)
b.box((xe + 0.12, 0.42, 1.4), (0.1, 0.72, 2.0), mat="hull2", bevel=0.03)
b.box((xe + 0.16, 0.0, 2.85), (0.1, 0.9, 0.15), mat="window", bevel=0.02)
b.box((xe + 0.5, 0.0, 0.2), (1.0, 2.4, 0.3), mat="frame", bevel=0.03)
b.box((xe + 1.1, 0.0, 0.05), (0.7, 2.2, 0.15), mat="frame", bevel=0.03)
# roof: horizontal tank on cradles
tx = cx3 - 1.0
b.lathe([(0, -1.9), (0.82, -1.9), (0.82, 1.9), (0, 1.9)], segs=16, c=(tx, -0.4, h3 + 1.05), rot=(0, math.radians(90), 0), mat="hull")
b.sphere((tx - 1.9, -0.4, h3 + 1.05), 0.82, scale=(0.4, 1, 1), u=16, v=8, mat="hull")
b.sphere((tx + 1.9, -0.4, h3 + 1.05), 0.82, scale=(0.4, 1, 1), u=16, v=8, mat="hull")
for dx in (-1.2, 0.0, 1.2):
    b.cyl((tx + dx, -0.4, h3 + 1.05), 0.85, 0.85, 0.12, segs=16, axis="X", mat="accent")
for dx in (-1.4, 1.4):
    b.box((tx + dx, -0.4, h3 + 0.4), (0.3, 1.2, 0.7), mat="frame", bevel=0.04)
b.cyl((tx, -0.4, h3 + 1.95), 0.16, 0.16, 0.25, segs=8, mat="frame")
# exhaust stack
sxp, syp = cx3 + 2.8, -1.7
b.cyl((sxp, syp, h3 + 2.4), 0.3, 0.22, 4.8, segs=12, mat="hull2")
b.cyl((sxp, syp, h3 + 4.9), 0.36, 0.36, 0.14, segs=12, mat="accent")
b.cyl((sxp, syp, h3 + 0.25), 0.5, 0.5, 0.5, segs=12, mat="frame", bevel=0.03)
for z in (1.2, 2.6, 3.9):
    b.cyl((sxp, syp, h3 + z), 0.28, 0.28, 0.08, segs=12, mat="frame")
# AC units
for ux in (cx3 + 1.8, cx3 + 3.0):
    b.box((ux, 0.9, h3 + 0.4), (1.0, 1.0, 0.65), mat="hull2", bevel=0.04)
    b.cyl((ux, 0.9, h3 + 0.74), 0.38, 0.38, 0.05, segs=14, mat="frame")
    for a_ in range(3):
        b.box((ux, 0.9, h3 + 0.78), (0.72, 0.04, 0.02), rot=(0, 0, a_ * 60 * D2R), mat="frame")

# ---- pipes along the back ------------------------------------------------------------------------------------------------------------
yb = -HW - 0.28
xa, xb = mods[0][0] - mods[0][1] / 2 + 0.7, mods[2][0] + mods[2][1] / 2 - 0.9
b.pipe([(xa, yb, 0.4), (xa, yb, 2.0), (xb, yb, 2.0), (xb, yb, h3 + 0.6), (xb - 0.3, -0.4, h3 + 0.6), (tx + 0.9, -0.4, h3 + 0.7)], 0.13, segs=10, mat="accent", bend=0.5)
b.pipe([(xa + 0.6, yb - 0.04, 0.4), (xa + 0.6, yb - 0.04, 1.5), (xb - 1.0, yb - 0.04, 1.5), (xb - 1.0, yb - 0.04, 0.4)], 0.09, segs=8, mat="frame", bend=0.4)
for i in range(8):
    x = xa + 0.4 + i * (xb - xa - 0.8) / 7
    b.box((x, -HW - 0.1, 1.75), (0.14, 0.22, 0.9), mat="frame", bevel=0.02)
for x in (-7.0, -1.9, 1.9, 7.0, 10.5):
    b.cyl((x, yb, 2.0), 0.2, 0.2, 0.12, segs=10, axis="X", mat="frame")
for x in (-6.0, 5.2):
    b.cyl((x, yb - 0.02, 2.0), 0.08, 0.08, 0.4, segs=8, axis="Y", mat="frame")
    b.cyl((x, yb - 0.02, 2.0), 0.21, 0.21, 0.04, segs=12, axis="Y", mat="accent")         # valve wheel
    b.box((x, yb - 0.02, 2.0), (0.4, 0.03, 0.04), mat="accent")
# front conduits
for x in (-4.6, 4.6, -11.2, 11.2):
    b.pipe([(x, HW + 0.1, 3.2 if abs(x) > 5 else 3.6), (x, HW + 0.1, 0.4)], 0.06, segs=6, mat="frame", bend=0.1)

# ---- lights --------------------------------------------------------------------------------------------------------------------------
for x in (-7.0, -9.2, 8.7, 10.6):
    b.box((x, HW + 0.12, 3.05 if x < 0 else 2.85), (0.3, 0.14, 0.12), mat="frame", bevel=0.02)
    b.box((x, HW + 0.2, 3.0 if x < 0 else 2.8), (0.22, 0.04, 0.08), mat="window")
for x in (-3.0, 3.0):
    b.cyl((x, 4.6, 0.4), 0.09, 0.09, 0.8, segs=8, mat="frame")
    b.cyl((x, 4.6, 0.88), 0.11, 0.11, 0.16, segs=8, mat="window")

hab = b.build(S.nm(ID, "Hab"), col, smooth=38)

bm_ = S.MB(Mblink)
bm_.sphere((0, 0, 0), 0.12, u=10, v=7, mat="blink")
blink = bm_.build(S.nm(ID, "BlinkLight"), col, smooth=None)
blink.location = tip
a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (cx2, 7.2, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, tuple(tip + Vector((0, 0, 0.1))), size=0.4)
a_cargo = L.empty(S.nm(ID, "Anchor_Cargo"), col, (cx3 - 1.4, 5.4, 0.0), size=0.4)

objs = [hab, blink, a_door, a_top, a_cargo]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [25.4, 4.4, 7.0], "offset_y": -0.55, "center": [0, 1.65, 0.0]},
    colliders=[{"shape": "box", "size": [25.4, 4.4, 7.0], "offset_y": -0.55, "center": [0, 1.65, 0.0]},
               {"shape": "box", "size": [2.8, 0.6, 3.2], "offset_y": -0.3, "center": [0, 0.0, -5.0], "note": "front ramp (optional walkable ramp)"}],
    nodes={"blink": ["BlinkLight"], "anchors": ["Anchor_Door", "Anchor_Top", "Anchor_Cargo"], "meshes": ["Hab"]},
    notes="Long modular outpost (3 modules + 2 connector tubes), 25.4 m along X, front (doors/ramp) = Blender +Y = Godot -Z. Plinth sinks 0.55 m below y=0. "
          "Entrance ramp + Anchor_Door at the middle (hub) module; Anchor_Cargo at the roller door of the storage module; BlinkLight (red, own material *_blink) on the hub mast = Anchor_Top. "
          "Pipes run along the back wall.",
    preview_kw=dict(dist_mult=1.15),
)
print(entry["size"], entry["tris"])
