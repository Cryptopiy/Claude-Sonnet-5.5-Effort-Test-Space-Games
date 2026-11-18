"""flora2 / rock_sandstone_a : ~2.5 m layered sandstone boulder (banded red/orange/ochre strata, ledges, talus rubble)."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "rock_sandstone_a")
SD = OVR.get("seed", 31)
rng = random.Random(SD)
col = L.fresh_collection(MID)
mats = [
    L.mat(MID + "_rust", F.hexcol("#8c3f23"), roughness=0.92),
    L.mat(MID + "_orange", F.hexcol("#c0602a"), roughness=0.92),
    L.mat(MID + "_ochre", F.hexcol("#d08d44"), roughness=0.92),
    L.mat(MID + "_cream", F.hexcol("#dcb87e"), roughness=0.92),
    L.mat(MID + "_sand", F.hexcol("#cda26b"), roughness=0.98),
]
bm = bmesh.new()
tap = lambda f: F.pw(f, [(0.0, 1.0), (0.5, 0.99), (0.82, 0.93), (0.96, 0.84), (1.0, 0.74)])   # QA: broad shoulders, no pointed crown
F.strata(bm, 2.5, 1.5, rng, seed=3 + (SD - 31), layers=8, segs=32, aspect=(1.0, 0.8), taper=tap, lean=(0.12, -0.07), recess=0.17,
         amp=0.12, kz=0.6, kth=1.6, skirt=0.16, skirt_h=0.35, mats=(0, 1, 2, 3), skirt_mat=4, lobes=0.24, top_round=0.05, zamp=0.07, soft_slope=0.1,
         gullies=[(1.0, 0.09, 0.16, 0.25, 1.0), (3.7, 0.08, 0.14, 0.1, 0.9), (5.3, 0.1, 0.12, 0.3, 1.0)])
F.plane_cut(bm, [((0.7, 0.1, 2.3), (0.35, 0.1, 0.93)), ((-0.9, -0.5, 1.9), (-0.55, -0.3, 0.78))])   # QA: shallow tilted cap cut instead of a steep wedge
F.rubble(bm, rng, 4, 0.18, 0.4, 1.75, mat=4, seed=9, subdiv=1, ring_min=1.15)
F.rubble(bm, rng, 2, 0.2, 0.3, 1.8, mat=1, seed=19, subdiv=1, ring_min=1.2)
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, mats, smooth_deg=48)
F.finish(MID, [ob], "rock", ["desert"],
         F.vc({"shape": "cylinder", "radius": 1.25, "height": 2.2, "offset_y": 0.0}, OVR),
         tintable=["rust", "orange", "ochre", "cream", "sand"],
         notes="Layered sandstone boulder ~2.5 m wide/2.5 m tall, origin at ground centre. Strata are separate material slots (rust..cream + sand talus).")
