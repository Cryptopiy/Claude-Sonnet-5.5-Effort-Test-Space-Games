"""wreck_ship - crashed small ship, ~10 m: torn plating exposing ribs, bent left wing, broken right wing stub, one engine missing,
scorched paint, glowing embers; tilted (~14 deg nose-up, ~6 deg roll) with the ORIGIN at its lowest centre point (meant to sit half buried).
Nose points to +Y before the tilt.  Single mesh 'wreck_ship'.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
COLL_NAME = "wreck_ship"
coll = fresh_collection(COLL_NAME)
rng = random.Random(21)
NC = 28
Y_NOSE, Y_N0 = 5.2, 3.4
_ky = [-4.6, -3.6, -2.0, 0.0, 2.0, Y_N0]
_W = pchip(_ky, [0.95, 1.12, 1.28, 1.30, 1.15, 0.92])
_ZT = pchip(_ky, [0.55, 0.80, 0.92, 0.88, 0.66, 0.42])
_ZB = pchip(_ky, [-0.72, -0.92, -1.0, -1.0, -0.92, -0.72])


def hash01(a, b=0.0, c=0.0):
    x = math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
    return x - math.floor(x)


def fus_dims(y):
    if y <= Y_N0:
        return _W(y), _ZT(y), _ZB(y)
    u = (y - Y_N0) / (Y_NOSE - Y_N0)
    f = max(0.0, 1 - u ** 2.0) ** 0.5
    zc0 = (_ZT(Y_N0) + _ZB(Y_N0)) / 2
    zc = lerp(zc0, -0.35, u * u)
    return _W(Y_N0) * f, zc + (_ZT(Y_N0) - zc0) * f, zc - (zc0 - _ZB(Y_N0)) * f


def fus_ring(y, scale=1.0, ncols=NC):
    w, zt, zb = fus_dims(y)
    zeq = zb + 0.46 * (zt - zb)
    pts = []
    for k in range(ncols):
        th = TAU * k / ncols
        c, s = math.cos(th), math.sin(th)
        n = 3.6 if s >= 0 else 4.4
        x = w * spow(c, 2.0 / n)
        z = zeq + (zt - zeq) * (abs(s) ** (2.0 / n)) if s >= 0 else zeq - (zeq - zb) * (abs(s) ** (2.0 / n))
        pts.append(Vector((x * scale, y, zeq + (z - zeq) * scale)))
    return pts


def hull_top_z(x, y):
    w, zt, zb = fus_dims(y)
    zeq = zb + 0.46 * (zt - zb)
    r = min(abs(x) / max(w, 1e-6), 0.999)
    return zeq + (zt - zeq) * (1 - r ** 3.6) ** (1 / 3.6)


# ---------------------------------------------------------------------------------------------
HOLES = [dict(th=12.0, y=-0.6, hth=52.0, hy=1.85, name='A'), dict(th=128.0, y=-3.15, hth=24.0, hy=0.75, name='B')]


def in_hole(k, y):
    th = (k + 0.5) * 360.0 / NC
    thd = ((th + 180.0) % 360.0) - 180.0
    for h in HOLES:
        d = (abs(thd - h['th']) / h['hth']) ** 2.6 + (abs(y - h['y']) / h['hy']) ** 2.6
        d += 0.30 * (hash01(k * 1.37, y * 3.1) - 0.5)
        if d < 1.0:
            return True
    return False


def fuselage(mb):
    ylist = [-4.6, -4.5, -4.1]
    y = -3.7
    while y < Y_N0 - 0.05:
        ylist.append(round(y, 3))
        y += 0.4
    ylist.append(Y_N0)
    nn = 7
    for j in range(1, nn + 1):
        ylist.append(Y_N0 + (Y_NOSE - Y_N0) * math.sin(PI / 2 * j / nn))
    rings = [fus_ring(y) for y in ylist]
    part = mb.loft(rings, mat='Hull_Paint', cap_a=True, cap_b=False, cap_kind='ngon')
    part.ylist = ylist
    # painted flank stripe
    acc = mb.mi('Hull_Accent')
    for bi in range(len(part.bands)):
        yb = (ylist[bi] + ylist[bi + 1]) / 2
        for k in (1, 2, NC // 2 - 3, NC // 2 - 2):
            f = part.bands[bi][k]
            if f is not None and -3.4 < yb < 3.3:
                f.material_index = acc
    # belly dark
    for bi in range(len(part.bands)):
        for k in range(int(NC * 0.58), int(NC * 0.92)):
            f = part.bands[bi][k]
            if f is not None:
                f.material_index = mb.mi('Hull_Dark')
    # carve the tears
    kill = []
    for bi in range(len(part.bands)):
        yb = (ylist[bi] + ylist[bi + 1]) / 2
        for k in range(NC):
            f = part.bands[bi][k]
            if f is not None and in_hole(k, yb):
                kill.append(f)
    bmesh.ops.delete(mb.bm, geom=kill, context='FACES')
    # jagged boundary: bend the plating, then build lips
    bm = mb.bm
    bverts = set()
    for e in bm.edges:
        if len(e.link_faces) == 1:
            bverts.add(e.verts[0])
            bverts.add(e.verts[1])
    for v in bverts:
        if not v.is_valid:
            continue
        n = v.normal if v.normal.length > 0 else Vector((0, 0, 1))
        r = hash01(v.co.x * 9.1, v.co.y * 7.3, v.co.z * 5.9)
        v.co += n * (0.16 * (r - 0.25)) + Vector((0, 0.12 * (hash01(v.co.y * 3.3, v.co.z) - 0.5), 0))
    dark = mb.mi('Hull_Dark')
    inner = {}
    lip_faces = []
    for e in [e for e in bm.edges if len(e.link_faces) == 1]:
        f = e.link_faces[0]
        f.normal_update()
        a, b = e.verts
        for v in (a, b):
            if v not in inner:
                nrm = v.normal if v.normal.length > 0 else f.normal
                inner[v] = bm.verts.new(v.co - nrm.normalized() * 0.055)
        try:
            q = bm.faces.new((a, b, inner[b], inner[a]))
        except ValueError:
            continue
        q.material_index = dark
        q.smooth = False
        lip_faces.append(q)
    # orient lips towards the hole centre
    for q in lip_faces:
        q.normal_update()
        c = q.calc_center_median()
        H = Vector((1.3, -0.6, -0.1)) if c.y > -2.2 else Vector((-0.5, -3.15, 0.7))
        if q.normal.dot(H - c) < 0 and c.y > -2.2:
            q.normal_flip()
        elif q.normal.dot(H - c) < 0:
            q.normal_flip()
    return part


# ---------------------------------------------------------------------------------------------
def airfoil_loft(mb, stations, n_half=8, t_ratio=0.12, te=0.012, flat_bottom=0.3, mat='Hull_Paint', sx=1.0, jag=0.0, cap_b=True):
    af = airfoil(n_half, t_ratio, te=te, flat_bottom=flat_bottom)
    tmax = max(z for (_, z) in af) - min(z for (_, z) in af)
    rings = []
    for i, s in enumerate(stations):
        O = Vector((s['O'][0] * sx, s['O'][1], s['O'][2]))
        N = Vector((s['N'][0] * sx, s['N'][1], s['N'][2])).normalized()
        chord = s['le'] - s['te']
        zs = s['t'] / tmax
        ring = []
        for k, (xc, zc) in enumerate(af):
            y = s['le'] - xc * chord
            p = O + Vector((0, y, 0)) + N * (zc * zs)
            if jag and i == len(stations) - 1:
                p += Vector((0.20 * (hash01(k, 1.0) - 0.5), 0.30 * (hash01(k, 2.0) - 0.5), 0.14 * (hash01(k, 3.0) - 0.5))) * jag
            ring.append(p)
        rings.append(ring)
    return mb.loft(rings, mat=mat, cap_a=True, cap_b=cap_b, cap_kind='fan')


def wing_left(mb):
    """left wing (-X): straight, then bent down ~38 deg and sheared off"""
    pan = [(0.9, -0.30, 1.6, -3.9, 0.55), (1.9, -0.28, 0.5, -3.8, 0.45), (3.0, -0.25, -0.6, -3.6, 0.34)]
    S = []
    a0 = rad(3)
    for (x, z, le, te, t) in pan:
        S.append(dict(O=(x, 0, z), N=(-math.sin(a0), 0, math.cos(a0)), le=le, te=te, t=t))
    R = 0.9
    x0, z0 = pan[-1][0], pan[-1][1]
    a1 = rad(-40)
    for j in range(1, 6):
        a = lerp(a0, a1, j / 5)
        x = x0 + R * (math.sin(a) - math.sin(a0))
        z = z0 + R * (math.cos(a0) - math.cos(a))
        S.append(dict(O=(x, 0, z), N=(-math.sin(a), 0, math.cos(a)), le=lerp(-0.6, -1.2, j / 5), te=lerp(-3.6, -3.4, j / 5), t=lerp(0.34, 0.26, j / 5)))
    T = Vector((math.cos(a1), 0, math.sin(a1)))
    base = Vector(S[-1]['O'])
    for j in range(1, 3):
        p = base + T * (0.55 * j)
        S.append(dict(O=(p.x, 0, p.z), N=(-math.sin(a1), 0, math.cos(a1)), le=lerp(-1.2, -1.6, j / 2), te=-3.3, t=0.22))
    part = airfoil_loft(mb, S, sx=-1.0, jag=1.0)
    dark = mb.mi('Hull_Dark')
    ncol = len(part.bands[0])
    for bi in range(len(part.bands)):
        for k in range(8, ncol):
            f = part.bands[bi][k]
            if f is not None:
                f.material_index = dark
    return part, S


def wing_right_stub(mb):
    pan = [(0.9, -0.30, 1.6, -3.9, 0.55), (1.6, -0.29, 0.95, -3.85, 0.50), (2.1, -0.28, 0.45, -3.8, 0.46)]
    S = []
    a0 = rad(3)
    for (x, z, le, te, t) in pan:
        S.append(dict(O=(x, 0, z), N=(-math.sin(a0), 0, math.cos(a0)), le=le, te=te, t=t))
    part = airfoil_loft(mb, S, sx=1.0, jag=1.4)
    dark = mb.mi('Hull_Dark')
    for bi in range(len(part.bands)):
        for k in range(8, len(part.bands[0])):
            f = part.bands[bi][k]
            if f is not None:
                f.material_index = dark
    # spars and ribs sticking out of the broken end
    end = Vector(S[-1]['O'])
    for (dy, dz, ln) in ((0.5, 0.0, 0.7), (-1.2, 0.02, 0.45), (-2.6, -0.02, 0.9)):
        mb.tube([end + Vector((0.0, dy - 0.3, dz)), end + Vector((ln, dy - 0.3 + 0.1 * ln, dz - 0.1 * ln))], 0.035, segs=5, mat='Hull_Dark')
    for dy in (0.3, -1.6):
        mb.tube([end + Vector((0.05, dy, 0.08)), end + Vector((0.05, dy - 1.0, 0.08))], 0.028, segs=5, mat='Metal', cap_a=True, cap_b=True)
    return part


# ---------------------------------------------------------------------------------------------
POD_X, POD_Z = 1.95, -0.30


def engine_left(mb):
    cx = -POD_X
    prof = [(0.50, 0.45, 'Hull_Dark'), (0.52, 0.62, 'Hull_Dark'), (0.60, 0.66, 'Hull_Accent'), (0.62, 0.40, 'Hull_Paint'),
            (0.64, -0.60, 'Hull_Paint'), (0.62, -2.40, 'Hull_Paint'), (0.60, -2.45, 'Hull_Dark'), (0.58, -3.80, 'Hull_Dark'),
            (0.55, -4.15, 'Hull_Dark'), (0.50, -4.35, 'Hull_Dark'), (0.47, -4.70, 'Hull_Dark'), (0.54, -5.00, 'Metal'), (0.62, -5.22, 'Metal'),
            (0.55, -5.22, 'Hull_Dark'), (0.42, -4.92, 'Hull_Dark'), (0.34, -4.45, 'Hull_Dark')]
    segs = 24
    rings = [[Vector((cx + r * math.cos(TAU * k / segs), y, POD_Z + r * math.sin(TAU * k / segs))) for k in range(segs)] for (r, y, m_) in prof]
    part = mb.loft(rings, mat='Hull_Paint', cap_a=True, cap_b=True, cap_kind='ngon')
    for bi in range(len(part.bands)):
        mi = mb.mi(prof[bi + 1][2])
        for f in part.bands[bi]:
            if f is not None:
                f.material_index = mi
    # dent on the outer side + cracked nozzle lip
    dc = Vector((cx - 0.55, -1.3, POD_Z + 0.1))
    for v in part.verts:
        d = (v.co - dc).length
        if d < 0.7:
            v.co += Vector((0.16 * (1 - d / 0.7), 0, -0.05 * (1 - d / 0.7)))
    kill = [part.bands[11][k] for k in (3, 4, 5, 15, 16)]
    bmesh.ops.delete(mb.bm, geom=[f for f in kill if f is not None], context='FACES')
    return part


def engine_right_stub(mb):
    cx = POD_X
    # broken mount: pylon block, torn skin and two exposed ring frames with dangling wires
    mb.rbox((0.7, 1.6, 0.5), center=(cx - 0.35, -0.5, POD_Z - 0.1), bevel=0.06, bsegs=1, mat='Hull_Dark')
    for (y, r) in ((-0.2, 0.55), (-1.1, 0.5)):
        mb.torus(r, 0.035, center=(cx + 0.1, y, POD_Z), segs=18, tsegs=5, rot=(PI / 2, 0, 0), mat='Metal', a0=rad(-60), a1=rad(230))
    for k in range(4):
        a = rad(-40 + k * 85)
        mb.tube([(cx + 0.1, -0.2, POD_Z + 0.5 * math.sin(a)), (cx + 0.1, -1.1, POD_Z + 0.48 * math.sin(a) + 0.02)], 0.03, segs=5, mat='Metal')
    pts = [(cx + 0.12, -0.5, POD_Z - 0.1), (cx + 0.55, -0.6, POD_Z - 0.35), (cx + 0.7, -0.4, POD_Z - 0.9), (cx + 0.55, -0.3, POD_Z - 1.45)]
    mb.tube(pts, 0.022, segs=5, mat='Rubber')
    pts = [(cx + 0.1, -1.0, POD_Z + 0.2), (cx + 0.45, -1.15, POD_Z - 0.2), (cx + 0.5, -1.0, POD_Z - 0.85)]
    mb.tube(pts, 0.02, segs=5, mat='Rubber')


# ---------------------------------------------------------------------------------------------
def tail_fin(mb):
    S = []
    n = 5
    for j in range(n + 1):
        u = j / n
        S.append(dict(O=(0.0 + 0.35 * u * u, 0, 0.55 + 1.5 * u), N=(1, 0, 0), le=lerp(-1.2, -3.4, u ** 1.1), te=lerp(-4.1, -4.3, u), t=lerp(0.34, 0.14, u)))
    part = airfoil_loft(mb, S, n_half=6, sx=1.0, jag=1.6, mat='Hull_Paint')
    for bi in range(3, len(part.bands)):
        for f in part.bands[bi]:
            if f is not None:
                f.material_index = mb.mi('Hull_Dark')
    return part


def cockpit(mb):
    """broken canopy frame + remains of the seat and console"""
    y0, y1, W = 1.1, 3.6, 0.78
    for (y, brk) in ((1.55, 0), (2.35, 1), (3.1, 2)):
        zt = hull_top_z(0, y) + 1.0 - 0.15 * abs(y - 2.2)
        pts = []
        for j in range(11):
            ph = PI * j / 10
            x = W * math.cos(ph) * (1 - 0.18 * abs(y - 2.2))
            z = hull_top_z(x, y) - 0.04 + (zt - hull_top_z(0, y)) * (math.sin(ph) ** 0.9)
            pts.append(Vector((x, y, z)))
        if brk == 1:
            pts = pts[:6]
            pts = [p + Vector((0.0, 0.0, 0.0)) for p in pts]
            pts[-1] = pts[-1] + Vector((-0.15, 0.2, 0.1))
        if brk == 2:
            pts = pts[4:]
            pts = [p + Vector((0.2 * (i / len(pts)), -0.1 * (i / len(pts)), -0.08 * i / len(pts))) for i, p in enumerate(pts)]
        mb.tube(pts, 0.035, segs=5, mat='Hull_Dark')
    # rim fragments
    rim = [Vector((0.8 * math.cos(a), 1.2 + 2.3 * (0.5 + 0.5 * math.sin(a)), hull_top_z(0.8 * math.cos(a), 1.2 + 2.3 * (0.5 + 0.5 * math.sin(a))) + 0.05))
           for a in [rad(d) for d in range(-90, 100, 14)]]
    mb.tube(rim[:8], 0.05, segs=6, mat='Hull_Paint')
    # seat remains + console
    dk = hull_top_z(0, 2.1)
    mb.rbox((0.5, 0.5, 0.14), center=(0.0, 2.05, dk + 0.1), bevel=0.04, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.52, 0.12, 0.7), center=(0.0, 1.75, dk + 0.45), rot=(rad(-18), 0, rad(6)), bevel=0.04, bsegs=1, mat='Hull_Accent')
    mb.rbox((1.1, 0.6, 0.35), center=(0.0, 3.05, dk + 0.16), rot=(0, 0, rad(-4)), bevel=0.04, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.4, 0.03, 0.2), center=(-0.2, 2.74, dk + 0.34), rot=(rad(-25), 0, 0), bevel=0.0, mat='Hull_Dark')


def inner_liner(mb):
    """inward-facing inner skin (dark) so the torn openings are not see-through"""
    ylist = [-4.45, -3.6, -2.8, -2.0, -1.2, -0.4, 0.4, 1.2, 2.0, 2.8, Y_N0]
    rings = [fus_ring(y, 0.955) for y in ylist]
    part = mb.loft(rings, mat='Hull_Dark', cap_a=True, cap_b=True, cap_kind='fan', )
    for f in part.faces:
        f.normal_flip()
        f.smooth = False
    return part


def interior(mb):
    """ribs, stringers and equipment visible through the big flank tear"""
    for y in (-2.0, -1.2, -0.4, 0.4, 1.0):
        pts = [fus_ring(y, 0.965)[k % NC] for k in range(-9, 11)]
        mb.tube(pts, 0.05, segs=5, mat='Metal')
    for th_k in (0, 2, 4, 26):
        pts = [fus_ring(y, 0.965)[th_k % NC] for y in (-2.4, -1.6, -0.8, 0.0, 0.8, 1.3)]
        mb.tube(pts, 0.035, segs=5, mat='Metal')
    mb.rbox((1.5, 3.6, 0.07), center=(0.0, -0.55, -0.52), rot=(rad(2), 0, 0), bevel=0.01, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.6, 0.8, 0.5), center=(-0.35, -1.0, -0.2), rot=(0, 0, rad(10)), bevel=0.04, bsegs=1, mat='Hull_Paint')
    mb.cyl(0.25, 0.9, center=(0.25, 0.2, -0.15), segs=12, mat='Metal', rot=(PI / 2, rad(8), 0))
    mb.rbox((0.4, 0.5, 0.4), center=(0.4, -1.8, -0.2), rot=(0, rad(8), rad(-14)), bevel=0.03, bsegs=1, mat='Hull_Accent')
    # hanging cables from the edge of the tear
    for k, (x, y, z) in enumerate(((1.15, 0.9, 0.55), (1.25, -1.9, 0.5), (1.3, -0.3, -0.75), (-0.6, -3.1, 0.85))):
        p0 = Vector((x, y, z))
        pts = [p0, p0 + Vector((0.15, 0.05, -0.25)), p0 + Vector((0.35, 0.1 * (k - 1.5), -0.65)), p0 + Vector((0.4 + 0.1 * k, 0.2, -1.1))]
        mb.tube(pts, 0.022, segs=5, mat='Rubber')


def embers(mb, part):
    pts = []
    for e in mb.bm.edges:
        if len(e.link_faces) == 1:
            pts.append((e.verts[0].co + e.verts[1].co) / 2)
    rng.shuffle(pts)
    n = 0
    for p in pts:
        if n >= 10:
            break
        if hash01(p.x * 5.1, p.y * 3.7, p.z * 2.3) > 0.35:
            continue
        mb.sphere(0.05 + 0.05 * rng.random(), center=p + Vector((0, 0, 0.0)), segs=8, mat='Emissive_Light')
        n += 1
    for k in range(8):
        a = rng.random() * TAU
        p = Vector((1.3 + 0.9 * math.cos(a), -0.8 + 1.8 * math.sin(a), -0.2 + 0.7 * rng.random()))
        mb.rbox((0.045, 0.045, 0.045), center=p, rot=(rng.random() * 3, rng.random() * 3, rng.random() * 3), bevel=0.0, mat='Emissive_Light')
    mb.sphere(0.12, center=(POD_X + 0.3, -0.9, POD_Z - 0.2), segs=8, mat='Emissive_Light')


def scorch(mb):
    centres = [Vector((1.4, -0.6, 0.0)), Vector((-0.4, -3.2, 0.7)), Vector((0.0, 5.0, -0.3)), Vector((-1.95, -2.0, -0.3)), Vector((POD_X, -0.9, POD_Z))]
    paint = mb.mi('Hull_Paint')
    acc = mb.mi('Hull_Accent')
    dark = mb.mi('Hull_Dark')
    for f in mb.bm.faces:
        if f.material_index not in (paint, acc):
            continue
        c = f.calc_center_median()
        prox = max(math.exp(-((c - q).length ** 2) / (2 * 1.7 ** 2)) for q in centres)
        n_ = 0.5 + 0.25 * math.sin(1.3 * c.x + 0.7 * c.z) + 0.25 * math.sin(1.9 * c.y - 0.8 * c.x + 1.0)
        s = 0.45 * n_ + 0.62 * prox + (0.12 if c.z < -0.6 else 0.0)
        if s > 0.86:
            f.material_index = dark
        elif s > 0.70 and f.material_index == acc:
            f.material_index = paint


def build():
    mb = MB("wreck_ship")
    fus = fuselage(mb)
    wl, _ = wing_left(mb)
    wing_right_stub(mb)
    engine_left(mb)
    engine_right_stub(mb)
    tail_fin(mb)
    cockpit(mb)
    inner_liner(mb)
    interior(mb)
    embers(mb, fus)
    scorch(mb)
    ob = mb.finish("wreck_ship", coll, smooth_angle=45, weighted=False)
    # tilt: nose up ~14 deg, roll ~6 deg, then drop so the lowest point sits at z=0 and centre it there
    M = Matrix.Rotation(rad(14), 4, 'X') @ Matrix.Rotation(rad(-6), 4, 'Y')
    me = ob.data
    me.transform(M)
    me.update()
    lo = min(v.co.z for v in me.vertices)
    low = [v.co for v in me.vertices if v.co.z < lo + 0.25]
    cx = sum(p.x for p in low) / len(low)
    cy = sum(p.y for p in low) / len(low)
    me.transform(Matrix.Translation((-cx, -cy, -lo)))
    me.update()
    return ob


set_material_overrides({'Emissive_Light': dict(color='#FFB070', emit='#FF6A10', emit_strength=4.5, rough=0.5),
                        'Hull_Paint': dict(color='#8A867F', metal=0.3, rough=0.84),
                        'Hull_Accent': dict(color='#B4561F', metal=0.25, rough=0.8)})
ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
restore_materials()
park(COLL_NAME)
