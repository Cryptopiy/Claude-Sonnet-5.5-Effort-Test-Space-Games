import math
from mathutils import Vector
exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\3. High Effort\tools\blender\blib.py").read())

hull = mat("ship_hull", (0.78, 0.8, 0.84), 0.55, 0.38)
hull_dark = mat("ship_dark", (0.12, 0.13, 0.16), 0.7, 0.45)
accent = mat("ship_accent", (0.95, 0.42, 0.08), 0.3, 0.45)
accent2 = mat("ship_teal", (0.08, 0.55, 0.62), 0.3, 0.4)
glass = mat("ship_glass", (0.25, 0.55, 0.8), 0.0, 0.05, emit=(0.1, 0.25, 0.4), emit_strength=0.3, alpha=0.45)
engine_glow = mat("ship_engine_glow", (0.3, 0.8, 1.0), 0.0, 0.3, emit=(0.3, 0.8, 1.0), emit_strength=6.0)
light_r = mat("ship_light_red", (1, 0.1, 0.1), 0, 0.3, emit=(1, 0.1, 0.1), emit_strength=5.0)
light_g = mat("ship_light_green", (0.1, 1, 0.2), 0, 0.3, emit=(0.1, 1, 0.2), emit_strength=5.0)
metal = mat("ship_metal", (0.45, 0.46, 0.5), 0.9, 0.3)

remove_tree("Ship")
root = empty("Ship")


def ring(w, h, zc, n=24, p=2.6):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        x = w * math.copysign(abs(c) ** (2 / p), c)
        z = h * math.copysign(abs(s) ** (2 / p), s) + zc
        pts.append(Vector((x, 0, z)))
    return pts


def section(y, w, h, zc, n=24, p=2.6):
    return [Vector((q.x, y, q.z)) for q in ring(w, h, zc, n, p)]


# ---- fuselage (single loft, nose along +Y)
secs = [(-6.0, 1.0, 0.8, 0.0), (-5.0, 1.55, 0.95, 0.05), (-3.0, 2.0, 1.15, 0.1), (-0.5, 1.95, 1.2, 0.15),
        (2.0, 1.45, 1.0, 0.12), (4.2, 0.9, 0.7, 0.05), (6.0, 0.4, 0.4, -0.02), (7.2, 0.08, 0.1, -0.05)]
b = MB("Hull")
b.loft([section(*s) for s in secs], m=hull, close_start=True, close_end=True)
# dark belly plate
b.loft([section(y, w * 0.98, h * 0.5, zc - h * 0.55, n=16, p=2.0) for (y, w, h, zc) in secs[1:6]], m=hull_dark, close_start=False, close_end=False, smooth=True)
# nose accent band
b.loft([section(y, w * 1.02, h * 1.02, zc) for (y, w, h, zc) in [(4.8, 0.78, 0.62, 0.05), (5.2, 0.68, 0.58, 0.05)]], m=accent, close_start=False, close_end=False)
# dorsal spine + intake
b.box((0, -2.2, 1.35), (0.7, 3.8, 0.45), m=hull_dark, taper=(0.5, 0.6))
b.box((0, -3.7, 1.0), (1.9, 0.5, 0.35), m=hull_dark)
# racing stripe
b.box((0, 0.7, 1.27), (0.55, 5.2, 0.05), m=accent)
# side vents
for sx in (-1, 1):
    b.box((sx * 1.62, -1.6, 0.25), (0.14, 2.4, 0.5), m=hull_dark)
hull_ob = b.build(parent=root)

# ---- canopy
b = MB("Canopy")
b.sphere((0, 2.3, 0.95), (0.85, 2.0, 0.62), seg=20, rings=10, m=glass, smooth=True)
b.cyl((0, 2.3, 0.95), 0.9, 0.9, 0.06, seg=24, m=metal, scale=(1, 2.2))
canopy_ob = b.build(parent=root)
# canopy frame ribs
b = MB("CanopyFrame")
for yy in (0.9, 2.3, 3.7):
    k = 1 - abs(yy - 2.3) / 2.6
    b.box((0, yy, 1.0 + 0.4 * k), (1.5 * (0.5 + 0.5 * k), 0.12, 0.08), m=hull_dark)
    for sx in (-1, 1):
        b.box((sx * 0.75 * (0.5 + 0.5 * k), yy, 0.98 + 0.2 * k), (0.1, 0.14, 0.5 * k + 0.2), m=hull_dark)
b.box((0, 2.3, 1.62), (0.1, 3.5, 0.08), m=hull_dark)
b.build(parent=root)

# ---- wings (swept planform prisms)
def wing(side):
    s = side
    plan = [(1.6, -4.4), (1.6, 0.8), (7.0, -4.2), (7.0, -5.3), (3.2, -5.2)]
    rings = []
    for z, k in ((-0.12, 1.0), (0.14, 0.85)):
        rings.append([Vector((s * x * (k if x > 6 else 1.0), y, z - 0.05 * (x - 1.6) * 0.1)) for (x, y) in plan])
    return rings
b = MB("Wings")
for s in (-1, 1):
    r = wing(s)
    if s < 0:
        r = [list(reversed(rr)) for rr in r]
    b.loft(r, m=hull, smooth=False)
    # leading edge accent + wingtip pod
    b.box((s * 6.9, -4.7, 0.0), (0.4, 1.4, 0.4), m=accent, taper=(0.8, 0.8))
wings_ob = b.build(parent=root)
b = MB("NavLights")
b.sphere((-7.0, -5.1, 0.0), (0.16, 0.16, 0.16), seg=8, rings=6, m=light_r)
b.sphere((7.0, -5.1, 0.0), (0.16, 0.16, 0.16), seg=8, rings=6, m=light_g)
b.build(parent=root)

# ---- tail fins
b = MB("Fins")
for s in (-1, 1):
    rings = []
    for z0, k in ((0, 1.0), (1.0, 0.55)):
        pass
    fin = [Vector((s * 0.0, y, z)) for (y, z) in [(-3.8, 1.2), (-5.6, 1.2), (-6.1, 2.9), (-5.3, 3.2)]]
    r0 = [Vector((s * 1.0 + s * 0.0, q.y, q.z)) for q in fin]
    r1 = [Vector((s * 1.0 + s * 0.14, q.y, q.z)) for q in fin]
    if s > 0:
        r0, r1 = r1, r0
    b.loft([r0, r1], m=hull, smooth=False)
b.box((-1.05, -5.5, 2.9), (0.18, 0.7, 0.1), m=accent)
b.box((1.05, -5.5, 2.9), (0.18, 0.7, 0.1), m=accent)
b.build(parent=root)

# ---- engines
b = MB("Engines")
for s in (-1, 1):
    x = s * 1.25
    b.cyl((x, -5.2, 0.15), 0.62, 0.55, 2.4, seg=18, rot=(90, 0, 0), m=hull_dark)
    b.cyl((x, -6.55, 0.15), 0.62, 0.48, 0.5, seg=18, rot=(90, 0, 0), m=metal)
    b.cyl((x, -6.84, 0.15), 0.4, 0.4, 0.08, seg=18, rot=(90, 0, 0), m=engine_glow)
    b.box((x, -4.2, 0.78), (0.5, 1.4, 0.18), m=accent, taper=(0.7, 1.0))
engines_ob = b.build(parent=root)
empty("Engine_L", (-1.25, -6.9, 0.15), root)
empty("Engine_R", (1.25, -6.9, 0.15), root)
empty("CockpitCam", (0, 1.7, 1.12), root)
empty("Nose", (0, 7.2, -0.05), root)

# ---- landing gear: pivot at hip, extended pose (hanging down -Z)
def gear(name, pos, foot_dx=0.0, length=1.7):
    g = empty(name, pos, root)
    b = MB(name + "_Mesh")
    b.cyl((0, 0, -length / 2), 0.12, 0.1, length, seg=10, m=metal)
    b.cyl((0, 0, -length * 0.35), 0.17, 0.17, 0.5, seg=10, m=hull_dark)
    b.cyl((0, 0, -length - 0.04), 0.55, 0.55, 0.1, seg=16, m=hull_dark)
    b.box((0, 0, -length - 0.12), (0.5, 0.5, 0.06), m=accent)
    b.build(parent=g)
    return g
gear("Gear_Front", (0, 3.4, -0.55), length=1.55)
gear("Gear_L", (-1.6, -4.2, -0.5), length=1.6)
gear("Gear_R", (1.6, -4.2, -0.5), length=1.6)

# ensure hull sits so gear feet touch z = -2.2 relative to origin; origin = centre of ship
export(root, "ship.glb")
preview(root, "ship.png", elev=22, azim=-40, res=(900, 600))
stash(root)
print("ship done")
