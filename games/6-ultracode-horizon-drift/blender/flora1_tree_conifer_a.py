import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

ID = "tree_conifer_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_bark", "#6e4a34", rough=0.95),
    F.M(ID + "_bark_dark", "#40291f", rough=1.0),
    F.M(ID + "_leaf_dark", "#062a3a", rough=0.8),
    F.M(ID + "_leaf", "#0b6650", rough=0.75),
    F.M(ID + "_leaf_light", "#4fd68e", rough=0.7),
    F.M(ID + "_cone", "#a9703a", rough=0.7),
]
BARK, BARKD, LDARK, LMID, LLIGHT, CONE = range(6)
b = F.Builder(mats, seed=33)
rng = b.rng
H = 14.0

# ---- trunk ----------------------------------------------------------------------------------------------------------
tp = F.spline([(0, 0, -0.06), (0.10, 0.04, 3.5), (-0.08, 0.06, 7.5), (0.05, -0.04, 11.0), (0.0, 0.0, H - 0.4)], 6)
b.tube(tp, lambda t: 0.06 + 0.46 * (1 - t) ** 1.5 + 0.2 * (1 - t) ** 12, segs=10, mat=lambda i, k: BARKD if k % 3 == 0 else BARK,
       cap0=True, apex=0.9, nz=0.08, nf=1.5, seed=2)
for i in range(4):
    a = i * math.tau / 4 + rng.uniform(-0.3, 0.3)
    dx, dy = math.cos(a), math.sin(a)
    rp = F.spline([(dx * 0.25, dy * 0.25, 0.7), (dx * 0.55, dy * 0.55, 0.28), (dx * 0.95, dy * 0.95, -0.02)], 4)
    b.tube(rp, (0.14, 0.04), segs=6, mat=BARK, nz=0.1, nf=2.0, seed=i)


def trunk_x(z):
    # approximate trunk centre line (so tiers follow the slight bend)
    best = min(range(len(tp)), key=lambda i: abs(tp[i].z - z))
    return tp[best].x, tp[best].y


# ---- tiers -------------------------------------------------------------------------------------------------------------
N_TIER = 14
Z0, Z1 = 1.9, 12.7
NS = 11  # spikes per tier
cone_spots = []
for k in range(N_TIER):
    t = k / (N_TIER - 1.0)
    zk = Z0 + (Z1 - Z0) * (t ** 0.92)
    R = 0.5 + 3.1 * (1 - t) ** 0.95
    Hk = 0.95 + 0.28 * R
    cx, cy = trunk_x(zk)
    rot = rng.uniform(0, math.tau)
    ns = max(8, int(round(NS - 3 * t)))
    A = b.vert((cx, cy, zk + Hk))
    U = b.vert((cx, cy, zk + 0.12 * Hk))
    Mr, tips, vals = [], [], []
    for i in range(ns):
        a = rot + math.tau * i / ns
        a2 = a + math.pi / ns
        Mr.append(b.vert((cx + math.cos(a) * R * 0.42, cy + math.sin(a) * R * 0.42, zk + Hk * 0.34)))
        rr = R * rng.uniform(0.88, 1.1)
        tips.append(b.vert((cx + math.cos(a) * rr, cy + math.sin(a) * rr, zk - 0.5 * (rr / 3.0) - rng.uniform(0, 0.15))))
        rv = R * rng.uniform(0.55, 0.68)
        vals.append(b.vert((cx + math.cos(a2) * rv, cy + math.sin(a2) * rv, zk + 0.02 * Hk + rng.uniform(0, 0.1))))
    for i in range(ns):
        j = (i + 1) % ns
        b.tri(A, Mr[i], Mr[j], LMID)
        b.tri(Mr[i], tips[i], vals[i], LLIGHT)
        b.tri(Mr[i], vals[i], Mr[j], LMID)
        b.tri(Mr[j], vals[i], tips[j], LLIGHT)
        # underside
        b.tri(U, vals[i], tips[i], LDARK)
        b.tri(U, tips[j], vals[i], LDARK)
    if k % 2 == 1 and k > 1:
        for q in range(2):
            i = rng.randrange(ns)
            p = tips[i].co
            cone_spots.append((Vector((p.x, p.y, p.z)), R))

# ---- pine cones --------------------------------------------------------------------------------------------------------
for (p, R) in cone_spots:
    d = Vector((p.x, p.y, 0)).normalized() if (abs(p.x) + abs(p.y)) > 1e-4 else Vector((1, 0, 0))
    b.blob(p - Vector((0, 0, 0.18)) - d * 0.12, (0.13, 0.13, 0.26), subdiv=1, amt=0.12, seed=int(p.z * 10), mat=CONE)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["lush"],
                 {"shape": "cylinder", "radius": 0.5, "height": 14.0, "offset_y": 0.0},
                 tintable=["leaf"],
                 notes="Origin at trunk base. Tall layered conifer ~14 m, 14 star-shaped drooping skirts (tier radius 3.2 m at the bottom). Materials: bark, bark_dark, leaf_dark/leaf/leaf_light (tintable 'leaf'), cone.")
print(info)
