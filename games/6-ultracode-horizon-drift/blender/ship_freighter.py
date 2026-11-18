"""ship_freighter -- decorative capital cargo ship, ~142 m long.  Blender: +Y bow, Z up, origin = middle of the ship.
Node names: Freighter (root) > Hull, Containers, Engines, EngineGlow_0..4, NavLight_L/R/Tail, BlinkLight.
"""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy, bmesh
from mathutils import Vector, Matrix
import lib_common as L
import ship_lib as S
importlib.reload(L)
importlib.reload(S)
V = Vector
TAU = math.tau
MID = "ship_freighter"
PFX = MID + "__"
rng = random.Random(7)
DO_EXPORT = True
DO_PREVIEW = False


def W(x, y, z):
    return Vector((x, y, z))


M = {}
M["hull"] = L.mat(MID + "_hull", (0.30, 0.34, 0.40), metallic=0.35, roughness=0.55)
M["dark"] = L.mat(MID + "_dark", (0.045, 0.05, 0.06), metallic=0.5, roughness=0.5)
M["accent"] = L.mat(MID + "_accent", (0.95, 0.52, 0.05), metallic=0.1, roughness=0.45)
M["trim"] = L.mat(MID + "_trim", (0.52, 0.54, 0.58), metallic=0.5, roughness=0.45)
M["window"] = L.mat(MID + "_window", (1.0, 0.6, 0.2), emission=(1.0, 0.58, 0.18), emission_strength=2.6)
M["glow"] = L.mat(MID + "_glow", (0.1, 0.7, 1.0), emission=(0.08, 0.75, 1.0), emission_strength=5.0)
M["red"] = L.mat(MID + "_nav_red", (1.0, 0.05, 0.03), emission=(1.0, 0.05, 0.03), emission_strength=7.0)
M["green"] = L.mat(MID + "_nav_green", (0.05, 1.0, 0.15), emission=(0.05, 1.0, 0.15), emission_strength=7.0)
M["white"] = L.mat(MID + "_nav_white", (1.0, 1.0, 1.0), emission=(1.0, 0.97, 0.9), emission_strength=8.0)
M["flame_o"] = L.mat(MID + "_flame_outer", (0.05, 0.55, 1.0), emission=(0.05, 0.6, 1.0), emission_strength=3.0, alpha=0.45)
M["flame_i"] = L.mat(MID + "_flame_inner", (0.5, 0.9, 1.0), emission=(0.45, 0.9, 1.0), emission_strength=5.0)
CONT = [
    L.mat(MID + "_cont_red", (0.50, 0.12, 0.06), metallic=0.25, roughness=0.6),
    L.mat(MID + "_cont_blue", (0.08, 0.20, 0.50), metallic=0.25, roughness=0.6),
    L.mat(MID + "_cont_teal", (0.05, 0.40, 0.36), metallic=0.25, roughness=0.6),
    L.mat(MID + "_cont_mustard", (0.78, 0.52, 0.06), metallic=0.25, roughness=0.6),
    L.mat(MID + "_cont_white", (0.70, 0.70, 0.67), metallic=0.25, roughness=0.6),
    L.mat(MID + "_cont_green", (0.10, 0.34, 0.14), metallic=0.25, roughness=0.6),
]
HULL, DARK, ACC, TRIM, WIN, GLOW = 0, 1, 2, 3, 4, 5
HULL_MATS = [M["hull"], M["dark"], M["accent"], M["trim"], M["window"], M["glow"]]

col = L.fresh_collection(MID)
for o in list(bpy.data.objects):
    if o.name.startswith(PFX):
        bpy.data.objects.remove(o, do_unlink=True)
S.begin(col)
root = L.empty(PFX + "Freighter", col, (0, 0, 0), display="PLAIN_AXES", size=5.0)

# ------------------------------------------------------------------------------------------------------------
# main hull loft
# ------------------------------------------------------------------------------------------------------------
FK = [
    (-69.5, 11.5, 7.2, 0.3, -6.8, 3.4, 3.6),
    (-66.0, 13.0, 8.4, 0.5, -8.0, 3.4, 3.6),
    (-52.0, 13.0, 8.4, 0.5, -8.0, 3.4, 3.6),
    (-44.0, 12.0, 7.8, 0.4, -7.4, 3.4, 3.6),
    (-41.0, 5.4, 5.2, 0.0, -5.2, 4.0, 4.0),
    (-36.0, 5.2, 5.0, 0.0, -5.0, 4.0, 4.0),
    (12.0, 5.2, 5.0, 0.0, -5.0, 4.0, 4.0),
    (16.0, 7.0, 6.0, 0.2, -5.6, 3.6, 3.8),
    (20.0, 11.0, 8.2, 0.5, -6.6, 3.4, 3.6),
    (44.0, 11.5, 8.6, 0.5, -6.8, 3.4, 3.6),
    (52.0, 9.0, 7.6, 0.4, -6.0, 3.0, 3.2),
    (60.0, 5.5, 5.2, 0.2, -4.4, 2.8, 3.0),
    (66.0, 2.8, 3.0, 0.1, -2.6, 2.4, 2.6),
    (71.0, 0.5, 0.9, 0.0, -0.7, 2.2, 2.2),
]
YS = [71, 69.5, 67.5, 65, 62, 59, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20.5, 18, 16, 14, 12, 8, 0, -8, -16, -24, -32, -37, -40.5,
      -42.2, -44, -48, -52, -56, -60, -64, -66, -68, -69.5]
NSEG = 24
hull = bmesh.new()
G, F = S.loft_sections(hull, FK, YS, nseg=NSEG, mat=HULL)
for key, f in F.items():
    if key in ("cap0", "cap1"):
        f.material_index = DARK
        continue
    i, j = key
    ym = 0.5 * (YS[i] + YS[i + 1])
    m = HULL
    if 14 <= j <= 22:
        m = DARK
    if j in (23, 0, 11, 12) and (-68 < ym < -44 or 20 < ym < 56):
        m = ACC
    if ym > 63:
        m = DARK if j in range(12, 24) else HULL
    f.material_index = m
bmesh.ops.recalc_face_normals(hull, faces=hull.faces)
hull.faces.ensure_lookup_table()
surf = S.Surf(hull)
ks_ = sorted(FK)
ZC = S.Mono([k[0] for k in ks_], [k[3] for k in ks_])

det = bmesh.new()


def hline(pts_param, width=0.2, lift=0.05, mat=DARK):
    P_, N_ = [], []
    for (y, phi) in pts_param:
        a = math.radians(phi)
        loc, nrm, idx, d = surf.bvh.ray_cast(V((0, y, ZC(y))), V((math.cos(a), 0, math.sin(a))), 400.0)
        if loc is None:
            continue
        P_.append(loc)
        N_.append(nrm)
    if len(P_) >= 2:
        S.ribbon(det, P_, N_, width, lift, mat)


for y in (-66, -62, -58, -54, -50, -46, 22, 26, 30, 34, 38, 42, 47, 55, 61):
    hline([(y, p) for p in range(0, 361, 6)], width=0.22, lift=0.05)
for ph in (45, 135, 225, 315):
    hline([(y, ph) for y in range(-67, -44, 3)], width=0.2)
    hline([(y, ph) for y in range(21, 60, 3)], width=0.2)
for ph in (20, 160, 90, 270):
    hline([(y, ph) for y in range(-36, 12, 3)], width=0.25)
# spine rings between the gantry posts
for y in (10, 7, -4, -17, -30, -38):
    hline([(y, p) for p in range(0, 361, 8)], width=0.2)


def side_ray(y, z, sgn):
    loc, nrm, idx, d = surf.bvh.ray_cast(V((60.0 * sgn, y, z)), V((-sgn, 0, 0)), 400.0)
    return loc, nrm


# windows: command block flanks, engine block flanks
for sgn in (-1, 1):
    for z in (3.4, 5.0):
        for k in range(18):
            y = 22.5 + k * 1.2
            loc, nrm = side_ray(y, z, sgn)
            if loc is not None and rng.random() > 0.08:
                S.quad(det, loc, nrm, V((0, 0, 1)), 0.7, 0.6, WIN, lift=0.06)
    for z in (4.0,):
        for k in range(12):
            y = -66.5 + k * 1.1
            loc, nrm = side_ray(y, z, sgn)
            if loc is not None and rng.random() > 0.15:
                S.quad(det, loc, nrm, V((0, 0, 1)), 0.5, 0.45, WIN, lift=0.06)
# bow landing lights / sensor band
for sgn in (-1, 1):
    loc, nrm = side_ray(63.5, 0.3, sgn)
    if loc is not None:
        S.quad(det, loc, nrm, V((0, 0, 1)), 1.3, 0.6, GLOW, lift=0.06)

# ------------------------------------------------------------------------------------------------------------
# surface greebles (plates, vents, sensor domes) scattered over the command block / prow / engine block
# ------------------------------------------------------------------------------------------------------------
def obox(center, size, normal, mat, spin=0.0, off=(0.0, 0.0, 0.0)):
    """Box on the hull: local Z = surface normal, local Y = hull axis projected on the tangent plane (QA v2: panels line up with the ship instead
    of the old random spin).  `off` is a local offset (x across, y along the hull, z along the normal).  `spin` is ignored (kept so the rng stream
    and therefore the container layout stay identical)."""
    n = V(normal).normalized()
    t = V((0, 1, 0)) - n * n.y
    if t.length < 0.25:
        t = V((1, 0, 0)) - n * n.x
    t = t.normalized()
    bx = t.cross(n)
    m = Matrix(((bx.x, t.x, n.x), (bx.y, t.y, n.y), (bx.z, t.z, n.z))).to_4x4()
    b = S.box(V(off), size, mat)
    bmesh.ops.transform(b, matrix=m, verts=b.verts)
    bmesh.ops.translate(b, vec=V(center), verts=b.verts)
    return b


def fit_across(loc, y, w):
    """Largest panel width across the hull that keeps the sagitta of the (curved) hull under ~0.12 m."""
    R = max(math.hypot(loc.x, loc.z - ZC(y)), 0.6)
    return min(w, 2.0 * math.sqrt(2.0 * R * 0.12))


def scatter(n, y0, y1, phis, kinds):
    global det
    for _ in range(n):
        y = rng.uniform(y0, y1)
        ph = rng.choice(phis) + rng.uniform(-14, 14)
        a = math.radians(ph)
        loc, nrm, idx, d = surf.bvh.ray_cast(V((0, y, ZC(y))), V((math.cos(a), 0, math.sin(a))), 400.0)
        if loc is None:
            continue
        kind = rng.choice(kinds)
        if kind == "plate":
            sz = (rng.uniform(1.2, 3.8), rng.uniform(1.2, 3.8), rng.uniform(0.25, 0.7))
            sz = (fit_across(loc, y, sz[0]), sz[1], sz[2])
            det = L.bm_merge(det, obox(loc + nrm * sz[2] * 0.4, sz, nrm, rng.choice((HULL, TRIM, DARK)), rng.uniform(0, 3.14)))
        elif kind == "vent":
            sz = (rng.uniform(1.0, 2.0), rng.uniform(1.0, 2.0), 0.5)
            sz = (fit_across(loc, y, sz[0]), sz[1], sz[2])
            det = L.bm_merge(det, obox(loc + nrm * 0.2, sz, nrm, DARK, rng.uniform(0, 3.14)))
            for k in range(3):
                det = L.bm_merge(det, obox(loc + nrm * 0.5, (sz[0] * 0.8, 0.12, 0.3), nrm, TRIM, rng.uniform(0, 0.0),
                                           off=(0.0, (k - 1) * sz[1] * 0.3, 0.0)))
        elif kind == "dome":
            r = rng.uniform(0.7, 1.6)
            det = L.bm_merge(det, S.uvsphere(loc + nrm * 0.1, r, scale=(1, 1, 0.6), u=8, v=4, mat=TRIM),
                             S.uvsphere(loc + nrm * (0.1 + r * 0.45), r * 0.4, scale=(1, 1, 0.8), u=6, v=4, mat=WIN))
        elif kind == "mast":
            h = rng.uniform(2.0, 5.0)
            det = L.bm_merge(det, S.cyl(loc, loc + nrm * h, 0.12, 0.06, segs=5, mat=DARK))


scatter(28, 20, 58, (45, 90, 135), ("plate", "plate", "vent", "dome", "mast"))
scatter(16, 20, 56, (10, 170), ("plate", "vent"))
scatter(20, -67, -45, (60, 90, 120), ("plate", "vent", "mast", "dome"))
scatter(14, 58, 68, (80, 100), ("plate", "mast"))
scatter(14, -36, 10, (90,), ("plate", "vent"))
# prow collar (accent ring) + docking spotlights
for yy, wd in ((56.0, 0.9), (59.0, 0.45)):
    hline([(yy, p) for p in range(0, 361, 6)], width=wd, lift=0.07, mat=ACC)
# spine cable tray
det = L.bm_merge(det, S.box((0, -14.0, 5.35), (1.6, 46.0, 0.5), TRIM), S.box((0, -14.0, 5.7), (0.5, 46.0, 0.3), DARK))

# ------------------------------------------------------------------------------------------------------------
# gantry frames + containers
# ------------------------------------------------------------------------------------------------------------
POSTS_Y = [11.0, -2.0, -15.0, -28.0, -41.0]
XS = 11.6
for sgn in (-1, 1):
    for yk in POSTS_Y:
        det = L.bm_merge(det, S.box((sgn * XS, yk, 0), (0.8, 0.8, 10.6), HULL))
        for z in (-4.9, 0.0, 4.9):
            det = L.bm_merge(det, S.box((sgn * (5.2 + XS) / 2.0, yk, z), (XS - 5.2, 0.6, 0.6), TRIM))
    for z in (-4.9, 4.9):
        det = L.bm_merge(det, S.box((sgn * XS, (POSTS_Y[0] + POSTS_Y[-1]) / 2, z), (0.6, POSTS_Y[0] - POSTS_Y[-1], 0.6), TRIM))
    for k in range(len(POSTS_Y) - 1):
        y0, y1 = POSTS_Y[k], POSTS_Y[k + 1]
        det = L.bm_merge(det, S.cyl(W(sgn * XS, y0, 4.9), W(sgn * XS, y1, -4.9), 0.16, 0.16, segs=5, mat=DARK),
                         S.cyl(W(sgn * XS, y0, -4.9), W(sgn * XS, y1, 4.9), 0.16, 0.16, segs=5, mat=DARK))

cb = bmesh.new()
CW, CH, CL = 2.6, 2.6, 12.0
containers = []
for sgn in (-1, 1):
    for k in range(len(POSTS_Y) - 1):
        yc = 0.5 * (POSTS_Y[k] + POSTS_Y[k + 1])
        for ci, xc in enumerate((6.65, 9.4)):
            for zr in (-2.75, 0.0, 2.75):
                if rng.random() < 0.10:
                    continue
                containers.append((sgn * xc, yc, zr, rng.randrange(6), ci))
# loose stacks on the aft deck
for (x, y) in ((-6.0, -56.0), (6.0, -56.0), (-6.0, -46.5), (6.0, -46.5)):
    for zr in (8.4 + 1.3, 8.4 + 3.9):
        if rng.random() < 0.8:
            containers.append((x, y, zr, rng.randrange(6), 9))
for (x, y, z, ci, outer) in containers:
    b = S.box((x, y, z), (CW, CL if outer != 9 else 8.0, CH), mat=ci)
    cb = L.bm_merge(cb, b)
    if outer == 1:                                      # corrugation ribs on the visible outer side
        sgn = 1 if x > 0 else -1
        for k in range(5):
            yy = y - 4.4 + k * 2.2
            cb = L.bm_merge(cb, S.box((x + sgn * (CW / 2 + 0.04), yy, z), (0.1, 0.35, CH * 0.92), ci))

# ------------------------------------------------------------------------------------------------------------
# bridge tower + head
# ------------------------------------------------------------------------------------------------------------
TX, TY = 0.0, -54.0
det = L.bm_merge(det, S.box((TX, TY, 8.4 + 8.0), (9.0, 11.0, 16.0), HULL, taper=(0.62, 0.7)))                 # tower shaft
det = L.bm_merge(det, S.box((TX, TY, 17.2), (12.5, 15.0, 1.4), TRIM))                                        # mid deck
det = L.bm_merge(det, S.box((TX, TY, 27.4), (19.0, 20.0, 6.0), HULL, taper=(0.84, 0.88)))                    # command head
det = L.bm_merge(det, S.box((TX, TY, 30.6), (14.0, 14.0, 1.0), DARK))
det = L.bm_merge(det, S.box((TX, TY + 10.1, 27.6), (17.0, 0.4, 3.0), DARK))                                   # forward window band
for k in range(15):
    det = L.bm_merge(det, S.box((TX - 7.0 + k * 1.0, TY + 10.4, 27.6 + (0.4 if k % 2 else 0.0)), (0.7, 0.1, 1.2 + (0.0 if k % 2 else 0.3)), WIN))
for sgn in (-1, 1):
    for k in range(9):
        det = L.bm_merge(det, S.box((sgn * 9.45, TY + 7.0 - k * 1.8, 27.6), (0.1, 1.0, 1.1), WIN))
    for k in range(5):
        det = L.bm_merge(det, S.box((sgn * 2.9, TY + 5.6 + 0.0, 10.8 + k * 1.8), (0.1, 0.1, 0.1), WIN))
# vertical lit slits on the tower front
for k in range(7):
    det = L.bm_merge(det, S.box((TX - 1.8 + (k % 3) * 1.8, TY + 5.6, 11.0 + (k // 3) * 3.2), (0.7, 0.1, 1.5), WIN))
# tower braces, deck lights, head side wings
for sgn in (-1, 1):
    det = L.bm_merge(det, S.cyl(W(sgn * 6.3, TY - 5.0, 8.4), W(sgn * 3.6, TY - 3.0, 17.0), 0.3, 0.3, segs=5, mat=TRIM),
                     S.cyl(W(sgn * 6.3, TY + 5.0, 8.4), W(sgn * 3.6, TY + 3.0, 17.0), 0.3, 0.3, segs=5, mat=TRIM),
                     S.box((sgn * 10.8, TY + 2.0, 27.4), (3.2, 10.0, 2.4), HULL, taper=(0.8, 0.9)),
                     S.box((sgn * 12.5, TY + 2.0, 27.4), (0.3, 8.0, 1.2), WIN))
    for k in range(6):
        det = L.bm_merge(det, S.box((sgn * 6.15, TY + 7.2 - k * 2.9, 17.9), (0.3, 0.5, 0.3), GLOW))
# masts, dish, beacon
det = L.bm_merge(det, S.cyl(W(-5.0, TY - 4.0, 30.8), W(-5.0, TY - 4.0, 40.0), 0.22, 0.12, segs=6, mat=DARK),
                 S.cyl(W(4.0, TY + 2.0, 30.8), W(4.0, TY + 2.0, 37.0), 0.18, 0.1, segs=6, mat=DARK),
                 S.cyl(W(0.0, TY, 30.8), W(0.0, TY, 33.6), 0.9, 0.7, segs=8, mat=TRIM),
                 S.dish(W(0.0, TY, 34.4), (0, 0.5, 1.0), 3.6, 1.1, segs=14, rings=3, mat=TRIM),
                 S.cyl(W(0.0, TY, 33.6), W(0.0, TY, 35.2), 0.12, 0.12, segs=5, mat=DARK))
det = L.bm_merge(det, S.box((-5.0, TY - 4.0, 40.3), (1.6, 0.2, 0.2), DARK), S.box((-5.0, TY - 4.0, 38.4), (2.4, 0.2, 0.2), DARK))
# aft engine-block details: heat sinks on top
for k in range(6):
    det = L.bm_merge(det, S.box((0.0, -64.5 + k * 1.1, 9.0), (10.0, 0.4, 1.2), TRIM))

# ------------------------------------------------------------------------------------------------------------
# radiators (command block) and fuel tanks (engine block)
# ------------------------------------------------------------------------------------------------------------
for sgn in (-1, 1):
    for (yy, ww) in ((24.0, 13.0), (39.0, 13.0)):
        det = L.bm_merge(det, S.box((sgn * 19.0, yy, 1.5), (0.35, ww, 12.0), HULL))
        det = L.bm_merge(det, S.box((sgn * 19.0, yy, 7.8), (0.7, ww + 0.4, 0.5), TRIM))
        det = L.bm_merge(det, S.box((sgn * 19.0, yy, -4.8), (0.7, ww + 0.4, 0.5), TRIM))
        det = L.bm_merge(det, S.box((sgn * 15.2, yy, 1.5), (7.5, 0.9, 0.9), TRIM))
        for k in range(1, 6):
            det = L.bm_merge(det, S.box((sgn * 19.0, yy - ww / 2 + k * ww / 6, 1.5), (0.45, 0.16, 12.0), DARK))
        det = L.bm_merge(det, S.box((sgn * 19.0, yy, 1.5), (0.45, ww, 0.16), DARK))
tanks = bmesh.new()
TANK_PROFILE = [(-64.0, 0.6), (-63.2, 2.0), (-61.5, 2.85), (-58.0, 3.0), (-38.0, 3.0), (-34.5, 2.85), (-33.0, 2.0), (-32.2, 0.6)]
for sgn in (-1, 1):
    S.revolve_y(tanks, TANK_PROFILE, segs=14, centre=(sgn * 17.2, -3.0), mats=[HULL] * 7, cap_first=True, cap_last=True)
    for yy in (-58.0, -48.0, -38.0):
        det = L.bm_merge(det, S.box((sgn * 14.2, yy, -3.0), (3.0, 1.0, 1.4), TRIM))
        # bands
    for yy in (-56.0, -52.0, -48.0, -44.0, -40.0):
        P_, N_ = [], []
        for k in range(25):
            a = TAU * k / 24
            n = V((math.cos(a), 0, math.sin(a)))
            P_.append(W(sgn * 17.2, yy, -3.0) + n * 3.0)
            N_.append(n)
        S.ribbon(tanks, P_, N_, 0.9, 0.06, ACC if yy in (-52.0, -44.0) else DARK)
bmesh.ops.recalc_face_normals(tanks, faces=[f for f in tanks.faces if f.material_index == HULL])
det = L.bm_merge(det, tanks)

# ------------------------------------------------------------------------------------------------------------
# engines
# ------------------------------------------------------------------------------------------------------------
E_DARK, E_METAL, E_HULL, E_GLOW = 0, 1, 2, 3
ENG_MATS = [M["dark"], M["trim"], M["hull"], M["glow"]]
eng = bmesh.new()
engines = []     # (x, z, scale)
engines.append((0.0, 0.5, 1.0))
for (x, z) in ((-8.8, -3.8), (8.8, -3.8), (-8.8, 4.8), (8.8, 4.8)):
    engines.append((x, z, 0.66))
EY0 = -69.5
glow_pos = []
for (x, z, sc) in engines:
    prof = [(0.0, 3.6), (0.8, 3.1), (2.2, 2.5), (4.0, 2.7), (6.0, 3.4), (7.8, 4.1), (8.1, 4.25), (8.15, 3.95), (6.5, 3.3), (4.4, 2.4), (2.6, 1.9),
            (2.5, 0.2)]
    pr = [(EY0 - t * sc, r * sc) for (t, r) in prof]
    S.revolve_y(eng, pr, segs=14, centre=(x, z), mats=[E_HULL, E_HULL, E_METAL, E_METAL, E_METAL, E_METAL, E_METAL, E_DARK, E_DARK, E_DARK, E_GLOW],
                cap_first=False, cap_last=True)
    glow_pos.append((x, EY0 - 8.1 * sc, z, sc))
    # gimbal ring + struts
    for k in range(6):
        a = TAU * k / 6
        eng = L.bm_merge(eng, S.box((x + math.cos(a) * 3.7 * sc, EY0 + 0.4, z + math.sin(a) * 3.7 * sc), (0.7 * sc, 1.2, 0.7 * sc), E_METAL))
bmesh.ops.recalc_face_normals(eng, faces=eng.faces)

# ------------------------------------------------------------------------------------------------------------
# finish objects
# ------------------------------------------------------------------------------------------------------------
hull_all = L.bm_merge(hull, det)
ob_hull = S.finish("Hull", hull_all, col, HULL_MATS, parent=root, prefix=PFX, smooth_deg=40)
ob_cont = S.finish("Containers", cb, col, CONT, parent=root, prefix=PFX, flat=True)
ob_eng = S.finish("Engines", eng, col, ENG_MATS, parent=root, prefix=PFX, smooth_deg=40)


def build_glow(sc):
    bm = bmesh.new()
    S.revolve_axis(bm, [(0, 3.3 * sc), (2.0 * sc, 3.0 * sc), (8 * sc, 1.9 * sc), (16 * sc, 0.8 * sc), (24 * sc, 0.1 * sc)], (0, 0, 0), (0, 0, -1), segs=12,
                   mats=0, cap_first=True)
    bm2 = bmesh.new()
    S.revolve_axis(bm2, [(0.1, 2.0 * sc), (2 * sc, 1.8 * sc), (6 * sc, 1.0 * sc), (11 * sc, 0.3 * sc), (14 * sc, 0.05 * sc)], (0, 0, 0), (0, 0, -1), segs=12,
                   mats=1, cap_first=True)
    for f in bm2.faces:
        f.material_index = 1
    bm = L.bm_merge(bm, bm2)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


glows = []
for n, (x, y, z, sc) in enumerate(glow_pos):
    g = S.finish("EngineGlow_%d" % n, build_glow(sc), col, [M["flame_o"], M["flame_i"]], parent=root, prefix=PFX, smooth_deg=80)
    g.location = V((x, y, z))
    g.rotation_euler = (-math.pi / 2, 0, 0)
    glows.append(g)


def nav(name, pos, mat, r=0.7):
    bm = S.uvsphere(pos, r, u=10, v=6, mat=0)
    return S.finish(name, bm, col, [mat], origin=pos, parent=root, prefix=PFX, flat=False, smooth_deg=80)


nav("NavLight_L", (-19.2, 24.0, 8.4), M["red"])
nav("NavLight_R", (19.2, 24.0, 8.4), M["green"])
nav("NavLight_Tail", (0.0, -69.9, 7.2), M["white"], 0.8)
nav("BlinkLight", (-5.0, TY - 4.0, 40.6), M["red"], 0.6)
nav("BlinkLight_2", (4.0, TY + 2.0, 37.3), M["red"], 0.5)

bpy.context.view_layer.update()
S.tri_report(root, MID)
if DO_PREVIEW:
    S.preview_set(root, MID + "_p", views=((35, 20), (145, 20), (0, 8), (90, 4), (0, 88), (200, -35)), size=(520, 400), dist_mult=1.1, ground=False)
if DO_EXPORT:
    path, names = S.export_named([root], MID, PFX)
    print("EXPORTED", path)
    print(names)
L.save_blend()
S.end(col)
