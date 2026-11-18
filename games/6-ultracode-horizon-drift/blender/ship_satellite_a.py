"""satellite_a -- small comms satellite ~6.6 m span.  Blender: +Y front (dish points +Y/+Z), Z up, origin = bus centre.
Nodes: Satellite > Body (bus, dish, antennas), SolarPanels, BlinkLight.
"""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy, bmesh
from mathutils import Vector, Matrix
import lib_common as L
import ship_lib as S
importlib.reload(L)
importlib.reload(S)
V = Vector
TAU = math.tau
MID = "satellite_a"
PFX = MID + "__"
rng = random.Random(5)
DO_EXPORT = True
DO_PREVIEW = False


def W(x, y, z):
    return Vector((x, y, z))


M = {}
M["gold"] = L.mat(MID + "_foil", (0.85, 0.58, 0.12), metallic=0.75, roughness=0.32)
M["hull"] = L.mat(MID + "_hull", (0.70, 0.72, 0.76), metallic=0.35, roughness=0.45)
M["dark"] = L.mat(MID + "_dark", (0.04, 0.045, 0.055), metallic=0.5, roughness=0.5)
M["trim"] = L.mat(MID + "_trim", (0.36, 0.38, 0.43), metallic=0.65, roughness=0.4)
M["accent"] = L.mat(MID + "_accent", (0.9, 0.25, 0.04), metallic=0.1, roughness=0.45)
M["glow"] = L.mat(MID + "_glow", (0.1, 0.7, 1.0), emission=(0.08, 0.75, 1.0), emission_strength=4.0)
M["solar"] = L.mat(MID + "_solar", (0.03, 0.08, 0.30), metallic=0.8, roughness=0.25)
M["blink"] = L.mat(MID + "_blink", (1.0, 0.1, 0.05), emission=(1.0, 0.12, 0.05), emission_strength=8.0)
GOLD, HULL, DARK, TRIM, ACC, GLOW = 0, 1, 2, 3, 4, 5
MATS = [M["gold"], M["hull"], M["dark"], M["trim"], M["accent"], M["glow"]]

col = L.fresh_collection(MID)
for o in list(bpy.data.objects):
    if o.name.startswith(PFX):
        bpy.data.objects.remove(o, do_unlink=True)
S.begin(col)
root = L.empty(PFX + "Satellite", col, (0, 0, 0), display="PLAIN_AXES", size=1.0)

# bus: rounded square prism along Y, gold foil with grey end plates
bus = bmesh.new()
KEYS = [(-1.0, 0.74, 0.74, 0.0, -0.74, 6.0, 6.0), (1.0, 0.74, 0.74, 0.0, -0.74, 6.0, 6.0)]
ys = [-1.0, -0.96, -0.9, -0.5, 0.0, 0.5, 0.9, 0.96, 1.0]
# shrink the end rings a little to bevel the ends
Gb, Fb = S.loft_sections(bus, KEYS, ys, nseg=24, mat=GOLD)
for v in bus.verts:
    if abs(abs(v.co.y) - 1.0) < 1e-3:
        v.co.x *= 0.9
        v.co.z *= 0.9
    elif abs(abs(v.co.y) - 0.96) < 1e-3:
        v.co.x *= 0.985
        v.co.z *= 0.985
for key, f in Fb.items():
    if key in ("cap0", "cap1"):
        f.material_index = HULL
bmesh.ops.recalc_face_normals(bus, faces=bus.faces)
parts = [bus]
# radiator panels (side), hatch plates, bands
for sgn in (-1, 1):
    parts.append(S.box((sgn * 0.745, 0.15, 0.0), (0.04, 1.1, 1.0), DARK))
    parts.append(S.box((sgn * 0.765, 0.15, 0.0), (0.02, 1.0, 0.9), HULL))
    for k in range(6):
        parts.append(S.box((sgn * 0.77, 0.15, -0.38 + k * 0.15), (0.02, 0.96, 0.03), TRIM))
for y in (-0.55, 0.55):
    parts.append(S.box((0, y, 0.0), (1.56, 0.06, 1.56), TRIM))
# thrusters (rear corners) and front sensors
for sx in (-1, 1):
    for sz in (-1, 1):
        parts.append(S.cyl(W(sx * 0.6, -0.98, sz * 0.6), W(sx * 0.6, -1.25, sz * 0.6), 0.12, 0.07, segs=8, mat=DARK))
        parts.append(S.cyl(W(sx * 0.6, -0.96, sz * 0.6), W(sx * 0.6, -1.0, sz * 0.6), 0.14, 0.14, segs=8, mat=TRIM))
parts.append(S.cyl(W(-0.4, 0.98, -0.35), W(-0.4, 1.45, -0.35), 0.17, 0.17, segs=10, mat=DARK))
parts.append(S.cyl(W(0.4, 0.98, -0.35), W(0.4, 1.35, -0.35), 0.13, 0.13, segs=10, mat=DARK))
parts.append(S.cyl(W(-0.4, 1.45, -0.35), W(-0.4, 1.5, -0.35), 0.15, 0.15, segs=10, mat=GLOW))
# dish on an arm
dc = W(0.0, 0.55, 1.45)
axis = V((0, 1.0, 0.45)).normalized()
parts.append(S.cyl(W(0, 0.5, 0.74), W(0, 0.5, 1.30), 0.1, 0.08, segs=8, mat=TRIM))
parts.append(S.cyl(W(0, 0.5, 1.26), dc + axis * 0.0, 0.14, 0.14, segs=10, mat=TRIM))
parts.append(S.dish(dc, axis, 1.05, 0.34, segs=24, rings=4, mat=HULL))
parts.append(S.cyl(dc, dc + axis * 0.7, 0.03, 0.03, segs=5, mat=DARK))
for k in range(3):
    a = TAU * k / 3
    ref = V((1, 0, 0))
    u_ = axis.cross(ref).normalized()
    w_ = axis.cross(u_).normalized()
    parts.append(S.cyl(dc + axis * 0.32 + (u_ * math.cos(a) + w_ * math.sin(a)) * 0.95, dc + axis * 0.7, 0.012, 0.012, segs=4, mat=DARK))
parts.append(S.cyl(dc + axis * 0.7, dc + axis * 0.85, 0.07, 0.11, segs=8, mat=ACC))
# antennas / mast
parts.append(S.cyl(W(-0.5, -0.3, 0.74), W(-0.5, -0.3, 1.9), 0.02, 0.01, segs=5, mat=DARK))
parts.append(S.cyl(W(0.45, -0.55, 0.74), W(0.45, -0.55, 1.5), 0.02, 0.01, segs=5, mat=DARK))
parts.append(S.cyl(W(0.0, -0.5, 0.74), W(0.0, -0.5, 1.3), 0.035, 0.02, segs=6, mat=TRIM))
parts.append(S.cyl(W(0.0, -0.5, 1.28), W(0.0, -0.5, 1.4), 0.06, 0.04, segs=6, mat=ACC))
# solar array hinges
for sgn in (-1, 1):
    parts.append(S.cyl(W(sgn * 0.74, -0.1, 0), W(sgn * 3.35, -0.1, 0), 0.05, 0.05, segs=6, mat=TRIM))
    parts.append(S.box((sgn * 0.9, -0.1, 0), (0.3, 0.3, 0.25), TRIM))
body = L.bm_merge(*parts)
ob_body = S.finish("Body", body, col, MATS, parent=root, prefix=PFX, smooth_deg=40)

# solar arrays
sol = bmesh.new()
SM = [M["solar"], M["trim"], M["dark"]]
parts = []
for sgn in (-1, 1):
    for k in range(3):
        x0 = 1.05 + k * 0.80
        xc = sgn * (x0 + 0.36)
        parts.append(S.box((xc, -0.1, 0.0), (0.72, 1.7, 0.05), 0))
        parts.append(S.box((xc, -0.1, 0.0), (0.77, 1.76, 0.035), 1))
        for j in range(1, 4):
            parts.append(S.box((xc - 0.36 + j * 0.18, -0.1, 0.031), (0.012, 1.66, 0.006), 2))
            parts.append(S.box((xc - 0.36 + j * 0.18, -0.1, -0.031), (0.012, 1.66, 0.006), 2))
        for j in range(1, 6):
            parts.append(S.box((xc, -0.1 - 0.85 + j * 1.7 / 6.0, 0.031), (0.7, 0.012, 0.006), 2))
            parts.append(S.box((xc, -0.1 - 0.85 + j * 1.7 / 6.0, -0.031), (0.7, 0.012, 0.006), 2))
    parts.append(S.box((sgn * 3.45, -0.1, 0), (0.1, 1.82, 0.12), 1))
sol = L.bm_merge(*parts)
ob_sol = S.finish("SolarPanels", sol, col, SM, parent=root, prefix=PFX, flat=True)

bl = S.uvsphere((0.0, -0.5, 1.46), 0.11, u=10, v=6, mat=0)
S.finish("BlinkLight", bl, col, [M["blink"]], origin=(0.0, -0.5, 1.46), parent=root, prefix=PFX, flat=False, smooth_deg=80)

bpy.context.view_layer.update()
S.tri_report(root, MID)
if DO_EXPORT:
    path, names = S.export_named([root], MID, PFX)
    print("EXPORTED", path)
    print(names)
L.save_blend()
S.end(col)
