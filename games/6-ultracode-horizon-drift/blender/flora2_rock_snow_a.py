"""flora2 / rock_snow_a : ~2.6 m dark slate boulder wearing a ragged snow cap, with snowy satellite rocks and low lumpy snow banks that overlap its base.
QA rework 2: the previous drifts were fat egg shapes plus a sword-shaped 'tail' that read as white logs lying next to a small rock.  Now the main rock is
larger, the banks are low, noisy, overlap the rock base / satellites (so they read as drifted snow, not separate blobs) and there is no tapered blade."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "rock_snow_a")
SD = OVR.get("seed", 606)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_rock = L.mat(MID + "_rock", F.hexcol("#415069"), roughness=0.9)
m_snow = L.mat(MID + "_snow", F.hexcol("#f2f8ff"), roughness=0.9)
m_rock2 = L.mat(MID + "_rock_light", F.hexcol("#667a9c"), roughness=0.9)

bm = F.faceted_rock((1.4, 1.1, 1.05), 4, 11 + (SD - 606), 0.24, 1.3, planes=13, plane_dist=0.74, up_bias=0.15, rng=rng, bottom=0.5, sink=0.05, fine=(0.05, 4.0))
F.vein_bands(bm, 2, (0.4, 0.3, 1.0), 2.2, 0.28, 0.5, seed=3)
sat = []
for k, (rr, sd) in enumerate(((0.5, 21), (0.38, 33), (0.3, 44))):
    a = rng.random() * F.TAU + k * 2.1
    dd = rng.uniform(1.45, 1.7)
    sm = F.faceted_rock((rr, rr * 0.9, rr * 0.75), 3, sd + (SD - 606), 0.25, 1.5, planes=6, plane_dist=0.78, up_bias=0.2, rng=rng, bottom=0.45, sink=0.03)
    for v in sm.verts:
        v.co += Vector((math.cos(a) * dd, math.sin(a) * dd * 0.85, 0))
    bm = F.merge(bm, sm)
    sat.append(a)
# snow on everything facing up (ragged edge: steeper faces stay bare slate)
F.snow_cap(bm, 1, thick=0.08, threshold=0.58, noise_amp=0.6, seed=5, freq=1.5)


def bank(radius, ang, dist, seed, rot):
    """Low, lumpy snow bank: flattened noisy ellipsoid half-sunk into the ground, long axis tangent to the rock, overlapping the base."""
    b = F.ico_blob(radius, 3, seed + (SD - 606), 0.42, 2.0, 3)
    for v in b.verts:
        x, y = v.co.x, v.co.y
        v.co.x = x * math.cos(rot) - y * math.sin(rot) + math.cos(ang) * dist
        v.co.y = x * math.sin(rot) + y * math.cos(rot) + math.sin(ang) * dist * 0.85
        v.co.z += 0.03
    for f in b.faces:
        f.material_index = 1
    return b


ta = rng.random() * F.TAU
bm = F.merge(bm, bank((1.15, 0.55, 0.3), ta, 1.05, 77, ta + 1.57))                 # the biggest bank, on the leeward side
bm = F.merge(bm, bank((0.8, 0.45, 0.25), ta + 2.3, 1.0, 91, ta + 2.3 + 1.57))
bm = F.merge(bm, bank((0.7, 0.4, 0.22), ta + 4.2, 1.05, 92, ta + 4.2 + 1.57))
# a thin snow apron joining the satellites to the bank (sells it as one wind-blown drift field)
for k, a in enumerate(sat):
    bm = F.merge(bm, bank((0.55, 0.38, 0.2), a, 1.3, 120 + k, a + 1.57))
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_rock, m_snow, m_rock2], smooth_deg=26)
F.finish(MID, [ob], "rock", ["frozen"],
         F.vc({"shape": "cylinder", "radius": 1.2, "height": 1.4, "offset_y": 0.0}, OVR),
         tintable=["rock"],
         notes="Slate-blue boulder with a ragged snow cap (slot snow) on up-facing faces, 3 satellite rocks and low lumpy snow banks overlapping the base. "
               "Origin at ground centre.")
