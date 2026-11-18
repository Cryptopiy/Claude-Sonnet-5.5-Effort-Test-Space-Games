"""flora2 / cactus_b : ~1.2 m barrel-cactus cluster (central barrel + pups + a short branching column), golden spines and yellow blooms."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

MID = "cactus_b"
rng = random.Random(23)
col = L.fresh_collection(MID)
m_skin = L.mat(MID + "_skin", F.hexcol("#2f9a7c"), roughness=0.5)
m_spine = F.mat_dbl(MID + "_spine", F.hexcol("#ffd98a"), roughness=0.55)
m_flower = F.mat_dbl(MID + "_flower", F.hexcol("#ffc21a"), roughness=0.5, emission=F.hexcol("#ff9a00"), emission_strength=2.6)

bm = bmesh.new()
tufts = []


def barrel(cx, cy, H, R, ribs, lean=(0.0, 0.0), depth=0.14, flowers=7, tuft_rows=5, tuft_len=0.11, squash=1.0):
    prof = []
    n = 8 if ribs > 12 else 6
    for i in range(n):
        f = i / (n - 1)
        # egg shaped barrel: wide at 40% height, flat-ish base, domed crown
        rr = R * (math.sin(math.pi * (0.06 + 0.88 * f)) ** 0.62)
        prof.append((H * f, max(rr, 0.04 * R)))

    def mod(th, z, r, i):
        return r * (1.0 - depth * (0.5 - 0.5 * math.cos(ribs * th)) ** 1.5)

    def centre(z):
        f = z / H
        return (cx + lean[0] * f * f, cy + lean[1] * f * f)

    rings = F.lathe(bm, prof, segs=ribs * 2, mod=mod, centre=centre, cap_top="apex", cap_bottom=None, mat=0, top_dome=-0.01)
    # spine areoles on the ridges
    for i in range(1, n - 1):
        if (i % 2) != 1:
            continue
        z, r0 = prof[i]
        c = centre(z)
        for j in range(ribs):
            th = F.TAU * j / ribs
            out = Vector((math.cos(th), math.sin(th), 0.0))
            # tilt outward vector with the barrel's slope
            slope = (prof[i + 1][1] - prof[i - 1][1]) / max(prof[i + 1][0] - prof[i - 1][0], 1e-4)
            nrm = (out - Vector((0, 0, slope))).normalized()
            pos = Vector((c[0], c[1], z)) + out * r0
            tufts.append((pos, nrm, Vector((0, 0, 1)), tuft_len))
    # crown of flowers around the top
    ztop = H
    ct = centre(ztop)
    for j in range(flowers):
        th = F.TAU * j / flowers + rng.random() * 0.5
        rr = R * rng.uniform(0.22, 0.42)
        pos = Vector((ct[0] + math.cos(th) * rr, ct[1] + math.sin(th) * rr, ztop - 0.02 * H + rng.uniform(0, 0.03)))
        F.flower(bm, pos, Vector((math.cos(th) * 0.25, math.sin(th) * 0.25, 1.0)), 0.075 * (R / 0.4) * rng.uniform(0.85, 1.2), 2, rng, petals=6, two_sided=False)


# central barrel + pups
barrel(0.0, 0.0, 0.92, 0.40, 14, lean=(0.03, 0.02), flowers=8, tuft_len=0.12)
barrel(0.58, 0.12, 0.55, 0.26, 9, lean=(0.06, 0.0), flowers=5, tuft_len=0.09)
barrel(-0.42, 0.40, 0.42, 0.22, 8, lean=(-0.05, 0.02), flowers=4, tuft_len=0.08)
barrel(-0.30, -0.45, 0.34, 0.18, 7, lean=(0.0, -0.04), flowers=3, tuft_len=0.07)
barrel(0.30, -0.5, 0.26, 0.15, 7, lean=(0.03, -0.02), flowers=3, tuft_len=0.06)

# short branching columnar offshoot (gives the cluster a taller secondary read, ~1.2 m)
path = F.catmull([(0.3, 0.25, 0.05), (0.38, 0.3, 0.35), (0.36, 0.4, 0.75), (0.3, 0.46, 1.1)], 5)
R0, R1 = 0.13, 0.105
radii = [F.lerp(R0, R1, i / (len(path) - 1)) for i in range(len(path))]
path2, radii2, tip_b = F.extend_dome(path, radii, 0.14, 3)
info = F.tube(bm, path2, radii2, segs=14, mat=0, cap_a=None, cap_b="apex", tip_b=tip_b,
              profile=lambda th, u: 1.0 - 0.15 * (0.5 - 0.5 * math.cos(7 * th)) ** 1.5, ref=Vector((0, 1, 0)))
for i in range(1, len(path) - 1, 3):
    inf = info[i]
    for j in range(7):
        th = F.TAU * j / 7
        out = inf["n"] * math.cos(th) + inf["b"] * math.sin(th)
        tufts.append((inf["p"] + out * inf["r"] * 0.99, out, inf["t"], 0.08))
top = info[len(path) - 1]
for j in range(5):
    th = F.TAU * j / 5 + rng.random() * 0.5
    out = top["n"] * math.cos(th) + top["b"] * math.sin(th)
    pos = top["p"] + top["t"] * 0.09 + out * 0.07
    F.flower(bm, pos, (out * 0.3 + top["t"]).normalized(), 0.07, 2, rng, petals=6, two_sided=False)

for pos, out, up, ln in tufts:
    F.spine_tuft(bm, pos, out, up, n=3, length=ln, width=0.011, spread=0.7, mat=1, rng=rng, two_sided=False)

F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, [m_skin, m_spine, m_flower], smooth_deg=50)
F.finish(MID, [ob], "flora", ["desert"],
         {"shape": "cylinder", "radius": 0.7, "height": 0.95, "offset_y": 0.0},
         tintable=["skin", "flower"],
         notes="Barrel-cactus cluster: central barrel, 4 pups and a short branching column. Origin at ground centre of the main barrel. "
               "Materials: skin, spine (two-sided needles), flower (emissive golden-yellow).")
