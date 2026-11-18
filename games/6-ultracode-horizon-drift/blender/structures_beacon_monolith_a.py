import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix, Euler

ID = "beacon_monolith_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
V = Vector
rnd = random.Random(2026)

M = S.mats(ID, {
    "stone": dict(color=(0.028, 0.032, 0.042), metallic=0.55, roughness=0.28),
    "stone2": dict(color=(0.085, 0.085, 0.10), metallic=0.1, roughness=0.78),
    "glow": dict(color=(0.04, 0.35, 0.33), emission=(0.1, 1.0, 0.82), emission_strength=4.0, roughness=0.3),
})

Z0, Z1 = 0.75, 6.5


def hx(z):
    t = (z - Z0) / (Z1 - Z0)
    return 0.95 + (0.60 - 0.95) * t


def hy(z):
    t = (z - Z0) / (Z1 - Z0)
    return 0.64 + (0.40 - 0.64) * t


def ch(z):
    t = (z - Z0) / (Z1 - Z0)
    return 0.13 * (1 - 0.35 * t)


def theta(z):
    t = (z - Z0) / (Z1 - Z0)
    return 9.0 * D2R * t


def rz(a):
    return Matrix.Rotation(a, 3, "Z")


def shaft_ring(z, scale=1.0, jit=0.0, off=(0, 0)):
    x, y, c = hx(z) * scale, hy(z) * scale, ch(z) * scale
    pts = [(x - c, -y), (x, -y + c), (x, y - c), (x - c, y), (-x + c, y), (-x, y - c), (-x, -y + c), (-x + c, -y)]
    R = rz(theta(z))
    out = []
    for (px, py) in pts:
        p = R @ V((px, py, 0))
        out.append(V((p.x + off[0] + rnd.uniform(-jit, jit), p.y + off[1] + rnd.uniform(-jit, jit), z)))
    return out


b = S.MB(M)

# ---- plinth tiers ---------------------------------------------------------------------------------------------------
b.box((0, 0, -0.25), (6.5, 6.5, 1.1), mat="stone2", bevel=0.12, top=(0.97, 0.97))
b.box((0, 0, 0.42), (4.9, 4.9, 0.28), mat="stone", bevel=0.07, top=(0.97, 0.97))
b.box((0, 0, 0.65), (3.5, 3.5, 0.24), mat="stone2", bevel=0.06, top=(0.96, 0.96))
b.box((0, 0, 0.74), (2.5, 2.5, 0.08), mat="stone", bevel=0.03)
# code ticks around the lowest tier
n_t = 40
for i in range(n_t):
    a = 2 * math.pi * i / n_t
    if abs(((a * 180 / math.pi) % 90) - 45) > 41 and False:
        continue
    ln = rnd.choice([0.12, 0.2, 0.34, 0.12, 0.26])
    r = 2.95
    b.box((r * math.cos(a), r * math.sin(a), 0.285), (ln, 0.07, 0.02), rot=(0, 0, a + math.pi / 2), mat="glow")
for k in range(4):
    a = k * math.pi / 2 + math.pi / 4
    r = 2.95
    b.box((r * math.cos(a), r * math.sin(a), 0.29), (0.34, 0.34, 0.02), rot=(0, 0, a + math.pi / 4), mat="glow")
# glow line square on tier 1 top
for k in range(4):
    a = k * math.pi / 2
    d = V((math.cos(a), math.sin(a), 0))
    t_ = V((-math.sin(a), math.cos(a), 0))
    p = d * 2.28
    b.box((p.x, p.y, 0.565), (0.05, 4.3, 0.016) if k % 2 == 0 else (4.3, 0.05, 0.016), mat="glow")

# ---- shaft (lofted, slightly twisted, tapered, chipped near the top) ------------------------------------------------------
N = 22
rings = []
for i in range(N + 1):
    z = Z0 - 0.05 + (Z1 - Z0 + 0.05) * i / N
    rings.append(shaft_ring(z, 1.0 if z > Z0 else 1.04, jit=0.012))
# pyramidion
rings.append(shaft_ring(Z1 + 0.18, 0.93, jit=0.01))
rings.append(shaft_ring(Z1 + 0.45, 0.74, jit=0.01, off=(0.0, -0.04)))
rings.append(shaft_ring(Z1 + 0.62, 0.34, jit=0.0, off=(0.0, -0.08)))
b.loft(rings, mat="stone", cap0=True, cap1=True)
ztip = Z1 + 0.62
# broken chip on one upper corner: a few dark-stone wedges at the top-back-left
b.box((-0.45, -0.22, Z1 - 0.35), (0.3, 0.26, 0.5), rot=(0.3, 0.2, 0.6), mat="stone2", bevel=0.02)
# glowing eye diamond at the very top (floating)
b.sphere((0, -0.08, ztip + 0.35), 0.17, scale=(0.8, 0.8, 1.6), u=4, v=4, mat="glow")


# ---- glyphs (flat ribbons following the surface) -------------------------------------------------------------------------------
def face_pt(face, a, z, off=0.012):
    """face: '+y','-y','+x','-x';  a = lateral metres along the face, z height"""
    if face == "+y":
        p = V((a, hy(z) + off, z))
        n = V((0, 1, 0))
    elif face == "-y":
        p = V((-a, -hy(z) - off, z))
        n = V((0, -1, 0))
    elif face == "+x":
        p = V((hx(z) + off, -a, z))
        n = V((1, 0, 0))
    else:
        p = V((-hx(z) - off, a, z))
        n = V((-1, 0, 0))
    R = rz(theta(z))
    q = R @ V((p.x, p.y, 0))
    return V((q.x, q.y, z)), R @ n


def ribbon(face, pts2d, w=0.04, closed=False, mat="glow", off=0.012):
    P, Nn = [], []
    for (a, z) in pts2d:
        p, n = face_pt(face, a, z, off)
        P.append(p)
        Nn.append(n)
    n_ = len(P)
    Ls, Rs = [], []
    for i in range(n_):
        i0 = (i - 1) % n_ if closed else max(i - 1, 0)
        i1 = (i + 1) % n_ if closed else min(i + 1, n_ - 1)
        t = (P[i1] - P[i0]).normalized()
        side = t.cross(Nn[i]).normalized() * (w / 2)
        Ls.append(P[i] + side)
        Rs.append(P[i] - side)
    rng = range(n_) if closed else range(n_ - 1)
    for i in rng:
        j = (i + 1) % n_
        # outward-facing quad
        b.quad(Rs[i], Ls[i], Ls[j], Rs[j], mat=mat)


def circle_pts(a0, z0, r, n=24, start=0.0, sweep=2 * math.pi):
    return [(a0 + r * math.cos(start + sweep * i / n), z0 + r * math.sin(start + sweep * i / n)) for i in range(n + 1)]


def diamond(a0, z0, r):
    return [(a0, z0 + r), (a0 + r * 0.6, z0), (a0, z0 - r), (a0 - r * 0.6, z0)]


def maxa(z):
    return hx(z) - ch(z) - 0.1


# FRONT face (+y)
f = "+y"
ribbon(f, [(-maxa(1.3), 1.3), (maxa(1.3), 1.3), (maxa(6.0), 6.0), (-maxa(6.0), 6.0)], w=0.035, closed=True)
for (za, zb) in ((1.5, 2.55), (2.85, 3.3), (4.55, 5.0), (5.45, 5.9)):
    ribbon(f, [(0, za), (0, zb)], w=0.06)
for r_ in (0.40, 0.26, 0.1):
    ribbon(f, circle_pts(0, 3.95, r_, n=28), w=0.04, closed=True)
for k in range(8):
    a = k * math.pi / 4
    ribbon(f, [(0.43 * math.cos(a), 3.95 + 0.43 * math.sin(a)), (0.55 * math.cos(a), 3.95 + 0.55 * math.sin(a))], w=0.035)
ribbon(f, diamond(0, 5.22, 0.22), w=0.04, closed=True)
ribbon(f, diamond(0, 5.22, 0.09), w=0.04, closed=True)
for zr in [1.55 + 0.19 * i for i in range(6)]:
    for sgn in (-1, 1):
        x0 = sgn * 0.12
        for d in range(rnd.randint(1, 3)):
            ln = rnd.choice([0.06, 0.1, 0.16, 0.24])
            gap = 0.06
            ribbon(f, [(x0, zr), (x0 + sgn * ln, zr)], w=0.04)
            x0 += sgn * (ln + gap)
            if abs(x0) > maxa(zr) - 0.05:
                break
for zr in (5.7, 5.95):
    for sgn in (-1, 1):
        ribbon(f, [(sgn * 0.14, zr), (sgn * 0.14 + sgn * rnd.choice([0.1, 0.2, 0.3]), zr)], w=0.035)
for zr in (2.9, 3.2):
    for sgn in (-1, 1):
        ribbon(f, [(sgn * 0.18, zr), (sgn * 0.18 + sgn * rnd.choice([0.1, 0.24]), zr)], w=0.035)

# BACK face (-y)
f = "-y"
ribbon(f, [(-maxa(1.3), 1.3), (maxa(1.3), 1.3), (maxa(6.0), 6.0), (-maxa(6.0), 6.0)], w=0.035, closed=True)
ribbon(f, [(0, 1.5), (0, 2.3)], w=0.06)
ribbon(f, [(0, 4.3), (0, 5.9)], w=0.06)
for r_ in (0.5, 0.34, 0.18):
    ribbon(f, circle_pts(0, 3.3, r_, n=32), w=0.04, closed=True)
for k in range(16):
    a = k * math.pi / 8
    r_in, r_out = (0.5, 0.62) if k % 2 == 0 else (0.5, 0.57)
    ribbon(f, [(r_in * math.cos(a), 3.3 + r_in * math.sin(a)), (r_out * math.cos(a), 3.3 + r_out * math.sin(a))], w=0.032)
for k in range(5):
    z = 4.55 + k * 0.28
    ribbon(f, [(-0.28, z + 0.18), (0, z), (0.28, z + 0.18)], w=0.04)
for zr in (1.45, 1.62):
    ribbon(f, [(-0.45, zr), (0.45, zr)], w=0.03)
ribbon(f, diamond(0, 2.15, 0.12), w=0.035, closed=True)

# SIDE faces
for face in ("+x", "-x"):
    ribbon(face, [(0, 1.3), (0, 6.0)], w=0.05)
    for k in range(7):
        z = 1.6 + k * 0.62
        ribbon(face, diamond(0, z, 0.1), w=0.032, closed=True)
        ln = rnd.choice([0.12, 0.2, 0.28])
        ribbon(face, [(0.16, z), (0.16 + ln, z)], w=0.03)
        ribbon(face, [(-0.16, z + 0.3), (-0.16 - rnd.choice([0.12, 0.2]), z + 0.3)], w=0.03)

# ---- rubble ----------------------------------------------------------------------------------------------------------------------------
for i in range(11):
    a = rnd.uniform(0, 2 * math.pi)
    r = rnd.uniform(4.3, 6.4)
    sx, sy, sz = rnd.uniform(0.5, 1.5), rnd.uniform(0.5, 1.2), rnd.uniform(0.35, 0.9)
    b.box((r * math.cos(a), r * math.sin(a), sz * 0.5 - 0.35), (sx, sy, sz),
          rot=(rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), rnd.uniform(0, 3.1)), mat="stone2", bevel=0.09)
# a couple of fallen glyph slabs with glow marks
for k, (ang, rr) in enumerate(((200, 4.5), (320, 4.9))):
    a = ang * D2R
    p = V((rr * math.cos(a), rr * math.sin(a), 0.1))
    b.box(p, (1.4, 0.7, 0.3), rot=(0.08, 0.1, a + 0.5), mat="stone", bevel=0.05)
    q = p + V((0, 0, 0.17))
    b.box(q, (0.9, 0.04, 0.015), rot=(0.08, 0.1, a + 0.5), mat="glow")

mono = b.build(S.nm(ID, "Monolith"), col, smooth=40)


# ---- floating rings (separate objects, origin = ring centre, spin about local Z (Blender) = local Y (Godot)) ----------------------------
def make_ring(name, n, r0, r1, h, zc, tilt, glow_r):
    mb = S.MB(M)
    for i in range(n):
        a0 = 2 * math.pi * i / n + 0.03
        a1 = 2 * math.pi * (i + 1) / n - 0.03
        steps = 3
        outer = [(r1 * math.cos(a0 + (a1 - a0) * k / steps), r1 * math.sin(a0 + (a1 - a0) * k / steps)) for k in range(steps + 1)]
        inner = [(r0 * math.cos(a0 + (a1 - a0) * k / steps), r0 * math.sin(a0 + (a1 - a0) * k / steps)) for k in range(steps + 1)][::-1]
        mb.prism(outer + inner, -h / 2, h / 2, mat="stone", bevel=0.025)
        # glow dash on the top face
        am = (a0 + a1) / 2
        rm = (r0 + r1) / 2
        mb.box((rm * math.cos(am), rm * math.sin(am), h / 2 + 0.006), ((a1 - a0) * rm * 0.55, (r1 - r0) * 0.28, 0.014),
               rot=(0, 0, am + math.pi / 2), mat="glow")
    mb.lathe([(glow_r, -0.03), (glow_r + 0.045, -0.03), (glow_r + 0.045, 0.03), (glow_r, 0.03), (glow_r, -0.03)], segs=64, mat="glow")
    ob = mb.build(S.nm(ID, name), col, smooth=40)
    ob.location = (0, 0, zc)
    ob.rotation_euler = tilt
    return ob


ring_a = make_ring("Ring_Outer", 14, 2.05, 2.42, 0.24, 5.0, (12 * D2R, -6 * D2R, 0), 1.98)
ring_b = make_ring("Ring_Inner", 9, 1.42, 1.68, 0.18, 3.0, (-9 * D2R, 8 * D2R, 0), 1.37)

# ---- orbiting shards -----------------------------------------------------------------------------------------------------------------------
sh = S.MB(M)
for i in range(8):
    a = rnd.uniform(0, 2 * math.pi)
    r = rnd.uniform(2.9, 3.9)
    z = rnd.uniform(1.6, 7.0)
    hgt = rnd.uniform(0.28, 0.5)
    rad = rnd.uniform(0.1, 0.18)
    rot = (rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(0, 6))
    c = V((r * math.cos(a), r * math.sin(a), z))
    sh.lathe([(0, -hgt * 1.0), (rad, 0.0)], segs=5, c=c, rot=rot, mat="stone")
    sh.lathe([(rad, 0.0), (0, hgt * 1.15)], segs=5, c=c, rot=rot, mat="glow")
shards = sh.build(S.nm(ID, "Shards"), col, smooth=None, flat=True)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (0, 3.0, 0.3), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (0, 0, ztip + 0.9), size=0.4)

objs = [mono, ring_a, ring_b, shards, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "box", "size": [6.5, 1.1, 6.5], "offset_y": -0.8, "center": [0, -0.25, 0]},
    colliders=[{"shape": "box", "size": [6.5, 1.1, 6.5], "offset_y": -0.8, "center": [0, -0.25, 0], "note": "plinth"},
               {"shape": "box", "size": [2.0, 7.2, 1.4], "offset_y": 0.3, "center": [0, 3.9, 0], "note": "shaft"}],
    nodes={"rings": ["Ring_Outer", "Ring_Inner"], "meshes": ["Monolith", "Shards"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Ancient obelisk ~7.4 m with emissive teal glyph ribbons (material *_glow, emission 5.5) on all 4 faces; main glyph face = Blender +Y (Godot -Z) with a circle motif, "
          "back face has a dial. Ring_Outer / Ring_Inner are separate objects with the origin at the ring centre (y=5.0 / 3.0 in Godot), tilted a few degrees; spin them about their local Y (Godot). "
          "Shards = static floating crystals. Plinth sinks 0.8 m below y=0. Anchor_Door = stand point on the front of the plinth, Anchor_Top above the tip.",
    preview_kw=dict(dist_mult=1.6),
)
print(entry["size"], entry["tris"])
