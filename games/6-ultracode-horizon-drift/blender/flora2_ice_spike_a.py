"""flora2 / ice_spike_a : ~5 m jagged cluster of ice spikes (frosted, stepped, leaning) rising from a snow drift."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "ice_spike_a")
SD = OVR.get("seed", 909)
rng = random.Random(SD)
col = L.fresh_collection(MID)
# QA: emissive materials must ship with glTF emission strength >= 2 (the exporter folds a dimmed colour into the strength: 0.35 x 2.0 shipped as 0.7).
# The frosty shell is therefore NOT emissive (pure albedo, lit by the sun/sky); only the deep-blue lower sections glow (colour x 2.0).
m_ice = L.mat(MID + "_ice", F.hexcol("#8dd0ff"), roughness=0.18, specular=0.8)
m_ice.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.0, 0.0, 0.0, 1.0)   # (a reused material may keep an old colour)
m_deep = L.mat(MID + "_deep", F.hexcol("#3d86e0"), roughness=0.12, emission=F.hexcol("#2a8cff"), emission_strength=2.0, specular=0.8)
m_snow = L.mat(MID + "_snow", F.hexcol("#eef6ff"), roughness=0.92)
m_rock = L.mat(MID + "_rock", F.hexcol("#4a5b7c"), roughness=0.9)

bm = bmesh.new()


def spike(base, az, tilt, height, r0, sides=6, bend=0.35, steps=9):
    d = Vector((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))
    side = Vector((-math.sin(az), math.cos(az), 0.0))
    path = []
    for i in range(steps):
        t = i / (steps - 1)
        # slight S-curve + lean
        p = Vector(base) + d * (height * t) + side * (bend * math.sin(t * 2.6) * height * 0.05) + Vector((0, 0, 0))
        if i > 0:
            p = p + Vector((rng.gauss(0, 1), rng.gauss(0, 1), 0)) * 0.025 * height * t
        path.append(p)
    # radii: tapered, with stepped "ledges"
    radii = []
    for i in range(steps):
        t = i / (steps - 1)
        r = r0 * (1.0 - t) ** 0.85 * (1.0 - 0.3 * (i % 2)) + 0.004
        radii.append(r)
    twist = rng.uniform(-0.6, 0.6)
    jit = [1.0 + rng.uniform(-0.34, 0.34) for _ in range(sides)]

    def prof(th, u):
        k = int(round(th / F.TAU * sides)) % sides
        return jit[k]

    # material per ring interval: deep blue near the base -> frosty tip
    bnd = rng.uniform(0.25, 0.5)
    rows = [1 if (i / (steps - 1)) < bnd else 0 for i in range(steps - 1)]
    F.tube(bm, path, radii, segs=sides, mat=0, cap_a=None, cap_b="apex", tip_b=r0 * 0.35, profile=prof, twist=twist, mat_rows=rows)


# main spires
spike((0.0, 0.0, -0.1), 0.4, 0.06, 5.2, 0.85, 7, 0.4, 11)
spike((0.9, 0.4, -0.1), 0.2, 0.3, 4.0, 0.65, 6, 0.3, 9)
spike((-0.85, 0.35, -0.1), 2.6, 0.34, 4.2, 0.62, 6, 0.3, 9)
spike((0.1, -1.0, -0.1), 4.4, 0.42, 3.4, 0.55, 6, 0.3, 8)
spike((-0.45, 1.05, -0.1), 1.9, 0.5, 2.8, 0.46, 6, 0.3, 8)
spike((1.25, -0.55, -0.1), 5.6, 0.55, 2.5, 0.4, 5, 0.2, 7)
spike((-1.25, -0.5, -0.1), 3.6, 0.5, 2.2, 0.36, 5, 0.2, 7)
for i in range(5):
    az = F.TAU * i / 5 + 0.4
    dd = rng.uniform(1.45, 1.75)
    spike((math.cos(az) * dd, math.sin(az) * dd, -0.08), az + rng.uniform(-0.3, 0.3), rng.uniform(0.5, 0.85), rng.uniform(1.3, 2.2), rng.uniform(0.24, 0.32), 5, 0.2, 7)
# small outer shards
for i in range(8):
    az = F.TAU * i / 8 + rng.uniform(-0.3, 0.3)
    dd = rng.uniform(1.8, 2.2)
    spike((math.cos(az) * dd, math.sin(az) * dd, -0.05), az + rng.uniform(-0.4, 0.4), rng.uniform(0.35, 0.85), rng.uniform(0.7, 1.6), rng.uniform(0.12, 0.2), 5, 0.1, 6)

# snow drift + rocks
drift = F.ico_blob((2.2, 2.1, 0.5), 2, 7, 0.2, 1.4, 3)
for v in drift.verts:
    v.co.z += 0.03
for f in drift.faces:
    f.material_index = 2
bm = F.merge(bm, drift)
for i in range(5):
    az = rng.random() * F.TAU
    d = rng.uniform(1.4, 2.1)
    r = rng.uniform(0.2, 0.4)
    rk = F.ico_blob((r, r * 0.9, r * 0.7), 1, 30 + i, 0.3, 1.5, 2)
    F.plane_cut(rk, F.random_planes(rng, 3, r * 0.7, up_bias=0.4))
    for v in rk.verts:
        v.co += Vector((math.cos(az) * d, math.sin(az) * d, r * 0.3))
    for f in rk.faces:
        f.material_index = 3
    bm = F.merge(bm, rk)

F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, [m_ice, m_deep, m_snow, m_rock], all_flat=True)
for p in ob.data.polygons:
    if p.material_index in (2, 3):
        p.use_smooth = True
F.finish(MID, [ob], "flora", ["frozen"],
         F.vc({"shape": "cylinder", "radius": 1.3, "height": 4.0, "offset_y": 0.0}, OVR)   # QA: covers the spike cluster base (outer spires sit ~1 m off-centre),
         tintable=["ice", "deep"],
         notes="Cluster of tall faceted ice spikes (hero spire 5.2 m) with stepped ledges, deep-blue lower sections (slot deep, emissive strength 2.0 = the glow; slot ice is not emissive), "
               "snow drift and rocks at the base. Opaque, flat shaded. Origin at ground centre.")
