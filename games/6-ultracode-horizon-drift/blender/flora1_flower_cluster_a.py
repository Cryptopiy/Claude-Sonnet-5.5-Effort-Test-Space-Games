import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

ID = "flower_cluster_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_stem", "#2e9a44", rough=0.7),
    F.M(ID + "_petal_a", "#ff4fa6", rough=0.45, emit="#ff3d99", emit_strength=2.6),
    F.M(ID + "_petal_b", "#4cc6ff", rough=0.45, emit="#2db8ff", emit_strength=2.6),
    F.M(ID + "_core", "#ffe66a", rough=0.4, emit="#ffd83a", emit_strength=5.0),
    F.M(ID + "_leaf", "#1f8a3c", rough=0.7),
]
STEM, PA, PB, CORE, LEAF = range(5)
b = F.Builder(mats, seed=17)
rng = b.rng


def flower(base, tip, tilt, size, petal_mat, seed):
    """stem from base to tip (curved), head at tip facing along the end tangent."""
    mid = base.lerp(tip, 0.5) + Vector((tilt[0], tilt[1], 0)) * 0.25
    pts = F.spline([base, mid, tip], 4)
    info = b.tube(pts, (0.014, 0.009), segs=5, mat=STEM, cap1=True)
    d = (pts[-1] - pts[-3]).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    for ring, (n, ln, wd, tl) in enumerate(((6, 0.13 * size, 0.085 * size, 0.62), (5, 0.095 * size, 0.07 * size, 0.38))):
        off = rng.uniform(0, math.tau) + ring * math.pi / n
        for i in range(n):
            a = off + math.tau * i / n
            r = u * math.cos(a) + v * math.sin(a)
            dirv = (d * math.cos(tl) + r * math.sin(tl)).normalized()
            b.leaf(tip - d * 0.01 + r * 0.01, dirv, ln, wd, mat=petal_mat, up=d, fold=-0.25, droop=-0.1, mid=0.6)
    b.blob(tip + d * 0.012, (0.028, 0.028, 0.02), subdiv=1, amt=0.0, mat=CORE, rot=Matrix.Rotation(0, 3, 'Z'))


# leaves at the base
for i in range(7):
    a = i * math.tau / 7 + rng.uniform(-0.3, 0.3)
    d = Vector((math.cos(a), math.sin(a), 0.55 + rng.uniform(0, 0.3))).normalized()
    b.leaf((math.cos(a) * 0.02, math.sin(a) * 0.02, 0.0), d, rng.uniform(0.18, 0.28), rng.uniform(0.07, 0.1), mat=LEAF, fold=0.25, droop=0.35, mid=0.45)

spots = [(0.0, 0.0, 0.46), (0.13, 0.09, 0.36), (-0.14, 0.07, 0.40), (0.05, -0.15, 0.33), (-0.07, -0.12, 0.43), (0.18, -0.06, 0.27), (-0.20, -0.04, 0.29)]
for i, (x, y, h) in enumerate(spots):
    base = Vector((x * 0.25, y * 0.25, 0.0))
    tip = Vector((x, y, h))
    flower(base, tip, (x, y), 1.0 if i < 3 else 0.85, PB if i in (2, 5) else PA, i)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["lush", "exotic", "swamp"],
                 {"shape": "none"},
                 tintable=["petal"],
                 notes="Origin at ground centre. Cluster of 7 flowers with emissive petals (petal_a pink, petal_b cyan; tintable 'petal') and glowing yellow cores, ~0.5 m. Two-sided petals/leaves.",
                 views=((35, 25), (125, 25), (215, 25), (305, 25), (0, 82), (80, 5)), dist_mult=1.5)
print(info)
