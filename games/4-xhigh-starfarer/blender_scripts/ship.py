exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort\blender_scripts\lib.py").read())
clear_prefix("Ship")

hull = mat("hull_white", (0.78, 0.80, 0.84), 0.40, 0.34)
hull_dark = mat("hull_dark", (0.09, 0.10, 0.13), 0.80, 0.40)
accent = mat("hull_accent", (0.95, 0.34, 0.05), 0.25, 0.42)
trim = mat("hull_trim", (0.40, 0.43, 0.50), 0.90, 0.28)
glass = mat("glass_cockpit", (0.06, 0.14, 0.20), 0.0, 0.05, alpha=0.38)
glow = mat("engine_glow", (0.3, 0.8, 1.0), 0, 0.3, emit=(0.30, 0.75, 1.0), emit_strength=9.0)
nav_r = mat("light_red", (1, 0.1, 0.1), 0, 0.3, emit=(1, 0.08, 0.05), emit_strength=7.0)
nav_g = mat("light_green", (0.1, 1, 0.2), 0, 0.3, emit=(0.1, 1, 0.2), emit_strength=7.0)
lamp = mat("light_white", (1, 1, 1), 0, 0.3, emit=(1, 0.95, 0.85), emit_strength=9.0)
screen = mat("screen_blue", (0.1, 0.4, 0.6), 0, 0.3, emit=(0.15, 0.6, 1.0), emit_strength=3.0)
seat = mat("seat_fabric", (0.12, 0.13, 0.16), 0.0, 0.8)
flame_m = mat("flame", (0.4, 0.8, 1.0), 0, 0.5, emit=(0.4, 0.8, 1.0), emit_strength=6.0)

HULL, DARK, ACC, TRIM, GLOW, GLASS, NR, NG, LAMP, SCR, SEAT = range(11)
MATS = [hull, hull_dark, accent, trim, glow, glass, nav_r, nav_g, lamp, screen, seat]

b = MB(MATS)

# ---- fuselage
S = [
    dict(p=(0, -5.0, 0.05), rx=0.85, ry=0.70, n=3.0),
    dict(p=(0, -4.6, 0.05), rx=1.10, ry=0.86, n=3.0),
    dict(p=(0, -3.0, 0.05), rx=1.36, ry=0.98, n=2.8),
    dict(p=(0, -0.8, 0.10), rx=1.42, ry=1.02, n=2.6),
    dict(p=(0, 1.2, 0.10), rx=1.20, ry=0.92, n=2.4),
    dict(p=(0, 3.0, 0.05), rx=0.78, ry=0.62, n=2.2),
    dict(p=(0, 4.4, -0.02), rx=0.42, ry=0.36, n=2.1),
    dict(p=(0, 5.3, -0.08), rx=0.13, ry=0.13, n=2.0),
]
b.loft(S, seg=20, mi=HULL, mi_cap=DARK)

# belly plate + dark underside strip
b.box((1.6, 6.8, 0.08), (0, 0.2, -0.93), DARK, smooth=False)
# dorsal spine
b.loft([
    dict(p=(0, -4.4, 0.78), rx=0.34, ry=0.20, n=2.4),
    dict(p=(0, -3.0, 1.02), rx=0.50, ry=0.26, n=2.4),
    dict(p=(0, -1.0, 1.12), rx=0.56, ry=0.26, n=2.4),
    dict(p=(0, -0.2, 1.00), rx=0.40, ry=0.18, n=2.4),
], seg=12, mi=HULL, mi_cap=DARK)
# vent slats on the spine
for i in range(7):
    b.box((0.62, 0.07, 0.05), (0, -3.6 + i * 0.28, 1.27 - i * 0.015), DARK)
# accent chevron stripes on the nose
b.box((0.70, 0.22, 0.05), (0, 3.2, 0.64), ACC)
b.box((0.42, 0.18, 0.05), (0, 3.85, 0.45), ACC)

# ---- cockpit canopy frame (glass is a separate object)
b.sphere((0.68, 1.55, 0.55), (0, 1.55, 0.70), seg=20, rings=10, mi=TRIM, smooth=True)   # frame shell slightly larger, mostly hidden
# ---- interior
b.box((1.0, 0.55, 0.28), (0, 2.45, 0.44), DARK)              # dash
b.box((0.8, 0.04, 0.2), (0, 2.18, 0.60), SCR, rot=(math.radians(-25), 0, 0))  # screen
b.box((0.34, 0.04, 0.12), (-0.28, 2.17, 0.50), SCR)
b.box((0.34, 0.04, 0.12), (0.28, 2.17, 0.50), SCR)
b.box((0.55, 0.55, 0.14), (0, 1.0, 0.18), SEAT)              # seat cushion
b.box((0.55, 0.12, 0.65), (0, 0.68, 0.52), SEAT, rot=(math.radians(-12), 0, 0))  # seat back
b.box((0.22, 0.12, 0.18), (0, 0.64, 0.98), SEAT)             # headrest

# ---- wings
w0 = b._n()
wing = [(1.1, 1.6), (4.7, -2.7), (4.7, -3.9), (1.2, -3.9)]
b.prism(wing, 0.20, 'XY', offset=-0.14, mi=HULL)
b.prism([(3.7, -1.6), (4.7, -2.7), (4.7, -3.9), (3.4, -3.9)], 0.24, 'XY', offset=-0.14, mi=ACC)
b.prism([(1.15, 0.8), (3.6, -1.9), (3.6, -2.2), (1.15, -0.4)], 0.22, 'XY', offset=-0.14, mi=TRIM)   # leading-edge strip
# dihedral
piv = Vector((1.1, 0, 0))
b.transform(Matrix.Translation(piv) @ Matrix.Rotation(math.radians(-6), 4, 'Y') @ Matrix.Translation(-piv), w0)
# canards
c0 = b._n()
b.prism([(0.95, 2.9), (2.4, 1.9), (2.4, 1.45), (0.95, 1.8)], 0.12, 'XY', offset=-0.22, mi=HULL)
# winglet fin
b.prism([(-2.6, 0.0), (-3.9, 0.0), (-4.05, 1.5), (-3.35, 1.6)], 0.14, 'YZ', offset=4.65, mi=HULL)
b.prism([(-3.3, 1.0), (-4.0, 1.0), (-4.05, 1.5), (-3.35, 1.6)], 0.16, 'YZ', offset=4.65, mi=ACC)
# nacelle + pylon
n0 = b._n()
b.cyl(0.58, 0.58, 3.7, (2.0, -2.9, -0.28), 'Y', seg=18, mi=HULL)
b.cyl(0.30, 0.58, 0.9, (2.0, -0.6, -0.28), 'Y', seg=18, mi=TRIM)       # intake
b.cyl(0.46, 0.46, 0.18, (2.0, -4.82, -0.28), 'Y', seg=18, mi=DARK)     # nozzle ring
b.cyl(0.38, 0.38, 0.06, (2.0, -4.93, -0.28), 'Y', seg=18, mi=GLOW)     # glow disc
b.box((1.0, 2.4, 0.26), (1.45, -2.9, -0.20), DARK)
b.box((0.18, 3.0, 0.20), (2.0, -2.9, 0.34), ACC)                        # stripe on top of nacelle
# mirror wings/canards/fin/nacelle across x=0
b.mirror_x(w0)
# ---- dorsal tail fin (centre line)
b.prism([(-1.4, 0.9), (-4.2, 2.3), (-4.95, 2.3), (-4.95, 0.7)], 0.16, 'YZ', offset=0.0, mi=HULL)
b.prism([(-3.6, 1.55), (-4.2, 2.3), (-4.95, 2.3), (-4.95, 1.55)], 0.18, 'YZ', offset=0.0, mi=ACC)

# ---- central main thruster
b.cyl(0.62, 0.52, 0.5, (0, -5.22, 0.05), 'Y', seg=20, mi=DARK)
b.cyl(0.44, 0.44, 0.06, (0, -5.5, 0.05), 'Y', seg=20, mi=GLOW)

# ---- nav lights / lamps / antenna
b.sphere(0.10, (-4.72, -3.55, -0.10), seg=8, rings=6, mi=NR)
b.sphere(0.10, (4.72, -3.55, -0.10), seg=8, rings=6, mi=NG)
b.sphere(0.07, (-0.35, 4.3, -0.20), seg=8, rings=6, mi=LAMP)
b.sphere(0.07, (0.35, 4.3, -0.20), seg=8, rings=6, mi=LAMP)
b.cyl(0.025, 0.02, 1.1, (0.0, -1.6, 1.62), 'Z', seg=6, mi=TRIM)
b.sphere(0.05, (0.0, -1.6, 2.2), seg=6, rings=4, mi=NR)
# gear bay doors (belly)
b.box((0.8, 1.1, 0.05), (0, 3.0, -0.70), TRIM)
b.box((0.9, 1.4, 0.05), (-1.6, -2.7, -0.84), TRIM)
b.box((0.9, 1.4, 0.05), (1.6, -2.7, -0.84), TRIM)
# side intakes near cockpit
b.box((0.10, 1.1, 0.34), (1.30, -0.2, 0.12), DARK)
b.box((0.10, 1.1, 0.34), (-1.30, -0.2, 0.12), DARK)
# side accent line
b.box((0.06, 3.2, 0.12), (1.40, -1.9, 0.30), ACC)
b.box((0.06, 3.2, 0.12), (-1.40, -1.9, 0.30), ACC)

body = b.to_obj("Ship_Body")

# ---- glass
g = MB(MATS)
g.sphere((0.64, 1.50, 0.50), (0, 1.55, 0.72), seg=20, rings=12, mi=GLASS, smooth=True)
glass_obj = g.to_obj("Ship_Glass")


# ---- landing gear (origin = hinge)
def gear(name, hinge, length, side):
    gb = MB(MATS)
    gb.cyl(0.11, 0.09, length * 0.55, (0, 0, -length * 0.275), 'Z', seg=10, mi=TRIM)
    gb.cyl(0.07, 0.06, length * 0.50, (0, 0, -length * 0.74), 'Z', seg=8, mi=HULL)
    gb.cyl(0.36, 0.40, 0.09, (0, 0, -length - 0.04), 'Z', seg=14, mi=DARK)
    gb.sphere(0.10, (0, 0, -length * 0.02), seg=8, rings=6, mi=TRIM)
    brace_pts = [Vector((0.0, 0.0, -0.1)), Vector((0.0, 0.0, -length * 0.5))]
    gb.tube([Vector((0.12 * side, 0.35, -0.12)), Vector((0.02 * side, 0.0, -length * 0.62))], 0.035, seg=6, mi=TRIM)
    return gb.to_obj(name, loc=hinge, parent=body)


gf = gear("Ship_Gear_Front", (0, 3.0, -0.68), 1.30, 0)
gl = gear("Ship_Gear_L", (-1.6, -2.7, -0.86), 1.12, -1)
gr = gear("Ship_Gear_R", (1.6, -2.7, -0.86), 1.12, 1)


# ---- flames (origin at the nozzle, pointing -Y)
def flame(name, loc, r, l):
    fb = MB(MATS)
    fb.cyl(0.0, r, l, (0, -l / 2, 0), 'Y', seg=12, mi=0, smooth=True, caps=False)
    fb.mats = [flame_m]
    return fb.to_obj(name, loc=loc, parent=body)


fl_l = flame("Ship_Flame_L", (-2.0, -4.96, -0.28), 0.36, 3.4)
fl_r = flame("Ship_Flame_R", (2.0, -4.96, -0.28), 0.36, 3.4)
fl_c = flame("Ship_Flame_C", (0, -5.53, 0.05), 0.42, 4.2)

parts = [body, glass_obj, gf, gl, gr, fl_l, fl_r, fl_c]
for o in parts:
    o["asset"] = "ship"
path = export_glb("ship", parts)
print("exported", path)
preview(parts, PROJECT + r"\blender_scripts\_pv_ship.png", cam_dir=(1.0, -1.3, 0.55), dist=19)
preview(parts, PROJECT + r"\blender_scripts\_pv_ship_top.png", cam_dir=(0.1, -0.6, 1.4), dist=19)
shelf(parts, -40, 0)
bpy.ops.wm.save_mainfile()
print("tris", sum(len(o.data.polygons) for o in parts))
