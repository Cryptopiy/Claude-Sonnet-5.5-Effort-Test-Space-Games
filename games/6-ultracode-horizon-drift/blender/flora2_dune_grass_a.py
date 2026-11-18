"""flora2 / dune_grass_a : ~0.8 m sparse dry grass tuft: broad tapering two-sided straw blades (twisted so they read from every angle,
arching outward) + three seed stalks with feathery seed heads. ~190 tris.  QA rework: the first version used hair-thin radial blades and
detached floating seed diamonds."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector, Matrix
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "dune_grass_a")
SD = OVR.get("seed", 222)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_blade = F.mat_foliage(MID + "_blade", F.hexcol("#e2cb82"), roughness=0.85)
m_tip = F.mat_foliage(MID + "_blade_tip", F.hexcol("#a98550"), roughness=0.9)
m_seed = F.mat_foliage(MID + "_seed", F.hexcol("#d49a45"), roughness=0.8)


def two_sided_quad(bm, a, b, c, d, mat):
    f = bm.faces.new([bm.verts.new(p) for p in (a, b, c, d)])
    f.material_index = mat
    g = bm.faces.new([bm.verts.new(p) for p in (d, c, b, a)])
    g.material_index = mat


def two_sided_tri(bm, a, b, c, mat):
    f = bm.faces.new([bm.verts.new(p) for p in (a, b, c)])
    f.material_index = mat
    g = bm.faces.new([bm.verts.new(p) for p in (c, b, a)])
    g.material_index = mat


def ribbon(bm, base, az, length, half_w, lean, curve, twist, mat_lo, mat_hi, hi_from, wprof=(0.8, 1.0, 0.7), segs=3):
    """Two-sided blade: centre line arcs outward along azimuth `az` (leaning `lean` rad from vertical, bending a further `curve`),
    ribbon width axis twisted about the blade axis by `twist` rad.  Returns (tip, tangent, side) for attaching things."""
    dirh = Vector((math.cos(az), math.sin(az), 0.0))
    side0 = Vector((-math.sin(az), math.cos(az), 0.0))
    step = length / segs
    pts = [Vector(base)]
    tans = []
    for i in range(segs):
        a = lean + curve * (i + 0.5) / segs
        t = (dirh * math.sin(a) + Vector((0, 0, 1)) * math.cos(a)).normalized()
        tans.append(t)
        pts.append(pts[-1] + t * step)
    rings = []
    sides = []
    for i in range(segs):
        t = tans[i]
        s = (Matrix.Rotation(twist * (1.0 + 0.35 * i / segs), 3, t) @ side0).normalized()
        sides.append(s)
        w = half_w * wprof[min(i, len(wprof) - 1)]
        rings.append((pts[i] - s * w, pts[i] + s * w))
    for i in range(segs - 1):
        m = mat_lo if i < hi_from else mat_hi
        two_sided_quad(bm, rings[i][0], rings[i][1], rings[i + 1][1], rings[i + 1][0], m)
    two_sided_tri(bm, rings[-1][0], rings[-1][1], pts[-1], mat_hi)
    return pts[-1], tans[-1], sides[-1]


bm = bmesh.new()
nb = 15
for i in range(nb):
    az = F.TAU * (i / nb) + rng.uniform(-0.35, 0.35)
    inner = (i % 3 == 0)
    if inner:
        ln = rng.uniform(0.36, 0.56)
        lean = rng.uniform(0.04, 0.28)
        curve = rng.uniform(0.2, 0.6)
    else:
        ln = rng.uniform(0.46, 0.76)
        lean = rng.uniform(0.15, 0.5)
        curve = rng.uniform(0.5, 1.0)
    hw = rng.uniform(0.032, 0.046)
    r0 = rng.uniform(0.0, 0.05)
    base = Vector((math.cos(az) * r0, math.sin(az) * r0, 0.0))
    dead = rng.random() < 0.2
    ribbon(bm, base, az, ln, hw, lean, curve, rng.uniform(-0.85, 0.85), 1 if dead else 0, 1, 0 if dead else 2)
# seed stalks: thin stem + feathery seed head attached to the stem tip
for i in range(3):
    az = F.TAU * (i / 3) + rng.uniform(-0.5, 0.5)
    ln = rng.uniform(0.58, 0.72)
    tip, t, s = ribbon(bm, Vector((0, 0, 0)), az, ln, 0.011, rng.uniform(0.04, 0.12), rng.uniform(0.25, 0.5), rng.uniform(-0.5, 0.5), 1, 1, 9,
                       wprof=(1.0, 0.9, 0.8))
    p = t.cross(s).normalized()
    hl = rng.uniform(0.15, 0.2)
    hw = 0.022
    for ax in (s, p):
        b0 = tip - t * 0.02
        two_sided_quad(bm, b0, tip + t * hl * 0.3 + ax * hw, tip + t * hl, tip + t * hl * 0.3 - ax * hw, 2)
for v in bm.verts:
    if v.co.z < 0.0:
        v.co.z = 0.0
F.apply_variant(bm, OVR)
ob = F.build_obj(MID, bm, col, [m_blade, m_tip, m_seed], smooth_deg=None, all_flat=True)
F.finish(MID, [ob], "flora", ["desert"],
         {"shape": "none"},
         tintable=["blade"],
         notes="Sparse dry grass tuft ~0.8 m: 15 broad two-sided blades (twisted, arching outward) + 3 seed stalks with seed heads (materials have backface "
               "culling ON; both sides modelled). Origin at ground. No collider. Cheap enough for dense MultiMesh scatter.",
         dist_mult=1.9)
