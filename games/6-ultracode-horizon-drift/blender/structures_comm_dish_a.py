import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "comm_dish_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
TAU = math.tau
V = Vector
rnd = random.Random(77)

M = S.mats(ID, {
    "hull": "white",
    "hull2": dict(color=(0.36, 0.38, 0.41), metallic=0.25, roughness=0.5),
    "frame": "graphite",
    "steel": "steel",
    "accent": "orange",
    "base": dict(color=(0.20, 0.195, 0.18), metallic=0.0, roughness=0.92),
    "lamp": "window_warm",
})
Mblink = S.mats(ID, {"blink": "emit_red"})
RX = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))

Z_PED = 2.3        # azimuth axis origin height (top of pedestal)
Z_TRUN = 2.6       # trunnion height above the azimuth origin
ELEV = 40.0
RD, DD = 3.0, 1.0  # dish radius / depth

# =========================================================== base (static) =====================================================
b = S.MB(M)
b.box((0, 0, -0.1), (15.2, 9.8, 0.8), mat="base", bevel=0.12)
b.box((0, 0, 0.32), (14.6, 9.2, 0.06), mat="hull2", bevel=0.02)
for sy in (-1, 1):
    b.box((0, sy * 4.78, 0.15), (15.25, 0.06, 0.2), mat="accent")
# pedestal
b.lathe([(0, 0.3), (2.0, 0.3), (2.0, 0.55), (1.6, 0.8), (1.45, 2.0), (1.6, 2.15), (1.6, 2.3), (0, 2.3)], segs=20, mat="base")
b.lathe([(1.5, 1.2), (1.58, 1.2), (1.58, 1.35), (1.5, 1.35), (1.5, 1.2)], segs=20, mat="accent")
for k in range(12):
    a = TAU * k / 12
    b.cyl((1.8 * math.cos(a), 1.8 * math.sin(a), 0.6), 0.07, 0.07, 0.14, segs=6, mat="steel")
b.box((0, 1.52, 1.15), (0.9, 0.12, 1.5), mat="frame", bevel=0.04)             # service door
b.box((0, 1.6, 1.1), (0.76, 0.08, 1.3), mat="hull2", bevel=0.03)
b.box((0.2, 1.67, 1.1), (0.06, 0.05, 0.25), mat="steel")
b.box((0, 1.6, 1.95), (0.5, 0.05, 0.08), mat="lamp")
# slew ring on top
b.lathe([(0, 2.3), (1.62, 2.3), (1.62, 2.38), (0, 2.38)], segs=24, mat="steel")
# --- hut -----------------------------------------------------------------------------------------------------------------------------
hx, hy = -5.2, 0.4
b.box((hx, hy, 0.33 + 1.35), (3.6, 2.8, 2.7), mat="hull", bevel=0.08)
b.box((hx, hy, 0.33 + 2.75), (3.9, 3.1, 0.2), mat="hull2", bevel=0.05)
b.box((hx, hy, 0.33 + 2.9), (3.0, 2.2, 0.1), mat="frame", bevel=0.02)
yf = hy + 1.4
b.box((hx - 0.9, yf + 0.04, 0.33 + 1.1), (1.25, 0.14, 2.2), mat="frame", bevel=0.04)
b.box((hx - 0.9, yf + 0.12, 0.33 + 1.0), (1.05, 0.1, 2.0), mat="hull2", bevel=0.03)
b.cyl((hx - 0.9, yf + 0.18, 0.33 + 1.55), 0.13, 0.13, 0.05, segs=12, axis="Y", mat="lamp")
b.box((hx - 0.55, yf + 0.18, 0.33 + 1.0), (0.06, 0.06, 0.3), mat="steel")
b.box((hx - 0.9, yf + 0.2, 0.33 + 2.38), (0.6, 0.06, 0.12), mat="lamp")
b.box((hx - 0.9, yf + 0.55, 0.38), (1.6, 0.9, 0.12), mat="frame", bevel=0.03)
for sx in (0.7, 1.35):
    b.box((hx + sx, yf + 0.05, 0.33 + 1.5), (0.5, 0.1, 0.7), mat="frame", bevel=0.04)
    b.box((hx + sx, yf + 0.1, 0.33 + 1.5), (0.4, 0.06, 0.58), mat="lamp", bevel=0.03)
b.box((hx + 0.95, yf + 0.04, 0.33 + 0.4), (1.5, 0.08, 0.14), mat="accent")
# side vent + AC unit
b.vent((hx + 1.81, hy, 0.33 + 1.1), 0.9, 0.8, n=6, rot=(0, 0, math.radians(90)), mat_slat="frame", mat_back="frame")
b.box((hx + 0.6, hy - 0.2, 0.33 + 3.15), (1.0, 0.9, 0.5), mat="hull2", bevel=0.04)
b.cyl((hx + 0.6, hy - 0.2, 0.33 + 3.43), 0.36, 0.36, 0.05, segs=14, mat="frame")
# roof mast
b.cyl((hx - 1.2, hy - 0.6, 0.33 + 4.6), 0.07, 0.05, 3.2, segs=8, mat="hull2")
for z in (3.4, 4.1, 4.8):
    b.box((hx - 1.2, hy - 0.6, 0.33 + z), (0.9 - (z - 3.4) * 0.25, 0.04, 0.04), mat="frame")
b.cyl((hx - 1.2, hy - 0.6, 0.33 + 6.35), 0.015, 0.01, 1.2, segs=5, mat="frame")
# --- generator / equipment on the +X side ---------------------------------------------------------------------------------------------
gx, gy = 5.4, 1.4
b.box((gx, gy, 0.33 + 0.8), (2.6, 1.5, 1.6), mat="hull2", bevel=0.06)
b.box((gx, gy, 0.33 + 1.65), (2.7, 1.6, 0.12), mat="frame", bevel=0.03)
b.vent((gx - 0.5, gy + 0.76, 0.33 + 0.9), 1.1, 0.9, n=7, mat_slat="frame", mat_back="frame")
b.box((gx + 0.75, gy + 0.76, 0.33 + 0.9), (0.6, 0.03, 1.0), mat="hull", bevel=0.01)
b.box((gx, gy + 0.76, 0.33 + 0.3), (2.4, 0.03, 0.1), mat="accent")
b.cyl((gx + 0.9, gy - 0.4, 0.33 + 2.5), 0.12, 0.09, 1.7, segs=8, mat="frame")
b.cyl((gx + 0.9, gy - 0.4, 0.33 + 3.4), 0.16, 0.16, 0.06, segs=8, mat="steel")
# cable trays to the pedestal
for yy, w in ((0.3, 0.07), (-0.1, 0.06)):
    b.pipe([V((hx + 1.9, yy, 0.35)), V((-2.4, yy, 0.38)), V((-1.7, yy, 0.38)), V((-1.5, yy, 0.8))], w, segs=6, mat="frame", bend=0.4)
    b.pipe([V((gx - 1.3, yy + 0.4, 0.4)), V((2.6, yy + 0.4, 0.38)), V((1.7, yy + 0.4, 0.38)), V((1.5, yy + 0.4, 0.8))], w, segs=6, mat="frame", bend=0.4)
for x in (-3.4, -2.8, 2.2, 3.0):
    b.box((x, 0.2, 0.4), (0.5, 0.4, 0.1), mat="hull2", bevel=0.02)
# corner floodlight poles
for (x, y, s) in ((-7.0, -4.2, 1), (7.0, -4.2, -1), (7.0, 4.2, -1)):
    b.cyl((x, y, 2.2), 0.09, 0.07, 4.0, segs=8, mat="hull2")
    b.cyl((x, y, 0.5), 0.2, 0.2, 0.4, segs=8, mat="frame")
    b.box((x - s * 0.2, y, 4.2), (0.6, 0.3, 0.2), rot=(0, 0.3 * s, 0), mat="frame", bevel=0.02)
    b.box((x - s * 0.22, y + 0.08, 4.15), (0.5, 0.05, 0.14), rot=(0, 0.3 * s, 0), mat="lamp")
# warning bollards
for k in range(4):
    b.cyl((-1.2 + k * 0.8, 4.3, 0.7), 0.06, 0.06, 0.7, segs=6, mat="frame")
    b.cyl((-1.2 + k * 0.8, 4.3, 1.06), 0.075, 0.075, 0.1, segs=6, mat="accent")
base = b.build(S.nm(ID, "Base"), col, smooth=40)

# =========================================================== azimuth head (turntable + yoke) ======================================
az = S.MB(M)
az.lathe([(0, 0.0), (1.55, 0.0), (1.55, 0.18), (1.3, 0.3), (0, 0.3)], segs=24, mat="hull2")
az.lathe([(1.45, 0.17), (1.58, 0.17), (1.58, 0.28), (1.45, 0.28), (1.45, 0.17)], segs=24, mat="accent")
for sx in (-1, 1):
    x = sx * 1.75
    az.box((x, 0, 1.35), (0.4, 1.1, 2.1), mat="hull", bevel=0.07, top=(0.9, 0.85))
    az.box((x, 0, 0.4), (0.5, 1.5, 0.35), mat="hull2", bevel=0.05)
    az.cyl((x, 0, Z_TRUN), 0.35, 0.35, 0.55, segs=16, axis="X", mat="steel")
    az.cyl((x + sx * 0.28, 0, Z_TRUN), 0.18, 0.18, 0.1, segs=12, axis="X", mat="frame")
    az.box((x + sx * 0.0, 0.55, 0.9), (0.35, 0.08, 0.8), mat="hull2", bevel=0.02)
az.box((0, 0, 0.75), (3.1, 0.5, 0.35), mat="hull2", bevel=0.05)
az_ob = az.build(S.nm(ID, "Dish_Az"), col, smooth=40)
az_ob.location = (0, 0, Z_PED)
S.parent_to(az_ob, base)

# =========================================================== dish (elevation group) ================================================
dm = S.MB(M)
vy = 0.45                        # dish vertex (y), opening towards +Y (the trunnion shaft at y=0 stays behind the dish)
dm.dish(V((0, vy, 0)), V((0, 1, 0)), RD, DD, mat="hull", th=0.07, segs=32, n=8)
# rim stripe
dm.lathe([(RD - 0.01, DD - 0.03), (RD + 0.05, DD - 0.03), (RD + 0.05, DD + 0.1), (RD - 0.01, DD + 0.1), (RD - 0.01, DD - 0.03)], segs=32, c=V((0, vy, 0)), rot=S.rot_to(V((0, 1, 0))), mat="accent")
dm.lathe([(RD - 0.2, DD - 0.05), (RD - 0.01, DD - 0.05), (RD - 0.01, DD + 0.1), (RD - 0.2, DD + 0.1), (RD - 0.2, DD - 0.05)], segs=32, c=V((0, vy, 0)), rot=S.rot_to(V((0, 1, 0))), mat="steel") if False else None
# hub + back structure
dm.cyl((0, vy - 0.35, 0), 0.65, 0.5, 0.8, segs=16, axis="Y", mat="steel")
dm.cyl((0, vy - 0.75, 0), 0.4, 0.4, 0.15, segs=16, axis="Y", mat="frame")
for k in range(8):
    a = TAU * k / 8 + 0.2
    chain = []
    for q in range(6):
        r_ = 0.5 + (RD * 0.93 - 0.5) * q / 5
        chain.append(V((r_ * math.cos(a), vy + DD * (r_ / RD) ** 2 - 0.15, r_ * math.sin(a))))
    for q in range(5):
        dm.strut(chain[q], chain[q + 1], 0.07 - 0.008 * q, 0.07 - 0.008 * (q + 1), segs=6, mat="steel")
for rr in (1.0, 1.9, 2.7):
    zz = vy + DD * (rr / RD) ** 2 - 0.1
    dm.lathe([(rr - 0.06, -0.06), (rr + 0.06, -0.06), (rr + 0.06, 0.06), (rr - 0.06, 0.06), (rr - 0.06, -0.06)], segs=24, c=V((0, zz, 0)), rot=S.rot_to(V((0, 1, 0))), mat="steel")
# trunnion shafts + counterweight
dm.cyl((0, 0, 0), 0.22, 0.22, 3.55, segs=12, axis="X", mat="steel")
dm.box((0, vy - 1.05, 0), (1.4, 0.55, 1.0), mat="hull2", bevel=0.06)
dm.box((0, vy - 1.05, 0.55), (1.0, 0.35, 0.15), mat="accent")
# quad-pod feed
f_y = vy + 2.15
for k in range(4):
    a = TAU * k / 4 + math.pi / 4
    rim = V((RD * 0.9 * math.cos(a), vy + DD * 0.81, RD * 0.9 * math.sin(a)))
    dm.strut(rim, V((0.12 * math.cos(a), f_y - 0.15, 0.12 * math.sin(a))), 0.04, 0.035, segs=6, mat="frame")
dm.cyl((0, f_y - 0.1, 0), 0.2, 0.12, 0.35, segs=12, axis="Y", mat="frame")
dm.cyl((0, f_y + 0.12, 0), 0.12, 0.12, 0.12, segs=12, axis="Y", mat="steel")
dm.sphere((0, f_y + 0.22, 0), 0.1, u=10, v=6, mat="accent")
el_ob = dm.build(S.nm(ID, "Dish_El"), col, smooth=40)
el_ob.location = (0, 0, Z_TRUN)
el_ob.rotation_euler = (ELEV * D2R, 0, 0)
S.parent_to(el_ob, az_ob)

bl = S.MB(Mblink)
bl.sphere((0, 0, 0), 0.1, u=10, v=7, mat="blink")
blink = bl.build(S.nm(ID, "BlinkLight"), col, smooth=None)
blink.location = (-5.2 - 1.2, 0.4 - 0.6, 0.33 + 7.0)
S.parent_to(blink, base)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (-6.1, 0.4 + 1.4 + 1.9, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (0, 0, 7.7), size=0.4)
objs = [base, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [15.2, 1.1, 9.8], "offset_y": -0.5, "center": [0, 0.05, 0]},
    colliders=[{"shape": "cylinder", "radius": 2.0, "height": 2.4, "offset_y": 0.3, "center": [0, 1.5, 0], "note": "pedestal"},
               {"shape": "box", "size": [3.6, 2.7, 2.8], "offset_y": 0.33, "center": [-5.2, 1.7, -0.4], "note": "hut"},
               {"shape": "box", "size": [2.6, 1.6, 1.5], "offset_y": 0.33, "center": [5.4, 1.1, -1.4], "note": "generator"}],
    nodes={"dish_az": ["Dish_Az"], "dish_el": ["Dish_El"], "blink": ["BlinkLight"], "meshes": ["Base"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Ground antenna station: 6 m dish on a pedestal + control hut (-X side) + generator (+X). Hierarchy Base > Dish_Az > Dish_El. `Dish_Az` origin = top of the pedestal: rotate about local Y (Godot) = azimuth. "
          "`Dish_El` (child of Dish_Az) origin = the trunnion axis: rotate about local X for elevation; exported rest pose = elevation +40 deg (rotation.x = +40 deg, dish opens toward Blender +Y = Godot -Z). "
          "BlinkLight (red emissive, own material *_blink) on the hut mast. Anchor_Door in front of the hut door. Slab sinks to y=-0.5.",
    preview_kw=dict(dist_mult=1.45),
)
print(entry["size"], entry["tris"])
