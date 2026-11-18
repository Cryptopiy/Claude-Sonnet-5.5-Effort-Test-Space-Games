import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "reed_cluster_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_reed", "#7fa83a", rough=0.8),
    F.M(ID + "_reed_tip", "#c4d060", rough=0.75),
    F.M(ID + "_reed_dry", "#b79a52", rough=0.85),
    F.M(ID + "_cattail", "#5b3420", rough=0.9),
    F.M(ID + "_stem", "#6f9a36", rough=0.7),
]
REED, TIP, DRY, CAT, STEM = range(5)
b = F.Builder(mats, seed=71)
rng = b.rng
NB = 26
for i in range(NB):
    a = rng.uniform(0, math.tau)
    r0 = rng.uniform(0.0, 0.32)
    cx, cy = math.cos(a) * r0, math.sin(a) * r0
    h = rng.uniform(1.1, 2.1)
    if i % 6 == 0:
        h *= 0.55
    lean = rng.uniform(0.1, 0.7) * (h / 1.6)
    la = a + rng.uniform(-0.6, 0.6)
    lx, ly = math.cos(la), math.sin(la)
    pts = []
    for t in (0.0, 0.35, 0.7, 1.0):
        pts.append(Vector((cx + lx * lean * t ** 2.0, cy + ly * lean * t ** 2.0, h * (t - 0.18 * t ** 3))))
    hint = Vector((math.cos(la + 1.4), math.sin(la + 1.4), 0))
    dry = (i % 7 == 3)
    b.ribbon(pts, (0.07, 0.012), normal_hint=hint, matfn=(lambda ri, rj: DRY) if dry else (lambda ri, rj: (REED, REED, TIP)[min(ri, 2)]))

# cattails
for i in range(5):
    a = i * math.tau / 5 + rng.uniform(-0.4, 0.4)
    r0 = rng.uniform(0.05, 0.3)
    h = rng.uniform(1.5, 2.2)
    lean = rng.uniform(0.15, 0.5)
    base = Vector((math.cos(a) * r0, math.sin(a) * r0, 0))
    top = base + Vector((math.cos(a) * lean, math.sin(a) * lean, h))
    sp = F.spline([base, base.lerp(top, 0.5) + Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0)), top], 3)
    b.tube(sp, (0.016, 0.009), segs=4, mat=STEM, cap1=True)
    d = (sp[-1] - sp[-3]).normalized()
    b.tube([top - d * 0.02, top + d * 0.26], (0.042, 0.042), segs=6, mat=CAT, cap0=True, cap1=True, nz=0.05, nf=8.0, seed=i)
    b.tube([top + d * 0.25, top + d * 0.5], (0.01, 0.004), segs=4, mat=STEM, cap1=True)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["swamp", "lush", "ocean"],
                 {"shape": "none"},
                 tintable=["reed"],
                 notes="Origin at ground centre. 26 two-sided reed blades (1.1-2.1 m, a few dry) + 5 cattail spikes (cattail). Materials: reed, reed_tip, reed_dry [tintable 'reed'], cattail, stem. Intended for swamp shores / MultiMesh.",
                 views=((35, 15), (125, 15), (215, 15), (305, 15), (0, 82), (80, 3)), dist_mult=1.7)
print(info)
