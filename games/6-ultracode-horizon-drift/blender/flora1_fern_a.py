import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "fern_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_rachis", "#5f8a30", rough=0.7),
    F.M(ID + "_leaf_dark", "#1b7a3e", rough=0.7),
    F.M(ID + "_leaf", "#34b24a", rough=0.65),
    F.M(ID + "_leaf_light", "#86da5c", rough=0.6),
]
RACH, LD, LM, LL = range(4)
b = F.Builder(mats, seed=52)
rng = b.rng
NF = 11
for fi in range(NF):
    a = fi * 2.39996 + rng.uniform(-0.1, 0.1)
    young = fi % 4 == 3
    el0 = math.radians(rng.uniform(58, 72) if young else rng.uniform(22, 48))
    droop = math.radians(rng.uniform(40, 65) if not young else rng.uniform(10, 25))
    Lf = rng.uniform(0.7, 0.95) * (0.85 if young else 1.0)
    steps = 8
    p = Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.02))
    pts = [p.copy()]
    for k in range(steps):
        t = (k + 0.5) / steps
        el = el0 - droop * (t ** 1.4)
        d = Vector((math.cos(el) * math.cos(a), math.cos(el) * math.sin(a), math.sin(el)))
        p = p + d * (Lf / steps)
        pts.append(p.copy())
    b.tube(pts, (0.014, 0.004), segs=3, mat=RACH, cap1=True)
    NP = 14
    for k in range(NP):
        t = 0.1 + 0.88 * k / (NP - 1.0)
        pos, tan = F.polyline_at(pts, t)
        side = tan.cross(Z)
        if side.length < 1e-3:
            side = tan.cross(X)
        side.normalize()
        ln = 0.24 * (1.0 - t) ** 0.55 + 0.03
        wd = ln * 0.34
        mat = LD if t < 0.38 else (LM if t < 0.72 else LL)
        if fi % 3 == 0 and t > 0.3:
            mat = LL if t > 0.6 else LM
        for sgn in (1, -1):
            dv = (tan * math.cos(math.radians(58)) + side * (sgn * math.sin(math.radians(58)))).normalized()
            dv.z -= 0.18
            b.blade(pos, dv.normalized(), ln, wd, mat=mat, up=Z, droop=0.12, mid=0.42)
    # tip leaflet
    pos, tan = F.polyline_at(pts, 1.0)
    b.blade(pos, tan, 0.1, 0.045, mat=LL, up=Z, droop=0.1)

# fiddleheads in the centre
for fi in range(2):
    a = fi * 3.1 + 0.4
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for k in range(16):
        th = k / 15.0 * 3.6 * math.pi
        rr = 0.075 * (1.0 - k / 17.0)
        # stalk rises first, then coils in the vertical plane along the outward axis
        zc = 0.28 + 0.0 + rr * math.sin(th) * 1.0
        out = 0.05 + rr * (1 - math.cos(th))
        if k < 6:
            pts.append(Vector((ca * 0.04, sa * 0.04, 0.02 + k * 0.05)))
        else:
            pts.append(Vector((ca * (0.04 + out * 0.9), sa * (0.04 + out * 0.9), zc - 0.02 + (k - 6) * 0.004)))
    b.tube(pts, lambda t: 0.014 * (1 - 0.8 * t) + 0.004, segs=4, mat=LL, cap1=True)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["lush", "swamp", "ocean"],
                 {"shape": "none"},
                 tintable=["leaf"],
                 notes="Origin at ground centre. Rosette of 11 arching fronds with two-sided leaflets (3 green tones, dark base -> light tips; tintable 'leaf') + 2 fiddleheads, ~1.6 m wide.",
                 views=((35, 28), (125, 28), (215, 28), (305, 28), (0, 82), (80, 6)), dist_mult=1.5)
print(info)
