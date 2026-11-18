"""astro_creature_crawler.py - 'Emberback' six-legged armoured crawler/beetle (~0.8 m long, 1.3 m leg span).
Origin = ground contact below the body centre, front = +Y.  Flat hierarchy: Body, Head (pivot neck), Leg_1..Leg_6 (pivot at the body).
Leg numbering is chosen so that i%2 gives the two tripod gait groups:  1=LF 2=RF 3=RM 4=LM 5=LB 6=RB  (L = -X, R = +X; F/M/B = front/mid/back).
Run:  python tools/bmcp.py file blender/astro_creature_crawler.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
from astro_lib import *
import math
from math import radians

M = A.Model("creature_crawler_a")
shell = M.m("shell", (0.95, 0.48, 0.04), roughness=0.38, metallic=0.15)
plate = M.m("plate", (0.50, 0.10, 0.02), roughness=0.45, metallic=0.1)
dark = M.m("dark", (0.06, 0.04, 0.03), roughness=0.5, metallic=0.25)
glow = M.m("glow", (0.45, 1.0, 0.05), emission=(0.45, 1.0, 0.05), emission_strength=4.0)
MATS = [shell, plate, dark, glow]
SH, PL, DK, GL = 0, 1, 2, 3

ZC = 0.28
SEC = [(-0.42, 0.04, 0.04, 0.27), (-0.36, 0.17, 0.13, 0.28), (-0.17, 0.27, 0.21, 0.31), (0.08, 0.28, 0.21, 0.32),
       (0.24, 0.22, 0.16, 0.31), (0.33, 0.13, 0.10, 0.30), (0.38, 0.08, 0.06, 0.30)]
SEC = [(y, rx * 1.12, rz * 1.2, zc + 0.02) for (y, rx, rz, zc) in SEC]


def sec_at(y):
    if y <= SEC[0][0]:
        return SEC[0][1:]
    for a, b in zip(SEC, SEC[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return tuple(lerp(a[i], b[i], t) for i in (1, 2, 3))
    return SEC[-1][1:]


def surf(y, ang_deg, side=1, k=1.0):
    rx, rz, zc = sec_at(y)
    a = radians(ang_deg)
    ex = 2.0 / 2.2
    return V((side * rx * k * sgnpow(cos(a), ex), y, zc + rz * k * sgnpow(sin(a), ex)))


def build_body():
    rings = []
    for (y, rx, rz, zc) in SEC:
        ring = ring_xz(y, 0.0, zc, rx, rz, 16, p=2.2)
        for p in ring:                     # flatten the underside
            if p.z < zc:
                p.z = zc + (p.z - zc) * 0.45
        rings.append(ring)
    bm = loft(rings, mat=SH)
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y > 0.17:
            f.material_index = PL           # thorax shield
        if c.z < ZC - 0.02:
            f.material_index = DK           # underside
    parts = [bm]
    # dorsal seam between the wing covers
    pts = [V((0, y, sec_at(y)[2] + sec_at(y)[1] * 1.0 + 0.004)) for y in (-0.36, -0.2, -0.05, 0.1)]
    parts.append(tube(pts, [0.008, 0.012, 0.012, 0.008], segs=5, round_start=1, round_end=1, mat=DK))
    # glowing stripes along both wing covers
    for side in (1, -1):
        for ang, r in ((68, 0.011), (38, 0.012)):
            pts = [surf(y, ang, side, 1.005) for y in (-0.33, -0.2, -0.06, 0.07, 0.17)]
            parts.append(tube(pts, [r] * len(pts), segs=4, round_start=1, round_end=1, mat=GL))
    # rim spikes
    for side in (1, -1):
        for y, h in ((-0.28, 0.07), (-0.14, 0.09), (0.0, 0.09), (0.14, 0.07)):
            base = surf(y, 8, side, 1.0)
            tip = base + V((side * 0.07, 0.0, 0.05 + h * 0.4))
            parts.append(cone(base + V((side * -0.01, 0, 0.0)), tip, 0.028, segs=6, mat=DK))
    # thorax crest horn
    parts.append(cone(V((0, 0.2, sec_at(0.2)[2] + sec_at(0.2)[1] * 0.9)), V((0, 0.3, sec_at(0.2)[2] + sec_at(0.2)[1] + 0.12)), 0.035, segs=6, mat=PL))
    return merge(*parts)


def build_head():
    parts = []
    parts.append(ellipsoid((0, 0.44, 0.30), (0.125, 0.115, 0.095), 10, 7, mat=DK))
    parts.append(ellipsoid((0, 0.5, 0.265), (0.1, 0.07, 0.05), 8, 5, mat=PL))            # clypeus / mouth plate
    for sx in (1, -1):
        parts.append(ellipsoid((0.085 * sx, 0.485, 0.34), (0.036, 0.034, 0.04), 6, 4, mat=GL))          # big eyes
        parts.append(ellipsoid((0.05 * sx, 0.515, 0.375), (0.018, 0.018, 0.02), 5, 3, mat=GL))          # small eyes
        mp = [V((0.06 * sx, 0.52, 0.255)), V((0.13 * sx, 0.62, 0.235)), V((0.14 * sx, 0.72, 0.245)), V((0.06 * sx, 0.80, 0.265))]
        parts.append(tube(mp, [0.032, 0.026, 0.018, 0.004], segs=5, round_start=1, mat=PL))
        ap = [V((0.045 * sx, 0.5, 0.375)), V((0.08 * sx, 0.62, 0.50)), V((0.15 * sx, 0.74, 0.55)), V((0.2 * sx, 0.84, 0.50))]
        parts.append(tube(ap, [0.011, 0.009, 0.007, 0.005], segs=4, mat=DK))
        parts.append(ellipsoid(ap[-1], (0.022, 0.022, 0.022), 5, 3, mat=GL))
    return merge(*parts)


LEGS = [  # (index, side, y, kind)
    (1, -1, 0.16, "F"), (2, 1, 0.16, "F"), (3, 1, -0.02, "M"), (4, -1, -0.02, "M"), (5, -1, -0.20, "B"), (6, 1, -0.20, "B")]


def build_leg(side, y, kind):
    P = V((0.22 * side, y, 0.29))
    dk = {"F": (0.15, 0.25, 0.30), "M": (0.03, 0.06, 0.08), "B": (-0.14, -0.25, -0.29)}[kind]
    K = V((0.47 * side, y + dk[0], 0.45))
    A_ = V((0.57 * side, y + dk[1], 0.16))
    F = V((0.61 * side, y + dk[2], 0.0))
    pts = [P, P.lerp(K, 0.55) + V((0, 0, 0.05)), K, K.lerp(A_, 0.5), A_, F]
    bm = tube(pts, [0.058, 0.048, 0.042, 0.036, 0.027, 0.009], segs=6, round_start=1, mat=DK)
    bm = merge(bm, ellipsoid(K + V((0, 0, 0.0)), (0.05, 0.05, 0.05), 5, 4, mat=GL))                # glowing knee joint
    bm = merge(bm, cone(K + V((0, 0, 0.03)), K + V((0.0, 0.0, 0.13)), 0.03, segs=5, mat=PL))          # knee spike
    return bm, P


M.add("Body", build_body(), MATS, (0, 0, ZC), smooth_deg=60)
M.add("Head", build_head(), MATS, (0, 0.36, 0.30), smooth_deg=60)
for idx, side, y, kind in LEGS:
    bm, P = build_leg(side, y, kind)
    M.add("Leg_%d" % idx, bm, MATS, P, smooth_deg=60)

M.report()
M.preview("creature_crawler_a", views=((150, 20), (90, 10), (30, 20), (0, 12), (200, 25), (0, 85)), size=(420, 340), cols=3, dist_mult=1.4)
M.export(["Body", "Head"] + ["Leg_%d" % i for i in range(1, 7)])
M.manifest("creature", ["desert", "volcanic", "barren", "toxic", "any"],
           {"shape": "box", "size": [1.3, 0.55, 1.2], "offset_y": 0.025, "center_y": 0.3},
           nodes={"body": ["Body"], "head": ["Head"], "legs": ["Leg_%d" % i for i in range(1, 7)]},
           notes="~0.8 m armoured beetle: amber shell, dark legs, lime glowing stripes/eyes/knees. Flat hierarchy (all top-level siblings). Origin = ground "
                 "contact below the body centre (Body pivot y=0.28). Leg pivots at the body attachment (x=+-0.2, y=0.27); leg numbering for a tripod gait "
                 "(i%2 groups): 1=LF 2=RF 3=RM 4=LM 5=LB 6=RB (L=-X, R=+X; in Godot front=-Z). Rotate legs about local X for stepping (and Z to lift). "
                 "Head pivot at the neck. Materials: _shell (tintable), _plate, _dark, _glow (emissive lime, tintable).",
           tintable=["shell", "glow"])
L.save_blend()
