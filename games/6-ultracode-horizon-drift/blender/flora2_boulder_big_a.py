"""flora2 / boulder_big_a : ~9 m landmark boulder.  QA rework: a cleaved two-part boulder (dark fissure between the halves), a balanced
capstone bridging the cleft, flanking blocks + rubble, shared horizontal strata bands, darker undersides and muted lichen patches.
The first version was one smooth heap with a jagged 'gravestone' slab and neon lichen decals."""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy, bmesh
from mathutils import Vector, Matrix
L = F.L

OVR = globals().get("OVR", {})
MID = OVR.get("MID", "boulder_big_a")
SD = OVR.get("seed", 3030)
rng = random.Random(SD)
col = L.fresh_collection(MID)
m_rock = L.mat(MID + "_rock", F.hexcol("#6f6258"), roughness=0.95)
m_dark = L.mat(MID + "_rock_dark", F.hexcol("#352f2b"), roughness=0.97)
m_lichen = L.mat(MID + "_lichen", F.hexcol("#76823f"), roughness=1.0)
m_strata = L.mat(MID + "_rock_light", F.hexcol("#86796a"), roughness=0.95)


def place(bm, dx, dy, dz=0.0, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        v.co.x = x * c - y * s + dx
        v.co.y = x * s + y * c + dy
        v.co.z += dz
    return bm


def piece(radius, seed, planes, dist, **kw):
    return F.faceted_rock(radius, kw.pop("subdiv", 4), seed + SD, kw.pop("amp", 0.2), kw.pop("freq", 1.0), planes=planes, plane_dist=dist,
                          up_bias=kw.pop("up_bias", 0.25), rng=rng, bottom=kw.pop("bottom", 0.55), sink=kw.pop("sink", 0.3),
                          fine=(0.05, 2.2), octaves=3, **kw)


# --- the two cleaved halves: each gets a (slightly tilted) flat cleavage face toward the other one
A = piece((2.4, 2.9, 3.9), 1, 15, 0.72, freq=0.9)
F.plane_cut(A, [(Vector((0.55, 0.0, 0.0)), Vector((1.0, 0.12, 0.06)))])
place(A, -1.25, 0.1, 0.0, 0.05)
B = piece((2.5, 2.7, 4.9), 2, 15, 0.72, freq=0.9)
F.plane_cut(B, [(Vector((-0.55, 0.0, 0.0)), Vector((-1.0, -0.1, 0.05)))])
place(B, 1.5, -0.1, 0.0, -0.08)
bm = F.merge(A, B)
# --- balanced capstone bridging the fissure
ztop = max(F.top_z(bm, -1.0, 0.1, 1.4), F.top_z(bm, 1.4, 0.0, 1.4))
cap = piece((2.2, 1.45, 1.0), 3, 11, 0.74, subdiv=3, bottom=0.5, sink=0.0, up_bias=0.1, amp=0.18)
for v in cap.verts:
    v.co.z -= 0.0
cap = place(cap, 0.25, 0.15, ztop - 0.75, 0.35)
# tilt the capstone ~10 degrees about Y so it sits on the two peaks
Rm = Matrix.Rotation(math.radians(9), 4, "Y")
cc = Vector((0.25, 0.15, ztop))
for v in cap.verts:
    v.co = cc + (Rm @ (v.co - cc))
bm = F.merge(bm, cap)
# --- flanking blocks, partly leaning into the main mass
for (cx, cy, rr, sd, rot) in ((3.8, 1.0, 1.6, 5, 0.4), (-3.7, -1.1, 1.5, 8, 1.2), (1.6, -2.9, 1.15, 9, 0.0), (-2.2, 2.5, 1.0, 12, 0.7), (2.7, 2.6, 0.8, 14, 0.3)):
    sm = piece((rr, rr * 0.85, rr * 0.9), sd, 10, 0.74, subdiv=3, bottom=0.45, sink=0.12, up_bias=0.3, amp=0.25)
    bm = F.merge(bm, place(sm, cx, cy, 0.0, rot))
# --- small rubble
for i in range(9):
    a = rng.random() * F.TAU
    d = rng.uniform(3.2, 4.8)
    rr = rng.uniform(0.28, 0.6)
    sm = piece((rr, rr * 0.85, rr * 0.7), 20 + i, 6, 0.78, subdiv=2, bottom=0.45, sink=0.06, up_bias=0.3, amp=0.25)
    bm = F.merge(bm, place(sm, math.cos(a) * d * 1.1, math.sin(a) * d * 0.85, 0.0, rng.random() * 3))
# --- materials: shared horizontal strata, dark undersides + fissure, lichen patches on tops and in sheltered nooks
F.vein_bands(bm, 3, (0.05, 0.02, 1.0), 0.55, 0.34, 0.22, seed=7, only_mats=[0], nfreq=0.4)
F.under_mat(bm, 1, -0.4, only_mats=[0, 3])
for f in bm.faces:
    c = F.face_center(f)
    if abs(c.x) < 0.9 and c.z < 4.8 and abs(f.normal.x) > 0.75:
        f.material_index = 1
F.snow_cap(bm, 2, thick=0.035, threshold=0.58, noise_amp=0.5, seed=13, freq=0.55, only_mats=[0, 3], smooth_iter=3)
F.apply_variant(bm, OVR)
F.flat_base(bm, 0.0, True)
ob = F.build_obj(MID, bm, col, [m_rock, m_dark, m_lichen, m_strata], smooth_deg=40)
F.finish(MID, [ob], "rock", ["any", "barren", "desert", "frozen"],
         F.vc({"shape": "cylinder", "radius": 3.8, "height": 6.0, "offset_y": 0.0}, OVR),
         tintable=["rock", "lichen"],
         notes="~9 m wide x ~6.5 m tall landmark boulder: cleaved into two halves with a dark fissure, a balanced capstone bridging the cleft, "
               "5 flanking blocks + rubble. Slots rock, rock_dark (undersides + fissure), lichen (tintable, up-facing patches), rock_light (strata bands). "
               "Origin ground centre.", dist_mult=1.6)
