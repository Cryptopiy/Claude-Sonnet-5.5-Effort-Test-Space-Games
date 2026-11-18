# exec()'d by ship_player.py (shares its globals).  Builds canopy, interior, engines, glows, gear, ramp door, lights, anchors.
def W(x, y, z):
    return Vector((x, y, z))


# NOTE: runs BEFORE the Hull object is finished; it appends detail geometry to the global bmesh `det`.

# ---------------------------------------------------------------------------------------------------------------
# canopy (glass bubble lofted from the cockpit opening) + frame ribs (into Hull)
# ---------------------------------------------------------------------------------------------------------------
def tip_pt(y):
    loc, nrm, idx, d = surf_fus.bvh.ray_cast(V((0, y, 5.0)), V((0, 0, -1)), 50.0)
    return V((0.0, y, loc.z if loc is not None else 0.7))


rl = CAN_LOOP_R
loop = [tip_pt(CAN_Y0 + 0.02)] + [p.copy() for p in rl] + [tip_pt(CAN_Y1 - 0.02)] + [V((-p.x, p.y, p.z)) for p in reversed(rl)]
NR = len(rl)
K_CAN, H_RIDGE, YA, YB, SKIRT = 9, 1.48, 2.40, 3.30, 0.05


def can_ring(m):
    a = math.pi / 2 * m / K_CAN
    s = math.cos(a)
    sn = math.sin(a)
    out = []
    for p in loop:
        yc = min(max(p.y, YA), YB)
        x = p.x * s
        y = yc + (p.y - yc) * s
        z = p.z + (H_RIDGE - p.z) * (sn ** 0.85)
        out.append(V((x, y, z)))
    return out


can_rings = [[V((p.x, p.y, p.z - SKIRT)) for p in loop]] + [can_ring(m) for m in range(K_CAN + 1)]
cn_bm = bmesh.new()
cnG, cnF = S.grid_from_rings(cn_bm, can_rings, closed=True, mat=0)
bmesh.ops.remove_doubles(cn_bm, verts=cn_bm.verts, dist=1e-4)
orient_out(cn_bm, lambda c: V((0, c.y, 0.3)))
cn_bm.normal_update()
RIB_POINTS = []      # (ring index m, loop index k) -> position helper
cring = lambda m, k: can_rings[1 + m][k]


def meridian(k, up=True):
    pts = [cring(m, k).copy() for m in range(K_CAN + 1)]
    nrm = []
    for m in range(K_CAN + 1):
        pp = pts[m]
        n = V((pp.x * 0.7, (pp.y - min(max(pp.y, YA), YB)) * 0.7, 1.0))
        nrm.append(n.normalized())
    return pts, nrm


# arch ribs (right meridian -> over the ridge -> left meridian)
for a_ in (3, 7, 11, 15, 19):
    if a_ >= NR:
        continue
    kr = 1 + a_
    kl = len(loop) - 1 - a_
    p1, n1 = meridian(kr)
    p2, n2 = meridian(kl)
    pts = p1 + list(reversed(p2))[1:]
    nrs = n1 + list(reversed(n2))[1:]
    S.ribbon(det, pts, nrs, 0.045, 0.012, DARK)
# centre rib: rear tip meridian -> ridge -> front tip meridian
p1, n1 = meridian(0)
p2, n2 = meridian(NR + 1)
pts = p1 + list(reversed(p2))
nrs = n1 + list(reversed(n2))
S.ribbon(det, pts, nrs, 0.04, 0.012, DARK)
# base frame ring (metal lip)
base_pts = [V((p.x, p.y, p.z + 0.012)) for p in loop]
base_nrm = [V((p.x * 0.5, (p.y - min(max(p.y, YA), YB)) * 0.3, 1.0)).normalized() for p in loop]
S.ribbon(det, base_pts, base_nrm, 0.085, 0.004, METAL, closed=True)
ob_canopy = S.finish("Canopy", cn_bm, col, [M["glass"]], parent=root, prefix=PFX, flat=False, smooth_deg=60)

# ---------------------------------------------------------------------------------------------------------------
# cockpit interior
# ---------------------------------------------------------------------------------------------------------------
I_DARK, I_SEAT, I_SEATACC, I_SCR_C, I_SCR_A, I_TRIM = 0, 1, 2, 3, 4, 5
INT_MATS = [M["dark"], M["seat"], M["seat_acc"], M["screen_c"], M["screen_a"], M["trim"]]
ib = bmesh.new()
rot_back = math.radians(12)
# pilot seat
parts = [
    S.box((0, 2.50, 0.50), (0.50, 0.56, 0.14), I_SEAT),                                     # cushion
    S.box((-0.285, 2.50, 0.58), (0.07, 0.50, 0.20), I_SEAT),                                # bolsters
    S.box((0.285, 2.50, 0.58), (0.07, 0.50, 0.20), I_SEAT),
    S.box((0, 2.16, 0.95), (0.52, 0.14, 0.82), I_SEAT, rot=(rot_back, 0, 0)),               # backrest
    S.box((0, 2.225, 0.98), (0.14, 0.03, 0.70), I_SEATACC, rot=(rot_back, 0, 0)),           # accent stripe
    S.box((0, 2.05, 1.24), (0.30, 0.12, 0.22), I_SEAT, rot=(rot_back, 0, 0)),               # headrest
    S.cyl((0, 2.45, 0.36), (0, 2.45, 0.44), 0.14, 0.11, segs=10, mat=I_DARK),               # pedestal
    S.box((-0.15, 2.32, 0.88), (0.04, 0.02, 0.62), I_SEATACC, rot=(rot_back, 0, math.radians(-8))),   # harness
    S.box((0.15, 2.32, 0.88), (0.04, 0.02, 0.62), I_SEATACC, rot=(rot_back, 0, math.radians(8))),
]
# armrests + sticks
parts += [
    S.box((-0.40, 2.62, 0.74), (0.12, 0.62, 0.07), I_DARK),
    S.box((0.40, 2.62, 0.74), (0.12, 0.62, 0.07), I_DARK),
    S.cyl((0.40, 2.82, 0.76), (0.40, 2.86, 1.02), 0.022, 0.018, segs=8, mat=I_TRIM),            # flight stick
    S.box((0.40, 2.87, 1.06), (0.06, 0.07, 0.11), I_DARK, rot=(math.radians(-10), 0, 0)),
    S.box((0.40, 2.90, 1.08), (0.03, 0.015, 0.03), I_SCR_A),
    S.cyl((-0.40, 2.82, 0.76), (-0.40, 2.78, 0.96), 0.022, 0.02, segs=8, mat=I_TRIM),            # throttle
    S.box((-0.40, 2.77, 0.99), (0.05, 0.10, 0.06), I_DARK),
]
# dashboard console
dash = S.prism_x([(3.10, 0.34), (3.10, 0.58), (3.38, 0.80), (3.75, 0.78), (3.80, 0.60), (3.80, 0.34)], -0.34, 0.34, I_DARK)
parts.append(dash)
slope = math.atan2(0.80 - 0.58, 3.38 - 3.10)         # face slope angle about X
ny, nz = -math.sin(slope), math.cos(slope)


def scr(cx, w, h, mat, off=0.012):
    t = 0.5
    y = 3.10 + 0.28 * t
    z = 0.58 + 0.22 * t
    return S.box((cx, y + ny * off, z + nz * off), (w, 0.012, h), mat, rot=(slope - math.pi / 2, 0, 0))


parts.append(scr(0.0, 0.30, 0.15, I_SCR_C))
parts.append(scr(-0.21, 0.13, 0.12, I_SCR_A))
parts.append(scr(0.21, 0.13, 0.12, I_SCR_C))
parts.append(S.box((0, 3.58, 0.805), (0.50, 0.10, 0.02), I_SCR_C))       # upper strip display
for k in range(5):
    parts.append(S.box((-0.20 + 0.10 * k, 3.17, 0.545), (0.05, 0.03, 0.02), I_SCR_A if k % 2 else I_SCR_C))
# rear bulkhead + side consoles
parts += [
    S.box((0, 1.90, 0.66), (0.78, 0.07, 0.62), I_DARK),
    S.box((0, 1.935, 0.80), (0.5, 0.012, 0.05), I_SCR_C),
    S.box((-0.58, 3.05, 0.45), (0.14, 0.9, 0.20), I_DARK),
    S.box((0.58, 3.05, 0.45), (0.14, 0.9, 0.20), I_DARK),
    S.box((-0.58, 3.05, 0.555), (0.05, 0.5, 0.012), I_SCR_A),
    S.box((0.58, 3.05, 0.555), (0.05, 0.5, 0.012), I_SCR_C),
    S.box((0, 2.9, 0.37), (0.62, 1.7, 0.03), I_TRIM),                    # floor plate
]
ib = L.bm_merge(*parts)
bmesh.ops.recalc_face_normals(ib, faces=ib.faces)
ob_int = S.finish("CockpitInterior", ib, col, INT_MATS, parent=root, prefix=PFX, smooth_deg=40)

# ---------------------------------------------------------------------------------------------------------------
# engines (right side built in world coords, left mirrored)
# ---------------------------------------------------------------------------------------------------------------
ENG_X, ENG_Z, EXIT_Y = 1.95, 0.02, -6.45
ENG_PROFILE = [(-1.10, 0.10), (-1.16, 0.30), (-1.30, 0.50), (-1.55, 0.66), (-1.90, 0.76), (-2.40, 0.83), (-3.00, 0.86), (-3.60, 0.86),
               (-4.30, 0.84), (-4.90, 0.78), (-5.40, 0.70), (-5.75, 0.64), (-6.05, 0.68), (-6.30, 0.76), (-6.45, 0.80), (-6.47, 0.74),
               (-6.25, 0.64), (-6.00, 0.54), (-5.82, 0.50), (-5.80, 0.05)]
ENG_MATS = [DARK, DARK, DARK, HULL, HULL, HULL, ACC, HULL, HULL, TRIM, METAL, METAL, METAL, METAL, TRIM, DARK, DARK, DARK, GLOW]


def build_engine():
    bm = bmesh.new()
    S.revolve_y(bm, ENG_PROFILE, segs=28, centre=(ENG_X, ENG_Z), mats=ENG_MATS, cap_first=True, cap_last=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ys_r = list(reversed([p[0] for p in ENG_PROFILE[:14]]))
    rs_r = list(reversed([p[1] for p in ENG_PROFILE[:14]]))
    rfun = S.Mono(ys_r, rs_r)
    seg_n = 48
    for (y, wdt, mat) in ((-1.75, 0.04, DARK), (-2.95, 0.035, DARK), (-3.65, 0.035, DARK), (-4.30, 0.05, DARK), (-4.46, 0.05, DARK),
                          (-4.62, 0.05, DARK), (-4.78, 0.05, DARK), (-5.45, 0.06, GLOW)):
        r = rfun(y)
        P_, N_ = [], []
        for k in range(seg_n + 1):
            a = TAU * k / seg_n
            n = V((math.cos(a), 0, math.sin(a)))
            P_.append(V((ENG_X, y, ENG_Z)) + n * r)
            N_.append(n)
        S.ribbon(bm, P_, N_, wdt, 0.012, mat)
    for k in range(10):                                   # longitudinal seams
        a = TAU * (k + 0.5) / 10
        n = V((math.cos(a), 0, math.sin(a)))
        P_, N_ = [], []
        for y in (-1.8, -2.3, -2.9, -3.7, -4.2):
            P_.append(V((ENG_X, y, ENG_Z)) + n * rfun(y))
            N_.append(n)
        S.ribbon(bm, P_, N_, 0.02, 0.01, DARK)
    # inner core spokes (dark) in front of the glow plate
    for k in range(6):
        a = TAU * k / 6
        n = V((math.cos(a), 0, math.sin(a)))
        p0 = V((ENG_X, -5.80, ENG_Z)) + n * 0.06
        p1 = V((ENG_X, -5.80, ENG_Z)) + n * 0.50
        S.ribbon(bm, [p0, p1], [V((0, -1, 0)), V((0, -1, 0))], 0.035, 0.012, DARK)
    return bm


engR = build_engine()
engL = S.mirror_x(engR)
ob_engR = S.finish("Engine_R", engR, col, HULL_MATS, origin=(ENG_X, EXIT_Y, ENG_Z), parent=root, prefix=PFX, smooth_deg=40)
ob_engL = S.finish("Engine_L", engL, col, HULL_MATS, origin=(-ENG_X, EXIT_Y, ENG_Z), parent=root, prefix=PFX, smooth_deg=40)

# ---------------------------------------------------------------------------------------------------------------
# engine glow cones: origin on the nozzle exit plane, long axis = local -Y in Godot (= local -Z in Blender, object rotated -90 deg about X)
# ---------------------------------------------------------------------------------------------------------------
def build_glow():
    bm = bmesh.new()
    S.revolve_axis(bm, [(0, 0.60), (0.3, 0.55), (1.0, 0.35), (2.0, 0.15), (2.8, 0.015)], (0, 0, 0), (0, 0, -1), segs=16,
                   mats=0, cap_first=True)
    set_m = lambda b, i: [setattr(f, "material_index", i) for f in b.faces]
    set_m(bm, 0)
    bm2 = bmesh.new()
    S.revolve_axis(bm2, [(0.02, 0.36), (0.3, 0.32), (0.8, 0.18), (1.5, 0.05), (1.9, 0.01)], (0, 0, 0), (0, 0, -1), segs=16, mats=1, cap_first=True)
    set_m(bm2, 1)
    bm = L.bm_merge(bm, bm2)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


ob_glowR = S.finish("EngineGlow_R", build_glow(), col, [M["flame_o"], M["flame_i"]], parent=root, prefix=PFX, smooth_deg=80)
ob_glowR.location = V((ENG_X, EXIT_Y, ENG_Z))
ob_glowR.rotation_euler = (-math.pi / 2, 0, 0)
ob_glowL = S.finish("EngineGlow_L", build_glow(), col, [M["flame_o"], M["flame_i"]], parent=root, prefix=PFX, smooth_deg=80)
ob_glowL.location = V((-ENG_X, EXIT_Y, ENG_Z))
ob_glowL.rotation_euler = (-math.pi / 2, 0, 0)

# ---------------------------------------------------------------------------------------------------------------
# nav lights
# ---------------------------------------------------------------------------------------------------------------
def nav(name, pos, mat, r=0.095):
    bm = S.uvsphere(pos, r, u=10, v=6, mat=0)
    return S.finish(name, bm, col, [mat], origin=pos, parent=root, prefix=PFX, flat=False, smooth_deg=80)


ob_navL = nav("NavLight_L", (-5.69, -3.85, 0.125), M["red"])
ob_navR = nav("NavLight_R", (5.69, -3.85, 0.125), M["green"])
ob_navT = nav("NavLight_Tail", (0, -5.55, 0.22), M["white"], r=0.085)
# little housing for the tail light
det = L.bm_merge(det, S.box((0, -5.42, 0.18), (0.26, 0.10, 0.16), METAL))

# ---------------------------------------------------------------------------------------------------------------
# landing gear (deployed pose).  Objects are modelled in world coordinates, origin = hinge.
# ---------------------------------------------------------------------------------------------------------------
G_METAL, G_DARK, G_ACC, G_TRIM = 0, 1, 2, 3
GEAR_MATS = [M["metal"], M["dark"], M["accent"], M["trim"]]


def foot_pad(cx, cy, z_bottom, mat_main=G_DARK):
    bm = bmesh.new()
    S.revolve_axis(bm, [(0.0, 0.30), (0.02, 0.36), (0.085, 0.36), (0.12, 0.32), (0.17, 0.18), (0.23, 0.12)], (cx, cy, z_bottom),
                   (cx, cy, z_bottom + 1), segs=20, mats=[G_DARK, G_DARK, G_ACC, G_METAL, G_METAL], cap_first=True, cap_last=True)
    return bm


def build_front_gear():
    H = V((0, 3.35, -0.50))
    zc = -1.90
    parts = [
        S.cyl(H + W(0, 0, 0.12), H + W(0, 0.03, -0.42), 0.17, 0.15, segs=12, mat=G_DARK),
        S.cyl(H + W(0, 0.03, -0.30), H + W(0, 0.08, -0.88), 0.115, 0.095, segs=12, mat=G_METAL),
        S.cyl(H + W(0, 0.07, -0.84), H + W(0, 0.16, -1.30), 0.065, 0.065, segs=10, mat=G_TRIM),
        S.cyl(H + W(0, 0.07, -0.78), H + W(0, 0.07, -0.90), 0.135, 0.135, segs=12, mat=G_ACC),            # collar
        S.cyl(H + W(0.0, -0.42, -0.18), H + W(0.0, 0.07, -0.76), 0.042, 0.042, segs=8, mat=G_DARK),      # drag brace
        S.cyl(H + W(0.07, 0.0, -0.45), H + W(0.07, 0.15, -1.2), 0.014, 0.014, segs=6, mat=G_ACC),       # hose
        S.box(H + W(-0.09, 0.16, -1.29), (0.03, 0.17, 0.22), G_METAL),                                 # fork plates (bottom = pad bottom = -1.90, QA fix)
        S.box(H + W(0.09, 0.16, -1.29), (0.03, 0.17, 0.22), G_METAL),
        foot_pad(0, 3.35 + 0.16, zc + 0.0),
    ]
    bm = L.bm_merge(*parts)
    return bm, H


def build_side_gear():
    H = W(3.10, -2.30, -0.12)
    parts = [
        S.cyl(H + W(0, 0, 0.1), H + W(0.05, 0, -0.45), 0.19, 0.17, segs=12, mat=G_DARK),
        S.cyl(H + W(0.05, 0, -0.35), H + W(0.14, 0, -1.02), 0.13, 0.108, segs=12, mat=G_METAL),
        S.cyl(H + W(0.14, 0, -0.98), H + W(0.20, 0, -1.55), 0.075, 0.075, segs=10, mat=G_TRIM),
        S.cyl(H + W(0.15, 0, -0.95), H + W(0.15, 0, -1.07), 0.15, 0.15, segs=12, mat=G_ACC),
        S.cyl(H + W(-0.62, 0.0, -0.40), H + W(0.15, 0, -1.04), 0.045, 0.045, segs=8, mat=G_DARK),        # side brace
        S.cyl(H + W(0.02, -0.75, -0.40), H + W(0.14, 0.0, -1.1), 0.04, 0.04, segs=8, mat=G_DARK),         # drag brace
        S.cyl(H + W(0.08, 0.06, -0.45), H + W(0.21, 0.06, -1.45), 0.014, 0.014, segs=6, mat=G_ACC),
        S.box(H + W(0.20, -0.09, -1.62), (0.17, 0.03, 0.22), G_METAL),
        S.box(H + W(0.20, 0.09, -1.62), (0.17, 0.03, 0.22), G_METAL),
        foot_pad(H.x + 0.20, H.y, -1.90),
    ]
    bm = L.bm_merge(*parts)
    return bm, H


bmF, HF = build_front_gear()
ob_gF = S.finish("Gear_Front", bmF, col, GEAR_MATS, origin=HF, parent=root, prefix=PFX, smooth_deg=40)
bmGR, HR = build_side_gear()
bmGL = S.mirror_x(bmGR)
ob_gR = S.finish("Gear_R", bmGR, col, GEAR_MATS, origin=HR, parent=root, prefix=PFX, smooth_deg=40)
ob_gL = S.finish("Gear_L", bmGL, col, GEAR_MATS, origin=W(-HR.x, HR.y, HR.z), parent=root, prefix=PFX, smooth_deg=40)

# ---------------------------------------------------------------------------------------------------------------
# left boarding door / ramp (hinge = bottom edge, local Blender Y axis)
# ---------------------------------------------------------------------------------------------------------------
DZ = [-0.55, -0.30, -0.05, 0.20, 0.50]
DY = [0.78, 1.07, 1.36, 1.65, 1.94]
Pg, Ng = [], []
for z in DZ:
    rowP, rowN = [], []
    for y in DY:
        loc, nrm, idx, d = surf_fus.bvh.ray_cast(V((-6.0, y, z)), V((1, 0, 0)), 50.0)
        rowP.append(loc)
        rowN.append(nrm)
    Pg.append(rowP)
    Ng.append(rowN)
door = bmesh.new()
S.slab_from_grid(door, Pg, Ng, 0.022, 0.03, mat_out=HULL, mat_in=DARK, mat_edge=TRIM)
bmesh.ops.recalc_face_normals(door, faces=door.faces)
# frame (outer face) + handle
border = [Pg[0][c] for c in range(5)] + [Pg[r][4] for r in range(1, 5)] + [Pg[4][c] for c in range(3, -1, -1)] + [Pg[r][0] for r in range(3, 0, -1)]
bnorm = [Ng[0][c] for c in range(5)] + [Ng[r][4] for r in range(1, 5)] + [Ng[4][c] for c in range(3, -1, -1)] + [Ng[r][0] for r in range(3, 0, -1)]
cen = W(0, 0, 0)
for p_ in border:
    cen += p_
cen /= len(border)
inset = [p_ + (cen - p_).normalized() * 0.05 for p_ in border]
S.ribbon(door, inset, bnorm, 0.06, 0.03, 2, closed=True)
for r in (1, 2, 3):                                               # treads on the inner face
    P_ = [Pg[r][c] - Ng[r][c] * 0.034 for c in range(5)]
    N_ = [-Ng[r][c] for c in range(5)]
    S.ribbon(door, P_, N_, 0.07, 0.003, 5)
hx = Pg[2][3] + Ng[2][3] * 0.03
hnd = S.box((hx.x - 0.02, hx.y, hx.z), (0.05, 0.22, 0.05), 3)
lock = S.box((hx.x - 0.025, Pg[3][3].y, Pg[3][3].z + 0.02), (0.03, 0.05, 0.05), 4)
door = L.bm_merge(door, hnd, lock)
DOOR_ORIGIN = V((sum(Pg[0][c].x for c in range(5)) / 5.0 - 0.0, 1.36, DZ[0]))
ob_door = S.finish("RampDoor", door, col, HULL_MATS, origin=DOOR_ORIGIN, parent=root, prefix=PFX, smooth_deg=40)
# door recess on the hull (dark panel with glowing frame, visible when the door is open)
rec = bmesh.new()
rP, rN = [], []
for r in range(len(DZ)):
    rowP = [Pg[r][c] + Ng[r][c] * 0.004 for c in range(5)]
    rP.append(rowP)
    rN.append([Ng[r][c] for c in range(5)])
for r in range(len(DZ) - 1):
    for c in range(4):
        f = rec.faces.new((rec.verts.new(rP[r][c]), rec.verts.new(rP[r][c + 1]), rec.verts.new(rP[r + 1][c + 1]), rec.verts.new(rP[r + 1][c])))
        f.material_index = DARK
        f.normal_update()
        if f.normal.dot(rN[r][c]) < 0:
            f.normal_flip()
det = L.bm_merge(det, rec)

# ---------------------------------------------------------------------------------------------------------------
# tail cap details (seen in the chase camera): heat-exchanger slits, frame, sensor dome on the back
# ---------------------------------------------------------------------------------------------------------------
cap_y = -5.46
for k, (zz, ww) in enumerate(((-0.30, 0.50), (-0.18, 0.66), (-0.06, 0.74), (0.06, 0.74), (0.18, 0.66), (0.30, 0.50))):
    det = L.bm_merge(det, S.box((0, cap_y - 0.012, zz), (ww, 0.03, 0.035), GLOW))
fr_pts = [V((0.80 * math.cos(TAU * k / 40), cap_y - 0.004, -0.02 + 0.44 * math.sin(TAU * k / 40))) for k in range(41)]
S.ribbon(det, fr_pts, [V((0, -1, 0))] * len(fr_pts), 0.045, 0.004, TRIM, closed=False)
for sx in (-1, 1):
    det = L.bm_merge(det, S.box((0.5 * sx, cap_y - 0.02, 0.38), (0.12, 0.04, 0.09), METAL))
# sensor domes on the back
for (yy, rr) in ((0.30, 0.16), (-0.1, 0.11)):
    loc, nrm, idx, d = surf_fus.bvh.ray_cast(V((0.0, yy, 5.0)), V((0, 0, -1)), 50.0)
    if loc is not None:
        det = L.bm_merge(det, S.uvsphere((0, yy, loc.z + 0.01), rr, scale=(1, 1, 0.55), u=12, v=6, mat=DARK),
                         S.uvsphere((0, yy + rr * 0.45, loc.z + 0.04), rr * 0.35, scale=(1, 0.5, 0.7), u=8, v=4, mat=GLOW))

# ---------------------------------------------------------------------------------------------------------------
# anchors
# ---------------------------------------------------------------------------------------------------------------
def anchor(name, loc, size=0.35, display="ARROWS"):
    return L.empty(PFX + name, col, loc, parent=root, display=display, size=size)


anchor("Anchor_ChaseCam", (0, -16.0, 4.5), 0.6)
anchor("Anchor_Cockpit", (0, 2.75, 1.15), 0.2, "SPHERE")
anchor("Anchor_Exit", (-3.3, 1.36, -1.90), 0.4)
anchor("Anchor_GearContact_Front", (0, 3.35 + 0.16, -1.90), 0.25)
anchor("Anchor_GearContact_L", (-HR.x - 0.20, HR.y, -1.90), 0.25)
anchor("Anchor_GearContact_R", (HR.x + 0.20, HR.y, -1.90), 0.25)
anchor("Anchor_Engine_L", (-ENG_X, EXIT_Y - 0.35, ENG_Z), 0.25)
anchor("Anchor_Engine_R", (ENG_X, EXIT_Y - 0.35, ENG_Z), 0.25)
