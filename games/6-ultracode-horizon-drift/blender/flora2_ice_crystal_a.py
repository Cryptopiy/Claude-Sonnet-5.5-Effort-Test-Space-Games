"""flora2 / ice_crystal_a : ~3 m cluster of translucent blue hexagonal ice crystals with glowing cores on a snowy base."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "ice_crystal_a")
SD = OVR.get("seed", 404)
rng = random.Random(SD)
col = L.fresh_collection(MID)
# QA: the glTF exporter folds colour brightness into the strength (strength_glb = max(colour) * strength), so a dimmed colour x 2.0 shipped as 1.1.
# Full-brightness colour x 2.0 ships as a real 2.0 (visible emission is halved again by alpha 0.5, so it is still a glow, not a lamp).
m_ice = L.mat(MID + "_ice", F.hexcol("#8fdcff"), roughness=0.05, emission=F.hexcol("#35b0ff"), emission_strength=2.0, alpha=0.5, specular=0.9)
m_core = L.mat(MID + "_core", F.hexcol("#6aeaff"), roughness=0.2, emission=F.hexcol("#33dcff"), emission_strength=5.0)
m_snow = L.mat(MID + "_snow", F.hexcol("#e9f4ff"), roughness=0.92)
m_rock = L.mat(MID + "_rock", F.hexcol("#46567a"), roughness=0.9)

bm = bmesh.new()   # ice (mat 0) + cores (mat 1)


def up_tilt(az, tilt):
    return Vector((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))


crystals = []
# hero crystal
crystals.append((Vector((0, 0, -0.05)), up_tilt(0.6, 0.07), 3.1, 0.36, 6))
# medium ring
n_mid = 6
for i in range(n_mid):
    az = F.TAU * i / n_mid + rng.uniform(-0.25, 0.25)
    tilt = rng.uniform(0.3, 0.7)
    r = rng.uniform(0.2, 0.28)
    base = Vector((math.cos(az) * 0.3, math.sin(az) * 0.3, -0.05))
    crystals.append((base, up_tilt(az, tilt), rng.uniform(1.5, 2.5), r, 6))
# small outer shards
n_small = 9
for i in range(n_small):
    az = F.TAU * i / n_small + rng.uniform(-0.3, 0.3)
    tilt = rng.uniform(0.6, 1.15)
    r = rng.uniform(0.09, 0.15)
    d = rng.uniform(0.5, 0.85)
    base = Vector((math.cos(az) * d, math.sin(az) * d, -0.03))
    crystals.append((base, up_tilt(az, tilt), rng.uniform(0.45, 1.1), r, rng.choice((5, 6))))

for base, d, ln, r, sides in crystals:
    F.crystal(bm, base, d, ln, r, sides=sides, tip=0.26 if ln > 1.0 else 0.35, mat=0, taper=0.9, rng=rng, jitter=0.08)
    if ln > 1.4:   # glowing inner core visible through the translucent ice
        F.crystal(bm, base + d * 0.15, d, ln * 0.78, r * 0.3, sides=5, tip=0.3, mat=1, taper=0.8, rng=rng, jitter=0.05)

# snowy / rocky base
base_snow = F.ico_blob((1.15, 1.1, 0.3), 2, 4, 0.22, 1.6, 3)
for v in base_snow.verts:
    v.co.z += 0.02
for f in base_snow.faces:
    f.material_index = 2
bm = F.merge(bm, base_snow)
for i in range(4):
    az = rng.random() * F.TAU
    d = rng.uniform(0.7, 1.15)
    r = rng.uniform(0.14, 0.26)
    rk = F.ico_blob((r, r * 0.9, r * 0.7), 1, 10 + i, 0.3, 1.5, 2)
    F.plane_cut(rk, F.random_planes(rng, 3, r * 0.7, up_bias=0.4))
    for v in rk.verts:
        v.co += Vector((math.cos(az) * d, math.sin(az) * d, r * 0.3))
    for f in rk.faces:
        f.material_index = 3
    bm = F.merge(bm, rk)

F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, [m_ice, m_core, m_snow, m_rock], all_flat=True)
# snow base + rocks look better smooth-ish: use angle smoothing on those slots
for p in ob.data.polygons:
    if p.material_index in (2, 3):
        p.use_smooth = True
F.finish(MID, [ob], "flora", ["frozen"],
         F.vc({"shape": "cylinder", "radius": 0.9, "height": 3.0, "offset_y": 0.0}, OVR),
         tintable=["ice", "core"],
         notes="Cluster of translucent (alpha 0.5, BLEND) hexagonal ice crystals with emissive cyan inner cores (slot core) and a snowy base with rocks. "
               "Origin at ground centre. ice shell emission strength 2.0 (exported glTF strength 2.0, halved on screen by alpha 0.5); core 5.0. ~3.1 m hero crystal.")
