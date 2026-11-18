import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix

ID = "bulb_plant_a"
col = L.fresh_collection(ID)
m_leaf = L.mat(ID + "_leaf", (0.20, 0.42, 0.04), roughness=0.55, specular=0.4)
m_stem = L.mat(ID + "_stem", (0.42, 0.55, 0.18), roughness=0.6, specular=0.3)
m_bulb = L.mat(ID + "_bulb", (0.20, 0.30, 1.0), roughness=0.25, emission=(0.05, 0.16, 1.0), emission_strength=2.6, specular=0.7)
m_calyx = L.mat(ID + "_calyx", (0.10, 0.28, 0.06), roughness=0.55, specular=0.4)
mats = [m_leaf, m_stem, m_bulb, m_calyx]
LEAF, STEM, BULB, CALYX = 0, 1, 2, 3
rg = random.Random(9)
parts = []

# --- rosette of broad drooping leaves ---------------------------------------------------------------------------
for i in range(9):
    a = i * math.tau / 9 + rg.uniform(-0.2, 0.2)
    el = math.radians(rg.uniform(22, 50))
    d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    ln = rg.uniform(0.7, 1.05)
    parts.append(F.leaf((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.04), d, ln, rg.uniform(0.26, 0.36), bend=rg.uniform(0.4, 0.75),
                        mat=LEAF, segs=6, fold=0.3, sideways=rg.uniform(-0.2, 0.2), double=True,
                        width_fn=lambda t: (math.sin(math.pi * min(1.0, 0.18 + t * 0.85)) ** 0.7)))


def lantern(pos, direction, R, Ln, seed, sepals=5):
    r_ = random.Random(seed)
    prof = [(0.03 * R, 0.0), (0.38 * R, 0.1 * Ln), (0.82 * R, 0.33 * Ln), (1.0 * R, 0.58 * Ln), (0.86 * R, 0.82 * Ln), (0.48 * R, 0.96 * Ln), (0.0, Ln)]
    b = F.lathe(prof, segs=12, mat=BULB, ring_fn=lambda i, k, a: 1.0 + 0.06 * math.sin(a * 6 + seed))
    out = [b]
    for k in range(sepals):
        a = k * math.tau / sepals + r_.uniform(-0.1, 0.1)
        d = Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 0.8)).normalized()
        out.append(F.leaf((math.cos(a) * 0.03 * R, math.sin(a) * 0.03 * R, 0.0), d, Ln * 0.55, R * 0.55, bend=-0.25, mat=CALYX, segs=3,
                          fold=0.5, double=True, up=(0, 0, 1)))
    bm = F.join(*out)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(pos)) @ F.rot_to(direction), verts=bm.verts)
    return bm


# --- arching stems with hanging glowing bulbs ----------------------------------------------------------------------
cfg = [(0.3, 0.55, 0.95, 0.19, 0.34), (1.45, 0.45, 0.75, 0.16, 0.28), (2.6, 0.6, 1.0, 0.2, 0.36), (3.8, 0.4, 0.7, 0.15, 0.26),
       (4.8, 0.5, 0.85, 0.17, 0.3), (5.6, 0.35, 0.55, 0.12, 0.2)]
for i, (a, reach, hgt, R, Ln) in enumerate(cfg):
    ca, sa = math.cos(a), math.sin(a)
    P = lambda r, z: Vector((ca * r, sa * r, z))
    p = F.bez(P(0.04, 0.0), P(0.06, hgt * 0.8), P(reach * 0.8, hgt * 1.12), P(reach, hgt * 0.78), 7)
    parts.append(F.tube(p, [0.05, 0.042, 0.036, 0.032, 0.03, 0.03, 0.03, 0.03], segs=6, mat=STEM, rough=0.05, seed=i, cap_start=True, cap_end=False))
    d = (p[-1] - p[-2]).normalized()
    parts.append(lantern(p[-1] - d * 0.02, d, R, Ln, 30 + i))

# small buds low in the rosette
for i, (a, dd) in enumerate([(0.9, 0.38), (2.1, 0.3), (3.3, 0.4), (4.4, 0.33), (5.2, 0.42)]):
    parts.append(L.bm_sphere(0.05, subdiv=1, matrix=L.xf((math.cos(a) * dd, math.sin(a) * dd, 0.07), (0, 0, 0), (1, 1, 1.2)), mat_index=BULB))
    parts.append(F.tube([(math.cos(a) * dd, math.sin(a) * dd, 0.0), (math.cos(a) * dd, math.sin(a) * dd, 0.06)], [0.018, 0.015], segs=4, mat=STEM, cap_start=False))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50, floor=-0.03)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["toxic", "swamp", "exotic"], {"shape": "cylinder", "radius": 0.4, "height": 0.8, "offset_y": 0.0},
                 tintable=["leaf", "bulb"], notes="Lantern bulb plant ~1 m: leaf rosette + 6 arching stems with hanging glowing blue bulbs (emissive 'bulb'). Origin at base centre.")
L.save_blend()
