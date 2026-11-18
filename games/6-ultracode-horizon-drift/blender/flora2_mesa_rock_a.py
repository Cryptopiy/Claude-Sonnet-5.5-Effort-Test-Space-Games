"""flora2 / mesa_rock_a : ~18 m layered sandstone butte (landmark) with a satellite pillar, gullies, talus slope and boulders."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

MID = "mesa_rock_a"
rng = random.Random(2024)
col = L.fresh_collection(MID)
mats = [
    L.mat(MID + "_rust", F.hexcol("#7f361e"), roughness=0.93),
    L.mat(MID + "_orange", F.hexcol("#b95a27"), roughness=0.93),
    L.mat(MID + "_ochre", F.hexcol("#c98340"), roughness=0.93),
    L.mat(MID + "_cream", F.hexcol("#d6ad74"), roughness=0.93),
    L.mat(MID + "_sand", F.hexcol("#c59a64"), roughness=0.98),
    L.mat(MID + "_cap", F.hexcol("#4d2a20"), roughness=0.85),
]
bm = bmesh.new()
pts = [(0.0, 1.0), (0.33, 0.97), (0.7, 0.93), (0.9, 0.9), (0.94, 1.0), (1.0, 1.02)]
tap = lambda f: F.pw(f, pts)
gul = [(0.5, 0.2, 0.3, 0.12, 0.98), (2.9, 0.16, 0.22, 0.25, 0.95), (4.6, 0.22, 0.3, 0.1, 0.9), (1.7, 0.12, 0.18, 0.4, 0.96)]
# main butte
F.strata(bm, 18.0, 3.8, rng, seed=4, layers=12, segs=36, aspect=(1.0, 0.74), taper=tap, lean=(0.5, -0.3), recess=0.085,
         amp=0.14, kz=0.22, kth=1.5, gullies=gul, thickness_var=0.8, soft_slope=0.12, skirt=0.75, skirt_h=6.5, mats=(0, 1, 2, 3), skirt_mat=4, cap_mat=5, lobes=0.2, top_round=0.02,
         cap_extra=0.1, mat_noise=0.9, zamp=0.16, skirt_amp=2.2)
# satellite pillar fused to the skirt of the main butte
F.strata(bm, 10.5, 1.6, rng, seed=21, layers=7, segs=24, aspect=(1.0, 0.9), taper=lambda f: F.pw(f, [(0, 1.0), (0.4, 0.9), (0.85, 0.86), (1.0, 0.95)]),
         offset=(5.2, -2.6), lean=(-0.2, 0.3), recess=0.1, amp=0.1, kz=0.35, kth=1.5, zamp=0.1, soft_slope=0.1, thickness_var=0.7,
         gullies=[(1.2, 0.2, 0.25, 0.2, 0.9)], skirt=0.6, skirt_h=3.0, mats=(0, 1, 2, 3), skirt_mat=4, cap_mat=5, lobes=0.14, top_round=0.03,
         cap_extra=0.12)
# talus boulders
F.rubble(bm, rng, 4, 0.9, 2.1, 10.0, mat=4, seed=3, subdiv=2, ring_min=6.2)
F.rubble(bm, rng, 5, 0.5, 1.2, 10.5, mat=1, seed=33, subdiv=1, ring_min=6.5)
F.rubble(bm, rng, 5, 0.4, 0.9, 10.5, mat=4, seed=53, subdiv=1, ring_min=6.5)
# boulders on the cap rock
ztop = 18.0
F.rubble(bm, rng, 8, 0.35, 1.0, 2.2, mat=5, seed=77, subdiv=1, centre=(0.5, -0.3), ring_min=0.4, zoff=ztop - 0.15)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, mats, smooth_deg=50)
F.finish(MID, [ob], "rock", ["desert"],
         {"shape": "cylinder", "radius": 5.2, "height": 18.0, "offset_y": 0.0},
         # no "cap": the game classifies tint words by keyword and "cap" is a GLOW word (hue-shifted by the glow palette), which would recolour the dark caprock
         # differently from the strata. The cap stays its fixed dark brown on every planet.
         tintable=["rust", "orange", "ochre", "cream", "sand"],
         notes="Layered butte landmark ~18 m tall (main cliff radius ~4.3 m, talus skirt radius ~7.5 m + loose boulders out to ~10 m) with a 10 m satellite pillar "
               "at +X/-Y. Origin at ground centre of the main butte. Collider approximates the main cliff only.",
         dist_mult=1.6)
