import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "outpost_hab_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0

M = S.mats(ID, {
    "hull": "white",
    "hull2": dict(color=(0.36, 0.38, 0.41), metallic=0.2, roughness=0.5),
    "frame": "graphite",
    "accent": "orange",
    "base": "dconcrete",
    "window": "window_warm",
    "status": "emit_green",
})
Mblink = S.mats(ID, {"blink": "emit_red"})

b = S.MB(M)
Rd, Hs, zc = 5.0, 0.9, 0.45


def dp(theta, phi, r=Rd):
    return Vector((r * math.cos(phi) * math.cos(theta), r * math.cos(phi) * math.sin(theta), zc + r * Hs * math.sin(phi)))


def dnormal(p):
    return Vector((p.x, p.y, (p.z - zc) / (Hs * Hs))).normalized()


# ---- foundation ---------------------------------------------------------------------------------------------------
b.lathe([(0, -0.55), (5.65, -0.55), (5.65, 0.30), (5.45, 0.45), (0, 0.45)], segs=40, mat="base")
b.lathe([(5.62, 0.08), (5.72, 0.08), (5.72, 0.28), (5.62, 0.28), (5.62, 0.08)], segs=40, mat="accent")
b.lathe([(4.9, 0.4), (5.35, 0.4), (5.35, 0.6), (5.1, 0.7), (4.9, 0.7), (4.9, 0.4)], segs=40, mat="frame")

# ---- dome core + panels --------------------------------------------------------------------------------------------
core = [(0, zc)]
phis = [0, 20, 38, 55, 70, 82, 90]
prof = [(0, zc), (4.97, zc)]
for ph in phis[1:]:
    p = dp(0, ph * D2R, 4.97)
    prof.append((p.x, p.z))
prof[-1] = (0.0, prof[-1][1])
b.lathe(prof, segs=24, mat="frame")
for i in range(24):
    th0, th1 = i * 15 * D2R, (i + 1) * 15 * D2R
    thc = (i + 0.5) * 15
    for j in range(len(phis) - 2):
        ph0, ph1 = phis[j] * D2R, phis[j + 1] * D2R
        if abs(thc - 90) < 12 and j < 2:
            continue            # airlock covers this
        m = "hull" if (i + j) % 2 == 0 else "hull2"
        if j == 1 and i % 6 == 3:
            m = "accent"
        t = 0.07 if (i % 2 == 0) else 0.05
        b.panel(dp(th0, ph0), dp(th1, ph0), dp(th1, ph1), dp(th0, ph1), t=t, shrink=0.04, mat=m)
# accent ring (orange belt) low on the dome
b.lathe([(dp(0, 4 * D2R).x + 0.02, dp(0, 4 * D2R).z), (dp(0, 4 * D2R).x + 0.12, dp(0, 4 * D2R).z),
         (dp(0, 11 * D2R).x + 0.12, dp(0, 11 * D2R).z), (dp(0, 11 * D2R).x + 0.02, dp(0, 11 * D2R).z), (dp(0, 4 * D2R).x + 0.02, dp(0, 4 * D2R).z)],
        segs=48, mat="accent")
# skylight cap
ztop = zc + Rd * Hs
b.lathe([(0, ztop - 0.12), (1.05, ztop - 0.12), (1.05, ztop - 0.02), (0.95, ztop + 0.06), (0.8, ztop + 0.06), (0.8, ztop - 0.02), (0, ztop - 0.02)],
        segs=16, mat="frame")
b.lathe([(0, ztop + 0.02), (0.74, ztop + 0.02), (0.66, ztop + 0.14), (0.4, ztop + 0.22), (0, ztop + 0.25)], segs=16, mat="window")

# ---- windows ------------------------------------------------------------------------------------------------------
for k, ang in enumerate([10, 50, 130, 170, 210, 250, 290, 330]):
    th = ang * D2R
    p = dp(th, 27 * D2R, Rd)
    n = dnormal(p)
    rm = S.rot_to(n)
    b.box(p + n * 0.03, (1.25, 0.8, 0.22), rot=rm, mat="frame", bevel=0.07)
    b.box(p + n * 0.045, (1.0, 0.58, 0.25), rot=rm, mat="window", bevel=0.05)

# ---- airlock ------------------------------------------------------------------------------------------------------
ay0, ay1 = 3.85, 6.85
b.box((0, (ay0 + ay1) / 2, 0.45 + 1.45), (3.3, ay1 - ay0, 2.9), mat="hull", bevel=0.1)
b.box((0, (ay0 + ay1) / 2 + 0.05, 0.45 + 3.0), (3.55, ay1 - ay0 + 0.25, 0.22), mat="hull2", bevel=0.06)     # roof slab
b.box((0, (ay0 + ay1) / 2, 0.45 + 3.15), (2.6, ay1 - ay0 - 0.6, 0.12), mat="frame", bevel=0.03)             # roof hatch
b.vent((0.8, (ay0 + ay1) / 2, 3.69), 0.9, 0.9, n=4, rot=(math.radians(90), 0, 0), mat_slat="frame", mat_back="frame")   # roof vent (facing up)
# side panels (lines)
b.wall_panels((1.66, ay0 + 0.1, 0.55), (0, 2.75, 0), (0, 0, 2.7), 3, 2, gap=0.06, t=0.03, mats_=("hull", "hull2"), seed=3)
b.wall_panels((-1.66, ay1 - 0.1, 0.55), (0, -2.75, 0), (0, 0, 2.7), 3, 2, gap=0.06, t=0.03, mats_=("hull", "hull2"), seed=5)
# front face: door frame + leaves
fy = ay1
b.box((0, fy + 0.04, 0.45 + 1.2), (2.0, 0.14, 2.5), mat="frame", bevel=0.04)           # frame
b.box((-0.4, fy + 0.12, 0.45 + 1.1), (0.78, 0.1, 2.2), mat="hull2", bevel=0.03)         # leaf L
b.box((0.4, fy + 0.12, 0.45 + 1.1), (0.78, 0.1, 2.2), mat="hull2", bevel=0.03)          # leaf R
for sx in (-1, 1):
    b.cyl((sx * 0.4, fy + 0.19, 0.45 + 1.55), 0.15, 0.15, 0.06, segs=14, axis="Y", mat="window")
    b.box((sx * 0.4, fy + 0.19, 0.45 + 0.4), (0.5, 0.03, 0.4), mat="accent")             # kick plate stripe
b.box((0, fy + 0.2, 0.45 + 1.1), (0.04, 0.05, 2.2), mat="frame")                          # centre seam
for i in range(5):                                                                        # hazard chevron header
    b.box((-0.8 + i * 0.4, fy + 0.13, 0.45 + 2.33), (0.22, 0.04, 0.12), rot=(0, 0, 0.0), mat="accent")
b.box((0, fy + 0.22, 0.45 + 2.62), (0.7, 0.1, 0.16), mat="status", bevel=0.02)           # status light
b.box((0, fy + 0.15, 0.45 + 2.82), (1.1, 0.35, 0.1), mat="frame", bevel=0.03)             # canopy
for sx in (-1, 1):
    b.box((sx * 1.35, fy + 0.2, 0.45 + 2.35), (0.22, 0.2, 0.42), mat="frame", bevel=0.04)
    b.box((sx * 1.35, fy + 0.32, 0.45 + 2.35), (0.14, 0.05, 0.3), mat="window")             # door lamps
# keypad
b.box((1.18, fy + 0.07, 0.45 + 1.15), (0.2, 0.06, 0.3), mat="frame", bevel=0.02)
b.box((1.18, fy + 0.11, 0.45 + 1.22), (0.12, 0.02, 0.1), mat="status")
# landing and steps
b.box((0, fy + 0.65, 0.2), (3.0, 1.3, 0.5), mat="frame", bevel=0.04)        # platform (z -0.05..0.45)
b.box((0, fy + 0.65, 0.425), (2.9, 1.2, 0.05), mat="accent")
b.box((0, fy + 1.55, 0.1), (2.6, 0.7, 0.3), mat="frame", bevel=0.03)
b.box((0, fy + 1.55, 0.255), (2.5, 0.6, 0.03), mat="accent")
b.box((0, fy + 2.15, 0.0), (2.2, 0.55, 0.16), mat="frame", bevel=0.03)
for sx in (-1, 1):
    b.rail((sx * 1.45, fy + 0.15, 0.45), (sx * 1.45, fy + 1.3, 0.45), height=0.9, posts=2, mat="frame", r=0.03)
    b.rail((sx * 1.3, fy + 1.3, 0.2), (sx * 1.3, fy + 2.1, 0.0), height=0.9, posts=2, mat="frame", r=0.03)

# ---- antenna mast -------------------------------------------------------------------------------------------------
mx, my = 0.0, -1.7
mz = zc + Rd * Hs * math.sqrt(max(0.0, 1 - (my / Rd) ** 2)) - 0.1
b.cyl((mx, my, mz + 0.12), 0.55, 0.42, 0.25, segs=12, mat="frame", bevel=0.03)
b.cyl((mx, my, mz + 2.0), 0.13, 0.07, 3.8, segs=10, mat="hull2")
for z in (0.9, 1.9, 2.8):
    b.cyl((mx, my, mz + z), 0.15, 0.15, 0.1, segs=10, mat="accent" if z > 2 else "frame")
# dish
dish_n = Vector((0.7, 0.5, 0.45)).normalized()
dish_rm = S.rot_to(dish_n)
dc = Vector((mx, my, mz + 3.1)) + Vector((0.28, 0.2, 0.0))
b.lathe([(0, 0.0), (0.5, 0.18), (0.58, 0.2), (0.56, 0.22), (0.46, 0.2), (0, 0.04)][::1], segs=16, c=dc, rot=dish_rm, mat="hull")
b.cyl(dc + dish_n * 0.28, 0.025, 0.025, 0.5, segs=6, mat="frame", rot=dish_rm)
b.sphere(dc + dish_n * 0.55, 0.05, u=8, v=6, mat="frame")
# yagi cross bars + whip
b.box((mx, my, mz + 3.6), (1.1, 0.05, 0.05), mat="frame")
b.box((mx, my, mz + 3.4), (0.8, 0.05, 0.05), mat="frame")
b.cyl((mx - 0.3, my, mz + 4.4), 0.015, 0.008, 1.6, segs=5, mat="frame")
b.cyl((mx, my, mz + 4.2), 0.02, 0.01, 0.9, segs=5, mat="frame")
tipz = mz + 4.05

# ---- utility box + vents (rear-left) -----------------------------------------------------------------------------------
ua = 215 * D2R
up = Vector((6.15 * math.cos(ua), 6.15 * math.sin(ua), 0.0))
um = S.MB(M)
um.box((0, 0, 0.5), (2.6, 1.3, 1.6), mat="hull2", bevel=0.07)
um.box((0, 0, 1.38), (2.7, 1.4, 0.16), mat="frame", bevel=0.04)
um.vent((-0.55, 0.66, 0.55), 0.9, 0.8, n=6, mat_slat="frame", mat_back="frame")
um.box((0.7, 0.66, 0.65), (0.7, 0.04, 1.0), mat="hull", bevel=0.01)
um.box((0.7, 0.69, 0.65), (0.1, 0.03, 0.1), mat="status")
um.cyl((-0.9, -0.1, 1.6), 0.14, 0.14, 0.5, segs=8, mat="frame")
um.cyl((-0.9, -0.1, 1.9), 0.18, 0.18, 0.06, segs=8, mat="frame")
um.transform(S.M4(up, (0, 0, ua - 90 * D2R)))
b.append(um)
# pipes from the unit to the dome
for dz, off in ((0.6, -0.5), (0.95, 0.3)):
    p0 = up + Vector((0, 0, 0.9))
    a = 215 * D2R
    pt = Vector((4.88 * math.cos(a + off * 0.06), 4.88 * math.sin(a + off * 0.06), 0))
    p_mid = Vector((5.5 * math.cos(a + off * 0.06), 5.5 * math.sin(a + off * 0.06), 0.95 + dz))
    b.pipe([Vector((up.x + math.cos(a) * 0.2 + off * -math.sin(a) * 0.6, up.y + math.sin(a) * 0.2 + off * math.cos(a) * 0.6, 1.0)),
            Vector((p_mid.x, p_mid.y, 1.4 + dz)),
            Vector((pt.x, pt.y, 1.6 + dz))], 0.09, segs=8, mat="frame", bend=0.4)

# ---- storage tank (rear-right) ------------------------------------------------------------------------------------------
ta = 305 * D2R
tp = Vector((6.5 * math.cos(ta), 6.5 * math.sin(ta), 0))
b.lathe([(0, -0.4), (0.85, -0.4), (0.85, 1.6), (0.7, 1.95), (0.35, 2.12), (0, 2.15)], segs=16, c=tp, mat="hull")
for z in (0.2, 1.2):
    b.lathe([(0.84, z), (0.93, z), (0.93, z + 0.12), (0.84, z + 0.12), (0.84, z)], segs=16, c=tp, mat="accent")
b.cyl(tp + Vector((0, 0, 2.3)), 0.1, 0.1, 0.3, segs=8, mat="frame")
b.pipe([tp + Vector((0, 0, 2.3)), tp + Vector((0, 0, 2.75)), Vector((tp.x * 0.88, tp.y * 0.88, 2.75)), Vector((tp.x * 0.78, tp.y * 0.78, 2.2))],
       0.07, segs=8, mat="frame", bend=0.3)
b.ladder(tp + Vector((0.0, 0.0, -0.3)) + Vector((math.cos(ta + 1.0), math.sin(ta + 1.0), 0)) * 0.87,
         tp + Vector((0, 0, 1.6)) + Vector((math.cos(ta + 1.0), math.sin(ta + 1.0), 0)) * 0.87, width=0.4, mat="frame",
         out=(math.cos(ta + 1.0), math.sin(ta + 1.0), 0))

# ---- bollard lights by the stairs ------------------------------------------------------------------------------------------
for sx in (-1, 1):
    b.cyl((sx * 1.9, ay1 + 2.6, 0.3), 0.1, 0.1, 0.8, segs=8, mat="frame")
    b.cyl((sx * 1.9, ay1 + 2.6, 0.78), 0.12, 0.12, 0.16, segs=8, mat="window")
    b.cyl((sx * 1.9, ay1 + 2.6, 0.88), 0.13, 0.13, 0.05, segs=8, mat="frame")

hab = b.build(S.nm(ID, "Hab"), col, smooth=38)

# blink light
bl_mesh = S.MB(Mblink)
bl_mesh.sphere((0, 0, 0), 0.11, u=10, v=7, mat="blink")
blink = bl_mesh.build(S.nm(ID, "BlinkLight"), col, smooth=None)
blink.location = (mx - 0.3, my, mz + 5.25)
blink.name = S.nm(ID, "BlinkLight")

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (0, fy + 3.3, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (mx - 0.3, my, mz + 5.3), size=0.4)

objs = [hab, blink, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "cylinder", "radius": 5.7, "height": 5.6, "offset_y": -0.55, "center": [0, 2.25, 0]},
    colliders=[{"shape": "cylinder", "radius": 5.7, "height": 5.6, "offset_y": -0.55, "center": [0, 2.25, 0]},
               {"shape": "box", "size": [3.3, 3.5, 3.4], "offset_y": -0.05, "center": [0, 1.65, -5.35], "note": "airlock + stairs (door side = Godot -Z)"}],
    nodes={"blink": ["BlinkLight"], "anchors": ["Anchor_Door", "Anchor_Top"], "meshes": ["Hab"]},
    notes="Domed habitat d=10 m (foundation d=11.3, sinks 0.55 m below y=0). Airlock/door faces Blender +Y = Godot -Z; Anchor_Door is 3.3 m in front of the stairs. "
          "BlinkLight (red emissive sphere, own material outpost_hab_a_blink) at the antenna tip = Anchor_Top. Warm emissive windows/skylight (material *_window), green status light (*_status).",
    preview_kw=dict(dist_mult=1.35),
)
print(entry["size"], entry["tris"])
