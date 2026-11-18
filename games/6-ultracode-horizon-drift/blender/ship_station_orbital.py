"""station_orbital -- orbital station ~217 m across.  Blender axes: station axis = Y (docking bay faces +Y).
Ring: separate object, origin at the hub centre, axis along Blender Y == Godot local Z  -> spin it with rotate_object_local(Vector3.BACK, a)
Nodes: Station > Hub, Ring, SolarPanels, NavLight_L/R, BlinkLight, Anchor_Dock (front docking port).
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
MID = "station_orbital"
PFX = MID + "__"
rng = random.Random(21)
DO_EXPORT = True
DO_PREVIEW = False


def W(x, y, z):
    return Vector((x, y, z))


M = {}
M["hull"] = L.mat(MID + "_hull", (0.62, 0.65, 0.70), metallic=0.3, roughness=0.5)
M["trim"] = L.mat(MID + "_trim", (0.33, 0.36, 0.42), metallic=0.5, roughness=0.45)
M["dark"] = L.mat(MID + "_dark", (0.04, 0.045, 0.055), metallic=0.5, roughness=0.5)
M["accent"] = L.mat(MID + "_accent", (0.05, 0.55, 0.62), metallic=0.2, roughness=0.4)
M["window"] = L.mat(MID + "_window", (1.0, 0.82, 0.5), emission=(1.0, 0.75, 0.38), emission_strength=2.6)
M["glow"] = L.mat(MID + "_glow", (0.1, 0.7, 1.0), emission=(0.08, 0.75, 1.0), emission_strength=5.0)
M["solar"] = L.mat(MID + "_solar", (0.03, 0.07, 0.24), metallic=0.75, roughness=0.28)
M["red"] = L.mat(MID + "_nav_red", (1.0, 0.05, 0.03), emission=(1.0, 0.05, 0.03), emission_strength=7.0)
M["green"] = L.mat(MID + "_nav_green", (0.05, 1.0, 0.15), emission=(0.05, 1.0, 0.15), emission_strength=7.0)
M["white"] = L.mat(MID + "_nav_white", (1.0, 1.0, 1.0), emission=(1.0, 0.97, 0.9), emission_strength=8.0)
HULL, TRIM, DARK, ACC, WIN, GLOW = 0, 1, 2, 3, 4, 5
MATS = [M["hull"], M["trim"], M["dark"], M["accent"], M["window"], M["glow"]]

col = L.fresh_collection(MID)
for o in list(bpy.data.objects):
    if o.name.startswith(PFX):
        bpy.data.objects.remove(o, do_unlink=True)
S.begin(col)
root = L.empty(PFX + "Station", col, (0, 0, 0), display="PLAIN_AXES", size=10.0)

# ------------------------------------------------------------------------------------------------------------
# RING  (rotates about Blender Y)
# ------------------------------------------------------------------------------------------------------------
RC, RA, RB = 102.0, 6.5, 9.0         # centreline radius, radial half depth, axial half width
NR, NM = 72, 12
ring = bmesh.new()
rings_pts = []
for k in range(NR):
    ph = TAU * k / NR
    cph, sph = math.cos(ph), math.sin(ph)
    pr = []
    for j in range(NM):
        ps = TAU * j / NM
        dr, dy = S.superellipse_pt(ps, RA, RB, 0.0, -RB, 3.4, 3.4)
        rho = RC + dr
        pr.append(V((rho * cph, dy, rho * sph)))
    rings_pts.append(pr)
rG, rF = S.grid_from_rings(ring, rings_pts + [rings_pts[0]], closed=True, mat=HULL)
for key, f in rF.items():
    if isinstance(key, tuple):
        k, j = key
        mod = (k // 3) % 2
        m = HULL if mod == 0 else TRIM
        if j in (5, 6):
            m = DARK if (k // 3) % 4 == 1 else TRIM
        f.material_index = m
bmesh.ops.remove_doubles(ring, verts=ring.verts, dist=1e-4)
bmesh.ops.recalc_face_normals(ring, faces=ring.faces)
# window rows
rdet = bmesh.new()
NWIN = 144
for k in range(NWIN):
    ph = TAU * (k + 0.5) / NWIN
    rad = V((math.cos(ph), 0, math.sin(ph)))
    tan_ = V((-math.sin(ph), 0, math.cos(ph)))
    lit = rng.random() > 0.12
    if not lit:
        continue
    for (yy, ny) in ((RB * 1.0 + 0.04, 1), (-RB - 0.04, -1)):
        for rho in (RC - 2.6, RC + 1.2):
            c = rad * rho + V((0, yy, 0))
            S.quad(rdet, c, V((0, ny, 0)), rad, 2.0 * math.pi * rho / NWIN * 0.62, 1.2, WIN)
    c = rad * (RC + RA + 0.04) + V((0, 3.0, 0))
    S.quad(rdet, c, rad, V((0, 1, 0)), 2.0 * math.pi * (RC + RA) / NWIN * 0.62, 1.0, WIN)
    c = rad * (RC + RA + 0.04) + V((0, -3.0, 0))
    S.quad(rdet, c, rad, V((0, 1, 0)), 2.0 * math.pi * (RC + RA) / NWIN * 0.62, 1.0, WIN)
# circumferential accent bands on the outer face
def torus_band(bm, rho, y, w, h, mat, n=NR):
    rings_ = []
    for k in range(n):
        ph = TAU * k / n
        cph, sph = math.cos(ph), math.sin(ph)
        rr = []
        for (dr, dy) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            rr.append(V(((rho + dr) * cph, y + dy, (rho + dr) * sph)))
        rings_.append(rr)
    rings_.append(rings_[0])
    G_, F_ = S.grid_from_rings(bm, rings_, closed=True, mat=mat)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    return bm


tb = bmesh.new()
torus_band(tb, RC + RA + 0.15, 0.0, 0.5, 1.6, ACC)
torus_band(tb, RC + RA * 0.55, RB + 0.2, 1.4, 0.7, TRIM)
torus_band(tb, RC + RA * 0.55, -RB - 0.2, 1.4, 0.7, TRIM)
torus_band(tb, RC - RA * 0.4, RB + 0.2, 0.9, 0.5, ACC)
torus_band(tb, RC - RA * 0.4, -RB - 0.2, 0.9, 0.5, ACC)
bmesh.ops.recalc_face_normals(tb, faces=tb.faces)
# module separators (dark radial ribs) and habitat pods on the outer face
rb = bmesh.new()
for k in range(0, NR, 6):
    ph = TAU * k / NR
    cph, sph = math.cos(ph), math.sin(ph)
    q = Matrix.Rotation(-ph, 4, "Y")
    b = S.box((0, 0, 0), (1.0, 2 * RB + 1.0, 1.0), DARK)
    bmesh.ops.transform(b, matrix=q, verts=b.verts)
    bmesh.ops.translate(b, vec=W((RC + RA) * cph, 0, (RC + RA) * sph), verts=b.verts)
    rb = L.bm_merge(rb, b)
for k in range(20):
    ph = rng.uniform(0, TAU)
    cph, sph = math.cos(ph), math.sin(ph)
    sz = (rng.uniform(3.5, 7.0), rng.uniform(3.0, 6.0), rng.uniform(1.5, 3.2))
    yo = rng.uniform(-4.5, 4.5)
    b = S.box((0, 0, 0), (sz[2], sz[1], sz[0]), rng.choice((HULL, TRIM, DARK)))
    bmesh.ops.transform(b, matrix=Matrix.Rotation(-ph, 4, "Y"), verts=b.verts)
    bmesh.ops.translate(b, vec=W((RC + RA + sz[2] / 2) * cph, yo, (RC + RA + sz[2] / 2) * sph), verts=b.verts)
    rb = L.bm_merge(rb, b)
    if rng.random() < 0.6:
        m = S.cyl(W((RC + RA + sz[2]) * cph, yo, (RC + RA + sz[2]) * sph), W((RC + RA + sz[2] + rng.uniform(2, 6)) * cph, yo,
                                                                          (RC + RA + sz[2] + rng.uniform(2, 6)) * sph), 0.18, 0.1, segs=5, mat=DARK)
        rb = L.bm_merge(rb, m)
# spokes (6) from hub collar to ring inner wall, with flanges
sp = bmesh.new()
for k in range(6):
    ph = TAU * k / 6 + math.radians(15)
    d = V((math.cos(ph), 0, math.sin(ph)))
    sp = L.bm_merge(sp, S.cyl(d * 20.0, d * (RC - RA + 0.6), 3.6, 3.2, segs=10, mat=TRIM),
                    S.cyl(d * 20.0, d * 27.0, 4.4, 4.4, segs=10, mat=ACC),
                    S.cyl(d * (RC - RA - 8.0), d * (RC - RA - 5.5), 4.4, 4.4, segs=10, mat=ACC))
    # window slits along the spoke
    for t in range(5):
        c = d * (36.0 + t * 11.0)
        S.quad(sp, c + W(0, 3.65, 0) * 0, V((0, 1, 0)), d, 1.4, 2.6, WIN, lift=3.62)
        S.quad(sp, c, V((0, -1, 0)), d, 1.4, 2.6, WIN, lift=3.62)
ring_all = L.bm_merge(ring, rdet, tb, rb, sp)
ob_ring = S.finish("Ring", ring_all, col, MATS, origin=(0, 0, 0), parent=root, prefix=PFX, smooth_deg=40)

# ------------------------------------------------------------------------------------------------------------
# HUB (stationary): fuselage-like body of revolution + collar + docking port + arms + antennas
# ------------------------------------------------------------------------------------------------------------
hub = bmesh.new()
HP = [(-62, 5.0), (-61, 8.5), (-57, 12.5), (-50, 15.0), (-38, 16.0), (-22, 16.0), (-14, 17.0), (-12, 19.5), (12, 19.5), (14, 17.0), (22, 16.0),
      (36, 16.0), (44, 14.5), (52, 11.5), (58, 9.8), (60.5, 9.8), (61.5, 9.0), (61.5, 7.2), (58.0, 6.8), (50.0, 6.8), (49.5, 0.05)]
HM = [TRIM, HULL, HULL, HULL, HULL, TRIM, HULL, TRIM, HULL, TRIM, HULL, HULL, HULL, HULL, TRIM, ACC, DARK, DARK, DARK, GLOW]
HM = [HULL, HULL, HULL, HULL, HULL, TRIM, TRIM, TRIM, TRIM, TRIM, HULL, HULL, HULL, HULL, TRIM, ACC, ACC, DARK, DARK, DARK]
S.revolve_y(hub, HP, segs=32, centre=(0, 0), mats=HM, cap_first=True, cap_last=True)
bmesh.ops.recalc_face_normals(hub, faces=hub.faces)
hub.faces.ensure_lookup_table()
hsurf = S.Surf(hub)
hd = bmesh.new()
# hub bands, window rows, collar details
for y in (-46.0, -30.0, -18.0, 22.0, 30.0, 40.0, 48.0):
    P_, N_ = [], []
    r = S.Mono([p[0] for p in HP[:16]], [p[1] for p in HP[:16]])(y)
    for k in range(33):
        a = TAU * k / 32
        n = V((math.cos(a), 0, math.sin(a)))
        P_.append(W(0, y, 0) + n * r)
        N_.append(n)
    S.ribbon(hd, P_, N_, 0.7, 0.06, DARK if y not in (30.0, -30.0) else ACC)
# window strips on the hub (two rings of lit windows)
rmono = S.Mono([p[0] for p in HP[:16]], [p[1] for p in HP[:16]])
for (y0, y1) in ((-9.0, 9.0),):
    pass
for yy in (-44.0, -36.0, 26.0, 34.0):
    r = rmono(yy)
    for k in range(40):
        a = TAU * (k + rng.random() * 0.5) / 40
        n = V((math.cos(a), 0, math.sin(a)))
        if rng.random() < 0.18:
            continue
        S.quad(hd, W(0, yy, 0) + n * (r + 0.05), n, V((0, 1, 0)), 1.9, 1.3, WIN)
# stationary bearing discs next to the ring
for yy in (-RB - 2.5, RB + 2.5):
    hd = L.bm_merge(hd, S.cyl(W(0, yy - 0.8, 0), W(0, yy + 0.8, 0), 22.0, 22.0, segs=32, mat=TRIM))
    for k in range(24):
        a = TAU * k / 24
        n = V((math.cos(a), 0, math.sin(a)))
        S.quad(hd, W(0, yy + (0.82 if yy > 0 else -0.82), 0) + n * 20.5, V((0, 1 if yy > 0 else -1, 0)), n, 1.2, 1.0, GLOW)
# docking port at the front: lit guide ring and strips
for k in range(16):
    a = TAU * k / 16
    n = V((math.cos(a), 0, math.sin(a)))
    S.quad(hd, W(0, 61.55, 0) + n * 8.1, V((0, 1, 0)), n, 0.9, 1.3, GLOW)
for k in range(8):
    a = TAU * k / 8
    n = V((math.cos(a), 0, math.sin(a)))
    hd = L.bm_merge(hd, S.cyl(W(0, 50.0, 0) + n * 6.6, W(0, 58.0, 0) + n * 6.6, 0.25, 0.25, segs=4, mat=TRIM))
# docking arms (4) angled forward with collars
arms = bmesh.new()
ARM_ENDS = []
for k in range(4):
    a = math.radians(45 + 90 * k)
    d = V((math.cos(a), 0.0, math.sin(a)))
    p0 = W(0, 30.0, 0) + d * 15.0
    dirv = (d + V((0, 0.55, 0))).normalized()
    p1 = p0 + dirv * 32.0
    arms = L.bm_merge(arms, S.cyl(p0 - dirv * 2.0, p1, 2.6, 2.3, segs=10, mat=HULL),
                      S.cyl(p0 - dirv * 1.0, p0 + dirv * 3.0, 3.6, 3.6, segs=10, mat=TRIM),
                      S.cyl(p0 + dirv * 15.0, p0 + dirv * 16.2, 3.0, 3.0, segs=10, mat=ACC))
    # collar (hollow look): dark disc + ring of lights
    pe = p1
    bm_c = bmesh.new()
    S.revolve_axis(bm_c, [(0.0, 3.4), (1.6, 3.4), (1.6, 2.7), (0.3, 2.4), (0.3, 0.05)], pe, pe + dirv * 2.0, segs=14, mats=[ACC, TRIM, DARK, DARK],
                   cap_first=True, cap_last=False)
    arms = L.bm_merge(arms, bm_c)
    ref = V((0, 1, 0)) if abs(dirv.y) < 0.9 else V((1, 0, 0))
    u_ = dirv.cross(ref).normalized()
    w_ = dirv.cross(u_).normalized()
    for t in range(8):
        aa = TAU * t / 8
        nn = u_ * math.cos(aa) + w_ * math.sin(aa)
        S.quad(arms, pe + dirv * 1.64 + nn * 3.05, dirv, nn, 0.5, 0.7, GLOW)
    ARM_ENDS.append(pe)
# antennas, dish
mast_base = W(0, -26.0, 16.0)
hd = L.bm_merge(hd, S.cyl(mast_base, mast_base + W(0, 0, 16.0), 0.9, 0.5, segs=8, mat=TRIM),
                S.dish(mast_base + W(0, 0, 17.0), (0, 0.45, 1.0), 7.5, 2.2, segs=18, rings=3, mat=HULL),
                S.cyl(mast_base + W(0, 0, 17.0), mast_base + W(0, 1.5, 23.0), 0.15, 0.1, segs=5, mat=DARK),
                S.cyl(W(0, 8.0, -19.0), W(0, 8.0, -34.0), 0.7, 0.4, segs=8, mat=TRIM),
                S.cyl(W(6.0, -20.0, 15.5), W(6.0, -20.0, 28.0), 0.25, 0.12, segs=5, mat=DARK),
                S.cyl(W(-6.0, -30.0, 15.0), W(-6.0, -30.0, 24.0), 0.25, 0.12, segs=5, mat=DARK))
# rear thrusters + radiator fins
for k in range(4):
    a = TAU * (k + 0.5) / 4
    d = V((math.cos(a), 0, math.sin(a)))
    bm_t = bmesh.new()
    S.revolve_axis(bm_t, [(0, 2.2), (1.0, 2.0), (3.0, 2.6), (3.2, 2.3), (1.5, 1.6), (1.4, 0.05)], W(0, -61.0, 0) + d * 5.5, W(0, -70.0, 0) + d * 5.5, segs=10,
                   mats=[TRIM, TRIM, DARK, DARK, GLOW], cap_first=True, cap_last=False)
    hd = L.bm_merge(hd, bm_t)
for sgn in (-1, 1):
    hd = L.bm_merge(hd, S.box((sgn * 12.0, -52.0, 0), (9.0, 14.0, 0.3), TRIM), S.box((sgn * 12.0, -52.0, 0), (8.6, 0.25, 1.0), DARK),
                    S.box((sgn * 12.0, -48.0, 0), (8.6, 0.25, 1.0), DARK), S.box((sgn * 12.0, -56.0, 0), (8.6, 0.25, 1.0), DARK))
hub_all = L.bm_merge(hub, hd, arms)
ob_hub = S.finish("Hub", hub_all, col, MATS, origin=(0, 0, 0), parent=root, prefix=PFX, smooth_deg=40)

# ------------------------------------------------------------------------------------------------------------
# SOLAR WINGS
# ------------------------------------------------------------------------------------------------------------
solar = bmesh.new()
SOL_MATS = [M["solar"], M["trim"], M["dark"]]
SY = -40.0
for sgn in (-1, 1):
    solar = L.bm_merge(solar, S.cyl(W(sgn * 12.0, SY, 0), W(sgn * 116.0, SY, 0), 1.3, 1.1, segs=8, mat=1))
    for sec in range(3):
        x0 = 20.0 + sec * 31.0
        xc = sgn * (x0 + 14.0)
        for dz in (-0.35, 0.35):
            solar = L.bm_merge(solar, S.box((xc, SY, dz), (27.0, 36.0, 0.25), 0))
        solar = L.bm_merge(solar, S.box((xc, SY, 0), (27.6, 36.6, 0.18), 1))
        for k in range(1, 6):                              # cell grid lines (dark thin boxes proud of the surface)
            solar = L.bm_merge(solar, S.box((xc - 13.5 + k * 27.0 / 6.0, SY, 0.5), (0.18, 35.6, 0.08), 2),
                               S.box((xc - 13.5 + k * 27.0 / 6.0, SY, -0.5), (0.18, 35.6, 0.08), 2))
        for k in range(1, 4):
            solar = L.bm_merge(solar, S.box((xc, SY - 18.0 + k * 9.0, 0.5), (26.8, 0.18, 0.08), 2),
                               S.box((xc, SY - 18.0 + k * 9.0, -0.5), (26.8, 0.18, 0.08), 2))
        solar = L.bm_merge(solar, S.box((xc, SY + 18.6, 0), (27.6, 1.0, 1.0), 1), S.box((xc, SY - 18.6, 0), (27.6, 1.0, 1.0), 1))
ob_solar = S.finish("SolarPanels", solar, col, SOL_MATS, origin=(0, 0, 0), parent=root, prefix=PFX, flat=True)


def nav(name, pos, mat, r=1.2):
    bm = S.uvsphere(pos, r, u=10, v=6, mat=0)
    return S.finish(name, bm, col, [mat], origin=pos, parent=root, prefix=PFX, flat=False, smooth_deg=80)


nav("NavLight_L", (-117.5, SY, 0), M["red"])
nav("NavLight_R", (117.5, SY, 0), M["green"])
nav("BlinkLight", mast_base + W(0, 1.5, 23.4), M["white"], 0.9)
L.empty(PFX + "Anchor_Dock", col, (0, 63.0, 0), parent=root, display="ARROWS", size=4.0)

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
