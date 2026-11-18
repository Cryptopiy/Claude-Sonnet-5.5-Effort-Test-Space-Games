"""astro_creature_quadruped.py - 'Mossback' style chunky four-legged grazer (~2.4 m long, 1.4 m tall).
Origin = ground contact below the body centre, front = +Y.  Flat hierarchy: Body, Head (pivot neck), Tail (pivot rump),
Leg_FL / Leg_FR / Leg_BL / Leg_BR (pivot at hip).
Run:  python tools/bmcp.py file blender/astro_creature_quadruped.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
from astro_lib import *
import math
from math import radians

M = A.Model("creature_quadruped_a")
skin = M.m("skin", (0.07, 0.50, 0.42), roughness=0.62)
belly = M.m("belly", (0.90, 0.72, 0.42), roughness=0.7)
horn = M.m("horn", (0.95, 0.86, 0.66), roughness=0.5)
glow = M.m("glow", (1.0, 0.06, 0.5), emission=(1.0, 0.06, 0.5), emission_strength=3.2)
SK, BE, HO, GL = 0, 1, 2, 3
MATS = [skin, belly, horn, glow]

# ---- body sections (y, rx, rz, zc) -----------------------------------------------------------------------------
SEC = [(-0.80, 0.06, 0.07, 0.90), (-0.72, 0.21, 0.25, 0.90), (-0.52, 0.32, 0.36, 0.89), (-0.22, 0.345, 0.36, 0.86),
       (0.08, 0.355, 0.38, 0.88), (0.34, 0.37, 0.43, 0.92), (0.54, 0.29, 0.35, 0.95), (0.68, 0.19, 0.23, 0.96)]


def sec_at(y):
    if y <= SEC[0][0]:
        return SEC[0][1:]
    for a, b in zip(SEC, SEC[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return tuple(lerp(a[i], b[i], t) for i in (1, 2, 3))
    return SEC[-1][1:]


def surf(y, ang_deg, side=1, k=1.0):
    """point on the body surface at height-angle ang (0 = equator, 90 = top) on the +/-X side, p=2.4"""
    rx, rz, zc = sec_at(y)
    a = radians(ang_deg)
    ex = 2.0 / 2.4
    return V((side * rx * k * sgnpow(cos(a), ex), y, zc + rz * k * sgnpow(sin(a), ex)))


def build_body():
    rings = [ring_xz(y, 0.0, zc, rx, rz, 16, p=2.4) for (y, rx, rz, zc) in SEC]
    bm = loft(rings, mat=SK)
    for f in bm.faces:
        c = f.calc_center_median()
        rx, rz, zc = sec_at(c.y)
        if c.z < zc - 0.42 * rz:
            f.material_index = BE
    parts = [bm]
    # dorsal plates with glow gems
    ys = [-0.58, -0.42, -0.25, -0.07, 0.11, 0.28, 0.44]
    hs = [0.13, 0.17, 0.20, 0.23, 0.26, 0.29, 0.20]
    for y, h in zip(ys, hs):
        rx, rz, zc = sec_at(y)
        zt = zc + rz
        pts = []
        for sx in (-0.05, 0.05):
            for dy in (-0.085, 0.085):
                pts.append((sx, y + dy, zt - 0.04))
        pts.append((0, y - 0.06, zt + h))
        pts.append((0, y - 0.02, zt + h * 0.96))
        parts.append(hull(pts, mat=HO))
        # glowing tip of the plate (upper ~30%)
        f = 0.66
        tip = []
        for sx_ in (-1, 1):
            for dy in (-1, 1):
                tip.append((sx_ * 0.05 * (1 - f) * 1.15, y - 0.06 * f + dy * 0.085 * (1 - f) * 1.15, zt - 0.04 + (h + 0.04) * f))
        tip.append((0, y - 0.06, zt + h * 1.005))
        tip.append((0, y - 0.02, zt + h * 0.965))
        parts.append(hull(tip, mat=GL))
    # flank glow stripes
    for side in (1, -1):
        pts = [surf(y, 38, side, 1.0) for y in (-0.62, -0.45, -0.28, -0.1, 0.08, 0.24, 0.4)]
        parts.append(tube(pts, [0.013] * len(pts), segs=5, round_start=1, round_end=1, mat=GL))
    return merge(*parts)


def build_head():
    parts = []
    parts.append(ellipsoid((0, 0.84, 0.95), (0.21, 0.26, 0.20), 12, 8, mat=SK))
    parts.append(ellipsoid((0, 1.04, 0.885), (0.15, 0.19, 0.12), 10, 6, mat=SK))
    parts.append(ellipsoid((0, 1.0, 0.795), (0.115, 0.16, 0.055), 8, 5, mat=BE))
    for sx in (1, -1):
        parts.append(ellipsoid((0.185 * sx, 0.925, 1.0), (0.04, 0.05, 0.05), 6, 4, mat=GL))           # eyes
        parts.append(ellipsoid((0.235 * sx, 0.74, 1.03), (0.115, 0.022, 0.085), 6, 4, mat=BE,
                               matrix=Euler((0.1, 0.0, 0.6 * sx)).to_matrix().to_4x4()))             # ears
        # horns: sweep up and back
        hp = [V((0.10 * sx, 0.80, 1.10)), V((0.20 * sx, 0.74, 1.27)), V((0.21 * sx, 0.60, 1.43)), V((0.15 * sx, 0.46, 1.52))]
        parts.append(tube(hp, [0.055, 0.045, 0.03, 0.005], segs=7, round_start=1, mat=HO))
    return merge(*parts)


def build_tail():
    pts = [V((0, -0.74, 0.92)), V((0, -0.95, 0.88)), V((0, -1.13, 0.72)), V((0, -1.22, 0.55))]
    bm = tube(pts, [0.095, 0.075, 0.052, 0.034], segs=8, round_start=1, mat=SK)
    bm = merge(bm, ellipsoid((0, -1.235, 0.49), (0.075, 0.085, 0.095), 7, 5, mat=GL))
    for sx in (1, -1):
        bm = merge(bm, tube([V((0.0, -1.2, 0.55)), V((0.08 * sx, -1.3, 0.50)), V((0.12 * sx, -1.36, 0.42))], [0.02, 0.014, 0.003], segs=5, mat=HO))
    return bm


def build_front_leg(sx):
    hx, hy = 0.28 * sx, 0.36
    pts = [V((hx, hy, 0.80)), V((hx, hy + 0.025, 0.46)), V((hx, hy, 0.15))]
    bm = tube(pts, [0.155, 0.12, 0.088], segs=8, round_start=1, mat=SK)
    bm = merge(bm, tube([V((hx, hy, 0.19)), V((hx, hy, 0.17))], [0.098, 0.098], segs=8, mat=GL))     # glowing anklet
    bm = merge(bm, ellipsoid((hx, hy + 0.05, 0.05), (0.115, 0.15, 0.055), 8, 5, mat=HO))             # foot pad
    return bm, V((hx, hy, 0.80))


def build_back_leg(sx):
    hx, hy = 0.30 * sx, -0.46
    pts = [V((hx, hy, 0.83)), V((hx, hy + 0.12, 0.54)), V((hx, hy - 0.04, 0.28)), V((hx, hy + 0.02, 0.12))]
    bm = tube(pts, [0.175, 0.13, 0.088, 0.078], segs=8, round_start=1, mat=SK)
    bm = merge(bm, tube([V((hx, hy + 0.02, 0.17)), V((hx, hy + 0.02, 0.15))], [0.09, 0.09], segs=8, mat=GL))
    bm = merge(bm, ellipsoid((hx, hy + 0.08, 0.05), (0.12, 0.16, 0.055), 8, 5, mat=HO))
    return bm, V((hx, hy, 0.83))


# ---- assemble --------------------------------------------------------------------------------------------------
M.add("Body", build_body(), MATS, (0, 0, 0.88), smooth_deg=55)
M.add("Head", build_head(), MATS, (0, 0.62, 0.99), smooth_deg=55)
M.add("Tail", build_tail(), MATS, (0, -0.74, 0.92), smooth_deg=55)
for sx, sfx in ((-1, "L"), (1, "R")):
    bm, pv = build_front_leg(sx)
    M.add("Leg_F" + sfx, bm, MATS, pv, smooth_deg=55)
    bm, pv = build_back_leg(sx)
    M.add("Leg_B" + sfx, bm, MATS, pv, smooth_deg=55)

M.report()
M.preview("creature_quadruped_a", views=((150, 12), (90, 6), (30, 12), (0, 8), (200, 8), (0, 85)), size=(420, 340), cols=3, dist_mult=1.45)
M.export(["Body", "Head", "Tail", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"])
M.manifest("creature", ["lush", "swamp", "exotic", "any"],
           {"shape": "box", "size": [0.85, 1.4, 2.4], "offset_y": 0.0, "center_y": 0.7},
           nodes={"body": ["Body"], "head": ["Head"], "tail": ["Tail"], "legs": ["Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"]},
           notes="Chunky teal/pink bioluminescent grazer, ~2.4 m long. Flat hierarchy: all nodes are top-level siblings under the scene root. "
                 "Origin = ground contact below the body centre. Body origin at body centre (0, 0.88, 0); Head pivot at the neck (0, 0.99, -0.62 Godot); "
                 "Tail pivot at the rump; Leg_* pivots at the hips (y=0.80/0.83). Rotate legs about local X for walking (diagonal pairs FL+BR / FR+BL). "
                 "Materials: _skin (tintable), _belly, _horn, _glow (emissive pink accent, tintable).",
           tintable=["skin", "glow"])
L.save_blend()
