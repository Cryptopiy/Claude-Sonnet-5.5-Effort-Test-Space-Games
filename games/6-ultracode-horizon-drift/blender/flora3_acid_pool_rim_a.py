import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix, noise

ID = "acid_pool_rim_a"
col = L.fresh_collection(ID)
m_rock = L.mat(ID + "_rock", (0.12, 0.10, 0.07), roughness=0.92, specular=0.25)
m_crust = L.mat(ID + "_crust", (0.46, 0.36, 0.04), roughness=0.8, specular=0.3)
m_acid = L.mat(ID + "_acid", (0.06, 0.45, 0.02), roughness=0.15, emission=(0.14, 1.0, 0.02), emission_strength=2.0, specular=0.8)
m_stain = L.mat(ID + "_stain", (0.17, 0.30, 0.04), roughness=0.85, specular=0.25)
mats = [m_rock, m_crust, m_acid, m_stain]
ROCK, CRUST, ACID, STAIN = range(4)
rg = random.Random(63)
parts = []

RING_R = 3.15
# --- low continuous berm ---------------------------------------------------------------------------------------------
N = 30
pts = []
for i in range(N + 1):
    a = math.tau * i / N
    r = RING_R + 0.18 * noise.noise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 2.0)))
    pts.append(Vector((math.cos(a) * r, math.sin(a) * r, 0.12 + 0.1 * math.sin(a * 3))))
# close the loop by dropping the duplicated last point (tube is open; we overlap the ends)
berm = F.tube(pts, [0.55 + 0.12 * math.sin(i * 0.9) for i in range(N + 1)], segs=7, mat=ROCK, rough=0.14, seed=2, cap_start=False, cap_end=False,
              aspect=0.75)
parts.append(berm)

# --- rock ring -----------------------------------------------------------------------------------------------------------
rocks = []
NR = 26
for i in range(NR):
    a = math.tau * i / NR + rg.uniform(-0.07, 0.07)
    r = RING_R + rg.uniform(-0.3, 0.35)
    R = rg.uniform(0.42, 0.78)
    hz = rg.uniform(0.9, 1.9) if (i % 3 == 0) else rg.uniform(0.6, 1.15)
    rk = F.rock_blob(R, 2, 0.42, 1.4, 200 + i, (rg.uniform(0.9, 1.3), rg.uniform(0.8, 1.1), hz), flat_bottom=0.15, ridged=0.7, mat=ROCK,
                     center=(math.cos(a) * r, math.sin(a) * r, -0.15))
    rocks.append(rk)
rim = F.join(*rocks)
# stain the inner low faces, crust the upper inner faces
for f in rim.faces:
    c = f.calc_center_median()
    rr = math.hypot(c.x, c.y)
    inward = -(f.normal.x * c.x + f.normal.y * c.y) / max(rr, 0.01)
    if inward > 0.25 and rr < RING_R + 0.2:
        if c.z < 0.55:
            f.material_index = STAIN
        elif rg.random() < 0.55:
            f.material_index = CRUST
parts.append(rim)

# sulphur lumps on the rim
for i in range(14):
    a = rg.uniform(0, math.tau)
    r = RING_R - rg.uniform(0.35, 0.8)
    parts.append(F.rock_blob(rg.uniform(0.1, 0.26), 2, 0.35, 1.6, 400 + i, (1, 1, 0.6), flat_bottom=0.0, mat=CRUST,
                             center=(math.cos(a) * r, math.sin(a) * r, 0.22 + rg.uniform(0, 0.25))))

# --- acid surface -------------------------------------------------------------------------------------------------------
def wave(i, k, a):
    return 0.03 * math.sin(a * 5 + i * 1.7) + 0.02 * math.sin(a * 11 - i)
pool = F.lathe([(0.0, 0.2), (0.8, 0.2), (1.6, 0.19), (2.3, 0.18), (2.85, 0.2), (3.0, 0.14)], segs=32, mat=ACID, z_fn=wave,
               ring_fn=lambda i, k, a: 1.0 + 0.03 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, i))))
bmesh.ops.recalc_face_normals(pool, faces=pool.faces)
for f in list(pool.faces):
    if f.normal.z < 0:
        bmesh.ops.reverse_faces(pool, faces=[f])
parts.append(pool)
# bubbles
for i in range(8):
    a = rg.uniform(0, math.tau)
    d = rg.uniform(0.2, 2.2)
    r = rg.uniform(0.1, 0.24)
    parts.append(L.bm_sphere(r, subdiv=2, matrix=L.xf((math.cos(a) * d, math.sin(a) * d, 0.2 + r * 0.1), (0, 0, 0), (1, 1, 0.55)), mat_index=ACID))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, smooth_deg=55, floor=-0.2)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "rock", ["toxic"], {"shape": "none", "offset_y": 0.0},
                 tintable=["acid"], notes="Rock ring (~8 m diameter, outer radius ~4 m, 26 rocks + berm) around a glowing acid pool (emissive 'acid' surface at y~0.2, recessed inside the ring). Origin at pool centre on the ground. Collider: none (ring rocks are decorative); add a trigger Area (radius 2.6) for acid damage.")
L.save_blend()
