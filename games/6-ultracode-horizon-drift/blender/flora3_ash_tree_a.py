import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix, noise

ID = "ash_tree_a"
col = L.fresh_collection(ID)
m_bark = L.mat(ID + "_bark", (0.075, 0.07, 0.07), roughness=0.95, specular=0.2)
m_leaf = L.mat(ID + "_leaf", (0.17, 0.19, 0.17), roughness=0.9, specular=0.15)
m_leaf2 = L.mat(ID + "_leaf2", (0.085, 0.095, 0.09), roughness=0.9, specular=0.15)
m_ember = L.mat(ID + "_ember", (1.0, 0.25, 0.03), roughness=0.4, emission=(1.0, 0.12, 0.008), emission_strength=3.2)
mats = [m_bark, m_leaf, m_leaf2, m_ember]
BARK, LEAF, LEAF2, EMBER = range(4)
rg = random.Random(77)
parts = []


def pad(center, R, seed, layers=3, tilt=(0.0, 0.0)):
    """Layered flat canopy discs (acacia / ash-cloud look) + hanging ember berries."""
    r_ = random.Random(seed)
    out = []
    for j in range(layers):
        Rj = R * (1.0 - 0.22 * j) * r_.uniform(0.92, 1.05)
        zj = 0.34 * j
        prof = [(0.0, zj - 0.02), (0.45 * Rj, zj - 0.09), (0.9 * Rj, zj - 0.02), (1.0 * Rj, zj + 0.08), (0.82 * Rj, zj + 0.26),
                (0.5 * Rj, zj + 0.34), (0.0, zj + 0.38)]
        sd = r_.uniform(0, 10)
        d = F.lathe(prof, segs=14, mat_fn=lambda i: [LEAF2, LEAF2, LEAF2, LEAF, LEAF, LEAF][i],
                    ring_fn=lambda i, k, a, sd=sd: 1.0 + 0.16 * noise.noise(Vector((math.cos(a) * 1.6 + sd, math.sin(a) * 1.6, i * 0.4))) + 0.07 * math.sin(a * 7 + sd),
                    z_fn=lambda i, k, a, sd=sd: 0.06 * noise.noise(Vector((math.cos(a) * 2.2 + sd, math.sin(a) * 2.2, i))),
                    center=(r_.uniform(-0.18, 0.18) * R, r_.uniform(-0.18, 0.18) * R, 0))
        out.append(d)
    # hanging strands with ember berries below the rim
    for j in range(6):
        a = r_.uniform(0, math.tau)
        rr = R * r_.uniform(0.55, 0.95)
        p0 = Vector((math.cos(a) * rr, math.sin(a) * rr, -0.07))
        ln = r_.uniform(0.35, 0.8)
        p1 = p0 + Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, -ln))
        out.append(F.tube([p0, p0.lerp(p1, 0.5) + Vector((0.03, 0, 0)), p1], [0.018, 0.014, 0.012], segs=4, mat=BARK, cap_start=False))
        out.append(L.bm_sphere(0.07, subdiv=1, matrix=L.xf(p1 + Vector((0, 0, -0.02)), (0, 0, 0), (1, 1, 1.25)), mat_index=EMBER))
    bm = F.join(*out)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ L.xf((0, 0, 0), (tilt[0], tilt[1], r_.uniform(0, 3))), verts=bm.verts)
    return bm


def branch(p0, d, length, r0, seed, n=5, droop=0.0):
    r_ = random.Random(seed)
    cur = Vector(p0)
    dd = Vector(d).normalized()
    pts = [cur.copy()]
    for i in range(n):
        dd = (dd + Vector((r_.uniform(-1, 1), r_.uniform(-1, 1), r_.uniform(-0.15, 0.3))) * 0.2 - Vector((0, 0, droop * 0.1))).normalized()
        cur = cur + dd * (length / n)
        pts.append(cur.copy())
    radii = [r0 * (1 - 0.65 * i / n) for i in range(n + 1)]
    parts.append(F.tube(pts, radii, segs=6, mat=BARK, rough=0.12, seed=seed, cap_start=False,
                        ring_fn=lambda i, k, a: 1.0 + 0.07 * math.sin(a * 4 + i)))
    return pts


# --- trunk ---------------------------------------------------------------------------------------------------------------
tp = F.bez((0, 0, -0.1), (0.5, 0.2, 1.4), (-0.5, 0.1, 2.5), (0.15, 0.0, 3.5), 9)
rad = [0.34 * (1 - 0.42 * (i / 9)) + 0.42 * (1 - i / 9) ** 6 for i in range(10)]
trunk = F.tube(tp, rad, segs=10, mat=BARK, rough=0.1, seed=4, ring_fn=lambda i, k, a: 1.0 + 0.09 * math.sin(a * 5 + i * 0.7) + 0.04 * math.sin(a * 9), cap_start=False)
parts.append(trunk)
# roots
for i in range(5):
    a = i * math.tau / 5 + 0.3
    ca, sa = math.cos(a), math.sin(a)
    pts = F.bez((ca * 0.2, sa * 0.2, 0.7), (ca * 0.5, sa * 0.5, 0.45), (ca * 0.85, sa * 0.85, 0.15), (ca * 1.3, sa * 1.3, -0.05), 5)
    parts.append(F.tube(pts, [0.2, 0.16, 0.12, 0.085, 0.055, 0.03], segs=5, mat=BARK, rough=0.15, seed=i, cap_start=False))

# --- limbs with canopies --------------------------------------------------------------------------------------------------
limbs = [(30, 40, 2.6, 0.2, 2.9), (150, 38, 2.4, 0.19, 3.0), (255, 45, 2.2, 0.18, 3.2), (330, 30, 1.9, 0.16, 2.1), (90, 33, 1.9, 0.16, 2.3), (200, 28, 1.6, 0.14, 1.7)]
for i, (az, el, ln, r0, z0) in enumerate(limbs):
    A, E = math.radians(az), math.radians(el)
    d = (math.cos(A) * math.cos(E), math.sin(A) * math.cos(E), math.sin(E))
    c = min(tp, key=lambda q: abs(q.z - z0))
    pts = branch(c, d, ln, r0, 50 + i)
    tipp = pts[-1]
    parts.append(pad(tipp + Vector((0, 0, 0.12)), rg.uniform(1.2, 1.55) * (1.0 if ln > 2 else 0.8), 70 + i, layers=3 if ln > 2 else 2,
                     tilt=(rg.uniform(-0.12, 0.12), rg.uniform(-0.12, 0.12))))
# crown on top of the trunk
top = tp[-1]
branch(top + Vector((0, 0, -0.1)), (0.1, 0.0, 1.0), 1.4, 0.16, 99)
parts.append(pad(top + Vector((0.15, 0.0, 1.35)), 1.7, 90, layers=3))

# ash drift at the base
parts.append(F.rock_blob(1.2, 3, 0.25, 1.0, 12, (1.0, 1.0, 0.18), flat_bottom=0.1, mat=LEAF2))
bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50, floor=-0.1)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["volcanic"], {"shape": "cylinder", "radius": 0.5, "height": 3.2, "offset_y": 0.0},
                 tintable=["leaf"], notes="Ash tree ~7 m: sinuous grey trunk with layered flat ash-grey canopy pads and hanging ember berries (emissive 'ember'). Origin at trunk base.")
L.save_blend()
