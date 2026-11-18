"""flora2 / rock_moon_c : ~4 m elongated slab outcrop (cleaved, stepped, cratered) with pale mineral banding and scattered chips."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

MID = "rock_moon_c"
rng = random.Random(8303)
col = L.fresh_collection(MID)
m_rock = L.mat(MID + "_rock", F.hexcol("#52535b"), roughness=0.95)
m_dark = L.mat(MID + "_rock_dark", F.hexcol("#2c2d35"), roughness=0.95)
m_dust = L.mat(MID + "_dust", F.hexcol("#76757b"), roughness=1.0)
m_vein = L.mat(MID + "_vein", F.hexcol("#7d88a0"), roughness=0.55, metallic=0.3)

bm = F.faceted_rock((2.3, 1.25, 1.15), 4, 41, 0.22, 1.0, planes=14, plane_dist=0.68, up_bias=0.45, rng=rng, bottom=0.55, sink=0.1,
                    craters=[(2, 0.45, 0.6, 0.15), (3, 0.17, 0.28, 0.08)], ridged=0.35, fine=(0.05, 4.5))
# a stepped ledge: a second slab leaning against the first
ledge = F.faceted_rock((1.3, 0.8, 0.55), 3, 6, 0.2, 1.3, planes=7, plane_dist=0.72, up_bias=0.3, rng=rng, bottom=0.5, sink=0.04)
for v in ledge.verts:
    v.co += Vector((-1.3, 1.35, 0.0))
bm = F.merge(bm, ledge)
for (cx, cy, rr, sd) in ((2.2, -0.8, 0.45, 5), (-2.3, -0.9, 0.3, 7), (1.9, 1.1, 0.25, 9), (0.4, -1.45, 0.2, 10)):
    sm = F.faceted_rock((rr, rr * 0.8, rr * 0.65), 3, sd, 0.3, 1.5, planes=5, plane_dist=0.75, up_bias=0.2, rng=rng, bottom=0.45, sink=0.03)
    for v in sm.verts:
        v.co += Vector((cx, cy, 0))
    bm = F.merge(bm, sm)
F.vein_bands(bm, 3, (0.5, 0.15, 0.85), 1.7, 0.08, 0.7, seed=14)
F.under_mat(bm, 1, -0.25, only_mats=[0])
F.snow_cap(bm, 2, thick=0.03, threshold=0.55, noise_amp=0.4, seed=7, freq=1.1, only_mats=[0])
F.xf_bm(bm, F.Matrix.Diagonal(Vector((0.85, 0.85, 0.85, 1.0))))
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_rock, m_dark, m_dust, m_vein], smooth_deg=16)
F.finish(MID, [ob], "rock", ["barren"],
         {"shape": "box", "size": [3.6, 1.3, 2.0], "offset_y": 0.0},
         tintable=["rock", "dust"],
         notes="Long slab outcrop ~4.4 m x 3.1 m x 1.4 m (long axis = X), leaning ledge on the +Y side, craters, pale mineral banding. Origin ground centre.")
