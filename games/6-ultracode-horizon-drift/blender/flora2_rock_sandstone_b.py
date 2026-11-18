"""flora2 / rock_sandstone_b : ~3 m sandstone hoodoo (eroded stem, wide dark cap rock), leaning, banded strata."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

MID = "rock_sandstone_b"
rng = random.Random(77)
col = L.fresh_collection(MID)
mats = [
    L.mat(MID + "_rust", F.hexcol("#843a20"), roughness=0.92),
    L.mat(MID + "_orange", F.hexcol("#b95a28"), roughness=0.92),
    L.mat(MID + "_ochre", F.hexcol("#cb8740"), roughness=0.92),
    L.mat(MID + "_cream", F.hexcol("#d8b27a"), roughness=0.92),
    L.mat(MID + "_sand", F.hexcol("#c99f68"), roughness=0.98),
    L.mat(MID + "_cap", F.hexcol("#5c3226"), roughness=0.85),
]
bm = bmesh.new()
pts = [(0.0, 1.05), (0.12, 0.92), (0.45, 0.66), (0.62, 0.7), (0.74, 0.95), (0.82, 1.32), (0.95, 1.38), (1.0, 0.95)]
tap = lambda f: F.pw(f, pts)
F.strata(bm, 3.1, 0.72, rng, seed=8, layers=10, segs=30, aspect=(1.0, 0.72), taper=tap, lean=(0.32, 0.12), recess=0.14,
         amp=0.11, kz=0.8, kth=1.4, skirt=0.5, skirt_h=0.4, mats=(0, 1, 2, 3), skirt_mat=4, cap_mat=5, lobes=0.2, top_round=0.05, cap_extra=0.0,
         zamp=0.06, soft_slope=0.08, gullies=[(0.8, 0.12, 0.2, 0.1, 0.62), (3.9, 0.1, 0.16, 0.1, 0.6)])
F.plane_cut(bm, [((0.95, 0.0, 2.75), (0.65, 0.1, 0.5))])
F.rubble(bm, rng, 5, 0.15, 0.4, 1.7, mat=4, seed=5, subdiv=1, ring_min=0.9)
F.rubble(bm, rng, 2, 0.18, 0.3, 1.8, mat=1, seed=15, subdiv=1, ring_min=1.0)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, mats, smooth_deg=48)
F.finish(MID, [ob], "rock", ["desert"],
         {"shape": "cylinder", "radius": 0.75, "height": 3.0, "offset_y": 0.0},
         tintable=["rust", "orange", "ochre", "cream", "sand", "cap"],
         notes="Sandstone hoodoo (mushroom rock) ~3 m tall, ~2.3 m cap width, leans slightly toward +X. Origin at ground centre of the stem.")
