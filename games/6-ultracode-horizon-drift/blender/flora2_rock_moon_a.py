"""flora2 / rock_moon_a : ~2.6 m angular, chiselled grey airless-moon rock with dust on its top facets."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "rock_moon_a")
SD = OVR.get("seed", 8101)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_rock = L.mat(MID + "_rock", F.hexcol("#55555c"), roughness=0.95)
m_dark = L.mat(MID + "_rock_dark", F.hexcol("#2e2e36"), roughness=0.95)
m_dust = L.mat(MID + "_dust", F.hexcol("#76757b"), roughness=1.0)
m_vein = L.mat(MID + "_vein", F.hexcol("#7d88a0"), roughness=0.7, metallic=0.25)

bm = F.faceted_rock((1.5, 1.15, 1.2), 4, 17 + (SD - 8101), 0.3, 1.2, planes=14, plane_dist=0.74, up_bias=0.25, rng=rng, bottom=0.55, sink=0.08,
                    craters=[(2, 0.4, 0.55, 0.16)], fine=(0.05, 5.0))
for (cx, cy, rr, sd) in ((1.6, 0.4, 0.4, 5), (-1.5, -0.6, 0.3, 7)):
    sm = F.faceted_rock((rr, rr * 0.8, rr * 0.7), 3, sd, 0.3, 1.5, planes=6, plane_dist=0.75, up_bias=0.2, rng=rng, bottom=0.45, sink=0.03)
    for v in sm.verts:
        v.co += Vector((cx, cy, 0))
    bm = F.merge(bm, sm)
F.vein_bands(bm, 3, (0.7, 0.2, 0.55), 1.5, 0.09, 0.6, seed=9)
F.under_mat(bm, 1, -0.25, only_mats=[0])
F.snow_cap(bm, 2, thick=0.025, threshold=0.5, noise_amp=0.35, seed=2, freq=1.4, only_mats=[0])
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_rock, m_dark, m_dust, m_vein], smooth_deg=16)
F.finish(MID, [ob], "rock", ["barren"],
         F.vc({"shape": "cylinder", "radius": 1.3, "height": 1.8, "offset_y": 0.0}, OVR),
         tintable=["rock", "dust"],
         notes="Angular grey moon rock ~3 m wide / 2.2 m tall (chiselled facets, two craters, pale mineral vein, dust on top facets) + 2 chunks. Origin ground centre.")
