import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "ruin_arch_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
TAU = math.tau
rnd = random.Random(1313)


def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)


M = S.mats(ID, {
    "stone": dict(color=(0.24, 0.205, 0.16), metallic=0.0, roughness=0.92),
    "stone2": dict(color=(0.115, 0.105, 0.095), metallic=0.0, roughness=0.95),
    "rune": dict(color=(0.04, 0.35, 0.33), emission=(0.1, 1.0, 0.82), emission_strength=3.5, roughness=0.3),
    "moss": dict(color=(0.075, 0.17, 0.05), metallic=0.0, roughness=1.0),
})
RXp = Matrix.Rotation(math.pi / 2, 3, "X")          # local (x, y, z) -> world (x, -z, y): polygon in XZ, extrusion along Y
RXs = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))     # polygon (y,z), extrusion along X

ZC = 5.7
R_IN, R_OUT, THICK = 3.9, 5.5, 1.6
NB = 16
START = 11.25
MISSING = {2, 10}
b = S.MB(M)


def block(th0, th1, r_in, r_out, thick, seed, mat):
    mb = S.MB(M)
    steps = 4
    outer = [(r_out * math.cos(th0 + (th1 - th0) * i / steps), r_out * math.sin(th0 + (th1 - th0) * i / steps)) for i in range(steps + 1)]
    inner = [(r_in * math.cos(th0 + (th1 - th0) * i / steps), r_in * math.sin(th0 + (th1 - th0) * i / steps)) for i in range(steps, -1, -1)]
    mb.prism(outer + inner, -thick / 2, thick / 2, mat=mat, rot=RXp, bevel=0.08)
    L.noise_displace(mb.bm, 0.07, 1.1, seed=seed)
    return mb


# ---- plaza + dais + steps ------------------------------------------------------------------------------------------------------
b.lathe([(0, -0.5), (8.7, -0.5), (8.7, -0.05), (8.2, 0.14), (0, 0.14)], segs=44, mat="stone2")
for rr, w in ((6.3, 0.16), (4.5, 0.12)):
    b.lathe([(rr, 0.12), (rr + w, 0.12), (rr + w, 0.24), (rr, 0.24), (rr, 0.12)], segs=60, mat="stone")
for k in range(40):
    a = TAU * k / 40 + 0.04
    ln = rnd.choice([0.18, 0.3, 0.46, 0.22])
    b.box((7.4 * math.cos(a), 7.4 * math.sin(a), 0.145), (ln, 0.08, 0.02), rot=(0, 0, a + math.pi / 2), mat="rune")
# cracks (dark gashes)
for k in range(7):
    a = rnd.uniform(0, TAU)
    r0 = rnd.uniform(2.5, 7.5)
    b.box((r0 * math.cos(a), r0 * math.sin(a), 0.15), (rnd.uniform(0.8, 1.8), 0.05, 0.03), rot=(0, 0, a + rnd.uniform(-0.5, 0.5)), mat="stone2") if False else None
# dais
DZ = 1.8
b.box((0, -0.4, DZ / 2 + 0.0), (10.6, 3.6 + 0.8, DZ), mat="stone", bevel=0.1)
b.box((0, -0.4, DZ + 0.03), (10.2, 4.2, 0.08), mat="stone2", bevel=0.03)
b.box((0, 0.0, DZ / 2 - 0.55), (11.2, 5.2, 0.7), mat="stone2", bevel=0.1)
# steps down to the plaza (front +Y)
nst = 6
for i in range(nst):
    top = 0.3 * (i + 1)
    y0 = 1.9 + 0.5 * (nst - 1 - i) + 0.25
    b.box((0, y0 + 0.5, top / 2 + 0.05), (6.2, 0.5, top + 0.1), mat="stone" if i % 2 == 0 else "stone2", bevel=0.04)
for sx in (-1, 1):
    b.prism([(4.5, -0.3), (4.5, 0.5), (1.6, 2.3), (1.6, -0.3)], sx * 3.25 - 0.28, sx * 3.25 + 0.28, mat="stone2", rot=RXs, bevel=0.06)
# dais floor glyph ring + centre
for k in range(24):
    a = TAU * k / 24
    ln = rnd.choice([0.2, 0.34, 0.2, 0.5])
    b.box((2.3 * math.cos(a), -0.4 + 2.3 * math.sin(a) * 0.55, DZ + 0.08), (ln, 0.07, 0.02), rot=(0, 0, a + math.pi / 2), mat="rune")
b.lathe([(0, 0), (0.55, 0), (0.55, 0.03), (0, 0.03)], segs=16, c=(0, -0.2, DZ + 0.075), mat="rune")
b.lathe([(0.78, 0), (0.86, 0), (0.86, 0.03), (0.78, 0.03), (0.78, 0)], segs=24, c=(0, -0.2, DZ + 0.075), mat="rune")

# ---- the ring --------------------------------------------------------------------------------------------------------------------
step_a = TAU / NB
for k in range(NB):
    th0 = START * D2R + k * step_a + 0.012
    th1 = START * D2R + (k + 1) * step_a - 0.012
    thc = (th0 + th1) / 2
    if k in MISSING:
        continue
    rin, rout, thick = R_IN + rnd.uniform(-0.06, 0.05), R_OUT + rnd.uniform(-0.08, 0.08), THICK + rnd.uniform(-0.12, 0.06)
    if k == 3:
        rout += 0.5
        rin -= 0.1
        thick += 0.2
    bk = block(th0, th1, rin, rout, thick, k * 3 + 1, "stone" if k % 3 else "stone2")
    b.append(bk, Matrix.Translation(V((0, 0, ZC))))
    # inner glow band
    b.append((lambda mb_: (mb_.prism([(((rin + 0.01) * math.cos(th0 + (th1 - th0) * i / 4)), ((rin + 0.01) * math.sin(th0 + (th1 - th0) * i / 4))) for i in range(5)] +
                                    [(((rin - 0.03) * math.cos(th0 + (th1 - th0) * i / 4)), ((rin - 0.03) * math.sin(th0 + (th1 - th0) * i / 4))) for i in range(4, -1, -1)],
                                    -0.1, 0.1, mat="rune", rot=RXp), mb_)[1])(S.MB(M)), Matrix.Translation(V((0, 0, ZC))))
    # carved glyph bars on the front (+Y) face
    face_y = thick / 2 + 0.012
    for g in range(rnd.randint(2, 3)):
        rr = rnd.uniform(R_IN + 0.35, R_OUT - 0.3)
        aa = thc + rnd.uniform(-0.07, 0.07)
        ln = rnd.choice([0.25, 0.4, 0.55])
        radial = rnd.random() < 0.5
        b.box((rr * math.cos(aa), face_y, ZC + rr * math.sin(aa)), (ln, 0.02, 0.06), rot=(0, -(aa if radial else aa + math.pi / 2), 0), mat="rune")
    if k % 2 == 0:
        rr = (R_IN + R_OUT) / 2
        b.box((rr * math.cos(thc), face_y, ZC + rr * math.sin(thc)), (0.22, 0.02, 0.22), rot=(0, math.pi / 4, 0), mat="rune")
    # back face (-Y)
    if k % 3 == 0:
        rr = rnd.uniform(R_IN + 0.5, R_OUT - 0.4)
        b.box((rr * math.cos(thc), -face_y, ZC + rr * math.sin(thc)), (0.4, 0.02, 0.06), rot=(0, -thc, 0), mat="rune")
# keystone diamond
kz = ZC + 4.85
b.box((0, THICK / 2 + 0.2 + 0.03, kz), (0.62, 0.02, 0.62), rot=(0, math.pi / 4, 0), mat="rune")
b.box((0, THICK / 2 + 0.2 + 0.045, kz), (0.42, 0.02, 0.42), rot=(0, math.pi / 4, 0), mat="stone2")
b.box((0, THICK / 2 + 0.2 + 0.06, kz), (0.14, 0.02, 0.14), rot=(0, math.pi / 4, 0), mat="rune")
# mortar-less bevel details: small wedge stones under the open gaps
# ---- moss + vines ---------------------------------------------------------------------------------------------------------------
for k in range(14):
    thx = rnd.uniform(15, 165) * D2R
    r = R_OUT + rnd.uniform(-0.1, 0.05)
    sz = rnd.uniform(0.3, 0.65)
    ms = S.MB(M)
    ms.sphere((0, 0, 0), sz, scale=(1.0, rnd.uniform(0.9, 1.4), 0.38), u=8, v=5, mat="moss")
    L.noise_displace(ms.bm, sz * 0.25, 2.0, seed=k + 40)
    ms.transform(S.M4((r * math.cos(thx), rnd.uniform(-0.55, 0.55), ZC + r * math.sin(thx)), (0, -thx + math.pi / 2, 0)))
    b.append(ms)
for k in range(9):
    thx = rnd.uniform(95, 175) * D2R
    y = rnd.uniform(-0.6, 0.6)
    p0 = V((R_IN * math.cos(thx), y, ZC + R_IN * math.sin(thx)))
    ln = rnd.uniform(0.9, 2.3)
    b.pipe([p0, p0 + V((rnd.uniform(-0.15, 0.15), 0.05, -ln * 0.5)), p0 + V((rnd.uniform(-0.3, 0.3), 0.1, -ln))], 0.03, segs=5, mat="moss", bend=0.4)
    for lf in range(3):
        q = p0 + V((0, 0.02, -ln * (0.35 + 0.2 * lf)))
        b.box(q + V((0.06, 0, 0)), (0.16, 0.02, 0.09), rot=(0, 0, rnd.uniform(-0.5, 0.5)), mat="moss")

# ---- columns, fallen blocks, rubble ----------------------------------------------------------------------------------------------
cx, cy = -4.8, 3.6
b.lathe([(0, 0.0), (0.82, 0.0), (0.82, 0.32), (0.62, 0.42), (0.52, 0.55), (0.5, 3.1), (0.6, 3.2), (0.68, 3.5), (0.62, 3.62), (0, 3.62)], segs=12, c=V((cx, cy, 0.1)), mat="stone")
for z in (1.0, 2.0):
    b.lathe([(0.5, 0), (0.56, 0), (0.56, 0.08), (0.5, 0.08), (0.5, 0)], segs=12, c=V((cx, cy, z)), mat="stone2")
b.lathe([(0, 0.0), (0.82, 0.0), (0.82, 0.32), (0.62, 0.42), (0.52, 0.55), (0.5, 1.6), (0, 1.6)], segs=12, c=V((4.8, 3.6, 0.1)), mat="stone")
for k in range(7):
    a = TAU * k / 7
    b.box((4.8 + 0.42 * math.cos(a), 3.6 + 0.42 * math.sin(a), 1.8), (0.16, 0.14, rnd.uniform(0.25, 0.55)), rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), a), mat="stone")
# fallen column drums
for (x, y, a) in ((3.0, 6.4, 0.5), (3.9, 7.0, 0.9), (2.4, 7.2, 1.7)):
    b.cyl((x, y, 0.5), 0.5, 0.5, 1.2, segs=12, rot=(0, math.pi / 2, a), mat="stone")
    b.cyl((x, y, 0.5), 0.54, 0.54, 0.1, segs=12, rot=(0, math.pi / 2, a), mat="stone2")
# the two missing ring blocks lying around
for k, (px, py, rz, tilt) in zip(sorted(MISSING), ((-3.4, 5.4, 0.7, 0.0), (5.6, 5.0, 2.4, 0.1))):
    th0 = START * D2R + k * step_a + 0.012
    th1 = START * D2R + (k + 1) * step_a - 0.012
    bk = block(th0, th1, R_IN, R_OUT, THICK, k * 3 + 1, "stone")
    # re-centre the arc so it lies flat: rotate about its own centre
    c = V((0, 0, 0))
    for v in bk.bm.verts:
        c += v.co
    c /= len(bk.bm.verts)
    bk.transform(Matrix.Translation(-c))
    bk.transform(Matrix.Rotation(-(th0 + th1) / 2 + math.pi / 2, 4, "Y"))
    zmin = min(v.co.z for v in bk.bm.verts)
    bk.transform(Matrix.Translation(V((0, 0, -zmin + 0.05))))
    bk.transform(S.M4((px, py, 0), (tilt, 0, rz)))
    b.append(bk)
    # moss on the fallen blocks
    ms = S.MB(M)
    ms.sphere((0, 0, 0), 0.5, scale=(1.2, 0.9, 0.34), u=8, v=5, mat="moss")
    ms.transform(S.M4((px, py, 0.95), (0, 0, rz)))
    b.append(ms)
for k in range(16):
    a = rnd.uniform(0, TAU)
    r = rnd.uniform(5.0, 8.3)
    s = rnd.uniform(0.2, 0.55)
    rk = S.MB(M)
    rk.sphere((0, 0, 0), s, scale=(rnd.uniform(0.8, 1.4), rnd.uniform(0.8, 1.2), rnd.uniform(0.5, 0.9)), u=7, v=5, mat="stone" if k % 2 else "stone2")
    L.noise_displace(rk.bm, s * 0.3, 2.0, seed=k + 100)
    rk.transform(S.M4((r * math.cos(a), r * math.sin(a), s * 0.2 + 0.1), (0, 0, rnd.uniform(0, 3))))
    b.append(rk)
# step moss
for k in range(5):
    ms = S.MB(M)
    ms.sphere((0, 0, 0), 0.35, scale=(1.2, 0.8, 0.3), u=8, v=5, mat="moss")
    ms.transform(S.M4((rnd.uniform(-2.8, 2.8), rnd.uniform(2.3, 4.0), 0.2 + 0.3 * rnd.random()), (0, 0, rnd.uniform(0, 3))))
    b.append(ms)

arch = b.build(S.nm(ID, "Arch"), col, smooth=45)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (0, 5.8, 0.0), size=0.5)
a_gate = L.empty(S.nm(ID, "Anchor_Gate"), col, (0, 0, ZC), size=1.0, display="CIRCLE")
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (0, 0, ZC + R_OUT + 1.0), size=0.5)
objs = [arch, a_door, a_gate, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [11.2, 2.3, 5.2], "offset_y": -0.5, "center": [0, 0.65, 0.0]},
    colliders=[{"shape": "box", "size": [11.2, 2.3, 5.2], "offset_y": -0.5, "center": [0, 0.65, 0.0], "note": "dais (walkable top at y=1.8, steps on the Godot +Z side)"},
               {"shape": "box", "size": [1.7, 7.6, 1.7], "offset_y": 1.8, "center": [-4.7, 5.6, 0.0], "note": "ring left side"},
               {"shape": "box", "size": [1.7, 7.6, 1.7], "offset_y": 1.8, "center": [4.7, 5.6, 0.0], "note": "ring right side"},
               {"shape": "box", "size": [8.6, 1.7, 1.7], "offset_y": 9.6, "center": [0, 10.45, 0.0], "note": "ring top"}],
    nodes={"meshes": ["Arch"], "anchors": ["Anchor_Door", "Anchor_Gate", "Anchor_Top"]},
    notes="Ancient ring gate ~12 m: a stone ring (16 blocks, 2 fallen) standing on a dais (top y=1.8, 6 steps on the front = Blender +Y = Godot -Z) over a round plaza; the ring plane is X/Y (Godot), you walk through along Z. "
          "Emissive teal runes (material *_rune, emission 3.5) incl. glowing inner edge; moss patches + vines. Anchor_Gate = ring centre (y=5.7: put a portal/energy effect there), Anchor_Door = stand point in front of the steps, Anchor_Top above the ring. Plaza sinks to y=-0.5.",
    preview_kw=dict(dist_mult=1.45),
)
print(entry["size"], entry["tris"])
