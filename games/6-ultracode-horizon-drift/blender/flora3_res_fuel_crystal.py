import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix

ID = "res_fuel_crystal"
col = L.fresh_collection(ID)
m_body = L.mat(ID + "_body", (0.20, 0.55, 1.0), roughness=0.15, emission=(0.05, 0.40, 1.0), emission_strength=2.6, specular=0.9)
m_facet = L.mat(ID + "_facet", (0.45, 0.80, 1.0), roughness=0.12, emission=(0.20, 0.65, 1.0), emission_strength=3.4, specular=0.9)
m_tip = L.mat(ID + "_tip", (0.85, 0.95, 1.0), roughness=0.1, emission=(0.65, 0.88, 1.0), emission_strength=4.2)
m_rock = L.mat(ID + "_rock", (0.05, 0.07, 0.14), roughness=0.8, specular=0.4)
mats = [m_body, m_facet, m_tip, m_rock]
rg = random.Random(44)
parts = []

# (azimuth deg, tilt deg, length, radius, offset from centre)
cfg = [
    (0, 6, 1.32, 0.15, 0.0),
    (35, 20, 1.05, 0.12, 0.16), (130, 24, 1.15, 0.13, 0.17), (215, 18, 0.95, 0.11, 0.17), (300, 27, 1.0, 0.12, 0.18),
    (80, 40, 0.7, 0.09, 0.26), (170, 44, 0.62, 0.085, 0.27), (255, 38, 0.75, 0.095, 0.27), (345, 46, 0.6, 0.08, 0.28),
    (15, 62, 0.4, 0.06, 0.34), (105, 66, 0.34, 0.055, 0.34), (195, 60, 0.42, 0.06, 0.36), (285, 68, 0.32, 0.05, 0.36),
]
shafts = []
for i, (az, tilt, ln, r, off) in enumerate(cfg):
    A, T = math.radians(az), math.radians(tilt)
    d = Vector((math.sin(T) * math.cos(A), math.sin(T) * math.sin(A), math.cos(T)))
    base = Vector((math.cos(A) * off, math.sin(A) * off, 0.04))
    parts.append(F.crystal(base, d, ln, r, sides=6, tip_frac=0.34, taper=0.92, mat=0, mat_tip=2, mat_alt=1, seed=200 + i, jitter=0.08,
                           two_stage=True, stage2=0.45))
    shafts.append((base, d, ln, r, i))
# small shards sprouting from the shafts of the bigger crystals
for (base, d, ln, r, i) in shafts[:5]:
    for j in range(2):
        t = rg.uniform(0.25, 0.5)
        p = base + d * ln * t
        side = d.cross(Vector((rg.uniform(-1, 1), rg.uniform(-1, 1), rg.uniform(-1, 1)))).normalized()
        nd = (d * 0.45 + side * 0.9).normalized()
        parts.append(F.crystal(p, nd, ln * rg.uniform(0.22, 0.34), r * 0.5, sides=6, tip_frac=0.4, taper=0.85, mat=0, mat_tip=2, mat_alt=1,
                               seed=300 + i * 3 + j, two_stage=False))
# rock bed
bed = F.rock_blob(0.62, 3, 0.3, 1.2, 8, (1.0, 1.0, 0.3), flat_bottom=0.2, ridged=0.5, mat=3)
parts.append(bed)
for i, (a, d, r) in enumerate([(0.5, 0.65, 0.17), (2.0, 0.6, 0.14), (3.5, 0.68, 0.19), (5.0, 0.6, 0.13)]):
    parts.append(F.rock_blob(r, 2, 0.35, 1.5, 70 + i, (1, 1, 0.75), flat_bottom=0.2, mat=3, center=(math.cos(a) * d, math.sin(a) * d, 0)))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, flat=True)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "resource", ["any"], {"shape": "cylinder", "radius": 0.55, "height": 1.2, "offset_y": 0.0},
                 tintable=[], notes="Resource 'Zyrite' (fuel): slender blue-white glowing hex crystal cluster (emissive body/facet/tip, strength 2.6-4.2) on a dark rock bed. ~1.3 m. Origin at ground centre. Add a cyan OmniLight at (0,0.7,0) if desired.")
L.save_blend()
