"""flora2 / cactus_a : ~4 m ribbed saguaro with two arms, spine tufts and glowing pink flowers."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "cactus_a")
SD = OVR.get("seed", 11)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_skin = L.mat(MID + "_skin", F.hexcol("#2c9a5a"), roughness=0.5)
m_spine = F.mat_dbl(MID + "_spine", F.hexcol("#f5ebc0"), roughness=0.6)  # single-sided needles, material is double sided
m_flower = F.mat_dbl(MID + "_flower", F.hexcol("#ff3f8e"), roughness=0.5, emission=F.hexcol("#ff2f84"), emission_strength=2.5)
m_stamen = L.mat(MID + "_stamen", F.hexcol("#ffe14a"), roughness=0.6, emission=F.hexcol("#ffc400"), emission_strength=3.0)

bm = bmesh.new()
tufts = []   # (pos, out, up, size) collected, built at the end


def ribbed(n, depth):
    def prof(th, u):
        return 1.0 - depth * (0.5 - 0.5 * math.cos(n * th)) ** 1.5
    return prof


def column(path, R0, R1, ribs, dome_h, flare=0.0, tuft_step=2, tuft_len=0.12, depth=0.16, flowers=6, flower_size=0.1):
    # rebuild path with uniform spacing ~ every sample
    N = len(path)
    cum = [0.0]
    for i in range(1, N):
        cum.append(cum[-1] + (path[i] - path[i - 1]).length)
    tot = cum[-1]
    radii = []
    for i in range(N):
        u = cum[i] / tot
        r = F.lerp(R0, R1, u) * (1.0 + flare * math.exp(-cum[i] / 0.28))
        radii.append(r)
    path2, radii2, tip_b = F.extend_dome(path, radii, dome_h, 4)
    info = F.tube(bm, path2, radii2, segs=ribs * 2, mat=0, cap_a="flat", cap_b="apex", tip_b=tip_b,
                  profile=ribbed(ribs, depth), ref=Vector((0, 1, 0)))
    # spine tufts on ridges
    for i in range(1, N - 1, tuft_step):
        inf = info[i]
        for j in range(ribs):
            th = F.TAU * j / ribs
            out = inf["n"] * math.cos(th) + inf["b"] * math.sin(th)
            pos = inf["p"] + out * inf["r"] * 0.995
            tufts.append((pos, out, inf["t"], tuft_len))
    # flowers on the dome (a ring of blossoms near the crown)
    top = info[N - 1]
    P = top["p"]
    tdir = top["t"]
    for j in range(flowers):
        th = F.TAU * j / flowers + rng.random() * 0.4
        a = rng.uniform(0.35, 0.75)
        out = top["n"] * math.cos(th) + top["b"] * math.sin(th)
        pos = P + tdir * (dome_h * math.sin(a)) + out * (R1 * math.cos(a))
        nrm = (pos - (P + tdir * 0.0)).normalized()
        F.flower(bm, pos, (nrm + out * 0.4 + tdir * 0.6).normalized(), flower_size * rng.uniform(0.85, 1.2), 2, rng, petals=6, cup=0.6, two_sided=False, center_mat=3)
    return info


# --- main trunk -------------------------------------------------------------------------------------------------
H = 3.55
trunk_ctrl = [(0, 0, 0.0), (0.04, 0.0, 1.0), (0.0, 0.05, 2.1), (0.05, 0.0, 3.0), (0.03, 0.02, H)]
trunk = F.catmull(trunk_ctrl, 5)
column(trunk, 0.33, 0.26, 10, 0.38, flare=0.35, tuft_step=3, tuft_len=0.14, depth=0.17, flowers=8, flower_size=0.17)

# --- arms -------------------------------------------------------------------------------------------------------
def arm(phi, h0, reach, rise, r0, r1, ribs=8):
    d = Vector((math.cos(phi), math.sin(phi), 0.0))
    # start well inside the trunk, bend out, then up
    ctrl = [d * 0.0 + Vector((0.04, 0, h0)), d * 0.30 + Vector((0.04, 0, h0 + 0.02)), d * (reach * 0.78) + Vector((0.04, 0, h0 + 0.14)),
            d * reach + Vector((0.04, 0, h0 + 0.55)), d * (reach + 0.04) + Vector((0.04, 0, h0 + rise))]
    path = F.catmull(ctrl, 5)
    column(path, r0, r1, ribs, 0.26, flare=0.0, tuft_step=3, tuft_len=0.11, depth=0.15, flowers=5, flower_size=0.13)


arm(0.35, 1.45, 0.95, 1.55, 0.19, 0.155)
arm(math.pi + 0.5, 2.15, 0.82, 1.1, 0.165, 0.135)
arm(1.95, 2.7, 0.5, 0.7, 0.125, 0.105, ribs=7)

# --- spine tufts (two-sided needles) ---------------------------------------------------------------------------
for pos, out, up, ln in tufts:
    F.spine_tuft(bm, pos, out, up, n=3, length=ln, width=0.012, spread=0.55, mat=1, rng=rng, two_sided=False)

F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, drop_bottom=True)
ob = F.build_obj(MID, bm, col, [m_skin, m_spine, m_flower, m_stamen], smooth_deg=50)
F.finish(MID, [ob], "flora", ["desert"],
         F.vc({"shape": "cylinder", "radius": 0.32, "height": 3.9, "offset_y": 0.0}, OVR),
         tintable=["skin", "flower"],
         notes="Saguaro-style ribbed cactus, 2 arms. Origin at ground (bottom-centre of trunk). Materials: skin (green), spine (cream needles, "
               "two-sided, backface culling on), flower (emissive pink). Collider offset_y = bottom of collider; center_y = collider centre (Godot axes).")
