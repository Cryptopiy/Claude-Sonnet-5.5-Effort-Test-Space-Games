import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

ID = "tree_broadleaf_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_bark", "#7a5538", rough=0.95),
    F.M(ID + "_bark_dark", "#43301f", rough=1.0),
    F.M(ID + "_leaf_dark", "#0a6244", rough=0.75),
    F.M(ID + "_leaf", "#26a03d", rough=0.7),
    F.M(ID + "_leaf_light", "#72c83a", rough=0.65),
    F.M(ID + "_fruit", "#ff4f86", rough=0.35, emit="#ff3d7a", emit_strength=2.2),
]
BARK, BARKD, LDARK, LMID, LLIGHT, FRUIT = range(6)
b = F.Builder(mats, seed=21)
rng = b.rng

# ---- trunk -------------------------------------------------------------------------------------------------------
trunk_pts = F.spline([(0, 0, -0.12), (0.07, 0.05, 0.9), (-0.10, 0.0, 1.9), (0.08, -0.07, 2.9), (0.0, 0.0, 3.6)], 5)
b.tube(trunk_pts, lambda t: 0.27 - 0.05 * t + 0.38 * (1 - t) ** 4, segs=12, mat=lambda i, k: BARKD if k % 3 == 0 else BARK,
       cap0=True, cap1=True, nz=0.10, nf=1.4, seed=3, rmod=lambda t, a, k: 1.0 + 0.06 * math.cos(a * 6))

# ---- buttress roots -----------------------------------------------------------------------------------------------
for i in range(5):
    a = i * math.tau / 5 + rng.uniform(-0.25, 0.25)
    dx, dy = math.cos(a), math.sin(a)
    reach = rng.uniform(1.15, 1.5)
    pts = F.spline([(dx * 0.22, dy * 0.22, 1.0), (dx * 0.48, dy * 0.48, 0.5), (dx * (reach * 0.7), dy * (reach * 0.7), 0.13),
                    (dx * reach, dy * reach, -0.08)], 4)
    b.tube(pts, (0.17, 0.05), segs=6, mat=BARK, cap1=True, nz=0.12, nf=2.0, seed=i)

# ---- branches ------------------------------------------------------------------------------------------------------
anchors = []  # (pos, dir, radius)
fork = Vector((0, 0, 3.55))
# leader
end, d, _ = b.branch(fork, (0.06, 0.04, 1), 2.55, 0.2, 0.06, bend=(0.2, 0, 1), bend_amt=0.2, wobble=0.1, steps=6, segs=7, mat=BARK, nz=0.1)
anchors.append((end, d, 2.15))
for i in range(4):
    a = i * math.tau / 4 + rng.uniform(-0.3, 0.3)
    el = math.radians(rng.uniform(44, 58))
    dirv = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    length = rng.uniform(2.5, 3.1)
    end, d, info = b.branch(fork, dirv, length, 0.17, 0.07, bend=(0, 0, 1), bend_amt=0.7, wobble=0.1, steps=6, segs=7, mat=BARK, nz=0.1, seed=i)
    anchors.append((end, d, 1.7))
    # sub branch from 60% along
    p = info.pts[4]
    a2 = a + rng.choice((-1, 1)) * math.radians(rng.uniform(35, 55))
    el2 = math.radians(rng.uniform(30, 50))
    d2 = Vector((math.cos(a2) * math.cos(el2), math.sin(a2) * math.cos(el2), math.sin(el2)))
    end2, dd2, _ = b.branch(p, d2, rng.uniform(1.4, 1.9), 0.07, 0.025, bend=(0, 0, 1), bend_amt=0.5, wobble=0.12, steps=5, segs=6, mat=BARK, seed=i + 10)
    anchors.append((end2, dd2, 1.35))
# two low side branches
for i in range(2):
    a = rng.uniform(0, math.tau)
    p = Vector((0, 0, rng.uniform(2.6, 3.0)))
    dirv = Vector((math.cos(a), math.sin(a), 0.35))
    end, d, _ = b.branch(p, dirv, 1.7, 0.1, 0.035, bend=(0, 0, 1), bend_amt=0.3, wobble=0.1, steps=5, segs=6, mat=BARK, seed=20 + i)
    anchors.append((end, d, 1.1))


# ---- canopy --------------------------------------------------------------------------------------------------------
fruit_spots = []
for ci, (pos, dirv, rad) in enumerate(anchors):
    centre = pos + dirv * (rad * 0.35) + Vector((0, 0, rad * 0.2))
    verts = b.canopy_cluster(centre, rad, (LDARK, LMID, LLIGHT), seed=ci + 1, subdiv=3 if rad > 1.6 else 2, squash=0.9,
                             n_sat=2 if rad > 1.25 else 1, n_fringe=9, n_top=9 if rad > 1.25 else 5, leaf_len=(0.9, 1.3), leaf_w=0.58)
    if True:
        cand2 = [(p, n) for (p, n) in verts if n.z < 0.15]
        rng.shuffle(cand2)
        for (p, n) in cand2[:3]:
            fruit_spots.append(p + n * 0.05)

# a few glowing fruits peeking out of the foliage
for p in fruit_spots:
    b.blob(p, 0.16, subdiv=1, amt=0.0, mat=FRUIT)

ob = b.finish(ID + "_mesh", col, flat_mats=())
ob.location = (0, 0, 0)
info = F.publish(ID, [ob], "flora", ["lush"],
                 {"shape": "cylinder", "radius": 0.45, "height": 4.0, "offset_y": 0.0},
                 tintable=["leaf"],
                 notes="Origin at trunk base (z=0, roots dip 0.1 m under). Lush broadleaf tree ~9 m, canopy radius ~4 m. Materials: bark, bark_dark, leaf_dark/leaf/leaf_light (tintable via 'leaf'), fruit (emissive pink dots). Foliage leaf cards are two-sided geometry.")
print(info)
