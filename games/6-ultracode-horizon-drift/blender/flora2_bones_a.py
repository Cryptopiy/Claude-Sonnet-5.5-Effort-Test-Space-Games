"""flora2 / bones_a : ~6.5 m alien beast skeleton half-buried in sand: arched rib cage on a vertebral spine, long skull with horns & teeth."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

MID = "bones_a"
rng = random.Random(7700)
col = L.fresh_collection(MID)
m_bone = L.mat(MID + "_bone", F.hexcol("#efe6d3"), roughness=0.85)
m_aged = L.mat(MID + "_bone_aged", F.hexcol("#cdbb94"), roughness=0.95)
m_dark = L.mat(MID + "_socket", F.hexcol("#2a2119"), roughness=1.0)

bm = bmesh.new()
HS = 2.75   # spine height above the ground


def spine_pts():
    return F.catmull([(0, -3.5, 0.45), (0, -2.7, 1.8), (0, -1.8, HS - 0.1), (0, 0.0, HS + 0.15), (0, 1.3, HS - 0.05), (0, 2.0, HS - 0.9),
                      (0, 2.5, 1.5), (0, 2.85, 0.75)], 8)


sp = spine_pts()
N = len(sp)


def spine_r(i):
    u = i / (N - 1)
    base = F.pw(u, [(0.0, 0.035), (0.15, 0.09), (0.45, 0.13), (0.8, 0.115), (1.0, 0.1)])
    return base * (1.0 + 0.3 * math.cos(F.TAU * u * 26))


F.tube(bm, sp, [spine_r(i) for i in range(N)], segs=6, mat=1, cap_a="apex", cap_b="flat", tip_a=0.1)
# spinous processes on the back
for i in range(int(N * 0.16), int(N * 0.8), 2):
    p = sp[i]
    F.add_cone(bm, p + Vector((0, 0, spine_r(i) * 0.6)), Vector((0, 0.15, 1.0)), 0.3 * (1.0 - abs(i / N - 0.45)), 0.05, segs=4, mat=0, base_cap=False)

# --- ribs ---------------------------------------------------------------------------------------------------------
stations = [-1.8 + i * 0.3 for i in range(11)]
broken = {2: 0.55, 7: 0.7, 9: 0.45}        # (station index on the +X side) truncated ribs
for si, y in enumerate(stations):
    zs = HS + 0.15 * math.cos((y - 0.0) / 3.8 * math.pi * 0.5) + 0.0
    s = 0.62 + 0.38 * math.sin(math.pi * (si + 0.5) / len(stations)) ** 0.8
    for sx in (-1, 1):
        w = 1.0 + rng.uniform(-0.05, 0.05)
        ctrl = [(sx * 0.14, y, zs - 0.06), (sx * 0.72 * s * w, y + 0.02, zs + 0.02), (sx * 1.55 * s * w, y + 0.05, zs - 0.5 * s),
                (sx * 2.05 * s * w, y + 0.09, zs - 1.4 * s), (sx * 2.18 * s * w, y + 0.12, zs - 2.05 * s), (sx * 1.98 * s * w, y + 0.15, 0.08)]
        pts = F.catmull(ctrl, 3)
        cutoff = None
        if sx == 1 and si in broken:
            cutoff = broken[si]
        if cutoff is not None:
            pts = pts[:max(int(len(pts) * cutoff), 4)]
        n = len(pts)
        radii = [F.pw(i / (n - 1), [(0.0, 0.085), (0.4, 0.125), (1.0, 0.05)]) * (0.9 + 0.2 * s) for i in range(n)]
        rows = [1 if i < 3 else 0 for i in range(n - 1)]
        if cutoff is not None:
            rows[-1] = 1
        F.tube(bm, pts, radii, segs=5, mat=0, cap_a="flat", cap_b="flat" if cutoff is not None else "apex", tip_b=0.08, aspect=0.6, mat_rows=rows)

# a fallen rib lying in the sand
fr = F.catmull([(2.9, -2.2, 0.1), (3.5, -1.5, 0.12), (3.9, -0.5, 0.1), (3.6, 0.3, 0.09)], 4)
F.tube(bm, fr, [F.pw(i / (len(fr) - 1), [(0.0, 0.1), (0.5, 0.12), (1.0, 0.04)]) for i in range(len(fr))], segs=5, mat=1, cap_a="flat", cap_b="apex", tip_b=0.08)

# --- skull -------------------------------------------------------------------------------------------------------
Y0 = 2.75
LS = 1.75
ts = [0.0, 0.14, 0.3, 0.5, 0.7, 0.88, 1.0]
hw = [0.30, 0.43, 0.40, 0.31, 0.21, 0.14, 0.09]
hh = [0.27, 0.37, 0.34, 0.26, 0.18, 0.12, 0.08]
rings = []
for k, t in enumerate(ts):
    y = Y0 + LS * t
    zc = 0.1 + hh[k] + 0.04
    ring = []
    for j in range(10):
        a = F.TAU * j / 10
        sn = math.sin(a)
        zz = zc + hh[k] * (sn if sn > 0 else sn * 0.55)
        ring.append(Vector((math.cos(a) * hw[k], y, zz)))
    rings.append(ring)
# orientation: ring runs around +Y; use loft winding via reversed ring so normals face outward
rings = [r[::-1] for r in rings]
F.loft(bm, rings, True, "flat", Vector((0, Y0 + LS + 0.05, 0.1 + hh[-1] + 0.04)), 0, mat_rows=[0] * (len(rings) - 1))
# eye sockets + nostrils
for sx in (-1, 1):
    e = F.ico_blob((0.11, 0.07, 0.1), 1, 3, 0.05, 1.0, 1)
    for v in e.verts:
        v.co += Vector((sx * 0.37, Y0 + LS * 0.27, 0.1 + 0.37 + 0.12))
    for f in e.faces:
        f.material_index = 2
    bm = F.merge(bm, e)
    nst = F.ico_blob((0.03, 0.04, 0.04), 1, 5, 0.0, 1.0, 1)
    for v in nst.verts:
        v.co += Vector((sx * 0.05, Y0 + LS * 0.98, 0.1 + 0.12 + 0.07))
    for f in nst.faces:
        f.material_index = 2
    bm = F.merge(bm, nst)
# teeth
for sx in (-1, 1):
    for i in range(8):
        t = 0.38 + i * 0.075
        k = 3
        y = Y0 + LS * t
        w = F.pw(t, list(zip(ts, hw)))
        h = F.pw(t, list(zip(ts, hh)))
        F.add_cone(bm, Vector((sx * w * 0.82, y, 0.1 + h * 0.4 + 0.04)), Vector((0, 0.05, -1.0)), 0.13, 0.03, segs=4, mat=0, base_cap=False)
# horns and crest
for sx in (-1, 1):
    hp = F.catmull([(sx * 0.24, Y0 + 0.35, 0.62), (sx * 0.5, Y0 + 0.05, 0.9), (sx * 0.9, Y0 - 0.4, 1.45), (sx * 1.05, Y0 - 0.9, 2.2)], 4)
    F.tube(bm, hp, [F.lerp(0.11, 0.015, (i / (len(hp) - 1)) ** 0.85) for i in range(len(hp))], segs=5, mat=1, cap_a="flat", cap_b="apex", tip_b=0.12)
for i in range(3):
    F.add_cone(bm, Vector((0, Y0 + 0.28 - i * 0.2, 0.7 - i * 0.04)), Vector((0, -0.4, 1.0)), 0.5 - i * 0.1, 0.07, segs=4, mat=1)

F.xf_bm(bm, F.Matrix.Diagonal(Vector((0.8, 0.8, 0.8, 1.0))))
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_bone, m_aged, m_dark], smooth_deg=55)
F.finish(MID, [ob], "prop", ["desert", "barren"],
         {"shape": "none"},
         tintable=[],
         notes="Alien skeleton ~6.5 m long (along Y; skull toward +Y = Godot -Z), ~5 m wide incl. fallen rib, rib arches ~2.7 m tall (walk-under). Origin at ground, centre of the rib cage. "
               "No collider (QA decision): the ribs are thin and the player is meant to walk under/through the rib cage; a solid bounding box would wall it off. "
               "If a collider is wanted, use a small cylinder at the skull (the -Z end) only.",
         dist_mult=1.55)
