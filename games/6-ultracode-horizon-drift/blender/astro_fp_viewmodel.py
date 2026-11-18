"""astro_fp_viewmodel.py - first-person view model: both gloved forearms holding the multitool.
Camera at the origin looking along Blender +Y (up = +Z).  Objects: FP_Arms (both sleeves + gloves), FP_Tool (origin = grip, with child Muzzle).
Run:  python tools/bmcp.py file blender/astro_fp_viewmodel.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
import astro_parts as P; importlib.reload(P)
from astro_lib import *
import math
from math import radians

M = A.Model("fp_viewmodel")
mats = P.tool_materials(M)
glove_m = M.m("glove", (0.14, 0.15, 0.18), metallic=0.1, roughness=0.6)
BODY, DARK, ACC, GLOW, GLOVE = 0, 1, 2, 3, 4
arm_mats = mats + [glove_m]

# ---- tool placement -------------------------------------------------------------------------------------------
K = 1.2                          # viewmodel is built at 1.0 then scaled up K about the camera (FPS viewmodels are oversized)
G = V((0.19, 0.42, -0.15))       # grip position BEFORE the K scale
YAW, PITCH = radians(10.0), radians(3.5)
R = Euler((PITCH, 0, YAW), 'XYZ').to_matrix()


def T(p):
    """tool-local point -> camera/world point"""
    return G + R @ V(p)


def Td(d):
    return R @ V(d)


def yc(z):
    """grip centre-line y at height z (tool-local)"""
    pts = [(0.03, 0.012), (-0.04, 0.0), (-0.115, -0.025)]
    if z >= pts[0][0]:
        return pts[0][1]
    if z <= pts[-1][0]:
        return pts[-1][1]
    for (z0, y0), (z1, y1) in zip(pts, pts[1:]):
        if z1 <= z <= z0:
            return y1 + (y0 - y1) * (z - z1) / (z0 - z1)


# ---- tool ------------------------------------------------------------------------------------------------------
tool_bm, muz = P.build_multitool(1.0)
xform(tool_bm, Matrix.Scale(K, 4))
tool = M.add("FP_Tool", tool_bm, mats, (0, 0, 0), smooth_deg=40)
tool.location = G * K
tool.rotation_euler = (PITCH, 0, YAW)
M.pivot["FP_Tool"] = G * K
M.empty("Muzzle", G * K + muz * K, parent="FP_Tool", size=0.03)


# ---- arms ------------------------------------------------------------------------------------------------------
def sleeve(path, radii, segs=12):
    bm = tube(path, radii, segs=segs, mat=BODY, up=(0, 0, 1))
    return bm


def finger(pts, r0, r1, segs=6):
    n = len(pts)
    rad = [r0 + (r1 - r0) * i / (n - 1) for i in range(n)]
    return tube(pts, rad, segs=segs, round_end=1, mat=GLOVE)


def cuff_rings(wrist, dirv, r):
    d = Vector(dirv).normalized()
    out = [tube([wrist - d * 0.012, wrist + d * 0.012], [r * 1.05] * 2, segs=14, mat=GLOVE),
           tube([wrist - d * 0.05, wrist - d * 0.034], [r * 1.09] * 2, segs=14, mat=ACC)]
    return out


parts = []

# ===== right arm + hand (holds the grip) =====
Wr = T((0.022, -0.10, -0.05))
dir_r = V((0.50, -0.62, -0.62)).normalized()
Er = Wr + dir_r * 0.32
Far = Er + V((0.35, -0.6, -0.7)).normalized() * 0.18
parts.append(sleeve([Wr + dir_r * 0.02, Wr + dir_r * 0.15, Er, Far], [0.05, 0.058, 0.07, 0.078]))
parts += cuff_rings(Wr, -dir_r, 0.052)
# forearm guard plate (orange) on the outer top of the sleeve
sd = dir_r.cross(V((0, 0, 1))).normalized()
ud = sd.cross(dir_r).normalized()
parts.append(rbox((0, 0, 0), (0.07, 0.2, 0.014), r=0.005, segs=1, matrix=basis(Wr + dir_r * 0.2 + ud * 0.057, -dir_r), mat=ACC))
# wrist stripe on the sleeve
parts.append(tube([Wr + dir_r * 0.15, Wr + dir_r * 0.17], [0.062, 0.062], segs=14, mat=ACC))
# palm
palm_c = T((0.012, -0.06, -0.05))
parts.append(rbox((0, 0, 0), (0.088, 0.052, 0.095), r=0.02, matrix=Matrix.Translation(palm_c) @ Matrix(R).to_4x4(), mat=GLOVE))
# knuckle plate (orange) on the back/top of the hand
parts.append(rbox((0, 0, 0), (0.07, 0.016, 0.05), r=0.005, segs=1,
                  matrix=Matrix.Translation(T((0.012, -0.088, -0.035))) @ Matrix(R).to_4x4(), mat=ACC))
# four fingers wrapping the grip + index on the trigger
for i, z in enumerate((-0.01, -0.038, -0.066, -0.093)):
    y0 = yc(z)
    if i == 0:
        pts = [T((0.034, y0 - 0.055, z)), T((0.044, y0 - 0.015, z)), T((0.040, y0 + 0.03, z + 0.002)), T((0.014, y0 + 0.058, z + 0.003))]
    else:
        pts = [T((0.034, y0 - 0.055, z)), T((0.045, y0 - 0.015, z)), T((0.038, y0 + 0.025, z)), T((0.012, y0 + 0.045, z))]
    parts.append(finger(pts, 0.0155, 0.0135))
# thumb along the left side of the receiver
th_pts = [T((-0.028, -0.07, -0.02)), T((-0.047, -0.04, 0.025)), T((-0.052, 0.0, 0.05)), T((-0.05, 0.034, 0.058))]
parts.append(tube(th_pts, [0.019, 0.0165, 0.0145, 0.0125], segs=7, round_end=1, mat=GLOVE))
bm_r = merge(*parts)

# ===== left arm + hand (supports the barrel housing from below) =====
parts = []
Wl = T((-0.034, 0.105, -0.06))
dir_l = V((-0.62, -0.55, -0.56)).normalized()
Fal = Wl + dir_l * 0.5
parts.append(sleeve([Wl + dir_l * 0.02, Wl + dir_l * 0.16, Wl + dir_l * 0.34, Fal], [0.05, 0.058, 0.068, 0.078]))
parts += cuff_rings(Wl, -dir_l, 0.052)
parts.append(tube([Wl + dir_l * 0.16, Wl + dir_l * 0.18], [0.0625, 0.0625], segs=14, mat=ACC))
# wrist computer on top of the left sleeve
fc = Wl + dir_l * 0.12
side = dir_l.cross(V((0, 0, 1))).normalized()
upv = side.cross(dir_l).normalized()
mw = basis(fc + upv * 0.05, -dir_l)
parts.append(rbox((0, 0, 0), (0.07, 0.10, 0.022), r=0.007, matrix=mw, mat=DARK))
parts.append(rbox((0, 0, 0), (0.05, 0.075, 0.004), r=0.001, segs=1, matrix=basis(fc + upv * 0.062, -dir_l), mat=GLOW))
sd = dir_l.cross(V((0, 0, 1))).normalized()
ud = sd.cross(dir_l).normalized()
parts.append(rbox((0, 0, 0), (0.07, 0.17, 0.014), r=0.005, segs=1, matrix=basis(Wl + dir_l * 0.27 + ud * 0.06, -dir_l), mat=ACC))
# palm under the canister
lp_c = T((-0.012, 0.205, -0.032))
parts.append(rbox((0, 0, 0), (0.082, 0.09, 0.042), r=0.016, matrix=Matrix.Translation(lp_c) @ Matrix(R).to_4x4(), mat=GLOVE))
# fingers wrap up the right side of housing/canister
for j in range(4):
    y = 0.162 + 0.0225 * j
    pts = []
    for ang in (-105, -60, -15, 30, 70):
        a = radians(ang)
        pts.append(T((0.056 * math.cos(a) - 0.004, y, 0.054 + 0.072 * math.sin(a))))
    parts.append(finger(pts, 0.0148, 0.0128, segs=6))
# thumb on the left side of the housing
tp = [T((-0.052, 0.15, -0.012)), T((-0.062, 0.18, 0.03)), T((-0.058, 0.214, 0.066))]
parts.append(tube(tp, [0.019, 0.016, 0.0135], segs=7, round_end=1, mat=GLOVE))
bm_l = merge(*parts)

arms = merge(bm_r, bm_l)
xform(arms, Matrix.Scale(K, 4))
M.add("FP_Arms", arms, arm_mats, (0, 0, 0), smooth_deg=40)

M.report()
# --- previews: the camera's view + orbit views
M.render_view("fp_viewmodel_cam", (0, 0, 0), (0, 1, 0), fov=75, size=(960, 540), bg=(0.2, 0.28, 0.4))
M.render_view("fp_viewmodel_cam60", (0, 0, 0), (0, 1, 0), fov=60, size=(640, 360), bg=(0.2, 0.28, 0.4))
M.preview("fp_viewmodel", views=((150, 18), (90, 10), (30, 25), (0, 10), (210, 18), (0, 85)), size=(420, 300), cols=3, dist_mult=1.1)
M.export(["FP_Arms", "FP_Tool"])
M.manifest("tool", ["any"], {"shape": "none"},
           nodes={"objects": ["FP_Arms", "FP_Tool"], "anchors": ["Muzzle"]},
           notes="First-person view model built for a camera at the origin looking along Godot -Z (Blender +Y), ~75 deg vertical FOV. "
                 "FP_Arms = both gloved forearms (white sleeves, dark gloves, cyan wrist screen on the left), FP_Tool = multitool whose origin is "
                 "the right-hand grip at ~(0.205, -0.225, -0.40) in Godot axes (x right, y up, z forward=-Z), slightly yawed/pitched inward. "
                 "Muzzle empty (child of FP_Tool) at the barrel tip. Both objects are top-level siblings: parent the whole scene to the camera. "
                 "Materials fp_viewmodel_body/dark/accent/glow.",
           tintable=["accent", "glow"])
L.save_blend()
