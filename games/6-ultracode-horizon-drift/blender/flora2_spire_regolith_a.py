"""flora2 / spire_regolith_a : ~7 m jagged faceted rock spire cluster (airless-moon look): dark faceted shards, dust on ledges, pale ore streaks."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "spire_regolith_a")
SD = OVR.get("seed", 7070)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_rock = L.mat(MID + "_rock", F.hexcol("#4a4a52"), roughness=0.95)
m_dark = L.mat(MID + "_rock_dark", F.hexcol("#2d2d34"), roughness=0.97)
m_dust = L.mat(MID + "_dust", F.hexcol("#77746d"), roughness=1.0)
m_ore = L.mat(MID + "_ore", F.hexcol("#8c9ab6"), roughness=0.5, metallic=0.4)

bm = bmesh.new()


def shard(H, R0, offset, lean, seed, segs=7, rows=26):
    r2 = random.Random(seed)
    prof = []
    for i in range(rows):
        f = i / (rows - 1)
        r = R0 * (1.0 - f) ** 0.75 * (0.92 + 0.16 * math.sin(f * 7.0 + seed)) + 0.04
        prof.append((H * f, r))
    kf = [r2.uniform(0.0, 50.0) for _ in range(segs)]

    def mod(th, z, r, i):
        k = int(round(th / F.TAU * segs)) % segs
        # each facet column varies smoothly with height -> long vertical ridges instead of stacked slabs
        return r * (1.0 + 0.42 * F.n3(k * 2.17 + kf[k], z * 0.42, seed * 0.7, 1) + 0.10 * F.fbm3(math.cos(th) * 1.5, math.sin(th) * 1.5, z * 0.7, seed, 2))

    def centre(z):
        f = z / H
        return (offset[0] + lean[0] * f * f, offset[1] + lean[1] * f * f)

    b = bmesh.new()
    F.lathe(b, prof, segs=segs, mod=mod, centre=centre, cap_top="apex", cap_bottom=None, mat=0, rot0=r2.random(), top_dome=-0.02)
    # one chisel facet near the tip (shaves a side wedge, does not decapitate the shard)
    ang = r2.random() * F.TAU
    cz = H * r2.uniform(0.78, 0.88)
    c0 = centre(cz)
    F.plane_cut(b, [((c0[0] + math.cos(ang) * 0.12, c0[1] + math.sin(ang) * 0.12, cz), Vector((math.cos(ang) * 0.93, math.sin(ang) * 0.93, 0.36)))])
    return b


bm = F.merge(bm, shard(7.4, 1.9, (0, 0), (0.9, 0.4), 3 + (SD - 7070), 7, 28))
bm = F.merge(bm, shard(4.8, 1.25, (2.0, 0.5), (0.8, -0.3), 8 + (SD - 7070), 6, 22))
bm = F.merge(bm, shard(3.7, 1.05, (-1.8, -0.9), (-0.7, -0.4), 12 + (SD - 7070), 6, 20))
bm = F.merge(bm, shard(2.6, 0.8, (0.4, -2.1), (0.3, -0.7), 17, 6, 16))
bm = F.merge(bm, shard(2.0, 0.65, (-1.0, 1.8), (-0.2, 0.5), 21, 5, 14))
# debris
for i in range(9):
    a = rng.random() * F.TAU
    d = rng.uniform(1.7, 3.0)
    r = rng.uniform(0.2, 0.7)
    rk = F.faceted_rock((r, r * 0.85, r * 0.7), 2, 40 + i, 0.3, 1.5, planes=5, plane_dist=0.75, up_bias=0.3, rng=rng, bottom=0.4, sink=0.05, fine=(0.0, 3.0))
    for v in rk.verts:
        v.co += Vector((math.cos(a) * d, math.sin(a) * d, 0))
    bm = F.merge(bm, rk)
F.vein_bands(bm, 3, (0.3, 0.2, 1.0), 0.9, 0.09, 0.7, seed=5)
F.under_mat(bm, 1, -0.2, only_mats=[0])
F.snow_cap(bm, 2, thick=0.03, threshold=0.55, noise_amp=0.35, seed=9, freq=1.0, only_mats=[0])
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_rock, m_dark, m_dust, m_ore], smooth_deg=22)
F.finish(MID, [ob], "rock", ["barren"],
         F.vc({"shape": "cylinder", "radius": 1.5, "height": 7.0, "offset_y": 0.0}, OVR),
         tintable=["rock", "dust"],
         notes="Jagged faceted spire cluster, main shard ~7 m (leans toward +X/+Y by ~1 m), 4 smaller shards, debris. Dust on up-facing facets, pale ore streaks. Origin ground centre of the main shard.",
         dist_mult=1.5)
