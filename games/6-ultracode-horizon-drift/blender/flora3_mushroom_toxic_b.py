import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import flora3_mush as M; importlib.reload(M)
import bmesh
from mathutils import Vector

ID = "mushroom_toxic_b"
col = L.fresh_collection(ID)
m_stem = L.mat(ID + "_stem", (0.62, 0.66, 0.42), roughness=0.7, specular=0.3)
m_cap = L.mat(ID + "_cap", (0.10, 0.50, 0.06), roughness=0.4, specular=0.55)
m_glow = L.mat(ID + "_glow", (0.7, 0.10, 1.0), roughness=0.4, emission=(0.65, 0.03, 1.0), emission_strength=2.8)
m_band = L.mat(ID + "_band", (0.05, 0.22, 0.05), roughness=0.6, specular=0.3)
mats = [m_stem, m_cap, m_glow, m_band]
MI = dict(stem=0, cap=1, glow=2, band=3)

# (azimuth, dist, height, cap radius, bend, style, tilt x, tilt y)
cfg = [(0.0, 0.0, 2.05, 0.62, (0.15, 0.05), "cone", 0.0, 0.0),
       (1.0, 0.7, 1.45, 0.5, (0.2, 0.1), "dome", 0.18, -0.1),
       (2.2, 0.65, 1.2, 0.46, (-0.1, 0.1), "bell", -0.12, 0.2),
       (3.3, 0.75, 1.7, 0.52, (0.0, -0.15), "flat", 0.1, 0.18),
       (4.3, 0.6, 0.95, 0.38, (0.1, 0.1), "dome", -0.2, -0.1),
       (5.3, 0.8, 0.7, 0.3, (-0.1, 0.0), "cone", 0.2, 0.15),
       (0.5, 1.3, 0.5, 0.26, (0.0, 0.05), "flat", -0.2, 0.2),
       (3.8, 1.35, 0.42, 0.22, (0.05, 0.0), "dome", 0.1, -0.15)]
parts = []
for i, (a, d, h, r, bend, st, tx, ty) in enumerate(cfg):
    chf = {"cone": 1.1, "bell": 0.95, "flat": 0.32, "dome": 0.6}[st]
    parts.append(M.mushroom((math.cos(a) * d, math.sin(a) * d, 0), h, r, bend=bend, seed=40 + i, style=st, spots=5 if h > 1 else 2, MI=MI,
                            segs=10, stem_segs=7, skirt=(h > 1.6), tilt=(tx, ty), stem_r=r * 0.2, bulb=1.6, cap_h=r * chf, spot_scale=2.4))
parts.append(M.mycelium((0.1, 0.0, 0), 0.85, MI["band"], MI["glow"], seed=5, n=4, bump=0.3))
bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50, floor=-0.05)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["toxic", "swamp"], {"shape": "cylinder", "radius": 0.9, "height": 1.2, "offset_y": 0.0},
                 tintable=["cap", "glow"], notes="Cluster of 8 toxic mushrooms ~2 m tall (green caps, violet emissive 'glow' spots/gills) with mycelium mound. Origin at cluster centre on the ground.")
L.save_blend()
