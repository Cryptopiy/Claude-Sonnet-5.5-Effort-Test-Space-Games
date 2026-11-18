import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector

ID = "rock_lava_a"
col = L.fresh_collection(ID)
m_rock = L.mat(ID + "_rock", (0.07, 0.052, 0.045), roughness=0.9, specular=0.3)
m_glow = L.mat(ID + "_glow", (1.0, 0.2, 0.02), roughness=0.5, emission=(1.0, 0.11, 0.008), emission_strength=3.3)
m_hot = L.mat(ID + "_hot", (1.0, 0.55, 0.06), roughness=0.5, emission=(1.0, 0.30, 0.025), emission_strength=4.2)
mats = [m_rock, m_glow, m_hot]


def plated_rock(radius, scale, seed, cells, subdiv=3, amount=0.3, shrink=0.9, depth=0.22, center=(0, 0, 0), flat=0.4, bulge=0.06, ridged=0.7):
    bm = F.rock_blob(radius, subdiv, amount, 1.1, seed, scale, flat_bottom=flat, ridged=ridged)
    cen = Vector((0, 0, 0))
    for v in bm.verts:
        cen += v.co
    cen /= len(bm.verts)
    F.cell_plates(bm, cells, seed=seed, shrink=shrink, depth=depth, centre=cen, mat_top=0, mat_wall=1, bulge=bulge, bulge_rand=bulge * 0.5)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return bm


big = plated_rock(1.25, (1.0, 0.95, 1.25), 5, 14, subdiv=4, amount=0.42, shrink=0.92, depth=0.3, bulge=0.16)
parts = [big]
for i, (ang, dist, rad, cells, sc) in enumerate([(0.7, 1.45, 0.5, 4, (1.0, 0.8, 0.85)), (2.7, 1.35, 0.4, 4, (1.1, 0.9, 0.9)),
                                                 (4.5, 1.4, 0.55, 5, (0.9, 1.1, 0.8))]):
    s = plated_rock(rad, sc, 20 + i, cells, subdiv=2, amount=0.38, shrink=0.9, depth=0.2, bulge=0.03, ridged=0.8,
                    center=(math.cos(ang) * dist, math.sin(ang) * dist, 0))
    parts.append(s)
bm = F.join(*parts)
for f in bm.faces:
    if f.material_index == 1:
        c = f.calc_center_median()
        if c.z > 1.1 and abs(c.x) < 1.3 and abs(c.y) < 1.3:
            f.material_index = 2
ob = F.finish(ID, bm, col, mats, smooth_deg=45, floor=-0.1)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "rock", ["volcanic"], {"shape": "sphere", "radius": 1.15, "offset_y": 0.3},
                 tintable=["glow", "hot"], notes="Dark basalt plates separated by glowing V-grooves (emissive); origin at ground centre; rotate freely around Y.")
L.save_blend()
