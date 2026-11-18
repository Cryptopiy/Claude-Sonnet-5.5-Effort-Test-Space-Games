import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix, noise

ID = "fungus_cap_a"
col = L.fresh_collection(ID)
m_cap = L.mat(ID + "_cap", (0.55, 0.13, 0.035), roughness=0.5, specular=0.5)
m_band = L.mat(ID + "_band", (0.78, 0.50, 0.22), roughness=0.55, specular=0.4)
m_glow = L.mat(ID + "_glow", (0.85, 1.0, 0.10), roughness=0.4, emission=(0.8, 1.0, 0.05), emission_strength=2.8)
m_under = L.mat(ID + "_gill", (0.62, 0.36, 0.42), roughness=0.7, specular=0.3)
m_stump = L.mat(ID + "_stump", (0.10, 0.075, 0.065), roughness=0.95, specular=0.2)
m_moss = L.mat(ID + "_moss", (0.12, 0.28, 0.06), roughness=0.9, specular=0.2)
mats = [m_cap, m_band, m_glow, m_under, m_stump, m_moss]
CAP, BAND, GLOW, UNDER, STUMP, MOSS = range(6)
rg = random.Random(52)
parts = []


def shelf(R, seed, thick=0.12):
    """Half-disc bracket, flat edge at x=0 (stump side), growing toward +X. Origin at attachment centre."""
    r_ = random.Random(seed)
    prof = [(0.0, 0.0), (0.4 * R, -0.045 * R), (0.8 * R, -0.075 * R), (0.97 * R, -0.045 * R), (1.0 * R, 0.0),
            (0.96 * R, 0.07 * R), (0.8 * R, 0.1 * R), (0.62 * R, 0.13 * R), (0.45 * R, 0.14 * R), (0.25 * R, 0.16 * R), (0.0, 0.17 * R)]
    # materials per ring segment: underside gill, rim glow, top bands
    mf = lambda i: [UNDER, UNDER, UNDER, GLOW, GLOW, CAP, BAND, CAP, BAND, CAP][i]

    def ring_fn(i, k, a):
        w = 1.0 + 0.05 * math.sin(a * 11 + seed) + 0.04 * noise.noise(Vector((math.cos(a) * 2 + seed, math.sin(a) * 2, i * 0.3)))
        return w

    def z_fn(i, k, a):
        base = 0.012 * R * math.sin(i * 2.2 + a * 6)
        return base * (1 if i >= 5 else 0.4)

    bm = F.lathe(prof, segs=16, mat_fn=mf, ring_fn=ring_fn, z_fn=z_fn, seed=seed)
    # keep only the half with x >= -0.05R (flat side against the stump), push the cut edge slightly into the trunk
    cut = [f for f in bm.faces if f.calc_center_median().x < -0.05 * R]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    # stretch slightly outward (half-moon look)
    bmesh.ops.scale(bm, vec=Vector((1.15, 0.92, 1.0)), verts=bm.verts)
    return bm


# --- stump / log base ----------------------------------------------------------------------------------------------
sp = F.bez((0, 0, -0.1), (0.1, 0.0, 0.5), (-0.1, 0.05, 1.0), (0.05, 0.0, 1.5), 7)
radii = [0.62, 0.56, 0.5, 0.47, 0.45, 0.44, 0.40, 0.30]
stump = F.tube(sp, radii, segs=11, mat=STUMP, rough=0.1, seed=3, ring_fn=lambda i, k, a: 1.0 + 0.07 * math.sin(a * 5 + i * 0.8), cap_start=False, cap_end=True)
parts.append(stump)
# mossy collar + roots
parts.append(F.rock_blob(0.85, 3, 0.25, 1.2, 4, (1.0, 1.0, 0.28), flat_bottom=0.1, mat=MOSS))
for i in range(5):
    a = i * math.tau / 5 + 0.4
    ca, sa = math.cos(a), math.sin(a)
    pts = F.bez((ca * 0.35, sa * 0.35, 0.55), (ca * 0.6, sa * 0.6, 0.35), (ca * 0.9, sa * 0.9, 0.15), (ca * 1.25, sa * 1.25, 0.0), 5)
    parts.append(F.tube(pts, [0.17, 0.14, 0.11, 0.08, 0.05, 0.03], segs=5, mat=STUMP, rough=0.15, seed=i, cap_start=False))

# --- shelf brackets spiralling up the stump --------------------------------------------------------------------------
cfg = [(0.3, 0.25, 0.75, 0.0), (1.4, 0.45, 0.62, 0.1), (2.5, 0.65, 0.82, -0.05), (3.6, 0.85, 0.7, 0.12), (4.6, 1.05, 0.58, 0.0), (5.6, 1.2, 0.5, -0.1),
       (0.9, 1.35, 0.4, 0.1), (3.1, 1.4, 0.36, 0.0)]
for i, (a, z, R, tilt) in enumerate(cfg):
    sh = shelf(R, 10 + i)
    # place at the stump surface at height z
    t = max(0.0, min(1.0, (z + 0.1) / 1.6))
    c = F.bez((0, 0, -0.1), (0.1, 0.0, 0.5), (-0.1, 0.05, 1.0), (0.05, 0.0, 1.5), 7)[min(7, int(t * 7 + 0.5))]
    rad = radii[min(7, int(t * 7 + 0.5))] * 0.9
    m = Matrix.Translation(Vector((c.x + math.cos(a) * rad, c.y + math.sin(a) * rad, z))) @ L.xf((0, 0, 0), (tilt, -0.12, a))
    bmesh.ops.transform(sh, matrix=m, verts=sh.verts)
    parts.append(sh)

# --- small ground brackets and glowing spore bumps -----------------------------------------------------------------
for i in range(4):
    a = rg.uniform(0, math.tau)
    d = rg.uniform(0.9, 1.5)
    sh = shelf(rg.uniform(0.22, 0.34), 50 + i)
    m = Matrix.Translation(Vector((math.cos(a) * d, math.sin(a) * d, 0.05))) @ L.xf((0, 0, 0), (rg.uniform(-0.15, 0.15), -0.08, a + 3.14))
    bmesh.ops.transform(sh, matrix=m, verts=sh.verts)
    parts.append(sh)
for i in range(9):
    a = rg.uniform(0, math.tau)
    d = rg.uniform(0.7, 1.3)
    r = rg.uniform(0.04, 0.08)
    parts.append(L.bm_sphere(r, subdiv=1, matrix=L.xf((math.cos(a) * d, math.sin(a) * d, r * 0.7), (0, 0, 0), (1, 1, 0.8)), mat_index=GLOW))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=50, floor=-0.05)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "flora", ["toxic", "swamp"], {"shape": "cylinder", "radius": 0.55, "height": 1.5, "offset_y": 0.0},
                 tintable=["cap", "glow"], notes="Shelf (bracket) fungus on a mossy stump ~1.6 m: 8 stacked half-disc brackets with banded tops, pale gills underneath and an emissive rim ('glow'). Origin at stump base.")
L.save_blend()
