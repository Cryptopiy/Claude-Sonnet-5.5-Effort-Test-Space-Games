import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "crashed_ship_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
TAU = math.tau
def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)

rnd = random.Random(404)

M = S.mats(ID, {
    "hull": dict(color=(0.40, 0.39, 0.36), metallic=0.15, roughness=0.6),
    "burnt": "burnt",
    "accent": dict(color=(0.62, 0.15, 0.02), metallic=0.1, roughness=0.6),
    "steel": dict(color=(0.17, 0.18, 0.20), metallic=0.8, roughness=0.45),
    "glass": dict(color=(0.10, 0.28, 0.40), metallic=0.0, roughness=0.08, alpha=0.4),
    "ember": dict(color=(0.4, 0.06, 0.01), emission=(1.0, 0.17, 0.015), emission_strength=4.5, roughness=0.5),
    "glow": "emit_cyan",
    "dirt": dict(color=(0.045, 0.038, 0.032), metallic=0.0, roughness=1.0),
})
RX = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))     # prism profile (y,z) extruded along X


def burn(p, bias=0.0):
    return S.fbm(V(p) * 0.45 + V(11, 7, 3), 3) * 1.1 + 0.38 + bias


def sup(c, s, n):
    return math.copysign(abs(c) ** (2.0 / n), c), math.copysign(abs(s) ** (2.0 / n), s)


def ring_pts(y, a, b, zc, segs=24, n=3.4, hump=0.0, dent=0.0):
    pts = []
    for j in range(segs):
        phi = -TAU * j / segs
        cx, sz = sup(math.cos(phi), math.sin(phi), n)
        z = zc + b * sz * (1 + (hump if sz > 0 else 0.0))
        p = V((a * cx, y, z))
        if dent:
            nv = S.fbm(p * 1.3 + V(3, 9, 1), 2)
            p = p + V((nv * dent, nv * dent * 0.3, S.fbm(p * 1.3 + V(8, 2, 5), 2) * dent))
        pts.append(p)
    return pts


def centroid(ring):
    c = V((0, 0, 0))
    for p in ring:
        c += p
    return c / len(ring)


def jag(ring, direction, amp, seed):
    r = random.Random(seed)
    c = centroid(ring)
    out = []
    for j, p in enumerate(ring):
        k = r.random()
        d = amp * (0.15 + 0.85 * k) if j % 2 == 0 else amp * 0.22 * k
        q = p + V(direction) * d + (p - c).normalized() * d * 0.25
        out.append(q)
    return out


def inset_ring(ring, amt):
    c = centroid(ring)
    return [p - (p - c).normalized() * amt for p in ring]


def quad_out(mb, p0, p1, p2, p3, outward, mat):
    n = (p1 - p0).cross(p3 - p0)
    if n.dot(outward) < 0:
        mb.quad(p0, p3, p2, p1, mat=mat)
    else:
        mb.quad(p0, p1, p2, p3, mat=mat)


def shell(mb, rings, matfn, inset=0.08, open0=False, open1=False, mat_in="steel", mat_rim="steel", cap0=None, cap1=None):
    mb.loft(rings, mat=matfn, closed=True, cap0=cap0 is not None, cap1=cap1 is not None, cap_mat=cap0 or cap1)
    inner = [inset_ring(r, inset) for r in rings]
    mb.loft(inner, mat=lambda i, j: (mat_in if matfn(i, j) is not None else None), closed=True, flip=True)
    for idx, is_open, nxt in ((0, open0, 1), (len(rings) - 1, open1, len(rings) - 2)):
        if not is_open:
            continue
        ro, ri = rings[idx], inner[idx]
        out_dir = (centroid(rings[idx]) - centroid(rings[nxt])).normalized()
        n = len(ro)
        for j in range(n):
            j2 = (j + 1) % n
            quad_out(mb, ro[j], ro[j2], ri[j2], ri[j], out_dir, mat_rim)


def sub(*bits):
    return S.MB(M)


# =====================================================================================================================
# FORE SECTION (local frame: level, nose +Y, centre of the section at the origin)
# =====================================================================================================================
mf = S.MB(M)
SEG = 24
Y_F = [-1.0, -0.4, 0.3, 1.0, 1.7, 2.4, 3.1, 3.8, 4.4, 4.85, 5.15]
Y0F, Y1F = Y_F[0], Y_F[-1]


def f_dims(y):
    t = (y - Y0F) / (Y1F - Y0F)
    u = max(0.0, (t - 0.45) / 0.55)
    a = 1.45 * (1 - u ** 2.4) ** 0.5
    b = 1.15 * (1 - u ** 2.0) ** 0.5
    zc = -0.32 * u ** 2.2
    hump = 0.20 * math.exp(-(((t - 0.5) / 0.2) ** 2))
    return max(a, 0.15), max(b, 0.13), zc, hump, t


F_rings = []
for k, y in enumerate(Y_F):
    a, b_, zc, hump, t = f_dims(y)
    dent = 0.05 + (0.16 if t > 0.82 else 0.0)
    F_rings.append(ring_pts(y, a, b_, zc, SEG, 3.4, hump, dent))
F_rings[0] = jag(F_rings[0], (0, -1, 0), 0.85, 17)
F_rings[1] = [p + V((0, rnd.uniform(-0.12, 0.05), 0)) for p in F_rings[1]]

CAN_I = (3, 6)
CAN_J = (16, 17, 18, 19, 20)


def f_skip(i, j):
    """cells with no hull skin: canopy opening + torn skin"""
    if CAN_I[0] <= i <= CAN_I[1] and j in CAN_J:
        return True
    return False


torn_cells = set()
for i in (0, 1):
    for j in range(SEG):
        if rnd.random() < (0.45 if i == 0 else 0.16):
            torn_cells.add((i, j))
for j in (2, 3, 4, 14, 15):             # nose crush hole
    torn_cells.add((9, j))
torn_cells.add((8, 3))
torn_cells.add((8, 4))


def f_core_mat(i, j):
    if f_skip(i, j):
        return None
    return "steel"


shell(mf, F_rings, f_core_mat, inset=0.1, open0=True, open1=False, cap1="steel")

# hull panels
for i in range(len(F_rings) - 1):
    for j in range(SEG):
        if f_skip(i, j) or (i, j) in torn_cells:
            continue
        j2 = (j + 1) % SEG
        a_, b_, c_, d_ = F_rings[i][j], F_rings[i][j2], F_rings[i + 1][j2], F_rings[i + 1][j]
        cen = (a_ + b_ + c_ + d_) * 0.25
        v = burn(cen) + (0.28 if i < 2 else 0.0) + (0.22 if i >= 9 else 0.0)
        if v > 0.72:
            m = "burnt"
        elif 2 <= i <= 7 and j in (23, 0, 1, 11, 12, 13):
            m = "accent"
        else:
            m = "hull"
        mf.panel(a_, b_, c_, d_, t=0.045 + rnd.random() * 0.03, shrink=0.03, mat=m)

# canopy: frame + remaining glass
for i in range(CAN_I[0], CAN_I[1] + 1):
    for j in CAN_J:
        j2 = (j + 1) % SEG
        if j == CAN_J[-1]:
            continue
        a_, b_, c_, d_ = F_rings[i][j], F_rings[i][j2], F_rings[i + 1][j2], F_rings[i + 1][j]
        if rnd.random() < 0.42:
            mf.panel(a_, b_, c_, d_, t=0.012, shrink=0.02, mat="glass")
for i in range(CAN_I[0], CAN_I[1] + 2):
    for j in CAN_J[:-1]:
        mf.beam(F_rings[i][j], F_rings[i][j + 1], 0.07, 0.09, mat="steel")
for j in (CAN_J[0], CAN_J[2], CAN_J[-1]):
    for i in range(CAN_I[0], CAN_I[1] + 1):
        mf.beam(F_rings[i][j], F_rings[i + 1][j], 0.07, 0.09, mat="steel")
mf.beam(F_rings[CAN_I[1] + 1][CAN_J[0]], F_rings[CAN_I[1] + 1][CAN_J[-1]] + V((0, 0.15, 0.05)), 0.07, 0.1, mat="steel")
# snapped canopy arch sticking up
p0 = F_rings[4][18]
mf.strut(p0, p0 + V((0.35, -0.2, 0.85)), 0.04, 0.03, segs=6, mat="steel")

# interior bulkhead rings
for i in (1, 3, 5, 7):
    inner = inset_ring(F_rings[i], 0.13)
    for j in range(SEG):
        if f_skip(i, j) and j in CAN_J:
            continue
        mf.beam(inner[j], inner[(j + 1) % SEG], 0.06, 0.12, mat="steel")
# floor, seats, console
mf.box((0, 1.2, -0.72), (2.2, 4.6, 0.08), mat="steel", bevel=0.02)
for sx in (-1, 1):
    mf.box((sx * 0.55, 2.3, -0.42), (0.62, 0.7, 0.4), mat="burnt", bevel=0.06)
    mf.box((sx * 0.55, 1.95, 0.0), (0.58, 0.14, 0.85), mat="burnt", bevel=0.05, rot=(-0.12, 0, 0))
mf.box((0, 3.55, -0.2), (1.9, 0.9, 0.55), mat="steel", bevel=0.05, rot=(0.25, 0, 0))
mf.box((0.3, 3.35, 0.13), (0.8, 0.04, 0.35), mat="glow", rot=(0.25, 0, 0))
mf.box((-0.5, 3.35, 0.1), (0.4, 0.04, 0.2), mat="ember", rot=(0.25, 0, 0))
mf.box((0.0, 1.0, -0.5), (0.6, 0.5, 0.4), mat="burnt", bevel=0.05)
for sx in (-1, 1):
    mf.beam((sx * 0.7, 3.2, -0.55), (sx * 1.0, 1.0, -0.2), 0.12, 0.08, mat="steel")
# ribs sticking out of the break (bent girders)
for k in range(5):
    a = (k / 5.0) * TAU + 0.3
    base = V((1.25 * math.cos(a), -0.9, 1.0 * math.sin(a) - 0.05))
    dirv = V((math.cos(a) * 0.25, -1.0, math.sin(a) * 0.15 - 0.45))
    mf.strut(base, base + dirv * rnd.uniform(0.7, 1.4), 0.045, 0.035, segs=6, mat="steel")
# dangling cables
for k in range(5):
    x0 = rnd.uniform(-0.8, 0.8)
    z0 = rnd.uniform(-0.5, 0.6)
    ln = rnd.uniform(1.2, 2.2)
    mf.pipe([V((x0, -0.5, z0)), V((x0 + rnd.uniform(-0.3, 0.3), -1.0 - ln * 0.3, z0 - 0.25)),
             V((x0 + rnd.uniform(-0.5, 0.5), -1.2 - ln * 0.7, z0 - 0.9)), V((x0 + rnd.uniform(-0.6, 0.6), -1.4 - ln, z0 - 1.3))],
            0.028, segs=6, mat="steel", bend=0.3)
# embers on the torn rim
for j in range(0, SEG, 2):
    p = F_rings[0][j]
    if rnd.random() < 0.55:
        mf.box(p + V((0, 0.05, 0)), (0.08, 0.05, 0.05), rot=(rnd.random(), rnd.random(), rnd.random()), mat="ember")

# ---- wings (in fore-section frame) ---------------------------------------------------------------------------------
def wing_rings(sign, s_list, root_x=1.2, z0=-0.38, droop=0.0, noise=0.03):
    rings = []
    for s in s_list:
        le = 2.2 - 0.38 * s
        te = -1.0 + 0.12 * s
        h = 0.30 * (1 - 0.72 * s / 4.6)
        ring = []
        nu = 7
        up = []
        for k in range(nu + 1):
            u = k / nu
            shp = (1 - (2 * u - 1) ** 2) ** 0.7 * (1 - 0.25 * u)
            up.append((le + (te - le) * u, h * shp))
        lo = []
        for k in range(nu, -1, -1):
            u = k / nu
            shp = (1 - (2 * u - 1) ** 2) ** 0.7 * (1 - 0.25 * u)
            lo.append((le + (te - le) * u, -h * shp * 0.75))
        pts = up + lo[1:-1]
        for (yy, zz) in pts:
            x = sign * (root_x + s)
            z = z0 + zz - droop * s * s
            ring.append(V((x, yy, z)))
        rings.append(ring)
    return rings


def wing_mat(seedoff):
    def fn(i, j):
        pos = V((i * 0.6, j * 0.4, seedoff))
        v = S.fbm(pos * 0.9 + V(5, 5, seedoff), 3) * 1.1 + 0.42
        if v > 0.7:
            return "burnt"
        if 1 <= i <= 3 and j in (2, 3, 4):
            return "accent"
        return "hull"
    return fn


# right wing: intact, bent down, tip crumpled
ss = [0.0, 0.5, 1.1, 1.8, 2.5, 3.2, 3.8, 4.3, 4.6]
rw = wing_rings(1, ss, droop=0.05)
rw = [[p + V((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.05, 0.05), rnd.uniform(-0.03, 0.03))) for p in r] for r in rw]
rw[-1] = jag(rw[-1], (1, 0, 0), 0.5, 5)
shell(mf, rw, wing_mat(1.0), inset=0.05, open0=False, open1=True)
# left wing: torn off at s ~ 1.9
ss_l = [0.0, 0.5, 1.1, 1.6, 1.95]
lw = wing_rings(-1, ss_l, droop=0.0)
lw[-1] = jag(lw[-1], (-1, 0, 0), 0.9, 9)
# make jag direction go along -X only for tips; the loft for left wing is mirrored -> flip
mf.loft(lw, mat=wing_mat(2.0), closed=True, flip=True)
inner_l = [inset_ring(r, 0.05) for r in lw]
mf.loft(inner_l, mat="steel", closed=True)
ro, ri = lw[-1], inner_l[-1]
for j in range(len(ro)):
    quad_out(mf, ro[j], ro[(j + 1) % len(ro)], ri[(j + 1) % len(ro)], ri[j], V((-1, 0, 0)), "steel")
# spars sticking out of the left break
for k in range(3):
    yy = 1.1 - k * 0.7
    p0 = V((-3.1, yy, -0.4))
    mf.strut(p0, p0 + V((-rnd.uniform(0.5, 0.9), rnd.uniform(-0.2, 0.2), rnd.uniform(0.1, 0.5))), 0.04, 0.03, segs=6, mat="steel")
mf.box(V((-3.2, 0.5, -0.4)), (0.1, 0.1, 0.1), mat="ember")
mf.box(V((-3.15, -0.3, -0.35)), (0.1, 0.08, 0.1), mat="ember")
# collapsed nose gear
g0 = V((0.0, 3.3, -1.0))
mf.strut(g0, g0 + V((0.25, 0.45, -1.15)), 0.09, 0.07, segs=8, mat="steel")
mf.strut(g0 + V((0.25, 0.45, -1.15)), g0 + V((0.55, 0.4, -1.7)), 0.07, 0.05, segs=8, mat="steel")
mf.box(g0 + V((0.62, 0.4, -1.78)), (0.7, 0.9, 0.12), rot=(0.1, 0.35, 0.2), mat="steel", bevel=0.03)
g1 = V((1.0, 0.2, -0.95))
mf.strut(g1, g1 + V((0.2, -0.3, -0.9)), 0.09, 0.07, segs=8, mat="steel")
mf.box(g1 + V((0.25, -0.35, -1.0)), (0.7, 1.0, 0.12), rot=(0.05, 0.2, 0.1), mat="steel", bevel=0.03)

# =====================================================================================================================
# AFT SECTION (local: torn end at y = 0 facing +Y, rear at y = -4.3)
# =====================================================================================================================
ma = S.MB(M)
Y_A = [-4.3, -3.6, -2.9, -2.2, -1.5, -0.8, -0.3, 0.0]
A_rings = []
for y in Y_A:
    s = (y - Y_A[0]) / (Y_A[-1] - Y_A[0])
    e = s ** 0.8
    a = 1.0 + 0.45 * e
    b_ = 0.88 + 0.27 * e
    A_rings.append(ring_pts(y, a, b_, 0.08 * (1 - s), SEG, 3.4, 0.0, 0.05))
A_rings[-1] = jag(A_rings[-1], (0, 1, 0), 0.8, 31)
A_rings[-2] = [p + V((0, rnd.uniform(-0.1, 0.1), 0)) for p in A_rings[-2]]
a_torn = set()
for i in (5, 6):
    for j in range(SEG):
        if rnd.random() < (0.42 if i == 6 else 0.15):
            a_torn.add((i, j))


def a_core(i, j):
    return "steel"


shell(ma, A_rings, a_core, inset=0.1, open0=False, open1=True, cap0="steel")
for i in range(len(A_rings) - 1):
    for j in range(SEG):
        if (i, j) in a_torn:
            continue
        j2 = (j + 1) % SEG
        a_, b_, c_, d_ = A_rings[i][j], A_rings[i][j2], A_rings[i + 1][j2], A_rings[i + 1][j]
        cen = (a_ + b_ + c_ + d_) * 0.25
        v = burn(cen + V((4, 4, 4))) + (0.3 if i < 3 else 0.0) + (0.25 if i >= 6 else 0.0)
        if v > 0.7:
            m = "burnt"
        elif 1 <= i <= 4 and j in (23, 0, 1, 11, 12, 13):
            m = "accent"
        else:
            m = "hull"
        ma.panel(a_, b_, c_, d_, t=0.045 + rnd.random() * 0.03, shrink=0.03, mat=m)
for i in (3, 5):
    inner = inset_ring(A_rings[i], 0.13)
    for j in range(SEG):
        ma.beam(inner[j], inner[(j + 1) % SEG], 0.06, 0.12, mat="steel")
# rear engine plate details + tail fin
fin = [(-1.3, 0.85), (-4.0, 0.85), (-4.15, 2.5), (-3.65, 3.4), (-3.4, 2.9), (-3.0, 3.5), (-2.7, 2.7), (-2.2, 3.0), (-1.9, 2.0)]
ma.prism(fin, -0.07, 0.07, mat="hull", rot=RX, bevel=0.01)
ma.prism([(-1.8, 1.3), (-3.9, 1.3), (-3.95, 1.8), (-1.75, 1.8)], -0.075, 0.075, mat="accent", rot=RX)
ma.prism([(-3.6, 2.3), (-4.0, 2.3), (-4.1, 2.9), (-3.62, 3.35), (-3.5, 2.6)], -0.078, 0.078, mat="burnt", rot=RX)
# nacelle right (intact, burnt)
NAC = [(0, -1.45), (0.27, -1.45), (0.40, -1.72), (0.45, -1.72), (0.47, -1.4), (0.50, -0.95), (0.57, -0.3), (0.58, 0.5), (0.52, 1.1), (0.36, 1.45), (0.0, 1.55)]
c_r = V((1.5, -3.4, -0.12))
ma.lathe(NAC, segs=18, c=c_r, rot=(-math.pi / 2, 0, 0), mat="burnt")
ma.lathe([(0.0, -1.43), (0.25, -1.43), (0.25, -1.41), (0.0, -1.41)], segs=16, c=c_r, rot=(-math.pi / 2, 0, 0), mat="ember")
ma.cyl(c_r + V((0, 0.75, 0)), 0.60, 0.60, 0.22, segs=18, axis="Y", mat="accent")
ma.cyl(c_r + V((0, -0.55, 0)), 0.55, 0.55, 0.07, segs=18, axis="Y", mat="steel")
ma.beam(V((0.9, -3.4, -0.1)), V((1.5, -3.4, -0.1)), 0.35, 0.3, mat="steel")
ma.beam(V((1.0, -3.6, 0.45)), V((1.5, -3.0, 0.2)), 0.1, 0.4, mat="steel")
# nacelle left: just a stump with ragged rim
c_l = V((-1.5, -2.4, -0.12))
ma.lathe([(0.63, -0.4), (0.62, 0.0), (0.63, 1.1), (0, 1.1)][::1], segs=18, c=c_l, rot=(-math.pi / 2, 0, 0), mat="burnt")
for k in range(11):
    a = TAU * k / 11
    r = 0.62
    p = c_l + V((r * math.cos(a), -0.4 - rnd.random() * 0.35, r * math.sin(a)))
    ma.box(p, (0.09, 0.4, 0.05), rot=(0, 0, a), mat="steel")
for k in range(4):
    a = TAU * k / 4 + 0.4
    ma.pipe([c_l + V((0.2 * math.cos(a), -0.1, 0.2 * math.sin(a))), c_l + V((0.35 * math.cos(a), -0.6, 0.35 * math.sin(a) - 0.05)),
             c_l + V((0.6 * math.cos(a), -0.9, 0.6 * math.sin(a) - 0.4))], 0.025, segs=6, mat="steel", bend=0.2)
ma.box(c_l + V((0.15, -0.55, 0.2)), (0.12, 0.08, 0.08), mat="ember")
# embers on the torn rim
for j in range(0, SEG, 2):
    if rnd.random() < 0.5:
        ma.box(A_rings[-1][j] + V((0, 0.05, 0)), (0.08, 0.05, 0.05), rot=(rnd.random(), rnd.random(), rnd.random()), mat="ember")
# ribs sticking out
for k in range(5):
    a = (k / 5.0) * TAU + 1.0
    base = V((1.35 * math.cos(a), 0.0, 1.05 * math.sin(a)))
    dirv = V((math.cos(a) * 0.2, 1.0, math.sin(a) * 0.2 + 0.2))
    ma.strut(base, base + dirv * rnd.uniform(0.6, 1.2), 0.045, 0.035, segs=6, mat="steel")

# =====================================================================================================================
# place the sections in the world
# =====================================================================================================================
def place(mb, loc, yaw, pitch, roll, floor_z, ref_pts=None):
    R = Matrix.Rotation(yaw * D2R, 4, "Z") @ Matrix.Rotation(pitch * D2R, 4, "X") @ Matrix.Rotation(roll * D2R, 4, "Y")
    mb.transform(R)
    if ref_pts:
        zmin = min((R @ p).z for p in ref_pts)
    else:
        zmin = min(v.co.z for v in mb.bm.verts)
    mb.transform(Matrix.Translation(V((loc[0], loc[1], floor_z - zmin))))
    return R


Rf = place(mf, (0.3, 1.6, 0), -7, -9, 10, -0.3, ref_pts=F_rings[-1] + F_rings[-2] + F_rings[-3])
Ra = place(ma, (-1.1, -2.4, 0), 17, 3, -15, -0.12)

# =====================================================================================================================
# debris + ground scar (world frame)
# =====================================================================================================================
md = S.MB(M)
# broken wing tip lying on its side
tip_s = [2.6, 3.0, 3.5, 4.0, 4.5]
tr = wing_rings(-1, tip_s, droop=0.0)
tr[0] = jag(tr[0], (1, 0, 0), 0.5, 13)
tr[-1] = jag(tr[-1], (-1, 0, 0), 0.5, 14)
tw = S.MB(M)
shell(tw, tr, wing_mat(3.0), inset=0.05, open0=True, open1=True)
tw.transform(Matrix.Translation(V((3.55 + 1.2, 0, 0))))
Rw = Matrix.Rotation(40 * D2R, 4, "Z") @ Matrix.Rotation(14 * D2R, 4, "Y") @ Matrix.Rotation(6 * D2R, 4, "X")
tw.transform(Rw)
zm = min(v.co.z for v in tw.bm.verts)
tw.transform(Matrix.Translation(V((-6.2, 0.6, 0.0 - zm - 0.05))))
md.append(tw)
# torn-off engine pod lying on the ground
pod = S.MB(M)
pod.lathe(NAC, segs=18, c=(0, 0, 0), rot=(-math.pi / 2, 0, 0), mat="burnt")
pod.cyl((0, 0.75, 0), 0.60, 0.60, 0.22, segs=18, axis="Y", mat="accent")
pod.cyl((0, -0.55, 0), 0.55, 0.55, 0.07, segs=18, axis="Y", mat="steel")
pod.lathe([(0.0, -1.43), (0.25, -1.43), (0.25, -1.41), (0.0, -1.41)], segs=16, rot=(-math.pi / 2, 0, 0), mat="ember")
Rp = Matrix.Rotation(-64 * D2R, 4, "Z") @ Matrix.Rotation(7 * D2R, 4, "Y")
pod.transform(Rp)
zm = min(v.co.z for v in pod.bm.verts)
pod.transform(Matrix.Translation(V((4.9, -4.6, -zm - 0.05))))
md.append(pod)
# plates
for k in range(12):
    ang = rnd.uniform(0, TAU)
    r = rnd.uniform(3.2, 6.8)
    w, h = rnd.uniform(0.7, 1.9), rnd.uniform(0.6, 1.4)
    tiltx, tilty = rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)
    m = rnd.choice(["hull", "burnt", "hull", "accent", "burnt"])
    md.box((r * math.cos(ang) * 0.9, r * math.sin(ang) * 0.9 - 0.5, 0.1 + abs(tiltx) * h * 0.5), (w, h, 0.05),
           rot=(tiltx, tilty, rnd.uniform(0, 3.14)), mat=m, bevel=0.01)
# curved bulkhead arcs
for (cx, cy, a0, a1, rad) in ((4.3, -1.0, 0.3, 2.0, 1.4), (-3.6, -5.2, 3.0, 4.6, 1.3), (-2.6, 6.0, 0.5, 2.1, 1.0)):
    n = 7
    for k in range(n):
        a = a0 + (a1 - a0) * k / n
        b2 = a0 + (a1 - a0) * (k + 1) / n
        p0 = V((cx + rad * math.cos(a), cy + rad * math.sin(a), 0.1))
        p1 = V((cx + rad * math.cos(b2), cy + rad * math.sin(b2), 0.1))
        md.beam(p0, p1, 0.1, 0.16, mat="steel", up=(0, 0, 1))
# girders
for k in range(6):
    p = V((rnd.uniform(-5.5, 5.5), rnd.uniform(-6, 5), 0.12))
    d = V((math.cos(rnd.uniform(0, 3.14)), math.sin(rnd.uniform(0, 3.14)), rnd.uniform(0.0, 0.25))).normalized() * rnd.uniform(1.0, 2.4)
    md.beam(p, p + d, 0.1, 0.1, mat="steel")
# two crates (one tipped)
md.box((4.1, 2.4, 0.33), (0.85, 0.6, 0.66), rot=(0, 0, 0.5), mat="accent", bevel=0.04)
md.box((4.1, 2.4, 0.66), (0.9, 0.65, 0.06), rot=(0, 0, 0.5), mat="steel", bevel=0.01)
md.box((4.9, 1.2, 0.29), (0.85, 0.6, 0.6), rot=(0.9, 0.1, 1.1), mat="accent", bevel=0.04)
# an ejected seat
md.box((-4.4, -2.2, 0.28), (0.6, 0.7, 0.4), rot=(0.4, 0.2, 0.9), mat="burnt", bevel=0.06)
md.box((-4.55, -1.95, 0.62), (0.58, 0.14, 0.8), rot=(0.6, 0.2, 0.9), mat="burnt", bevel=0.05)
# small embers around the wreck
for k in range(10):
    p = V((rnd.uniform(-5, 5), rnd.uniform(-6.5, 5.5), 0.1))
    md.box(p, (0.09, 0.06, 0.05), rot=(0, 0, rnd.uniform(0, 3)), mat="ember")

def gbox(mb):
    xs = [v.co.x for v in mb.bm.verts]
    ys = [v.co.y for v in mb.bm.verts]
    zs = [max(v.co.z, -0.6) for v in mb.bm.verts]
    sx, sy, sz = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
    cx, cy, cz = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2
    return {"shape": "box", "size": [round(sx, 2), round(sz, 2), round(sy, 2)], "offset_y": round(min(zs), 2), "center": [round(cx, 2), round(cz, 2), round(-cy, 2)]}


box_fore = gbox(mf)
box_aft = gbox(ma)
box_fore["note"] = "fore section + wings (approx)"
box_aft["note"] = "aft section (approx)"
# union of both for the primary collider
def union(a, b_):
    ax0, ax1 = a["center"][0] - a["size"][0] / 2, a["center"][0] + a["size"][0] / 2
    bx0, bx1 = b_["center"][0] - b_["size"][0] / 2, b_["center"][0] + b_["size"][0] / 2
    az0, az1 = a["center"][2] - a["size"][2] / 2, a["center"][2] + a["size"][2] / 2
    bz0, bz1 = b_["center"][2] - b_["size"][2] / 2, b_["center"][2] + b_["size"][2] / 2
    ay0 = a["offset_y"]
    ay1 = a["offset_y"] + a["size"][1]
    by0 = b_["offset_y"]
    by1 = b_["offset_y"] + b_["size"][1]
    x0, x1, z0, z1, y0, y1 = min(ax0, bx0), max(ax1, bx1), min(az0, bz0), max(az1, bz1), min(ay0, by0), max(ay1, by1)
    return {"shape": "box", "size": [round(x1 - x0, 2), round(y1 - y0, 2), round(z1 - z0, 2)], "offset_y": round(y0, 2), "center": [round((x0 + x1) / 2, 2), round((y0 + y1) / 2, 2), round((z0 + z1) / 2, 2)]}


box_all = union(box_fore, box_aft)
print("colliders", box_all, box_fore, box_aft)
SHX, SHY = -box_all["center"][0], box_all["center"][2]       # Blender shift (x, y) that centres the primary collider on the origin
SH = Matrix.Translation(V((SHX, SHY, 0)))
for box in (box_all, box_fore, box_aft):
    box["center"] = [round(box["center"][0] + SHX, 2), box["center"][1], round(box["center"][2] - SHY, 2)]
mf.transform(SH)
ma.transform(SH)
md.transform(SH)

wreck_mb = S.MB(M)
wreck_mb.append(mf)
wreck_mb.append(ma)
wreck_mb.append(md)
for v_ in wreck_mb.bm.verts:
    if v_.co.z < -0.6:
        v_.co.z = -0.6          # everything below -0.6 is buried anyway; keeps the AABB sane
wreck = wreck_mb.build(S.nm(ID, "Wreck"), col, smooth=38)

# ground scar (scorched earth with berms) --------------------------------------------------------------------------------------------------------
sc = S.MB(M)
prof = [(-3.2, -0.45), (-2.8, 0.02), (-2.35, 0.22), (-1.95, 0.30), (-1.6, 0.14), (-1.0, 0.07), (0.0, 0.05), (1.0, 0.07), (1.6, 0.14), (1.95, 0.30), (2.35, 0.22), (2.8, 0.02), (3.2, -0.45)]
rings = []
Ys = [-8.0, -6.6, -4.8, -3.0, -1.2, 0.6, 2.4, 4.1, 5.5, 6.4]
for k, y in enumerate(Ys):
    t = k / (len(Ys) - 1)
    wscale = 0.45 + 0.62 * math.sin(math.pi * min(1.0, t * 1.08)) ** 0.6
    cx = 0.5 * math.sin(t * 3.2) - 0.6 * t
    ring = []
    for (u, z) in prof:
        n = S.fbm(V((u * 0.6, y * 0.4, 1.0)), 2) * 0.12
        ring.append(V((cx + u * wscale, y + n * 2.0, z * (0.7 + 0.3 * wscale) + n)))
    rings.append(ring)
sc.loft(rings, mat="dirt", closed=False)
# glowing cracks on the scar
for k in range(14):
    t0 = rnd.uniform(0.1, 0.9)
    y = Ys[0] + (Ys[-1] - Ys[0]) * t0
    x = rnd.uniform(-1.6, 1.6) + 0.5 * math.sin(t0 * 3.2) - 0.6 * t0
    ang = rnd.uniform(0, TAU)
    ln = rnd.uniform(0.25, 0.8)
    pts = [V((x, y, 0.09))]
    for s in range(3):
        ang += rnd.uniform(-0.8, 0.8)
        pts.append(pts[-1] + V((math.cos(ang) * ln / 3, math.sin(ang) * ln / 3, 0.0)))
    for s in range(len(pts) - 1):
        d = pts[s + 1] - pts[s]
        side = V((-d.y, d.x, 0)).normalized() * 0.025
        sc.quad(pts[s] - side, pts[s] + side, pts[s + 1] + side, pts[s + 1] - side, mat="ember")
        sc.quad(pts[s] + side + V((0, 0, 0.001)), pts[s] - side + V((0, 0, 0.001)), pts[s + 1] - side + V((0, 0, 0.001)), pts[s + 1] + side + V((0, 0, 0.001)), mat="ember")
sc.transform(SH)
scar = sc.build(S.nm(ID, "Scar"), col, smooth=None)
scar_flat = scar
for p in scar.data.polygons:
    p.use_smooth = True

# ---- anchors -------------------------------------------------------------------------------------------------------------------------
fore_break = Rf @ V((0, -1.0, 0)) + V((0.3, 1.6, 0.0))
a_smoke0 = L.empty(S.nm(ID, "Anchor_Smoke_0"), col, (SHX + 0.0, SHY + 0.6, 1.3), size=0.5)
a_smoke1 = L.empty(S.nm(ID, "Anchor_Smoke_1"), col, (SHX + 2.2, SHY - 4.6, 1.0), size=0.5)
a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (SHX - 4.3, SHY + 2.0, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (SHX + 0.3, SHY + 2.0, 3.0), size=0.4)
objs = [wreck, scar, a_smoke0, a_smoke1, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider=box_all,
    colliders=[box_fore, box_aft],
    nodes={"smoke": ["Anchor_Smoke_0", "Anchor_Smoke_1"], "meshes": ["Wreck", "Scar"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Crashed explorer shuttle (~12 m of hull): fore section nose-down in the ground at +Y (Godot -Z), broken aft section with one engine left, snapped wings, scattered debris, scorched ground scar (mesh `Scar`, dark soil with glowing ember cracks). "
          "`Wreck` = ship + debris, `Scar` = ground decal-mesh sinking to -0.45 at its rim. Emissive embers (*_ember) + cyan dying screen (*_glow). Anchor_Smoke_0/1 = emitter points (breach / engine stump) for smoke or fire particles. "
          "Visible side stripe = accent orange, scorch = burnt. Collider is rough: use the box, or the two sub-boxes in `colliders`.",
    preview_kw=dict(dist_mult=1.25),
)
print(entry["size"], entry["tris"])
