import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

ID = "exotic_crystal_tree_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_trunk", "#2d2250", rough=0.75, spec=0.5),
    F.M(ID + "_crystal_a", "#38dcff", rough=0.1, emit="#22c4ff", emit_strength=2.2, alpha=0.55, spec=0.5),
    F.M(ID + "_crystal_b", "#ff5fd2", rough=0.1, emit="#ff38c4", emit_strength=2.2, alpha=0.55, spec=0.5),
    F.M(ID + "_core", "#e8ffff", rough=0.3, emit="#b6f5ff", emit_strength=6.0),
]
TRUNK, CA, CB, CORE = range(4)
b = F.Builder(mats, seed=61)
b.flat = {0, 1, 2, 3}
rng = b.rng

# ---- base mound + trunk ------------------------------------------------------------------------------------------------
b.blob((0, 0, 0.18), (1.15, 1.15, 0.5), subdiv=2, amt=0.28, freq=1.3, seed=4, mat=TRUNK, flat_bottom=0.5)
tp = F.spline([(0, 0, -0.04), (0.14, 0.05, 1.2), (-0.10, 0.10, 2.4), (0.10, -0.05, 3.6), (0.0, 0.0, 4.5)], 5)
b.tube(tp, lambda t: 0.62 - 0.32 * t - 0.1 * t * t + 0.16 * (1 - t) ** 5, segs=6, mat=TRUNK, cap0=True, cap1=True, twist=1.3, nz=0.05, nf=1.2, seed=1)
for i in range(6):
    a = i * math.tau / 6 + rng.uniform(-0.3, 0.3)
    el = math.radians(rng.uniform(45, 70))
    d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    b.crystal(Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.05)), d, rng.uniform(0.9, 1.5), 0.13, sides=5, mat=CB if i % 2 else TRUNK, seed=i)


def trunk_at(z):
    best = min(range(len(tp)), key=lambda i: abs(tp[i].z - z))
    return tp[best]


# ---- branches --------------------------------------------------------------------------------------------------------------
for i in range(6):
    z = 2.3 + i * 0.36
    a = i * 2.39996 + 0.4
    tc = trunk_at(z)
    el = math.radians(rng.uniform(26, 42))
    d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    start = Vector((tc.x, tc.y, z)) + Vector((math.cos(a), math.sin(a), 0)) * 0.12
    cm = CA if i % 2 == 0 else CB
    end, ed, info = b.branch(start, d, rng.uniform(2.4, 3.1), 0.24, 0.1, bend=(0, 0, 1), bend_amt=0.7, wobble=0.06, steps=5, segs=6, mat=cm, seed=i)
    # inner glowing core following the branch
    cp = info.pts
    b.tube(cp[1:], lambda t: 0.075 * (1 - 0.6 * t), segs=4, mat=CORE, cap0=True, cap1=True)
    # side shards
    for (pi, sgn) in ((2, 1), (3, -1)):
        pp = cp[pi]
        side = Vector((-d.y, d.x, 0)).normalized() * sgn
        sd = (side * 0.8 + Vector((0, 0, 0.7))).normalized()
        b.crystal(pp, sd, rng.uniform(0.45, 0.7), 0.055, sides=5, mat=cm, seed=i * 3 + pi)
    # tip cluster
    for k in range(4):
        jit = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.2, 0.7)))
        cd = (ed + jit).normalized()
        ln = rng.uniform(0.9, 1.6)
        rr = rng.uniform(0.07, 0.12)
        mm = CB if cm == CA else CA
        if k == 0:
            mm = cm
        b.crystal(end - ed * 0.05, cd, ln, rr, sides=6, mat=mm, seed=i * 7 + k)
        b.crystal(end - ed * 0.02, cd, ln * 0.78, rr * 0.3, sides=4, mat=CORE, cap0=False, seed=i * 7 + k + 99)

    # forked sub-branch
    pf = cp[3]
    sa = a + (1 if i % 2 == 0 else -1) * 0.8
    sd2 = Vector((math.cos(sa) * 0.8, math.sin(sa) * 0.8, 0.6)).normalized()
    e2, d2, info2 = b.branch(pf, sd2, rng.uniform(1.3, 1.8), 0.12, 0.06, bend=(0, 0, 1), bend_amt=0.6, wobble=0.05, steps=4, segs=5, mat=cm, seed=i + 50)
    b.tube(info2.pts[1:], lambda t: 0.04 * (1 - 0.6 * t), segs=4, mat=CORE, cap0=True, cap1=True)
    for k in range(3):
        jit = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.1, 0.7)))
        cd = (d2 + jit).normalized()
        ln = rng.uniform(0.6, 1.1)
        rr = rng.uniform(0.055, 0.09)
        b.crystal(e2 - d2 * 0.05, cd, ln, rr, sides=6, mat=CB if cm == CA else CA, seed=i * 11 + k)
        b.crystal(e2 - d2 * 0.02, cd, ln * 0.78, rr * 0.3, sides=4, mat=CORE, cap0=False, seed=i * 11 + k + 99)

# ---- crown spire ----------------------------------------------------------------------------------------------------------
top = Vector((tp[-1].x, tp[-1].y, 4.4))
b.crystal(top, (0.03, 0.02, 1), 2.8, 0.3, sides=6, tip=0.32, taper=0.78, mat=CA, seed=200)
b.crystal(top + Vector((0, 0, 0.1)), (0.03, 0.02, 1), 2.35, 0.1, sides=4, tip=0.35, mat=CORE, cap0=False, seed=201)
for i in range(4):
    a = i * math.tau / 4 + 0.6
    d = Vector((math.cos(a) * 0.42, math.sin(a) * 0.42, 1)).normalized()
    ln = rng.uniform(1.4, 2.0)
    b.crystal(top + Vector((math.cos(a), math.sin(a), 0)) * 0.12, d, ln, 0.17, sides=6, mat=CB if i % 2 == 0 else CA, seed=210 + i)
    b.crystal(top + Vector((math.cos(a), math.sin(a), 0.05)) * 0.12, d, ln * 0.8, 0.055, sides=4, mat=CORE, cap0=False, seed=220 + i)
# a few free-floating shards
for i in range(4):
    a = rng.uniform(0, math.tau)
    p = Vector((math.cos(a) * rng.uniform(0.9, 1.6), math.sin(a) * rng.uniform(0.9, 1.6), rng.uniform(4.6, 6.4)))
    b.crystal(p, rand_unit if False else Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 1)), rng.uniform(0.25, 0.4), 0.05, sides=4, mat=CB if i % 2 else CA, seed=300 + i)

ob = b.finish(ID + "_mesh", col, flat_mats=(0, 1, 2, 3))
info = F.publish(ID, [ob], "flora", ["exotic"],
                 {"shape": "cylinder", "radius": 0.6, "height": 4.5, "offset_y": 0.0},
                 tintable=["crystal"],
                 notes="Origin at trunk base. Dark twisted crystalline trunk with 6 translucent crystal branches (alpha 0.55, emissive) + opaque emissive inner cores (core). Materials: trunk, crystal_a (cyan), crystal_b (magenta) [tintable 'crystal'], core (emissive 6.0). Flat shaded. ~7 m.")
print(info)
