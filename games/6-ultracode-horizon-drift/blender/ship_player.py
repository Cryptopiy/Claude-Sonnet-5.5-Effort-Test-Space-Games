"""ship_player  --  "Wanderer" explorer shuttle (hero asset).   Run:  python tools/bmcp.py file blender/ship_player.py
Blender axes: +Y nose, +X right (starboard), Z up.  Origin = centre of mass.  ~13 m long, ~11 m span, ~4.3 m tall (incl. gear).
All geometry is procedural (bmesh).  Object names carry the prefix `ship_player__`; it is stripped from the glb node names.
"""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
import lib_common as L
import ship_lib as S
importlib.reload(L)
importlib.reload(S)
V = Vector
TAU = math.tau
MID = "ship_player"
PFX = MID + "__"
random.seed(11)
DO_EXPORT = True
DO_PREVIEW = False
PART = "all"     # "all" | "hull" (quick preview of the hull only)

# --------------------------------------------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------------------------------------------
M = {}
M["hull"] = L.mat(MID + "_hull", (0.66, 0.63, 0.58), metallic=0.12, roughness=0.42)
M["dark"] = L.mat(MID + "_dark", (0.055, 0.060, 0.070), metallic=0.45, roughness=0.5)
M["accent"] = L.mat(MID + "_accent", (0.95, 0.22, 0.02), metallic=0.1, roughness=0.38)
M["metal"] = L.mat(MID + "_metal", (0.36, 0.37, 0.40), metallic=0.7, roughness=0.36)
M["glow"] = L.mat(MID + "_glow", (0.1, 0.7, 1.0), emission=(0.08, 0.75, 1.0), emission_strength=5.0)
M["trim"] = L.mat(MID + "_trim", (0.40, 0.41, 0.44), metallic=0.3, roughness=0.5)
M["glass"] = L.mat(MID + "_glass", (0.25, 0.55, 0.85), metallic=0.0, roughness=0.05, alpha=0.35, specular=0.8)
M["screen_c"] = L.mat(MID + "_screen_cyan", (0.1, 0.7, 1.0), emission=(0.1, 0.8, 1.0), emission_strength=4.0)
M["screen_a"] = L.mat(MID + "_screen_amber", (1.0, 0.55, 0.1), emission=(1.0, 0.55, 0.1), emission_strength=3.5)
M["seat"] = L.mat(MID + "_seat", (0.10, 0.11, 0.13), metallic=0.0, roughness=0.8)
M["seat_acc"] = L.mat(MID + "_seat_accent", (0.85, 0.2, 0.03), metallic=0.0, roughness=0.7)
M["red"] = L.mat(MID + "_nav_red", (1.0, 0.05, 0.03), emission=(1.0, 0.05, 0.03), emission_strength=6.0)
M["green"] = L.mat(MID + "_nav_green", (0.05, 1.0, 0.15), emission=(0.05, 1.0, 0.15), emission_strength=6.0)
M["white"] = L.mat(MID + "_nav_white", (1.0, 1.0, 1.0), emission=(1.0, 0.97, 0.9), emission_strength=7.0)
M["flame_o"] = L.mat(MID + "_flame_outer", (0.05, 0.55, 1.0), emission=(0.05, 0.6, 1.0), emission_strength=3.0, alpha=0.45)
M["flame_i"] = L.mat(MID + "_flame_inner", (0.5, 0.9, 1.0), emission=(0.45, 0.9, 1.0), emission_strength=5.0)
HULL, DARK, ACC, METAL, GLOW, TRIM = 0, 1, 2, 3, 4, 5
HULL_MATS = [M["hull"], M["dark"], M["accent"], M["metal"], M["glow"], M["trim"]]

col = L.fresh_collection(MID)
for o in list(bpy.data.objects):          # stale objects of an earlier run of this script
    if o.name.startswith(PFX):
        bpy.data.objects.remove(o, do_unlink=True)

S.begin(col)
root = L.empty(PFX + "Ship", col, (0, 0, 0), display="PLAIN_AXES", size=1.0)

# --------------------------------------------------------------------------------------------------------------
# fuselage
# --------------------------------------------------------------------------------------------------------------
NSEG = 40
# (y, half width, z top, z widest, z bottom, n_top, n_bottom)
FKEYS = [
    (-5.45, 0.98, 0.52, -0.02, -0.50, 2.4, 3.2),
    (-4.80, 1.22, 0.74, -0.04, -0.66, 2.5, 3.4),
    (-3.60, 1.46, 0.90, -0.06, -0.80, 2.6, 3.6),
    (-1.80, 1.60, 0.95, -0.06, -0.88, 2.6, 3.8),
    (0.00, 1.62, 0.90, -0.06, -0.90, 2.6, 3.8),
    (1.60, 1.56, 0.84, -0.08, -0.90, 2.6, 3.8),
    (3.00, 1.34, 0.74, -0.10, -0.84, 2.5, 3.6),
    (4.20, 1.00, 0.58, -0.12, -0.68, 2.4, 3.2),
    (5.20, 0.68, 0.40, -0.12, -0.50, 2.3, 3.0),
    (6.00, 0.38, 0.22, -0.10, -0.30, 2.2, 2.6),
    (6.45, 0.15, 0.11, -0.07, -0.16, 2.1, 2.3),
    (6.65, 0.04, 0.04, -0.05, -0.08, 2.0, 2.0),
]
ks = sorted(FKEYS)
yk = [k[0] for k in ks]
FN = [S.Mono(yk, [k[i] for k in ks]) for i in range(1, 7)]


def fus_params(y):
    return [f(y) for f in FN]


def zc_fus(y):
    return FN[2](y)


# canopy plan outline (half width as a function of y)
CAN_Y0, CAN_Y1, CAN_W = 1.62, 4.88, 0.80


def canopy_w(y):
    t = (y - CAN_Y0) / (CAN_Y1 - CAN_Y0)
    if t <= 0 or t >= 1:
        return 0.0
    if t < 0.28:
        s = math.sqrt(max(0.0, 1 - ((0.28 - t) / 0.28) ** 2))
    else:
        s = (1 - (t - 0.28) / 0.72) ** 0.85
    return CAN_W * s


RING_YS = [6.65, 6.50, 6.30, 6.05, 5.75, 5.45, 5.15] + [4.95 - 0.14 * k for k in range(24)] +           [1.5, 1.25, 0.95, 0.60, 0.20, -0.20, -0.60, -1.0, -1.4, -1.8, -2.2, -2.6, -3.0, -3.4, -3.8, -4.2, -4.6, -5.0, -5.45]
FLOOR_Z = 0.36
NOSE_DARK_Y = 5.95
JA, JB = 7, 13                                       # columns of the cockpit opening (right / left edge)
TUB_FRAC = {7: 1.0, 8: 0.86, 9: 0.5, 10: 0.0, 11: -0.5, 12: -0.86, 13: -1.0}
TUB_MIN_W = 0.14


def z_top(x, hw, zt, zc, nt):
    u = min(abs(x) / hw, 0.9999)
    return zc + (zt - zc) * (1 - u ** nt) ** (1.0 / nt)


CAN_LOOP_R = []                                      # (y, x, z) right-hand opening boundary, filled by build_fuselage
TUB_FLAGS = []


def build_fuselage(bm):
    rings = []
    del TUB_FLAGS[:]
    for y in RING_YS:
        hw, zt, zc, zb, nt, nb = fus_params(y)
        w = canopy_w(y)
        tub = w > TUB_MIN_W
        TUB_FLAGS.append(tub)
        kd = S.smoothstep(TUB_MIN_W, 0.36, w)
        ring = []
        for j in range(NSEG):
            th = TAU * j / NSEG
            x, z = S.superellipse_pt(th, hw, zt, zc, zb, nt, nb)
            if tub and JA <= j <= JB:
                x = w * TUB_FRAC[j]
                zs = z_top(x, hw, zt, zc, nt)
                z = zs if j in (JA, JB) else S.lerp(zs, min(zs, FLOOR_Z), kd)
            ring.append(V((x, y, z)))
        rings.append(ring)
    G, F = S.grid_from_rings(bm, rings, closed=True, mat=HULL, cap_start=True, cap_end=True)
    del CAN_LOOP_R[:]
    for i in reversed(range(len(RING_YS))):                  # rear -> front
        if TUB_FLAGS[i]:
            p = G[i][JA].co
            CAN_LOOP_R.append(V((p.x, p.y, p.z)))
    for key, f in F.items():                      # colour zoning
        if key in ("cap0", "cap1"):
            f.material_index = DARK
            continue
        i, j = key
        y_mid = 0.5 * (RING_YS[i] + RING_YS[i + 1])
        m = HULL
        if 21 <= j <= 38:                         # belly
            m = DARK
        elif j in (2, 3, 16, 17) and -4.9 < y_mid < 5.2:   # flank accent stripe
            m = ACC
        if y_mid > NOSE_DARK_Y:
            m = DARK
        if TUB_FLAGS[i] and TUB_FLAGS[i + 1] and JA <= j < JB:     # cockpit tub
            m = TRIM if j in (JA, JB - 1) else DARK
        f.material_index = m
    return G, F


# --------------------------------------------------------------------------------------------------------------
# wings / fins
# --------------------------------------------------------------------------------------------------------------
def foil_loft(bm, sts, nchord=10, up_mat=HULL, lo_mat=DARK, cap0=True, cap1=True, flaps=False):
    rings = [S.foil_ring(s["le"], s["te"], s["up"], s["t"], nchord) for s in sts]
    G, F = S.grid_from_rings(bm, rings, closed=True, cap_start=cap0, cap_end=cap1)
    for key, f in F.items():
        if isinstance(key, tuple):
            f.material_index = up_mat if key[1] < nchord else lo_mat
            if key[1] in (nchord - 1, nchord):   # leading edge strip
                f.material_index = TRIM
            if flaps and key[0] >= 2 and key[1] < nchord:           # light-grey control surfaces on the upper side
                us = [(1 - math.cos(math.pi * k / nchord)) / 2 for k in range(nchord + 1)]
                j = key[1]
                if 0.5 * (us[nchord - j] + us[nchord - j - 1]) > 0.66:
                    f.material_index = TRIM
    return G, F


WING = [  # x, le_y, te_y, zc, thickness
    (0.80, 1.30, -4.75, -0.34, 0.60),
    (1.80, 0.30, -4.85, -0.30, 0.50),
    (3.00, -0.95, -4.80, -0.20, 0.36),
    (4.20, -2.10, -4.62, -0.07, 0.24),
    (5.20, -3.00, -4.45, 0.07, 0.15),
    (5.58, -3.32, -4.38, 0.13, 0.07),
]
WX = [w[0] for w in WING]
W_LE = S.Mono(WX, [w[1] for w in WING])
W_TE = S.Mono(WX, [w[2] for w in WING])


def build_wing(bm):
    sts = [dict(le=V((x, ly, z)), te=V((x, ty, z)), up=V((0, 0, 1)), t=t) for (x, ly, ty, z, t) in WING]
    return foil_loft(bm, sts, nchord=10, flaps=True)


FIN_CANT = math.radians(16)
FIN_X = 2.12


def build_fin(bm):
    s = V((math.sin(FIN_CANT), 0, math.cos(FIN_CANT)))
    n = V((math.cos(FIN_CANT), 0, -math.sin(FIN_CANT)))
    base = V((FIN_X, 0, 0.45))
    spec = [  # height, le_y, te_y, thick
        (0.00, -2.60, -6.05, 0.40),
        (0.70, -3.25, -6.10, 0.30),
        (1.40, -4.05, -6.15, 0.21),
        (1.95, -4.75, -6.18, 0.12),
        (2.10, -5.00, -6.18, 0.05),
    ]
    sts = []
    for (h, ly, ty, t) in spec:
        c = base + s * h
        sts.append(dict(le=V((c.x, ly, c.z)), te=V((c.x, ty, c.z)), up=n, t=t))
    G, F = foil_loft(bm, sts, nchord=8, up_mat=HULL, lo_mat=HULL)
    for key, f in F.items():
        if isinstance(key, tuple) and key[0] >= 2:
            f.material_index = ACC
    return G, F


# --------------------------------------------------------------------------------------------------------------
# assemble shells
# --------------------------------------------------------------------------------------------------------------
fus = bmesh.new()
build_fuselage(fus)
bmesh.ops.recalc_face_normals(fus, faces=fus.faces)
fus.faces.ensure_lookup_table()
surf_fus = S.Surf(fus)

wr = bmesh.new()
build_wing(wr)
bmesh.ops.recalc_face_normals(wr, faces=wr.faces)
wl = S.mirror_x(wr)
wboth = wr.copy()
wboth = L.bm_merge(wboth, wl.copy())
surf_wing = S.Surf(wboth)

fn = bmesh.new()
build_fin(fn)
bmesh.ops.recalc_face_normals(fn, faces=fn.faces)
fn_l = S.mirror_x(fn)

hull = bmesh.new()
hull = L.bm_merge(hull, fus.copy(), wr, wl, fn, fn_l)
bmesh.ops.recalc_face_normals(hull, faces=hull.faces)
surf_hull = S.Surf(hull)

det = bmesh.new()          # panel lines, greebles ... (merged into the Hull later)


# --------------------------------------------------------------------------------------------------------------
# panel lines on the fuselage (projected from the centre line)
# --------------------------------------------------------------------------------------------------------------
def canopy_zone(loc, pad=0.14):
    y = loc.y
    return CAN_Y0 - 0.1 < y < CAN_Y1 + 0.1 and abs(loc.x) < canopy_w(y) + pad and loc.z > 0.15


def fus_line(pts_param, width=0.026, lift=0.009, skip=canopy_zone, det_bm=None, force_mat=None):
    det_bm = det_bm or det
    st = {"p": [], "n": [], "m": None}

    def flush():
        if len(st["p"]) >= 2:
            S.ribbon(det_bm, st["p"], st["n"], width, lift, st["m"])
        st["p"], st["n"], st["m"] = [], [], None

    for (y, phi) in pts_param:
        a = math.radians(phi)
        loc, nrm, idx, d = surf_fus.bvh.ray_cast(V((0, y, zc_fus(y))), V((math.cos(a), 0, math.sin(a))), 50.0)
        if loc is None or (skip and skip(loc)):
            flush()
            continue
        mi = fus.faces[idx].material_index
        m = force_mat if force_mat is not None else (TRIM if mi in (DARK, METAL) else DARK)
        if st["m"] is not None and m != st["m"]:
            flush()
        st["m"] = m
        st["p"].append(loc)
        st["n"].append(nrm)
    flush()


def ring_line(y, phi0=0, phi1=360, step=5, **kw):
    n = int((phi1 - phi0) / step)
    fus_line([(y, phi0 + step * k) for k in range(n + 1)], **kw)


def long_line(phi, y0, y1, step=0.15, **kw):
    n = max(1, int(abs(y1 - y0) / step))
    fus_line([(y0 + (y1 - y0) * k / n, phi) for k in range(n + 1)], **kw)


def panel_yphi(y0, y1, p0, p1, ry=0.12, rp=6.0, per=3, **kw):
    pts = []
    corners = [(y1 - ry, p1 - rp, 0), (y0 + ry, p1 - rp, 90), (y0 + ry, p0 + rp, 180), (y1 - ry, p0 + rp, 270)]
    for (cy, cp, ang) in corners:
        for k in range(per + 1):
            t = math.radians(ang + 90.0 * k / per)
            pts.append((cy + ry * math.cos(t), cp + rp * math.sin(t)))
    fus_line(pts + [pts[0]], **kw)


for y in (5.35, 1.45, -0.55, -2.35, -4.25):
    ring_line(y)
ring_line(NOSE_DARK_Y, width=0.035, force_mat=TRIM)
for ph in (14, 166, 40, 140):
    long_line(ph, -4.85, 5.2, step=0.2, width=0.02)
for ph in (222, 318):
    long_line(ph, 3.4, -4.6, step=0.2, width=0.022)
for ph in (258, 282):
    long_line(ph, 2.6, -4.2, step=0.2, width=0.022)
# dorsal hatches + vents (behind the canopy)
panel_yphi(-1.55, -0.45, 62, 118, ry=0.1, rp=7, width=0.024)
panel_yphi(-3.25, -2.1, 64, 116, ry=0.1, rp=7, width=0.024)
for k in range(5):
    fus_line([(-2.95 + k * 0.17, 72), (-2.95 + k * 0.17, 108)], width=0.03, lift=0.008)
for k in range(4):
    fus_line([(-1.35 + k * 0.17, 76), (-1.35 + k * 0.17, 104)], width=0.03, lift=0.008)
# flank hatches
panel_yphi(-3.9, -2.75, -15, 18, ry=0.1, rp=6, width=0.024)
panel_yphi(-2.5, -1.2, -15, 18, ry=0.1, rp=6, width=0.024)
panel_yphi(-3.9, -2.75, 162, 195, ry=0.1, rp=6, width=0.024)
panel_yphi(-2.5, -1.2, 162, 195, ry=0.1, rp=6, width=0.024)
# right equipment hatch (mirror of the left door)
panel_yphi(0.75, 1.95, -20, 20, ry=0.15, rp=8, width=0.04)
# thin cyan light lines along the lower chine (fuselage flanks)
for ph in (-11, 191):
    long_line(ph, 3.6, -4.7, step=0.2, width=0.035, lift=0.008, force_mat=GLOW)
# belly: gear bays / hatches
panel_yphi(3.0, 3.8, 262, 278, ry=0.1, rp=3, width=0.03)
panel_yphi(-3.2, -1.9, 246, 294, ry=0.12, rp=8, width=0.03)

# --------------------------------------------------------------------------------------------------------------
# wing panel lines (right wing, then mirrored)
# --------------------------------------------------------------------------------------------------------------
det_w = bmesh.new()


def wing_pts(pairs, top):
    pts, nrs = [], []
    for (x, y) in pairs:
        if top:
            loc, nrm, idx, d = surf_wing.bvh.ray_cast(V((x, y, 6.0)), V((0, 0, -1)), 50.0)
        else:
            loc, nrm, idx, d = surf_wing.bvh.ray_cast(V((x, y, -6.0)), V((0, 0, 1)), 50.0)
        if loc is None:
            continue
        pts.append(loc)
        nrs.append(nrm)
    return pts, nrs


def wing_span_line(x0, x1, u0, u1=None, top=True, width=0.03, lift=0.009, mat=None, n=12):
    pairs = []
    for k in range(n + 1):
        t = k / n
        x = x0 + (x1 - x0) * t
        u = u0 if u1 is None else u0 + (u1 - u0) * t
        pairs.append((x, W_LE(x) + (W_TE(x) - W_LE(x)) * u))
    pts, nrs = wing_pts(pairs, top)
    if len(pts) >= 2:
        S.ribbon(det_w, pts, nrs, width, lift, ((TRIM if not top else DARK) if mat is None else mat))


def wing_chord_line(x, u0, u1, top=True, width=0.03, mat=None, n=6):
    pairs = []
    for k in range(n + 1):
        u = u0 + (u1 - u0) * k / n
        pairs.append((x, W_LE(x) + (W_TE(x) - W_LE(x)) * u))
    pts, nrs = wing_pts(pairs, top)
    if len(pts) >= 2:
        S.ribbon(det_w, pts, nrs, width, 0.009, ((TRIM if not top else DARK) if mat is None else mat))


for top in (True, False):
    wing_span_line(3.0, 5.3, 0.66, top=top)          # flap hinge line
    wing_span_line(2.9, 5.3, 0.16, top=top)          # slat line
    wing_chord_line(3.95, 0.66, 0.995, top=top)
    wing_chord_line(4.75, 0.66, 0.995, top=top)
    wing_chord_line(3.0, 0.16, 0.995, top=top)
wing_span_line(2.7, 5.15, 0.36, top=True, width=0.30, lift=0.004, mat=DARK)     # dark border under the stripe
wing_span_line(2.7, 5.15, 0.36, top=True, width=0.20, lift=0.009, mat=ACC)      # accent stripe on the wing
wing_span_line(3.1, 5.2, 0.90, top=False, width=0.05, lift=0.008, mat=GLOW)     # glowing trailing-edge strip, underside
# wing fences (small vertical plates on the upper surface)
for xf in (3.55, 4.55):
    ya = W_LE(xf) + (W_TE(xf) - W_LE(xf)) * 0.16
    yb = W_LE(xf) + (W_TE(xf) - W_LE(xf)) * 0.62
    la, na, _, _ = surf_wing.bvh.ray_cast(V((xf, ya, 6.0)), V((0, 0, -1)), 50.0)
    lb, nb_, _, _ = surf_wing.bvh.ray_cast(V((xf, yb, 6.0)), V((0, 0, -1)), 50.0)
    if la is not None and lb is not None:
        prof = [(ya, la.z - 0.01), (yb, lb.z - 0.01), (yb, lb.z + 0.09), (ya + 0.25, la.z + 0.17), (ya, la.z + 0.12)]
        det_w = L.bm_merge(det_w, S.prism_x(prof, xf - 0.02, xf + 0.02, TRIM))
det = L.bm_merge(det, det_w, S.mirror_x(det_w))


# --------------------------------------------------------------------------------------------------------------
# dorsal spine fairing, chin sensor, RCS blocks, wingtip pods ...
# --------------------------------------------------------------------------------------------------------------
def spine_w(y):
    t = (y + 5.15) / 4.75
    if t < 0 or t > 1:
        return 0.0
    return 0.25 * math.sin(math.pi * min(1.0, t * 1.05) ** 0.6) ** 0.6 + 0.02


def spine_h(y):
    t = (y + 5.15) / 4.75
    return 0.22 * (spine_w(y) / 0.27) ** 0.7 * (0.65 + 0.35 * t)


def orient_out(bm, ref_fn):
    for f in bm.faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(c - ref_fn(c)) < 0:
            f.normal_flip()


spine_ys = [-0.4 - 4.75 * k / 14 for k in range(15)]       # front -> rear
sp_bm = bmesh.new()
spG, spF = S.fairing(sp_bm, surf_fus, spine_ys, spine_w, spine_h, nseg=8, n_exp=2.2, skirt=0.04, mats=HULL)
orient_out(sp_bm, lambda c: V((0, c.y, 0.2)))
# accent line + panel line on the spine top
pts = [spG[i][4].co.copy() for i in range(1, 14)]
sp_bm.normal_update()
nrs = [spG[i][4].normal.copy() if spG[i][4].normal.length > 0.1 else V((0, 0, 1)) for i in range(1, 14)]
nrs = [n if n.z > 0 else -n for n in nrs]
S.ribbon(sp_bm, pts, nrs, 0.07, 0.006, ACC)
det = L.bm_merge(det, sp_bm)

# antenna blade behind the cockpit + tail light housing
ant = S.prism_y([(-0.03, 0.0), (0.03, 0.0), (0.012, 0.55), (-0.012, 0.55)], -5.15, -4.95, DARK)
ant_pts = S.cyl((0, -5.1, 0.55), (0, -5.1, 0.30), 0.012, 0.012, segs=6, mat=METAL)
det = L.bm_merge(det, ant)


def surface_x(y, z, side):
    """x of the fuselage skin at (y, z) seen from `side` (+1 right / -1 left)."""
    loc, nrm, idx, d = surf_fus.bvh.ray_cast(V((6.0 * side, y, z)), V((-side, 0, 0)), 50.0)
    return loc, nrm


# chin sensor pod under the nose
chin = S.uvsphere((0, 4.65, -0.52), 0.25, scale=(0.9, 1.6, 0.75), u=14, v=8, mat=DARK)
chin_lens = S.uvsphere((0, 5.02, -0.52), 0.075, scale=(1, 0.7, 1), u=8, v=6, mat=GLOW)
chin_mount = S.box((0, 4.45, -0.50), (0.2, 0.6, 0.14), TRIM)
det = L.bm_merge(det, chin, chin_lens, chin_mount)

# RCS blocks on the nose flanks and tail
for side in (-1, 1):
    for (yy, zz) in ((4.45, -0.05), (-5.2, 0.15)):
        loc, nrm = surface_x(yy, zz, side)
        if loc is None:
            continue
        blk = S.box((loc.x + 0.02 * side, yy, zz), (0.10, 0.42, 0.16), TRIM, rot=(0, 0, 0))
        n1 = S.cyl((loc.x + 0.06 * side, yy - 0.12, zz), (loc.x + 0.16 * side, yy - 0.12, zz), 0.045, 0.06, segs=8, mat=DARK)
        n2 = S.cyl((loc.x + 0.06 * side, yy + 0.12, zz), (loc.x + 0.16 * side, yy + 0.12, zz), 0.045, 0.06, segs=8, mat=DARK)
        det = L.bm_merge(det, blk, n1, n2)

# wingtip pods (right + mirrored)
pods = bmesh.new()
S.revolve_y(pods, [(-2.85, 0.03), (-2.95, 0.09), (-3.20, 0.13), (-4.0, 0.13), (-4.5, 0.09), (-4.62, 0.04)], segs=10,
            centre=(5.50, 0.125), mats=[METAL, METAL, METAL, METAL, DARK], cap_first=True, cap_last=True)
det = L.bm_merge(det, pods)
pods2 = bmesh.new()
S.revolve_y(pods2, [(-2.85, 0.03), (-2.95, 0.09), (-3.20, 0.13), (-4.0, 0.13), (-4.5, 0.09), (-4.62, 0.04)], segs=10,
            centre=(-5.50, 0.125), mats=[METAL, METAL, METAL, METAL, DARK], cap_first=True, cap_last=True)
det = L.bm_merge(det, pods2)

if PART == "all":
    exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender\ship_player_parts.py", encoding="utf-8").read())

hull_all = L.bm_merge(hull, det)
ob_hull = S.finish("Hull", hull_all, col, HULL_MATS, parent=root, prefix=PFX, smooth_deg=45)
print("HULL built")

bpy.context.view_layer.update()
S.tri_report(root, MID)
if DO_PREVIEW:
    S.preview_set(root, MID + "_p", views=((32, 18), (148, 18), (0, 10), (90, 4), (0, 88), (30, -40)), size=(520, 400), dist_mult=1.3,
                  ground=False)

if DO_EXPORT:
    path, names = S.export_named([root], "ship_player", PFX)
    print("EXPORTED", path)
    print(names)
L.save_blend()
S.end(col)
