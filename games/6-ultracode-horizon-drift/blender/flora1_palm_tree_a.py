import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "palm_tree_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_trunk", "#9a7449", rough=0.95),
    F.M(ID + "_trunk_ring", "#7a5a3a", rough=1.0),
    F.M(ID + "_frond", "#2fbe4c", rough=0.6),
    F.M(ID + "_frond_dark", "#1b8a3e", rough=0.65),
    F.M(ID + "_rachis", "#7d8d3a", rough=0.7),
    F.M(ID + "_coconut", "#6e4524", rough=0.55),
]
TR, TRR, FR, FRD, RA, CO = range(6)
b = F.Builder(mats, seed=17)
rng = b.rng

# ---- leaning, ringed trunk ----------------------------------------------------------------------------------------------
tp = F.spline([(0, 0, -0.05), (0.22, 0.04, 1.75), (0.72, 0.09, 3.5), (1.4, 0.11, 5.25), (2.05, 0.05, 6.6)], 8)
N = len(tp)
b.tube(tp, lambda t: 0.19 + 0.12 * (1 - t) + 0.16 * (1 - t) ** 9, segs=9, mat=lambda i, k: TRR if i % 2 else TR, cap0=True, cap1=True, nz=0.04, nf=2.5, seed=3,
       rmod=lambda t, a, k: 1.0 + (0.07 if int(round(t * (N - 1))) % 2 else 0.0))
top = tp[-1]
td = (tp[-1] - tp[-3]).normalized()
b.blob(top + Vector((0, 0, 0.1)), (0.28, 0.28, 0.2), subdiv=2, amt=0.15, seed=1, mat=TRR)  # crown shaft

# ---- fronds ------------------------------------------------------------------------------------------------------------------
NFR = 13
for fi in range(NFR):
    a = fi * 2.39996 + rng.uniform(-0.1, 0.1)
    old = fi % 3 == 2
    el0 = math.radians(rng.uniform(52, 70) if fi < 4 else (rng.uniform(25, 48) if fi < 9 else rng.uniform(5, 25)))
    droop = math.radians(rng.uniform(70, 100))
    Lf = rng.uniform(2.8, 3.4)
    steps = 9
    p = top + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.12))
    pts = [p.copy()]
    for k in range(steps):
        t = (k + 0.5) / steps
        el = el0 - droop * (t ** 1.5)
        d = Vector((math.cos(el) * math.cos(a), math.cos(el) * math.sin(a), math.sin(el)))
        p = p + d * (Lf / steps)
        pts.append(p.copy())
    b.tube(pts, (0.045, 0.012), segs=4, mat=RA, cap1=True)
    NP = 17
    for k in range(NP):
        t = 0.12 + 0.86 * k / (NP - 1.0)
        pos, tan = F.polyline_at(pts, t)
        side = tan.cross(Z)
        if side.length < 1e-3:
            side = tan.cross(X)
        side.normalize()
        ln = 1.05 * math.sin(math.pi * (0.08 + 0.82 * (1 - t) ** 0.8)) * (1.0 - 0.35 * t) + 0.12
        wd = 0.12 + 0.03 * ln
        for sgn in (1, -1):
            dv = (tan * 0.45 + side * (sgn * 0.9) + Vector((0, 0, -0.62))).normalized()
            b.blade(pos, dv, ln, wd, mat=FR if (k + (0 if sgn > 0 else 1)) % 2 == 0 else FRD, up=Z, droop=0.1, mid=0.35)
    pos, tan = F.polyline_at(pts, 1.0)
    b.blade(pos, tan, 0.35, 0.1, mat=FR, up=Z, droop=0.3)

# ---- coconuts -----------------------------------------------------------------------------------------------------------------
for i in range(6):
    a = i * math.tau / 6 + 0.3
    q = top + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.2 + rng.uniform(-0.08, 0.05)))
    b.blob(q, (0.15, 0.15, 0.17), subdiv=2, amt=0.06, seed=i, mat=CO)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["ocean", "lush", "swamp"],
                 {"shape": "cylinder", "radius": 0.3, "height": 4.0, "offset_y": 0.0},
                 tintable=["frond"],
                 notes="Origin at trunk base. Palm leaning towards +X (Godot +X) by ~2 m at the crown, ~8.4 m tall; ringed trunk (trunk/trunk_ring alternate), 13 feathery drooping fronds (frond/frond_dark [tintable 'frond'], rachis), 6 coconuts. Collider is only the lower trunk.")
print(info)
