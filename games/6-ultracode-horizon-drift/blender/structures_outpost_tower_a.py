import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "outpost_tower_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
V = Vector

M = S.mats(ID, {
    "hull": "white",
    "hull2": dict(color=(0.34, 0.36, 0.40), metallic=0.45, roughness=0.5),
    "frame": "graphite",
    "accent": "orange",
    "base": "dconcrete",
    "lamp": "window_warm",
    "red": "emit_red",
})
Mblink = S.mats(ID, {"blink": "emit_red"})
b = S.MB(M)

ZB = 0.4
ZT = 16.0
H0, H1 = 2.2, 0.55


def half(z):
    return H0 + (H1 - H0) * (z - ZB) / (ZT - ZB)


levels = [ZB, 3.4, 6.4, 9.2, 11.8, 14.0, ZT]
seg_mat = ["hull2", "hull2", "accent", "hull", "accent", "hull"]


def corner(sx, sy, z):
    h = half(z)
    return V((sx * h, sy * h, z))


# ---- foundation + footings ------------------------------------------------------------------------------------------------
b.box((1.95, 0, (ZB - 0.55) / 2), (10.7, 6.8, ZB + 0.55), mat="base", bevel=0.1)
b.box((1.95, 0, ZB - 0.03), (10.4, 6.5, 0.06), mat="frame", bevel=0.02)
for sx in (-1, 1):
    for sy in (-1, 1):
        c = corner(sx, sy, ZB)
        b.box((c.x, c.y, ZB + 0.2), (0.95, 0.95, 0.4), mat="hull2", bevel=0.06)
        b.box((c.x, c.y, ZB + 0.42), (0.7, 0.7, 0.06), mat="frame")
        for bx in (-1, 1):
            for by in (-1, 1):
                b.cyl((c.x + bx * 0.3, c.y + by * 0.3, ZB + 0.48), 0.05, 0.05, 0.12, segs=6, mat="frame")

# ---- legs + bracing ---------------------------------------------------------------------------------------------------------
for i in range(len(levels) - 1):
    z0, z1 = levels[i], levels[i + 1]
    t0 = (z0 - ZB) / (ZT - ZB)
    t1 = (z1 - ZB) / (ZT - ZB)
    r0 = 0.17 + (0.085 - 0.17) * t0
    r1 = 0.17 + (0.085 - 0.17) * t1
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.strut(corner(sx, sy, z0), corner(sx, sy, z1), r0, r1, segs=8, mat=seg_mat[i])
    # joints
    if i > 0:
        for sx in (-1, 1):
            for sy in (-1, 1):
                c = corner(sx, sy, z0)
                b.sphere(c, r0 * 1.35, u=8, v=6, mat="frame")
# ring beams
for z in levels[1:-1]:
    for (a, c_) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
        b.beam(corner(a[0], a[1], z), corner(c_[0], c_[1], z), 0.09, 0.09, mat="hull2")
# diagonals (X bracing) on each face
faces = [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]
for i in range(len(levels) - 1):
    z0, z1 = levels[i], levels[i + 1]
    for (a, c_) in faces:
        b.strut(corner(a[0], a[1], z0), corner(c_[0], c_[1], z1), 0.04, 0.04, segs=5, mat="hull2")
        b.strut(corner(c_[0], c_[1], z0), corner(a[0], a[1], z1), 0.04, 0.04, segs=5, mat="hull2")
# base ring beams near the ground
for (a, c_) in faces:
    b.beam(corner(a[0], a[1], 1.2), corner(c_[0], c_[1], 1.2), 0.1, 0.1, mat="hull2")

# ---- top collar + mast --------------------------------------------------------------------------------------------------------
b.box((0, 0, ZT + 0.15), (1.5, 1.5, 0.45), mat="frame", bevel=0.07)
b.box((0, 0, ZT + 0.4), (1.2, 1.2, 0.08), mat="accent")
b.cyl((0, 0, ZT + 2.2), 0.17, 0.08, 4.0, segs=10, mat="hull")
for z in (1.0, 1.8, 2.6, 3.4):
    b.cyl((0, 0, ZT + z), 0.2 - z * 0.02, 0.2 - z * 0.02, 0.1, segs=10, mat="accent" if int(z * 10) % 16 == 0 else "frame")
# panel antennas
for k in range(3):
    a = (90 + k * 120) * D2R
    d = V((math.cos(a), math.sin(a), 0))
    rm = (0, 0, a - math.pi / 2)
    p = d * 0.45
    b.box((p.x, p.y, ZT + 1.9), (0.42, 0.14, 1.5), rot=rm, mat="hull", bevel=0.04)
    b.box((p.x + d.x * 0.08, p.y + d.y * 0.08, ZT + 1.9), (0.34, 0.06, 1.38), rot=rm, mat="hull2")
    b.beam((d.x * 0.15, d.y * 0.15, ZT + 1.4), (p.x, p.y, ZT + 1.4), 0.05, 0.05, mat="frame")
    b.beam((d.x * 0.15, d.y * 0.15, ZT + 2.4), (p.x, p.y, ZT + 2.4), 0.05, 0.05, mat="frame")
# yagi arms near the top
for z, ln in ((3.2, 1.3), (3.6, 1.0)):
    b.box((0, 0, ZT + z), (ln, 0.04, 0.04), mat="frame")
b.cyl((0, 0, ZT + 4.35), 0.025, 0.012, 0.8, segs=5, mat="frame")
tip_z = ZT + 4.15

# ---- equipment platform ---------------------------------------------------------------------------------------------------------
zp = 14.2
hp = 1.55
b.box((0, 0, zp), (2 * hp, 2 * hp, 0.14), mat="frame", bevel=0.03)
b.box((0, 0, zp - 0.13), (2 * hp - 0.4, 2 * hp - 0.4, 0.12), mat="hull2")
for sx in (-1, 1):
    for sy in (-1, 1):
        b.strut(V((sx * 0.8, sy * 0.8, zp - 1.4)), V((sx * hp * 0.95, sy * hp * 0.95, zp - 0.05)), 0.05, 0.05, segs=5, mat="hull2")
for (a, c_) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
    p0 = V((a[0] * hp * 0.97, a[1] * hp * 0.97, zp + 0.07))
    p1 = V((c_[0] * hp * 0.97, c_[1] * hp * 0.97, zp + 0.07))
    b.rail(p0, p1, height=1.05, posts=4, mat="accent", r=0.028, post_r=0.028)
b.box((-0.9, -0.6, zp + 0.45), (0.8, 0.6, 0.8), mat="hull", bevel=0.04)
b.box((-0.9, -0.28, zp + 0.5), (0.5, 0.03, 0.3), mat="lamp")
b.box((0.9, -0.7, zp + 0.35), (0.7, 0.7, 0.6), mat="hull2", bevel=0.04)
b.vent((0.9, -1.06, zp + 0.38), 0.5, 0.4, n=4, rot=(0, 0, math.pi), mat_slat="frame", mat_back="frame")
# floodlights on the platform
for sx in (-1, 1):
    b.box((sx * 1.3, 1.3, zp + 1.35), (0.3, 0.16, 0.2), rot=(0.3, 0, sx * 0.4), mat="frame", bevel=0.02)
    b.box((sx * 1.3, 1.38, zp + 1.33), (0.22, 0.04, 0.13), rot=(0.3, 0, sx * 0.4), mat="lamp")

# ---- dish ---------------------------------------------------------------------------------------------------------------------------
dn = V((0.0, 0.86, 0.5)).normalized()
dc = V((0.0, 2.35, 11.6))
b.dish(dc, dn, 1.7, 0.5, mat="hull", th=0.05, segs=24, n=6)
b.lathe([(0, -0.1), (0.5, -0.1), (0.55, 0.0), (0.4, 0.15), (0, 0.15)], segs=12, c=dc - dn * 0.02, rot=S.rot_to(-dn), mat="frame")
for k in range(4):
    a = k * 90 * D2R + 45 * D2R
    rim = dc + S.rot_to(dn) @ V((1.7 * math.cos(a), 1.7 * math.sin(a), 0.5 + 0.05))
    feed = dc + dn * 1.25
    b.strut(rim, feed, 0.025, 0.025, segs=5, mat="frame")
b.cyl(dc + dn * 1.18, 0.09, 0.07, 0.25, segs=8, rot=S.rot_to(dn), mat="frame")
b.sphere(dc + dn * 1.32, 0.07, u=8, v=6, mat="accent")
# yoke / mounting back to the tower legs
for sx in (-1, 1):
    b.strut(corner(sx, 1, 10.6), dc - dn * 0.15 + V((sx * 0.35, 0, 0)), 0.07, 0.07, segs=6, mat="hull2")
    b.strut(corner(sx, 1, 12.6), dc - dn * 0.15 + V((sx * 0.35, 0, 0)), 0.06, 0.06, segs=6, mat="hull2")
b.beam(dc - dn * 0.2 + V((-0.45, 0, 0)), dc - dn * 0.2 + V((0.45, 0, 0)), 0.14, 0.14, mat="frame", bevel=0.02)

# ---- red obstruction lamps ---------------------------------------------------------------------------------------------------------------
for z in (6.4, 11.8):
    for sx, sy in ((1, 1), (-1, -1)):
        c = corner(sx, sy, z)
        b.sphere(c + V((sx * 0.05, sy * 0.05, 0.3)), 0.09, u=8, v=6, mat="red")

# ---- ladder on the back face ----------------------------------------------------------------------------------------------------------
lad_off = 0.42
pb = V((0, -(half(ZB + 0.1) + lad_off), ZB + 0.1))
pt = V((0, -(half(14.0) + lad_off), 14.0))
for sx in (-1, 1):
    b.strut(pb + V((sx * 0.26, 0, 0)), pt + V((sx * 0.26, 0, 0)), 0.025, 0.025, segs=5, mat="frame")
n_r = int((pt - pb).length / 0.36)
for i in range(1, n_r):
    p = pb.lerp(pt, i / n_r)
    b.box(p, (0.52, 0.035, 0.035), mat="frame")
for i in range(0, n_r, 5):
    p = pb.lerp(pt, i / n_r)
    # standoff brackets to the leg rings
    face_y = -half(p.z)
    b.beam(V((0.26, face_y, p.z)), V((0.26, p.y, p.z)), 0.04, 0.04, mat="frame")
    b.beam(V((-0.26, face_y, p.z)), V((-0.26, p.y, p.z)), 0.04, 0.04, mat="frame")
# cable tray up one leg
c0 = corner(1, -1, ZB + 0.4)
for k in range(2):
    off = V((0.12 + 0.07 * k, 0.12 - 0.07 * k, 0))
    b.pipe([V((3.0, -2.6, 0.5)), V((c0.x, -2.6, 0.5)), V((c0.x, c0.y, 0.5)), corner(1, -1, 14.0) + off], 0.035, segs=6, mat="frame", bend=0.3)

# ---- equipment shed ------------------------------------------------------------------------------------------------------------------------
sx0, sy0 = 4.75, 0.0
b.box((sx0, sy0, ZB + 1.3), (3.4, 4.0, 2.6), mat="hull", bevel=0.08)
b.box((sx0, sy0, ZB + 2.68), (3.7, 4.3, 0.2), mat="hull2", bevel=0.05)
b.box((sx0, sy0, ZB + 2.82), (2.6, 3.0, 0.1), mat="frame", bevel=0.02)
b.box((sx0, sy0 - 0.9, ZB + 2.95), (1.6, 1.0, 0.25), mat="hull2", bevel=0.04)
b.vent((sx0 + 0.9, sy0 - 0.6, ZB + 3.1), 0.9, 0.4, n=4, rot=(math.radians(90), 0, 0), mat_slat="frame", mat_back="frame")
S_wall = dict(gap=0.06, t=0.03, mats_=("hull", "hull2"))
b.wall_panels((sx0 - 1.6, sy0 + 2.0, ZB + 0.5), (3.2, 0, 0), (0, 0, 1.8), 4, 2, **S_wall, seed=1) if False else None
# front face (+Y): door
yf = sy0 + 2.0
b.box((sx0 - 0.9, yf + 0.04, ZB + 1.1), (1.3, 0.14, 2.2), mat="frame", bevel=0.04)
b.box((sx0 - 0.9, yf + 0.12, ZB + 1.0), (1.1, 0.1, 2.0), mat="hull2", bevel=0.03)
b.box((sx0 - 0.9, yf + 0.19, ZB + 1.0), (0.08, 0.05, 1.8), mat="frame")
b.cyl((sx0 - 0.9, yf + 0.19, ZB + 1.5), 0.14, 0.14, 0.05, segs=12, axis="Y", mat="lamp")
b.box((sx0 - 0.9, yf + 0.18, ZB + 2.4), (0.6, 0.08, 0.14), mat="lamp", bevel=0.02)
b.box((sx0 - 0.9, yf + 0.45, ZB - 0.05), (1.6, 0.9, 0.12), mat="frame", bevel=0.03)
for i in range(4):
    b.box((sx0 + 0.55 + i * 0.28, yf + 0.04, ZB + 1.3), (0.12, 0.08, 1.6), mat="frame")
b.box((sx0 + 0.55 + 0.42, yf + 0.04, ZB + 0.55), (0.9, 0.08, 0.12), mat="accent")
b.box((sx0 + 1.0, yf + 0.05, ZB + 0.18), (1.1, 0.1, 0.3), mat="accent")
# side generator and pipe
b.box((sx0 + 2.4, sy0 - 0.3, ZB + 0.6), (1.0, 1.4, 1.2), mat="hull2", bevel=0.05)
b.cyl((sx0 + 2.4, sy0 - 0.3, ZB + 1.55), 0.13, 0.13, 0.7, segs=8, mat="frame")
b.cyl((sx0 + 2.4, sy0 - 0.3, ZB + 1.95), 0.18, 0.18, 0.06, segs=8, mat="frame")
b.pipe([V((sx0 - 1.72, sy0 - 0.8, ZB + 1.8)), V((sx0 - 2.2, sy0 - 0.8, ZB + 1.8)), V((sx0 - 2.2, sy0 - 0.8, ZB + 0.3))], 0.07, segs=6, mat="frame", bend=0.2)
# cable from shed to tower
b.pipe([V((sx0 - 1.72, sy0 + 0.6, ZB + 0.5)), V((1.8, sy0 + 0.6, ZB + 0.5)), V((1.0, 1.4, ZB + 0.5)), V(corner(1, 1, ZB + 0.9))], 0.05, segs=6, mat="frame", bend=0.25)
# bollard lights
for x in (2.9, 6.6):
    b.cyl((x, yf + 1.4, ZB + 0.4), 0.09, 0.09, 0.8, segs=8, mat="frame")
    b.cyl((x, yf + 1.4, ZB + 0.88), 0.11, 0.11, 0.16, segs=8, mat="lamp")
# antenna feeder box at base
b.box((-1.0, -3.0, ZB + 0.35), (1.0, 0.5, 0.7), mat="hull2", bevel=0.04)

tower = b.build(S.nm(ID, "Tower"), col, smooth=38)
X0 = -1.95                                  # shift so that the plinth (not the tower axis) is centred on the origin
tower.location = (X0, 0, 0)

bl = S.MB(Mblink)
bl.sphere((0, 0, 0), 0.14, u=10, v=7, mat="blink")
blink = bl.build(S.nm(ID, "BlinkLight"), col, smooth=None)
blink.location = (X0, 0, tip_z + 0.5)
a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (X0 + sx0 - 0.9, yf + 1.9, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (X0, 0, tip_z + 0.65), size=0.5)

objs = [tower, blink, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [10.7, 3.0, 6.8], "offset_y": -0.55, "center": [0, 0.95, 0.0]},
    colliders=[{"shape": "box", "size": [10.7, 3.0, 6.8], "offset_y": -0.55, "center": [0, 0.95, 0.0], "note": "plinth + shed + lower legs"},
               {"shape": "box", "size": [4.6, 6.0, 4.6], "offset_y": 0.4, "center": [X0, 3.4, 0.0], "note": "lower tower (tower axis is at x=%.2f)" % X0},
               {"shape": "cylinder", "radius": 0.9, "height": 14.0, "offset_y": 6.4, "center": [X0, 13.4, 0.0], "note": "upper tower / mast core"}],
    nodes={"blink": ["BlinkLight"], "anchors": ["Anchor_Door", "Anchor_Top"], "meshes": ["Tower"]},
    notes="Lattice comm tower ~20.5 m (4 tapered legs, orange/white aviation bands, platform, dish pointing Blender +Y/up = Godot -Z, ladder on the back face) + equipment shed on the +X side. "
          "The plinth (10.7 x 6.8 m) is centred on the origin: the tower axis is at x=-1.95 (Godot x), the shed on the +X side. BlinkLight (red, own material *_blink) at the mast tip (y~20.2) = Anchor_Top; Anchor_Door in front of the shed door.",
    preview_kw=dict(dist_mult=1.2),
)
print(entry["size"], entry["tris"])
