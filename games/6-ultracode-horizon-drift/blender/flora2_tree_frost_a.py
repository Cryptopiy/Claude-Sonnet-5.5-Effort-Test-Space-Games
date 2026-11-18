"""flora2 / tree_frost_a : ~9 m snow-laden conifer. Drooping scalloped tiers of dark needles, each wearing a layer of snow."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "tree_frost_a")
SD = OVR.get("seed", 1212)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_trunk = L.mat(MID + "_trunk", F.hexcol("#5b4637"), roughness=0.95)
m_needle = L.mat(MID + "_needle", F.hexcol("#1a5c55"), roughness=0.8)
m_snow = L.mat(MID + "_snow", F.hexcol("#f1f8ff"), roughness=0.9)

bm = bmesh.new()
H = 9.2
# --- trunk -------------------------------------------------------------------------------------------------------
path = F.catmull([(0, 0, 0), (0.05, 0.03, 2.5), (-0.03, 0.05, 5.5), (0.02, 0.0, H - 0.5)], 5)
tr = [F.lerp(0.42, 0.05, (i / (len(path) - 1)) ** 0.8) * (1.0 + 0.5 * math.exp(-i * 0.9)) for i in range(len(path))]
F.tube(bm, path, tr, segs=8, mat=0, cap_a="flat", cap_b="apex", tip_b=0.1)

# --- tiers -------------------------------------------------------------------------------------------------------
n_tiers = 11
K = 9                  # fingers (branch tips) per tier
SEGS = K * 3


def finger(th, phi, lo, hi):
    return lo + (hi - lo) * abs(math.cos(K * (th + phi) / 2.0)) ** 1.6


for t in range(n_tiers):
    f = t / (n_tiers - 1)
    ztop = 2.2 + f * (H - 3.0) + rng.uniform(-0.08, 0.08)
    R = F.lerp(2.6, 0.5, f ** 0.9) * rng.uniform(0.94, 1.06)
    h = R * 0.56 + 0.2
    jx, jy = rng.uniform(-0.12, 0.12) * (1 - f), rng.uniform(-0.12, 0.12) * (1 - f)
    tilt = rng.uniform(0.05, 0.14)
    psi = rng.random() * F.TAU
    phi = rng.random() * F.TAU
    lo = 0.8
    hi = 1.12
    prof = [(ztop - h, R), (ztop - 0.55 * h, 0.7 * R), (ztop - 0.18 * h, 0.35 * R), (ztop, 0.06 * R)]

    def mod(th, z, r, i, R=R, phi=phi):
        w = (r / R) ** 1.6            # edge rows carry the full finger pattern
        fm = finger(th, phi, lo, hi)
        return r * (1.0 + (fm - 1.0) * w)

    def zmod(th, z, r, i, R=R, phi=phi, h=h, tilt=tilt, psi=psi):
        tl = tilt * (r / R) * math.cos(th - psi) * R * 0.5
        if i != 0:
            return tl
        return tl - 0.22 * h * (0.5 + 0.5 * math.cos(K * (th + phi))) + 0.1 * h      # fingertips droop

    F.lathe(bm, prof, segs=SEGS, mod=mod, mat=1, cap_top="apex", cap_bottom=None, top_dome=0.0, zmod=zmod, rot0=0.0, centre=lambda z, jx=jx, jy=jy: (jx, jy))

    # snow layer: same umbrella, slightly above the needles, shorter tongues
    def zn(r_frac):
        # needle surface height at radius fraction (piecewise through the profile rows)
        pts = [(0.06, ztop), (0.35, ztop - 0.18 * h), (0.7, ztop - 0.55 * h), (1.0, ztop - h)]
        return F.pw(r_frac, pts)

    off = 0.11
    sp = [(zn(0.92) + off * 0.2, 0.92 * R), (zn(0.7) + off, 0.7 * R), (zn(0.35) + off, 0.35 * R), (zn(0.06) + off, 0.07 * R)]

    def smod(th, z, r, i, R=R, phi=phi):
        if i == 0:
            fm = finger(th, phi, 0.8, 1.1) * (0.9 + 0.16 * F.n3(math.cos(th) * 2, math.sin(th) * 2, t, 5))
            return r * fm
        return r * (1.0 + 0.1 * (finger(th, phi, lo, hi) - 1.0) * (r / R))

    def szmod(th, z, r, i, R=R, phi=phi, h=h, tilt=tilt, psi=psi):
        tl = tilt * (r / R) * math.cos(th - psi) * R * 0.5
        if i != 0:
            return tl
        return tl - 0.16 * h * (0.5 + 0.5 * math.cos(K * (th + phi))) + 0.05 * h

    F.lathe(bm, sp, segs=SEGS, mod=smod, mat=2, cap_top="apex", cap_bottom=None, top_dome=0.02, zmod=szmod, centre=lambda z, jx=jx, jy=jy: (jx, jy))

# top leader + snow cap
lead = F.tube(bm, [Vector((0.02, 0.0, H - 0.9)), Vector((0.02, 0.0, H + 0.4))], [0.2, 0.03], segs=6, mat=1, cap_a=None, cap_b="apex", tip_b=0.2)
F.tube(bm, [Vector((0.02, 0.0, H - 0.35)), Vector((0.02, 0.0, H + 0.55))], [0.11, 0.02], segs=6, mat=2, cap_a=None, cap_b="apex", tip_b=0.2)

# snow mound at the foot of the trunk
mound = F.lathe(bm, [(0.0, 1.5), (0.1, 1.15), (0.26, 0.6), (0.34, 0.28)], segs=14, mat=2, cap_top="apex", cap_bottom=None,
                mod=lambda th, z, r, i: r * (1.0 + 0.18 * F.n3(math.cos(th) * 1.5, math.sin(th) * 1.5, z, 3)))

F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, [m_trunk, m_needle, m_snow], smooth_deg=55)
F.finish(MID, [ob], "flora", ["frozen"],
         F.vc({"shape": "cylinder", "radius": 0.45, "height": 5.0, "offset_y": 0.0}, OVR),
         tintable=["needle"],
         notes="Snow-laden conifer 9.95 m tall incl. leader (trunk to 9.2 m), 11 drooping tiers (radius up to ~2.7 m at the bottom tier, canopy starts ~1.4 m above ground). "
               "Materials: trunk, needle (tintable dark teal), snow (white caps). Collider = trunk only.",
         dist_mult=1.5)
