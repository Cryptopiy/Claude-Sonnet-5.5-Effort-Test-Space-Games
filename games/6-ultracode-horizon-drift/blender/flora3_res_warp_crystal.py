import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora3_lib as F; importlib.reload(F)
import bmesh
from mathutils import Vector, Matrix

ID = "res_warp_crystal"
col = L.fresh_collection(ID)
m_body = L.mat(ID + "_body", (0.42, 0.05, 0.9), roughness=0.12, emission=(0.48, 0.03, 1.0), emission_strength=3.0, specular=0.9)
m_facet = L.mat(ID + "_facet", (0.95, 0.06, 0.65), roughness=0.1, emission=(1.0, 0.04, 0.70), emission_strength=3.6, specular=0.9)
m_core = L.mat(ID + "_core", (1.0, 0.65, 1.0), roughness=0.1, emission=(1.0, 0.55, 1.0), emission_strength=4.6)
m_stone = L.mat(ID + "_stone", (0.07, 0.04, 0.11), roughness=0.85, specular=0.35)
m_ring = L.mat(ID + "_ring", (0.18, 0.08, 0.30), metallic=0.5, roughness=0.3, emission=(0.50, 0.06, 1.0), emission_strength=2.0, specular=0.8)
mats = [m_body, m_facet, m_core, m_stone, m_ring]
BODY, FACET, CORE, STONE, RING = range(5)
rg = random.Random(66)
parts = []


def gem(center, height, R, sides=6, twist=0.28, seed=0, tilt=(0, 0, 0), mat_lo=BODY, mat_hi=FACET):
    prof = [(0.0, -0.5 * height), (0.38 * R, -0.3 * height), (0.88 * R, -0.12 * height), (R, 0.0), (0.9 * R, 0.12 * height),
            (0.5 * R, 0.3 * height), (0.0, 0.5 * height)]
    mf = lambda i: (CORE if i in (0, 5) else (mat_lo if i < 3 else mat_hi))
    b = F.lathe(prof, segs=sides, mat_fn=mf, twist=twist, rough=0.04, seed=seed)
    bmesh.ops.transform(b, matrix=Matrix.Translation(Vector(center)) @ L.xf((0, 0, 0), tilt), verts=b.verts)
    return b


# hovering central voidstone
parts.append(gem((0, 0, 0.72), 0.96, 0.26, sides=6, twist=0.3, seed=1))
# orbiting broken ring
ring = F.lathe([(0.5, -0.018), (0.58, -0.018), (0.58, 0.018), (0.5, 0.018), (0.5, -0.018)], segs=30, mat=RING)
bmesh.ops.recalc_face_normals(ring, faces=ring.faces)
gaps = [(0.25, 0.85), (2.3, 2.9), (4.2, 4.75)]
dele = []
for f in ring.faces:
    c = f.calc_center_median()
    ang = math.atan2(c.y, c.x) % math.tau
    if any(a0 < ang < a1 for a0, a1 in gaps):
        dele.append(f)
bmesh.ops.delete(ring, geom=dele, context="FACES")
bmesh.ops.transform(ring, matrix=Matrix.Translation(Vector((0, 0, 0.74))) @ L.xf((0, 0, 0), (0.33, 0.12, 0.4)), verts=ring.verts)
parts.append(ring)
# orbiting shards
for i in range(7):
    a = i * math.tau / 7 + rg.uniform(-0.3, 0.3)
    rr = rg.uniform(0.52, 0.72)
    z = rg.uniform(0.3, 1.1)
    parts.append(gem((math.cos(a) * rr, math.sin(a) * rr, z), rg.uniform(0.14, 0.26), rg.uniform(0.04, 0.07), sides=4, twist=0.2, seed=10 + i,
                     tilt=(rg.uniform(-0.6, 0.6), rg.uniform(-0.6, 0.6), rg.uniform(0, 3))))

# cracked stone plate with violet energy seams
plate = F.rock_blob(0.62, 4, 0.18, 1.0, 9, (1.0, 1.0, 0.14), flat_bottom=0.15, ridged=0.4, mat=STONE)
F.cell_plates(plate, 7, seed=8, shrink=0.9, depth=0.35, centre=Vector((0, 0, 0.0)), mat_top=STONE, mat_wall=FACET, bulge=0.015, bulge_rand=0.01)
parts.append(plate)
for i, (a, d, r) in enumerate([(0.4, 0.62, 0.12), (2.3, 0.6, 0.1), (3.7, 0.66, 0.14), (5.2, 0.58, 0.09)]):
    parts.append(F.rock_blob(r, 2, 0.35, 1.5, 80 + i, (1, 1, 0.8), flat_bottom=0.2, mat=STONE, center=(math.cos(a) * d, math.sin(a) * d, 0)))

bm = F.join(*parts)
ob = F.finish(ID, bm, col, mats, flat=True)
F.run_standard(ID, ob)
print(L.export_glb([ob], ID + ".glb"))
F.write_manifest([ob], ID, "resource", ["any"], {"shape": "sphere", "radius": 0.6, "offset_y": 0.2},
                 tintable=[], notes="Resource 'Voidstone' (warp): twisted magenta-violet gem hovering at y~0.7 over a cracked stone plate with violet seams, broken orbiting ring + 7 shards (all static; Godot may bob/spin the node about Y). Emissive 2.0-4.6. Origin at ground centre.")
L.save_blend()
