"""Structures (landing pad, outpost, monolith, beacon...), creatures and the cockpit interior."""
import math, random
from mathutils import Vector
exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\3. High Effort\tools\blender\blib.py").read())

wall = mat("st_wall", (0.82, 0.84, 0.86), 0.2, 0.5)
wall_dark = mat("st_dark", (0.16, 0.17, 0.2), 0.6, 0.5)
st_acc = mat("st_accent", (0.9, 0.45, 0.1), 0.3, 0.5)
st_teal = mat("st_teal", (0.1, 0.5, 0.6), 0.3, 0.45)
pad_m = mat("st_pad", (0.3, 0.32, 0.36), 0.5, 0.6)
lamp = mat("st_lamp", (0.4, 0.9, 1.0), 0, 0.3, emit=(0.4, 0.9, 1.0), emit_strength=4.0)
lamp_o = mat("st_lamp_orange", (1.0, 0.6, 0.15), 0, 0.3, emit=(1.0, 0.6, 0.15), emit_strength=4.0)
win = mat("st_window", (0.3, 0.7, 1.0), 0, 0.1, emit=(0.3, 0.75, 1.0), emit_strength=2.5)
solar = mat("st_solar", (0.05, 0.1, 0.3), 0.6, 0.2)
mono = mat("mono_black", (0.02, 0.02, 0.03), 0.7, 0.2)
rune = mat("mono_rune", (0.4, 0.7, 1.0), 0, 0.3, emit=(0.4, 0.75, 1.0), emit_strength=5.0)
glass = mat("ship_glass", (0.25, 0.55, 0.8), 0.0, 0.05, emit=(0.1, 0.25, 0.4), emit_strength=0.3, alpha=0.45)
metal = mat("ship_metal", (0.45, 0.46, 0.5), 0.9, 0.3)
crate_m = mat("crate_body", (0.55, 0.42, 0.2), 0.3, 0.6)


def new(name):
    remove_tree(name)
    return empty(name)


def pub(r, f, **kw):
    export(r, f)
    preview(r, f.replace(".glb", ".png"), elev=kw.get("elev", 22), azim=kw.get("azim", -35), res=(480, 400), dist=kw.get("dist"))
    stash(r)


# ---------------- landing pad: 24 m wide hex-ish disc, ship rests at z=0
r = new("landing_pad")
b = MB("landing_pad_m")
b.cyl((0, 0, 0.15), 11.0, 11.5, 0.3, seg=24, m=pad_m, smooth=False)
b.cyl((0, 0, 0.32), 9.2, 9.2, 0.04, seg=24, m=wall_dark)
b.cyl((0, 0, 0.35), 6.0, 6.0, 0.04, seg=24, m=pad_m)
for i in range(12):
    a = 2 * math.pi * i / 12
    b.box((math.cos(a) * 10.2, math.sin(a) * 10.2, 0.36), (0.9, 0.35, 0.1), rot=(0, 0, math.degrees(a) + 90), m=st_acc)
    b.sphere((math.cos(a) * 8.6, math.sin(a) * 8.6, 0.4), (0.22, 0.22, 0.12), seg=8, rings=4, m=lamp)
b.box((0, 0, 0.38), (1.2, 7.0, 0.04), m=st_acc)
b.box((0, 0, 0.38), (7.0, 1.2, 0.04), m=st_acc)
b.build(parent=r)
pub(r, "landing_pad.glb", elev=35)

# ---------------- outpost: dome habitat + tower + modules
r = new("outpost")
b = MB("outpost_m")
b.cyl((0, 0, 0.3), 7.5, 7.7, 0.6, seg=20, m=pad_m, smooth=False)
b.lathe([(6.0, 0.6), (6.0, 1.4), (5.3, 3.6), (3.6, 5.3), (0.01, 6.1)], seg=20, m=wall, smooth=True, center=(0, 0, 0))
b.lathe([(6.05, 0.9), (6.05, 1.2)], seg=20, m=st_acc, smooth=True)
for i in range(8):
    a = 2 * math.pi * i / 8
    b.box((math.cos(a) * 5.7, math.sin(a) * 5.7, 2.1), (1.4, 0.2, 1.1), rot=(0, 0, math.degrees(a) + 90), m=win)
# connected modules
for (x, y, w, d, h, rot) in ((9.0, 0, 5, 3.4, 3.0, 0), (-7.5, 6.0, 4.2, 3.2, 2.8, 45), (0, -10, 4.4, 3.4, 2.6, 90)):
    b.box((x, y, h / 2 + 0.1), (w, d, h), rot=(0, 0, rot), m=wall)
    b.box((x, y, h + 0.2), (w + 0.2, d + 0.2, 0.3), rot=(0, 0, rot), m=st_teal)
    b.box((x, y, h * 0.6), (w + 0.05, d * 0.5, 0.45), rot=(0, 0, rot), m=win)
# tower with antenna
b.cyl((-5.5, -6.5, 5.0), 0.5, 0.35, 10.0, seg=8, m=wall_dark)
b.cyl((-5.5, -6.5, 10.4), 0.9, 0.9, 0.3, seg=12, m=wall)
b.cyl((-5.5, -6.5, 12.0), 0.06, 0.06, 3.0, seg=5, m=metal)
b.sphere((-5.5, -6.5, 13.6), (0.28, 0.28, 0.28), seg=8, rings=5, m=lamp_o)
# solar panels
for (x, y) in ((-10, -1), (-10, 3.5)):
    b.box((x, y, 1.6), (0.12, 3.6, 2.4), rot=(0, 20, 0), m=solar)
    b.box((x, y, 0.5), (0.2, 0.3, 1.0), m=metal)
b.build(parent=r)
pub(r, "outpost.glb", elev=28, azim=-30, dist=45)

# ---------------- monolith (ancient glowing slab)
r = new("monolith")
b = MB("monolith_m")
b.box((0, 0, 4.5), (2.4, 0.7, 9.0), m=mono, taper=(0.82, 0.9))
b.cyl((0, 0, 0.2), 2.6, 2.8, 0.4, seg=6, m=mono, smooth=False)
for i, z in enumerate((1.8, 3.2, 4.6, 6.0, 7.4)):
    b.box((0, -0.36, z), (0.9 - 0.08 * i, 0.04, 0.16), m=rune)
    b.box((0, 0.36, z), (0.9 - 0.08 * i, 0.04, 0.16), m=rune)
b.sphere((0, 0, 11.5), (0.5, 0.5, 0.5), seg=10, rings=6, m=rune)
b.build(parent=r)
pub(r, "monolith.glb")

# ---------------- beacon / radio tower
r = new("beacon")
b = MB("beacon_m")
b.cyl((0, 0, 0.3), 1.6, 1.8, 0.6, seg=8, m=pad_m, smooth=False)
b.cyl((0, 0, 4.5), 0.3, 0.12, 8.0, seg=8, m=metal)
for k in range(3):
    a = 2 * math.pi * k / 3
    b.cyl((math.cos(a) * 0.55, math.sin(a) * 0.55, 2.2), 0.08, 0.06, 4.6, seg=5, rot=(math.sin(a) * -7, math.cos(a) * 7, 0), m=metal)
b.box((0, 0, 3.2), (1.3, 0.1, 0.9), rot=(0, 0, 0), m=wall)
b.box((0, 0, 3.2), (0.1, 1.3, 0.9), m=wall)
b.sphere((0, 0, 8.7), (0.3, 0.3, 0.3), seg=8, rings=5, m=lamp_o)
b.sphere((0, 0, 7.4), (0.7, 0.7, 0.18), seg=10, rings=4, m=st_teal)
b.build(parent=r)
pub(r, "beacon.glb")

# ---------------- crate + solar panel array
r = new("crate")
b = MB("crate_m")
b.box((0, 0, 0.55), (1.4, 1.0, 1.1), m=crate_m)
b.box((0, 0, 0.55), (1.45, 1.05, 0.14), m=wall_dark)
b.box((0, -0.52, 0.55), (0.5, 0.04, 0.4), m=lamp_o)
b.build(parent=r)
pub(r, "crate.glb")

r = new("solar_array")
b = MB("solar_array_m")
for i in range(3):
    b.box((i * 3.6 - 3.6, 0, 1.5), (3.2, 0.12, 2.2), rot=(0, 0, 0), m=solar)
    b.box((i * 3.6 - 3.6, 0, 0.6), (0.2, 0.3, 1.2), m=metal)
b.box((0, 0.25, 1.5), (11, 0.05, 0.1), m=wall_dark)
b.build(parent=r)
pub(r, "solar_array.glb")

# ---------------- creatures
fl_body = mat("cr_floater", (0.55, 0.85, 1.0), 0.0, 0.3, emit=(0.3, 0.6, 1.0), emit_strength=0.8, alpha=0.9)
fl_core = mat("cr_floater_core", (1.0, 0.5, 0.9), 0.0, 0.3, emit=(1.0, 0.4, 0.8), emit_strength=3.0)
fl_tent = mat("cr_floater_tent", (0.7, 0.9, 1.0), 0.0, 0.4, emit=(0.4, 0.7, 1.0), emit_strength=0.8)
r = new("creature_floater")
b = MB("floater_body")
b.lathe([(0.01, 0.0), (0.9, 0.15), (1.5, 0.7), (1.45, 1.4), (0.9, 1.95), (0.01, 2.1)], seg=14, m=fl_body, smooth=True)
b.sphere((0, 0, 1.0), (0.45, 0.45, 0.45), seg=8, rings=5, m=fl_core)
b.build(parent=r)
for i in range(6):
    a = 2 * math.pi * i / 6
    t = empty("Tentacle%d" % i, (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.1), r)
    bb = MB("tentacle%d_m" % i)
    bb.cyl((0, 0, -0.9), 0.08, 0.03, 1.8, seg=5, m=fl_tent, caps=False)
    bb.build(parent=t)
pub(r, "creature_floater.glb", elev=10)

hp_body = mat("cr_hopper", (0.85, 0.55, 0.3), 0.0, 0.7)
hp_belly = mat("cr_hopper_belly", (0.98, 0.88, 0.7), 0.0, 0.7)
hp_eye = mat("cr_hopper_eye", (0.05, 0.05, 0.08), 0.2, 0.2)
hp_tip = mat("cr_hopper_tip", (0.4, 0.9, 0.9), 0.0, 0.3, emit=(0.3, 0.9, 0.9), emit_strength=2.0)
r = new("creature_hopper")
b = MB("hopper_body")
b.sphere((0, 0, 0.55), (0.45, 0.65, 0.5), seg=12, rings=8, m=hp_body)
b.sphere((0, 0.15, 0.4), (0.38, 0.55, 0.38), seg=10, rings=6, m=hp_belly)
b.sphere((0, 0.62, 0.8), (0.3, 0.3, 0.28), seg=10, rings=6, m=hp_body)
for s in (-1, 1):
    b.sphere((s * 0.14, 0.86, 0.9), (0.07, 0.06, 0.08), seg=6, rings=4, m=hp_eye)
    b.cyl((s * 0.14, 0.52, 1.15), 0.07, 0.03, 0.6, seg=6, rot=(-12, s * 14, 0), m=hp_body)
    b.sphere((s * 0.14, 0.5, 1.5), (0.06, 0.06, 0.06), seg=6, rings=4, m=hp_tip)
b.build(parent=r)
for nm, (x, y) in (("LegFL", (-0.3, 0.3)), ("LegFR", (0.3, 0.3)), ("LegBL", (-0.32, -0.3)), ("LegBR", (0.32, -0.3))):
    lg = empty(nm, (x, y, 0.35), r)
    bb = MB(nm + "_m")
    bb.cyl((0, 0, -0.17), 0.07, 0.05, 0.36, seg=6, m=hp_body)
    bb.sphere((0, 0.04, -0.36), (0.09, 0.12, 0.05), seg=6, rings=4, m=hp_belly)
    bb.build(parent=lg)
pub(r, "creature_hopper.glb", elev=15)

# ---------------- cockpit interior (first-person ship view), origin at pilot eye point
cp_dark = mat("cp_dark", (0.08, 0.09, 0.11), 0.6, 0.45)
cp_panel = mat("cp_panel", (0.16, 0.18, 0.22), 0.5, 0.4)
cp_screen = mat("cp_screen", (0.1, 0.6, 0.9), 0, 0.2, emit=(0.1, 0.6, 0.9), emit_strength=2.0)
cp_orange = mat("cp_orange", (1.0, 0.45, 0.1), 0, 0.3, emit=(1.0, 0.45, 0.1), emit_strength=2.5)
r = new("Cockpit")
b = MB("cockpit_m")
# dashboard wedge in front of and below eye (forward = +Y)
b.box((0, 0.95, -0.42), (1.7, 0.9, 0.22), rot=(18, 0, 0), m=cp_dark, taper=(1.0, 1.0))
b.box((0, 0.8, -0.3), (0.5, 0.04, 0.22), rot=(-35, 0, 0), m=cp_screen)
b.box((-0.45, 0.8, -0.32), (0.3, 0.03, 0.16), rot=(-35, 0, 0), m=cp_orange)
b.box((0.45, 0.8, -0.32), (0.3, 0.03, 0.16), rot=(-35, 0, 0), m=cp_screen)
# side consoles
for s in (-1, 1):
    b.box((s * 0.82, 0.1, -0.5), (0.35, 1.8, 0.5), rot=(0, 0, 0), m=cp_panel)
    b.box((s * 0.8, 0.0, -0.22), (0.28, 0.8, 0.04), rot=(0, 0, 0), m=cp_screen if s > 0 else cp_orange)
    # A-pillars
    b.cyl((s * 0.88, 0.9, 0.35), 0.035, 0.03, 1.6, seg=6, rot=(-48, 0, 0), m=cp_dark)
# top arch
b.box((0, 0.7, 0.88), (1.9, 0.14, 0.09), rot=(-8, 0, 0), m=cp_dark)
b.box((0, 1.7, 0.55), (1.8, 0.1, 0.07), rot=(-35, 0, 0), m=cp_dark)
# joystick
b.cyl((0, 0.55, -0.42), 0.02, 0.02, 0.22, seg=6, m=metal)
b.sphere((0, 0.55, -0.3), (0.05, 0.05, 0.05), seg=8, rings=5, m=cp_orange)
b.build(parent=r)
export(r, "cockpit.glb")
stash(r)

print("structs done")
