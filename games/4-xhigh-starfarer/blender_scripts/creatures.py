exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort\blender_scripts\lib.py").read())
import math
R = random.Random

skin = mat("creature_skin", (0.55, 0.36, 0.24), 0.0, 0.7)
skin2 = mat("creature_skin2", (0.80, 0.68, 0.50), 0.0, 0.75)
spot = mat("creature_glow", (0.3, 1.0, 0.8), 0, 0.4, emit=(0.3, 1.0, 0.8), emit_strength=3.0)
eye = mat("creature_eye", (1.0, 0.85, 0.2), 0, 0.3, emit=(1.0, 0.8, 0.15), emit_strength=4.0)
horn = mat("creature_horn", (0.90, 0.88, 0.80), 0.0, 0.5)
jelly = mat("floater_body", (0.55, 0.35, 0.85), 0.0, 0.25, emit=(0.4, 0.2, 0.9), emit_strength=0.6)
jelly_t = mat("floater_tentacle", (0.45, 0.85, 0.95), 0.0, 0.3, emit=(0.3, 0.9, 1.0), emit_strength=2.0)
SK, SK2, SP, EY, HO = range(5)
MATS = [skin, skin2, spot, eye, horn]


def strider():
    b = MB(MATS)
    b.sphere((0.55, 1.15, 0.52), (0, 0, 1.55), seg=16, rings=10, mi=SK)
    b.sphere((0.50, 1.0, 0.36), (0, 0.05, 1.42), seg=14, rings=8, mi=SK2)
    b.tube([V((0, 0.9, 1.7)), V((0, 1.35, 2.0)), V((0, 1.7, 2.35))], [0.26, 0.20, 0.16], seg=10, mi=SK)
    b.sphere((0.24, 0.42, 0.22), (0, 2.0, 2.45), seg=12, rings=8, mi=SK)
    b.sphere((0.10, 0.10, 0.10), (-0.16, 2.12, 2.52), seg=8, rings=6, mi=EY)
    b.sphere((0.10, 0.10, 0.10), (0.16, 2.12, 2.52), seg=8, rings=6, mi=EY)
    seg_cyl(b, (-0.12, 1.95, 2.62), (-0.35, 1.85, 3.1), 0.07, 0.0, seg=5, mi=HO, smooth=False)
    seg_cyl(b, (0.12, 1.95, 2.62), (0.35, 1.85, 3.1), 0.07, 0.0, seg=5, mi=HO, smooth=False)
    b.tube([V((0, -1.0, 1.6)), V((0, -1.7, 1.55)), V((0, -2.3, 1.85)), V((0, -2.6, 2.3))], [0.22, 0.16, 0.10, 0.04], seg=8, mi=SK)
    for i in range(6):
        z = 2.05 - abs(i - 1.5) * 0.04
        seg_cyl(b, (0, 0.8 - i * 0.35, 2.0), (0, 0.8 - i * 0.35, 2.45 - i * 0.04), 0.09, 0.0, seg=4, mi=SP, smooth=False)
    for i in range(5):
        b.sphere(0.07, (0.5 * (1 if i % 2 else -1) * 0.95, 0.5 - i * 0.35, 1.7), seg=6, rings=4, mi=SP)
    body = b.to_obj("Creature_Body")
    legs = []
    for nm, x, y in (("FL", -0.42, 0.7), ("FR", 0.42, 0.7), ("BL", -0.42, -0.7), ("BR", 0.42, -0.7)):
        lb = MB(MATS)
        lb.tube([V((0, 0, 0)), V((0, 0.15, -0.7)), V((0, -0.05, -1.3))], [0.14, 0.10, 0.07], seg=7, mi=SK)
        lb.sphere((0.12, 0.2, 0.06), (0, 0.0, -1.33), seg=8, rings=5, mi=SK2)
        legs.append(lb.to_obj("Creature_Leg" + nm, loc=(x, y, 1.45), parent=body))
    return [body] + legs


def floater():
    b = MB([jelly, jelly_t, spot, eye, horn])
    b.sphere((1.3, 1.3, 0.9), (0, 0, 0.3), seg=20, rings=12, mi=0)
    b.sphere((1.15, 1.15, 0.5), (0, 0, -0.1), seg=18, rings=8, mi=2)
    r = R(2)
    for i in range(12):
        a = i * math.pi / 6
        b.sphere(0.09, (math.cos(a) * 0.75, math.sin(a) * 0.75, 1.05), seg=6, rings=4, mi=2)
    for i in range(8):
        a = i * math.pi / 4 + 0.2
        p0 = V((math.cos(a) * 0.7, math.sin(a) * 0.7, -0.1))
        L = r.uniform(2.6, 4.0)
        pts = [p0, p0 + V((math.cos(a) * 0.35, math.sin(a) * 0.35, -L * 0.4)), p0 + V((math.cos(a + 0.4) * 0.5, math.sin(a + 0.4) * 0.5, -L * 0.75)),
               p0 + V((math.cos(a) * 0.3, math.sin(a) * 0.3, -L))]
        b.tube(pts, [0.07, 0.05, 0.04, 0.02], seg=5, mi=1)
        b.sphere(0.07, pts[-1], seg=6, rings=4, mi=2)
    for i in range(4):
        a = i * math.pi / 2
        b.tube([V((0, 0, -0.2)), V((math.cos(a) * 0.4, math.sin(a) * 0.4, -1.0)), V((math.cos(a) * 0.9, math.sin(a) * 0.9, -2.2))], [0.12, 0.10, 0.03], seg=5, mi=0)
    return [b.to_obj("Creature_Floater")]


def flyer():
    b = MB(MATS)
    b.sphere((0.16, 0.42, 0.14), (0, 0, 0), seg=10, rings=7, mi=SK)
    b.sphere((0.11, 0.13, 0.11), (0, 0.46, 0.05), seg=8, rings=6, mi=SK2)
    seg_cyl(b, (0, 0.56, 0.05), (0, 0.80, 0.0), 0.04, 0.0, seg=5, mi=HO, smooth=False)
    b.sphere(0.03, (-0.07, 0.52, 0.09), seg=5, rings=4, mi=EY)
    b.sphere(0.03, (0.07, 0.52, 0.09), seg=5, rings=4, mi=EY)
    b.prism([(-0.06, -0.3), (0.06, -0.3), (0.16, -0.85), (-0.16, -0.85)], 0.03, 'XY', offset=0.0, mi=SK2)
    body = b.to_obj("Creature_Body")
    wings = []
    for nm, sx in (("L", -1), ("R", 1)):
        wb = MB(MATS)
        wb.prism([(0.0, 0.22), (0.9, 0.05), (1.25, -0.30), (0.5, -0.38), (0.0, -0.25)], 0.02, 'XY', offset=0.0, mi=SK, scale3=None)
        wb.prism([(0.7, 0.07), (1.25, -0.30), (0.9, -0.34)], 0.03, 'XY', offset=0.0, mi=SP)
        if sx < 0:
            wb.transform(Matrix.Diagonal((-1, 1, 1, 1)))
            wb.bm.faces.ensure_lookup_table()
            bmesh.ops.reverse_faces(wb.bm, faces=wb.bm.faces[:])
        wings.append(wb.to_obj("Creature_Wing" + nm, loc=(0.1 * sx, 0.04, 0.06), parent=body))
    return [body] + wings


items = [("creature_strider", strider), ("creature_floater", floater), ("creature_flyer", flyer)]
for o in list(bpy.data.objects):
    if o.get("asset") in [m[0] for m in items]:
        bpy.data.objects.remove(o, do_unlink=True)
for i, (name, fn) in enumerate(items):
    objs = fn()
    finish(name, objs, i, 9, pv=True, cam=(1, -1.3, 0.4))
bpy.ops.wm.save_mainfile()
