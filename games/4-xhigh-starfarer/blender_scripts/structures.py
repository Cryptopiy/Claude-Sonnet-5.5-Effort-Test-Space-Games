exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort\blender_scripts\lib.py").read())
import math
R = random.Random

rock = mat("rock", (0.52, 0.50, 0.48), 0.0, 0.92)
rock2 = mat("rock_light", (0.68, 0.64, 0.58), 0.0, 0.92)
sand_a = mat("sandstone_a", (0.80, 0.55, 0.34), 0.0, 0.9)
sand_b = mat("sandstone_b", (0.66, 0.38, 0.24), 0.0, 0.9)
sand_c = mat("sandstone_c", (0.88, 0.72, 0.50), 0.0, 0.9)
concrete = mat("pad_concrete", (0.32, 0.34, 0.37), 0.1, 0.8)
concrete_d = mat("pad_dark", (0.16, 0.17, 0.19), 0.1, 0.8)
yellow = mat("marking_yellow", (0.95, 0.75, 0.10), 0.0, 0.6, emit=(1.0, 0.7, 0.1), emit_strength=0.8)
white = mat("hab_white", (0.82, 0.84, 0.87), 0.25, 0.45)
white_d = mat("hab_gray", (0.45, 0.48, 0.54), 0.5, 0.4)
orange = mat("hab_orange", (0.92, 0.38, 0.07), 0.2, 0.5)
dark = mat("hab_dark", (0.10, 0.11, 0.14), 0.7, 0.4)
glass = mat("glass_window", (0.35, 0.6, 0.8), 0.0, 0.05, emit=(1.0, 0.85, 0.5), emit_strength=1.6)
solar = mat("solar_panel", (0.05, 0.10, 0.28), 0.7, 0.2)
lightw = mat("lamp_white", (1, 1, 1), 0, 0.3, emit=(1.0, 0.95, 0.85), emit_strength=8.0)
lightr = mat("lamp_red", (1, 0.1, 0.1), 0, 0.3, emit=(1.0, 0.1, 0.05), emit_strength=7.0)
lightc = mat("lamp_cyan", (0.2, 0.9, 1.0), 0, 0.3, emit=(0.2, 0.9, 1.0), emit_strength=6.0)
stone = mat("monolith_stone", (0.05, 0.06, 0.09), 0.75, 0.28)
glyph = mat("glyph_glow", (0.2, 0.8, 1.0), 0, 0.3, emit=(0.2, 0.8, 1.0), emit_strength=5.0)
metal = mat("metal_gray", (0.55, 0.57, 0.62), 0.9, 0.35)
char = mat("charred", (0.07, 0.06, 0.06), 0.4, 0.8)
fire = mat("ember", (1.0, 0.4, 0.1), 0, 0.5, emit=(1.0, 0.4, 0.08), emit_strength=5.0)
ore_g = mat("ore_glow", (0.9, 0.9, 0.9), 0.0, 0.15, emit=(0.8, 0.8, 0.8), emit_strength=2.5)
ore_r = mat("ore_rock", (0.20, 0.19, 0.20), 0.0, 0.9)
asteroid_m = mat("asteroid", (0.42, 0.38, 0.35), 0.0, 0.95)


def rock_a():
    b = MB([rock, rock2])
    b.ico((2.3, 1.9, 1.5), (0, 0, 0.8), sub=3, mi=0, noise=0.22, seed=1, flat=True)
    b.ico((0.9, 0.8, 0.6), (2.3, 0.8, 0.3), sub=2, mi=1, noise=0.2, seed=2, flat=True)
    b.ico((0.6, 0.5, 0.4), (-1.9, 1.4, 0.2), sub=2, mi=0, noise=0.25, seed=3, flat=True)
    return b.to_obj("Rock_A")


def rock_b():
    b = MB([rock, rock2])
    b.ico((3.2, 2.4, 0.9), (0, 0, 0.45), sub=3, mi=0, noise=0.18, seed=4, flat=True)
    b.ico((1.8, 1.4, 0.8), (0.6, 0.3, 1.1), sub=3, mi=1, noise=0.2, seed=5, flat=True)
    b.ico((0.7, 0.6, 0.5), (-2.6, -1.2, 0.2), sub=2, mi=0, noise=0.2, seed=6, flat=True)
    return b.to_obj("Rock_B")


def rock_c():
    b = MB([rock, rock2])
    b.ico((1.4, 1.2, 3.2), (0, 0, 1.4), sub=3, mi=0, noise=0.2, seed=7, flat=True)
    b.ico((1.0, 0.9, 2.0), (1.4, 0.6, 0.8), sub=3, mi=1, noise=0.2, seed=8, flat=True)
    b.ico((0.8, 0.7, 1.4), (-1.1, -0.7, 0.6), sub=2, mi=0, noise=0.22, seed=9, flat=True)
    return b.to_obj("Rock_C")


def pebbles():
    b = MB([rock, rock2])
    r = R(3)
    for i in range(7):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.0, 1.4)
        s = r.uniform(0.12, 0.35)
        b.ico((s * 1.2, s, s * 0.7), (math.cos(a) * d, math.sin(a) * d, s * 0.3), sub=1, mi=i % 2, noise=0.25, seed=i, flat=True)
    return b.to_obj("Pebbles")


def rock_arch():
    b = MB([sand_a, sand_b, sand_c])
    pts = []
    for i in range(13):
        a = math.pi * i / 12
        pts.append(V((math.cos(a) * 6.0, 0, math.sin(a) * 6.5 + 0.5)))
    rad = [(1.9 - 0.6 * math.sin(math.pi * i / 12), 1.4) for i in range(13)]
    b.tube(pts, rad, seg=10, mi=0, smooth=False)
    b.ico((2.6, 2.2, 1.2), (6.0, 0, 0.3), sub=2, mi=1, noise=0.2, seed=1, flat=True)
    b.ico((2.6, 2.2, 1.2), (-6.0, 0, 0.3), sub=2, mi=1, noise=0.2, seed=2, flat=True)
    b.ico((1.0, 1.0, 0.5), (3.0, 3.0, 0.2), sub=1, mi=2, noise=0.2, seed=3, flat=True)
    return b.to_obj("Rock_Arch")


def hoodoo():
    b = MB([sand_a, sand_b, sand_c])
    r = R(10)
    z = -0.5
    layers = [(2.6, 2.0, 2.0), (2.1, 1.7, 1.6), (1.6, 1.5, 1.8), (1.9, 1.2, 1.0), (1.3, 1.1, 2.0), (1.8, 1.5, 0.8)]
    for i, (rb, rt, h) in enumerate(layers):
        ox, oy = r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15)
        b.cyl(rb, rt, h, (ox, oy, z + h / 2), 'Z', seg=9, mi=i % 3, smooth=False)
        z += h * 0.95
    b.cyl(1.0, 0.7, 0.6, (0, 0, z + 0.3), 'Z', seg=9, mi=2, smooth=False)
    return b.to_obj("Hoodoo")


def asteroid(name, seed, radii):
    b = MB([asteroid_m])
    b.ico(radii, (0, 0, 0), sub=4, mi=0, noise=0.28, seed=seed, flat=True)
    # carve craters by pulling vertices near random directions inward
    r = R(seed)
    bm = b.bm
    for k in range(5):
        d = V((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1, 1))).normalized()
        cr = r.uniform(0.25, 0.45)
        for v in bm.verts:
            dist = (v.co.normalized() - d).length
            if dist < cr:
                f = 1.0 - (dist / cr) ** 2
                v.co *= 1.0 - 0.18 * f
    return b.to_obj(name)


def landing_pad():
    b = MB([concrete, concrete_d, yellow, lightw, metal, orange])
    b.cyl(7.2, 7.0, 0.7, (0, 0, -0.35), 'Z', seg=32, mi=0, smooth=False)
    b.cyl(6.4, 6.4, 0.06, (0, 0, 0.03), 'Z', seg=32, mi=1, smooth=False)
    b.cyl(5.7, 5.7, 0.05, (0, 0, 0.07), 'Z', seg=32, mi=2, smooth=False)
    b.cyl(5.4, 5.4, 0.06, (0, 0, 0.075), 'Z', seg=32, mi=1, smooth=False)
    b.box((0.55, 4.2, 0.05), (-1.3, 0, 0.11), 2)
    b.box((0.55, 4.2, 0.05), (1.3, 0, 0.11), 2)
    b.box((2.2, 0.55, 0.05), (0, 0, 0.11), 2)
    for i in range(16):
        a = i * 2 * math.pi / 16
        b.box((0.35, 0.18, 0.12), (math.cos(a) * 6.8, math.sin(a) * 6.8, 0.06), 3, rot=(0, 0, a))
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        x, y = math.cos(a) * 7.6, math.sin(a) * 7.6
        b.cyl(0.12, 0.12, 2.6, (x, y, 1.0), 'Z', seg=8, mi=4)
        b.sphere(0.24, (x, y, 2.4), seg=10, rings=7, mi=3)
        b.cyl(0.4, 0.4, 0.3, (x, y, -0.05), 'Z', seg=8, mi=1, smooth=False)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        b.box((0.9, 0.5, 0.06), (math.cos(a) * 3.7, math.sin(a) * 3.7, 0.10), 5, rot=(0, 0, a))
    return b.to_obj("Landing_Pad")


def outpost():
    b = MB([white, white_d, orange, dark, glass, solar, lightw, lightr, metal, concrete])
    WH, GR, OR, DK, GL, SO, LW, LR, ME, CO = range(10)
    b.box((15, 9, 0.5), (0, 0, 0.0), CO, bevel=0.1)
    # main module
    b.cyl(2.4, 2.4, 8.0, (0, 0, 2.9), 'X', seg=20, mi=WH)
    b.sphere((2.4, 2.4, 2.4), (4.0, 0, 2.9), seg=20, rings=12, mi=WH)
    b.sphere((2.4, 2.4, 2.4), (-4.0, 0, 2.9), seg=20, rings=12, mi=WH)
    b.cyl(2.5, 2.5, 0.35, (1.5, 0, 2.9), 'X', seg=20, mi=OR)
    b.cyl(2.5, 2.5, 0.35, (-1.5, 0, 2.9), 'X', seg=20, mi=OR)
    # windows
    for i in range(5):
        b.box((0.9, 0.12, 0.7), (-3.0 + i * 1.5, -2.3, 3.4), GL, rot=(math.radians(-14), 0, 0))
    # door
    b.box((1.5, 0.2, 2.3), (0, -2.32, 1.65), DK, bevel=0.04)
    b.box((1.8, 0.1, 2.6), (0, -2.38, 1.8), OR, bevel=0.03)
    b.box((1.5, 1.6, 0.2), (0, -3.2, 0.35), ME)   # step
    b.box((0.35, 0.08, 0.35), (1.1, -2.38, 2.0), LW)
    # side module + connector
    b.cyl(1.7, 1.7, 5.0, (-7.0, 0, 1.9), 'Y', seg=16, mi=WH)
    b.sphere((1.7, 1.7, 1.7), (-7.0, 2.5, 1.9), seg=16, rings=10, mi=WH)
    b.sphere((1.7, 1.7, 1.7), (-7.0, -2.5, 1.9), seg=16, rings=10, mi=WH)
    b.cyl(0.7, 0.7, 2.6, (-5.2, 0, 2.2), 'X', seg=12, mi=GR)
    b.box((0.9, 0.12, 0.6), (-7.0, -3.3, 2.1), GL)
    # dome
    b.sphere((2.6, 2.6, 2.4), (6.5, 0.5, 0.2), seg=20, rings=12, mi=GR)
    b.sphere((2.2, 2.2, 2.0), (6.5, 0.5, 0.3), seg=20, rings=12, mi=GL)
    # solar array
    for i in range(3):
        x = -4.0 + i * 4.0
        b.cyl(0.12, 0.12, 2.0, (x, 4.2, 1.0), 'Z', seg=8, mi=ME)
        b.box((3.4, 0.10, 2.0), (x, 4.3, 2.4), SO, rot=(math.radians(-35), 0, 0))
        b.box((3.5, 0.14, 0.12), (x, 4.37, 2.9), ME, rot=(math.radians(-35), 0, 0))
    # antenna + dish
    b.tube([V((-1.8, 0.0, 5.0)), V((-1.8, 0.0, 12.5))], 0.1, seg=8, mi=ME)
    for z in (7.0, 9.0, 11.0):
        b.box((1.2, 0.06, 0.06), (-1.8, 0, z), ME)
    b.sphere(0.2, (-1.8, 0, 12.6), seg=8, rings=6, mi=LR)
    b.cyl(0.05, 0.9, 0.5, (-1.8, 0.7, 10.0), 'Y', seg=14, mi=WH, rot=None)
    # tanks and crates
    for i in range(2):
        b.cyl(0.9, 0.9, 2.6, (5.0 + i * 2.0, -3.3, 1.5), 'Z', seg=14, mi=OR)
        b.sphere((0.9, 0.9, 0.5), (5.0 + i * 2.0, -3.3, 2.8), seg=14, rings=6, mi=OR)
    for i, (x, y, z) in enumerate([(-5.5, -3.6, 0.65), (-4.2, -3.6, 0.65), (-4.85, -3.6, 1.8)]):
        b.box((1.2, 1.2, 1.2), (x, y, z), OR if i != 1 else GR, bevel=0.05)
        b.box((1.25, 1.25, 0.15), (x, y, z), DK)
    # lamp posts
    for sx in (-1, 1):
        b.cyl(0.07, 0.07, 3.6, (sx * 7.0, -3.9, 1.8), 'Z', seg=6, mi=ME)
        b.sphere(0.22, (sx * 7.0, -3.9, 3.7), seg=8, rings=6, mi=LW)
    return b.to_obj("Outpost")


def monolith():
    b = MB([stone, glyph, concrete_d])
    ST, GL, BS = 0, 1, 2
    for i, (w, h) in enumerate([(7.0, 0.5), (5.8, 0.5), (4.6, 0.5)]):
        b.box((w, w * 0.7, h), (0, 0, -0.2 + i * 0.5), BS, bevel=0.06)
    sec = [dict(p=(0, 0, 1.3), rx=1.6, ry=0.9, n=6.0), dict(p=(0, 0, 8.0), rx=1.3, ry=0.75, n=6.0), dict(p=(0, 0, 12.5), rx=1.05, ry=0.6, n=6.0)]
    b.loft(sec, seg=24, axis='Z', mi=ST, mi_cap=ST)
    b.cone(1.2, 1.8, (0, 0, 13.4), 'Z', seg=4, mi=ST, smooth=False, rot=(0, 0, math.radians(45)))
    for z in (3.0, 5.0, 7.0, 9.0, 11.0):
        w = 1.0 - (z - 3.0) * 0.045
        b.box((w * 1.4, 0.05, 0.08), (0, -0.84 + (z - 3) * 0.008, z), GL)
        b.box((0.08, 0.05, 0.9), (-w * 0.4, -0.84, z + 0.4), GL)
        b.box((0.08, 0.05, 0.9), (w * 0.4, -0.84, z - 0.4), GL)
    b.sphere(0.35, (0, -0.86, 6.0), seg=12, rings=8, mi=GL)
    r = R(4)
    for i in range(6):
        a = i * math.pi / 3 + 0.2
        b.ico((0.9, 0.8, 1.8), (math.cos(a) * 6.0, math.sin(a) * 6.0, 0.8), sub=1, mi=ST, noise=0.2, seed=i, flat=True)
        b.box((0.06, 0.05, 1.0), (math.cos(a) * 5.35, math.sin(a) * 5.35, 1.0), GL, rot=(0, 0, a))
    return b.to_obj("Monolith")


def radio_tower():
    b = MB([metal, white, lightr, dark, orange])
    H = 18.0
    legs = []
    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.3
        legs.append((math.cos(a), math.sin(a)))
        seg_cyl(b, (math.cos(a) * 2.2, math.sin(a) * 2.2, -0.2), (math.cos(a) * 0.45, math.sin(a) * 0.45, H), 0.14, 0.08, seg=6, mi=0)
    for k in range(6):
        z0, z1 = 0.0 + k * 3.0, (k + 1) * 3.0
        t0, t1 = 2.2 - (2.2 - 0.45) * z0 / H, 2.2 - (2.2 - 0.45) * z1 / H
        for i in range(3):
            j = (i + 1) % 3
            p = V((legs[i][0] * t0, legs[i][1] * t0, z0))
            q = V((legs[j][0] * t1, legs[j][1] * t1, z1))
            seg_cyl(b, p, q, 0.05, 0.05, seg=5, mi=0)
            r0 = V((legs[j][0] * t0, legs[j][1] * t0, z0))
            seg_cyl(b, p, r0, 0.05, 0.05, seg=5, mi=0)
    b.cyl(2.6, 2.8, 0.5, (0, 0, -0.25), 'Z', seg=12, mi=3, smooth=False)
    b.cyl(0.5, 0.5, 2.0, (0, 0, H + 0.8), 'Z', seg=8, mi=1)
    b.sphere((1.0, 0.45, 1.0), (0.8, 0, H - 2.5), seg=14, rings=8, mi=1)
    b.sphere(0.35, (0, 0, H + 2.0), seg=10, rings=8, mi=2)
    b.box((1.4, 0.9, 1.0), (0, 2.6, 0.5), 4, bevel=0.05)
    return b.to_obj("Radio_Tower")


def crate_stack():
    b = MB([orange, dark, white_d])
    for (x, y, z, s, rz) in [(0, 0, 0.6, 1.2, 0.0), (1.3, 0.2, 0.6, 1.2, 0.15), (0.4, 0.05, 1.8, 1.2, 0.4), (-1.4, 0.5, 0.45, 0.9, -0.3)]:
        b.box((s, s, s), (x, y, z), 0, rot=(0, 0, rz), bevel=0.05)
        b.box((s * 1.03, s * 1.03, s * 0.12), (x, y, z), 1, rot=(0, 0, rz))
        b.box((s * 0.55, 0.04, s * 0.35), (x, y - s / 2 - 0.01, z + 0.05), 2, rot=(0, 0, rz))
    b.cyl(0.45, 0.45, 1.1, (-2.4, -0.7, 0.55), 'Z', seg=12, mi=2)
    b.cyl(0.47, 0.47, 0.1, (-2.4, -0.7, 0.55), 'Z', seg=12, mi=1)
    return b.to_obj("Crate_Stack")


def ore_node():
    b = MB([ore_g, ore_r])
    r = R(7)
    b.ico((1.2, 1.1, 0.5), (0, 0, 0.1), sub=1, mi=1, noise=0.2, seed=1, flat=True)
    for i in range(6):
        a = i * 1.05 + 0.4
        d = 0.0 if i == 0 else r.uniform(0.35, 0.8)
        h = 1.8 if i == 0 else r.uniform(0.7, 1.4)
        rad = 0.32 if i == 0 else r.uniform(0.14, 0.24)
        base = V((math.cos(a) * d, math.sin(a) * d, 0.0))
        lean = V((r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), 1.0)).normalized()
        seg_cyl(b, base, base + lean * h * 0.7, rad, rad * 0.9, seg=5, mi=0, smooth=False)
        seg_cyl(b, base + lean * h * 0.7, base + lean * h, rad * 0.9, 0.0, seg=5, mi=0, smooth=False)
    return b.to_obj("Ore_Node")


def wreck():
    b = MB([white, char, orange, metal, fire, dark])
    WH, CH, OR, ME, FI, DK = range(6)
    sec = [dict(p=(0, 0, 0), rx=1.4, ry=1.0, n=2.7), dict(p=(0, 2.5, 0.1), rx=1.35, ry=0.98, n=2.7), dict(p=(0, 4.5, 0.0), rx=1.0, ry=0.8, n=2.5),
           dict(p=(0, 6.0, -0.2), rx=0.6, ry=0.5, n=2.3)]
    f0 = b._n()
    b.loft(sec, seg=14, axis='Y', mi=WH, mi_cap=DK)
    b.transform(Matrix.Translation((0, -2.0, 1.2)) @ Euler((math.radians(14), 0, math.radians(18))).to_matrix().to_4x4(), f0)
    b.box((1.2, 1.4, 0.15), (-1.3, 3.0, 1.4), CH, rot=(0.2, 0.1, 0.5))
    # torn wing
    w0 = b._n()
    b.prism([(1.2, 1.6), (4.4, -2.4), (4.4, -3.4), (2.4, -3.6), (1.6, -1.2)], 0.2, 'XY', offset=0.0, mi=WH)
    b.prism([(3.2, -1.2), (4.4, -2.4), (4.4, -3.4), (3.0, -3.6)], 0.22, 'XY', offset=0.0, mi=OR)
    b.transform(Matrix.Translation((3.5, 2.0, 0.5)) @ Euler((math.radians(-25), math.radians(15), math.radians(100))).to_matrix().to_4x4(), w0)
    # debris
    r = R(3)
    for i in range(9):
        b.box((r.uniform(0.3, 1.2), r.uniform(0.3, 1.0), 0.08), (r.uniform(-5, 5), r.uniform(-4, 6), 0.1 + r.uniform(0, 0.4)), [CH, ME, WH][i % 3], rot=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), r.uniform(0, 3)))
    b.cyl(0.6, 0.6, 1.8, (-3.0, -1.5, 0.45), 'X', seg=10, mi=ME, rot=(0, 0.2, 0.4))
    b.sphere((0.9, 0.9, 0.35), (0.5, 4.2, 0.3), seg=10, rings=6, mi=FI)
    b.sphere((0.5, 0.5, 0.25), (-1.0, 2.2, 0.2), seg=8, rings=5, mi=FI)
    b.ico((2.0, 1.6, 0.7), (1.8, -0.6, 0.2), sub=1, mi=CH, noise=0.3, seed=5, flat=True)
    return b.to_obj("Wreck")


def space_station():
    b = MB([white, white_d, orange, dark, glass, solar, lightw, lightr, metal])
    WH, GR, OR, DK, GL, SO, LW, LR, ME = range(9)
    # hub along Y
    b.cyl(6.0, 6.0, 22.0, (0, 0, 0), 'Y', seg=24, mi=WH)
    b.sphere((6.0, 4.5, 6.0), (0, 11.0, 0), seg=24, rings=10, mi=WH)
    b.sphere((6.0, 3.5, 6.0), (0, -11.0, 0), seg=24, rings=10, mi=GR)
    b.cyl(6.3, 6.3, 1.2, (0, 4.0, 0), 'Y', seg=24, mi=OR)
    b.cyl(6.3, 6.3, 1.2, (0, -4.0, 0), 'Y', seg=24, mi=OR)
    # ring
    pts = [V((math.cos(2 * math.pi * i / 40) * 30.0, 0, math.sin(2 * math.pi * i / 40) * 30.0)) for i in range(41)]
    b.tube(pts, [(3.4, 2.6)] * 41, seg=14, mi=GR, smooth=True)
    for i in range(40):
        a = 2 * math.pi * i / 40
        if i % 2 == 0:
            b.box((2.6, 0.3, 1.2), (math.cos(a) * 30.0 * 0.0 + math.cos(a) * 30.0, math.sin(a) * 30.0 * 0.0, math.sin(a) * 30.0), GL, rot=(0, -a + math.pi / 2, 0))
    # spokes
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        seg_cyl(b, (math.cos(a) * 5.5, 0, math.sin(a) * 5.5), (math.cos(a) * 27.0, 0, math.sin(a) * 27.0), 1.1, 0.9, seg=10, mi=WH)
    # docking arm
    b.cyl(2.0, 2.0, 10.0, (0, 20.0, 0), 'Y', seg=12, mi=GR)
    b.cyl(3.4, 2.0, 2.0, (0, 26.0, 0), 'Y', seg=12, mi=OR)
    b.cyl(2.4, 2.4, 0.3, (0, 27.1, 0), 'Y', seg=12, mi=LW)
    # solar wings
    for sx in (-1, 1):
        seg_cyl(b, (sx * 6.0, -3.0, 0), (sx * 16.0, -3.0, 0), 0.5, 0.4, seg=8, mi=ME)
        b.box((14.0, 0.3, 6.0), (sx * 24.0, -3.0, 0), SO)
        for k in range(1, 7):
            b.box((0.15, 0.34, 6.1), (sx * (17.0 + k * 2.0), -3.0, 0), ME)
    b.sphere(0.5, (0, 9.0, 6.0), seg=8, rings=6, mi=LR)
    b.cyl(0.1, 0.1, 6.0, (0, -8.0, 6.0), 'Z', seg=6, mi=ME)
    b.sphere(0.4, (0, -8.0, 9.2), seg=8, rings=6, mi=LR)
    return b.to_obj("Space_Station")


items = [("rock_a", rock_a), ("rock_b", rock_b), ("rock_c", rock_c), ("pebbles", pebbles), ("rock_arch", rock_arch), ("hoodoo", hoodoo),
         ("asteroid_a", lambda: asteroid("Asteroid_A", 1, (1.0, 0.82, 0.9))), ("asteroid_b", lambda: asteroid("Asteroid_B", 2, (1.1, 0.7, 0.75))),
         ("asteroid_c", lambda: asteroid("Asteroid_C", 3, (0.9, 0.9, 1.1))),
         ("landing_pad", landing_pad), ("outpost", outpost), ("monolith", monolith), ("radio_tower", radio_tower), ("crate_stack", crate_stack),
         ("ore_node", ore_node), ("wreck", wreck), ("space_station", space_station)]
for o in list(bpy.data.objects):
    if o.get("asset") in [m[0] for m in items]:
        bpy.data.objects.remove(o, do_unlink=True)
for i, (name, fn) in enumerate(items):
    o = fn()
    big = name in ("space_station",)
    finish(name, [o], i % 8, i // 8 + 6, pv=name in ("landing_pad", "outpost", "monolith", "radio_tower", "wreck", "space_station", "rock_arch", "hoodoo", "ore_node"),
           cam=(1, -1.3, 0.5), dist=130 if big else None)
bpy.ops.wm.save_mainfile()
