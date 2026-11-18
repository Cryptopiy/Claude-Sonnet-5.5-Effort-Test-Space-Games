"""astro_parts.py - shared part builders for the astro group (multitool is used by multitool.glb and fp_viewmodel.glb)."""
import sys
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L
import astro_lib as A
from astro_lib import *
from math import radians, sin, cos, pi


def tool_materials(M):
    """Return [body, dark, accent, glow] materials for the multitool, named <model id>_body/dark/accent/glow."""
    body = M.m("body", (0.80, 0.83, 0.87), roughness=0.4, metallic=0.15)
    dark = M.m("dark", (0.045, 0.05, 0.06), metallic=0.45, roughness=0.45)
    accent = M.m("accent", (1.0, 0.30, 0.025), roughness=0.4)
    glow = M.m("glow", (0.05, 0.75, 1.0), emission=(0.05, 0.75, 1.0), emission_strength=4.0)
    return [body, dark, accent, glow]


def build_multitool(detail=1.0):
    """Multitool in tool coordinates: origin at the grip, barrel along +Y, Z up.  ~0.57 m long.
    Returns (bmesh, muzzle_point).  Slot order: body=0 dark=1 accent=2 glow=3."""
    B, D, AC, G = 0, 1, 2, 3
    sg = 12 if detail >= 1.0 else 8
    AXZ = 0.075

    def ax(y):
        return (0, y, AXZ)

    parts = []
    # receiver body + accent side inlays + top plate/rail
    parts.append(rbox((0, 0.04, 0.065), (0.07, 0.20, 0.085), r=0.016, mat=B))
    parts.append(rbox((0, 0.03, 0.062), (0.0752, 0.095, 0.05), r=0.008, segs=1, mat=AC))
    parts.append(rbox((0, 0.05, 0.1095), (0.044, 0.17, 0.012), r=0.004, segs=1, mat=D))
    # emissive side slits
    for sx in (1, -1):
        parts.append(rbox((0.0355 * sx, 0.075, 0.07), (0.004, 0.06, 0.012), r=0.001, segs=1, mat=G))
    # grip (angled back), ribs, pommel
    parts.append(tube([(0, 0.012, 0.03), (0, 0.0, -0.04), (0, -0.025, -0.115)], [(0.0235, 0.03), (0.023, 0.029), (0.025, 0.031)],
                      segs=10, round_end=1, up=(1, 0, 0), mat=AC))
    for z, y in ((-0.03, 0.003), (-0.06, -0.006), (-0.09, -0.016)):
        parts.append(tube([(0, y, z - 0.005), (0, y, z + 0.005)], [(0.0262, 0.0325)] * 2, segs=10, mat=D))
    parts.append(tube([(0, -0.024, -0.118), (0, -0.026, -0.128)], [(0.026, 0.032), (0.027, 0.033)], segs=10, mat=D))
    # trigger + guard
    parts.append(rbox((0, 0.036, -0.012), (0.012, 0.014, 0.042), r=0.004, segs=1, matrix=Matrix.Rotation(-0.25, 4, "X"), mat=D))
    parts.append(tube([(0, 0.02, -0.092), (0, 0.062, -0.075), (0, 0.072, -0.03), (0, 0.062, 0.015)], [0.0045] * 4, segs=5, mat=D))
    # rear battery / stock
    parts.append(tube([ax(-0.115), ax(-0.06)], [0.034, 0.033], segs=sg, round_start=1, mat=B))
    parts.append(tube([ax(-0.09), ax(-0.078)], [0.0355, 0.0355], segs=sg, mat=G))
    parts.append(tube([ax(-0.105), ax(-0.098)], [0.0355, 0.0355], segs=sg, mat=AC))
    # scope / sensor block on top front
    parts.append(rbox((0, 0.098, 0.125), (0.042, 0.07, 0.032), r=0.008, mat=D))
    parts.append(rbox((0, 0.1335, 0.125), (0.028, 0.004, 0.018), r=0.002, segs=1, mat=G))
    # display on top rear (tilted toward the user)
    th = 0.45
    n = Vector((0, -sin(th), cos(th)))
    c = Vector((0, -0.022, 0.118))
    mr = Matrix.Rotation(th, 4, 'X')
    parts.append(rbox(c, (0.056, 0.066, 0.014), r=0.004, segs=1, matrix=mr, mat=D))
    parts.append(rbox(c + n * 0.0075, (0.044, 0.052, 0.003), r=0.0005, segs=1, matrix=mr, mat=G))
    for i, w in enumerate((0.034, 0.024, 0.03)):
        parts.append(rbox(c + n * 0.0092 + Vector((-0.004, 0.0, 0)) + mr.to_3x3() @ Vector((0, 0.016 - i * 0.015, 0)),
                          (w, 0.005, 0.0015), r=0.0003, segs=1, matrix=mr, mat=D))
    # barrel housing + rings
    parts.append(tube([ax(0.10), ax(0.30)], [0.041, 0.036], segs=sg, mat=B))
    for y, m in ((0.135, AC), (0.17, D), (0.29, D)):
        parts.append(tube([ax(y - 0.008), ax(y + 0.008)], [0.0425] * 2, segs=sg, mat=m))
    # glowing core with struts
    parts.append(tube([ax(0.30), ax(0.43)], [0.0175, 0.0175], segs=10, mat=G))
    nstr = 6 if detail >= 1.0 else 4
    for k in range(nstr):
        a = 2 * pi * k / nstr + pi / nstr
        r = 0.031
        parts.append(tube([(r * cos(a), 0.298, AXZ + r * sin(a)), (r * cos(a), 0.418, AXZ + r * sin(a))], [0.0065] * 2, segs=5, mat=D))
    parts.append(tube([ax(0.296), ax(0.312)], [0.039] * 2, segs=sg, mat=D))
    parts.append(tube([ax(0.405), ax(0.422)], [0.038] * 2, segs=sg, mat=D))
    # muzzle + lens
    parts.append(tube([ax(0.422), ax(0.446)], [0.037, 0.027], segs=sg, mat=D))
    parts.append(tube([ax(0.446), ax(0.453)], [0.0215] * 2, segs=sg, mat=G))
    # swept side fins (accent)
    for sx in (1, -1):
        pts = []
        for (x, y) in ((0.034, 0.13), (0.034, 0.295), (0.092, 0.265), (0.092, 0.215)):
            for dz in (-0.006, 0.006):
                pts.append((x * sx, y, AXZ + dz))
        parts.append(hull(pts, mat=AC))
        # fin edge glow strip
        parts.append(hull([(0.0915 * sx, 0.218, AXZ + 0.0065), (0.0915 * sx, 0.262, AXZ + 0.0065), (0.0895 * sx, 0.262, AXZ + 0.0075),
                           (0.0895 * sx, 0.218, AXZ + 0.0075)], mat=G)) if detail >= 1.0 else None
    # under-barrel resource canister
    parts.append(tube([(0, 0.14, 0.02), (0, 0.27, 0.02)], [0.0245, 0.0245], segs=sg, round_start=1, round_end=1, mat=D))
    parts.append(tube([(0, 0.195, 0.02), (0, 0.207, 0.02)], [0.0262] * 2, segs=sg, mat=G))
    parts.append(rbox((0, 0.135, 0.045), (0.03, 0.05, 0.03), r=0.006, segs=1, mat=B))
    parts = [p for p in parts if p is not None]
    bm = merge(*parts)
    return bm, V((0, 0.456, AXZ))
