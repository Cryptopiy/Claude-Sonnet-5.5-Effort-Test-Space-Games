import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "solar_array_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
V = Vector
rnd = random.Random(33)

M = S.mats(ID, {
    "hull": "white",
    "hull2": dict(color=(0.36, 0.38, 0.41), metallic=0.25, roughness=0.5),
    "frame": "graphite",
    "steel": "steel",
    "accent": "orange",
    "base": "dconcrete",
    "solar": dict(color=(0.015, 0.05, 0.20), metallic=0.75, roughness=0.15),
    "lamp": "window_warm",
})
Mstat = S.mats(ID, {"status": "emit_green"})

TILT = -30.0 * D2R
PW, PH = 3.5, 2.3              # panel width (x) and slope length (y)
POST_H = 1.75
RowsY = (2.7, -2.7)
ColsX = (-4.3, 0.0, 4.3)

# ---- panel mesh (local: hinge at origin, panel plane at +0.26 above it, normal +Z, front edge at +Y) ---------------------------------
pm = S.MB(M)
zp = 0.26
pm.box((0, 0, zp), (PW, PH, 0.07), mat="frame", bevel=0.02)                          # carrier
pm.box((0, 0, zp + 0.045), (PW - 0.12, PH - 0.12, 0.03), mat="solar", bevel=0.005)  # cells
for i in range(1, 8):                                                                  # cell grid lines (busbars)
    pm.box((-PW / 2 + 0.06 + i * (PW - 0.12) / 8, 0, zp + 0.062), (0.012, PH - 0.12, 0.004), mat="steel")
for j in range(1, 5):
    pm.box((0, -PH / 2 + 0.06 + j * (PH - 0.12) / 5, zp + 0.062), (PW - 0.12, 0.012, 0.004), mat="steel")
# frame rim
pm.box((0, PH / 2 - 0.03, zp + 0.05), (PW, 0.08, 0.06), mat="steel", bevel=0.015)
pm.box((0, -PH / 2 + 0.03, zp + 0.05), (PW, 0.08, 0.06), mat="steel", bevel=0.015)
for sx in (-1, 1):
    pm.box((sx * (PW / 2 - 0.03), 0, zp + 0.05), (0.08, PH, 0.06), mat="steel", bevel=0.015)
# back structure
pm.cyl((0, 0, 0.0), 0.075, 0.075, PW + 0.2, segs=10, axis="X", mat="steel")                # torque tube
for sx in (-1.2, 0, 1.2):
    pm.box((sx, 0, zp - 0.1), (0.09, PH - 0.3, 0.1), mat="hull2", bevel=0.01)
    pm.strut(V((sx, 0, 0.0)), V((sx, PH / 2 - 0.25, zp - 0.05)), 0.03, 0.03, segs=5, mat="steel")
    pm.strut(V((sx, 0, 0.0)), V((sx, -PH / 2 + 0.25, zp - 0.05)), 0.03, 0.03, segs=5, mat="steel")
pm.box((0, PH / 2 - 0.08, zp - 0.05), (PW - 0.2, 0.06, 0.07), mat="hull2")
pm.box((0, -PH / 2 + 0.08, zp - 0.05), (PW - 0.2, 0.06, 0.07), mat="hull2")
# accent corner marker
pm.box((-PW / 2 + 0.2, PH / 2 - 0.16, zp + 0.075), (0.28, 0.12, 0.012), mat="accent")
panel_proto = pm.build(S.nm(ID, "__panel_proto"), col, smooth=40)
panel_mesh = panel_proto.data
bpy.data.objects.remove(panel_proto)

# ---- static array: footings, posts, hubs, cables -----------------------------------------------------------------------------------
b = S.MB(M)
hubs = []
for ry in RowsY:
    for cx in ColsX:
        b.box((cx, ry, 0.0), (1.5, 1.5, 0.5), mat="base", bevel=0.08, top=(0.9, 0.9))
        b.cyl((cx, ry, 0.35), 0.38, 0.32, 0.1, segs=12, mat="frame")
        b.cyl((cx, ry, 0.35 + POST_H / 2), 0.15, 0.13, POST_H, segs=12, mat="hull2")
        b.cyl((cx, ry, 0.8), 0.17, 0.17, 0.12, segs=12, mat="accent")
        b.box((cx, ry, 0.35 + POST_H - 0.05), (0.62, 0.4, 0.26), mat="frame", bevel=0.04)     # hub housing
        b.cyl((cx - 0.38, ry, 0.35 + POST_H + 0.0), 0.12, 0.12, 0.12, segs=10, axis="X", mat="steel")
        b.cyl((cx + 0.38, ry, 0.35 + POST_H + 0.0), 0.12, 0.12, 0.12, segs=10, axis="X", mat="steel")
        # junction box on the post
        b.box((cx + 0.22, ry, 0.95), (0.18, 0.24, 0.3), mat="frame", bevel=0.02)
        hubs.append((cx, ry, 0.35 + POST_H))
# cable runs along the ground (to the cabinet)
for ry in RowsY:
    path = [V((ColsX[0] - 0.4, ry, 0.15)), V((-6.5, ry, 0.12)), V((-6.5, 0.0, 0.12)), V((-7.2, 0.0, 0.12))]
    b.pipe([V((ColsX[2], ry + 0.5, 0.2))] + [V((ColsX[1], ry + 0.9, 0.1))] + [V((ColsX[0], ry + 0.9, 0.1))] + [V((-6.4, ry + 0.9, 0.1)), V((-6.4, 0.5, 0.1)), V((-7.0, 0.5, 0.1))],
           0.045, segs=6, mat="frame", bend=0.4)
    b.pipe([V((ColsX[2], ry + 0.65, 0.2)), V((ColsX[1], ry + 1.05, 0.1)), V((ColsX[0], ry + 1.05, 0.1)), V((-6.2, ry + 1.05, 0.1)), V((-6.2, 0.3, 0.1)), V((-7.0, 0.3, 0.1))],
           0.04, segs=6, mat="frame", bend=0.4)
    for cx in ColsX:
        b.box((cx, ry + 0.8, 0.07), (0.34, 0.3, 0.12), mat="hull2", bevel=0.02)
# ---- equipment cluster -------------------------------------------------------------------------------------------------------------------
b.box((-8.5, 0.0, -0.05), (4.4, 4.2, 0.3), mat="base", bevel=0.08)
# inverter cabinet
b.box((-8.6, -0.8, 1.15), (1.7, 1.1, 2.1), mat="hull", bevel=0.06)
b.box((-8.6, -0.8, 2.25), (1.9, 1.3, 0.14), mat="hull2", bevel=0.04)
b.box((-8.6, -0.22, 1.2), (1.4, 0.04, 1.8), mat="hull2", bevel=0.02)
b.vent((-8.15, -0.22, 0.65), 0.7, 0.7, n=6, mat_slat="frame", mat_back="frame")
b.box((-8.9, -0.21, 1.6), (0.35, 0.03, 0.22), mat="frame")
b.box((-8.6, -0.21, 2.0), (1.4, 0.03, 0.08), mat="accent")
b.cyl((-8.9, -0.18, 1.4), 0.06, 0.06, 0.03, segs=8, axis="Y", mat="lamp")
# battery containers
for k, bx in enumerate((-9.6, -7.5)):
    b.box((bx, 1.3, 0.8), (1.8, 1.0, 1.4), mat="hull2", bevel=0.05)
    b.box((bx, 1.3, 1.52), (1.9, 1.1, 0.1), mat="frame", bevel=0.03)
    b.box((bx, 0.78, 0.8), (1.5, 0.04, 1.1), mat="hull", bevel=0.01)
    for i in range(5):
        b.box((bx - 0.6 + i * 0.3, 0.77, 1.1), (0.14, 0.03, 0.14), mat="frame")
    b.box((bx, 0.76, 0.35), (1.5, 0.03, 0.08), mat="accent")
# transformer / meter post and light mast
b.cyl((-6.6, -1.9, 1.3), 0.08, 0.06, 2.6, segs=8, mat="frame")
b.box((-6.6, -1.9, 2.55), (0.5, 0.2, 0.14), mat="frame", bevel=0.02)
b.box((-6.6, -1.78, 2.54), (0.38, 0.04, 0.08), mat="lamp")
# border marker posts with amber lamps
for (x, y) in ((-6.2, 5.6), (6.4, 5.6), (6.4, -5.6), (-6.2, -5.6)):
    b.cyl((x, y, 0.45), 0.09, 0.09, 0.9, segs=8, mat="frame")
    b.cyl((x, y, 0.95), 0.12, 0.12, 0.14, segs=8, mat="accent")
    b.sphere((x, y, 1.08), 0.07, u=8, v=6, mat="lamp")
# walkway slabs between the rows
for i in range(7):
    b.box((-5.4 + i * 1.8, 0.0, 0.04), (1.3, 1.0, 0.08), mat="base", bevel=0.03)

array = b.build(S.nm(ID, "Array"), col, smooth=40)
X0 = 1.5                                   # centre the footprint on the origin
array.location = (X0, 0, 0)

panels = []
for k, (cx, ry, hz) in enumerate(hubs):
    o = bpy.data.objects.new(S.nm(ID, "Panel_%d" % k), panel_mesh)
    col.objects.link(o)
    o.location = (cx, ry, hz)
    o.rotation_euler = (TILT, 0, 0)
    S.parent_to(o, array)
    panels.append(o)

sl = S.MB(Mstat)
sl.box((0, 0, 0), (0.2, 0.04, 0.1), mat="status", bevel=0.01)
status = sl.build(S.nm(ID, "StatusLight"), col, smooth=None)
status.location = (-8.2, -0.2, 1.85)
S.parent_to(status, array)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (X0 - 8.6, 1.6, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (X0, 0, 3.5), size=0.4)
objs = [array, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [17.3, 3.0, 11.5], "offset_y": 0.0, "center": [0, 1.5, 0]},
    colliders=[{"shape": "box", "size": [4.4, 2.6, 4.2], "offset_y": 0.0, "center": [-8.5 + X0, 1.3, 0.0], "note": "equipment cluster"}] +
              [{"shape": "cylinder", "radius": 0.5, "height": 2.2, "offset_y": 0.0, "center": [cx + X0, 1.1, -ry], "note": "post %d" % k} for k, (cx, ry, hz) in enumerate(hubs)],
    nodes={"panels": ["Panel_%d" % k for k in range(len(panels))], "lights": ["StatusLight"], "meshes": ["Array"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Solar field: 2 rows x 3 tracking panels (Panel_0..5, children of Array, shared mesh) + inverter/battery cluster on the -X side. Panels face Blender +Y (Godot -Z), tilted 30 deg; "
          "each Panel_i origin = its hinge (post top); rest pose = rotation_degrees.x -30 deg (as exported); to track the sun rotate it about local X. StatusLight (green emissive, own material *_status). "
          "Anchor_Door in front of the inverter cabinet.",
    preview_kw=dict(dist_mult=1.4),
)
print(entry["size"], entry["tris"])
