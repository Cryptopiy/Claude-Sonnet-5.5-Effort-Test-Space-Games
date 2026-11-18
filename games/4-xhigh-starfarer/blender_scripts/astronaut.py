exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort\blender_scripts\lib.py").read())
clear_prefix("Astro")
clear_prefix("Tool")

suit = mat("suit_white", (0.86, 0.87, 0.90), 0.05, 0.55)
suit_dark = mat("suit_dark", (0.12, 0.13, 0.16), 0.5, 0.5)
suit_acc = mat("suit_orange", (0.95, 0.40, 0.06), 0.1, 0.5)
visor = mat("visor_gold", (0.85, 0.62, 0.20), 1.0, 0.08)
led_g = mat("led_cyan", (0.2, 0.9, 1.0), 0, 0.4, emit=(0.2, 0.9, 1.0), emit_strength=4.0)
led_r = mat("led_red", (1.0, 0.15, 0.1), 0, 0.4, emit=(1.0, 0.15, 0.1), emit_strength=4.0)
jet_glow = mat("jet_glow", (0.4, 0.8, 1.0), 0, 0.5, emit=(0.4, 0.8, 1.0), emit_strength=6.0)
W, D, A, VIS, LC, LR = range(6)
MATS = [suit, suit_dark, suit_acc, visor, led_g, led_r]

J = {  # joint world positions (z up, y forward)
    'hips': V((0, 0, 0.98)),
    'torso': V((0, 0, 1.06)),
    'head': V((0, 0, 1.52)),
    'armL1': V((-0.31, 0, 1.40)), 'armL2': V((-0.31, 0, 1.13)),
    'armR1': V((0.31, 0, 1.40)), 'armR2': V((0.31, 0, 1.13)),
    'legL1': V((-0.12, 0, 0.93)), 'legL2': V((-0.12, 0, 0.51)),
    'legR1': V((0.12, 0, 0.93)), 'legR2': V((0.12, 0, 0.51)),
}
PARENT = {'torso': 'hips', 'head': 'torso', 'armL1': 'torso', 'armL2': 'armL1', 'armR1': 'torso', 'armR2': 'armR1',
          'legL1': 'hips', 'legL2': 'legL1', 'legR1': 'hips', 'legR2': 'legR1'}
objs = {}


def part(key, fn):
    b = MB(MATS)
    fn(b)
    b.transform(Matrix.Translation(-J[key]))
    par = PARENT.get(key)
    loc = J[key] - (J[par] if par else V((0, 0, 0)))
    o = b.to_obj("Astro_" + key, loc=loc, parent=objs[par] if par else None)
    objs[key] = o
    return o


def hips(b):
    b.box((0.34, 0.22, 0.20), (0, 0, 0.98), D, smooth=False, bevel=0.03)
    b.box((0.36, 0.24, 0.07), (0, 0, 1.05), W, smooth=False, bevel=0.02)


def torso(b):
    b.loft([
        dict(p=(0, 0, 1.06), rx=0.19, ry=0.125, n=2.6),
        dict(p=(0, 0, 1.22), rx=0.24, ry=0.155, n=2.6),
        dict(p=(0, 0, 1.40), rx=0.265, ry=0.165, n=2.5),
        dict(p=(0, 0, 1.49), rx=0.17, ry=0.12, n=2.3),
    ], seg=18, axis='Z', mi=W, mi_cap=D)
    # chest panel + lights
    b.box((0.26, 0.04, 0.17), (0, 0.158, 1.27), A, smooth=False, bevel=0.01)
    b.box((0.05, 0.02, 0.05), (-0.07, 0.185, 1.30), LC)
    b.box((0.05, 0.02, 0.05), (0.0, 0.185, 1.30), LC)
    b.box((0.05, 0.02, 0.05), (0.07, 0.185, 1.30), LR)
    b.box((0.18, 0.02, 0.025), (0, 0.185, 1.22), D)
    # shoulder pads
    b.sphere((0.11, 0.10, 0.09), (-0.30, 0, 1.43), seg=12, rings=8, mi=A)
    b.sphere((0.11, 0.10, 0.09), (0.30, 0, 1.43), seg=12, rings=8, mi=A)
    # backpack + jet thrusters
    b.box((0.36, 0.20, 0.46), (0, -0.25, 1.30), W, smooth=False, bevel=0.03)
    b.box((0.30, 0.04, 0.30), (0, -0.36, 1.30), D, smooth=False)
    b.box((0.30, 0.205, 0.05), (0, -0.25, 1.40), A, smooth=False)
    for sx in (-1, 1):
        b.cyl(0.075, 0.09, 0.22, (0.11 * sx, -0.27, 1.00), 'Z', seg=12, mi=D)
        b.cyl(0.06, 0.06, 0.03, (0.11 * sx, -0.27, 0.885), 'Z', seg=12, mi=LC)
    b.cyl(0.015, 0.012, 0.28, (0.13, -0.30, 1.68), 'Z', seg=6, mi=D)    # antenna
    b.sphere(0.022, (0.13, -0.30, 1.83), seg=6, rings=4, mi=LR)
    # hose from helmet to pack
    b.tube([V((0.10, -0.12, 1.50)), V((0.12, -0.20, 1.52)), V((0.12, -0.24, 1.45))], 0.02, seg=6, mi=D)


def head(b):
    b.cyl(0.095, 0.105, 0.09, (0, 0, 1.52), 'Z', seg=14, mi=D)                       # neck ring
    b.sphere((0.185, 0.185, 0.18), (0, 0, 1.66), seg=20, rings=14, mi=W)             # helmet shell
    b.sphere((0.15, 0.125, 0.115), (0, 0.085, 1.675), seg=20, rings=12, mi=VIS)       # visor
    b.box((0.06, 0.03, 0.025), (0.0, 0.205, 1.58), LC)                               # chin light
    b.sphere((0.05, 0.05, 0.03), (-0.17, 0, 1.68), seg=8, rings=6, mi=A)             # ear pads
    b.sphere((0.05, 0.05, 0.03), (0.17, 0, 1.68), seg=8, rings=6, mi=A)


def arm1(sx):
    def f(b):
        c = J['armL1'] if sx < 0 else J['armR1']
        b.cyl(0.07, 0.062, 0.30, (c.x, 0, 1.275), 'Z', seg=12, mi=W)
        b.sphere(0.068, (c.x, 0, 1.13), seg=10, rings=8, mi=D)
    return f


def arm2(sx):
    def f(b):
        c = J['armL2'] if sx < 0 else J['armR2']
        b.cyl(0.062, 0.055, 0.22, (c.x, 0, 1.01), 'Z', seg=12, mi=W)
        b.cyl(0.062, 0.062, 0.05, (c.x, 0, 0.90), 'Z', seg=12, mi=A)              # cuff
        b.sphere((0.07, 0.08, 0.075), (c.x, 0.005, 0.83), seg=12, rings=8, mi=D)  # glove
    return f


def leg1(sx):
    def f(b):
        c = J['legL1'] if sx < 0 else J['legR1']
        b.cyl(0.10, 0.085, 0.44, (c.x, 0, 0.72), 'Z', seg=12, mi=W)
        b.sphere(0.085, (c.x, 0.012, 0.52), seg=10, rings=8, mi=D)
    return f


def leg2(sx):
    def f(b):
        c = J['legL2'] if sx < 0 else J['legR2']
        b.sphere((0.07, 0.085, 0.07), (c.x, 0.05, 0.50), seg=10, rings=8, mi=A)   # knee pad
        b.cyl(0.085, 0.07, 0.34, (c.x, 0, 0.31), 'Z', seg=12, mi=W)
        b.box((0.15, 0.31, 0.12), (c.x, 0.05, 0.075), D, smooth=False, bevel=0.03)  # boot
        b.box((0.15, 0.10, 0.06), (c.x, 0.16, 0.10), A, smooth=False, bevel=0.015)   # toe cap
        b.box((0.155, 0.32, 0.03), (c.x, 0.05, 0.015), D, smooth=False)             # sole
    return f


part('hips', hips)
part('torso', torso)
part('head', head)
part('armL1', arm1(-1)); part('armL2', arm2(-1))
part('armR1', arm1(1)); part('armR2', arm2(1))
part('legL1', leg1(-1)); part('legL2', leg2(-1))
part('legR1', leg1(1)); part('legR2', leg2(1))

# jetpack flames (children of torso, nozzle origin, pointing down -Z)
for sx, nm in ((-1, "L"), (1, "R")):
    fb = MB([jet_glow])
    fb.cyl(0.0, 0.055, 0.55, (0, 0, -0.275), 'Z', seg=10, mi=0, smooth=True, caps=False)
    fo = fb.to_obj("Astro_JetFlame_" + nm, loc=(0.11 * sx, -0.27, 0.875 - 1.06), parent=objs['torso'])
    objs["flame" + nm] = fo

# empty marking the right hand attach point (tool socket)
sock = empty("Astro_HandR", loc=(0, 0.02, -0.28 + 0.0), parent=objs['armR2'])
objs['sock'] = sock

alist = list(objs.values())
for o in alist:
    o["asset"] = "astronaut"
path = export_glb("astronaut", alist)
print("exported", path)
preview(alist, PROJECT + r"\blender_scripts\_pv_astro.png", cam_dir=(0.9, 1.2, 0.35), dist=6.0, lens=60)
preview(alist, PROJECT + r"\blender_scripts\_pv_astro_back.png", cam_dir=(-0.9, -1.2, 0.35), dist=6.0, lens=60)

# ---------------- multitool (first-person + hand held), forward +Y, origin at the grip
t_body = mat("tool_body", (0.22, 0.24, 0.28), 0.8, 0.35)
t_acc = mat("tool_orange", (0.95, 0.40, 0.06), 0.2, 0.45)
t_white = mat("tool_white", (0.82, 0.84, 0.88), 0.3, 0.4)
t_lens = mat("tool_lens", (0.1, 0.9, 1.0), 0, 0.2, emit=(0.1, 0.9, 1.0), emit_strength=7.0)
t_scr = mat("tool_screen", (0.1, 0.5, 0.7), 0, 0.3, emit=(0.15, 0.7, 1.0), emit_strength=3.0)
T = MB([t_body, t_acc, t_white, t_lens, t_scr])
T.box((0.07, 0.30, 0.10), (0, 0.10, 0.04), 0, bevel=0.012)
T.box((0.075, 0.18, 0.04), (0, 0.06, 0.105), 2, bevel=0.01)
T.cyl(0.032, 0.026, 0.26, (0, 0.34, 0.05), 'Y', seg=14, mi=0)
T.cyl(0.040, 0.040, 0.05, (0, 0.30, 0.05), 'Y', seg=14, mi=1)
T.cyl(0.022, 0.022, 0.03, (0, 0.485, 0.05), 'Y', seg=12, mi=3)
T.box((0.05, 0.07, 0.15), (0, -0.01, -0.07), 0, rot=(math.radians(-18), 0, 0), bevel=0.01)   # grip
T.box((0.045, 0.10, 0.05), (0, -0.12, 0.05), 1, bevel=0.01)
T.box((0.05, 0.07, 0.003), (0, 0.045, 0.126), 4)
T.box((0.03, 0.015, 0.03), (0.0, 0.17, 0.10), 3)
tool = T.to_obj("Tool_Multi")
tool["asset"] = "multitool"
export_glb("multitool", [tool])
preview([tool], PROJECT + r"\blender_scripts\_pv_tool.png", cam_dir=(1, -1, 0.6), dist=1.4)
shelf(alist, -30, 0)
shelf([tool], -28, 0)
bpy.ops.wm.save_mainfile()
print("astro tris", sum(len(o.data.polygons) for o in alist if o.type == 'MESH'))
