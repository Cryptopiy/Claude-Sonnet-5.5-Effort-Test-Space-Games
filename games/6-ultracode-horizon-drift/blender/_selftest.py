import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L
importlib.reload(L)
from mathutils import Vector

col = L.fresh_collection("selftest_rock")
m_rock = L.mat("selftest_rock_mat", (0.35, 0.33, 0.30), roughness=0.9)
m_glow = L.mat("selftest_glow", (0.1, 0.5, 1.0), emission=(0.1, 0.6, 1.0), emission_strength=4.0)
bm = L.bm_sphere(1.0, subdiv=3)
L.noise_displace(bm, amount=0.25, scale=1.3, seed=3)
for v in bm.verts:
    v.co.z *= 0.7
bm2 = L.bm_cylinder(0.15, 0.02, 1.5, segs=8, matrix=L.xf((0.3, 0.1, 0.5), (0.2, 0.3, 0)), mat_index=1)
bm = L.bm_merge(bm, bm2)
ob = L.obj_from_bm("selftest_rock", bm, col, [m_rock, m_glow], smooth=True)
L.report([ob], "selftest_rock")
paths = L.preview([ob], "selftest_rock")
print(paths)
print(L.montage(paths, "selftest_rock_sheet", cols=3))
print(L.export_glb([ob], "_selftest_rock.glb"))
