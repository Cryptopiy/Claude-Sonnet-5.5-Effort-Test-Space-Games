import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector

ID = "obsidian_spire_a"
col = L.fresh_collection(ID)
m_glass = L.mat(ID + "_glass", (0.012, 0.010, 0.016), metallic=0.25, roughness=0.10, specular=0.9)
m_rock = L.mat(ID + "_rock", (0.06, 0.045, 0.04), roughness=0.92, specular=0.3)
m_glow = L.mat(ID + "_glow", (1.0, 0.10, 0.015), roughness=0.4, emission=(1.0, 0.06, 0.006), emission_strength=3.5)
mats = [m_glass, m_rock, m_glow]
rng = random.Random(7)


def spire(base, h, r, sides, lean_dir, lean, seed, mat=0, n=7):
    rg = random.Random(seed)
    pts, radii = [], []
    ld = Vector(lean_dir).normalized()
    kink = Vector((rg.uniform(-1, 1), rg.uniform(-1, 1), 0)) * 0.10 * h / 6.0
    for i in range(n + 1):
        t = i / n
        p = Vector(base) + Vector((0, 0, h * t)) + ld * (lean * h * t ** 1.6) + kink * math.sin(t * math.pi * 1.5)
        pts.append(p)
        rr = r * (1 - t) ** 0.8 * (1 + 0.10 * math.sin(t * 8 + seed))
        radii.append(rr)
    radii[-1] = 0
    return F.tube(pts, radii, segs=sides, mat=mat, rough=0.24, seed=seed, twist=0.10, cap_start=True)


# --- rocky mound with glowing grooves -------------------------------------------------------------
mound = F.rock_blob(2.4, 4, 0.20, 0.9, 5, (1.0, 0.95, 0.30), flat_bottom=0.15, ridged=0.4)
cen = Vector((0, 0, 0.1))
F.cell_plates(mound, 9, seed=2, shrink=0.92, depth=0.35, centre=cen, mat_top=1, mat_wall=2, bulge=0.05, bulge_rand=0.03)

# --- spires ---------------------------------------------------------------------------------------
sp = []
sp.append(spire((0.0, 0.0, 0.1), 6.3, 1.0, 7, (0.3, 0.2, 0), 0.07, 1))
cfg = [  # angle, dist, height, radius, lean, sides
    (0.4, 1.35, 4.2, 0.55, 0.20, 6),
    (1.5, 1.5, 3.1, 0.48, 0.28, 6),
    (2.55, 1.3, 4.7, 0.58, 0.18, 7),
    (3.6, 1.55, 2.2, 0.40, 0.30, 5),
    (4.5, 1.25, 3.6, 0.50, 0.22, 6),
    (5.4, 1.5, 1.7, 0.36, 0.34, 5),
    (0.95, 2.15, 1.3, 0.30, 0.35, 5),
    (3.1, 2.1, 1.0, 0.28, 0.4, 5),
    (5.0, 2.0, 1.4, 0.30, 0.33, 5),
]
for i, (a, d, h, r, lean, sd) in enumerate(cfg):
    dirv = (math.cos(a), math.sin(a), 0)
    sp.append(spire((math.cos(a) * d, math.sin(a) * d, 0.05), h, r, sd, dirv, lean, 10 + i))
spires = F.join(*sp)

# --- glowing fissures on the glass (hug the spires, climbing upwards from the base) ----------------
def start_low(rg, verts):
    cand = [v for v in verts if v.z < 1.2]
    return rg.choice(cand)

veins = F.vein_network(spires, 20, rng, width=0.075, lift=0.012, steps=(6, 10), step_len=0.24, wander=0.4, fork=0.3,
                       mat=2, start_fn=start_low, bias=(0, 0, 1), bias_k=0.55, sides=3)

# --- loose shards lying at the base ----------------------------------------------------------------
shards = []
for i in range(7):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(2.1, 3.0)
    L_ = rng.uniform(0.5, 1.1)
    tilt = Vector((math.cos(a) * rng.uniform(0.7, 1.4), math.sin(a) * rng.uniform(0.7, 1.4), rng.uniform(0.4, 1.0)))
    shards.append(F.crystal((math.cos(a) * d, math.sin(a) * d, 0.0), tilt, L_, rng.uniform(0.09, 0.17), sides=5, tip_frac=0.4,
                            taper=0.8, mat=0, seed=40 + i, two_stage=False))

# molten seam ring where the big spires meet the mound
seams = []
for (a, d, h, r, lean, sd) in [(0, 0, 6.3, 1.0, 0, 7)] + cfg[:6]:
    cx, cy = (math.cos(a) * d, math.sin(a) * d) if d else (0, 0)
    rr = r * 1.02
    pts = [Vector((cx + math.cos(t) * rr, cy + math.sin(t) * rr, 0.28)) for t in [i * math.tau / 10 for i in range(11)]]
    seams.append(F.tube(pts, [0.065] * 11, segs=3, mat=2, cap_start=False, cap_end=False))

bm = F.join(mound, spires, veins, *seams, *shards)
ob = F.finish(ID, bm, col, mats, smooth_deg=38, floor=-0.05)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "rock", ["volcanic"], {"shape": "cylinder", "radius": 1.6, "height": 3.0, "offset_y": 0.0},
                 tintable=["glow"], notes="Cluster of glassy black obsidian spires on a cracked mound with glowing red fissures (emissive). Origin at ground centre; tallest spire ~6.3 m.")
L.save_blend()
