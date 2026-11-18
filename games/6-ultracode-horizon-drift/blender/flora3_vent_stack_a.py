import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, noise

ID = "vent_stack_a"
col = L.fresh_collection(ID)
m_rock = L.mat(ID + "_rock", (0.085, 0.058, 0.045), roughness=0.95, specular=0.25)
m_crust = L.mat(ID + "_crust", (0.34, 0.24, 0.03), roughness=0.85, specular=0.3)
m_glow = L.mat(ID + "_glow", (1.0, 0.22, 0.02), roughness=0.4, emission=(1.0, 0.11, 0.008), emission_strength=3.5)
m_hot = L.mat(ID + "_hot", (1.0, 0.65, 0.12), roughness=0.4, emission=(1.0, 0.30, 0.03), emission_strength=4.5)
mats = [m_rock, m_crust, m_glow, m_hot]
rng = random.Random(21)

# ---- chimney (lathe: outside bottom->top, over the rim, inside down to the glowing floor) -------------
prof = [(2.1, -0.1), (1.85, 0.5), (1.5, 1.1), (1.22, 1.8), (1.05, 2.6), (0.97, 3.4), (1.0, 4.05), (1.2, 4.6), (1.32, 4.88),
        (1.18, 5.04), (0.92, 5.0), (0.8, 4.66), (0.7, 4.25), (0.6, 4.02), (0.0, 4.08)]
MAT_SEG = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 2, 2, 3]
SEGS = 22


def ring_fn(i, k, a):
    z = prof[i][1]
    n = noise.noise(Vector((math.cos(a) * 1.3 + 4.0, math.sin(a) * 1.3, z * 0.55)))
    wob = 1.0 + 0.22 * n * (1.0 if z < 4.5 else 0.5)
    stri = 1.0 + 0.045 * math.sin(a * 9 + z * 0.7) * (1.0 if z < 4.5 else 0.3)
    return wob * stri


chim = F.lathe(prof, segs=SEGS, mat_fn=lambda i: MAT_SEG[i], ring_fn=ring_fn, rough=0.03, seed=3)
# jagged rim + bubbling floor
for v in chim.verts:
    r = math.hypot(v.co.x, v.co.y)
    if 4.8 < v.co.z < 5.1:
        a = math.atan2(v.co.y, v.co.x)
        v.co.z += 0.22 * noise.noise(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, 1.7))) + 0.12 * math.sin(a * 5)
    if 3.95 < v.co.z < 4.12 and r < 0.62:
        v.co.z += 0.10 * noise.noise(Vector((v.co.x * 3, v.co.y * 3, 0.0)))

# ---- rubble skirt with glowing cracks --------------------------------------------------------------
skirt = F.rock_blob(3.3, 4, 0.22, 0.8, 8, (1.0, 1.0, 0.16), flat_bottom=0.2, ridged=0.5)
cen = Vector((0, 0, 0.1))
F.cell_plates(skirt, 8, seed=9, shrink=0.93, depth=0.45, centre=cen, mat_top=0, mat_wall=2, bulge=0.03, bulge_rand=0.03)
# hole under the chimney is hidden by the chimney itself (chimney base is wider than skirt crown)

# ---- buttress fins -----------------------------------------------------------------------------------
fins = []
for i, (a, hgt) in enumerate([(0.3, 3.4), (1.5, 2.6), (2.5, 3.8), (3.7, 2.9), (4.7, 3.3), (5.6, 2.3)]):
    ca, sa = math.cos(a), math.sin(a)
    p0 = Vector((ca * 2.5, sa * 2.5, 0.55))
    p1 = Vector((ca * 1.7, sa * 1.7, hgt * 0.35))
    p2 = Vector((ca * 1.25, sa * 1.25, hgt * 0.75))
    p3 = Vector((ca * 0.98, sa * 0.98, hgt))
    pts = F.bez(p0, p1, p2, p3, 5)
    rad = [0.55 - 0.45 * (j / 5) for j in range(6)]
    rad[-1] = 0.0
    fins.append(F.tube(pts, rad, segs=6, mat=0, rough=0.25, seed=60 + i, aspect=0.7, cap_start=True))

# ---- sulphur lumps on the rim -----------------------------------------------------------------------
lumps = []
for i in range(11):
    a = rng.uniform(0, math.tau)
    rr = rng.uniform(1.0, 1.28)
    z = 4.85 + rng.uniform(-0.05, 0.1) + 0.12 * math.sin(a * 5)
    lumps.append(F.rock_blob(rng.uniform(0.13, 0.28), 2, 0.3, 2.0, 70 + i, (1, 1, 0.8), flat_bottom=0.0, mat=1,
                             center=(math.cos(a) * rr, math.sin(a) * rr, z)))
# sulphur streaks running down the outside from the rim
bv = F.bvh_of(chim)
streaks = []
verts = [v.co.copy() for v in chim.verts]
for i in range(7):
    cand = [v for v in verts if 4.0 < v.z < 4.9 and math.hypot(v.x, v.y) > 0.95]
    s = rng.choice(cand)
    pn = F.surface_walk(bv, s, rng.randint(4, 7), 0.22, rng, 0.25, bias=(0, 0, -1), bias_k=0.9)
    r_ = F.ribbon(pn, 0.10, 0.01, 4, mat=1)
    if r_:
        streaks.append(r_)
# lava drips (glowing) hugging the outside
drips = []
for i in range(4):
    cand = [v for v in verts if 4.2 < v.z < 4.9 and math.hypot(v.x, v.y) > 1.05]
    s = rng.choice(cand)
    pn = F.surface_walk(bv, s, rng.randint(4, 6), 0.2, rng, 0.2, bias=(0, 0, -1), bias_k=1.0)
    r_ = F.ribbon(pn, 0.075, 0.015, 4, mat=2)
    if r_:
        drips.append(r_)

# ---- small secondary fumarole ------------------------------------------------------------------------
sp = F.lathe([(0.75, 0.0), (0.55, 0.5), (0.42, 0.95), (0.5, 1.15), (0.36, 1.15), (0.3, 0.95), (0.0, 0.98)], segs=12,
             mat_fn=lambda i: [0, 0, 1, 1, 0, 2][i], ring_fn=lambda i, k, a: 1 + 0.15 * noise.noise(Vector((math.cos(a), math.sin(a), i * 0.7 + 7))),
             center=(2.55, 1.2, 0.0))
sp_cr = F.rock_blob(0.7, 3, 0.2, 1.4, 17, (1, 1, 0.3), flat_bottom=0.1, center=(2.55, 1.2, 0.0))

# molten overflow dome in the mouth so the glow is visible from the side
domes = [F.rock_blob(0.62, 3, 0.25, 1.5, 33, (1.0, 1.0, 0.62), flat_bottom=0.0, mat=3, center=(0.0, 0.0, 4.82)),
         F.rock_blob(0.3, 2, 0.3, 1.5, 34, (1.0, 1.0, 0.7), flat_bottom=0.0, mat=2, center=(0.45, -0.25, 5.0))]
for nm, parts in (("chim", [chim]), ("skirt", [skirt]), ("fins", fins), ("lumps", lumps), ("streaks", streaks), ("drips", drips), ("sp", [sp]), ("sp_cr", [sp_cr])):
    print(nm, round(min(v.co.z for b in parts for v in b.verts), 3))
bm = F.join(chim, skirt, *fins, *lumps, *streaks, *drips, sp, sp_cr, *domes)
ob = F.finish(ID, bm, col, mats, smooth_deg=48, floor=-0.05)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "rock", ["volcanic"], {"shape": "cylinder", "radius": 1.7, "height": 4.5, "offset_y": 0.0},
                 tintable=["glow", "hot"], notes="Chimney vent stack ~5 m with glowing magma mouth (emissive 'glow'/'hot'), sulphur crust rim, rubble skirt. Origin at ground centre of the stack; a small side fumarole sits at +X/+Y. Smoke/steam particles should be emitted at (0, 5.0, 0) Godot.")
L.save_blend()
