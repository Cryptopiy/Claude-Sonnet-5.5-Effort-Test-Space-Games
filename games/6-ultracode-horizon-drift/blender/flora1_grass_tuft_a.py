import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

# grass_tuft_a (v2): 9 tall 3-segment blades + 9 short 2-segment blades = 144 tris (two-sided, explicit back faces).
# The blade width axis is perpendicular to the lean direction, so every blade bends out of its own face plane (natural
# arching blade, no stiff "prism" look). Three tones dark base -> mid -> light tip (all contain 'blade' -> tintable).
ID = "grass_tuft_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_blade", "#2a8a33", rough=0.8),
    F.M(ID + "_blade_mid", "#58bb3d", rough=0.75),
    F.M(ID + "_blade_tip", "#b6e85c", rough=0.7),
]
b = F.Builder(mats, seed=8)
rng = b.rng


def blade(a, r0, h, lean, w0, segs, mats_by_row):
    cx, cy = math.cos(a) * r0, math.sin(a) * r0
    la = a + rng.uniform(-0.35, 0.35)
    lx, ly = math.cos(la), math.sin(la)
    pts = []
    for i in range(segs + 1):
        t = i / float(segs)
        k = lean * t ** 1.7
        pts.append(Vector((cx + lx * k, cy + ly * k, h * (t - 0.28 * t ** 3))))
    wid = [w0 * f for f in ((1.0, 0.92, 0.66, 0.0) if segs == 3 else (1.0, 0.7, 0.0))]
    hint = Vector((lx, ly, 0.0))
    b.ribbon(pts, wid, normal_hint=hint, matfn=lambda ri, rj: mats_by_row[min(ri, len(mats_by_row) - 1)])


for i in range(9):
    a = i * math.tau / 9 + rng.uniform(-0.25, 0.25)
    blade(a, rng.uniform(0.0, 0.05), rng.uniform(0.50, 0.78), rng.uniform(0.12, 0.30), 0.044, 3, (0, 1, 2))
for i in range(9):
    a = (i + 0.5) * math.tau / 9 + rng.uniform(-0.25, 0.25)
    blade(a, rng.uniform(0.03, 0.08), rng.uniform(0.26, 0.42), rng.uniform(0.20, 0.40), 0.042, 2, (1, 2))

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["lush", "swamp", "ocean"],
                 {"shape": "none"},
                 tintable=["blade"],
                 notes="Origin at ground centre. Two-sided grass blades (18 arching blades: 9 tall + 9 short, 3 tone materials blade / blade_mid / blade_tip from dark base to light tip), ~0.6 m. Intended for MultiMesh scattering; tint via 'blade' materials.",
                 views=((35, 25), (125, 25), (215, 25), (305, 25), (0, 82), (80, 5)), dist_mult=1.5)
print(info)
