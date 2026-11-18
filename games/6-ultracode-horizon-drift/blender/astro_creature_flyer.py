"""astro_creature_flyer.py - 'Skyfin' winged flyer (~2.5 m wingspan, ~1.5 m long incl. tail).
Origin = ground contact below the body centre (perched pose; legs reach the ground), front = +Y.
Flat hierarchy: Body, Head (pivot neck), Wing_L/Wing_R (pivot at the shoulder, exported spread), Tail (pivot tail root).
Run:  python tools/bmcp.py file blender/astro_creature_flyer.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
from astro_lib import *
import math
from math import radians

M = A.Model("creature_flyer_a")
skin = M.m("skin", (0.55, 0.05, 0.12), roughness=0.55)
belly = M.m("belly", (0.95, 0.68, 0.38), roughness=0.6)
memb = M.m("membrane", (1.0, 0.45, 0.04), roughness=0.5, double_sided=True)
bone = M.m("bone", (0.22, 0.03, 0.06), roughness=0.5)
glow = M.m("glow", (0.05, 0.9, 1.0), emission=(0.05, 0.9, 1.0), emission_strength=3.5)
MATS = [skin, belly, memb, bone, glow]
SK, BE, ME, BO, GL = 0, 1, 2, 3, 4

ZC = 0.55
SEC = [(-0.50, 0.03, 0.03, 0.55), (-0.38, 0.09, 0.09, 0.55), (-0.15, 0.15, 0.16, 0.56), (0.08, 0.175, 0.18, 0.575),
       (0.28, 0.145, 0.16, 0.595), (0.42, 0.085, 0.09, 0.625), (0.5, 0.055, 0.055, 0.645)]


SEC = [(y, rx * 1.25, rz * 1.25, zc) for (y, rx, rz, zc) in SEC]


def sec_at(y):
    if y <= SEC[0][0]:
        return SEC[0][1:]
    for a, b in zip(SEC, SEC[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return tuple(lerp(a[i], b[i], t) for i in (1, 2, 3))
    return SEC[-1][1:]


def resample(pts, n):
    pts = [Vector(p) for p in pts]
    lens = [0.0]
    for a, b in zip(pts, pts[1:]):
        lens.append(lens[-1] + (b - a).length)
    tot = lens[-1]
    out = []
    for i in range(n):
        d = tot * i / (n - 1)
        for j in range(len(pts) - 1):
            if lens[j] <= d <= lens[j + 1] + 1e-9:
                t = (d - lens[j]) / max(lens[j + 1] - lens[j], 1e-9)
                out.append(pts[j].lerp(pts[j + 1], t))
                break
    return out


def build_body():
    rings = [ring_xz(y, 0.0, zc, rx, rz, 14, p=2.2) for (y, rx, rz, zc) in SEC]
    bm = loft(rings, mat=SK)
    for f in bm.faces:
        c = f.calc_center_median()
        rx, rz, zc = sec_at(c.y)
        if c.z < zc - 0.35 * rz:
            f.material_index = BE
    parts = [bm]
    # breast keel glow strip + back glow stripe
    parts.append(tube([V((0, y, sec_at(y)[2] - sec_at(y)[1] * 0.97)) for y in (-0.2, 0.0, 0.2, 0.34)], [0.012, 0.016, 0.014, 0.01], segs=5, round_start=1, round_end=1, mat=GL))
    parts.append(tube([V((0, y, sec_at(y)[2] + sec_at(y)[1] * 0.98)) for y in (-0.3, -0.1, 0.1, 0.28)], [0.010, 0.014, 0.014, 0.010], segs=5, round_start=1, round_end=1, mat=GL))
    # dangling legs with talons
    for sx in (1, -1):
        pts = [V((0.07 * sx, -0.02, 0.45)), V((0.09 * sx, 0.07, 0.30)), V((0.08 * sx, -0.02, 0.17)), V((0.08 * sx, 0.02, 0.05))]
        parts.append(tube(pts, [0.036, 0.026, 0.02, 0.016], segs=5, round_start=1, mat=SK))
        for k in (-1, 0, 1):
            parts.append(tube([V((0.08 * sx + 0.025 * k, 0.03, 0.045)), V((0.08 * sx + 0.045 * k, 0.12, 0.025)), V((0.08 * sx + 0.05 * k, 0.17, 0.01))],
                              [0.012, 0.009, 0.002], segs=4, mat=BE))
        parts.append(tube([V((0.08 * sx, -0.01, 0.05)), V((0.08 * sx, -0.08, 0.02))], [0.012, 0.002], segs=4, mat=BE))
    return merge(*parts)


def build_head():
    parts = []
    parts.append(tube([V((0, 0.38, 0.60)), V((0, 0.47, 0.64)), V((0, 0.52, 0.665))], [0.075, 0.06, 0.055], segs=8, mat=SK))
    parts.append(ellipsoid((0, 0.56, 0.675), (0.075, 0.115, 0.07), 10, 7, mat=SK))
    # beak
    parts.append(tube([V((0, 0.64, 0.665)), V((0, 0.78, 0.65)), V((0, 0.9, 0.62))], [(0.045, 0.036), (0.032, 0.026), (0.004, 0.004)], segs=6, mat=BE))
    parts.append(tube([V((0, 0.64, 0.635)), V((0, 0.76, 0.62)), V((0, 0.84, 0.60))], [(0.035, 0.024), (0.024, 0.016), (0.004, 0.004)], segs=6, mat=BE))
    for sx in (1, -1):
        parts.append(ellipsoid((0.068 * sx, 0.575, 0.7), (0.026, 0.03, 0.03), 6, 4, mat=GL))
    # crest: swept-back thin fin with glowing edge
    crest = []
    for sx in (-0.007, 0.007):
        crest += [(sx, 0.52, 0.735), (sx, 0.62, 0.725), (sx, 0.40, 0.90), (sx, 0.30, 0.84)]
    parts.append(hull(crest, mat=SK))
    parts.append(tube([V((0, 0.56, 0.74)), V((0, 0.43, 0.895)), V((0, 0.34, 0.85))], [0.011, 0.011, 0.01], segs=4, round_end=1, mat=GL))
    return merge(*parts)


def build_tail():
    pts = [V((0, -0.42, 0.55)), V((0, -0.75, 0.50)), V((0, -1.08, 0.45))]
    parts = [tube(pts, [0.055, 0.035, 0.022], segs=6, round_start=1, mat=SK)]
    fan = []
    for z in (0.44, 0.45):
        fan += [(0.0, -1.0, z), (0.25, -1.35, z), (0.0, -1.55, z), (-0.25, -1.35, z)]
    parts.append(hull(fan, mat=ME))
    for sx in (1, -1):
        parts.append(ellipsoid((0.25 * sx, -1.36, 0.445), (0.028, 0.04, 0.025), 6, 4, mat=GL))
    parts.append(ellipsoid((0, -1.56, 0.445), (0.03, 0.04, 0.025), 6, 4, mat=GL))
    parts.append(tube([V((0, -1.04, 0.445)), V((0, -1.55, 0.445))], [0.012, 0.01], segs=4, mat=BO))
    return merge(*parts)


def build_wing(sx):
    k = 0.86
    root = V((0.16 * sx, 0.05, 0.64))

    def Wp(x, y, z):
        return root + V((x * sx * k, y * k, z * k))

    arm = [Wp(0, 0, 0), Wp(0.46, 0.14, 0.12), Wp(0.90, 0.03, 0.26)]
    wrist = arm[-1]
    tips = [Wp(1.30, -0.14, 0.36), Wp(1.10, -0.56, 0.24), Wp(0.80, -0.74, 0.14)]
    btrail = V((0.13 * sx, -0.40, 0.60))
    parts = []
    # --- membrane: inner panel (grid) ---
    lead = resample([arm[0], arm[1], arm[2]], 7)
    mid = btrail.lerp(tips[2], 0.5) + V((0, 0.07, 0.0))
    trail = resample([btrail, mid, tips[2]], 7)
    rows = []
    for t in (0.0, 0.33, 0.66, 1.0):
        row = []
        for a, b in zip(lead, trail):
            p = a.lerp(b, t)
            p.z += 0.035 * sin(pi * t)
            row.append(p)
        rows.append(row)
    parts.append(grid_surface(rows, mat=ME, flip=(sx < 0)))
    # --- fans between fingers ---
    def fan(tipA, tipB, n=6, nr=3, depth=0.2):
        arc = []
        mid_ = tipA.lerp(tipB, 0.5)
        inward = (wrist - mid_)
        for i in range(n):
            s = i / (n - 1)
            arc.append(tipA.lerp(tipB, s) + inward * depth * sin(pi * s))
        bm = bmesh.new()
        apex = bm.verts.new(wrist)
        prev = None
        rows_ = []
        for r in range(1, nr + 1):
            tt = r / nr
            rows_.append([bm.verts.new(wrist.lerp(p, tt) + V((0, 0, 0.03 * sin(pi * tt) * 0.6))) for p in arc])
        for j in range(n - 1):
            bm.faces.new((apex, rows_[0][j], rows_[0][j + 1]))
        for r in range(nr - 1):
            for j in range(n - 1):
                bm.faces.new((rows_[r][j], rows_[r + 1][j], rows_[r + 1][j + 1], rows_[r][j + 1]))
        set_mat(bm, ME)
        return bm

    parts.append(fan(tips[2], tips[1]))
    parts.append(fan(tips[1], tips[0]))
    # --- bones ---
    parts.append(tube(arm, [0.042, 0.03, 0.022], segs=6, round_start=1, mat=BO))
    for tp, r0 in zip(tips, (0.020, 0.018, 0.016)):
        m = wrist.lerp(tp, 0.5) + V((0, 0.0, 0.025))
        parts.append(tube([wrist, m, tp], [r0, r0 * 0.7, 0.006], segs=5, mat=BO))
    # thumb claw at the wrist
    parts.append(tube([wrist, wrist + V((0.0, 0.08, 0.03)), wrist + V((-0.02 * sx, 0.14, 0.0))], [0.02, 0.012, 0.002], segs=4, mat=BE))
    # --- glow veins on the membrane + tip beads ---
    for tp in tips:
        m = wrist.lerp(tp, 0.5) + V((0, 0.0, 0.025))
        parts.append(tube([wrist + V((0, 0, 0.012)), m + V((0, 0, 0.012)), tp + V((0, 0, 0.012))], [0.008, 0.007, 0.005], segs=4, mat=GL))
    parts.append(ellipsoid(tips[0], (0.03, 0.03, 0.025), 6, 4, mat=GL))
    parts.append(ellipsoid(tips[1], (0.026, 0.026, 0.022), 6, 4, mat=GL))
    return merge(*parts), root


M.add("Body", build_body(), MATS, (0, 0, ZC), smooth_deg=60)
hb = build_head()
hp = V((0, 0.45, 0.64))
xform(hb, Matrix.Translation(hp) @ Matrix.Scale(1.25, 4) @ Matrix.Translation(-hp))
M.add("Head", hb, MATS, (0, 0.42, 0.63), smooth_deg=60)
M.add("Tail", build_tail(), MATS, (0, -0.42, 0.55), smooth_deg=60)
for sx, sfx in ((-1, "L"), (1, "R")):
    bm, pv = build_wing(sx)
    M.add("Wing_" + sfx, bm, MATS, pv, smooth_deg=60)

M.report()
M.preview("creature_flyer_a", views=((150, 18), (90, 8), (30, 18), (0, 12), (200, 20), (0, 85)), size=(420, 340), cols=3, dist_mult=1.4)
M.export(["Body", "Head", "Tail", "Wing_L", "Wing_R"])
M.manifest("creature", ["lush", "desert", "any", "frozen"],
           {"shape": "sphere", "radius": 0.55, "offset_y": 0.05, "center_y": 0.6},
           nodes={"body": ["Body"], "head": ["Head"], "tail": ["Tail"], "wings": ["Wing_L", "Wing_R"]},
           notes="Winged flyer, ~2.5 m wingspan, ruby body / orange membrane wings with glowing cyan veins. Flat hierarchy (all top-level siblings). "
                 "Origin = ground contact below the body centre (the dangling talons touch y=0 when perched; Body pivot at y=0.55). Wing_L/Wing_R pivots "
                 "at the shoulders (x=+-0.16, y=0.64, z=-0.05 in Godot), exported SPREAD horizontally (slightly raised): flap by rotating about the local "
                 "forward axis (Godot Z); Wing_R rotation.z>0 raises its tip, Wing_L needs the opposite sign (mirror). Head pivot at the neck, Tail pivot at the tail root (swing about Y/X). "
                 "Membrane material is double-sided. Materials: _skin, _belly (beak/belly), _membrane, _bone, _glow (emissive).",
           tintable=["skin", "membrane", "glow"])
L.save_blend()
