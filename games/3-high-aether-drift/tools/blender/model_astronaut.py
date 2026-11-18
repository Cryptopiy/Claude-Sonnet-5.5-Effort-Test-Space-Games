import math
from mathutils import Vector
exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\3. High Effort\tools\blender\blib.py").read())

suit = mat("suit_white", (0.88, 0.88, 0.9), 0.1, 0.55)
suit_acc = mat("suit_orange", (0.95, 0.4, 0.06), 0.1, 0.5)
suit_dark = mat("suit_dark", (0.13, 0.14, 0.17), 0.5, 0.5)
visor = mat("suit_visor", (0.9, 0.65, 0.2), 0.9, 0.08, emit=(0.9, 0.55, 0.1), emit_strength=0.4)
glow = mat("suit_glow", (0.3, 0.8, 1.0), 0, 0.3, emit=(0.3, 0.8, 1.0), emit_strength=5.0)
metal = mat("suit_metal", (0.5, 0.52, 0.56), 0.85, 0.35)

remove_tree("Astronaut")
root = empty("Astronaut")

# Torso: pivot at hip centre
hip = empty("Hip", (0, 0, 0.95), root)
b = MB("Torso")
b.box((0, 0, 0.3), (0.5, 0.3, 0.45), m=suit, taper=(1.0, 1.0))
b.sphere((0, 0, 0.02), (0.26, 0.17, 0.14), seg=14, rings=6, m=suit_dark)
b.box((0, 0.16, 0.34), (0.3, 0.05, 0.2), m=suit_dark)
b.box((0, 0.17, 0.4), (0.08, 0.03, 0.06), m=glow)
b.box((0, 0.0, 0.1), (0.52, 0.32, 0.12), m=suit_acc)
torso = b.build(parent=hip)
# Backpack (jetpack)
b = MB("Backpack")
b.box((0, -0.26, 0.32), (0.4, 0.2, 0.5), m=suit_dark)
for s in (-1, 1):
    b.cyl((s * 0.13, -0.3, 0.2), 0.08, 0.1, 0.46, seg=10, m=metal)
    b.cyl((s * 0.13, -0.3, -0.04), 0.07, 0.07, 0.03, seg=10, m=glow)
b.box((0, -0.36, 0.5), (0.16, 0.05, 0.1), m=suit_acc)
back = b.build(parent=hip)
empty("JetL", (-0.13, -0.3, -0.05), hip)
empty("JetR", (0.13, -0.3, -0.05), hip)

# Head: pivot at neck
neck = empty("Head", (0, 0, 0.5), hip)
b = MB("HeadMesh")
b.sphere((0, 0.0, 0.14), (0.17, 0.18, 0.19), seg=16, rings=9, m=suit)
b.sphere((0, 0.07, 0.15), (0.14, 0.13, 0.145), seg=16, rings=9, m=visor)
b.cyl((0, 0, 0.0), 0.12, 0.14, 0.06, seg=12, m=suit_dark)
b.build(parent=neck)
empty("Eyes", (0, 0.05, 0.15), neck)

# Arms: pivot at shoulder
for name, s in (("ArmL", -1), ("ArmR", 1)):
    a = empty(name, (s * 0.32, 0, 0.46), hip)
    b = MB(name + "_Mesh")
    b.sphere((0, 0, 0), (0.1, 0.1, 0.1), seg=10, rings=6, m=suit_acc)
    b.cyl((0, 0, -0.17), 0.075, 0.065, 0.3, seg=10, m=suit)
    b.sphere((0, 0, -0.34), (0.07, 0.07, 0.07), seg=8, rings=6, m=suit_dark)
    b.cyl((0, 0, -0.47), 0.065, 0.075, 0.26, seg=10, m=suit)
    b.sphere((0, 0, -0.62), (0.075, 0.08, 0.08), seg=10, rings=6, m=suit_dark)
    b.build(parent=a)

# Legs: pivot at hip joint (relative to root)
for name, s in (("LegL", -1), ("LegR", 1)):
    l = empty(name, (s * 0.13, 0, 0.93), root)
    b = MB(name + "_Mesh")
    b.cyl((0, 0, -0.2), 0.105, 0.085, 0.4, seg=12, m=suit)
    b.sphere((0, 0, -0.41), (0.09, 0.09, 0.09), seg=10, rings=6, m=suit_dark)
    b.cyl((0, 0, -0.62), 0.085, 0.09, 0.36, seg=12, m=suit)
    b.cyl((0, 0, -0.62), 0.095, 0.095, 0.08, seg=12, m=suit_acc)
    b.box((0, 0.05, -0.88), (0.17, 0.32, 0.12), m=suit_dark)
    b.build(parent=l)

export(root, "astronaut.glb")
preview(root, "astronaut.png", elev=12, azim=-35, res=(500, 700))
stash(root)

# ---------------- multitool (first-person equipment)
remove_tree("Multitool")
mt = empty("Multitool")
b = MB("MultitoolMesh")
b.box((0, -0.02, 0.0), (0.07, 0.34, 0.11), m=suit_dark)           # body
b.box((0, -0.12, -0.1), (0.055, 0.1, 0.14), rot=(15, 0, 0), m=suit_dark)    # grip
b.box((0, 0.0, 0.065), (0.05, 0.28, 0.03), m=suit_acc)
b.cyl((0, 0.32, 0.0), 0.028, 0.02, 0.36, seg=12, rot=(-90, 0, 0), m=metal)    # barrel
b.cyl((0, 0.52, 0.0), 0.034, 0.034, 0.05, seg=12, rot=(-90, 0, 0), m=glow)
b.cyl((0, 0.18, 0.0), 0.04, 0.04, 0.05, seg=12, rot=(-90, 0, 0), m=suit_acc)
b.sphere((0, 0.06, 0.1), (0.04, 0.04, 0.03), seg=10, rings=6, m=glow)   # scanner lens
b.box((0.05, 0.02, 0.01), (0.02, 0.12, 0.07), m=suit)
b.box((-0.05, 0.02, 0.01), (0.02, 0.12, 0.07), m=suit)
b.build(parent=mt)
empty("Muzzle", (0, 0.56, 0.0), mt)
export(mt, "multitool.glb")
preview(mt, "multitool.png", elev=20, azim=-60, res=(500, 400))
stash(mt)
print("astronaut done")
