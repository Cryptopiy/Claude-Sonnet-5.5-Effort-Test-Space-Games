"""ship_explorer - hero spaceship.  Re-runnable: rebuilds the collection `ship_explorer` from scratch.
Blender axes: nose = +Y, up = +Z, ship's right = +X (left = -X).  Origin = centre of the ship.
Landing gear legs hang straight down (= extended).  To retract: rotate each Gear_* node about its X axis by -90 deg
(Blender and Godot X axes coincide): the foot swings towards the tail (-Y Blender / +Z Godot) and up into the hull.
"""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Emissive_Beacon', '#FFC070', rough=0.4, emit='#FF9A10', emit_strength=6.0)
COLL_NAME = "ship_explorer"
coll = fresh_collection(COLL_NAME)

# ------------------------------------------------------------------------------------------------
# key dimensions
# ------------------------------------------------------------------------------------------------
Y_NOSE, Y_TAIL = 7.0, -6.3
GROUND_Z = -3.0             # ground-contact plane (belly 1.6 m above ground, belly z = -1.4)
NC = 48                     # columns around the fuselage
Y_N0 = 3.9                  # where the nose cone starts
Y_CAP = 5.85                # nose cap groove

_ky = [-6.3, -5.6, -4.2, -2.2, -0.2, 1.6, 3.0, Y_N0]
_W = pchip(_ky, [1.38, 1.50, 1.60, 1.70, 1.82, 1.90, 1.84, 1.74])
_ZT = pchip(_ky, [0.78, 1.04, 1.16, 1.16, 1.00, 0.70, 0.60, 0.52])
_ZB = pchip(_ky, [-0.98, -1.26, -1.38, -1.40, -1.40, -1.38, -1.32, -1.24])
_NT = pchip(_ky, [3.2, 3.6, 3.9, 4.0, 3.8, 4.0, 3.8, 3.4])
_NB = pchip(_ky, [3.8, 4.4, 4.8, 5.0, 5.0, 4.8, 4.5, 4.0])
Z_TIP = -0.50
NOSE_PT, NOSE_PB, NOSE_PW = 1.9, 3.0, 2.3


def fus_dims(y):
    """half width, top z, bottom z, exponent top, exponent bottom of the fuselage section at y"""
    if y <= Y_N0:
        return _W(y), _ZT(y), _ZB(y), _NT(y), _NB(y)
    u = (y - Y_N0) / (Y_NOSE - Y_N0)
    fw = max(0.0, 1 - u ** NOSE_PW) ** (1.0 / NOSE_PW)
    ft = max(0.0, 1 - u ** NOSE_PT) ** (1.0 / NOSE_PT)
    fb = max(0.0, 1 - u ** NOSE_PB) ** (1.0 / NOSE_PB)
    w0, zt0, zb0 = _W(Y_N0), _ZT(Y_N0), _ZB(Y_N0)
    zc0 = (zt0 + zb0) / 2
    zc = lerp(zc0, Z_TIP, u ** 2)
    nt = lerp(_NT(Y_N0), 2.4, u)
    nb = lerp(_NB(Y_N0), 2.6, u)
    return w0 * fw, zc + (zt0 - zc0) * ft, zc - (zc0 - zb0) * fb, nt, nb


def fus_eq(zt, zb):
    return zb + 0.46 * (zt - zb)


def fus_ring(y, shrink=0.0, ncols=NC):
    w, zt, zb, nt, nb = fus_dims(y)
    zeq = fus_eq(zt, zb)
    pts = []
    for k in range(ncols):
        th = TAU * k / ncols
        c, s = math.cos(th), math.sin(th)
        x = w * spow(c, 2.0 / nt if s >= 0 else 2.0 / nb)
        if s >= 0:
            z = zeq + (zt - zeq) * (abs(s) ** (2.0 / nt))
        else:
            z = zeq - (zeq - zb) * (abs(s) ** (2.0 / nb))
        pts.append(Vector((x, y, z)))
    if shrink:
        cz = Vector((0, y, zeq))
        pts = [cz + (p - cz) * (1 - shrink) for p in pts]
    return pts


def hull_top_z(x, y):
    w, zt, zb, nt, nb = fus_dims(y)
    if w < 1e-6:
        return zt
    zeq = fus_eq(zt, zb)
    r = min(abs(x) / w, 0.9999)
    return zeq + (zt - zeq) * (1 - r ** nt) ** (1.0 / nt)


def fus_pt(y, th_deg, lift=0.0):
    """point on the analytic fuselage surface at section angle th (deg, 0 = +X side, 90 = top) pushed out by lift"""
    w, zt, zb, nt, nb = fus_dims(y)
    zeq = fus_eq(zt, zb)
    th = rad(th_deg)
    c, s = math.cos(th), math.sin(th)
    n = nt if s >= 0 else nb
    x = w * spow(c, 2.0 / n)
    if s >= 0:
        hz = zt - zeq
        z = zeq + hz * abs(s) ** (2.0 / n)
    else:
        hz = zeq - zb
        z = zeq - hz * abs(s) ** (2.0 / n)
    # outward normal of |x/w|^n + |(z-zeq)/hz|^n = 1
    nx = (abs(x) / max(w, 1e-6)) ** (n - 1) / max(w, 1e-6) * (1 if x >= 0 else -1)
    nz = (abs(z - zeq) / max(hz, 1e-6)) ** (n - 1) / max(hz, 1e-6) * (1 if z >= zeq else -1)
    nv = Vector((nx, 0, nz))
    nv = nv.normalized() if nv.length > 1e-9 else Vector((0, 0, 1))
    return Vector((x, y, z)) + nv * lift


def fus_stripe(mb, sx, y0, y1, th0, th1, mat, lift=0.010, rows=3, step=0.12, taper_end=False):
    """longitudinal ribbon between the section angles th0..th1 (deg, measured on the +X side; mirrored for sx=-1),
    from y0 (rear) to y1 (front).  Follows the fuselage exactly and narrows with the section."""
    n = max(2, int(abs(y1 - y0) / step) + 1)
    G = []
    for i in range(n):
        y = lerp(y0, y1, i / (n - 1))
        t = i / (n - 1)
        wscale = 1.0
        if taper_end:
            wscale = min(1.0, (1 - t) * 6.0 + 0.001)
        c = 0.5 * (th0 + th1)
        row = []
        for k in range(rows):
            th = c + (lerp(th0, th1, k / (rows - 1)) - c) * wscale
            p = fus_pt(y, th, lift)
            row.append(Vector((p.x * sx, p.y, p.z)))
        G.append(row)
    part = mb.grid(G, closed=False, mat=mat, smooth=True, outward=False)
    # orient outwards
    if part.faces:
        f = part.faces[len(part.faces) // 2]
        f.normal_update()
        cen = f.calc_center_median()
        w_, zt_, zb_, _, _ = fus_dims(cen.y)
        out = Vector((cen.x, 0, cen.z - fus_eq(zt_, zb_)))
        if f.normal.dot(out) < 0:
            for ff in part.faces:
                ff.normal_flip()
    return part


def fuselage(mb, grooves=(Y_CAP, 1.25, -4.6)):
    ys = [(-6.30, 'tail'), (-6.22, None), (-6.0, None), (-5.6, None)]
    y = -5.2
    while y < Y_N0 - 0.1:
        ys.append((round(y, 3), None))
        y += 0.5
    ys.append((Y_N0, None))
    nn = 10
    for j in range(1, nn + 1):
        u = math.sin(PI / 2 * j / nn)
        ys.append((Y_N0 + (Y_NOSE - Y_N0) * u, 'nose' if j == nn else None))
    ys.sort(key=lambda t: t[0])
    ylist, shr = [], []
    for (y, tag) in ys:
        if any(abs(y - g) < 0.2 for g in grooves) and tag is None:
            continue
        ylist.append(y)
        shr.append(0.0)
    for g in grooves:
        for (dy, sh) in ((-0.03, 0.0), (0.0, 0.014), (0.03, 0.0)):
            ylist.append(g + dy)
            shr.append(sh)
    ylist.append(Y_CAP - 0.17)          # extra ring: orange band behind the nose cap
    shr.append(0.0)
    order = sorted(range(len(ylist)), key=lambda i: ylist[i])
    ylist = [ylist[i] for i in order]
    shr = [shr[i] for i in order]
    rings = [fus_ring(y, sh) for y, sh in zip(ylist, shr)]
    part = mb.loft(rings, mat='Hull_Paint', cap_a=True, cap_b=False, cap_kind='ngon')
    part.ylist, part.shr = ylist, shr
    dark, accent = mb.mi('Hull_Dark'), mb.mi('Hull_Accent')
    for bi in range(len(part.bands)):
        y0, y1 = ylist[bi], ylist[bi + 1]
        yb = 0.5 * (y0 + y1)
        for k in range(NC):
            f = part.bands[bi][k]
            if f is None:
                continue
            if 28 <= k <= 43 or yb > Y_CAP + 0.03:
                f.material_index = dark                               # belly + nose cap
            elif abs(y0 - (Y_CAP - 0.17)) < 1e-6:
                f.material_index = accent                             # orange band behind the cap
        if shr[bi] > 0 or shr[bi + 1] > 0:
            for f in part.bands[bi]:
                if f is not None:
                    f.material_index = dark
    for f in part.caps:
        f.material_index = dark
    return part


# ------------------------------------------------------------------------------------------------
# wings / canards / fin / spine
# ------------------------------------------------------------------------------------------------
NH = 10      # airfoil half resolution -> 2*NH+1 columns


def airfoil_loft(mb, stations, n_half=NH, t_ratio=0.12, te=0.012, flat_bottom=0.0, mat='Hull_Paint', cap_a=True, cap_b=True,
                 sx=1.0):
    af = airfoil(n_half, t_ratio, te=te, flat_bottom=flat_bottom)
    tmax = max(z for (_, z) in af) - min(z for (_, z) in af)
    rings = []
    for s in stations:
        O = Vector((s['O'][0] * sx, s['O'][1], s['O'][2]))
        N = Vector((s['N'][0] * sx, s['N'][1], s['N'][2])).normalized()
        chord = s['le'] - s['te']
        zs = s['t'] / tmax
        ring = []
        for (xc, zc) in af:
            y = s['le'] - xc * chord
            ring.append(O + Vector((0, y, 0)) + N * (zc * zs))
        rings.append(ring)
    return mb.loft(rings, mat=mat, cap_a=cap_a, cap_b=cap_b, cap_kind='fan')


WING_PAN = [(1.0, -0.55, 1.90, -5.70, 0.74),
            (2.2, -0.50, 0.55, -5.65, 0.62),
            (3.4, -0.46, -0.45, -5.50, 0.47),
            (4.5, -0.41, -1.50, -5.30, 0.35),
            (5.5, -0.35, -2.50, -5.10, 0.25)]
_wle = pchip([p[0] for p in WING_PAN], [p[2] for p in WING_PAN])
_wte = pchip([p[0] for p in WING_PAN], [p[3] for p in WING_PAN])


def rounded_tail(S, T, n=3, ext=0.22):
    last = S[-1]
    out = []
    for j in range(1, n + 1):
        u = j / n
        f = math.sqrt(max(0.0, 1 - u * u)) * 0.97 + 0.03
        p = Vector(last['O']) + T * (ext * math.sin(u * PI / 2))
        cen = (last['le'] + last['te']) / 2
        half = (last['le'] - last['te']) / 2 * f
        out.append(dict(O=(p.x, 0, p.z), N=last['N'], le=cen + half, te=cen - half, t=last['t'] * f, a=last.get('a', 0)))
    return out


def wing_stations():
    """right wing (x>0): straight panel, bend, winglet."""
    S = []
    a0 = rad(3.5)
    for (x, z, le, te, t) in WING_PAN:
        S.append(dict(O=(x, 0, z), N=(-math.sin(a0), 0, math.cos(a0)), le=le, te=te, t=t, a=a0))
    R = 0.70
    x0, z0 = WING_PAN[-1][0], WING_PAN[-1][1]
    le0, te0 = WING_PAN[-1][2], WING_PAN[-1][3]
    a1 = rad(84)
    nb = 6
    for j in range(1, nb + 1):
        a = lerp(a0, a1, j / nb)
        x = x0 + R * (math.sin(a) - math.sin(a0))
        z = z0 + R * (math.cos(a0) - math.cos(a))
        S.append(dict(O=(x, 0, z), N=(-math.sin(a), 0, math.cos(a)), le=lerp(le0, le0 - 0.25, j / nb), te=lerp(te0, -5.05, j / nb),
                      t=lerp(0.25, 0.20, j / nb), a=a))
    xe, ze = S[-1]['O'][0], S[-1]['O'][2]
    a = a1
    T = Vector((math.cos(a), 0, math.sin(a)))
    hl = 1.5
    for j in range(1, 5):
        u = j / 4
        p = Vector((xe, 0, ze)) + T * (hl * u)
        S.append(dict(O=(p.x, 0, p.z), N=(-math.sin(a), 0, math.cos(a)), le=lerp(le0 - 0.25, -4.00, u), te=-5.05,
                      t=lerp(0.20, 0.10, u), a=a))
    S += rounded_tail(S, T)
    return S


WING_S = wing_stations()
N_PAN = len(WING_PAN)


def paint_airfoil(part, mb, bands, le_dark=True, lower_dark=True, accent_bands=None):
    dark, accent = mb.mi('Hull_Dark'), mb.mi('Hull_Accent')
    ncol = len(part.bands[0])
    for bi in bands:
        for k in range(ncol):
            f = part.bands[bi][k]
            if f is None:
                continue
            if lower_dark and k >= NH:
                f.material_index = dark
            if le_dark and k in (NH - 2, NH - 1):
                f.material_index = dark
    if accent_bands:
        for bi in accent_bands:
            for k in range(ncol):
                f = part.bands[bi][k]
                if f is not None:
                    f.material_index = accent


def wing(mb, sx=1.0):
    part = airfoil_loft(mb, WING_S, t_ratio=0.12, te=0.010, flat_bottom=0.35, sx=sx)
    nbnd = len(part.bands)
    paint_airfoil(part, mb, range(0, N_PAN), le_dark=True, lower_dark=True)
    paint_airfoil(part, mb, range(N_PAN, nbnd), le_dark=False, lower_dark=False, accent_bands=range(N_PAN + 1, nbnd))
    # the first bend band keeps a dark underside
    for k in range(NH, len(part.bands[0])):
        f = part.bands[N_PAN][k]
        if f is not None:
            f.material_index = mb.mi('Hull_Dark')
    return part


CANARD = [(1.3, 0.02, 4.10, 2.55, 0.24),
          (1.9, 0.03, 3.85, 2.52, 0.19),
          (2.5, 0.05, 3.52, 2.50, 0.14),
          (3.0, 0.07, 3.20, 2.48, 0.10)]


def canard_stations():
    S = []
    a = rad(4)
    for (x, z, le, te, t) in CANARD:
        S.append(dict(O=(x, 0, z), N=(-math.sin(a), 0, math.cos(a)), le=le, te=te, t=t, a=a))
    T = Vector((math.cos(a), 0, math.sin(a)))
    S += rounded_tail(S, T, n=2, ext=0.16)
    return S


def canard(mb, sx=1.0):
    S = canard_stations()
    part = airfoil_loft(mb, S, t_ratio=0.10, te=0.012, flat_bottom=0.3, sx=sx)
    nbnd = len(part.bands)
    paint_airfoil(part, mb, range(nbnd), le_dark=True, lower_dark=True, accent_bands=range(2, nbnd))
    return part


FIN_Z0, FIN_H = 0.90, 2.0


def fin_stations():
    S = []
    n = 6
    for j in range(n + 1):
        u = j / n
        S.append(dict(O=(0, 0, FIN_Z0 + FIN_H * u), N=(1, 0, 0), le=lerp(-1.6, -4.85, u ** 1.15), te=lerp(-5.55, -6.05, u),
                      t=lerp(0.44, 0.15, u)))
    S += rounded_tail(S, Vector((0, 0, 1)), n=2, ext=0.16)
    return S


FIN_S = fin_stations()


def fin(mb):
    part = airfoil_loft(mb, FIN_S, n_half=NH, t_ratio=0.12, te=0.02)
    for bi in range(4, len(part.bands)):
        for f in part.bands[bi]:
            if f is not None:
                f.material_index = mb.mi('Hull_Accent')
    return part


def spine(mb):
    ys = [1.15, 0.8, 0.2, -0.6, -1.6, -2.6, -3.6, -4.6, -5.4, -6.1]
    hs = [0.06, 0.12, 0.24, 0.34, 0.40, 0.42, 0.40, 0.36, 0.30, 0.22]
    ws = [0.46, 0.52, 0.56, 0.58, 0.56, 0.54, 0.52, 0.48, 0.44, 0.40]
    H = pchip(ys[::-1], hs[::-1])
    Wd = pchip(ys[::-1], ws[::-1])
    rings = []
    n = 22
    for i in range(n + 1):
        y = lerp(1.15, -6.1, i / n)
        h, w = H(y), Wd(y)
        zbase = hull_top_z(0, y) - 0.12
        total = h + 0.12
        rings.append([Vector((cx, y, zbase + total / 2 + cz)) for (cx, cz) in superellipse(16, w, total / 2, 2.8)])
    return mb.loft(rings, mat='Hull_Paint', cap_a=True, cap_b=True, cap_kind='fan')


# ------------------------------------------------------------------------------------------------
# engine pods
# ------------------------------------------------------------------------------------------------
POD_X, POD_Z = 2.35, -0.38
NOZ_Y_EXIT = -7.0
POD_R = 0.98
POD_SEGS = 32


def pod_profile():
    R = POD_R
    return [(0.72, 0.50, 'Hull_Dark'),
            (0.73, 0.88, 'Hull_Dark'),
            (0.77, 1.02, 'Metal'),
            (0.87, 1.00, 'Hull_Accent'),
            (0.91, 0.80, 'Hull_Accent'),
            (0.945, 0.50, 'Hull_Paint'),
            (0.97, 0.00, 'Hull_Paint'),
            (R, -0.60, 'Hull_Paint'),
            (R, -0.72, 'Hull_Accent'),
            (R, -0.84, 'Hull_Paint'),
            (R, -1.40, 'Hull_Paint'),
            (R - 0.015, -1.43, 'Hull_Dark'),
            (R - 0.015, -1.48, 'Hull_Dark'),
            (R, -1.51, 'Hull_Paint'),
            (R, -2.62, 'Hull_Paint'),
            (R - 0.015, -2.65, 'Hull_Dark'),
            (R - 0.015, -2.70, 'Hull_Dark'),
            (R, -2.73, 'Hull_Paint'),
            (0.975, -3.75, 'Hull_Paint'),
            (0.97, -3.82, 'Hull_Accent'),
            (0.97, -3.97, 'Hull_Accent'),
            (0.95, -4.01, 'Hull_Dark'),
            (0.93, -4.60, 'Hull_Dark'),
            (0.93, -4.65, 'Metal'),
            (0.965, -4.68, 'Metal'),
            (0.965, -4.77, 'Metal'),
            (0.93, -4.80, 'Metal'),
            (0.90, -5.20, 'Hull_Dark'),
            (0.86, -5.72, 'Hull_Dark')]


def pod(mb, sx=1.0):
    prof = pod_profile()
    cx = POD_X * sx
    segs = POD_SEGS
    rings = [[Vector((cx + r * math.cos(TAU * k / segs), y, POD_Z + r * math.sin(TAU * k / segs))) for k in range(segs)]
             for (r, y, m_) in prof]
    part = mb.loft(rings, mat='Hull_Paint', cap_a=True, cap_b=False, cap_kind='ngon')
    for f in part.caps:
        f.material_index = mb.mi('Hull_Dark')
    for bi in range(len(part.bands)):
        m_ = prof[bi + 1][2]
        for f in part.bands[bi]:
            if f is not None:
                f.material_index = mb.mi(m_)
    return part


def pod_details(mb, sx, surf):
    cx = POD_X * sx
    # intake spinner and fan blades
    mb.lathe([(0.0, 0.93), (0.09, 0.84), (0.18, 0.68), (0.23, 0.52), (0.23, 0.48), (0.0, 0.48)], 16,
             MB.xf((cx, 0, POD_Z), MB.aim((0, 1, 0))), mat='Metal')
    for k in range(9):
        a = TAU * k / 9
        R_ = Matrix.Rotation(-a, 3, 'Y') @ Matrix.Rotation(rad(28), 3, 'X')
        c = Vector((cx + 0.47 * math.cos(a), 0.62, POD_Z + 0.47 * math.sin(a)))
        mb.rbox((0.52, 0.025, 0.22), center=c, rot=R_, bevel=0.0, mat='Metal')
    # orange flank stripe + light line (outer side only)
    strip_on_surface(mb, surf, [(sx * 6, 0.30, POD_Z + 0.22), (sx * 6, -3.30, POD_Z + 0.22)], 0.18, 'Hull_Accent',
                     direction=(-sx, 0, 0), step=0.3)
    strip_on_surface(mb, surf, [(sx * 6, 0.20, POD_Z + 0.40), (sx * 6, -3.20, POD_Z + 0.40)], 0.035, 'Emissive_Light',
                     direction=(-sx, 0, 0), step=0.3)
    # gear bay on the underside
    gy = -2.6
    plate_on_surface(mb, surf, (cx, gy, -6.0), (0.78, 1.45), 0, 0.012, 'Hull_Dark', direction=(0, 0, 1), nu=3, nv=5, start_off=3.0)
    outline_rect(mb, surf, (cx, gy, -6.0), (0.90, 1.57), 0.04, 'Hull_Accent', 0.010, direction=(0, 0, 1), axes='xy', start_off=3.0)


def nozzle(mb, sx=1.0):
    cx = POD_X * sx
    prof = [(0.84, -5.68), (0.80, -5.90), (0.74, -6.30), (0.82, -6.75), (0.93, NOZ_Y_EXIT),
            (0.86, NOZ_Y_EXIT), (0.70, -6.60), (0.57, -6.10), (0.52, -5.85)]
    segs = POD_SEGS
    rings = [[Vector((cx + r * math.cos(TAU * k / segs), y, POD_Z + r * math.sin(TAU * k / segs))) for k in range(segs)]
             for (r, y) in prof]
    part = mb.loft(rings, mat='Hull_Dark', cap_a=False, cap_b=True, cap_kind='ngon')
    for f in part.bands[3]:
        f.material_index = mb.mi('Metal')
    for f in part.caps:
        f.material_index = mb.mi('Hull_Dark')
    for (r_in, y_) in ((0.655, -6.45), (0.74, -6.72)):
        mb.torus(r_in, 0.028, center=(cx, y_, POD_Z), segs=POD_SEGS, tsegs=5, rot=(PI / 2, 0, 0), mat='Metal')
    mb.torus(0.895, 0.026, center=(cx, NOZ_Y_EXIT + 0.01, POD_Z), segs=POD_SEGS, tsegs=5, rot=(PI / 2, 0, 0), mat='Hull_Accent')
    return part


# ------------------------------------------------------------------------------------------------
# decal helpers
# ------------------------------------------------------------------------------------------------
def outline_rect(mb, surf, center, size, width, mat, lift, direction, axes='xy', start_off=4.0):
    """4 thin ribbons forming a rectangle outline on a surface (axes: 'xy' or 'yz')."""
    c = Vector(center)
    a, b = size[0] / 2, size[1] / 2
    h = width / 2
    if axes == 'xy':
        P_ = [(Vector((c[0] - a, c[1] - b, c[2])), Vector((c[0] + a, c[1] - b, c[2]))),
              (Vector((c[0] - a, c[1] + b, c[2])), Vector((c[0] + a, c[1] + b, c[2]))),
              (Vector((c[0] - a, c[1] - b, c[2])), Vector((c[0] - a, c[1] + b, c[2]))),
              (Vector((c[0] + a, c[1] - b, c[2])), Vector((c[0] + a, c[1] + b, c[2])))]
        ext = [(Vector((-h, 0, 0)), Vector((h, 0, 0)))] * 2 + [(Vector((0, -h, 0)), Vector((0, h, 0)))] * 2
    else:
        P_ = [(Vector((c[0], c[1] - a, c[2] - b)), Vector((c[0], c[1] + a, c[2] - b))),
              (Vector((c[0], c[1] - a, c[2] + b)), Vector((c[0], c[1] + a, c[2] + b))),
              (Vector((c[0], c[1] - a, c[2] - b)), Vector((c[0], c[1] - a, c[2] + b))),
              (Vector((c[0], c[1] + a, c[2] - b)), Vector((c[0], c[1] + a, c[2] + b)))]
        ext = [(Vector((0, -h, 0)), Vector((0, h, 0)))] * 2 + [(Vector((0, 0, -h)), Vector((0, 0, h)))] * 2
    for (p, q), (e0, e1) in zip(P_, ext):
        strip_on_surface(mb, surf, [p + e0, q + e1], width, mat, lift=lift, direction=direction, start_off=start_off, step=0.3)


# ------------------------------------------------------------------------------------------------
# hull details
# ------------------------------------------------------------------------------------------------
def hull_details(hb, surf_f, wsurf, csurf, spine_part, fin_part):
    info = {}
    # ---- flank stripes (orange + cyan light line)
    for sx in (1, -1):
        fus_stripe(hb, sx, 1.25, 5.66, 28.0, 39.0, 'Hull_Accent', lift=0.010, rows=4)
        fus_stripe(hb, sx, 1.25, 4.75, 43.0, 45.5, 'Emissive_Light', lift=0.010, rows=2, taper_end=True)
    # ---- side hatch (left)
    HY0, HY1, HZ0, HZ1 = 2.95, 3.95, -1.00, -0.22
    outline_rect(hb, surf_f, (-4, (HY0 + HY1) / 2, (HZ0 + HZ1) / 2), (HY1 - HY0, HZ1 - HZ0), 0.04, 'Hull_Dark', 0.010,
                 direction=(1, 0, 0), axes='yz')
    plate_on_surface(hb, surf_f, (-4, (HY0 + HY1) / 2, (HZ0 + HZ1) / 2), (HY1 - HY0 - 0.12, HZ1 - HZ0 - 0.12), 0, 0.014,
                     'Hull_Paint', direction=(1, 0, 0), nu=4, nv=4)
    h = surf_f.cast((-6, 3.25, -0.62), (1, 0, 0))
    if h:
        p, n = h
        hb.rbox((0.05, 0.22, 0.05), center=p + n * 0.040, bevel=0.012, bsegs=1, mat='Metal')
    h = surf_f.cast((-6, 3.45, -0.60), (1, 0, 0))
    info['hatch'] = h[0].copy() if h else Vector((-1.86, 3.45, -0.60))
    plate_on_surface(hb, surf_f, (-4, 3.65, -0.40), (0.24, 0.18), 0, 0.022, 'Emissive_Window', direction=(1, 0, 0), nu=2, nv=2)
    # ---- dorsal lines + orange dorsal stripes
    for sx in (1, -1):
        strip_on_surface(hb, surf_f, [(sx * 0.67, 0.85, 5), (sx * 0.67, -5.3, 5)], 0.03, 'Hull_Dark', step=0.3)
        strip_on_surface(hb, surf_f, [(sx * 0.98, 0.70, 5), (sx * 0.98, -4.6, 5)], lambda t: 0.30 * min(1.0, (1 - t) * 9),
                         'Hull_Accent', step=0.3)
        strip_on_surface(hb, surf_f, [(sx * 1.20, 0.70, 5), (sx * 1.20, -4.5, 5)], 0.025, 'Hull_Dark', step=0.3)
    strip_on_surface(hb, surf_f, [(-1.4, 0.80, 5), (1.4, 0.80, 5)], 0.03, 'Hull_Dark', step=0.3)
    # ---- cockpit cowl in front of the canopy
    plate_on_surface(hb, surf_f, (0, 5.05, 5), (1.5, 0.55), 0, 0.02, 'Hull_Dark', nu=5, nv=2)
    # ---- nose headlights
    heads = {}
    for sx, nm in ((-1, 'L'), (1, 'R')):
        hh = surf_f.cast((sx * 0.60, 10, -0.40), (0, -1, 0))
        if hh:
            p, n = hh
            heads[nm] = (p.copy(), n.copy())
            hb.torus(0.15, 0.035, center=p + n * 0.01, segs=16, tsegs=5, rot=MB.aim(n), mat='Metal')
            hb.cyl(0.13, 0.04, center=p + n * 0.02, segs=16, mat='Emissive_Light', rot=MB.aim(n))
    info['heads'] = heads
    # ---- tail face: APU nozzle ring, louvres and status lights
    ty = Y_TAIL - 0.01
    tz = 0.5 * (fus_dims(Y_TAIL)[1] + fus_dims(Y_TAIL)[2]) - 0.02
    hb.torus(0.40, 0.045, center=(0, ty, tz), segs=24, tsegs=6, rot=(PI / 2, 0, 0), mat='Metal')
    hb.cyl(0.36, 0.05, center=(0, ty + 0.02, tz), segs=20, mat='Hull_Dark', rot=(PI / 2, 0, 0))
    hb.cyl(0.13, 0.03, center=(0, ty - 0.005, tz), segs=14, mat='Emissive_Amber', rot=(PI / 2, 0, 0))
    for sx in (-1, 1):
        for i in range(5):
            hb.rbox((0.46, 0.04, 0.045), center=(sx * 0.93, ty, tz + 0.40 - 0.2 * i), bevel=0.0, mat='Metal')
        for i in range(2):
            hb.cyl(0.035, 0.03, center=(sx * 0.93, ty - 0.005, tz - 0.55 - 0.13 * i), segs=8, rot=(PI / 2, 0, 0),
                   mat='Emissive_NavRed' if i == 0 else 'Emissive_NavGreen')
    # ---- sensor dome under the nose
    zb = fus_dims(4.9)[2]
    hb.sphere(0.20, center=(0, 4.9, zb + 0.04), segs=14, mat='Metal')
    hb.torus(0.22, 0.03, center=(0, 4.9, zb + 0.04), segs=16, tsegs=5, mat='Hull_Accent')
    # ---- belly gear bay (front) + belly intakes
    plate_on_surface(hb, surf_f, (0, 4.35, -6), (0.84, 1.45), 0, 0.012, 'Hull_Dark', direction=(0, 0, 1), nu=3, nv=5, start_off=3.0)
    outline_rect(hb, surf_f, (0, 4.35, -6), (0.96, 1.57), 0.04, 'Hull_Accent', 0.010, direction=(0, 0, 1), axes='xy', start_off=3.0)
    for sx in (-1, 1):
        zb_ = fus_dims(0.9)[2]
        hb.rbox((0.62, 1.30, 0.30), center=(sx * 0.95, 0.9, zb_ - 0.02), bevel=0.07, bsegs=2, mat='Hull_Dark', taper=(0.9, 0.9))
        hb.rbox((0.48, 0.06, 0.20), center=(sx * 0.95, 1.56, zb_ - 0.04), bevel=0.01, bsegs=1, mat='Rubber')
        outline_rect(hb, surf_f, (sx * 0.95, 0.9, -6), (0.82, 1.55), 0.03, 'Hull_Accent', 0.010, direction=(0, 0, 1), axes='xy',
                     start_off=3.0)
    # ---- spine: vents, antennas, dish
    ss = Surf(faces=spine_part.faces)
    for i in range(6):
        for sx in (-1, 1):
            plate_on_surface(hb, ss, (sx * 0.20, -0.85 - 0.40 * i, 5), (0.07, 0.30), 0, 0.014, 'Hull_Dark', nu=1, nv=3, chamfer=False)
    hb_ = ss.cast((0.20, 0.0, 6), (0, 0, -1))
    if hb_:
        p, n = hb_
        hb.cyl(0.05, 0.06, center=p, segs=10, mat='Metal')
        hb.cyl(0.012, 1.4, center=p + Vector((0, -0.12, 0.70)), segs=6, rot=(rad(10), 0, 0), mat='Metal')
        hb.sphere(0.03, center=p + Vector((0, -0.25, 1.38)), segs=8, mat='Emissive_NavRed')
    hb_ = ss.cast((-0.18, -0.2, 6), (0, 0, -1))
    if hb_:
        p, n = hb_
        hb.cyl(0.05, 0.06, center=p, segs=10, mat='Metal')
        hb.cyl(0.010, 0.8, center=p + Vector((0, 0.06, 0.40)), segs=6, rot=(rad(-8), 0, 0), mat='Metal')
    hb_ = ss.cast((-0.10, 0.45, 6), (0, 0, -1))
    if hb_:
        p, n = hb_
        hb.cyl(0.035, 0.22, center=p + Vector((0, 0, 0.06)), segs=8, mat='Metal')
        hb.sphere(0.07, center=p + Vector((0, 0, 0.18)), segs=10, mat='Hull_Dark')
        dc = p + Vector((0, 0.03, 0.30))
        rot = Matrix.Rotation(rad(-38), 3, 'X')
        hb.hemi(0.36, center=dc, segs=20, rings=5, mat='Hull_Paint', scale=(1, 1, 0.38), rot=rot)
        hb.cyl(0.012, 0.30, center=dc + rot @ Vector((0, 0, 0.15)), segs=6, mat='Metal', rot=rot)
        hb.sphere(0.035, center=dc + rot @ Vector((0, 0, 0.30)), segs=8, mat='Metal')
    # ---- wing details
    for sx in (1, -1):
        ws = wsurf[sx]
        pts = [(sx * x, _wle(x) - 0.76 * (_wle(x) - _wte(x)), 6) for x in (3.45, 4.1, 4.8, 5.4)]
        strip_on_surface(hb, ws, pts, 0.03, 'Hull_Dark', step=0.3)
        strip_on_surface(hb, ws, [(sx * 3.5, _wle(3.5) - 0.45, 6), (sx * 3.5, _wte(3.5) + 0.05, 6)], 0.03, 'Hull_Dark', step=0.3)
        strip_on_surface(hb, ws, [(sx * 4.0, _wle(4.0) - 0.50, 6), (sx * 4.0, _wte(4.0) + 0.55, 6)], 0.30, 'Hull_Accent', step=0.3)
        for (x0, x1) in ((3.5, 3.9), (4.35, 4.75)):
            strip_on_surface(hb, ws, [(sx * x0, _wle(x0) - 0.72, 6), (sx * x1, _wle(x1) - 0.72, 6)], 0.05, 'Emissive_Light', step=0.3)
    # ---- fin details (rudder seams, both sides)
    fs = Surf(faces=fin_part.faces)
    zs = [s['O'][2] for s in FIN_S[:7]]
    fle = pchip(zs, [s['le'] for s in FIN_S[:7]])
    fte = pchip(zs, [s['te'] for s in FIN_S[:7]])
    for sx in (1, -1):
        pts = [(sx * 4, fle(z) - 0.68 * (fle(z) - fte(z)), z) for z in (1.15, 1.7, 2.3, 2.8)]
        strip_on_surface(hb, fs, pts, 0.03, 'Hull_Dark', direction=(-sx, 0, 0), step=0.3)
    return info


# ------------------------------------------------------------------------------------------------
# cockpit
# ------------------------------------------------------------------------------------------------
CAN_Y0, CAN_Y1, CAN_W, CAN_TOP = 0.95, 4.65, 0.98, 2.0
CAN_APEX_Y = 2.45


def canopy_dims(y):
    """half width, deck height and bubble height above the deck at y"""
    u = (y - CAN_Y0) / (CAN_Y1 - CAN_Y0)
    a = abs((u - 0.5) / 0.5)
    w = CAN_W * max(0.0, 1 - a ** 2.2) ** (1 / 2.2)
    zd = hull_top_z(0, y)
    ua = (CAN_APEX_Y - CAN_Y0) / (CAN_Y1 - CAN_Y0)
    if u < ua:
        b = (ua - u) / ua
        hf = max(0.0, 1 - b ** 2.0) ** 0.5
    else:
        b = (u - ua) / (1 - ua)
        hf = max(0.0, 1 - b ** 2.4) ** (1 / 2.4)
    zapex = hull_top_z(0, CAN_APEX_Y)
    return w, zd, (CAN_TOP - zapex) * hf


def canopy_rings(n_rings=22, n_pts=17, expand=0.0, nexp=2.3):
    rings = []
    for i in range(n_rings + 1):
        s = i / n_rings
        u = (1 - math.cos(PI * s)) / 2
        y = lerp(CAN_Y0, CAN_Y1, u)
        w, zd, h = canopy_dims(y)
        if w < 1e-4:
            rings.append([Vector((0, y, zd - 0.10))] * n_pts)
            continue
        ring = []
        for j in range(n_pts):
            ph = PI * j / (n_pts - 1)
            c, sn = math.cos(ph), math.sin(ph)
            x = (w + expand) * spow(c, 2.0 / nexp)
            zbase = hull_top_z(x, y) - 0.10
            z = zbase + ((zd - zbase) + h + expand) * (abs(sn) ** (2.0 / nexp))
            ring.append(Vector((x, y, z)))
        rings.append(ring)
    return rings


def canopy_arch(y, n_pts=27, expand=0.02, nexp=2.3):
    """points of one transverse arch on the glass surface at y (left to right)"""
    w, zd, h = canopy_dims(y)
    pts = []
    for j in range(n_pts):
        ph = PI * j / (n_pts - 1)
        c, sn = math.cos(ph), math.sin(ph)
        x = (w + expand) * spow(c, 2.0 / nexp)
        zbase = hull_top_z(x, y) - 0.10
        z = zbase + ((zd - zbase) + h + expand) * (abs(sn) ** (2.0 / nexp))
        pts.append(Vector((x, y, z)))
    return pts


def canopy_glass(mb):
    return mb.loft(canopy_rings(), mat='Glass', cap_a=False, cap_b=False, closed=False)


def canopy_frame(mb):
    NR, NP = 22, 17
    rings = canopy_rings(n_rings=NR, n_pts=NP, expand=0.02)
    left = [r[-1] for r in rings]
    right = [r[0] for r in rings]
    loop = [p.copy() + Vector((0, 0, 0.09)) for p in left] + [p.copy() + Vector((0, 0, 0.09)) for p in reversed(right)]
    clean = []
    for p in loop:
        if not clean or (p - clean[-1]).length > 1e-3:
            clean.append(p)
    if (clean[0] - clean[-1]).length < 1e-3:
        clean.pop()
    mb.tube(clean, 0.07, segs=7, mat='Hull_Paint', close=True, fixed_up=True, squash=0.7)
    for s in (0.20, 0.42, 0.62, 0.80):
        u = (1 - math.cos(PI * s)) / 2
        y = lerp(CAN_Y0, CAN_Y1, u)
        mb.tube(canopy_arch(y, 27, 0.02), 0.032 if s != 0.80 else 0.05, segs=5, mat='Hull_Dark')
    mb.tube([rings[i][NP // 2] for i in range(2, NR - 1)], 0.03, segs=5, mat='Hull_Dark')


EYE = None


def screen_panel(mb, c, w, h, rot, mat_screen, ui_mat='Hull_Dark'):
    """bezel + glowing screen facing the pilot; returns (centre, normal, right, up) for UI details"""
    R_ = rot if isinstance(rot, Matrix) else Euler(rot, 'XYZ').to_matrix()
    n = R_ @ Vector((0, -1, 0))
    right = R_ @ Vector((1, 0, 0))
    up = R_ @ Vector((0, 0, 1))
    mb.rbox((w + 0.05, 0.035, h + 0.05), center=c, rot=R_, bevel=0.01, bsegs=1, mat='Hull_Dark')
    sc = Vector(c) + n * 0.020
    mb.rbox((w, 0.012, h), center=sc, rot=R_, bevel=0.0, mat=mat_screen)
    return Vector(c) + n * 0.028, n, right, up


def ui_bar(mb, ctr, right, up, rot, x, z, w, h, mat='Hull_Dark'):
    R_ = rot if isinstance(rot, Matrix) else Euler(rot, 'XYZ').to_matrix()
    mb.rbox((w, 0.004, h), center=ctr + right * x + up * z, rot=R_, bevel=0.0, mat=mat)


def console(mb, dk):
    y0, y1 = 3.28, 4.10
    zr, zf = dk + 0.32, dk + 0.50
    hw0, hw1 = 0.76, 0.56
    zb = dk - 0.06
    rings = []
    n = 6
    for i in range(n + 1):
        t = i / n
        y = lerp(y0, y1, t)
        top = lerp(zr, zf, t)
        hw = lerp(hw0, hw1, t)
        rings.append([Vector((cx, y, (top + zb) / 2 + cz)) for (cx, cz) in superellipse(20, hw, (top - zb) / 2, 4.0)])
    mb.loft(rings, mat='Hull_Dark', cap_a=True, cap_b=True, cap_kind='ngon')
    slope = math.atan2(zf - zr, y1 - y0)
    tilt = -(rad(30) + slope)
    ztop = lambda y: lerp(zr, zf, (y - y0) / (y1 - y0))
    # three screens
    Rc = Matrix.Rotation(tilt, 3, 'X')
    yc = 3.66
    ctr, n_, rt, up = screen_panel(mb, (0, yc, ztop(yc) + 0.10), 0.40, 0.24, Rc, 'Emissive_Screen')
    for (cx, cz, r_) in ((0.0, 0.0, 0.085), (0.0, 0.0, 0.045)):
        mb.torus(r_, 0.0035, center=ctr + rt * cx + up * cz + n_ * 0.003, segs=24, tsegs=4, rot=Rc @ Matrix.Rotation(PI / 2, 3, 'X'),
                 mat='Hull_Dark')
    ui_bar(mb, ctr, rt, up, Rc, 0.0, 0.0, 0.19, 0.004)
    ui_bar(mb, ctr, rt, up, Rc, 0.0, 0.0, 0.004, 0.19)
    mb.sphere(0.012, center=ctr + rt * 0.045 + up * 0.03 + n_ * 0.006, segs=6, mat='Emissive_Amber')
    for sx in (-1, 1):
        Rs = Matrix.Rotation(sx * rad(-14), 3, 'Z') @ Rc
        ys = 3.60
        mat_s = 'Emissive_ScreenAmber' if sx < 0 else 'Emissive_Screen'
        ctr2, n2, rt2, up2 = screen_panel(mb, (sx * 0.41, ys, ztop(ys) + 0.085), 0.30, 0.20, Rs, mat_s)
        if sx < 0:
            for i, (wd, zz) in enumerate(((0.22, 0.07), (0.17, 0.035), (0.24, 0.0), (0.12, -0.035), (0.2, -0.07))):
                ui_bar(mb, ctr2, rt2, up2, Rs, -0.5 * (0.24 - wd) * 0.5, zz, wd, 0.008)
        else:
            for i, hh in enumerate((0.05, 0.11, 0.08, 0.14, 0.06, 0.1)):
                ui_bar(mb, ctr2, rt2, up2, Rs, -0.11 + 0.044 * i, -0.09 + hh / 2, 0.022, hh)
    # switch row on the rear lip
    for i in range(9):
        x = -0.48 + 0.12 * i
        m_ = ('Emissive_Amber', 'Emissive_NavGreen', 'Emissive_NavRed', 'Emissive_Screen')[i % 4]
        mb.cyl(0.014, 0.014, center=(x, 3.40, ztop(3.40) + 0.004), segs=8, mat=m_)
        mb.rbox((0.02, 0.05, 0.012), center=(x, 3.45, ztop(3.45) + 0.004), bevel=0.0, mat='Metal')


def cockpit_interior(mb):
    global EYE
    yd = 2.15
    dk = hull_top_z(0, yd)
    mb.rbox((0.55, 0.52, 0.16), center=(0, yd, dk + 0.04), bevel=0.04, mat='Hull_Dark')
    mb.rbox((0.60, 0.58, 0.16), center=(0, yd + 0.02, dk + 0.18), bevel=0.05, mat='Hull_Accent')
    mb.rbox((0.60, 0.14, 0.86), center=(0, yd - 0.30, dk + 0.62), rot=(rad(-12), 0, 0), bevel=0.05, mat='Hull_Accent')
    mb.rbox((0.38, 0.10, 0.26), center=(0, yd - 0.37, dk + 1.16), rot=(rad(-12), 0, 0), bevel=0.04, mat='Hull_Dark')
    for sx in (-1, 1):
        mb.rbox((0.08, 0.50, 0.14), center=(sx * 0.36, yd + 0.05, dk + 0.34), bevel=0.03, mat='Hull_Dark')
        mb.rbox((0.04, 0.05, 0.80), center=(sx * 0.18, yd - 0.28, dk + 0.62), rot=(rad(-12), 0, 0), bevel=0.01, mat='Rubber')
    console(mb, dk)
    mb.cyl(0.022, 0.38, center=(0.0, 2.88, dk + 0.34), segs=8, mat='Metal')
    mb.rbox((0.11, 0.07, 0.07), center=(0.0, 2.88, dk + 0.56), bevel=0.02, bsegs=1, mat='Hull_Accent')
    for sx in (-1, 1):
        mb.rbox((0.22, 1.0, 0.20), center=(sx * 0.72, 2.75, dk + 0.08), bevel=0.04, mat='Hull_Dark')
        for i in range(3):
            mb.rbox((0.04, 0.04, 0.012), center=(sx * 0.72, 2.45 + 0.22 * i, dk + 0.18), bevel=0,
                    mat='Emissive_Amber' if i != 1 else 'Emissive_Screen')
    EYE = Vector((0, yd, dk + 0.34 + 0.65))
    return dk


# ------------------------------------------------------------------------------------------------
# landing gear
# ------------------------------------------------------------------------------------------------
HINGE_Z = -0.70


def gear_leg(mb, hx, hy):
    hz = HINGE_Z
    mb.cyl(0.15, 0.70, center=(hx, hy, hz), segs=12, rot=(0, PI / 2, 0), mat='Metal', bevel=0.02, bsegs=1)
    for sx in (-1, 1):
        mb.cyl(0.10, 0.06, center=(hx + sx * 0.37, hy, hz), segs=10, rot=(0, PI / 2, 0), mat='Hull_Accent')
    # upper housing (outer cylinder)
    mb.cyl(0.135, 1.05, center=(hx, hy, hz - 0.55), segs=14, mat='Hull_Dark', bevel=0.02, bsegs=1)
    mb.cyl(0.165, 0.10, center=(hx, hy, hz - 0.22), segs=14, mat='Metal', bevel=0.015, bsegs=1)
    mb.cyl(0.165, 0.12, center=(hx, hy, hz - 1.02), segs=14, mat='Hull_Accent', bevel=0.015, bsegs=1)
    # piston down to the ball joint
    z_top, z_bot = hz - 0.95, GROUND_Z + 0.56
    mb.cyl(0.075, z_top - z_bot, center=(hx, hy, (z_top + z_bot) / 2), segs=10, mat='Metal')
    for sy in (-1, 1):
        mb.rbox((0.045, 0.045, 0.70), center=(hx, hy + sy * 0.15, hz - 0.72), rot=(rad(sy * 14), 0, 0), bevel=0.0, mat='Metal')
    mb.tube([(hx + 0.13, hy, hz - 0.40), (hx + 0.19, hy, hz - 1.2), (hx + 0.09, hy, hz - 1.7)], 0.018, segs=5, mat='Rubber')
    mb.sphere(0.13, center=(hx, hy, GROUND_Z + 0.56), segs=10, mat='Metal')
    mb.cyl(0.34, 0.14, center=(hx, hy, GROUND_Z + 0.36), segs=20, mat='Hull_Dark', bevel=0.03, bsegs=1)
    for k in range(6):
        a = TAU * k / 6
        mb.rbox((0.20, 0.05, 0.10), center=(hx + 0.30 * math.cos(a), hy + 0.30 * math.sin(a), GROUND_Z + 0.44),
                rot=(0, 0, a), bevel=0.0, mat='Hull_Accent')
    mb.cyl(0.56, 0.24, center=(hx, hy, GROUND_Z + 0.12), segs=24, mat='Rubber', bevel=0.07, bsegs=2)


# ------------------------------------------------------------------------------------------------
# assembly
# ------------------------------------------------------------------------------------------------
def build():
    objs = {}
    hb = MB("Hull")
    fus = fuselage(hb)
    tmpmb = MB("tmp")                                   # groove-free copy used only to project decals
    surf_f = Surf(faces=fuselage(tmpmb, grooves=()).faces)
    tmpmb.bm.free()
    wparts, wsurf, csurf = {}, {}, {}
    for sx in (1, -1):
        wparts[sx] = wing(hb, float(sx))
        wsurf[sx] = Surf(faces=wparts[sx].faces)
        canard(hb, float(sx))
    fin_part = fin(hb)
    spine_part = spine(hb)
    canopy_frame(hb)
    info = hull_details(hb, surf_f, wsurf, csurf, spine_part, fin_part)
    heads = info['heads']
    hull = hb.finish("Hull", coll, smooth_angle=40, weighted=True)
    objs['Hull'] = hull
    mg = MB("Cockpit_Glass")
    canopy_glass(mg)
    glass = mg.finish("Cockpit_Glass", coll, smooth_angle=60, weighted=False)
    parent_keep(glass, hull)
    objs['Cockpit_Glass'] = glass
    mi_ = MB("Cockpit_Interior")
    cockpit_interior(mi_)
    interior = mi_.finish("Cockpit_Interior", coll, smooth_angle=40, weighted=True)
    parent_keep(interior, hull)
    objs['Cockpit_Interior'] = interior
    for sx, side in ((-1.0, 'L'), (1.0, 'R')):
        me = MB("Engine_" + side)
        pp = pod(me, sx)
        ps = Surf(faces=pp.faces)
        pod_details(me, sx, ps)
        nozzle(me, sx)
        eng = me.finish("Engine_" + side, coll, smooth_angle=40, weighted=True)
        parent_keep(eng, hull)
        set_origin(eng, (POD_X * sx, -3.0, POD_Z))
        objs['Engine_' + side] = eng
        mgl = MB("Engine_Glow_" + side)
        prof = [(0.0, -7.22), (0.12, -7.06), (0.28, -6.84), (0.43, -6.64), (0.51, -6.50), (0.0, -6.50)]
        mgl.lathe(prof, 24, MB.xf((POD_X * sx, 0, POD_Z), MB.aim((0, 1, 0))), mat='Emissive_Engine')
        glow = mgl.finish("Engine_Glow_" + side, coll, smooth_angle=60, weighted=False)
        parent_keep(glow, eng)
        set_origin(glow, (POD_X * sx, NOZ_Y_EXIT, POD_Z))
        objs['Engine_Glow_' + side] = glow
    for name, hx, hy in (("Gear_Front", 0.0, 4.35), ("Gear_RearL", -POD_X, -2.6), ("Gear_RearR", POD_X, -2.6)):
        mg_ = MB(name)
        gear_leg(mg_, hx, hy)
        g = mg_.finish(name, coll, smooth_angle=40, weighted=True)
        parent_keep(g, hull)
        set_origin(g, (hx, hy, HINGE_Z))
        objs[name] = g
    # ---- lights
    ws = WING_S
    tip = ws[len(ws) - 4]
    ymid = tip['le'] - 0.40 * (tip['le'] - tip['te'])
    base = Vector(tip['O']) + Vector((0, ymid, 0)) - Vector(tip['N']) * (tip['t'] / 2 + 0.0)
    for sx, nm, m_ in ((-1, 'L', 'Emissive_NavRed'), (1, 'R', 'Emissive_NavGreen')):
        ml = MB("Light_Nav_" + nm)
        pos = Vector((base.x * sx, base.y, base.z))
        ml.sphere(0.085, center=pos, segs=10, mat=m_)
        lt = ml.finish("Light_Nav_" + nm, coll, smooth_angle=60, weighted=False)
        parent_keep(lt, hull)
        set_origin(lt, pos)
        objs['Light_Nav_' + nm] = lt
    top = FIN_S[-1]
    bpos = Vector((0, (top['le'] + top['te']) / 2 + 0.05, top['O'][2] + 0.02))
    mbk = MB("Light_Beacon")
    mbk.hemi(0.09, center=bpos, segs=12, rings=4, mat='Emissive_Beacon')
    mbk.cyl(0.11, 0.05, center=bpos + Vector((0, 0, -0.02)), segs=12, mat='Metal')
    bk = mbk.finish("Light_Beacon", coll, smooth_angle=60, weighted=False)
    parent_keep(bk, hull)
    set_origin(bk, bpos)
    objs['Light_Beacon'] = bk
    # ---- markers
    mk = {}
    mk['Marker_Eye'] = EYE
    mk['Marker_EngineL'] = Vector((-POD_X, NOZ_Y_EXIT, POD_Z))
    mk['Marker_EngineR'] = Vector((POD_X, NOZ_Y_EXIT, POD_Z))
    mk['Marker_Exit'] = Vector((info['hatch'].x - 3.0, 3.45, GROUND_Z))
    mk['Marker_FootFront'] = Vector((0.0, 4.35, GROUND_Z))
    mk['Marker_FootRearL'] = Vector((-POD_X, -2.6, GROUND_Z))
    mk['Marker_FootRearR'] = Vector((POD_X, -2.6, GROUND_Z))
    if 'L' in heads and 'R' in heads:
        mk['Marker_Headlight_L'] = heads['L'][0] + heads['L'][1] * 0.05
        mk['Marker_Headlight_R'] = heads['R'][0] + heads['R'][1] * 0.05
    else:
        mk['Marker_Headlight_L'] = Vector((-0.62, 6.4, -0.40))
        mk['Marker_Headlight_R'] = Vector((0.62, 6.4, -0.40))
    mk['Marker_Hatch'] = info['hatch']
    for nm, pos in mk.items():
        parent = objs['Engine_L'] if nm == 'Marker_EngineL' else (objs['Engine_R'] if nm == 'Marker_EngineR' else hull)
        e = empty(nm, pos, coll, parent=parent, size=0.3)
        objs[nm] = e
    return objs


objs = build()
bpy.context.view_layer.update()
check(COLL_NAME, verbose=True)
park(COLL_NAME)      # keep names unique in the .blend: finished models are parked (suffix __collection), export scripts unpark
