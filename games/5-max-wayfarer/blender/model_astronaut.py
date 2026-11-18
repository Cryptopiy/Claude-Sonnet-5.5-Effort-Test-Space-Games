"""astronaut - the player character (hero asset). Re-runnable: rebuilds the collection `astronaut` from scratch.
Blender axes: faces +Y, up +Z, character's left = -X.  Scene origin = on the ground between the feet, height 1.8 m.
Every joint is its own mesh object whose ORIGIN sits on the joint (rotation 0, scale 1), nested exactly as in the brief.
"""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Suit_White', '#E6E6E1', metal=0.0, rough=0.6)
mat('Suit_Accent', '#F26A14', metal=0.0, rough=0.55)
mat('Suit_Dark', '#3A3D43', metal=0.1, rough=0.8)
mat('Visor', '#B27B25', metal=0.9, rough=0.08)
mat('Emissive_Jet', '#CFF4FF', rough=0.4, emit='#6FDCFF', emit_strength=4.0)
COLL_NAME = "astronaut"
coll = fresh_collection(COLL_NAME)

SH_X, SH_Z = 0.300, 1.400
HIP_X, HIP_Z, KNEE_Z, ANK_Z = 0.125, 0.93, 0.52, 0.11
NECK_Z, WAIST_Z, PELVIS_Z = 1.52, 1.04, 0.95
UP, LOW = 0.30, 0.27
ANG1, ANG2, ANG3 = rad(17), rad(13), rad(9)
HC = Vector((0, 0.012, 1.645))
HR = (0.165, 0.180, 0.155)


class Fr:
    """limb frame: origin + rotation about Y (limb axis = local -Z)"""

    def __init__(self, origin, theta=0.0):
        self.o = Vector(origin)
        self.R = Matrix.Rotation(theta, 3, 'Y')

    def p(self, x=0.0, y=0.0, z=0.0):
        return self.o + self.R @ Vector((x, y, z))

    def rot(self, loc=None):
        return self.R if loc is None else self.R @ loc


def limb_cap(mb, fr, z_top, z_bot, r_top, r_bot, mat_, segs=14, sc=(1.0, 1.0), off=(0.0, 0.0)):
    L = (z_top - z_bot) + r_top + r_bot
    zc = ((z_top + r_top) + (z_bot - r_bot)) / 2
    return mb.capsule(r_bot, L, center=fr.p(off[0], off[1], zc), segs=segs, mat=mat_, rot=fr.R, r2=r_top, scale=(sc[0], sc[1], 1.0))


def cap_between(mb, a, b, r0, r1, mat_, segs=10):
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    dn = d.normalized()
    mid = (a + b) / 2 + dn * (r1 - r0) / 2
    return mb.capsule(r0, L + r0 + r1, center=mid, segs=segs, mat=mat_, rot=MB.aim(dn), r2=r1)


# ------------------------------------------------------------------------------------------------
# torso / pelvis
# ------------------------------------------------------------------------------------------------
TORSO_SECT = [(1.030, 0.165, 0.112, 0.000), (1.120, 0.185, 0.122, 0.000), (1.220, 0.213, 0.138, 0.005),
              (1.320, 0.236, 0.148, 0.012), (1.400, 0.226, 0.132, 0.000), (1.455, 0.158, 0.105, -0.005),
              (1.495, 0.085, 0.080, -0.010)]
_tz = [s[0] for s in TORSO_SECT]
_tfront = pchip(_tz, [s[3] + s[2] for s in TORSO_SECT])
_tback = pchip(_tz, [s[3] - s[2] for s in TORSO_SECT])


def torso_mesh(mb):
    rings = []
    for (z, a, b, cy) in TORSO_SECT:
        rings.append([Vector((x, cy + y, z)) for (x, y) in superellipse(28, a, b, 2.6)])
    part = mb.loft(rings, mat='Suit_White', cap_a=True, cap_b=True, cap_kind='ngon')
    dark = mb.mi('Suit_Dark')
    for f in part.caps[:1]:
        f.material_index = dark
    # shoulder yoke
    mb.capsule(0.074, 0.56 + 0.148, center=(0, -0.004, SH_Z), segs=14, mat='Suit_White', rot=(0, PI / 2, 0))
    # chest plate, buttons, straps
    fy = _tfront(1.30)
    mb.rbox((0.23, 0.040, 0.19), center=(0, fy + 0.006, 1.30), bevel=0.016, bsegs=2, mat='Suit_Dark')
    for sx in (-1, 1):
        mb.cyl(0.014, 0.012, center=(sx * 0.06, fy + 0.032, 1.250), segs=10, rot=(PI / 2, 0, 0), mat='Suit_Accent')
        mb.rbox((0.05, 0.026, 0.36), center=(sx * 0.155, _tfront(1.27) - 0.004, 1.26), bevel=0.009, bsegs=1, mat='Suit_Dark')
    mb.rbox((0.11, 0.012, 0.018), center=(-0.025, fy + 0.029, 1.350), bevel=0.003, bsegs=1, mat='Suit_Accent')
    mb.rbox((0.11, 0.012, 0.018), center=(-0.025, fy + 0.029, 1.318), bevel=0.003, bsegs=1, mat='Suit_Accent')
    # waist ring and neck base
    mb.loft([[Vector((x, y, z)) for (x, y) in superellipse(28, a, b, 2.6)]
             for (z, a, b) in ((1.012, 0.176, 0.122), (1.026, 0.192, 0.134), (1.072, 0.194, 0.136), (1.092, 0.166, 0.110))],
            mat='Suit_Dark', cap_a=False, cap_b=False)
    mb.cyl(0.118, 0.055, center=(0, -0.004, 1.488), segs=22, mat='Suit_Dark', bevel=0.01, bsegs=1)
    mb.torus(0.113, 0.016, center=(0, -0.004, 1.514), segs=26, tsegs=6, mat='Metal')
    return part


def pelvis_mesh(mb):
    pel = [(0.850, 0.145, 0.108), (0.900, 0.170, 0.116), (0.960, 0.190, 0.122), (1.020, 0.190, 0.120), (1.070, 0.168, 0.112)]
    rings = [[Vector((x, y, z)) for (x, y) in superellipse(26, a, b, 2.8)] for (z, a, b) in pel]
    mb.loft(rings, mat='Suit_White', cap_a=True, cap_b=True, cap_kind='ngon')
    belt = [(0.952, 0.198, 0.134), (0.968, 0.212, 0.144), (1.040, 0.212, 0.144), (1.058, 0.196, 0.132)]
    mb.loft([[Vector((x, y, z)) for (x, y) in superellipse(26, a, b, 2.8)] for (z, a, b) in belt], mat='Suit_Dark', cap_a=True,
            cap_b=True, cap_kind='ngon')
    mb.rbox((0.090, 0.034, 0.064), center=(0, 0.150, 1.004), bevel=0.012, bsegs=1, mat='Metal')
    mb.rbox((0.052, 0.014, 0.036), center=(0, 0.170, 1.004), bevel=0.005, bsegs=1, mat='Suit_Accent')
    for sx in (-1, 1):
        mb.rbox((0.080, 0.100, 0.120), center=(sx * 0.232, 0.015, 0.975), bevel=0.02, bsegs=2, mat='Suit_Accent')
        mb.rbox((0.086, 0.026, 0.022), center=(sx * 0.232, 0.015, 1.020), bevel=0.005, bsegs=1, mat='Suit_Dark')
        mb.rbox((0.075, 0.090, 0.100), center=(sx * 0.100, -0.165, 0.990), bevel=0.018, bsegs=2, mat='Suit_Dark')


# ------------------------------------------------------------------------------------------------
# head / visor
# ------------------------------------------------------------------------------------------------
VIS_AZ, VIS_EL, VIS_EL0 = rad(64), rad(34), rad(5)


def visor_dir(az, el):
    return Vector((math.cos(el) * math.sin(az), math.cos(el) * math.cos(az), math.sin(el)))


def visor_point(s, a, n=3.2, kb=0.085, kr=0.04):
    az = VIS_AZ * s * spow(math.cos(a), 2.0 / n)
    el = VIS_EL0 + VIS_EL * s * spow(math.sin(a), 2.0 / n)
    d = visor_dir(az, el)
    m = kb * (1 - s * s) - kr * s * s
    return HC + Vector((d.x * HR[0] * (1 + m), d.y * HR[1] * (1 + m), d.z * HR[2] * (1 + m)))


def head_mesh(mb):
    segs = 48
    part = mb.sphere(1.0, center=HC, segs=segs, rings=24, mat='Suit_White', scale=HR)
    accent = mb.mi('Suit_Accent')
    nb = len(part.bands)
    for bi in range(nb):
        lat = -90 + 180 * (bi + 0.5) / nb
        for k in range(segs):
            f = part.bands[bi][k]
            if f is None:
                continue
            front_k = k in (10, 11, 12, 13)
            back_k = k in (34, 35, 36, 37)
            if lat > 28 and (front_k or back_k):
                f.material_index = accent
            elif lat > -15 and back_k:
                f.material_index = accent
    mb.torus(0.123, 0.021, center=(0, HC.y, 1.540), segs=30, tsegs=6, mat='Metal', scale=(0.98, 1.08, 1.0))
    mb.cyl(0.102, 0.05, center=(0, 0.0, 1.510), segs=22, mat='Suit_Dark', bevel=0.01, bsegs=1)
    for sx in (-1, 1):
        mb.cyl(0.046, 0.036, center=(sx * (HR[0] + 0.004), 0.012, 1.650), segs=18, rot=(0, PI / 2, 0), mat='Suit_Dark', bevel=0.008, bsegs=1)
        mb.cyl(0.028, 0.012, center=(sx * (HR[0] + 0.024), 0.012, 1.650), segs=14, rot=(0, PI / 2, 0), mat='Metal')
    mb.rbox((0.13, 0.036, 0.14), center=(0, HC.y - HR[1] + 0.006, 1.625), bevel=0.015, bsegs=2, mat='Suit_Dark')
    mb.rbox((0.075, 0.012, 0.055), center=(0, HC.y - HR[1] - 0.013, 1.65), bevel=0.004, bsegs=1, mat='Suit_Accent')
    mb.cyl(0.006, 0.075, center=(0.10, -0.092, 1.755), segs=6, rot=(rad(24), 0, 0), mat='Metal')
    mb.sphere(0.011, center=(0.10, -0.107, 1.787), segs=8, mat='Suit_Accent')
    for sx in (-1, 1):
        az, el = sx * rad(60), rad(22)
        d = visor_dir(az, el)
        n = Vector((d.x / HR[0] ** 2, d.y / HR[1] ** 2, d.z / HR[2] ** 2)).normalized()
        pt = HC + Vector((d.x * HR[0], d.y * HR[1], d.z * HR[2]))
        mb.cyl(0.029, 0.02, center=pt + n * 0.006, segs=14, rot=MB.aim(n), mat='Suit_Dark')
        mb.cyl(0.020, 0.012, center=pt + n * 0.014, segs=12, rot=MB.aim(n), mat='Emissive_Light')
    return part


def visor_mesh(mb):
    nr, npts = 7, 32
    rings = []
    for i in range(nr + 1):
        s = i / nr
        rings.append([visor_point(s, TAU * k / npts) for k in range(npts)])
    mb.loft(rings, mat='Visor', cap_a=False, cap_b=False, smooth=True)
    gas = [visor_point(0.86, TAU * k / 48) for k in range(48)]
    mb.tube(gas, 0.0075, segs=6, mat='Suit_Dark', close=True, fixed_up=True)


# ------------------------------------------------------------------------------------------------
# backpack
# ------------------------------------------------------------------------------------------------
BP_C = Vector((0.0, -0.165, 1.280))
JET_X, JET_Y, JET_Z0 = 0.105, -0.250, 0.80


def backpack_mesh(mb):
    mb.rbox((0.37, 0.17, 0.48), center=(0, -0.25, 1.280), bevel=0.05, bsegs=2, mat='Suit_White')
    mb.rbox((0.29, 0.125, 0.05), center=(0, -0.25, 1.525), bevel=0.02, bsegs=2, mat='Suit_Dark')
    mb.rbox((0.32, 0.03, 0.32), center=(0, -0.17, 1.28), bevel=0.012, bsegs=1, mat='Suit_Dark')    # back plate
    for sx in (-1, 1):
        mb.capsule(0.050, 0.42, center=(sx * 0.205, -0.25, 1.27), segs=14, mat='Suit_Accent')
        for zz in (1.13, 1.42):
            mb.torus(0.051, 0.011, center=(sx * 0.205, -0.25, zz), segs=14, tsegs=5, mat='Metal')
    mb.rbox((0.14, 0.022, 0.38), center=(0, -0.3345, 1.29), bevel=0.01, bsegs=1, mat='Suit_Dark')        # core frame
    mb.rbox((0.095, 0.014, 0.33), center=(0, -0.3415, 1.29), bevel=0.004, bsegs=1, mat='Emissive_Jet')   # glowing core
    for k in range(5):
        mb.rbox((0.11, 0.012, 0.012), center=(0, -0.3455, 1.19 + 0.05 * k + 0.07), bevel=0.0, mat='Suit_Dark')
    for sx in (-1, 1):
        prof = [(0.0, 1.06, 'Metal'), (0.056, 1.06, 'Metal'), (0.056, 0.95, 'Metal'), (0.064, 0.89, 'Metal'),
                (0.078, JET_Z0, 'Metal'), (0.065, JET_Z0, 'Suit_Dark'), (0.047, 0.86, 'Suit_Dark'), (0.0, 0.875, 'Suit_Dark')]
        mb.lathe_mats(prof, 20, MB.xf((sx * JET_X, JET_Y, 0)))
        mb.cyl(0.041, 0.012, center=(sx * JET_X, JET_Y, 0.878), segs=14, mat='Emissive_Jet')
        mb.torus(0.062, 0.011, center=(sx * JET_X, JET_Y, 0.93), segs=16, tsegs=5, mat='Suit_Accent')


# ------------------------------------------------------------------------------------------------
# arms
# ------------------------------------------------------------------------------------------------
def arm_frames(sx):
    S = Vector((sx * SH_X, 0, SH_Z))
    f1 = Fr(S, -sx * ANG1)
    E = f1.p(0, 0, -UP)
    f2 = Fr(E, -sx * ANG2)
    W = f2.p(0, 0, -LOW)
    f3 = Fr(W, -sx * ANG3)
    return S, E, W, f1, f2, f3


def arm_upper(mb, sx):
    S, E, W, f1, f2, f3 = arm_frames(sx)
    mb.sphere(0.090, center=S, segs=16, mat='Suit_Dark')
    prot = Matrix.Rotation(sx * rad(28), 3, 'Y')
    pc = S + Vector((sx * 0.012, 0, 0.034))
    mb.hemi(0.122, center=pc, segs=20, rings=6, mat='Suit_White', scale=(1.0, 1.1, 0.8), rot=prot, lat0=-0.4)
    mb.torus(0.1125, 0.013, center=pc + prot @ Vector((0, 0, -0.038)), segs=22, tsegs=6, rot=prot, mat='Suit_Accent', scale=(1.0, 1.1, 1.0))
    limb_cap(mb, f1, 0.0, -UP, 0.074, 0.064, 'Suit_White')
    mb.torus(0.0725, 0.0125, center=f1.p(0, 0, -0.115), segs=18, tsegs=6, rot=f1.R, mat='Suit_Accent')
    mb.cyl(0.069, 0.048, center=f1.p(0, 0, -UP + 0.010), segs=16, rot=f1.R, mat='Suit_Dark', bevel=0.008, bsegs=1)


def arm_lower(mb, sx):
    S, E, W, f1, f2, f3 = arm_frames(sx)
    mb.sphere(0.075, center=E, segs=16, mat='Suit_Dark')
    limb_cap(mb, f2, 0.0, -LOW, 0.063, 0.054, 'Suit_White')
    mb.rbox((0.030, 0.08, 0.16), center=f2.p(sx * 0.060, 0.0, -0.125), rot=f2.R, bevel=0.011, bsegs=1, mat='Suit_Accent')
    mb.cyl(0.059, 0.046, center=f2.p(0, 0, -LOW + 0.010), segs=16, rot=f2.R, mat='Suit_Dark', bevel=0.008, bsegs=1)
    mb.torus(0.058, 0.009, center=f2.p(0, 0, -LOW + 0.038), segs=16, tsegs=5, rot=f2.R, mat='Metal')


def hand(mb, sx):
    S, E, W, f1, f2, f3 = arm_frames(sx)
    mb.sphere(0.062, center=W, segs=14, mat='Suit_Dark')
    mb.cyl(0.053, 0.034, center=f3.p(0, 0, -0.012), segs=14, rot=f3.R, mat='Suit_White', bevel=0.006, bsegs=1)
    mb.rbox((0.100, 0.054, 0.112), center=f3.p(0, 0, -0.078), rot=f3.R, bevel=0.02, bsegs=2, mat='Suit_Dark')
    Rf = f3.rot(Matrix.Rotation(rad(-16), 3, 'X'))
    for k, ln in zip((-1.5, -0.5, 0.5, 1.5), (0.080, 0.092, 0.088, 0.074)):
        mb.rbox((0.0235, 0.040, ln), center=f3.p(k * 0.0245, 0.010, -0.128 - ln / 2 + 0.02), rot=Rf, bevel=0.0095, bsegs=2, mat='Suit_Dark')
    cap_between(mb, f3.p(-sx * 0.042, 0.028, -0.055), f3.p(-sx * 0.030, 0.064, -0.112), 0.021, 0.017, 'Suit_Dark')
    mb.rbox((0.013, 0.068, 0.068), center=f3.p(sx * 0.034, 0.0, -0.085), rot=f3.R, bevel=0.005, bsegs=1, mat='Suit_Accent')
    return f3.p(-sx * 0.040, 0.0, -0.10)


# ------------------------------------------------------------------------------------------------
# legs
# ------------------------------------------------------------------------------------------------
def leg_upper(mb, sx):
    fh = Fr((sx * HIP_X, 0, HIP_Z))
    limb_cap(mb, fh, 0.0, -(HIP_Z - KNEE_Z), 0.112, 0.097, 'Suit_White', segs=16)
    mb.torus(0.108, 0.013, center=fh.p(0, 0, -0.18), segs=22, tsegs=6, mat='Suit_Accent')
    mb.rbox((0.034, 0.09, 0.14), center=fh.p(sx * 0.109, 0.0, -0.11), bevel=0.011, bsegs=1, mat='Suit_Dark')


def leg_lower(mb, sx):
    fk = Fr((sx * HIP_X, 0, KNEE_Z))
    L = KNEE_Z - ANK_Z
    mb.sphere(0.108, center=fk.p(), segs=18, mat='Suit_Dark')
    mb.rbox((0.126, 0.056, 0.14), center=fk.p(0, 0.080, -0.012), bevel=0.022, bsegs=2, mat='Suit_Accent')
    limb_cap(mb, fk, -0.01, -(L - 0.04), 0.092, 0.073, 'Suit_White', segs=16)
    mb.rbox((0.086, 0.034, 0.22), center=fk.p(0, 0.075, -0.20), bevel=0.013, bsegs=1, mat='Suit_Dark')


def foot(mb, sx):
    fa = Fr((sx * HIP_X, 0, ANK_Z))
    mb.sphere(0.078, center=fa.p(), segs=14, mat='Suit_Dark')
    mb.cyl(0.094, 0.13, center=fa.p(0, 0, -0.008), segs=18, mat='Suit_Dark', bevel=0.012, bsegs=1)
    mb.torus(0.092, 0.0105, center=fa.p(0, 0, 0.054), segs=20, tsegs=5, mat='Suit_Accent')
    mb.rbox((0.140, 0.300, 0.092), center=fa.p(0, 0.060, -0.040), bevel=0.034, bsegs=2, mat='Suit_White')
    mb.rbox((0.156, 0.112, 0.074), center=fa.p(0, 0.190, -0.062), bevel=0.030, bsegs=2, mat='Suit_Accent')
    mb.rbox((0.150, 0.090, 0.112), center=fa.p(0, -0.066, -0.052), bevel=0.028, bsegs=2, mat='Suit_Dark')
    mb.rbox((0.168, 0.360, 0.046), center=fa.p(0, 0.066, -0.087), bevel=0.016, bsegs=1, mat='Suit_Dark')


# ------------------------------------------------------------------------------------------------
# assembly
# ------------------------------------------------------------------------------------------------
def build():
    O = {}

    def mk(name, builder, origin, *args, smooth=40, weighted=True):
        mb = MB(name)
        ret = builder(mb, *args)
        ob = mb.finish(name, coll, smooth_angle=smooth, weighted=weighted)
        set_origin(ob, origin)
        O[name] = ob
        return ret

    mk("Pelvis", pelvis_mesh, (0, 0, PELVIS_Z))
    mk("Torso", torso_mesh, (0, 0, WAIST_Z))
    mk("Head", head_mesh, (0, 0, NECK_Z), smooth=50)
    mk("Visor", visor_mesh, (0, 0, NECK_Z), smooth=70, weighted=False)
    mk("Backpack", backpack_mesh, BP_C)
    tool_pt = None
    for sx, s in ((-1, 'L'), (1, 'R')):
        S, E, W, f1, f2, f3 = arm_frames(sx)
        mk("Arm_%s_Upper" % s, arm_upper, S, sx)
        mk("Arm_%s_Lower" % s, arm_lower, E, sx)
        pp = mk("Hand_%s" % s, hand, W, sx)
        if sx == 1:
            tool_pt = pp
        mk("Leg_%s_Upper" % s, leg_upper, (sx * HIP_X, 0, HIP_Z), sx)
        mk("Leg_%s_Lower" % s, leg_lower, (sx * HIP_X, 0, KNEE_Z), sx)
        mk("Foot_%s" % s, foot, (sx * HIP_X, 0, ANK_Z), sx)
    ml = MB("Chest_Light")
    fy = _tfront(1.30)
    cl_pos = (0.068, fy + 0.030, 1.350)
    ml.rbox((0.046, 0.014, 0.028), center=cl_pos, bevel=0.005, bsegs=1, mat='Emissive_Light')
    cl = ml.finish("Chest_Light", coll, smooth_angle=60, weighted=False)
    set_origin(cl, cl_pos)
    O["Chest_Light"] = cl
    O["Marker_Eye"] = empty("Marker_Eye", (0, 0.05, 1.665), coll, size=0.06)
    O["Marker_JetL"] = empty("Marker_JetL", (-JET_X, JET_Y, JET_Z0), coll, size=0.05)
    O["Marker_JetR"] = empty("Marker_JetR", (JET_X, JET_Y, JET_Z0), coll, size=0.05)
    O["Marker_Tool"] = empty("Marker_Tool", tool_pt, coll, size=0.05)
    tree = [("Torso", "Pelvis"), ("Head", "Torso"), ("Visor", "Head"), ("Arm_L_Upper", "Torso"), ("Arm_L_Lower", "Arm_L_Upper"),
            ("Hand_L", "Arm_L_Lower"), ("Arm_R_Upper", "Torso"), ("Arm_R_Lower", "Arm_R_Upper"), ("Hand_R", "Arm_R_Lower"),
            ("Backpack", "Torso"), ("Marker_JetL", "Backpack"), ("Marker_JetR", "Backpack"), ("Chest_Light", "Torso"),
            ("Marker_Eye", "Torso"), ("Leg_L_Upper", "Pelvis"), ("Leg_L_Lower", "Leg_L_Upper"), ("Foot_L", "Leg_L_Lower"),
            ("Leg_R_Upper", "Pelvis"), ("Leg_R_Lower", "Leg_R_Upper"), ("Foot_R", "Leg_R_Lower"), ("Marker_Tool", "Hand_R")]
    for child, parent in tree:
        parent_keep(O[child], O[parent])
    return O


objs = build()
bpy.context.view_layer.update()
check(COLL_NAME, verbose=True)
park(COLL_NAME)      # keep names unique in the .blend: finished models are parked (suffix __collection), export scripts unpark
