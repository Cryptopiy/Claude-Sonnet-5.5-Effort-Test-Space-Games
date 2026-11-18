import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "supply_container_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
V = Vector
rnd = random.Random(5)

M = S.mats(ID, {
    "orange": dict(color=(0.80, 0.19, 0.02), metallic=0.15, roughness=0.5),
    "frame": "graphite",
    "steel": "steel",
    "white": dict(color=(0.60, 0.60, 0.56), metallic=0.05, roughness=0.6),
    "glow": "emit_cyan",
})
Mstat = S.mats(ID, {"status": dict(color=(0.05, 0.3, 0.4), emission=(0.15, 0.9, 1.0), emission_strength=6.0, roughness=0.3)})

RXm = Matrix.Rotation(math.pi / 2, 3, "X")     # local y->Z, local z->-Y


def panels(mb, origin, along, up, na, nv, normal, **kw):
    origin = V(origin)
    u, v = V(along), V(up)
    if u.cross(v).dot(V(normal)) < 0:
        origin = origin + u
        u = -u
    mb.wall_panels(origin, u, v, na, nv, **kw)


X, Y = 2.4, 1.3         # outer footprint
ZF, ZR = 0.1, 0.95      # bottom of shell, top rim (hinge line)
hx_, hy_ = X / 2, Y / 2

b = S.MB(M)
# ---- feet ------------------------------------------------------------------------------------------------------------
for sx in (-1, 1):
    for sy in (-1, 1):
        b.box((sx * (hx_ - 0.2), sy * (hy_ - 0.15), ZF / 2), (0.34, 0.26, ZF), mat="frame", bevel=0.03)
# ---- shell (hollow) ----------------------------------------------------------------------------------------------------
b.box((0, 0, ZF + 0.05), (X - 0.04, Y - 0.04, 0.1), mat="orange", bevel=0.02)
t_ = 0.09
hz = ZR - ZF
b.box((0, hy_ - t_ / 2, ZF + hz / 2), (X, t_, hz), mat="orange", bevel=0.015)
b.box((0, -hy_ + t_ / 2, ZF + hz / 2), (X, t_, hz), mat="orange", bevel=0.015)
b.box((hx_ - t_ / 2, 0, ZF + hz / 2), (t_, Y, hz), mat="orange", bevel=0.015)
b.box((-hx_ + t_ / 2, 0, ZF + hz / 2), (t_, Y, hz), mat="orange", bevel=0.015)
# ---- frame: corner posts + rim bars ---------------------------------------------------------------------------------------
for sx in (-1, 1):
    for sy in (-1, 1):
        b.box((sx * (hx_ - 0.07), sy * (hy_ - 0.07), ZF + hz / 2), (0.15, 0.15, hz + 0.02), mat="frame", bevel=0.03)
for sy in (-1, 1):
    b.box((0, sy * (hy_ - 0.05), ZR - 0.05), (X - 0.2, 0.1, 0.1), mat="frame", bevel=0.02)
    b.box((0, sy * (hy_ - 0.05), ZF + 0.08), (X - 0.2, 0.1, 0.12), mat="frame", bevel=0.02)
for sx in (-1, 1):
    b.box((sx * (hx_ - 0.05), 0, ZR - 0.05), (0.1, Y - 0.2, 0.1), mat="frame", bevel=0.02)
    b.box((sx * (hx_ - 0.05), 0, ZF + 0.08), (0.1, Y - 0.2, 0.12), mat="frame", bevel=0.02)
# ---- stamped panels on the long sides and ends ----------------------------------------------------------------------------------
for sy in (-1, 1):
    panels(b, (-hx_ + 0.2, sy * hy_, 0.3), (X - 0.4, 0, 0), (0, 0, 0.46), 3, 1, (0, sy, 0), gap=0.07, t=0.03, mats_=("orange",), bevel=0.012)
    for i in range(1, 3):
        b.box((-hx_ + 0.2 + i * (X - 0.4) / 3, sy * (hy_ + 0.015), 0.53), (0.03, 0.03, 0.5), mat="frame")
    # horizontal accent band
    b.box((0, sy * (hy_ + 0.012), 0.74), (X - 0.5, 0.025, 0.09), mat="white")
for sx in (-1, 1):
    panels(b, (sx * hx_, -hy_ + 0.18, 0.3), (0, Y - 0.36, 0), (0, 0, 0.46), 2, 1, (sx, 0, 0), gap=0.07, t=0.03, mats_=("orange",), bevel=0.012)
    b.box((sx * (hx_ + 0.012), 0, 0.74), (0.025, Y - 0.4, 0.09), mat="white")
# U handles on the short ends
for sx in (-1, 1):
    x0 = sx * (hx_ + 0.02)
    b.pipe([V((x0, -0.22, 0.52)), V((x0 + sx * 0.12, -0.22, 0.52)), V((x0 + sx * 0.12, 0.22, 0.52)), V((x0, 0.22, 0.52))], 0.026, segs=8, mat="steel", bend=0.05)
# warning label plate + triangle + ID bars on front (+Y)
b.box((-0.75, hy_ + 0.03, 0.5), (0.5, 0.025, 0.32), mat="white", bevel=0.01)
tri = [(-0.12, -0.09), (0.12, -0.09), (0, 0.12)]
b.prism([(x - 0.85, z + 0.5) for x, z in tri], -0.016, 0.0, mat="frame", loc=(0, hy_ + 0.045, 0), rot=RXm)
b.box((-0.58, hy_ + 0.045, 0.54), (0.14, 0.01, 0.025), mat="frame")
b.box((-0.58, hy_ + 0.045, 0.48), (0.14, 0.01, 0.025), mat="frame")
# latches (front)
for sx in (-1, 1):
    b.box((sx * 0.6, hy_ + 0.04, 0.82), (0.26, 0.07, 0.2), mat="frame", bevel=0.02)
    b.box((sx * 0.6, hy_ + 0.085, 0.84), (0.18, 0.03, 0.12), mat="steel", bevel=0.01)
    b.cyl((sx * 0.6, hy_ + 0.11, 0.78), 0.04, 0.04, 0.04, segs=8, axis="Y", mat="glow")
# ---- interior (visible when the lid is open) ----------------------------------------------------------------------------------------
b.box((0, 0, ZF + 0.28), (X - 0.3, Y - 0.3, 0.3), mat="frame", bevel=0.03)
for i in range(6):
    x = -0.9 + i * 0.36
    b.cyl((x, -0.12, ZF + 0.58), 0.12, 0.12, 0.34, segs=10, mat="glow", bevel=0.01)
    b.cyl((x, -0.12, ZF + 0.77), 0.14, 0.14, 0.05, segs=10, mat="steel")
b.box((0.0, 0.3, ZF + 0.5), (1.7, 0.35, 0.12), mat="steel", bevel=0.02)
b.box((-0.5, 0.3, ZF + 0.58), (0.4, 0.28, 0.06), mat="orange", bevel=0.01)
body = b.build(S.nm(ID, "Body"), col, smooth=38)

# ---- lid (origin = hinge, rotates about local X: +105 deg opens) -------------------------------------------------------------------------
lb = S.MB(M)
HY = hy_      # hinge is at the back edge -> lid local y spans 0..Y
ly = Y / 2
lb.box((0, ly, 0.17), (X + 0.04, Y + 0.04, 0.3), mat="orange", bevel=0.07, top=(0.96, 0.95))
lb.box((0, ly, 0.02), (X - 0.2, Y - 0.2, 0.05), mat="frame")                                # inner liner
lb.box((0, ly, 0.325), (X - 0.5, Y - 0.45, 0.04), mat="orange", bevel=0.015)                # raised panel
for sx in (-1, 0, 1):
    lb.box((sx * 0.75, ly, 0.35), (0.12, Y - 0.3, 0.04), mat="frame", bevel=0.01)
lb.box((0, ly, 0.19), (X + 0.08, 0.14, 0.06), mat="frame", bevel=0.02) if False else None
for sy in (-1, 1):
    lb.box((0, ly + sy * (Y / 2 - 0.02), 0.28), (X - 0.1, 0.07, 0.07), mat="frame", bevel=0.02)
for sx in (-1, 1):
    lb.box((sx * (X / 2 - 0.02), ly, 0.28), (0.07, Y - 0.1, 0.07), mat="frame", bevel=0.02)
lb.box((0, Y + 0.012, 0.12), (X - 0.5, 0.025, 0.09), mat="white")                            # white band on the lid lip
lb.box((0, 0.46 + 0.0, 0.3), (0.8, 0.2, 0.01), mat="white") if False else None
# carry handle
lb.pipe([V((-0.35, ly, 0.35)), V((-0.35, ly, 0.5)), V((0.35, ly, 0.5)), V((0.35, ly, 0.35))], 0.03, segs=8, mat="steel", bend=0.06)
# beacon ring on the lid
lb.lathe([(0.0, 0.345), (0.18, 0.345), (0.18, 0.375), (0.15, 0.4), (0.0, 0.4)], segs=14, c=(0.0, ly - 0.3, 0.0), mat="glow")
lb.cyl((0.0, ly - 0.3, 0.355), 0.2, 0.2, 0.03, segs=14, mat="frame")
# hinge barrels
for sx in (-1, 1):
    lb.cyl((sx * 0.85, -0.01, 0.02), 0.075, 0.075, 0.42, segs=10, axis="X", mat="steel")
    lb.box((sx * 0.85, -0.01, 0.12), (0.4, 0.1, 0.2), mat="frame", bevel=0.02)
# latch keepers
for sx in (-1, 1):
    lb.box((sx * 0.6, Y + 0.0, 0.08), (0.2, 0.06, 0.14), mat="steel", bevel=0.01)
lid = lb.build(S.nm(ID, "Lid"), col, smooth=38)
lid.location = (0, -hy_, ZR)
S.parent_to(lid, body)

# status light (own material, on the front wall)
sl = S.MB(Mstat)
sl.box((0, 0, 0), (0.22, 0.05, 0.1), mat="status", bevel=0.015)
status = sl.build(S.nm(ID, "StatusLight"), col, smooth=None)
status.location = (0.0, hy_ + 0.03, 0.62)
S.parent_to(status, body)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (0, hy_ + 1.1, 0.0), size=0.3)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (0, 0, 1.5), size=0.3)

objs = [body, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [2.4, 1.3, 1.3], "offset_y": 0.0, "center": [0, 0.65, 0]},
    nodes={"lid": ["Lid"], "lights": ["StatusLight"], "meshes": ["Body"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Rugged supply crate 2.4 x 1.3 x ~1.3 m, front (latches / label) = Blender +Y = Godot -Z. `Lid` is a child of `Body` with its origin on the hinge (back top edge): "
          "rotate it about local X by +105 deg (rotation_degrees.x = +105) to open - interior (glowing cells) is modelled. `StatusLight` (child of Body, own material *_status, cyan emissive) "
          "can be recoloured when looted. Origin at ground centre.",
    preview_kw=dict(dist_mult=1.5),
)
print(entry["size"], entry["tris"])
