import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "tree_swamp_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_bark", "#4a3a32", rough=1.0),
    F.M(ID + "_moss", "#6d9a36", rough=1.0),
    F.M(ID + "_leaf", "#2e6e3c", rough=0.7),
    F.M(ID + "_leaf_dark", "#10352c", rough=0.75),
    F.M(ID + "_vine", "#86a83e", rough=0.8),
    F.M(ID + "_glow", "#5cffd6", rough=0.3, emit="#3cf5c8", emit_strength=3.5),
]
BARK, MOSS, LEAF, LDARK, VINE, GLOW = range(6)
b = F.Builder(mats, seed=91)
rng = b.rng

# ---- hub + stilt roots -------------------------------------------------------------------------------------------------------
b.blob((0, 0, 0.75), (0.95, 0.95, 0.8), subdiv=2, amt=0.3, freq=1.3, seed=2, mat=BARK, flat_bottom=0.5)
# ---- gnarled trunk --------------------------------------------------------------------------------------------------------------
tp = F.spline([(0, 0, 0.5), (0.22, 0.10, 1.6), (-0.28, 0.16, 2.9), (0.12, -0.22, 4.1), (0.32, 0.05, 5.2)], 6)
b.tube(tp, lambda t: 0.68 - 0.3 * t + 0.1 * math.sin(t * 9), segs=10, mat=BARK, cap0=False, cap1=True, nz=0.2, nf=1.3, seed=5,
       rmod=lambda t, a, k: 1.0 + 0.1 * math.cos(a * 4 + t * 7))

# ---- branches --------------------------------------------------------------------------------------------------------------------
anchors = []
limb_pts = []
top = tp[-1]
for i in range(4):
    a = i * math.tau / 4 + rng.uniform(-0.35, 0.35)
    el = math.radians(rng.uniform(18, 42))
    d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
    end, ed, info = b.branch(top, d, rng.uniform(2.6, 3.4), 0.3, 0.1, bend=(0, 0, 1), bend_amt=0.15, wobble=0.22, steps=7, segs=7, mat=BARK,
                             nz=0.18, nf=1.2, seed=i + 3, curl=(Vector((0, 0, 1)), rng.choice((-1, 1)) * 1.0))
    anchors.append((end, ed, 1.45))
    limb_pts += info.pts[3:]
    for j in range(2):
        pj = info.pts[3 + j * 2]
        aj = a + (1 if j == 0 else -1) * rng.uniform(0.6, 1.1)
        dj = Vector((math.cos(aj) * 0.8, math.sin(aj) * 0.8, rng.uniform(0.1, 0.5))).normalized()
        e2, d2, inf2 = b.branch(pj, dj, rng.uniform(1.5, 2.2), 0.12, 0.04, bend=(0, 0, -1), bend_amt=0.35, wobble=0.2, steps=5, segs=6, mat=BARK,
                                nz=0.15, seed=i * 4 + j + 20)
        anchors.append((e2, d2, 1.05))
        limb_pts += inf2.pts[2:]
# crown leader
e3, d3, inf3 = b.branch(top, (0.05, 0.02, 1), 2.2, 0.26, 0.08, bend=(0, 0, 1), bend_amt=0.1, wobble=0.2, steps=5, segs=7, mat=BARK, nz=0.15, seed=33)
anchors.append((e3, d3, 1.5))
b.paint_by_normal(BARK, MOSS, 0.62, noise_amt=0.45, nscale=1.4, seed=2)

NR = 7
for i in range(NR):
    a = i * math.tau / NR + rng.uniform(-0.25, 0.25)
    ca, sa = math.cos(a), math.sin(a)
    h0 = rng.uniform(1.5, 2.2)
    Rg = rng.uniform(2.0, 2.9)
    pts = F.spline([(ca * 0.3, sa * 0.3, h0), (ca * 0.9, sa * 0.9, h0 + 0.25), (ca * (Rg * 0.62), sa * (Rg * 0.62), h0 * 0.5),
                    (ca * Rg, sa * Rg, -0.04)], 5)
    b.tube(pts, lambda t: 0.26 * (1 - t) ** 0.8 + 0.06, segs=7, mat=BARK, cap0=False, cap1=True, nz=0.22, nf=1.5, seed=i)
    # small knee roots
    if i % 2 == 0:
        ka = a + rng.uniform(-0.5, 0.5)
        kr = Rg * rng.uniform(0.45, 0.8)
        kp = F.spline([(math.cos(ka) * kr, math.sin(ka) * kr, -0.05), (math.cos(ka) * (kr + 0.12), math.sin(ka) * (kr + 0.12), 0.35),
                       (math.cos(ka) * (kr + 0.18), math.sin(ka) * (kr + 0.18), 0.6)], 3)
        b.tube(kp, (0.1, 0.03), segs=5, mat=BARK, cap1=True, nz=0.2, nf=2.0, seed=40 + i)



# ---- foliage clumps -----------------------------------------------------------------------------------------------------------------
for ci, (pos, dirv, rad) in enumerate(anchors):
    centre = pos + Vector((dirv.x, dirv.y, 0)) * (rad * 0.3) + Vector((0, 0, rad * 0.15))
    b.canopy_cluster(centre, rad, (LDARK, LEAF, LEAF), seed=ci + 11, subdiv=3 if rad > 1.45 else 2, squash=0.5, amt=0.28, freq=1.2, n_sat=1,
                     sat_scale=(0.5, 0.65), sat_spread=0.9, n_fringe=8, n_top=3, leaf_len=(0.8, 1.2), leaf_w=0.4, flat_bottom=0.5, droop=0.55,
                     fringe_down=0.9, top_leaf_scale=0.8)

# ---- hanging vines + moss beards + glow bulbs ---------------------------------------------------------------------------------------
rng.shuffle(limb_pts)
nv = 0
for p in limb_pts[:14]:
    L_ = rng.uniform(1.8, 4.4)
    sway = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * rng.uniform(0.1, 0.4)
    pts = [p, p + sway * 0.3 - Vector((0, 0, L_ * 0.3)), p + sway * 0.7 - Vector((0, 0, L_ * 0.65)), p + sway - Vector((0, 0, L_))]
    hint = Vector((sway.y, -sway.x, 0)) if sway.length > 1e-3 else Vector((1, 0, 0))
    b.ribbon(F.spline(pts, 2), (0.16, 0.04), normal_hint=hint, mat=VINE, tip=True)
    for fz in (0.45, 0.75):
        q = p + sway * fz - Vector((0, 0, L_ * fz))
        sd = Vector((sway.x * 0.7 + rng.uniform(-0.5, 0.5), sway.y * 0.7 + rng.uniform(-0.5, 0.5), -0.3)).normalized()
        b.blade(q, sd, 0.32, 0.17, mat=LEAF, up=Z, droop=0.2)
    if nv % 2 == 0:
        b.blob(pts[-1] - Vector((0, 0, 0.06)), (0.075, 0.075, 0.12), subdiv=1, amt=0.0, mat=GLOW)
    nv += 1
for p in limb_pts[14:20]:
    L_ = rng.uniform(0.9, 1.6)
    pts = [p, p - Vector((0, 0, L_ * 0.5)), p - Vector((0, 0, L_))]
    b.ribbon(pts, (0.34, 0.05), normal_hint=Vector((1, 0.2, 0)), mat=MOSS)

ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["swamp"],
                 {"shape": "cylinder", "radius": 0.75, "height": 5.0, "offset_y": 0.0},
                 tintable=["leaf", "vine"],
                 notes="Origin at the centre of the buttress/stilt-root hub at ground level (z=0). Gnarled swamp tree ~8 m with 7 arching stilt roots (reach ~2.9 m), mossy bark, drooping foliage clumps, hanging vines/moss beards and bioluminescent glow bulbs (glow, emissive 3.5). Collider covers the trunk only.")
print(info)
