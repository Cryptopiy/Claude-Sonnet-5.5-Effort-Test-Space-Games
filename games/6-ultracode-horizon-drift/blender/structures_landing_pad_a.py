import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "landing_pad_a"
col = L.fresh_collection(ID)
R = 9.0

M = S.mats(ID, {
    "deck": dict(color=(0.21, 0.225, 0.245), metallic=0.25, roughness=0.6),
    "base": "dconcrete",
    "trim": "graphite",
    "yellow": "yellow",
    "white": dict(color=(0.56, 0.56, 0.53), metallic=0.1, roughness=0.6),
    "light": "emit_cyan",
})
rnd = random.Random(7)


def arc_pts(r, a0, a1, n):
    return [(r * math.cos(a0 + (a1 - a0) * i / n), r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def sector(mb, r0, r1, a0, a1, z0, z1, mat, steps=2):
    outer = arc_pts(r1, a0, a1, steps)
    if r0 < 1e-6:
        pts = [(0, 0)] + outer
    else:
        pts = outer + arc_pts(r0, a0, a1, steps)[::-1]
    mb.prism(pts, z0, z1, mat=mat)


pad = S.MB(M)

# ---- skirt (hides terrain edge): flared dark concrete, base 1.5 m below the deck -------------------------------
pad.lathe([(0, -1.5), (9.55, -1.5), (9.55, -1.15), (9.3, -0.95), (9.3, -0.55), (9.05, -0.4), (9.05, -0.04), (0, -0.04)],
          segs=48, mat="base")
# horizontal band lines on the skirt
pad.lathe([(9.28, -1.1), (9.62, -1.1), (9.62, -1.0), (9.28, -1.0), (9.28, -1.1)], segs=48, mat="trim")

# ---- deck plates (three rings, gaps show the dark deck slab underneath) ------------------------------------------
pad.lathe([(0, -0.05), (8.35, -0.05), (8.35, -0.03), (0, -0.03)], segs=48, mat="trim")
rings = [(0.0, 3.4, 8), (3.5, 6.75, 16), (6.85, 8.35, 24)]
gap = 0.05
for (r0, r1, n) in rings:
    for i in range(n):
        a0 = TAU0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        rr = max(r0, 0.01) if r0 > 0 else 0
        da = (gap / max(r1, 0.5)) * 0.5
        pad_r0 = r0 + (0.025 if r0 > 0 else 0)
        pad_r1 = r1 - 0.025
        sector(pad, pad_r0, pad_r1, a0 + da, a1 - da, -0.03, 0.0, "deck", steps=3 if r1 > 4 else 2)

# glowing seam rings between the plate rings (visible through the gaps)
for rr_ in (3.45, 6.8):
    pad.lathe([(rr_ - 0.02, -0.034), (rr_ + 0.02, -0.034), (rr_ + 0.02, -0.02), (rr_ - 0.02, -0.02), (rr_ - 0.02, -0.034)], segs=72, mat="light")

# ---- rim: sloped raised lip ------------------------------------------------------------------------------------
pad.lathe([(8.30, -0.04), (9.05, -0.04), (9.05, 0.05), (8.9, 0.15), (8.55, 0.15), (8.32, 0.0), (8.30, -0.04)], segs=96, mat="trim")
# hazard stripes on the rim top (yellow on even slots)
for k in range(24):
    if k % 2 == 0:
        a0 = 2 * math.pi * k / 24
        a1 = 2 * math.pi * (k + 1) / 24
        sector(pad, 8.58, 8.9, a0, a1, 0.145, 0.158, "yellow", steps=2)
# inner ramp edge line
pad.lathe([(8.2, 0.0), (8.34, 0.0), (8.34, 0.018), (8.2, 0.018), (8.2, 0.0)], segs=96, mat="yellow")

# ---- paint markings (raised 2 cm) ----------------------------------------------------------------------------------
Z0, Z1 = 0.0, 0.022
pad.lathe([(7.25, Z0), (7.55, Z0), (7.55, Z1), (7.25, Z1), (7.25, Z0)], segs=96, mat="yellow")
# dashed inner ring
for k in range(12):
    a0 = 2 * math.pi * k / 12 + 0.06
    a1 = 2 * math.pi * (k + 1) / 12 - 0.30
    sector(pad, 5.35, 5.55, a0, a1, Z0, Z1, "yellow", steps=3)
# H marking
bw = 0.62
pad.box((-1.9, 0, Z1 / 2), (bw, 5.6, Z1), mat="white")
pad.box((1.9, 0, Z1 / 2), (bw, 5.6, Z1), mat="white")
pad.box((0, 0, Z1 / 2), (3.8 - bw, bw, Z1), mat="white")
# chevrons at the 4 compass points pointing at the H
chev = [(-0.9, 0.55), (0, -0.15), (0.9, 0.55), (0.9, 1.05), (0, 0.4), (-0.9, 1.05)]
for k in range(4):
    a = k * math.pi / 2
    ca, sa = math.cos(a), math.sin(a)
    # chevron placed at +Y then rotated about Z
    pts = [(x * ca - (y + 6.05) * sa, x * sa + (y + 6.05) * ca) for x, y in chev]
    pad.prism(pts, Z0, Z1, mat="white")
# pad number plate near console: small strip marks
for i in range(3):
    pad.box((-3.0 + i * 0.5, -6.55, Z1 / 2), (0.28, 0.9, Z1), mat="yellow")

# ---- floodlight masts ------------------------------------------------------------------------------------------
for ang in (45, 225, 315):
    a = math.radians(ang)
    p = Vector((8.75 * math.cos(a), 8.75 * math.sin(a), 0.0))
    inward = Vector((-math.cos(a), -math.sin(a), 0))
    pad.cyl(p + Vector((0, 0, 0.11)), 0.32, 0.26, 0.22, segs=12, mat="trim", bevel=0.02)
    pad.cyl(p + Vector((0, 0, 1.75)), 0.085, 0.06, 3.3, segs=8, mat="white")
    pad.cyl(p + Vector((0, 0, 0.7)), 0.12, 0.11, 0.18, segs=8, mat="yellow")
    # head
    hp = p + Vector((0, 0, 3.45))
    rm = S.rot_to(inward + Vector((0, 0, -0.35)))
    # lamp housing: box facing inward (local +Z of rm = direction)
    pad.box(hp + inward * 0.12, (0.7, 0.45, 0.16), rot=rm, mat="trim", bevel=0.02)
    pad.box(hp + inward * 0.12 + (inward + Vector((0, 0, -0.35))).normalized() * 0.09, (0.58, 0.34, 0.03), rot=rm, mat="light")
    pad.cyl(hp + Vector((0, 0, -0.1)), 0.05, 0.05, 0.25, segs=6, mat="trim")

pad_ob = pad.build(ID + "_Pad", col, smooth=38)
pad_ob.name = S.nm(ID, "Pad")

# ---- console ----------------------------------------------------------------------------------------------------
cons = S.MB(M)
cons.box((0, 0, 0.06), (1.9, 1.5, 0.12), mat="trim", bevel=0.03)                      # platform
cons.box((0, 0, 0.145), (1.82, 1.42, 0.03), mat="yellow")                             # platform edge paint under
cons.box((0, 0, 0.21), (1.7, 1.3, 0.06), mat="trim", bevel=0.02)
cons.box((0, -0.05, 0.64), (0.95, 0.62, 0.8), mat="white", bevel=0.04, top=(0.92, 0.55))   # pedestal
cons.box((0, -0.05, 0.28), (1.02, 0.7, 0.12), mat="trim", bevel=0.03)                 # plinth
# sloped screen head
head_rot = (math.radians(-28), 0, 0)
cons.box((0, 0.02, 1.2), (1.1, 0.5, 0.34), rot=head_rot, mat="white", bevel=0.04)
cons.box((0, 0.185, 1.245), (0.9, 0.04, 0.24), rot=head_rot, mat="trim")
scr_c = Vector((0, 0.2, 1.255))
cons.box((0, 0.215, 1.255), (0.8, 0.02, 0.18), rot=head_rot, mat="light")
# buttons / keys
for i in range(4):
    cons.box((-0.3 + i * 0.2, 0.19, 0.96), (0.1, 0.07, 0.04), rot=(math.radians(-18), 0, 0), mat="yellow" if i % 2 == 0 else "trim", bevel=0.01)
# side vents + antenna
cons.vent((0.485, -0.05, 0.62), 0.4, 0.4, n=5, rot=(0, 0, math.radians(90)), mat_slat="trim", mat_back="base")
cons.vent((-0.485, -0.05, 0.62), 0.4, 0.4, n=5, rot=(0, 0, math.radians(-90)), mat_slat="trim", mat_back="base")
cons.cyl((0.4, -0.2, 1.35), 0.018, 0.012, 0.7, segs=6, mat="trim")
cons.sphere((0.4, -0.2, 1.72), 0.04, u=8, v=6, mat="light")
cons.pipe([(-0.3, -0.5, 0.1), (-0.3, -0.62, 0.1), (-0.3, -0.62, 0.75), (-0.3, -0.42, 0.78)], 0.03, segs=6, mat="trim", bend=0.08)
ang = math.radians(135)
cpos = Vector((8.0 * math.cos(ang), 8.0 * math.sin(ang), 0.0))
cons.transform(S.M4(cpos + Vector((0, 0, 0.0)), (0, 0, ang + math.pi / 2)))
cons_ob = cons.build(ID + "_Console", col, smooth=38)
cons_ob.name = S.nm(ID, "Console")

# ---- pad lights (shared mesh) ----------------------------------------------------------------------------------------
lm = S.MB(M)
lm.lathe([(0, 0), (0.29, 0), (0.29, 0.03), (0.23, 0.05), (0, 0.05)], segs=14, mat="trim")
lm.lathe([(0, 0.05), (0.19, 0.05), (0.18, 0.09), (0.12, 0.14), (0.05, 0.165), (0, 0.17)], segs=14, mat="light")
light_mesh_ob = lm.build(ID + "_LightMesh", col, smooth=45)
light_mesh = light_mesh_ob.data
bpy.data.objects.remove(light_mesh_ob)
lights = []
for k in range(12):
    a = math.radians(15 + 30 * k)
    o = bpy.data.objects.new(S.nm(ID, "PadLight_%02d" % k), light_mesh)
    col.objects.link(o)
    o.location = (8.73 * math.cos(a), 8.73 * math.sin(a), 0.158)
    lights.append(o)

# ---- anchors -------------------------------------------------------------------------------------------------------------
inward = Vector((-math.cos(ang), -math.sin(ang), 0))
a_door = L.empty(S.nm(ID, "Anchor_Door"), col, tuple(cpos + inward * 1.35), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (0, 0, 0.05), size=0.6)
a_land = L.empty(S.nm(ID, "Anchor_Landing"), col, (0, 0, 0.0), size=1.0, display="CIRCLE")

objs = [pad_ob, cons_ob] + lights + [a_door, a_top, a_land]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "cylinder", "radius": 9.3, "height": 1.5, "offset_y": -1.5, "center": [0, -0.75, 0]},
    nodes={"lights": ["PadLight_%02d" % k for k in range(12)], "anchors": ["Anchor_Door", "Anchor_Top", "Anchor_Landing"],
           "meshes": ["Pad", "Console"]},
    preview_kw=dict(dist_mult=1.25),
    tintable=[],
    notes="Round landing pad d=18 m. Top face at y=0 (Godot), skirt extends 1.5 m below. Collider offset_y = y of collider BOTTOM, center = collider centre (Godot axes). "
          "H marking: bars along model Y (ship nose = Godot -Z). 12 emissive cyan PadLight_00..11 (origin = light position on the rim, y=0.158) share one mesh+material; "
          "Console at 135deg (Blender -X,+Y quadrant); Anchor_Door = interact stand point in front of console; Anchor_Top = pad centre (beam origin); Anchor_Landing = pad centre.",
)
print(entry)
