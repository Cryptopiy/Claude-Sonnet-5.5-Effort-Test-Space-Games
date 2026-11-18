"""Brief 3 creatures: creature_grazer, creature_flyer, creature_floater, creature_crawler.
Node names / pivots / hierarchy follow scripts/world/fauna.gd (the game rotates the named joint nodes):
  grazer : Body > Head (neck pivot), Tail (tail root pivot), Leg_FL / Leg_FR / Leg_BL / Leg_BR (hip pivots; swing about X)
  flyer  : Body > Wing_L (-X) / Wing_R (+X) (pivot at the wing root on the body side; flap = rotation about Y Blender), Tail
  floater: Bell (pivot = bell centre) > Tentacle_01 .. Tentacle_08 (pivot at the rim attachment point, hang ~4 m down)
  crawler: Body > Leg_1 .. Leg_6 (hip pivots; 1/3/5 left front->back, 2/4/6 right)
Front = +Y, origin = ground contact below the body centre (grazer, crawler) / body centre (flyer, floater).  ONLY=[names] builds a subset."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib_creature.py', encoding='utf-8').read(), 'libc', 'exec'))

nature_palette()
SEL = globals().get('ONLY')
CM = creature_mats()
T, C, TL, HN, HF, NS, ED, EWH, GM = 'Fur_Tan', 'Fur_Cream', 'Fur_Teal', 'Horn', 'Hoof', 'Skin_Nose', 'Eye_Dark', 'Eye_White', 'Glow_Main'


def scale_objs(objs, s):
    """uniform scale about the model origin: meshes about their own origin, locations multiplied (call BEFORE parenting)"""
    for o in objs:
        if o.type == 'MESH':
            o.data.transform(Matrix.Scale(s, 4))
            o.data.update()
        o.location = o.location * s


def link_tree(tree, objs):
    for child, parent in tree.items():
        if parent is not None:
            parent_keep(objs[child], objs[parent])


# ----------------------------------------------------------------------------------------------------------------------
def build_grazer(SC=0.93):
    name = 'creature_grazer'
    coll = fresh_collection(name)
    O = {}
    # ---- Body: barrel with shoulder hump, tabby stripes on the back, cream belly
    mb = MB('Body')
    st = [(-0.74, .86, .05, .05), (-0.71, .86, .15, .15), (-0.66, .86, .24, .24), (-0.56, .85, .32, .32), (-0.42, .85, .38, .38),
          (-0.26, .86, .42, .41), (-0.10, .87, .44, .43), (0.06, .88, .45, .44), (0.22, .90, .45, .45), (0.38, .92, .43, .45),
          (0.52, .94, .39, .43), (0.64, .96, .33, .38), (0.74, .98, .26, .31), (0.82, 1.0, .20, .24)]
    body = loft_y(mb, st, n=16, p=2.3, mat=T)
    for i, band in enumerate(body.bands):
        for k, f in enumerate(band):
            if f is None:
                continue
            if 9 <= k <= 14:
                f.material_index = mb.mi(C)
            elif 2 <= k <= 5 and i % 3 == 1 and 1 <= i <= 11:
                f.material_index = mb.mi(TL)
    # rump patch + chest tuft
    ball(mb, (0, -0.62, 0.90), 0.20, C, segs=8, rings=4, scale=(1.0, 0.7, 1.0))
    ball(mb, (0, 0.62, 0.62), 0.20, C, segs=8, rings=4, scale=(1.1, 1.0, 1.2))
    O['Body'] = put(mb, 'Body', coll, None)

    # ---- Head (pivot at the neck)
    mb = MB('Head')
    hs = [(0.68, 1.00, .15, .17), (0.76, 1.02, .20, .22), (0.86, 1.04, .23, .24), (0.97, 1.03, .235, .235), (1.06, .995, .19, .195),
          (1.14, .96, .15, .15), (1.20, .94, .10, .105), (1.22, .935, .05, .05)]
    head = loft_y(mb, hs, n=14, p=2.2, mat=T)
    for i, band in enumerate(head.bands):
        for k, f in enumerate(band):
            if f is None:
                continue
            if i >= 4:
                f.material_index = mb.mi(C)
            elif i in (1, 2, 3) and 0 <= k <= 6:
                f.material_index = mb.mi(TL)
    ball(mb, (0, 1.215, 0.945), 0.062, NS, segs=8, rings=4, scale=(1.15, 0.75, 0.85))
    for sx in (-1, 1):
        ball(mb, (sx * 0.205, 0.99, 1.07), 0.052, ED, segs=8, rings=4)
        ball(mb, (sx * 0.232, 1.01, 1.095), 0.017, EWH, segs=5, rings=3)
        cone(mb, (sx * 0.17, 0.88, 1.20), (sx * 0.36, 0.83, 1.31), 0.075, T, segs=6)
        cone(mb, (sx * 0.19, 0.89, 1.20), (sx * 0.33, 0.86, 1.285), 0.045, C, segs=5)
        hp = tube_path(mb, [(sx * 0.10, 0.92, 1.19), (sx * 0.19, 0.93, 1.33), (sx * 0.29, 0.88, 1.42), (sx * 0.37, 0.78, 1.46), (sx * 0.40, 0.68, 1.43)],
                       [0.06, 0.052, 0.04, 0.027, 0.01], segs=6, mat=HN, per=3)
        for bi in range(len(hp.bands)):
            if bi % 5 == 2:
                for f in hp.bands[bi]:
                    if f is not None:
                        f.material_index = mb.mi(TL)
    for i in range(4):
        y = 0.92 - i * 0.075
        z = 1.25 + 0.02 * i
        cone(mb, (0, y, z), (0, y - 0.11, z + 0.15), 0.055, TL, segs=5)
    bmesh.ops.scale(mb.bm, vec=Vector((1.22, 1.22, 1.22)), space=Matrix.Translation((0, -0.76, -1.00)), verts=list(mb.bm.verts))
    O['Head'] = put(mb, 'Head', coll, (0, 0.76, 1.00))

    # ---- Tail (pivot at the root) with a teal tuft
    mb = MB('Tail')
    tube_path(mb, [(0, -0.70, 0.92), (0, -0.84, 0.92), (0, -0.97, 0.87), (0, -1.07, 0.79)], [0.09, 0.075, 0.058, 0.045], segs=7, mat=T, per=3)
    ball(mb, (0, -1.10, 0.70), 0.12, TL, segs=8, rings=5, scale=(0.9, 1.2, 1.45))
    for sx, dy in ((0, -0.15), (-0.09, -0.10), (0.09, -0.10)):
        cone(mb, (sx * 0.5, -1.08, 0.78), (sx, -1.10 + dy, 0.52), 0.07, C, segs=5)
    O['Tail'] = put(mb, 'Tail', coll, (0, -0.72, 0.92))

    # ---- Legs (hip pivots)
    def leg(nm, px, py, sc, hind):
        mb = MB(nm)
        k_ = 1.12 if hind else 1.0
        ls = [(0.80, px, py, .19 * sc * k_, .21 * sc * k_), (0.66, px, py, .165 * sc * k_, .185 * sc * k_), (0.50, px, py, .125 * sc, .14 * sc),
              (0.36, px, py, .10, .11), (0.22, px, py, .088, .097), (0.12, px, py + .005, .092, .11), (0.07, px, py + .02, .12, .15),
              (0.0, px, py + .025, .115, .145)]
        lg = loft_z(mb, ls, n=10, p=2.2, mat=T)
        mats = [T, T, C, C, C, HF, HF]
        for i, band in enumerate(lg.bands):
            for f in band:
                if f is not None:
                    f.material_index = mb.mi(mats[i])
        O[nm] = put(mb, nm, coll, (px, py, 0.70))
    leg('Leg_FL', -0.30, 0.42, 1.05, False)
    leg('Leg_FR', 0.30, 0.42, 1.05, False)
    leg('Leg_BL', -0.30, -0.40, 1.0, True)
    leg('Leg_BR', 0.30, -0.40, 1.0, True)

    tree = {'Body': None, 'Head': 'Body', 'Tail': 'Body', 'Leg_FL': 'Body', 'Leg_FR': 'Body', 'Leg_BL': 'Body', 'Leg_BR': 'Body'}
    if SC != 1.0:
        scale_objs(list(O.values()), SC)
    link_tree(tree, O)
    return O['Body']


# ----------------------------------------------------------------------------------------------------------------------
def build_flyer():
    name = 'creature_flyer'
    coll = fresh_collection(name)
    O = {}
    SB, SBL, SCR, SW, SWU, SBK = 'Skin_Back', 'Skin_Belly', 'Skin_Crest', 'Skin_Wing', 'Skin_WingUnder', 'Skin_Beak'
    mb = MB('Body')
    st = [(-0.66, 0.0, .04, .04), (-0.62, 0.0, .09, .07), (-0.48, 0.0, .18, .12), (-0.28, .01, .25, .155), (-0.05, .02, .275, .17),
          (0.18, .02, .26, .165), (0.38, .02, .21, .145), (0.52, .015, .15, .115)]
    st = [(a, b, c * 1.14, d * 1.14) for (a, b, c, d) in st]
    body = loft_y(mb, st, n=14, p=2.4, mat=SB)
    for band in body.bands:
        for k, f in enumerate(band):
            if f is not None and k >= 7:
                f.material_index = mb.mi(SBL)
    hs = [(0.46, .015, .15, .12), (0.56, .02, .14, .115), (0.67, .03, .125, .115), (0.78, .025, .092, .088), (0.86, .012, .055, .052), (0.90, .005, .03, .03)]
    hs = [(a, b, c * 1.14, d * 1.14) for (a, b, c, d) in hs]
    head = loft_y(mb, hs, n=12, p=2.2, mat=SB)
    for band in head.bands:
        for k, f in enumerate(band):
            if f is not None and 6 <= k <= 11:
                f.material_index = mb.mi(SBL)
    cone(mb, (0, 0.84, 0.012), (0, 1.12, -0.012), 0.052, SBK, segs=6)
    cone(mb, (0, 0.80, -0.04), (0, 1.00, -0.05), 0.04, SBK, segs=5)
    for sx in (-1, 1):
        ball(mb, (sx * 0.108, 0.68, 0.065), 0.058, ED, segs=8, rings=4)
        ball(mb, (sx * 0.125, 0.70, 0.088), 0.018, EWH, segs=5, rings=3)
        # small feet / hip nubs under the body
        ball(mb, (sx * 0.12, -0.3, -0.13), 0.05, SBL, segs=6, rings=3)
    crest = [(0.80, 0.09), (0.72, 0.23), (0.52, 0.36), (0.26, 0.43), (0.00, 0.44), (0.20, 0.30), (0.42, 0.19), (0.60, 0.12)]
    Mx = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))        # local (x, y, z) -> world (z, x, y): polygon in the YZ plane
    mb.slab(crest, 0.05, SCR, m=Mx, z0=-0.025, bevel=0.012)
    # belly stripes
    O['Body'] = put(mb, 'Body', coll, None)

    # ---- Tail with a diamond fin
    mb = MB('Tail')
    tube_path(mb, [(0, -0.58, 0.0), (0, -0.80, -0.01), (0, -1.0, -0.03), (0, -1.2, -0.05), (0, -1.36, -0.06)], [0.075, 0.05, 0.038, 0.028, 0.02],
              segs=6, mat=SB, per=2)
    mb.slab([(0, -1.28), (0.20, -1.50), (0, -1.78), (-0.20, -1.50)], 0.025, SCR, m=Matrix.Translation((0, 0, -0.07)), bevel=0.008)
    Mx2 = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    mb.slab([(-1.30, -0.06), (-1.52, 0.17), (-1.60, -0.06)], 0.02, SCR, m=Mx2, z0=-0.01, bevel=0.006)
    O['Tail'] = put(mb, 'Tail', coll, (0, -0.60, 0.0))

    # ---- Wings: cambered, swept, scalloped trailing edge, drooping tips.  Built for +X, mirrored for -X
    keys_s = [0.0, 0.3, 0.65, 0.95, 1.12]
    f_le = pchip(keys_s, [.30, .38, .30, .08, -.20])
    f_te = pchip(keys_s, [-.32, -.44, -.42, -.31, -.24])
    f_tr = pchip(keys_s, [.11, .09, .07, .05, .03])
    svals = [0.0, 0.09, 0.19, 0.30, 0.42, 0.54, 0.66, 0.77, 0.87, 0.96, 1.04]

    def wing(sign, nm):
        mb = MB(nm)
        rings = []
        x0 = 0.22
        for i, s in enumerate(svals):
            chord = f_le(s) - f_te(s)
            if i % 2 == 1 and 0.25 < s < 1.0:
                chord *= 0.84
            z0 = 0.05 * math.sin(PI * s / 1.2) - 0.16 * (s / 1.12) ** 3 + 0.03
            af = airfoil(4, f_tr(s), te=0.004, camber=0.05)
            rings.append([Vector((sign * (x0 + s), f_le(s) - x_ * chord, z0 + zz * chord)) for (x_, zz) in af])
        tipz = 0.05 * math.sin(PI * 1.12 / 1.2) - 0.16 + 0.03
        rings.append([Vector((sign * (x0 + 1.12), -0.22, tipz))] * len(rings[0]))
        part = mb.loft(rings, mat=SW, cap_a=True, cap_b=False)
        nb = len(part.bands)
        for i, band in enumerate(part.bands):
            smid = (svals[i] + (svals[i + 1] if i + 1 < len(svals) else 1.12)) / 2
            for k, f in enumerate(band):
                if f is None:
                    continue
                top = k <= 3
                if smid > 0.8:
                    m_ = SCR
                elif k in (3, 4):
                    m_ = SCR
                else:
                    m_ = SW if top else SWU
                f.material_index = mb.mi(m_)
        ob = put(mb, nm, coll, (sign * 0.22, 0.04, 0.03))
        O[nm] = ob
    wing(-1, 'Wing_L')
    wing(1, 'Wing_R')
    tree = {'Body': None, 'Tail': 'Body', 'Wing_L': 'Body', 'Wing_R': 'Body'}
    link_tree(tree, O)
    return O['Body']


# ----------------------------------------------------------------------------------------------------------------------
def build_floater():
    name = 'creature_floater'
    coll = fresh_collection(name)
    O = {}
    SBL, SAR, STE = 'Skin_Bell', 'Skin_Arm', 'Skin_Tentacle'
    mb = MB('Bell')
    outer = [(0.0, 1.16), (0.35, 1.12), (0.70, 1.00), (1.00, 0.80), (1.25, 0.52), (1.42, 0.22), (1.52, -0.02), (1.58, -0.18)]
    inner = [(1.46, -0.16), (1.36, 0.0), (1.2, 0.30), (0.95, 0.60), (0.62, 0.82), (0.28, 0.93), (0.0, 0.96)]
    rings = lathe_rings(outer + inner, segs=24, lobes=8, lobe_amp=0.06, lobe_from=0.75, zig=(0.05, 1.3, 1.6, 4))
    add_bm(mb, rings_bm(rings), mat=SBL, smooth=True, closed=True)
    # glowing core + radial canals under the skin
    ball(mb, (0, 0, 0.48), 0.5, GM, segs=10, rings=6, scale=(1, 1, 0.75))
    zin = pchip([p[0] for p in reversed(inner)], [p[1] for p in reversed(inner)])
    for i in range(8):
        a = TAU * (i + 0.5) / 8
        c_, s_ = math.cos(a), math.sin(a)
        path = [Vector((r_ * c_, r_ * s_, zin(r_) - 0.05)) for r_ in (0.45, 0.85, 1.22)]
        mb.tube(path, [0.032, 0.026, 0.02], segs=5, mat=GM, cap_a=False, cap_b=True)
    # frilly oral arms (crossed ribbons)
    for ai in range(3):
        a0 = TAU * ai / 3 + 0.4
        for cross in (0, 1):
            spine, widths, wdirs = [], [], []
            for j in range(13):
                u = j / 12
                ang = a0 + u * 1.6 + cross * PI / 2
                off = Vector((math.cos(a0), math.sin(a0), 0)) * (0.16 + 0.10 * math.sin(u * 7 + ai))
                p = Vector((off.x + 0.14 * math.sin(u * 5.0 + ai), off.y + 0.14 * math.cos(u * 4.3 + ai * 2), 0.06 - 2.1 * u))
                spine.append(p)
                widths.append(0.36 * (1 - u) ** 0.55 * (1.0 + 0.4 * math.sin(j * 2.4 + ai)) + 0.03)
                wdirs.append(Vector((math.cos(ang), math.sin(ang), 0)))
            add_bm(mb, strip_bm(spine, widths, wdirs, tip=True), mat=SAR, smooth=True, closed=False)
    O['Bell'] = put(mb, 'Bell', coll, None, smooth_angle=70)

    # ---- 8 tentacles, pivot at the rim attachment point
    for i in range(8):
        nm = 'Tentacle_%02d' % (i + 1)
        th = TAU * i / 8
        rd = Vector((math.cos(th), math.sin(th), 0))
        td = Vector((-math.sin(th), math.cos(th), 0))
        L = 4.1 if i % 2 == 0 else 3.4
        att = Vector((rd.x * 1.40, rd.y * 1.40, -0.14))
        pts = []
        for j in range(9):
            u = j / 8
            wt = 0.11 * math.sin(u * TAU * 1.5 + i * 1.3) * min(1.0, u * 4)
            wr = 0.09 * math.sin(PI * u) + 0.06 * math.sin(u * TAU * 1.2 + i) * min(1.0, u * 3)
            pts.append(att + rd * wr + td * wt + Vector((0, 0, -L * u)))
        mb = MB(nm)
        rr = [0.075 * (1 - u) ** 0.8 + 0.014 for u in [j / 8 for j in range(9)]]
        tp = mb.tube(pts, rr, segs=5, mat=STE, cap_a=True, cap_b=True)
        for bi in (1, 4, 7):
            for f in tp.bands[bi]:
                if f is not None:
                    f.material_index = mb.mi(GM)
        ball(mb, att + Vector((0, 0, 0.02)), 0.10, GM, segs=6, rings=3)
        ball(mb, pts[-1], 0.045, GM, segs=6, rings=3)
        O[nm] = put(mb, nm, coll, att, smooth_angle=70)
    tree = {'Bell': None}
    for i in range(8):
        tree['Tentacle_%02d' % (i + 1)] = 'Bell'
    link_tree(tree, O)
    return O['Bell']


# ----------------------------------------------------------------------------------------------------------------------
def build_crawler():
    name = 'creature_crawler'
    coll = fresh_collection(name)
    O = {}
    SM, SD, SL, SU = 'Shell_Main', 'Shell_Dark', 'Shell_Light', 'Skin_Under'
    mb = MB('Body')
    prof = [(1.0, 0.0), (1.03, 0.06), (0.97, 0.14), (0.86, 0.24), (0.68, 0.33), (0.45, 0.40), (0.22, 0.44), (0.0, 0.46)]
    zr, RX, RY, HS = 0.17, 0.31, 0.36, 0.55
    dome = mb.lathe(prof, segs=18, m=MB.xf((0, -0.02, zr), None, scale=(RX, RY, HS)), mat=SM, cap_a=True, cap_b=False)
    for i, band in enumerate(dome.bands):
        for k, f in enumerate(band):
            if f is None:
                continue
            c = f.calc_center_median()
            if i <= 1:
                f.material_index = mb.mi(SD)
            elif c.y < -0.08:
                f.material_index = mb.mi(SL)
    for f in dome.caps:
        f.material_index = mb.mi(SU)
    rp = pchip([0.0, .22, .45, .68, .86, .97, 1.0], [.46, .44, .40, .33, .24, .14, .05])

    def dome_z(x, y):
        r = math.sqrt((x / RX) ** 2 + ((y + 0.02) / RY) ** 2)
        return zr + HS * rp(min(r, 1.0))
    spots = [(0.0, 0.03), (-0.11, 0.13), (0.11, 0.13), (-0.15, -0.07), (0.15, -0.07), (0.0, -0.17), (-0.21, 0.04), (0.21, 0.04)]
    for (x, y) in spots:
        z = dome_z(x, y)
        e = 0.01
        nx = -(dome_z(x + e, y) - dome_z(x - e, y)) / (2 * e)
        ny = -(dome_z(x, y + e) - dome_z(x, y - e)) / (2 * e)
        n = Vector((nx, ny, 1.0)).normalized()
        rs = 0.05 if abs(x) < 0.15 else 0.036
        ball(mb, Vector((x, y, z)) + n * 0.004, rs, GM, segs=7, rings=3, scale=(1, 1, 0.5), rot=MB.aim(n))
    ball(mb, (0, 0.35, 0.235), 0.18, SD, segs=10, rings=5, scale=(1.15, 0.95, 0.62))
    for sx in (-1, 1):
        es = tube_path(mb, [(sx * 0.09, 0.36, 0.25), (sx * 0.12, 0.40, 0.36), (sx * 0.13, 0.43, 0.45)], [0.032, 0.027, 0.023], segs=5, mat=SD, per=2)
        ball(mb, (sx * 0.135, 0.44, 0.49), 0.058, EWH, segs=8, rings=4)
        ball(mb, (sx * 0.135, 0.48, 0.495), 0.032, ED, segs=6, rings=3)
        tube_path(mb, [(sx * 0.13, 0.36, 0.19), (sx * 0.21, 0.48, 0.16), (sx * 0.23, 0.62, 0.14)], [0.04, 0.034, 0.03], segs=6, mat=SD, per=2)
        ball(mb, (sx * 0.23, 0.62, 0.14), 0.045, SD, segs=6, rings=3)
        cone(mb, (sx * 0.23, 0.62, 0.14), (sx * 0.15, 0.80, 0.14), 0.04, SL, segs=5)
        cone(mb, (sx * 0.23, 0.62, 0.14), (sx * 0.31, 0.79, 0.14), 0.04, SL, segs=5)
    O['Body'] = put(mb, 'Body', coll, None, smooth_angle=50)

    def leg(idx, side, y0, splay):
        nm = 'Leg_%d' % idx
        mb = MB(nm)
        hip = Vector((side * 0.25, y0, 0.19))
        knee = Vector((side * 0.38, y0 + splay * 0.08, 0.31))
        foot = Vector((side * 0.47, y0 + splay * 0.19, 0.0))
        mb.tube([hip, knee], [0.046, 0.04], segs=6, mat=SM, cap_a=True, cap_b=True)
        mb.tube([knee, foot + Vector((0, 0, 0.05))], [0.038, 0.018], segs=6, mat=SD, cap_a=True, cap_b=True)
        ball(mb, hip, 0.062, SD, segs=7, rings=4)
        ball(mb, knee, 0.052, SL, segs=7, rings=4)
        cone(mb, foot + Vector((0, 0, 0.08)), foot, 0.026, SL, segs=5, r2=0.006)
        O[nm] = put(mb, nm, coll, hip, smooth_angle=50)
    for idx, side, y0, sp in ((1, -1, 0.20, 1), (2, 1, 0.20, 1), (3, -1, 0.0, 0.0), (4, 1, 0.0, 0.0), (5, -1, -0.20, -1), (6, 1, -0.20, -1)):
        leg(idx, side, y0, sp)
    tree = {'Body': None}
    for i in range(1, 7):
        tree['Leg_%d' % i] = 'Body'
    link_tree(tree, O)
    return O['Body']


BUILDERS = [('creature_grazer', build_grazer), ('creature_flyer', build_flyer), ('creature_floater', build_floater), ('creature_crawler', build_crawler)]
for _n, _f in BUILDERS:
    if SEL is None or _n in SEL:
        _f()
        check(_n, verbose=False)
        park(_n)
        print('built', _n)
