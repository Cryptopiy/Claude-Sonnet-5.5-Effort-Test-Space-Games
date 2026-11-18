import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

ID = "tree_broadleaf_b"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_bark", "#9a8670", rough=0.95),
    F.M(ID + "_bark_dark", "#4d3b33", rough=1.0),
    F.M(ID + "_leaf_dark", "#8a1c4a", rough=0.75),
    F.M(ID + "_leaf", "#e0482f", rough=0.7),
    F.M(ID + "_leaf_light", "#ffa93a", rough=0.65),
    F.M(ID + "_blossom", "#fff0b8", rough=0.4, emit="#ffd98a", emit_strength=2.5),
]
BARK, BARKD, LDARK, LMID, LLIGHT, BLOSSOM = range(6)
b = F.Builder(mats, seed=5)
rng = b.rng

# ---- twisted trunk ---------------------------------------------------------------------------------------------------
pts = F.spline([(0, 0, -0.06), (0.22, 0.10, 0.8), (-0.12, 0.22, 1.6), (0.10, 0.02, 2.4)], 6)
b.tube(pts, lambda t: 0.30 - 0.06 * t + 0.34 * (1 - t) ** 4, segs=12, mat=lambda i, k: BARKD if k % 4 == 0 else BARK,
       cap0=True, cap1=True, nz=0.14, nf=1.2, seed=9, rmod=lambda t, a, k: 1.0 + 0.08 * math.cos(a * 5 + t * 6))
for i in range(4):
    a = i * math.tau / 4 + rng.uniform(-0.3, 0.3)
    dx, dy = math.cos(a), math.sin(a)
    reach = rng.uniform(1.0, 1.35)
    rp = F.spline([(dx * 0.2, dy * 0.2, 0.9), (dx * 0.5, dy * 0.5, 0.4), (dx * reach * 0.7, dy * reach * 0.7, 0.1), (dx * reach, dy * reach, -0.02)], 4)
    b.tube(rp, (0.15, 0.05), segs=6, mat=BARK, nz=0.1, nf=2.0, seed=i)

# ---- limbs ------------------------------------------------------------------------------------------------------------
fork = Vector((0.10, 0.02, 2.4))
tips = []
for i in range(3):
    a = i * math.tau / 3 + 0.5 + rng.uniform(-0.2, 0.2)
    el = math.radians(rng.uniform(28, 38))
    dirv = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    end, d, info = b.branch(fork, dirv, rng.uniform(2.5, 3.0), 0.2, 0.07, bend=(0, 0, 1), bend_amt=0.9, wobble=0.12, steps=7,
                            segs=7, mat=BARK, nz=0.1, seed=i)
    tips.append((end, d))
    # twig toward the disc rim
    p = info.pts[5]
    a2 = a + rng.choice((-1, 1)) * 0.9
    d2 = Vector((math.cos(a2) * 0.8, math.sin(a2) * 0.8, 0.55)).normalized()
    e2, dd2, _ = b.branch(p, d2, 1.3, 0.06, 0.025, bend=(0, 0, 1), bend_amt=0.4, wobble=0.1, steps=4, segs=6, mat=BARK, seed=i + 7)
    tips.append((e2, dd2))
lead_end, lead_d, _ = b.branch(fork, (0.05, -0.03, 1), 3.0, 0.17, 0.05, bend=(0, 0, 1), bend_amt=0.1, wobble=0.12, steps=6, segs=7, mat=BARK, nz=0.1, seed=30)

# ---- tiered canopy -----------------------------------------------------------------------------------------------------
blossoms = []
hang = []
for ci, (end, d) in enumerate(tips):
    big = ci % 2 == 0
    rad = 2.15 if big else 1.35
    centre = end + Vector((d.x, d.y, 0)) * 0.3 + Vector((0, 0, 0.35))
    verts = b.canopy_cluster(centre, rad, (LDARK, LMID, LLIGHT), seed=ci + 3, subdiv=3 if big else 2, squash=0.45, amt=0.3, freq=1.0,
                             n_sat=1 if big else 0, sat_scale=(0.5, 0.6), sat_spread=0.9, n_fringe=9 if big else 5, n_top=16 if big else 8,
                             leaf_len=(1.0, 1.5), leaf_w=0.5, flat_bottom=0.6, droop=0.5, top_leaf_scale=0.75)
    rim = [(p, n) for (p, n) in verts if abs(n.z) < 0.35]
    rng.shuffle(rim)
    for (p, n) in rim[:3 if big else 1]:
        hang.append((p, n))
    cand = [(p, n) for (p, n) in verts if n.z > 0.35]
    rng.shuffle(cand)
    for (p, n) in cand[:2]:
        blossoms.append(p + n * 0.04)
# crown disc
crown_c = lead_end + Vector((0, 0, 0.3))
verts = b.canopy_cluster(crown_c, 1.9, (LDARK, LMID, LLIGHT), seed=77, subdiv=3, squash=0.5, amt=0.2, freq=1.0, n_sat=1, sat_scale=(0.45, 0.55),
                         sat_spread=0.8, n_fringe=8, n_top=16, leaf_len=(1.0, 1.5), leaf_w=0.5, flat_bottom=0.6, droop=0.5, top_leaf_scale=0.8)
for (p, n) in verts:
    if n.z > 0.45 and rng.random() < 0.12:
        blossoms.append(p + n * 0.04)
    if abs(n.z) < 0.3 and rng.random() < 0.1:
        hang.append((p, n))

# hanging ribbons (weeping fringe)
for (p, n) in hang:
    nh = Vector((n.x, n.y, 0)).normalized() if (n.x or n.y) else Vector((1, 0, 0))
    L_ = rng.uniform(1.0, 1.6)
    pts = [p, p + nh * 0.15 - Vector((0, 0, L_ * 0.35)), p + nh * 0.28 - Vector((0, 0, L_ * 0.7)), p + nh * 0.3 - Vector((0, 0, L_))]
    b.ribbon(pts, (0.22, 0.04), normal_hint=nh, mat=LMID if rng.random() < 0.6 else LDARK)

for p in blossoms:
    b.blob(p, 0.14, subdiv=1, amt=0.0, mat=BLOSSOM)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["lush"],
                 {"shape": "cylinder", "radius": 0.45, "height": 3.0, "offset_y": 0.0},
                 tintable=["leaf"],
                 notes="Origin at trunk base. Weeping umbrella tree ~7 m with flat tiered canopy (~5 m wide), sunset palette (crimson/orange/amber) + small emissive blossoms. Materials: bark, bark_dark, leaf_dark/leaf/leaf_light (tintable 'leaf'), blossom (emissive).")
print(info)
