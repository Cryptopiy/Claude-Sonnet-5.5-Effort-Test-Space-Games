"""flora2 / icicle_arch_a : ~10 m glacial ice arch with hanging icicles, snow on top and drifts at its feet."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

MID = "icicle_arch_a"
rng = random.Random(1010)
col = L.fresh_collection(MID)
# QA: emissive materials must ship with glTF emission strength >= 2 (exporter folds a dimmed colour into the strength). Shell = not emissive, deep ice = glow.
m_ice = L.mat(MID + "_ice", F.hexcol("#86cbf8"), roughness=0.12, specular=0.8)
m_ice.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.0, 0.0, 0.0, 1.0)   # (a reused material may keep an old colour)
m_deep = L.mat(MID + "_deep", F.hexcol("#3a83dd"), roughness=0.1, emission=F.hexcol("#2c8dff"), emission_strength=2.0, specular=0.8)
m_snow = L.mat(MID + "_snow", F.hexcol("#eef6ff"), roughness=0.93)
m_rock = L.mat(MID + "_rock", F.hexcol("#46557a"), roughness=0.9)

bm = bmesh.new()
W = 3.9
HH = 6.4
N = 44
path = []
for i in range(N):
    a = math.pi * (i / (N - 1))
    x = -W * math.cos(a)
    z = HH * math.sin(a) ** 0.75 - 0.5 * (1 - math.sin(a)) * 0.0
    y = 0.5 * math.sin(a * 2.0) * 0.6
    path.append(Vector((x, y, z)))
# extend below ground to bury the feet
path.insert(0, Vector((-W - 0.05, 0.0, -0.6)))
path.append(Vector((W + 0.05, 0.0, -0.6)))
n = len(path)
radii = []
for i in range(n):
    u = i / (n - 1)
    r = 0.9 + 1.0 * (1.0 - math.sin(math.pi * u) ** 0.5)
    r *= 1.0 + 0.18 * F.n3(u * 7.0, 1.0, 2.0, 5)
    radii.append(r)
F.tube(bm, path, radii, segs=14, mat=0, cap_a="flat", cap_b="flat", aspect=0.8,
       profile=lambda th, u: 1.0 + 0.16 * math.sin(3 * th + 9 * u) + 0.14 * F.n3(math.cos(th) * 1.5, math.sin(th) * 1.5, u * 5.0, 8))
# craggy displacement along normals
bm.normal_update()
for v in bm.verts:
    p = v.co
    d = 0.5 * F.fbm3(p.x * 0.7, p.y * 0.7, p.z * 0.7, 3.3, 3)
    v.co = p + v.normal * d
# deeper ice veins (large-scale noise patches) + hanging icicles on the underside
bm.normal_update()
F.assign_mat(bm, lambda f: 1 if F.face_center(f).z < (1.9 + 1.6 * F.n3(F.face_center(f).x * 0.4, F.face_center(f).y * 0.4, 1.0, 2.0)) else 0)
F.clean_mask(bm, 1, 0, 2, 3)
under = [v for v in bm.verts if v.normal.z < -0.35 and v.co.z > 2.0]
rng.shuffle(under)
count = 0
for v in under:
    if count >= 55:
        break
    ln = rng.uniform(0.5, 2.1)
    F.add_cone(bm, v.co.copy(), Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), -1.0)), ln, rng.uniform(0.07, 0.15), segs=5, mat=0,
               base_cap=False, rng=rng, jitter=0.15)
    count += 1
# snow on top + mounds at the feet
F.snow_cap(bm, 2, thick=0.14, threshold=0.5, noise_amp=0.35, seed=3, freq=0.6, only_mats=[0, 1])
for sx in (-1, 1):
    mound = F.ico_blob((2.0, 1.8, 0.55), 2, 5 + sx, 0.2, 1.2, 3)
    for v in mound.verts:
        v.co += Vector((sx * W, 0.0, 0.05))
    for f in mound.faces:
        f.material_index = 2
    bm = F.merge(bm, mound)
    for i in range(3):
        r = rng.uniform(0.3, 0.6)
        rk = F.ico_blob((r, r * 0.9, r * 0.7), 1, 10 + i + sx, 0.3, 1.5, 2)
        F.plane_cut(rk, F.random_planes(rng, 3, r * 0.7, up_bias=0.4))
        ang = rng.random() * F.TAU
        for v in rk.verts:
            v.co += Vector((sx * W + math.cos(ang) * 1.8, math.sin(ang) * 1.6, r * 0.3))
        for f in rk.faces:
            f.material_index = 3
        bm = F.merge(bm, rk)
# faceted ice crystals sprouting around the feet
for sx in (-1, 1):
    for i in range(7):
        ang = rng.random() * F.TAU
        dd = rng.uniform(0.9, 2.2)
        base = Vector((sx * W + math.cos(ang) * dd * 0.8, math.sin(ang) * dd * 0.7, -0.1))
        out = Vector((math.cos(ang) * 0.5, math.sin(ang) * 0.5, 1.0)).normalized()
        F.crystal(bm, base, out, rng.uniform(1.0, 3.0), rng.uniform(0.2, 0.38), sides=6, tip=0.3, mat=0, taper=0.85, rng=rng, jitter=0.1)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_ice, m_deep, m_snow, m_rock], smooth_deg=38)
F.finish(MID, [ob], "structure", ["frozen"],
         {"shape": "none"},
         tintable=["ice", "deep"],
         notes="Natural ice arch, 12.3 m overall width (X, incl. foot crystals; 7.8 m between leg centres), ~7.3 m tall, ~4 m deep (Z in Godot). Walk-under opening ~5 m wide x ~4.5 m high: do NOT use a single collider; "
               "legs are at x = +-3.9 m (radius ~1.7 m) if you want two cylinder colliders. Hanging icicles, snow cap, snow drifts at the feet. Origin: ground centre between the legs. "
               "Slot deep (lower leg veins) is emissive strength 2.0; slot ice is not emissive.",
         dist_mult=1.5)
