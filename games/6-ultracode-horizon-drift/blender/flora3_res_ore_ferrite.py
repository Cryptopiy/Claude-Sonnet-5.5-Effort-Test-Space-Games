import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix

ID = "res_ore_ferrite"
col = L.fresh_collection(ID)
m_rock = L.mat(ID + "_rock", (0.20, 0.205, 0.22), roughness=0.85, specular=0.35)
m_ore = L.mat(ID + "_ore", (0.95, 0.32, 0.04), metallic=0.55, roughness=0.3, emission=(1.0, 0.11, 0.008), emission_strength=2.0, specular=0.8)
m_nug = L.mat(ID + "_nugget", (1.0, 0.42, 0.08), metallic=0.6, roughness=0.22, emission=(1.0, 0.17, 0.012), emission_strength=2.2, specular=0.9)
m_dark = L.mat(ID + "_dark", (0.08, 0.08, 0.095), roughness=0.9, specular=0.3)
mats = [m_rock, m_ore, m_nug, m_dark]
rg = random.Random(31)

# main boulder: angular, plated with orange metal in the seams
rock = F.rock_blob(0.62, 3, 0.42, 1.5, 14, (1.0, 0.92, 1.3), flat_bottom=0.3, ridged=0.7)
cen = Vector((0, 0, 0.5))
F.cell_plates(rock, 9, seed=6, shrink=0.9, depth=0.28, centre=cen, mat_top=0, mat_wall=1, bulge=0.025, bulge_rand=0.02)

# secondary rocks
small = []
for i, (a, d, r, sc) in enumerate([(0.9, 0.78, 0.24, (1, 0.9, 0.8)), (2.5, 0.72, 0.18, (1.1, 0.9, 0.9)), (4.3, 0.74, 0.26, (0.9, 1.0, 0.8)), (5.6, 0.6, 0.12, (1, 1, 1))]):
    sb = F.rock_blob(r, 2, 0.35, 1.5, 60 + i, sc, flat_bottom=0.25, ridged=0.6, mat=3 if i % 2 else 0, center=(math.cos(a) * d, math.sin(a) * d, 0))
    small.append(sb)

# ore outcrops: small clusters of metallic crystals sticking out of the rock surface
bvh = F.bvh_of(rock)
verts = [v.co.copy() for v in rock.verts]
nug = []
for c in range(4):
    v = rg.choice([q for q in verts if q.z > 0.3])
    p, n, idx, dist = bvh.find_nearest(v)
    n = (n + Vector((0, 0, 0.35))).normalized()
    for j in range(rg.randint(3, 4)):
        size = rg.uniform(0.32, 0.5) * (1.0 if j == 0 else 0.66)
        jit = Vector((rg.uniform(-1, 1), rg.uniform(-1, 1), rg.uniform(-1, 1))) * 0.35
        d = (n + jit).normalized()
        base = p + Vector((rg.uniform(-0.07, 0.07), rg.uniform(-0.07, 0.07), rg.uniform(-0.07, 0.07))) - d * 0.05
        nug.append(F.crystal(base, d, size, size * 0.3, sides=4, tip_frac=0.38, taper=0.75, mat=2, mat_alt=1, seed=c * 7 + j, two_stage=False, jitter=0.08))
# a few cube nuggets lodged in the surface
for i in range(6):
    v = rg.choice([q for q in verts if q.z > 0.1])
    p, n, idx, dist = bvh.find_nearest(v)
    size = rg.uniform(0.07, 0.13)
    bx = L.bm_box((size, size, size * rg.uniform(0.9, 1.4)), mat_index=2)
    m = Matrix.Translation(p + n * size * 0.1) @ F.rot_to(n) @ L.xf((0, 0, 0), (0, 0, rg.uniform(0, 3)))
    bmesh.ops.transform(bx, matrix=m, verts=bx.verts)
    nug.append(bx)

bm = F.join(rock, *small, *nug)
ob = F.finish(ID, bm, col, mats, flat=True)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "resource", ["any"], {"shape": "sphere", "radius": 0.7, "offset_y": 0.0},
                 tintable=[], notes="Resource 'Ferrite': grey faceted boulder with metallic orange veins and nugget crystals (emissive 'ore' 2.0 / 'nugget' 2.2, pickup highlight). ~1.1 m. Origin at ground centre. Pickup radius ~1.2 m.")
L.save_blend()
