import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix

ID = "tentacle_plant_a"
col = L.fresh_collection(ID)
m_flesh = L.mat(ID + "_flesh", (0.50, 0.04, 0.30), roughness=0.45, specular=0.5)
m_base = L.mat(ID + "_base", (0.10, 0.14, 0.05), roughness=0.85, specular=0.3)
m_glow = L.mat(ID + "_glow", (0.10, 0.9, 0.85), roughness=0.4, emission=(0.05, 0.95, 0.80), emission_strength=3.0)
m_sucker = L.mat(ID + "_sucker", (0.85, 0.55, 0.40), roughness=0.5, specular=0.4)
mats = [m_flesh, m_base, m_glow, m_sucker]
rg = random.Random(77)
parts = []


def tendril(az, r_start, length, e0, e1, wiggle, seed, base_r=0.15, n=13, tip_curl=2.2):
    r_ = random.Random(seed)
    ph = r_.uniform(0, math.tau)
    pts = []
    cur = Vector((math.cos(az) * r_start, math.sin(az) * r_start, 0.35))
    pts.append(cur.copy())
    dirs = []
    for i in range(n):
        t = i / (n - 1)
        e = math.radians(e0 + (e1 - e0) * (t ** tip_curl))
        a = az + wiggle * math.sin(t * math.pi * 1.4 + ph) + 0.35 * t
        d = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
        step = length / n * (1.0 - 0.45 * t ** 2)
        cur = cur + d * step
        pts.append(cur.copy())
        dirs.append(d)
    radii = [base_r * (1 - 0.88 * (i / n) ** 0.8) for i in range(n + 1)]
    tube = F.tube(pts, radii, segs=6, mat=0, rough=0.07, seed=seed, cap_start=False, cap_end=True, twist=0.12)
    return tube, pts, radii


# --- base: fleshy bulb mound with a ring of nubs -----------------------------------------------------
base = F.rock_blob(0.85, 3, 0.22, 1.3, 6, (1.0, 1.0, 0.55), flat_bottom=0.2, mat=1)
parts.append(base)
for i in range(7):
    a = i * math.tau / 7 + 0.2
    parts.append(L.bm_sphere(0.1, subdiv=1, matrix=L.xf((math.cos(a) * 0.95, math.sin(a) * 0.95, 0.12), (0, 0, 0), (1, 1, 0.7)), mat_index=2))

cfg = [  # az, start r, length, elev0, elev1, wiggle, base radius
    (0.0, 0.25, 4.2, 86, -40, 0.35, 0.18),
    (0.65, 0.3, 3.2, 78, -30, 0.5, 0.16),
    (1.3, 0.25, 3.8, 84, -55, 0.4, 0.17),
    (2.0, 0.3, 2.9, 72, -20, 0.55, 0.15),
    (2.7, 0.25, 4.0, 85, -45, 0.4, 0.18),
    (3.4, 0.3, 3.1, 76, -35, 0.5, 0.16),
    (4.1, 0.25, 3.6, 82, -40, 0.45, 0.17),
    (4.8, 0.3, 2.7, 66, -15, 0.6, 0.14),
    (5.5, 0.25, 3.4, 80, -45, 0.45, 0.16),
    (0.3, 0.45, 1.7, 50, -30, 0.7, 0.11),
    (2.35, 0.45, 1.6, 46, -35, 0.7, 0.11),
    (4.45, 0.45, 1.8, 48, -30, 0.7, 0.11),
]
for i, (az, rs, ln, e0, e1, wg, br) in enumerate(cfg):
    tb, pts, radii = tendril(az, rs, ln, e0, e1, wg, 100 + i, base_r=br)
    parts.append(tb)
    # glowing tip bulb
    parts.append(L.bm_sphere(0.10 + br * 0.3, subdiv=1, matrix=L.xf(pts[-1]), mat_index=2))
    # suckers along the lower/inner side
    fr = F.frames(pts)
    for j in range(3, len(pts) - 3, 2):
        tt, nn, bb = fr[j]
        side = nn if (j // 2) % 2 == 0 else -nn
        p0 = pts[j] + side * radii[j] * 0.8
        parts.append(F.tube([p0, p0 + side * radii[j] * 1.3], [radii[j] * 0.55, 0.0], segs=5, mat=3, cap_start=False))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["toxic", "swamp", "exotic"], {"shape": "cylinder", "radius": 0.8, "height": 1.2, "offset_y": 0.0},
                 tintable=["flesh", "glow"], notes="Tentacle plant ~3 m: 12 curling tendrils with suckers and glowing tips (emissive 'glow') on a fleshy mound. Origin at centre of the base on the ground. Sway tendrils with a vertex shader or rotate whole model slightly.")
L.save_blend()
