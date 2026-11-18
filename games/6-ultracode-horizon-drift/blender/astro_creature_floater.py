"""astro_creature_floater.py - 'Glowbell' bioluminescent jellyfish/balloon floater (~1.4 m bell, ~2.5 m with tentacles).
Origin = centre of the bell.  Flat hierarchy: Body (translucent bell + inner glow organs + oral arms), Tentacle_1..6 (pivot under the bell rim).
Run:  python tools/bmcp.py file blender/astro_creature_floater.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
from astro_lib import *
import math
from math import radians

M = A.Model("creature_floater_a")
bell = M.m("bell", (0.35, 0.75, 1.0), roughness=0.15, emission=(0.12, 0.45, 1.0), emission_strength=0.9, alpha=0.34, double_sided=True)
glow = M.m("glow", (1.0, 0.12, 0.8), emission=(1.0, 0.12, 0.8), emission_strength=3.0)
tent = M.m("tentacle", (0.40, 0.08, 1.0), roughness=0.55, emission=(0.42, 0.05, 1.0), emission_strength=1.0, alpha=0.8, double_sided=True)
BL, GL, TE = 0, 1, 2

NSCALLOP = 6


def rim_w(phi, a=1.0):
    return (0.05 * a * cos(NSCALLOP * phi), 0.04 * a * cos(NSCALLOP * phi))


def build_body():
    prof = [(-0.26, 0.60, 1.0), (-0.20, 0.66, 0.75), (-0.08, 0.68, 0.3), (0.04, 0.655, 0.0)]
    for deg in (14, 28, 42, 56, 70, 82, 90):
        th = radians(deg)
        prof.append((0.04 + 0.5 * sin(th), 0.655 * cos(th) if deg < 90 else 0.0, 0.0))
    n = 20
    rings = []
    for z, r, a in prof:
        ring = []
        for i in range(n):
            phi = 2 * pi * i / n
            dR, dz = rim_w(phi, a)
            ring.append(V(((r + dR) * cos(phi), (r + dR) * sin(phi), z + dz)))
        rings.append(ring)
    parts = [loft(rings, cap_start=False, cap_end=False, mat=BL)]
    # glowing rim ring
    parts.append(torus((0, 0, -0.26), 0.60, 0.02, 20, 4, mat=GL, wobble=lambda ph: rim_w(ph, 1.0)))
    # translucent frilly skirt hanging from the rim
    sk = []
    for z, r, ph0, amp in ((-0.26, 0.60, 0.0, 1.0), (-0.52, 0.50, pi / NSCALLOP, 1.6)):
        ring = []
        for i in range(n):
            phi = 2 * pi * i / n
            ring.append(V(((r + 0.04 * amp * cos(NSCALLOP * phi + ph0)) * cos(phi), (r + 0.04 * amp * cos(NSCALLOP * phi + ph0)) * sin(phi),
                           z + 0.07 * amp * cos(NSCALLOP * phi + ph0) * (1 if amp > 1 else 0.57))))
        sk.append(ring)
    parts.append(loft(sk, cap_start=False, cap_end=False, mat=TE))
    # inner glow core
    parts.append(ellipsoid((0, 0, 0.14), (0.2, 0.2, 0.17), 10, 6, mat=GL))
    # radial canals (visible through the translucent bell)
    for k in range(6):
        a = 2 * pi * k / 6 + radians(15)
        c, s = cos(a), sin(a)
        pts = [V((0.10 * c, 0.10 * s, 0.2)), V((0.28 * c, 0.28 * s, 0.30)), V((0.5 * c, 0.5 * s, 0.22)), V((0.63 * c, 0.63 * s, 0.0)),
               V((0.605 * c, 0.605 * s, -0.24))]
        parts.append(tube(pts, [0.010, 0.009, 0.008, 0.008, 0.008], segs=4, mat=GL))
    # oral arms: short thick frilly tentacles hanging from the centre
    for k in range(3):
        a = 2 * pi * k / 3
        c, s = cos(a), sin(a)
        c2, s2 = cos(a + 0.9), sin(a + 0.9)
        pts = [V((0.06 * c, 0.06 * s, -0.12)), V((0.11 * c, 0.11 * s, -0.34)), V((0.07 * c2, 0.07 * s2, -0.55)), V((0.13 * c2, 0.13 * s2, -0.72)),
               V((0.09 * c, 0.09 * s, -0.86))]
        parts.append(tube(pts, [0.05, 0.042, 0.032, 0.022, 0.008], segs=6, round_end=1, mat=TE))
    return merge(*parts)


def build_tentacle(k):
    """Tentacle mesh uses its OWN 2-slot list [tent, glow] -> local indices 0 (tube) / 1 (beads).
    (QA fix: the old code used the Body's indices TE=2 on a 2-slot object, so the tube silently fell back to the glow slot.)"""
    a0 = radians(15) + 2 * pi * k / 6
    r0 = 0.44
    p0 = V((r0 * cos(a0), r0 * sin(a0), -0.23))
    n = 12
    L_ = 1.55 + 0.12 * ((k * 5) % 6) / 5.0 * 3
    pts = []
    ph = k * 1.7
    for i in range(n):
        t = i / (n - 1)
        sw = 0.17 * t * (0.3 + t)
        x = p0.x + sw * math.sin(2 * pi * 0.9 * t + ph) + 0.22 * t * t * cos(a0)
        y = p0.y + sw * math.cos(2 * pi * 0.9 * t + ph * 0.7) + 0.22 * t * t * sin(a0)
        z = p0.z - L_ * t
        pts.append(V((x, y, z)))
    rad = [0.048 - 0.042 * (i / (n - 1)) ** 0.7 for i in range(n)]
    parts = [tube(pts, rad, segs=5, round_end=1, mat=0)]
    for t in (0.4, 0.75):
        i = int(round(t * (n - 1)))
        parts.append(ellipsoid(pts[i], (0.042, 0.042, 0.05), 6, 3, mat=1))
    parts.append(ellipsoid(pts[-1] + V((0, 0, -0.03)), (0.032, 0.032, 0.042), 6, 4, mat=1))
    return merge(*parts), p0


M.add("Body", build_body(), [bell, glow, tent], (0, 0, 0), smooth_deg=70)
for k in range(6):
    bm, pv = build_tentacle(k)
    M.add("Tentacle_%d" % (k + 1), bm, [tent, glow], pv, smooth_deg=70)

M.report()
M.preview("creature_floater_a", views=((150, 10), (90, 5), (30, 10), (0, 3), (200, 25), (0, 85)), size=(380, 460), cols=3, dist_mult=1.45,
          bg=(0.05, 0.06, 0.12))
M.export(["Body"] + ["Tentacle_%d" % (k + 1) for k in range(6)])
M.manifest("creature", ["exotic", "ocean", "toxic", "swamp", "any"],
           {"shape": "sphere", "radius": 0.7, "offset_y": -0.7, "center_y": 0.0},
           nodes={"body": ["Body"], "tentacles": ["Tentacle_%d" % (k + 1) for k in range(6)]},
           notes="Floating bioluminescent jellyfish. Origin = centre of the bell (hover it ~2-4 m above ground). Body = translucent bell "
                 "(alpha, double-sided) + magenta glow core/rim/canals + 3 oral arms; scale Body in Y/XZ for a pulse. Tentacle_1..6 are top-level "
                 "siblings with the pivot under the bell rim (r=0.44 m, y=-0.23), rest pose hanging down ~1.6-1.9 m: rotate about local X/Z to "
                 "sway. Materials: _bell (alpha 0.34), _tentacle (alpha 0.8, purple, tentacle tubes + frilly skirt + oral arms), _glow (emissive, tintable).",
           tintable=["bell", "tentacle", "glow"])
L.save_blend()
