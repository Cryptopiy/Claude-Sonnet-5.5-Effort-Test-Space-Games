import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix, noise

ID = "spore_pod_a"
col = L.fresh_collection(ID)
m_leaf = L.mat(ID + "_leaf", (0.05, 0.30, 0.22), roughness=0.55, specular=0.4)
m_pod = L.mat(ID + "_pod", (0.36, 0.06, 0.20), roughness=0.45, specular=0.5)
m_stem = L.mat(ID + "_stem", (0.30, 0.42, 0.12), roughness=0.7, specular=0.3)
m_sac = L.mat(ID + "_sac", (1.0, 0.55, 0.08), roughness=0.35, emission=(1.0, 0.38, 0.02), emission_strength=3.0)
mats = [m_leaf, m_pod, m_stem, m_sac]
LEAF, POD, STEM, SAC = 0, 1, 2, 3
rg = random.Random(5)
parts = []

# --- leaf rosette ---------------------------------------------------------------------------------------------
for i in range(11):
    a = i * math.tau / 11 + rg.uniform(-0.15, 0.15)
    el = math.radians(rg.uniform(28, 62))
    d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    ln = rg.uniform(0.95, 1.5)
    parts.append(F.leaf((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.05), d, ln, rg.uniform(0.3, 0.42), bend=rg.uniform(0.35, 0.7),
                        mat=LEAF, segs=5, fold=0.35, sideways=rg.uniform(-0.15, 0.15), double=True))

# --- pod builder -----------------------------------------------------------------------------------------------
def open_pod(pos, scale, seed, petals=5, sacs=9, tilt=(0.0, 0.0)):
    r_ = random.Random(seed)
    s = scale
    prof = [(0.0, 0.0), (0.15 * s, 0.03 * s), (0.29 * s, 0.17 * s), (0.34 * s, 0.38 * s), (0.30 * s, 0.6 * s), (0.26 * s, 0.74 * s),
            (0.22 * s, 0.68 * s), (0.18 * s, 0.5 * s), (0.0, 0.42 * s)]
    pod = F.lathe(prof, segs=12, mat=POD, ring_fn=lambda i, k, a: 1.0 + 0.07 * math.sin(a * 3 + seed) + 0.03 * math.sin(a * 7))
    out = [pod]
    # petals around the rim
    for k in range(petals):
        a = k * math.tau / petals + r_.uniform(-0.15, 0.15)
        d = Vector((math.cos(a) * 0.75, math.sin(a) * 0.75, 0.65)).normalized()
        out.append(F.leaf((math.cos(a) * 0.2 * s, math.sin(a) * 0.2 * s, 0.7 * s), d, 0.55 * s, 0.26 * s, bend=0.3, mat=POD, segs=4,
                          fold=0.5, double=True))
    # sacs inside / above
    for j in range(sacs):
        a = r_.uniform(0, math.tau)
        rr = r_.uniform(0.02, 0.17) * s
        z = (0.62 + r_.uniform(0.0, 0.28) + 0.2 * (1 - rr / (0.17 * s))) * s
        rad = r_.uniform(0.085, 0.15) * s
        out.append(L.bm_sphere(rad, subdiv=2 if rad > 0.145 * s else 1, matrix=L.xf((math.cos(a) * rr, math.sin(a) * rr, z)), mat_index=SAC))
    # hanging strands with sacs
    for j in range(3):
        a = r_.uniform(0, math.tau)
        p0 = Vector((math.cos(a) * 0.31 * s, math.sin(a) * 0.31 * s, 0.5 * s))
        p1 = p0 + Vector((math.cos(a) * 0.12 * s, math.sin(a) * 0.12 * s, -0.2 * s))
        p2 = p1 + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, -0.18 * s))
        out.append(F.tube([p0, p1, p2], [0.012 * s, 0.01 * s, 0.008 * s], segs=4, mat=STEM, cap_start=False))
        out.append(L.bm_sphere(0.075 * s, subdiv=1, matrix=L.xf(p2), mat_index=SAC))
    bm = F.join(*out)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(pos)) @ L.xf((0, 0, 0), (tilt[0], tilt[1], 0)), verts=bm.verts)
    return bm


def closed_pod(pos, scale, seed, tilt=(0.0, 0.0)):
    s = scale
    prof = [(0.0, 0.0), (0.12 * s, 0.02 * s), (0.25 * s, 0.14 * s), (0.31 * s, 0.34 * s), (0.27 * s, 0.56 * s), (0.15 * s, 0.7 * s), (0.04 * s, 0.76 * s), (0.0, 0.77 * s)]
    pod = F.lathe(prof, segs=10, mat=POD, ring_fn=lambda i, k, a: 1.0 + 0.08 * math.sin(a * 3 + seed))
    out = [pod]
    # glowing slit down the front (+Y) and spore beads
    out.append(L.bm_sphere(0.5, subdiv=1, matrix=L.xf((0, 0.27 * s, 0.38 * s), (0, 0, 0), (0.05 * s, 0.05 * s, 0.34 * s)), mat_index=SAC))
    for j in range(5):
        a = seed + j * 1.25
        out.append(L.bm_sphere(0.07 * s, subdiv=1, matrix=L.xf((math.cos(a) * 0.29 * s, math.sin(a) * 0.29 * s, (0.15 + 0.11 * j) * s), (0,0,0), (1,1,0.8)), mat_index=SAC))
    bm = F.join(*out)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(pos)) @ L.xf((0, 0, 0), (tilt[0], tilt[1], 0)), verts=bm.verts)
    return bm


# --- main stalk + pod ------------------------------------------------------------------------------------------
sp = F.bez((0, 0, -0.05), (0.05, 0.0, 0.4), (-0.08, 0.05, 0.75), (0.05, 0.0, 1.0), 6)
parts.append(F.tube(sp, [0.12, 0.095, 0.08, 0.07, 0.07, 0.075, 0.09], segs=7, mat=STEM, rough=0.06, seed=2, cap_start=True, cap_end=False))
parts.append(open_pod(sp[-1] + Vector((0, 0, -0.06)), 1.0, 1, sacs=11))

# --- secondary stalks -------------------------------------------------------------------------------------------
for i, (a, hgt, lean, sc, kind) in enumerate([(0.9, 0.85, 0.55, 0.62, "closed"), (2.6, 0.7, 0.5, 0.55, "open"), (4.3, 0.95, 0.6, 0.66, "closed"),
                                              (5.5, 0.55, 0.4, 0.5, "closed")]):
    ca, sa = math.cos(a), math.sin(a)
    b0 = Vector((ca * 0.25, sa * 0.25, 0))
    p = F.bez(b0, b0 + Vector((ca * 0.2, sa * 0.2, hgt * 0.5)), b0 + Vector((ca * lean * 0.8, sa * lean * 0.8, hgt * 0.85)),
              b0 + Vector((ca * lean, sa * lean, hgt)), 5)
    parts.append(F.tube(p, [0.075, 0.06, 0.05, 0.05, 0.055, 0.065], segs=6, mat=STEM, rough=0.06, seed=10 + i, cap_start=True, cap_end=False))
    tl = (math.sin(a) * 0.35, -math.cos(a) * 0.35)   # lean outward
    if kind == "open":
        parts.append(open_pod(p[-1] + Vector((0, 0, -0.04)), sc, 20 + i, petals=4, sacs=6, tilt=(tl[0], tl[1])))
    else:
        parts.append(closed_pod(p[-1] + Vector((0, 0, -0.04)), sc, 20 + i, tilt=(tl[0], tl[1])))

# --- ground sacs / nubs between the leaves ----------------------------------------------------------------------------
for i in range(7):
    a = rg.uniform(0, math.tau)
    d = rg.uniform(0.35, 0.75)
    r = rg.uniform(0.05, 0.1)
    parts.append(L.bm_sphere(r, subdiv=1, matrix=L.xf((math.cos(a) * d, math.sin(a) * d, r * 0.8), (0, 0, 0), (1, 1, 0.9)), mat_index=SAC))
parts.append(F.rock_blob(0.35, 2, 0.2, 1.5, 3, (1.0, 1.0, 0.4), flat_bottom=0.1, mat=STEM))

bm = F.join(*parts)
F.transform(bm, scale=(0.8, 0.8, 0.8))
ob = F.finish(ID, bm, col, mats, smooth_deg=50, floor=-0.03)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["toxic", "swamp", "exotic"], {"shape": "cylinder", "radius": 0.45, "height": 1.2, "offset_y": 0.0},
                 tintable=["leaf", "pod", "sac"], notes="Spore pod plant ~1.5 m: leaf rosette, one large open pod with glowing spore sacs (emissive 'sac') and 4 secondary pods (2 closed bud-pods per side). Origin at base centre.")
L.save_blend()
