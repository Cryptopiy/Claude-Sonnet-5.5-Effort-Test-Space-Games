import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, noise

ID = "tree_charred_a"
col = L.fresh_collection(ID)
# QA pass 2: two-tone char (dark trunk, lighter scorched outer limbs), glowing broken limb tips, more ember cracks,
# darker warm ash with ember pockets, glowing fallen log.
m_bark = L.mat(ID + "_bark", (0.034, 0.027, 0.024), roughness=0.96, specular=0.2)
m_ash = L.mat(ID + "_ash", (0.052, 0.046, 0.042), roughness=1.0, specular=0.1)
m_ember = L.mat(ID + "_ember", (1.0, 0.25, 0.03), roughness=0.5, emission=(1.0, 0.10, 0.008), emission_strength=3.5)
m_char = L.mat(ID + "_char", (0.150, 0.118, 0.098), roughness=0.95, specular=0.15)
mats = [m_bark, m_ash, m_ember, m_char]
BARK, ASH, EMBER, CHAR = 0, 1, 2, 3
rg = random.Random(33)
parts = []


def furrow(freq, amp, ph):
    return lambda i, k, a: 1.0 + amp * math.sin(a * freq + i * 0.6 + ph) + amp * 0.5 * math.sin(a * (freq + 3) - i)


def branch(p0, d, length, r0, depth, seed, broken=0.0, mat=BARK):
    r_ = random.Random(seed)
    n = 5
    cur = Vector(p0)
    dd = Vector(d).normalized()
    pts = [cur.copy()]
    for i in range(n):
        dd = (dd + Vector((r_.uniform(-1, 1), r_.uniform(-1, 1), r_.uniform(-0.2, 0.5))) * 0.22).normalized()
        cur = cur + dd * (length / n)
        pts.append(cur.copy())
    radii = [r0 * (1.0 - 0.72 * (i / n)) for i in range(n + 1)]
    radii[-1] = 0.0 if not broken else r0 * 0.34
    glow_tip = bool(broken) and r0 > 0.15
    parts.append(F.tube(pts, radii, segs=7 if r0 > 0.12 else 5, mat=mat, rough=0.14, seed=seed, ring_fn=furrow(4, 0.08, seed),
                        cap_start=False, cap_end=True))
    if glow_tip:
        # glowing ember crown on the broken end
        dtip = (pts[-1] - pts[-2]).normalized()
        parts.append(F.rock_blob(max(0.15, radii[-1] * 1.15), 1, 0.2, 1.5, seed % 11, (1.0, 1.0, 0.7), flat_bottom=0.0, mat=EMBER,
                                 center=pts[-1] + dtip * 0.02))
    if depth > 0:
        # sub branches (lighter scorched wood)
        for j in range(2 if depth > 1 else 1):
            idx = r_.randint(2, n - 1)
            base = pts[idx]
            sgn = 1 if j == 0 else -1
            side = Vector((-dd.y, dd.x, 0)).normalized() * sgn
            nd = (dd * 0.7 + side * 0.8 + Vector((0, 0, 0.35))).normalized()
            branch(base, nd, length * r_.uniform(0.45, 0.65), radii[idx] * 0.7, depth - 1, seed * 7 + j + 1, broken=r_.random() < 0.4, mat=CHAR)


# ---- trunk (thicker, deeper char furrows) -----------------------------------------------------------------------
tp = F.bez((0, 0, -0.05), (0.15, -0.1, 1.3), (-0.1, 0.1, 2.3), (0.15, 0.05, 3.6), 8)
rad = []
for i in range(9):
    t = i / 8
    rad.append(0.60 * (1 - 0.34 * t) + 0.55 * (1 - t) ** 5)
trunk = F.tube(tp, rad, segs=12, mat=BARK, rough=0.10, seed=5, ring_fn=furrow(5, 0.13, 1.0), cap_start=False, cap_end=False)
parts.append(trunk)

# split: central limb + spreading major limbs
top = tp[-1]


def on_trunk(z):
    best = min(tp, key=lambda q: abs(q.z - z))
    return best.copy()


branch(top + Vector((0, 0, -0.15)), (-0.25, 0.15, 1.0), 3.0, 0.46, 2, 101, broken=False)
for az, el, ln, r0, sd, brk, zz in [(20, 48, 3.0, 0.34, 202, True, 3.3), (150, 40, 2.8, 0.32, 303, True, 2.9),
                                    (250, 55, 2.6, 0.29, 505, False, 3.1), (320, 33, 2.3, 0.26, 606, True, 2.3),
                                    (95, 28, 2.0, 0.24, 707, True, 1.9), (205, 25, 1.7, 0.22, 808, True, 1.5)]:
    A, E = math.radians(az), math.radians(el)
    branch(on_trunk(zz), (math.cos(A) * math.cos(E), math.sin(A) * math.cos(E), math.sin(E)), ln, r0, 2, sd, broken=brk)
# two thick broken-off stubs low on the trunk with glowing cut faces
for az, el, zz, sd in [(60, 20, 0.95, 911), (265, 14, 1.2, 912)]:
    A, E = math.radians(az), math.radians(el)
    branch(on_trunk(zz), (math.cos(A) * math.cos(E), math.sin(A) * math.cos(E), math.sin(E)), 0.9, 0.30, 0, sd, broken=True)

# ---- roots -----------------------------------------------------------------------------------------
for i in range(6):
    a = i * math.tau / 6 + rg.uniform(-0.25, 0.25)
    ca, sa = math.cos(a), math.sin(a)
    L0 = rg.uniform(1.3, 1.9)
    pts = F.bez((ca * 0.25, sa * 0.25, 0.9), (ca * 0.7, sa * 0.7, 0.55), (ca * 1.1, sa * 1.1, 0.2), (ca * L0, sa * L0, -0.1), 6)
    parts.append(F.tube(pts, [0.28, 0.24, 0.18, 0.13, 0.09, 0.06, 0.04], segs=6, mat=BARK, rough=0.18, seed=20 + i, cap_start=False))

# ---- burning hollow in the trunk (glowing slit with charred lips) ---------------------------------------
slit = F.rock_blob(0.5, 2, 0.1, 2.0, 3, (0.24, 0.13, 1.1), flat_bottom=0.0, mat=EMBER, center=(0.02, 0.42, 1.55))
parts.append(slit)
for sgn in (-1, 1):
    pts = F.bez((sgn * 0.22, 0.40, 0.95), (sgn * 0.33, 0.46, 1.4), (sgn * 0.30, 0.46, 1.9), (sgn * 0.15, 0.40, 2.25), 6)
    parts.append(F.tube(pts, [0.07, 0.13, 0.16, 0.14, 0.11, 0.07, 0.02][:7], segs=5, mat=BARK, rough=0.12, seed=30 + sgn, cap_start=True))

# ---- ember cracks along the trunk -------------------------------------------------------------------------
def start_trunk(r_, verts):
    c = [v for v in verts if 0.3 < v.z < 3.2]
    return r_.choice(c)

veins = F.vein_network(trunk, 15, rg, width=0.042, lift=0.0, steps=(4, 8), step_len=0.2, wander=0.5, fork=0.25, mat=EMBER,
                       start_fn=start_trunk, bias=(0, 0, 1), bias_k=0.3, sides=3)
parts.append(veins)

# ---- fallen log (glowing cracks) + ash mounds with ember pockets -------------------------------------------------
log = F.tube(F.bez((1.5, -1.5, 0.2), (2.0, -1.3, 0.22), (2.6, -1.7, 0.18), (3.2, -1.6, 0.2), 5), [0.24, 0.22, 0.22, 0.2, 0.18, 0.11], segs=7, mat=CHAR,
             rough=0.12, seed=77, cap_start=True, cap_end=True, ring_fn=furrow(4, 0.09, 3))
parts.append(log)
lv = F.vein_network(log, 3, random.Random(9), width=0.03, lift=0.0, steps=(3, 5), step_len=0.2, wander=0.4, fork=0.0, mat=EMBER, sides=3)
if lv is not None:
    parts.append(lv)
parts.append(F.rock_blob(1.45, 2, 0.35, 1.2, 12, (1.0, 1.0, 0.2), flat_bottom=0.1, mat=ASH, center=(0.0, 0.0, 0.0)))
parts.append(F.rock_blob(0.8, 2, 0.3, 1.0, 14, (1.0, 1.0, 0.25), flat_bottom=0.1, mat=ASH, center=(1.9, -1.2, 0.0)))
parts.append(F.rock_blob(0.7, 2, 0.3, 1.0, 16, (1.0, 1.0, 0.25), flat_bottom=0.1, mat=ASH, center=(-1.4, 0.95, 0.0)))
for (ex, ey, er) in [(0.9, 0.7, 0.16), (-0.8, -0.8, 0.14), (1.2, -0.4, 0.12), (-0.5, 1.0, 0.13), (-1.35, 0.9, 0.12), (1.85, -1.25, 0.12)]:
    parts.append(F.rock_blob(er, 1, 0.25, 1.5, int(ex * 10) + 3, (1.0, 1.0, 0.35), flat_bottom=0.05, mat=EMBER, center=(ex, ey, 0.06)))

bm = F.join(*parts)
F.transform(bm, scale=(0.85, 0.85, 0.85))
ob = F.finish(ID, bm, col, mats, smooth_deg=45, floor=-0.1)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["volcanic"], {"shape": "cylinder", "radius": 0.6, "height": 3.5, "offset_y": 0.0},
                 tintable=["ash"], notes="Burnt dead tree ~6 m: thick furrowed trunk, lighter scorched limbs, broken limbs with glowing cut ends, glowing ember slit/cracks (emissive 'ember'), fallen log + dark ash mounds with ember pockets at the base. Origin at trunk base.")
L.save_blend()
