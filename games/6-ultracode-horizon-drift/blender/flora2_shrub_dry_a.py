"""flora2 / shrub_dry_a : ~1 m dry, spiky desert shrub (mound of grey twigs, sparse sage + straw leaves)."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector, Matrix
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "shrub_dry_a")
SD = OVR.get("seed", 14)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_wood = L.mat(MID + "_twig", F.hexcol("#8c7556"), roughness=0.9)
m_leaf = F.mat_dbl(MID + "_leaf", F.hexcol("#8fa253"), roughness=0.8)         # sage green (double sided material, single faces)
m_leaf2 = F.mat_dbl(MID + "_leaf_dry", F.hexcol("#d8b658"), roughness=0.85)   # straw yellow

bm = bmesh.new()
leaves = []


def branch(p0, d, length, r0, r1, level, bend=0.35, kids=3):
    d = d.normalized()
    pts = [Vector(p0)]
    cur = Vector(p0)
    side = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 0.3))).normalized()
    nseg = 4 if level == 0 else (3 if level == 1 else 2)
    dd = d.copy()
    for i in range(nseg):
        dd = (dd + side * bend / nseg + Vector((0, 0, 0.12 / nseg))).normalized()
        cur = cur + dd * (length / nseg)
        pts.append(cur.copy())
    seg = 5 if level == 0 else (4 if level == 1 else 3)
    radii = [F.lerp(r0, r1, i / nseg) for i in range(nseg + 1)]
    F.tube(bm, pts, radii, segs=seg, mat=0, cap_a=None, cap_b="apex", tip_b=r1 * 2.5)
    if level < 2:
        for c in range(kids):
            t = rng.uniform(0.3, 0.85)
            idx = min(int(t * nseg), nseg - 1)
            base = pts[idx].lerp(pts[idx + 1], t * nseg - idx)
            ax = rng.random() * F.TAU
            tangent = (pts[-1] - pts[0]).normalized()
            perp = tangent.cross(Vector((math.cos(ax), math.sin(ax), 0.3))).normalized()
            cd = (tangent * 0.6 + perp * rng.uniform(0.6, 1.0) + Vector((0, 0, 0.2))).normalized()
            branch(base, cd, length * rng.uniform(0.5, 0.7), r1 * 1.15, r1 * 0.45, level + 1, bend, kids=3)
    if level >= 1:
        nl = 5 if level == 1 else 4
        for _ in range(nl):
            t = rng.uniform(0.3, 1.0)
            idx = min(int(t * nseg), nseg - 1)
            p = pts[idx].lerp(pts[idx + 1], t * nseg - idx)
            leaves.append((p, (pts[-1] - pts[0]).normalized()))


n_stems = 8
for i in range(n_stems):
    az = F.TAU * i / n_stems + rng.uniform(-0.25, 0.25)
    tilt = rng.uniform(0.35, 0.8)
    d = Vector((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))
    branch(Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0.0)), d, rng.uniform(0.48, 0.62), 0.02, 0.01, 0, bend=0.3, kids=3)
F.tube(bm, [Vector((0, 0, -0.02)), Vector((0, 0, 0.10))], [0.05, 0.04], segs=6, mat=0, cap_a="flat", cap_b="flat")

# leaves: small lanceolate single-sided quads (the material is double sided)
for p, tdir in leaves:
    az = rng.random() * F.TAU
    ln = rng.uniform(0.08, 0.14)
    w = ln * rng.uniform(0.18, 0.26)
    dirv = (tdir * 0.45 + Vector((math.cos(az), math.sin(az), rng.uniform(-0.1, 0.5)))).normalized()
    side = dirv.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    mid = p + dirv * ln * 0.45 + Vector((0, 0, 0.01))
    tip = p + dirv * ln + Vector((0, 0, -0.012))
    mi = 1 if rng.random() < 0.6 else 2
    F.quad2(bm, p, mid + side * w, tip, mid - side * w, mi, False)

F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, [m_wood, m_leaf, m_leaf2], smooth_deg=60)
F.finish(MID, [ob], "flora", ["desert", "barren"],
         F.vc({"shape": "cylinder", "radius": 0.35, "height": 0.7, "offset_y": 0.0}, OVR),
         tintable=["leaf"],
         notes="Dry twiggy shrub, ~1 m wide mound. Origin at ground. Leaves are single-sided quads on a double-sided material (cull off). "
               "Materials: twig (grey-brown wood), leaf (sage), leaf_dry (straw). Cheap enough for MultiMesh scatter.")
