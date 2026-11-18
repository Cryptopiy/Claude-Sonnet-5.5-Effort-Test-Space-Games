import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix

ID = "res_bulb_plant"
col = L.fresh_collection(ID)
m_leaf = L.mat(ID + "_leaf", (0.07, 0.30, 0.04), roughness=0.5, specular=0.45)
# QA pass 2: sac emission re-hued (more green, less red) + lower strength so Godot's filmic tonemap/bloom keeps the yellow-green hue; bigger orange tips
m_sac = L.mat(ID + "_sac", (0.42, 0.85, 0.05), roughness=0.25, emission=(0.30, 1.0, 0.02), emission_strength=2.2, specular=0.7)
m_tip = L.mat(ID + "_tip", (1.0, 0.40, 0.02), roughness=0.3, emission=(1.0, 0.26, 0.01), emission_strength=4.0)
m_stem = L.mat(ID + "_stem", (0.30, 0.38, 0.06), roughness=0.6, specular=0.3)
mats = [m_leaf, m_sac, m_tip, m_stem]
LEAF, SAC, TIP, STEM = 0, 1, 2, 3
rg = random.Random(15)
parts = []

# --- spiky rosette leaves wrapping the sacs --------------------------------------------------------------------
for i in range(9):
    a = i * math.tau / 9 + rg.uniform(-0.12, 0.12)
    el = math.radians(rg.uniform(42, 72))
    d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    ln = rg.uniform(0.55, 0.85)
    parts.append(F.leaf((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.02), d, ln, rg.uniform(0.15, 0.22), bend=rg.uniform(0.15, 0.45),
                        mat=LEAF, segs=5, fold=0.45, sideways=rg.uniform(-0.1, 0.1), double=True,
                        width_fn=lambda t: (math.sin(math.pi * min(1.0, 0.12 + t * 0.88)) ** 0.6) * (1 - 0.25 * t)))


def sac(pos, direction, R, h, seed):
    prof = [(0.0, 0.0), (0.3 * R, 0.04 * h), (0.75 * R, 0.2 * h), (1.0 * R, 0.48 * h), (0.88 * R, 0.76 * h), (0.5 * R, 0.94 * h),
            (0.27 * R, 1.01 * h), (0.22 * R, 1.13 * h), (0.0, 1.27 * h)]
    b = F.lathe(prof, segs=11, mat_fn=lambda i: TIP if i >= 6 else SAC, ring_fn=lambda i, k, a: 1.0 + 0.045 * math.sin(a * 5 + seed))
    bmesh.ops.transform(b, matrix=Matrix.Translation(Vector(pos)) @ F.rot_to(direction), verts=b.verts)
    return b


# central big sac + ring of smaller ones, each on a short stalk
cfg = [(0.0, 0.0, 0.33, 0.2, 0.3, 0.0), (0.3, 0.2, 0.28, 0.14, 0.22, 0.3), (1.5, 0.22, 0.2, 0.12, 0.2, 0.35), (2.7, 0.2, 0.3, 0.13, 0.22, 0.3),
       (3.9, 0.22, 0.17, 0.11, 0.18, 0.4), (5.0, 0.2, 0.25, 0.15, 0.22, 0.3), (2.1, 0.32, 0.1, 0.085, 0.12, 0.6)]
for i, (a, rad, hgt, R, h, lean) in enumerate(cfg):
    ca, sa = math.cos(a), math.sin(a)
    base = Vector((ca * rad * 0.55, sa * rad * 0.55, 0.0))
    top = Vector((ca * rad, sa * rad, hgt))
    mid = (base + top) * 0.5 + Vector((ca * 0.03, sa * 0.03, 0))
    st = F.bez(base, base + Vector((0, 0, hgt * 0.5)), mid + Vector((0, 0, hgt * 0.35)), top, 4)
    parts.append(F.tube(st, [0.05, 0.043, 0.04, 0.04, 0.04], segs=5, mat=STEM, rough=0.05, seed=i, cap_start=True, cap_end=False))
    d = Vector((ca * lean, sa * lean, 1.0)).normalized()
    parts.append(sac(top - d * 0.02, d, R, h, 5 + i))

# little bud nubs around the root
for i in range(6):
    a = rg.uniform(0, math.tau)
    dd = rg.uniform(0.28, 0.42)
    r = rg.uniform(0.035, 0.06)
    parts.append(L.bm_sphere(r, subdiv=1, matrix=L.xf((math.cos(a) * dd, math.sin(a) * dd, r * 0.8), (0, 0, 0), (1, 1, 1.1)), mat_index=SAC))
parts.append(F.rock_blob(0.22, 2, 0.2, 1.5, 3, (1.0, 1.0, 0.45), flat_bottom=0.1, mat=STEM))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "resource", ["any"], {"shape": "cylinder", "radius": 0.4, "height": 0.7, "offset_y": 0.0},
                 tintable=[], notes="Resource 'Sodium' plant ~0.8 m: spiky green rosette around a cluster of glowing yellow-green sacs with orange glowing tips (emissive 'sac' 2.2, 'tip' 4.0). Origin at base centre.")
L.save_blend()
