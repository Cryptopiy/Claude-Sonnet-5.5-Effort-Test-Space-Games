import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "exotic_spiral_horn_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_horn_a", "#f6e3c2", rough=0.4, spec=0.5),
    F.M(ID + "_horn_b", "#b23ad8", rough=0.4, spec=0.5),
    F.M(ID + "_glow", "#ffd23c", rough=0.35, emit="#ffb81f", emit_strength=5.0),
    F.M(ID + "_sheath", "#1fb89c", rough=0.55),
    F.M(ID + "_sheath_b", "#127c74", rough=0.6),
]
HA, HB, GLOW, SH, SHB = range(5)
b = F.Builder(mats, seed=36)
rng = b.rng
LOBES = 2
SEGS = 10


def horn(ctrl, r_base, turns, glow_n=3, samples=6, lobes=LOBES):
    path = F.spline(ctrl, samples)
    n = len(path)
    twist = turns * math.tau

    def mat(i, k):
        if i >= n - 1 - glow_n:
            return GLOW
        ph = math.cos(lobes * (math.tau * (k + 0.5) / SEGS + twist * (i / (n - 1.0))))
        return HA if ph > 0 else HB
    b.tube(path, lambda t: r_base * (1.0 - t) ** 0.9 + 0.03, segs=SEGS, mat=mat, cap0=True, cap1=True, twist=twist,
           rmod=lambda t, a, k: 1.0 + 0.22 * math.cos(lobes * a) * (1.0 - 0.5 * t), nz=0.0)
    return path


# ---- main horn + satellites ---------------------------------------------------------------------------------------------------
main = horn([(0, 0, -0.05), (0.25, 0.1, 1.4), (0.05, 0.4, 2.7), (0.45, 0.3, 4.1), (0.9, 0.15, 5.4)], 0.68, 1.5, glow_n=6, samples=10)
tip = main[-1]
b.blob(tip + Vector((0.0, 0.0, 0.18)), (0.13, 0.13, 0.2), subdiv=2, amt=0.0, mat=GLOW)
sats = []
for i in range(4):
    a = i * math.tau / 4 + 0.5
    r = rng.uniform(1.0, 1.35)
    h = rng.uniform(2.1, 3.7)
    bx, by = math.cos(a) * r, math.sin(a) * r
    ctrl = [(bx, by, -0.05), (bx + math.cos(a) * 0.35, by + math.sin(a) * 0.35, h * 0.4),
            (bx + math.cos(a) * 0.75 + rng.uniform(-0.2, 0.2), by + math.sin(a) * 0.75, h * 0.75),
            (bx + math.cos(a) * 1.05, by + math.sin(a) * 1.05, h)]
    sats.append(horn(ctrl, rng.uniform(0.3, 0.4), rng.choice((-1.2, 1.2)), glow_n=3, samples=7))
for sp in sats:
    b.blob(sp[-1] + Vector((0, 0, 0.1)), (0.08, 0.08, 0.12), subdiv=1, amt=0.0, mat=GLOW)

# ---- bulbous base + sheath leaves -----------------------------------------------------------------------------------------------
b.blob((0, 0, 0.3), (1.0, 1.0, 0.5), subdiv=2, amt=0.2, freq=1.3, seed=4, mat=SHB, flat_bottom=0.6)
NS = 9
for i in range(NS):
    a = i * math.tau / NS + rng.uniform(-0.15, 0.15)
    ca, sa = math.cos(a), math.sin(a)
    Ls = rng.uniform(1.6, 2.5)
    r0 = 0.45
    pts = F.spline([(ca * r0, sa * r0, 0.05), (ca * (r0 + 0.35), sa * (r0 + 0.35), Ls * 0.35),
                    (ca * (r0 + 0.75), sa * (r0 + 0.75), Ls * 0.62), (ca * (r0 + 1.35), sa * (r0 + 1.35), Ls * 0.78)], 3)
    hint = Vector((ca, sa, 0.4))
    b.ribbon(pts, lambda t: (0.25 + 0.95 * math.sin(math.pi * min(1.0, t * 1.1) ** 0.8)) if t < 0.99 else 0.05,
             normal_hint=hint, mat=SH if i % 2 == 0 else SHB)
# glowing spores floating around the tip
for i in range(6):
    a = rng.uniform(0, math.tau)
    p = tip + Vector((math.cos(a) * rng.uniform(0.35, 0.8), math.sin(a) * rng.uniform(0.35, 0.8), rng.uniform(-0.8, 0.9)))
    b.blob(p, 0.055, subdiv=1, amt=0.0, mat=GLOW)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["exotic"],
                 {"shape": "cylinder", "radius": 0.7, "height": 6.0, "offset_y": 0.0},
                 tintable=["sheath", "horn_b"],
                 notes="Origin at the base centre. ~6 m spiral horn (2-lobed helical ridges, 1.5 turns, cream/violet stripes via horn_a/horn_b) with a golden emissive tip (glow, 5.0), 4 satellite horns 2-3.7 m, teal sheath leaves (sheath, sheath_b) and a few floating glow spores. The main horn leans to +X.")
print(info)
