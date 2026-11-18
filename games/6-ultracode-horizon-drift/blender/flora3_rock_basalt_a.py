import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix, noise

ID = "rock_basalt_a"
col = L.fresh_collection(ID)
m_rock = L.mat(ID + "_rock", (0.060, 0.066, 0.085), roughness=0.82, specular=0.4)
m_top = L.mat(ID + "_top", (0.15, 0.155, 0.165), roughness=0.9, specular=0.3)
m_glow = L.mat(ID + "_glow", (1.0, 0.2, 0.02), roughness=0.5, emission=(1.0, 0.11, 0.008), emission_strength=3.2)
mats = [m_rock, m_top, m_glow]
ROCK, TOP, GLOW = 0, 1, 2
rg = random.Random(91)


def column(cx, cy, R, h, seed, tilt=(0.0, 0.0), sides=6, bottom=-0.4):
    r_ = random.Random(seed)
    bm = bmesh.new()
    a0 = math.pi / 6
    jit = [1.0 + r_.uniform(-0.04, 0.04) for _ in range(sides)]
    rings = []
    # rings: bottom, mid (slight bulge), shoulder, top (chamfered)
    spec = [(bottom, 1.0), (h * 0.5, 1.0), (h - 0.1, 1.0), (h, 0.86)]
    for (z, rs) in spec:
        ring = []
        for k in range(sides):
            a = a0 + math.tau * k / sides
            x = cx + math.cos(a) * R * rs * jit[k]
            y = cy + math.sin(a) * R * rs * jit[k]
            zz = z
            if z == h or z == h - 0.1:
                zz = z + tilt[0] * (x - cx) + tilt[1] * (y - cy) + r_.uniform(-0.04, 0.04)
            ring.append(bm.verts.new((x, y, zz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new([A[k], A[k2], B[k2], B[k]])
            f.material_index = TOP if i == 2 else ROCK
    f = bm.faces.new(rings[-1])
    f.material_index = TOP
    return bm


# hex-grid cluster
cols = []
S = 0.62
cells = []
for q in range(-2, 3):
    for r in range(-2, 3):
        if abs(q + r) <= 2:
            cells.append((q, r))
maxd = 2.0
for i, (q, r) in enumerate(cells):
    x = S * math.sqrt(3) * (q + r / 2.0)
    y = S * 1.5 * r
    d = math.hypot(x, y)
    dn = d / (S * 3.2)
    h = 0.7 + 2.9 * max(0.0, 1 - dn) ** 1.1 + rg.uniform(-0.35, 0.8)
    if rg.random() < 0.18:
        h = rg.uniform(0.35, 0.8)
    tilt = (rg.uniform(-0.12, 0.12), rg.uniform(-0.12, 0.12))
    cols.append(column(x, y, S * 0.925, h, 100 + i, tilt, bottom=-0.3))
# fallen broken pieces
for i in range(5):
    a = rg.uniform(0, math.tau)
    d = rg.uniform(2.2, 3.0)
    piece = column(0, 0, S * 0.8, rg.uniform(0.4, 0.8), 300 + i, (0.1, 0.1), bottom=0.0)
    bmesh.ops.transform(piece, matrix=Matrix.Translation(Vector((math.cos(a) * d, math.sin(a) * d, 0.25))) @ L.xf((0, 0, 0), (rg.uniform(1.0, 1.6), rg.uniform(-0.4, 0.4), rg.uniform(0, 3))), verts=piece.verts)
    cols.append(piece)

# glowing magma bed in the gaps / rim at the base
bed = F.lathe([(0.0, 0.02), (1.95, 0.02), (2.15, 0.0)], segs=24, mat=GLOW, ring_fn=lambda i, k, a: 1.0 + 0.1 * noise.noise(Vector((math.cos(a) * 2 + 3, math.sin(a) * 2, 0.0))))
# lathe faces point up (profile goes outward along the top? ensure up)
bmesh.ops.recalc_face_normals(bed, faces=bed.faces)
for f in bed.faces:
    if f.normal.z < 0:
        bmesh.ops.reverse_faces(bed, faces=[f])
rub = []
for i in range(7):
    a = rg.uniform(0, math.tau)
    d = rg.uniform(2.3, 3.2)
    rub.append(F.rock_blob(rg.uniform(0.14, 0.3), 2, 0.4, 1.5, 120 + i, (1, 1, 0.8), flat_bottom=0.2, mat=ROCK, center=(math.cos(a) * d, math.sin(a) * d, 0)))

bm = F.join(*cols, bed, *rub)
ob = F.finish(ID, bm, col, mats, flat=True)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "rock", ["volcanic"], {"shape": "cylinder", "radius": 2.6, "height": 3.0, "offset_y": 0.0},
                 tintable=[], notes="Columnar basalt formation (19 hex columns, tallest ~3.4 m above ground) on a thin glowing magma bed (emissive 'glow' at z~0.04, optional). Origin at formation centre on the ground; columns sunk 0.3 m below the ground plane.")
L.save_blend()
