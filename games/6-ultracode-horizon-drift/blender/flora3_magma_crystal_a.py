import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector

ID = "magma_crystal_a"
col = L.fresh_collection(ID)
m_body = L.mat(ID + "_body", (0.55, 0.05, 0.01), roughness=0.25, emission=(1.0, 0.045, 0.002), emission_strength=2.2, specular=0.8)
m_facet = L.mat(ID + "_facet", (0.85, 0.12, 0.02), roughness=0.2, emission=(1.0, 0.10, 0.006), emission_strength=2.7, specular=0.8)
m_tip = L.mat(ID + "_tip", (1.0, 0.5, 0.08), roughness=0.2, emission=(1.0, 0.24, 0.02), emission_strength=3.6)
m_rock = L.mat(ID + "_rock", (0.05, 0.035, 0.03), roughness=0.92, specular=0.25)
m_glow = L.mat(ID + "_glow", (1.0, 0.2, 0.02), roughness=0.5, emission=(1.0, 0.1, 0.008), emission_strength=3.2)
mats = [m_body, m_facet, m_tip, m_rock, m_glow]
rg = random.Random(12)

cfg = [  # azimuth deg, tilt deg, length, radius
    (10, 7, 2.15, 0.30),
    (45, 22, 1.75, 0.23), (135, 27, 1.55, 0.21), (215, 21, 1.85, 0.25), (305, 30, 1.45, 0.20),
    (85, 42, 1.05, 0.16), (175, 48, 0.95, 0.15), (255, 45, 1.15, 0.17), (345, 50, 0.85, 0.14),
    (20, 60, 0.55, 0.11), (110, 63, 0.5, 0.10), (190, 58, 0.62, 0.11), (280, 64, 0.48, 0.10), (330, 70, 0.4, 0.09),
    (65, 20, 1.3, 0.17), (160, 30, 1.2, 0.16),
]
crys = []
for i, (az, tilt, ln, r) in enumerate(cfg):
    A, T = math.radians(az), math.radians(tilt)
    d = Vector((math.sin(T) * math.cos(A), math.sin(T) * math.sin(A), math.cos(T)))
    off = 0.15 + 0.35 * (tilt / 70.0)
    base = Vector((math.cos(A) * off, math.sin(A) * off, 0.05))
    if i == 0:
        base = Vector((0.0, 0.0, 0.05))
    crys.append(F.crystal(base, d, ln, r, sides=6, tip_frac=0.3, taper=0.88, mat=0, mat_tip=2, mat_alt=1, seed=100 + i,
                          jitter=0.14, two_stage=True, stage2=0.5))

base = F.rock_blob(1.0, 4, 0.22, 1.1, 4, (1.15, 1.0, 0.3), flat_bottom=0.15, ridged=0.5)
F.cell_plates(base, 7, seed=4, shrink=0.9, depth=0.35, centre=Vector((0, 0, 0.1)), mat_top=3, mat_wall=4, bulge=0.04, bulge_rand=0.03)
small_rocks = []
for i, (a, d, r) in enumerate([(0.6, 1.0, 0.25), (2.4, 1.05, 0.3), (4.2, 0.95, 0.22)]):
    small_rocks.append(F.rock_blob(r, 2, 0.35, 1.5, 50 + i, (1, 1, 0.7), flat_bottom=0.2, mat=3, center=(math.cos(a) * d, math.sin(a) * d, 0)))

bm = F.join(*crys, base, *small_rocks)
ob = F.finish(ID, bm, col, mats, flat=True)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "rock", ["volcanic"], {"shape": "cylinder", "radius": 0.9, "height": 1.8, "offset_y": 0.0},
                 tintable=["body", "facet", "tip"], notes="Cluster of glowing red-orange hex crystals (flat shaded, emissive body/facet/tip) on a dark cracked base. ~2.2 m tall. Origin at ground centre. Good for a light source (OmniLight orange at (0,1.0,0)).")
L.save_blend()
