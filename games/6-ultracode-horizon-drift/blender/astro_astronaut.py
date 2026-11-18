"""astro_astronaut.py - HORIZON DRIFT explorer in exosuit.  1.8 m tall, origin between the feet, facing Blender +Y.
Hierarchy (pivots = joints):  Astronaut > Hips > Torso > {Head > {Visor, Anchor_Eye}, Arm_L/R > Forearm_L/R > Anchor_Hand_L/R,
Jetpack > JetFlame_L/R};  Hips > Leg_L/R > Shin_L/R.   (Right = +X, front = +Y)
Run:  python tools/bmcp.py file blender/astro_astronaut.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
from astro_lib import *
import math
from math import radians, sqrt

M = A.Model("astronaut")
suit = M.m("suit", (0.80, 0.82, 0.86), roughness=0.5)
dark = M.m("dark", (0.05, 0.055, 0.065), metallic=0.35, roughness=0.5)
accent = M.m("accent", (1.0, 0.30, 0.025), roughness=0.42)
glow = M.m("glow", (0.1, 0.8, 1.0), emission=(0.1, 0.8, 1.0), emission_strength=5.0)
visor = M.m("visor", (0.01, 0.05, 0.30), metallic=0.5, roughness=0.08, emission=(0.04, 0.22, 1.0), emission_strength=0.7)
gold = M.m("gold", (1.0, 0.62, 0.10), metallic=0.9, roughness=0.2, emission=(1.0, 0.5, 0.05), emission_strength=0.8)
flame = M.m("flame", (1.0, 0.5, 0.1), emission=(1.0, 0.45, 0.08), emission_strength=6.0, alpha=0.85)

SUIT, DARK, ACC, GLOW = 0, 1, 2, 3   # slot order for most parts: [suit, dark, accent, glow]
MATS4 = [suit, dark, accent, glow]

P_HIPS = V((0, 0, 0.92))
P_TORSO = V((0, 0, 1.02))
P_HEAD = V((0, 0, 1.45))
HC = V((0, 0.01, 1.603))        # helmet centre
HR = (0.206, 0.216, 0.196)      # helmet radii  -> top at 1.799
HE = 0.86                       # helmet squareness exponent
SX = 0.275                      # shoulder pivot x
TW = 1.05                       # torso width factor


def helm_surface(d, k=1.0):
    d = V(d).normalized()
    p = V((HR[0] * sgnpow(d.x, HE), HR[1] * sgnpow(d.y, HE), HR[2] * sgnpow(d.z, HE)))
    return HC + p * k


# ---------------------------------------------------------------------------------------------------------------
root = M.empty("Astronaut", (0, 0, 0), size=0.3)


# ---------------------------------------------------------------------------------------------------------------
def build_hips():
    rings = []
    for z, rx, ry in [(0.79, 0.12, 0.095), (0.84, 0.158, 0.115), (0.92, 0.176, 0.125), (0.985, 0.168, 0.12), (1.03, 0.156, 0.112)]:
        rings.append(ring_pts(0, 0, z, rx, ry, 18, p=2.4))
    bm = loft(rings, mat=SUIT)
    face_mat_by(bm, lambda c: c.z < 0.86, DARK)
    for s in (1, -1):
        bm = merge(bm, ellipsoid((0.108 * s, 0.0, 0.90), (0.082, 0.082, 0.082), 10, 6, mat=DARK))
    # belt + stripe + buckle
    bm = merge(bm, tube([(0, 0, 0.985), (0, 0, 1.03)], [(0.181, 0.133)] * 2, segs=20, p=2.4, mat=DARK))
    bm = merge(bm, tube([(0, 0, 1.03), (0, 0, 1.048)], [(0.184, 0.136)] * 2, segs=20, p=2.4, mat=ACC))
    bm = merge(bm, rbox((0, 0.137, 1.012), (0.075, 0.03, 0.058), r=0.01, mat=ACC))
    bm = merge(bm, box((0, 0.1535, 1.012), (0.022, 0.004, 0.022), mat=GLOW))
    # pouches / holster / rear bag
    for s in (1, -1):
        rz = Matrix.Rotation(0.25 * s, 4, 'Z')
        bm = merge(bm, rbox((0.145 * s, 0.07, 0.985), (0.07, 0.07, 0.10), r=0.015, matrix=rz, mat=DARK))
        bm = merge(bm, rbox((0.145 * s, 0.07, 1.022), (0.074, 0.074, 0.03), r=0.01, matrix=rz, mat=ACC))
    bm = merge(bm, tube([(-0.12, -0.12, 0.93), (-0.12, -0.12, 1.03)], [0.03, 0.03], segs=8, round_start=1, round_end=1, mat=DARK))
    bm = merge(bm, rbox((0.02, -0.14, 0.99), (0.15, 0.06, 0.09), r=0.015, mat=DARK))
    return bm


def build_torso():
    T = [(1.00, 0.150, 0.105, 0.0), (1.08, 0.160, 0.112, 0.0), (1.17, 0.184, 0.128, 0.004), (1.27, 0.214, 0.146, 0.010),
         (1.36, 0.228, 0.148, 0.005), (1.42, 0.205, 0.128, -0.003), (1.46, 0.142, 0.100, 0.0), (1.49, 0.108, 0.084, 0.0)]
    bm = loft([ring_pts(0, cy, z, rx, ry, 20, p=2.5) for z, rx, ry, cy in T], mat=SUIT)
    face_mat_by(bm, lambda c: c.z < 1.16, DARK)
    # abdomen ribs
    for z in (1.055, 1.095, 1.135):
        k = (z - 1.0) / 0.17
        rx, ry = lerp(0.158, 0.186, k) + 0.008, lerp(0.110, 0.128, k) + 0.008
        bm = merge(bm, tube([(0, 0.002, z - 0.012), (0, 0.002, z + 0.012)], [(rx, ry)] * 2, segs=18, p=2.5, mat=DARK))
    # chest plate (dark) with accent frame, light, buttons, vents
    bm = merge(bm, rbox((0, 0.149, 1.285), (0.25, 0.045, 0.19), r=0.016, mat=DARK))
    bm = merge(bm, rbox((0, 0.1675, 1.347), (0.2, 0.012, 0.016), r=0.005, mat=ACC))
    bm = merge(bm, rbox((0, 0.1675, 1.222), (0.2, 0.012, 0.016), r=0.005, mat=ACC))
    bm = merge(bm, tube([(-0.065, 0.168, 1.292), (-0.065, 0.177, 1.292)], [0.028, 0.026], segs=12, mat=GLOW, up=(1, 0, 0)))
    for i, x in enumerate((0.03, 0.068)):
        bm = merge(bm, tube([(x + 0.012, 0.168, 1.295), (x + 0.012, 0.175, 1.295)], [0.012, 0.012], segs=8, mat=ACC if i == 0 else SUIT))
    for i in range(3):
        bm = merge(bm, rbox((0.045, 0.1685, 1.262 - i * 0.017), (0.09, 0.006, 0.007), r=0.002, segs=1, mat=SUIT))
    # collar ring + inner neck
    bm = merge(bm, tube([(0, 0, 1.43), (0, 0, 1.495)], [(0.134, 0.112), (0.128, 0.108)], segs=20, p=2.3, mat=DARK))
    bm = merge(bm, tube([(0, 0, 1.485), (0, 0, 1.502)], [(0.137, 0.115)] * 2, segs=20, p=2.3, mat=ACC))
    # shoulder yoke straps (accent) running over the shoulders on the chest
    for s in (1, -1):
        bm = merge(bm, tube([(0.075 * s, 0.05, 1.462), (0.16 * s, 0.054, 1.43), (0.228 * s, 0.03, 1.36)],
                            [(0.03, 0.013), (0.03, 0.014), (0.028, 0.014)], segs=8, mat=ACC, up=(0, 1, 0), p=2.5))
    return bm


def build_head():
    bm = ellipsoid(HC, HR, u=24, v=16, e=HE, mat=SUIT)
    # ear pods
    for s in (1, -1):
        bm = merge(bm, tube([(0.195 * s, 0.0, 1.603), (0.238 * s, 0.0, 1.603)], [0.056, 0.056], segs=12, mat=ACC))
        bm = merge(bm, tube([(0.238 * s, 0.0, 1.603), (0.252 * s, 0.0, 1.603)], [0.042, 0.036], segs=12, mat=DARK))
    # crest stripe over the top
    pts = []
    for psi in range(78, 172, 8):
        a = radians(psi)
        pts.append(helm_surface((0, cos(a), sin(a)), 1.006))
    bm = merge(bm, tube(pts, [(0.017, 0.008)] * len(pts), segs=6, mat=ACC, up=(1, 0, 0), round_start=1, round_end=1))
    # headlamp
    a = radians(66)
    lp = helm_surface((0, cos(a), sin(a)), 1.0)
    ln = V((0, HR[2] * cos(a), HR[1] * sin(a))).normalized()       # approx surface normal
    bm = merge(bm, rbox((0, 0, 0), (0.085, 0.05, 0.026), r=0.01, matrix=basis_z(lp + ln * 0.002, ln), mat=DARK))
    bm = merge(bm, rbox((0, 0, 0), (0.06, 0.034, 0.008), r=0.003, segs=1, matrix=basis_z(lp + ln * 0.0135, ln), mat=GLOW))
    # rear vent ring
    bm = merge(bm, cyl((0, -0.175, 1.61), (0, -0.215, 1.61), 0.052, 0.046, segs=12, mat=DARK))
    # chin / lower rim
    bm = merge(bm, tube([(0, 0.0, 1.425), (0, 0.0, 1.465)], [(0.12, 0.12), (0.125, 0.125)], segs=20, mat=DARK))
    return bm


def build_visor():
    us = [-1, -0.88, -0.7, -0.5, -0.3, -0.1, 0.1, 0.3, 0.5, 0.7, 0.88, 1]
    ws = [-1, -0.8, -0.5, -0.2, 0.1, 0.4, 0.7, 0.88, 1]
    th_max, ph0, ph_max, k = radians(62), radians(9), radians(35), 0.30
    rows = []
    for w in ws:
        row = []
        for u in us:
            x = u * sqrt(1 - k * w * w)
            y = w * sqrt(1 - k * u * u)
            th = x * th_max
            ph = ph0 + y * ph_max
            border = abs(u) == 1 or abs(w) == 1
            d = V((sin(th) * cos(ph), cos(th) * cos(ph), sin(ph)))
            row.append(helm_surface(d, 1.004 if border else 1.055))
        rows.append(row)
    bm = A.grid_surface(rows)
    bm.faces.ensure_lookup_table()
    nc = len(us) - 1
    nr = len(ws) - 1
    for idx, f in enumerate(bm.faces):
        i, j = divmod(idx, nc)
        f.normal_update()        # QA fix: f.normal was stale (zero) right after faces.new -> nothing was flipped, visor faced inward
        if f.normal.dot(f.calc_center_median() - HC) < 0:
            f.normal_flip()
        if i == 0 or i == nr - 1 or j == 0 or j == nc - 1:
            f.material_index = 2     # dark frame
        elif ws[i] >= 0.39:
            f.material_index = 1     # gold band
        else:
            f.material_index = 0     # blue glass
    return bm


def build_arm(s):
    S = V((SX * s, 0, 1.375))
    E = V(((SX + 0.043) * s, 0.035, 1.115))
    mid = (S + E) * 0.5 + V((0.008 * s, -0.012, 0))
    bm = tube([S, mid, E], [0.07, 0.068, 0.061], segs=12, mat=SUIT)
    bm = merge(bm, ellipsoid(S, (0.076, 0.076, 0.076), 10, 6, mat=DARK))
    rot = Euler((0, 0.38 * s, 0)).to_matrix().to_4x4()
    bm = merge(bm, ellipsoid(S + V((0.026 * s, 0, 0.036)), (0.096, 0.102, 0.07), u=14, v=8, e=0.8, mat=ACC, matrix=rot))
    off = V((0.004 * s, -0.006, 0))
    bm = merge(bm, tube([S * 0.55 + E * 0.45 + off, S * 0.42 + E * 0.58 + off], [0.0705, 0.0695], segs=12, mat=ACC))
    bm = merge(bm, ellipsoid(E, (0.064, 0.064, 0.064), 10, 6, mat=DARK))
    return bm, S


def build_forearm(s):
    E = V(((SX + 0.043) * s, 0.035, 1.115))
    W = V(((SX + 0.028) * s, 0.168, 1.0))
    d = (W - E).normalized()
    bm = tube([E, E + (W - E) * 0.5 + V((0.003 * s, 0.004, 0.004)), W], [0.062, 0.064, 0.056], segs=12, mat=SUIT)
    # cuff
    bm = merge(bm, tube([W - d * 0.035, W + d * 0.012], [0.066, 0.066], segs=12, mat=DARK))
    bm = merge(bm, tube([W - d * 0.032, W - d * 0.018], [0.0675, 0.0675], segs=12, mat=ACC))
    # glove
    H = W + d * 0.072
    pm = basis(H, d)
    bm = merge(bm, rbox((0, 0, 0), (0.088, 0.10, 0.06), r=0.02, matrix=pm, mat=DARK))
    right = V(pm.col[0][:3])
    upv = V(pm.col[2][:3])
    fwd = d
    xs = (-0.0315, -0.0105, 0.0105, 0.0315)
    lens = (0.95, 1.05, 1.0, 0.88)
    for x, ln in zip(xs, lens):
        p0 = H + fwd * 0.042 + right * x
        p1 = p0 + fwd * 0.036 * ln - upv * 0.004
        p2 = p1 + fwd * 0.026 * ln - upv * 0.022
        bm = merge(bm, tube([p0, p1, p2], [0.0195, 0.0185, 0.0155], segs=6, round_end=1, mat=DARK))
    # thumb (inner side)
    t0 = H + right * (-0.040 * s) + fwd * (-0.012)
    t1 = t0 + right * (-0.026 * s) + fwd * 0.030 + upv * 0.004
    t2 = t1 + right * (-0.004 * s) + fwd * 0.026 + upv * 0.004
    bm = merge(bm, tube([t0, t1, t2], [0.022, 0.0195, 0.0165], segs=6, round_end=1, mat=DARK))
    # knuckle plate
    bm = merge(bm, rbox(H + upv * 0.033 + fwd * 0.012, (0.07, 0.058, 0.012), r=0.004, segs=1, matrix=basis((0, 0, 0), d), mat=ACC))
    # wrist computer on the left forearm / sensor strip on the right
    fc = E + (W - E) * 0.5
    up2 = V(pm.col[2][:3])
    if s < 0:
        c2 = fc + up2 * 0.066
        bm = merge(bm, rbox(c2, (0.08, 0.105, 0.028), r=0.008, matrix=basis((0, 0, 0), d), mat=DARK))
        bm = merge(bm, rbox(c2 + up2 * 0.0136, (0.058, 0.08, 0.004), r=0.0015, segs=1, matrix=basis((0, 0, 0), d), mat=GLOW))
    else:
        c2 = fc + up2 * 0.063
        bm = merge(bm, rbox(c2, (0.055, 0.085, 0.020), r=0.006, matrix=basis((0, 0, 0), d), mat=ACC))
        bm = merge(bm, rbox(c2 + up2 * 0.0105, (0.014, 0.05, 0.004), r=0.0015, segs=1, matrix=basis((0, 0, 0), d), mat=GLOW))
    hand = H + fwd * 0.015 - upv * 0.002
    return bm, E, hand


def build_leg(s):
    cx = 0.108 * s
    HP = V((cx, 0, 0.90))
    K = V((cx, 0.018, 0.50))
    bm = tube([(cx, 0.0, 0.925), (cx, 0.012, 0.72), K + V((0, 0, 0.01))], [0.102, 0.096, 0.08], segs=14, round_start=1, mat=SUIT)
    bm = merge(bm, ellipsoid(K, (0.074, 0.074, 0.074), 10, 6, mat=DARK))
    # cargo pocket (outer thigh) + strap
    bm = merge(bm, rbox((cx + 0.1 * s, 0.0, 0.715), (0.052, 0.12, 0.15), r=0.016, mat=DARK))
    bm = merge(bm, rbox((cx + 0.1035 * s, 0.0, 0.775), (0.054, 0.122, 0.035), r=0.01, mat=ACC))
    bm = merge(bm, tube([(cx, 0.012, 0.645), (cx, 0.014, 0.665)], [0.0995, 0.0995], segs=14, mat=ACC))
    return bm, HP


def build_shin(s):
    cx = 0.108 * s
    K = V((cx, 0.018, 0.50))
    bm = tube([K, (cx, 0.008, 0.36), (cx, 0.0, 0.21)], [0.073, 0.071, 0.066], segs=12, mat=SUIT)
    # knee pad + shin guard
    bm = merge(bm, rbox((cx, 0.08, 0.512), (0.108, 0.054, 0.12), r=0.022, matrix=Matrix.Rotation(0.12, 4, 'X'), mat=ACC))
    bm = merge(bm, rbox((cx, 0.074, 0.35), (0.08, 0.03, 0.19), r=0.012, mat=SUIT))
    bm = merge(bm, rbox((cx, 0.0905, 0.35), (0.03, 0.006, 0.15), r=0.002, segs=1, mat=DARK))
    # ankle cuff
    bm = merge(bm, tube([(cx, 0.0, 0.17), (cx, 0.0, 0.225)], [0.078, 0.075], segs=12, mat=DARK))
    # boot upper
    rings = [ring_pts(cx, 0.0, 0.215, 0.074, 0.074, 14, p=2.2),
             ring_pts(cx, 0.015, 0.13, 0.084, 0.096, 14, p=2.4),
             ring_pts(cx, 0.045, 0.06, 0.09, 0.142, 14, p=2.6),
             ring_pts(cx, 0.05, 0.028, 0.092, 0.154, 14, p=2.6)]
    bm = merge(bm, loft(rings, mat=SUIT))
    # sole
    bm = merge(bm, loft([ring_pts(cx, 0.05, 0.0, 0.096, 0.162, 16, p=2.6), ring_pts(cx, 0.05, 0.03, 0.097, 0.162, 16, p=2.6)], mat=DARK))
    # toe cap
    bm = merge(bm, ellipsoid((cx, 0.155, 0.05), (0.083, 0.072, 0.052), u=12, v=8, e=0.9, mat=ACC))
    # heel block
    bm = merge(bm, rbox((cx, -0.09, 0.048), (0.11, 0.048, 0.085), r=0.016, mat=DARK))
    # ankle stripe
    bm = merge(bm, tube([(cx, 0.002, 0.185), (cx, 0.002, 0.198)], [0.0785, 0.0785], segs=12, mat=ACC))
    return bm, K


def build_jetpack():
    cy = -0.195
    bm = rbox((0, cy, 1.215), (0.32, 0.15, 0.37), r=0.04, mat=SUIT)
    bm = merge(bm, rbox((0, cy, 1.41), (0.325, 0.155, 0.045), r=0.016, mat=ACC))
    # back panel: dark recessed panel framed by the white shell, with reactor ring + slats
    bm = merge(bm, rbox((0, cy - 0.074, 1.205), (0.2, 0.014, 0.23), r=0.006, mat=DARK))
    bm = merge(bm, tube([(0, cy - 0.080, 1.27), (0, cy - 0.089, 1.27)], [0.036, 0.036], segs=12, mat=GLOW, up=(1, 0, 0)))
    bm = merge(bm, tube([(0, cy - 0.080, 1.27), (0, cy - 0.084, 1.27)], [0.046, 0.046], segs=12, mat=ACC, up=(1, 0, 0)))
    for i in range(4):
        bm = merge(bm, rbox((0, cy - 0.082, 1.185 - i * 0.032), (0.15, 0.008, 0.012), r=0.003, segs=1, mat=SUIT))
    for s in (1, -1):
        tx = 0.2 * s
        bm = merge(bm, tube([(tx, cy, 1.06), (tx, cy, 1.36)], [0.056, 0.056], segs=10, round_start=1, round_end=1, mat=SUIT))
        for z in (1.12, 1.30):
            bm = merge(bm, tube([(tx, cy, z - 0.01), (tx, cy, z + 0.01)], [0.0605, 0.0605], segs=10, mat=ACC))
        bm = merge(bm, tube([(0.15 * s, cy, 1.31), (0.19 * s, cy, 1.31)], [0.016, 0.016], segs=8, mat=DARK))
        bm = merge(bm, tube([(0.15 * s, cy, 1.12), (0.19 * s, cy, 1.12)], [0.016, 0.016], segs=8, mat=DARK))
        # nozzle: bell + collar
        nx = 0.078 * s
        bm = merge(bm, tube([(nx, cy, 1.045), (nx, cy, 0.99), (nx, cy, 0.945)], [0.044, 0.05, 0.06], segs=12, mat=DARK))
        bm = merge(bm, tube([(nx, cy, 1.04), (nx, cy, 1.02)], [0.055, 0.055], segs=12, mat=ACC))
        bm = merge(bm, tube([(nx, cy, 0.948), (nx, cy, 0.94)], [0.05, 0.05], segs=12, mat=GLOW))
        # status lights
        bm = merge(bm, ellipsoid((0.105 * s, cy + 0.05, 1.436), (0.013, 0.013, 0.013), 6, 4, mat=GLOW))
    return bm, V((0, cy, 1.215))


def build_flame(s):
    cy = -0.195
    nx = 0.078 * s
    z0 = 0.94
    pts = [V((nx, cy, z0)), V((nx, cy, z0 - 0.10)), V((nx, cy, z0 - 0.22)), V((nx, cy, z0 - 0.36))]
    bm = tube(pts, [0.045, 0.042, 0.026, 0.0], segs=10, cap_start=True, mat=0)
    return bm, pts[0]


# ---------------------------------------------------------------------------------------------------------------
# assemble
hips = M.add("Hips", build_hips(), MATS4, P_HIPS, parent="Astronaut")
torso = M.add("Torso", build_torso(), MATS4, P_TORSO, parent="Hips")
head = M.add("Head", build_head(), MATS4, P_HEAD, parent="Torso")
M.add("Visor", build_visor(), [visor, gold, dark], P_HEAD, parent="Head", smooth_deg=60)
M.empty("Anchor_Eye", (0, 0.09, 1.655), parent="Head", size=0.04)

for s, sfx in ((1, "R"), (-1, "L")):
    bm, S = build_arm(s)
    M.add("Arm_" + sfx, bm, [suit, dark, accent], S, parent="Torso")
    bm, E, hand = build_forearm(s)
    M.add("Forearm_" + sfx, bm, MATS4, E, parent="Arm_" + sfx)
    M.empty("Anchor_Hand_" + sfx, hand, parent="Forearm_" + sfx, size=0.04)
    bm, HP = build_leg(s)
    M.add("Leg_" + sfx, bm, [suit, dark, accent], HP, parent="Hips")
    bm, K = build_shin(s)
    M.add("Shin_" + sfx, bm, [suit, dark, accent], K, parent="Leg_" + sfx)

bm, jp = build_jetpack()
M.add("Jetpack", bm, MATS4, jp, parent="Torso")
for s, sfx in ((-1, "L"), (1, "R")):
    bm, pv = build_flame(s)
    M.add("JetFlame_" + sfx, bm, [flame], pv, parent="Jetpack", smooth_deg=80)

s = M.report()
M.preview("astronaut", views=((150, 12), (90, 6), (0, 12), (210, 12), (180, 3), (0, 85)), size=(380, 460), cols=3, dist_mult=1.5)
M.preview("astronaut_close", views=((160, 8), (200, 8), (120, 10)), size=(420, 420), cols=3, dist_mult=1.2,
          focus=["Head", "Torso"])
M.export("Astronaut")
M.manifest("character", ["any"],
           {"shape": "cylinder", "radius": 0.3, "height": 1.8, "offset_y": 0.0, "center_y": 0.9},
           nodes={"root": ["Astronaut"], "hierarchy": ["Hips", "Torso", "Head", "Visor", "Arm_L", "Arm_R", "Forearm_L", "Forearm_R",
                                                   "Jetpack", "JetFlame_L", "JetFlame_R", "Leg_L", "Leg_R", "Shin_L", "Shin_R"],
                  "anchors": ["Anchor_Eye", "Anchor_Hand_R", "Anchor_Hand_L"]},
           notes="1.8 m exosuit explorer, origin between the feet, faces Godot -Z. Every limb node origin = its joint (Hips at pelvis, "
                 "Torso at waist, Head at neck, Arm_* at shoulder, Forearm_* at elbow, Leg_* at hip, Shin_* at knee). Rotate about local X "
                 "for walk swing (rotation.x > 0 swings a hanging limb's far end FORWARD, toward -Z). JetFlame_* origin at the "
                 "nozzle exit, cone points down (-Y); scale Y to animate. Materials: astronaut_suit/dark/accent(orange team colour, tintable)/glow/"
                 "visor/gold/flame. Rest pose: relaxed, forearms bent forward ~45 deg.",
           tintable=["accent"])
L.save_blend()
