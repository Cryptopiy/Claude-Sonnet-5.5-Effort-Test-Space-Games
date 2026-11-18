import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

# bush_lush_a (v2): leafy shrub built from a shell of overlapping folded leaf cards around a hidden dark core,
# 7 woody stems at the base and clustered emissive berries. ~1.25 m high, ~2 m wide.
ID = "bush_lush_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_stem", "#6a4630", rough=0.95),
    F.M(ID + "_leaf_dark", "#0b5a46", rough=0.75),
    F.M(ID + "_leaf", "#1fa046", rough=0.7),
    F.M(ID + "_leaf_light", "#6fd04a", rough=0.65),
    F.M(ID + "_berry", "#ff3b8d", rough=0.3, emit="#ff2f86", emit_strength=2.4),
]
STEM, LDARK, LMID, LLIGHT, BERRY = range(5)
b = F.Builder(mats, seed=21)
rng = b.rng

# --- hidden dark core so the shell never shows daylight through it
b.blob((0.0, 0.0, 0.5), (0.5, 0.5, 0.36), subdiv=2, amt=0.25, freq=1.4, seed=3, mat=LDARK)

# --- woody stems at the base (mostly covered by leaves, visible between the lowest ones)
for i in range(7):
    a = i * math.tau / 7 + rng.uniform(-0.25, 0.25)
    d = Vector((math.cos(a) * 0.75, math.sin(a) * 0.75, 1.0))
    b.branch((math.cos(a) * 0.06, math.sin(a) * 0.06, -0.02), d, rng.uniform(0.45, 0.7), 0.03, 0.012,
             bend=(math.cos(a), math.sin(a), 0.4), bend_amt=0.25, wobble=0.08, steps=3, segs=5, mat=STEM, seed=i)

# --- leaf shell: golden-spiral samples on an ellipsoid, leaves point outward/up with a droop, overlapping like shingles
CEN = Vector((0.0, 0.0, 0.52))
RAD = Vector((0.7, 0.7, 0.56))
GOLD = math.pi * (3.0 - math.sqrt(5.0))


def shell(n, zmin, zmax, rscale, len_rng, wid, dark_bias, off):
    pts = []
    for k in range(n):
        z = zmin + (zmax - zmin) * (k + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = k * GOLD + off
        u = Vector((math.cos(a) * r, math.sin(a) * r, z))
        p = CEN + Vector((u.x * RAD.x, u.y * RAD.y, u.z * RAD.z)) * rscale
        nrm = Vector((u.x / RAD.x, u.y / RAD.y, u.z / RAD.z)).normalized()
        pts.append((p, nrm))
    return pts


berry_pts = []
for (p, nrm, ln, wid, dbias) in (
        [(p, n, (0.30, 0.42), 0.55, 0.0) for (p, n) in shell(150, -0.2, 1.0, 1.0, None, None, 0.0, 0.3)] +
        [(p, n, (0.26, 0.36), 0.58, -0.5) for (p, n) in shell(80, -0.1, 1.0, 0.72, None, None, 0.0, 1.9)]):
    az = rng.uniform(-0.5, 0.5)
    d = (nrm + Vector((0, 0, 0.30))).normalized()
    d = Matrix.Rotation(az, 3, Vector((0, 0, 1))) @ d
    length = rng.uniform(*ln)
    s = nrm.z * 0.85 + 0.45 * noise.noise(p * 2.3) + dbias + rng.uniform(-0.12, 0.12)
    mat = LDARK if s < -0.05 else (LMID if s < 0.5 else LLIGHT)
    b.leaf(p - nrm * 0.1, d, length, length * wid, mat=mat, fold=0.22, droop=0.22, roll=rng.uniform(-0.5, 0.5))
    if dbias == 0.0 and 0.05 < nrm.z < 0.8:
        berry_pts.append((p, nrm))

# --- berries in small clusters on the outer shell
rng.shuffle(berry_pts)
for (p, nrm) in berry_pts[:6]:
    for k in range(3):
        off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.07
        b.blob(p + nrm * 0.16 + off, rng.uniform(0.04, 0.055), subdiv=1, amt=0.0, mat=BERRY)

b.clamp_min_z(-0.02)
ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["lush"],
                 {"shape": "none"},
                 tintable=["leaf"],
                 notes="Origin at ground centre. Lush leafy shrub ~1.25 m high, ~2 m wide: ~230 overlapping two-sided folded leaf cards around a hidden dark core, 7 woody stems, clustered emissive pink berries. Materials: stem, leaf_dark/leaf/leaf_light (tintable 'leaf'), berry (emissive).")
print(info)
