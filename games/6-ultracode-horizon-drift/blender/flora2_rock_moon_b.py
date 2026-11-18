"""flora2 / rock_moon_b : ~1.6 m rounded, heavily cratered regolith boulder (pits with raised rims) + pebbles."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "rock_moon_b")
SD = OVR.get("seed", 8202)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_rock = L.mat(MID + "_rock", F.hexcol("#5a5a61"), roughness=0.97)
m_dark = L.mat(MID + "_rock_dark", F.hexcol("#34333a"), roughness=0.97)
m_dust = L.mat(MID + "_dust", F.hexcol("#7b7a80"), roughness=1.0)

bm = F.faceted_rock((1.0, 0.85, 0.72), 4, 29 + (SD - 8202), 0.17, 1.1, planes=4, plane_dist=0.92, up_bias=0.3, rng=rng, bottom=0.5, sink=0.05,
                    craters=[(3, 0.36, 0.52, 0.24), (7, 0.15, 0.26, 0.1)], crater_rim=0.35, fine=(0.04, 4.0))
for (cx, cy, rr, sd) in ((1.0, 0.65, 0.28, 3), (-0.85, 0.75, 0.2, 8), (0.3, -1.0, 0.22, 12), (-0.6, -0.8, 0.14, 13)):
    sm = F.faceted_rock((rr, rr * 0.9, rr * 0.7), 2, sd, 0.2, 1.5, planes=3, plane_dist=0.85, up_bias=0.3, rng=rng, bottom=0.45, sink=0.03,
                        craters=[(1, rr * 0.3, rr * 0.4, rr * 0.2)])
    for v in sm.verts:
        v.co += Vector((cx, cy, 0))
    bm = F.merge(bm, sm)
F.under_mat(bm, 1, -0.2, only_mats=[0])
F.snow_cap(bm, 2, thick=0.02, threshold=0.62, noise_amp=0.45, seed=4, freq=2.0, only_mats=[0])
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_rock, m_dark, m_dust], smooth_deg=30)
F.finish(MID, [ob], "rock", ["barren"],
         F.vc({"shape": "cylinder", "radius": 0.95, "height": 1.2, "offset_y": 0.0}, OVR),
         tintable=["rock", "dust"],
         notes="Rounded cratered boulder ~2 m wide / 1.3 m tall with 4 pebbles. Origin ground centre.")
