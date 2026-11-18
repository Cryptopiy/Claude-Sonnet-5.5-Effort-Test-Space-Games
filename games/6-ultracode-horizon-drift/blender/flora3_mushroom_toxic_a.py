import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import flora3_mush as M; importlib.reload(M)
import bmesh
from mathutils import Vector

ID = "mushroom_toxic_a"
col = L.fresh_collection(ID)
m_stem = L.mat(ID + "_stem", (0.42, 0.62, 0.26), roughness=0.7, specular=0.3)
m_cap = L.mat(ID + "_cap", (0.26, 0.03, 0.48), roughness=0.4, specular=0.55)
m_glow = L.mat(ID + "_glow", (0.30, 0.95, 0.08), roughness=0.4, emission=(0.25, 1.0, 0.05), emission_strength=3.0)
m_band = L.mat(ID + "_band", (0.14, 0.02, 0.22), roughness=0.6, specular=0.3)
mats = [m_stem, m_cap, m_glow, m_band]
MI = dict(stem=0, cap=1, glow=2, band=3)

parts = []
parts.append(M.mushroom((0, 0, 0), 4.2, 1.95, bend=(0.45, 0.15), seed=3, style="dome", spots=15, MI=MI, spot_big=1.0, segs=18))
sat = [(2.0, 1.45, 1.5, 0.62, (0.15, 0.05), "dome", 0.2, 0.1), (4.2, 1.5, 1.0, 0.42, (-0.1, 0.1), "bell", -0.1, 0.25),
       (0.9, -1.6, 1.8, 0.7, (-0.2, 0.0), "cone", 0.15, -0.2), (5.3, -1.0, 0.8, 0.36, (0.1, -0.1), "flat", -0.1, 0.1),
       (3.3, -1.7, 0.6, 0.3, (0.0, 0.05), "dome", 0.2, -0.1)]
for i, (a, d, h, r, bend, st, tx, ty) in enumerate(sat):
    parts.append(M.mushroom((math.cos(a) * d, math.sin(a) * d, 0), h, r, bend=bend, seed=20 + i, style=st, spots=5, MI=MI, segs=11, stem_segs=8,
                            skirt=(h > 1.4), tilt=(tx, ty)))
parts.append(M.mycelium((0, 0, 0), 1.2, MI["band"], MI["glow"], seed=9, n=6))
bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50, floor=-0.05)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["toxic", "swamp", "exotic"], {"shape": "cylinder", "radius": 0.45, "height": 3.0, "offset_y": 0.0},
                 tintable=["cap", "glow"], notes="Giant toxic mushroom ~4.2 m (purple cap, lime glowing spots/gills/rim = emissive 'glow') with 5 small satellite mushrooms + mycelium roots. Origin at stem base.")
L.save_blend()
