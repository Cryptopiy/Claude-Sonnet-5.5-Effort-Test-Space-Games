"""flora2 / dead_tree_a : ~5 m bleached, gnarled desert tree: buttress roots, twisting trunk, forked limbs, broken stubs."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "dead_tree_a")
SD = OVR.get("seed", 51)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_wood = L.mat(MID + "_wood", F.hexcol("#b4a88f"), roughness=0.95)
m_dark = L.mat(MID + "_wood_dark", F.hexcol("#4e4030"), roughness=0.95)
m_bark = L.mat(MID + "_bark", F.hexcol("#9d8f76"), roughness=0.98)

bm = bmesh.new()


def bark_profile(k):
    def prof(th, u):
        return 1.0 + 0.13 * math.sin(5 * th + 5 * u + k) + 0.09 * F.n3(math.cos(th) * 2, math.sin(th) * 2, u * 6 + k, 3)
    return prof


def limb(p0, d, length, r0, r1, depth, segs):
    d = d.normalized()
    n = 5 if depth == 0 else 4
    pts = [Vector(p0)]
    cur = Vector(p0)
    dd = d.copy()
    for i in range(n):
        kink = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 0.5)))
        dd = (dd + kink * (0.34 if depth < 2 else 0.5) + Vector((0, 0, 0.1))).normalized()
        cur = cur + dd * (length / n)
        pts.append(cur.copy())
    radii = [F.lerp(r0, r1, (i / n) ** 0.85) * (1.0 + 0.12 * F.n3(i * 1.3, depth, rng.random(), 2)) for i in range(n + 1)]
    broken = depth >= 1 and rng.random() < 0.55
    rows = [0] * n
    if broken:
        rows[-1] = 1
    F.tube(bm, pts, radii, segs=segs, mat=0, cap_a=None, cap_b="flat" if broken else "apex", tip_b=r1 * 3.0,
           profile=bark_profile(rng.random() * 6), mat_rows=rows, twist=rng.uniform(-0.8, 0.8))
    if depth < 2:
        kids = 3 if depth == 0 else 2
        for c in range(kids):
            t = rng.uniform(0.35, 0.85)
            idx = min(int(t * n), n - 1)
            base = pts[idx].lerp(pts[idx + 1], t * n - idx)
            tangent = (pts[-1] - pts[0]).normalized()
            ax = rng.random() * F.TAU
            perp = tangent.cross(Vector((math.cos(ax), math.sin(ax), 0.4))).normalized()
            cd = (tangent * 0.55 + perp * rng.uniform(0.6, 1.0) + Vector((0, 0, 0.35))).normalized()
            limb(base, cd, length * rng.uniform(0.38, 0.55), radii[idx] * 0.62, max(radii[idx] * 0.2, 0.02), depth + 1, 5 if depth == 0 else 4)


# --- trunk (twisted, leaning) ---------------------------------------------------------------------------------
trunk_pts = F.catmull([(0, 0, -0.1), (0.05, 0.0, 0.7), (-0.12, 0.1, 1.4), (-0.02, 0.22, 2.1)], 4)
tr = [F.lerp(0.5, 0.26, (i / (len(trunk_pts) - 1)) ** 0.9) * (1.0 + 0.5 * math.exp(-i * 0.6)) for i in range(len(trunk_pts))]
F.tube(bm, trunk_pts, tr, segs=10, mat=0, cap_a="flat", cap_b=None, profile=bark_profile(1.0), twist=1.2,
       mat_rows=[0 for i in range(len(trunk_pts) - 1)])
fork = trunk_pts[-1]
# roots
for i in range(4):
    a = F.TAU * i / 4 + rng.uniform(-0.4, 0.4)
    d = Vector((math.cos(a), math.sin(a), 0))
    rp = F.catmull([d * 0.05 + Vector((0, 0, 1.0)), d * 0.4 + Vector((0, 0, 0.55)), d * 0.75 + Vector((0, 0, 0.18)), d * (0.95 + rng.random() * 0.25) + Vector((0, 0, -0.1))], 3)
    F.tube(bm, rp, [F.pw(i2 / (len(rp) - 1), [(0.0, 0.36), (0.5, 0.3), (1.0, 0.16)]) for i2 in range(len(rp))], segs=7, mat=0, cap_a=None, cap_b="flat",
           profile=bark_profile(2.0 + i), aspect=0.75)
# limbs
limb(fork, Vector((0.25, 0.1, 1.0)), 2.8, 0.28, 0.06, 0, 8)
limb(fork + Vector((0, 0, -0.1)), Vector((-0.85, 0.2, 0.7)), 2.2, 0.23, 0.05, 0, 8)
limb(fork + Vector((0, 0.0, -0.2)), Vector((0.5, -0.8, 0.6)), 2.0, 0.2, 0.05, 0, 8)

# weathered bark streaks (noise stretched along the trunk) on the lower trunk, roots and thick limbs: the bleached wood shows through elsewhere
for f in bm.faces:
    if f.material_index == 0:
        c = F.face_center(f)
        if c.z < 3.2 and F.fbm3(c.x * 3.4, c.y * 3.4, c.z * 0.5, 5.5, 2) > 0.24:
            f.material_index = 2
F.clean_mask(bm, 2, 0, 1, 3)
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_wood, m_dark, m_bark], smooth_deg=50)
F.finish(MID, [ob], "flora", ["desert", "barren"],
         F.vc({"shape": "cylinder", "radius": 0.5, "height": 2.2, "offset_y": 0.0}, OVR),
         tintable=[],
         notes="Bleached dead tree ~5 m, twisting trunk with 4 buttress roots, 3 forking limbs, broken stubs (dark cut ends = slot wood_dark), bark patches. "
               "Collider = trunk only (limbs are thin).")
