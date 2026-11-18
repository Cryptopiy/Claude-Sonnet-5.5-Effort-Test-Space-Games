"""space_station (brief 3): rotating habitat ring (Ø150 m, spin axis = Blender Z = Godot Y) + 4 spokes + central hub, antennas,
radiator fins, solar wings and a big docking pier ending in a bay whose mouth faces +Y (Marker_Dock).
Nodes: Station (root mesh: hub, pier, bay, solar wings, antennas)  >  Ring (ring + collar + spokes + ports + greebles, origin at the hub
centre, rotation 0)  and  Marker_Dock (empty at the bay mouth, +Y = out of the bay).  Re-runnable (deletes its collection first)."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

palette()
NAME = 'space_station'
coll = fresh_collection(NAME)
HP, HA, HD, MT = 'Hull_Paint', 'Hull_Accent', 'Hull_Dark', 'Metal'
EW, EL, EA, ER, EG, ES = 'Emissive_Window', 'Emissive_Light', 'Emissive_Amber', 'Emissive_NavRed', 'Emissive_NavGreen', 'Emissive_Screen'
SOL, SOLG = 'Solar_Cell', 'Solar_Grid'
rng = random.Random(7)


def box(mb, size, center, mat, bevel=0.0, rot=None, taper=None):
    return mb.rbox(size, center=center, rot=rot, bevel=bevel, bsegs=1, mat=mat, smooth=False, taper=taper)


def lathe_loop(mb, pts, emats, segs, mat_fn=None, smooth=True):
    """closed (r, z) section revolved about Z (torus like).  emats[j] = material of the edge pts[j] -> pts[j+1].  mat_fn(k, j, base)."""
    rings = []
    for k in range(segs):
        th = TAU * k / segs
        c, s = math.cos(th), math.sin(th)
        rings.append([Vector((r * c, r * s, z)) for (r, z) in pts])
    part = mb.grid(rings, closed=True, mat=emats[0], smooth=smooth, outward=False, loop_rings=True)
    mb.fix_outward(part.faces)
    for k, band in enumerate(part.bands):
        for j, f in enumerate(band):
            if f is None:
                continue
            f.material_index = mb.mi(emats[j] if mat_fn is None else mat_fn(k, j, emats[j]))
    return part


def dish(mb, center, axis, R=6.0, depth=1.6, t=0.35, segs=20, mat=HP, inner=MT):
    """parabolic dish bowl (thin shell) opening towards `axis`"""
    ks = [0.0, 0.27, 0.53, 0.78, 1.0]
    prof = [(R * k, depth * k * k, inner) for k in ks]
    prof += [(R, depth - t * 0.4, mat)]
    prof += [(R * k, depth * k * k - t, mat) for k in reversed(ks[:-1])]
    return mb.lathe_mats(prof, segs, MB.xf(center, MB.aim(axis)))


# ------------------------------------------------------------------------------------------------------------------------
# RING (rotating): torus-like section, 96 segments = 16 modules of 6
# ------------------------------------------------------------------------------------------------------------------------
mbR = MB('Ring')
R_OUT, R_IN, HZ = 75.0, 57.0, 7.0
half = [(R_OUT, 0.0, None), (R_OUT, 1.1, HA), (R_OUT, 2.4, HP), (R_OUT, 4.3, EW), (R_OUT, 5.5, HP),
        (R_OUT - 1.4, HZ, HD), (R_IN + 2.0, HZ, HP), (R_IN, HZ - 2.0, HD), (R_IN, 2.4, EW), (R_IN, 0.0, HP)]
pts = [(r, z) for (r, z, m) in half]
emats = [m for (r, z, m) in half[1:]]
for i in range(len(half) - 2, 0, -1):
    pts.append((half[i][0], -half[i][1]))
    emats.append(half[i + 1][2])
emats.append(half[1][2])


def ring_mat(k, j, base):
    if k % 6 == 0:
        if base == HP:
            return HA
        if base == EW:
            return HD
    return base


lathe_loop(mbR, pts, emats, 96, ring_mat)

# collar around the hub housing (rotates with the ring) + 4 ribbed spokes
lathe_loop(mbR, [(9.5, -4.6), (10.6, -4.6), (11.6, -3.6), (11.6, 3.6), (10.6, 4.6), (9.5, 4.6)], [HD, HP, HA, HP, HD, HD], 32)
SP = [(2.3, 0.0, HD), (2.3, 2.6, HD), (3.1, 3.0, HA), (3.1, 5.0, HA), (2.3, 5.4, HP), (2.3, 15.0, HP), (3.0, 15.4, HD), (3.0, 16.8, HD),
      (2.3, 17.2, HP), (2.3, 28.0, HP), (3.0, 28.4, HD), (3.0, 29.8, HD), (2.3, 30.2, HP), (2.3, 40.5, HP), (3.2, 41.0, HA), (3.2, 43.0, HA),
      (2.5, 43.5, HD), (2.5, 48.0, HD)]
for a in (0, 90, 180, 270):
    th = math.radians(a)
    d = Vector((math.cos(th), math.sin(th), 0))
    mbR.lathe_mats(SP, 8, MB.xf(d * 10.5, MB.aim(d)))
    # junction block at the ring wall + service lights on the spoke
    box(mbR, (5.0, 6.4, 6.4), d * 56.2, HD, 0.5, rot=(0, 0, th))
    for h in (10.0, 22.5, 35.0):
        box(mbR, (0.7, 0.7, 0.7), d * (10.5 + h) + Vector((0, 0, 2.6)), EL)

# docking ports on the outer wall (lit frame + hatch) and hull plates on the top / bottom faces
for a in (22.5, 112.5, 202.5, 292.5):
    th = math.radians(a)
    d = Vector((math.cos(th), math.sin(th), 0))
    t_ = Vector((-math.sin(th), math.cos(th), 0))
    box(mbR, (6.0, 9.0, 6.0), d * 77.6, HP, 0.35, rot=(0, 0, th))
    box(mbR, (0.6, 7.0, 4.4), d * 80.7, HD, 0.15, rot=(0, 0, th))
    for s_ in (-1, 1):
        box(mbR, (0.5, 0.9, 0.9), d * 81.1 + t_ * (2.9 * s_) + Vector((0, 0, 2.3)), EL, rot=(0, 0, th))
        box(mbR, (0.5, 0.9, 0.9), d * 81.1 + t_ * (2.9 * s_) + Vector((0, 0, -2.3)), EA, rot=(0, 0, th))
    box(mbR, (0.7, 8.0, 0.7), d * 81.1 + Vector((0, 0, 3.4)), HA, rot=(0, 0, th))
for i in range(52):
    th = rng.uniform(0, TAU)
    r = rng.uniform(61.0, 71.5)
    sd = 1 if i % 2 == 0 else -1
    sx, sy, sz = rng.uniform(1.8, 4.4), rng.uniform(1.4, 3.6), rng.uniform(0.5, 1.4)
    c = Vector((r * math.cos(th), r * math.sin(th), sd * (HZ + sz / 2 - 0.05)))
    box(mbR, (sx, sy, sz), c, rng.choice([HD, MT, HA, HP, HD]), 0.12, rot=(0, 0, th + rng.choice([0.0, PI / 2])))

ring_ob = mbR.finish('Ring', coll, smooth_angle=35, weighted=True)

# ------------------------------------------------------------------------------------------------------------------------
# STATION root mesh: hub, pier + bay, solar wings, antennas, fins
# ------------------------------------------------------------------------------------------------------------------------
mbS = MB('Station')
HUB = [(0.0, -36.0, HD), (4.0, -36.0, HD), (5.6, -33.5, HP), (5.6, -26.0, HP), (6.5, -25.0, HA), (6.5, -22.0, HA), (5.6, -21.0, HP),
       (5.6, -13.5, HP), (8.9, -12.5, HD), (9.0, -11.5, HP), (9.0, -5.2, HP), (8.7, -4.6, HD), (8.7, 4.6, HD), (9.0, 5.2, HP), (9.0, 11.5, HP),
       (8.9, 12.5, HD), (5.6, 13.5, HP), (5.6, 19.0, HP), (6.4, 20.0, HA), (6.4, 26.0, HA), (5.6, 27.0, HP), (5.6, 40.0, HP), (4.6, 41.0, HD),
       (4.0, 44.0, HP), (0.0, 44.0, HP)]
mbS.lathe_mats(HUB, 28, MB.xf((0, 0, 0)), cap_a=False, cap_b=False)
# lower radiator fins
for i in range(8):
    th = TAU * (i + 0.5) / 8
    d = Vector((math.cos(th), math.sin(th), 0))
    box(mbS, (7.6, 0.5, 7.0), d * 9.2 + Vector((0, 0, -29.6)), HP, 0.08, rot=(0, 0, th))
    box(mbS, (7.7, 0.6, 0.9), d * 9.2 + Vector((0, 0, -26.4)), HA, 0.06, rot=(0, 0, th))
# sensor pods on the hub
for a, z in ((60, 8.0), (200, -17.0), (320, 16.5)):
    th = math.radians(a)
    d = Vector((math.cos(th), math.sin(th), 0))
    box(mbS, (3.0, 3.6, 2.6), d * 7.4 + Vector((0, 0, z)), HP, 0.3, rot=(0, 0, th))
    mbS.cyl(0.8, 0.8, center=d * 9.2 + Vector((0, 0, z)), segs=10, mat=HD, rot=MB.aim(d))

# solar wings: cross boom at z=-22 (the arrays turn about it), 3 panels each side, tilted so they read from the top and from the side
mbS.cyl(0.85, 112.0, center=(0, 0, -22.0), segs=8, mat=MT, rot=MB.aim((1, 0, 0)))


def pbox(M, size, local_c, mat, bevel=0.0):
    box(mbS, size, M @ Vector(local_c), mat, bevel, rot=M.to_3x3())


for sx_, tilt in ((-1, 48.0), (1, 38.0)):
    x0 = 9.0
    for i in range(3):
        M = Matrix.Translation((sx_ * (x0 + 7.6 + i * 16.2), 0, -22.0)) @ Matrix.Rotation(math.radians(tilt), 4, 'X')
        pbox(M, (15.0, 0.5, 16.0), (0, 0, 0), SOL, 0.1)
        for fy in (-1, 1):
            y = fy * 0.3
            pbox(M, (15.4, 0.26, 0.5), (0, y, 8.0), MT)
            pbox(M, (15.4, 0.26, 0.5), (0, y, -8.0), MT)
            pbox(M, (0.5, 0.26, 16.4), (-7.7, y, 0), MT)
            pbox(M, (0.5, 0.26, 16.4), (7.7, y, 0), MT)
            for gx in (-2.5, 2.5):
                pbox(M, (0.26, 0.2, 15.2), (gx, fy * 0.27, 0), SOLG)
            pbox(M, (14.4, 0.2, 0.26), (0, fy * 0.27, 0), SOLG)
        pbox(M, (1.0, 1.0, 2.0), (0, 0, 0), MT)          # hinge block
box(mbS, (2.4, 2.4, 7.0), (0, 0, -22.0), HD, 0.3)

# antennas on the top of the hub
mbS.cyl(0.9, 10.0, center=(0, 0, 49.0), segs=8, mat=MT)
adir = Vector((-0.8, -0.25, 0.55)).normalized()
dish(mbS, Vector((0, 0, 53.0)) + adir * 0.5, adir, R=6.2, depth=1.7)
mbS.cyl(0.25, 4.6, center=Vector((0, 0, 53.0)) + adir * 2.4, segs=6, mat=MT, rot=MB.aim(adir))
mbS.sphere(0.7, center=Vector((0, 0, 53.0)) + adir * 4.8, segs=8, mat=EL)
for sx_, sy_ in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
    mbS.cyl(0.28, 22.0, center=(sx_ * 1.6, sy_ * 1.6, 55.0), segs=5, mat=MT)
for z in (47.0, 53.0, 59.0, 65.0):
    box(mbS, (3.8, 3.8, 0.35), (0, 0, z), HP)
box(mbS, (3.2, 3.2, 2.0), (0, 0, 67.0), HD, 0.2)
mbS.cyl(0.18, 16.0, center=(0, 0, 76.0), segs=5, mat=MT)
mbS.sphere(0.5, center=(0, 0, 84.4), segs=6, mat=ER)
for a in (35, 155, 275):
    th = math.radians(a)
    d = Vector((math.cos(th), math.sin(th), 0))
    mbS.cyl(0.14, 11.0, center=d * 4.6 + Vector((0, 0, 47.5)), segs=4, mat=MT, rot=MB.aim(Vector((d.x * 0.45, d.y * 0.45, 1.0))))
# a few boxes + conduits on the upper hub
for a, z in ((90, 30.0), (210, 36.0), (330, 31.0)):
    th = math.radians(a)
    d = Vector((math.cos(th), math.sin(th), 0))
    box(mbS, (2.4, 4.2, 3.2), d * 6.4 + Vector((0, 0, z)), HD, 0.25, rot=(0, 0, th))

# docking pier + bay (mouth faces +Y)
ZC = 33.0
box(mbS, (6.0, 70.0, 6.0), (0, 38.0, ZC), HP, 0.45)
for y in (14.0, 30.0, 46.0, 62.0):
    box(mbS, (6.5, 1.2, 6.5), (0, y, ZC), HA, 0.2)
box(mbS, (2.0, 64.0, 1.0), (0, 38.0, ZC + 3.3), HD, 0.15)
for sx_ in (-1, 1):
    mbS.tube([(sx_ * 3.6, 6.0, ZC - 2.0), (sx_ * 3.6, 66.0, ZC - 2.0)], 0.35, segs=5, mat=MT)
mbS.tube([(0, 5.0, 22.0), (0, 42.0, ZC - 3.0)], 0.9, segs=6, mat=MT)
mbS.tube([(0, 4.0, 43.0), (0, 38.0, ZC + 3.2)], 0.7, segs=6, mat=MT)
mbS.tube([(0, 14.0, ZC - 3.0), (0, 14.0, 21.0)], 0.5, segs=5, mat=MT)

BX, BY0, BY1 = 15.0, 70.0, 106.0
BL = BY1 - BY0
BYC = (BY0 + BY1) / 2
ZF, ZT = ZC - 12.0, ZC + 12.0            # bay outer floor / ceiling
box(mbS, (2 * BX, BL, 4.5), (0, BYC, ZF + 2.25), HP, 0.4)
box(mbS, (2 * BX, BL, 4.5), (0, BYC, ZT - 2.25), HP, 0.4)
for sx_ in (-1, 1):
    box(mbS, (4.5, BL, 15.0), (sx_ * (BX - 2.25), BYC, ZC), HP, 0.4)
box(mbS, (21.0, 2.0, 15.0), (0, BY0 + 2.0, ZC), HD, 0.2)
# interior: guide light rails, ceiling light strips, back wall screen
zf_in = ZF + 4.5
for sx_ in (-1, 1):
    for i in range(9):
        y = BY0 + 5.0 + i * 3.6
        box(mbS, (0.9, 1.6, 0.3), (sx_ * 6.5, y, zf_in + 0.12), EL)
        box(mbS, (0.4, 1.2, 0.8), (sx_ * (BX - 4.5) + sx_ * -0.2, y, zf_in + 0.4), EL)
box(mbS, (1.0, BL - 6.0, 0.2), (0, BYC - 0.5, zf_in + 0.08), EA)
box(mbS, (15.0, 0.3, 6.0), (0, BY0 + 3.1, ZC + 0.5), ES)
for sx_ in (-1, 1):
    box(mbS, (1.4, BL - 8.0, 0.3), (sx_ * 5.0, BYC, ZT - 4.5 - 0.1), EW)
# mouth frame with hazard stripes + nav lights
FY = BY1 + 0.4
for i in range(12):
    xc = -BX - 1.2 + (2 * BX + 2.4) * (i + 0.5) / 12
    m_ = HA if i % 2 == 0 else HD
    box(mbS, ((2 * BX + 2.4) / 12, 2.4, 2.4), (xc, FY, ZT + 0.9), m_)
    box(mbS, ((2 * BX + 2.4) / 12, 2.4, 2.4), (xc, FY, ZF - 0.9), m_)
for i in range(7):
    zc_ = ZF + 1.5 + (ZT - ZF - 3.0) * (i + 0.5) / 7
    m_ = HA if i % 2 == 0 else HD
    for sx_ in (-1, 1):
        box(mbS, (2.4, 2.4, (ZT - ZF - 3.0) / 7), (sx_ * (BX + 0.0), FY, zc_), m_)
for sx_, m_ in ((-1, ER), (1, EG)):
    for z in (ZF - 1.0, ZT + 1.0):
        box(mbS, (1.4, 1.4, 1.4), (sx_ * (BX + 1.9), FY + 0.5, z), m_)
for sx_ in (-1, 1):
    for i in range(3):
        box(mbS, (0.7, 0.7, 0.7), (sx_ * (BX - 3.0), BY1 - 6.0 - i * 9.0, ZT + 0.2), EL)
box(mbS, (8.0, 0.5, 1.6), (0, FY + 1.3, ZT + 1.8), EL)
# dish-less beacon masts on top of the bay
for sx_ in (-1, 1):
    mbS.cyl(0.25, 7.0, center=(sx_ * 10.0, 96.0, ZT + 3.5), segs=5, mat=MT)
    mbS.sphere(0.6, center=(sx_ * 10.0, 96.0, ZT + 7.2), segs=8, mat=ER if sx_ < 0 else EG)

# bay hull detail: dark service panels, orange belt, vents and a few small antennas
for sx_ in (-1, 1):
    for i in range(4):
        y = BY0 + 5.0 + i * 8.5
        box(mbS, (0.35, 6.0, 5.5), (sx_ * (BX + 0.12), y, ZC + 1.0), HD, 0.1)
        box(mbS, (0.3, 5.0, 0.5), (sx_ * (BX + 0.28), y, ZC - 1.0), HP)
    box(mbS, (0.4, BL - 2.0, 1.2), (sx_ * (BX + 0.1), BYC, ZC - 5.2), HA)
for i in range(5):
    box(mbS, (6.0, 0.35, 3.0), (rng.uniform(-6, 6), 76.0 + i * 6.2, ZT + 0.1), HD, 0.1, rot=(0, 0, rng.choice([0, 0.2, -0.2])))
box(mbS, (3.0, BL - 6.0, 0.4), (0, BYC - 2.0, ZT + 0.05), HA)
box(mbS, (3.4, 3.4, 2.2), (0, 80.0, ZT + 1.2), HP, 0.3)
for i in range(3):
    mbS.cyl(0.12, 5.0 + i * 2.0, center=(-3.0 + i * 3.0, 78.0 + i, ZT + 3.5 + i), segs=4, mat=MT)

stn_ob = mbS.finish('Station', coll, smooth_angle=35, weighted=True)
parent_keep(ring_ob, stn_ob)
mk = empty('Marker_Dock', (0.0, BY1 + 0.6, ZC), coll, parent=stn_ob, size=6.0, kind='ARROWS')

print('built', NAME, [o.name for o in coll.all_objects])
