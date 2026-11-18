exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort\blender_scripts\lib.py").read())
import math
R = random.Random

bark = mat("bark", (0.36, 0.25, 0.17), 0.0, 0.9)
bark_pale = mat("bark_pale", (0.62, 0.56, 0.48), 0.0, 0.9)
leaf_a = mat("leaf_a", (0.20, 0.58, 0.26), 0.0, 0.7)
leaf_b = mat("leaf_b", (0.34, 0.72, 0.32), 0.0, 0.7)
leaf_c = mat("leaf_c", (0.80, 0.35, 0.55), 0.0, 0.7)
glowpink = mat("glow_pink", (1.0, 0.4, 0.7), 0, 0.4, emit=(1.0, 0.35, 0.7), emit_strength=3.0)
glowcyan = mat("glow_cyan", (0.3, 0.9, 1.0), 0, 0.4, emit=(0.3, 0.9, 1.0), emit_strength=4.0)
glowgreen = mat("glow_green", (0.4, 1.0, 0.5), 0, 0.4, emit=(0.4, 1.0, 0.5), emit_strength=4.0)
glowor = mat("glow_orange", (1.0, 0.45, 0.1), 0, 0.4, emit=(1.0, 0.4, 0.05), emit_strength=6.0)
snow = mat("snow", (0.92, 0.95, 1.0), 0.0, 0.6)
pine = mat("pine", (0.10, 0.36, 0.22), 0.0, 0.8)
cactus_m = mat("cactus", (0.30, 0.52, 0.26), 0.0, 0.7)
cactus_f = mat("cactus_flower", (1.0, 0.55, 0.15), 0, 0.5, emit=(1.0, 0.5, 0.1), emit_strength=1.5)
stalk_m = mat("stalk", (0.78, 0.74, 0.60), 0.0, 0.8)
cap_m = mat("mush_cap", (0.48, 0.16, 0.58), 0.0, 0.55)
gill_m = mat("mush_gill", (0.20, 0.08, 0.28), 0.0, 0.8)
crystal = mat("crystal", (0.55, 0.78, 1.0), 0.0, 0.12, emit=(0.35, 0.65, 1.0), emit_strength=1.4)
crystal_core = mat("crystal_core", (0.9, 0.95, 1.0), 0.0, 0.1, emit=(0.8, 0.9, 1.0), emit_strength=3.0)
ice = mat("ice", (0.70, 0.88, 1.0), 0.0, 0.1, emit=(0.4, 0.65, 0.9), emit_strength=0.4)
obsid = mat("obsidian", (0.06, 0.05, 0.07), 0.6, 0.25)
rock_dark = mat("rock_dark", (0.22, 0.17, 0.16), 0.0, 0.9)


def rotz(a):
    return Euler((0, 0, a))


# ============================================================ tree_lush (A): broad alien tree
def tree_lush():
    r = R(11)
    b = MB([bark, leaf_a, leaf_b, glowpink])
    # curved trunk
    pts = [V((0, 0, -0.5)), V((0.15, 0.1, 2.0)), V((-0.2, 0.0, 4.5)), V((0.1, -0.2, 7.0)), V((0.3, 0.0, 9.0))]
    b.tube(pts, [0.75, 0.55, 0.42, 0.32, 0.22], seg=9, mi=0, smooth=True)
    # root flare
    for i in range(5):
        a = i * 2 * math.pi / 5 + 0.3
        seg_cyl(b, (0, 0, 0.9), (math.cos(a) * 1.5, math.sin(a) * 1.5, -0.3), 0.30, 0.10, seg=6, mi=0)
    # branches
    tips = []
    for i in range(4):
        a = i * 2 * math.pi / 4 + 0.5
        z0 = 5.5 + i * 0.9
        p1 = V((math.cos(a) * 3.2, math.sin(a) * 3.2, z0 + 2.2))
        seg_cyl(b, (0, 0, z0), p1, 0.22, 0.09, seg=6, mi=0)
        tips.append(p1)
    tips.append(V((0.3, 0, 9.0)))
    # foliage blobs
    for i, t in enumerate(tips):
        rad = 2.6 + r.uniform(-0.3, 0.5) if i < 4 else 3.4
        b.ico((rad * 1.2, rad * 1.2, rad * 0.8), t + V((0, 0, 0.9)), sub=2, mi=1 + (i % 2), noise=0.16, seed=i, flat=True)
        b.ico((rad * 0.8, rad * 0.8, rad * 0.55), t + V((0.6, -0.5, 2.0)), sub=2, mi=2 - (i % 2), noise=0.18, seed=10 + i, flat=True)
    # glowing fruit
    for i in range(9):
        a = r.uniform(0, 6.28)
        d = r.uniform(1.5, 3.4)
        b.sphere(0.17, (math.cos(a) * d, math.sin(a) * d, 6.5 + r.uniform(0, 2.0)), seg=8, rings=6, mi=3)
    return b.to_obj("Tree_Lush")


def tree_umbrella():
    r = R(5)
    b = MB([bark_pale, leaf_c, leaf_b, glowpink])
    pts = [V((0, 0, -0.5)), V((0.5, 0, 3.0)), V((-0.3, 0.2, 7.0)), V((0.2, 0, 11.0)), V((0, 0, 13.0))]
    b.tube(pts, [0.55, 0.38, 0.30, 0.24, 0.18], seg=8, mi=0)
    for i in range(6):
        a = i * math.pi / 3
        p = V((math.cos(a) * 5.0, math.sin(a) * 5.0, 12.2 - (i % 2) * 0.5))
        seg_cyl(b, (0, 0, 12.0), p, 0.16, 0.07, seg=6, mi=0)
        b.ico((2.6, 2.6, 0.7), p + V((0, 0, 0.2)), sub=2, mi=1, noise=0.12, seed=i, flat=True)
        # hanging vine
        b.tube([p, p + V((0, 0, -1.4)), p + V((0.2, 0.2, -3.0))], [0.06, 0.04, 0.025], seg=5, mi=2)
        b.sphere(0.13, p + V((0.2, 0.2, -3.0)), seg=6, rings=4, mi=3)
    b.ico((3.4, 3.4, 0.9), (0, 0, 13.2), sub=2, mi=1, noise=0.12, seed=77, flat=True)
    return b.to_obj("Tree_Umbrella")


def tree_pine():
    b = MB([bark, pine, snow])
    seg_cyl(b, (0, 0, -0.3), (0, 0, 9.5), 0.5, 0.12, seg=8, mi=0)
    z = 1.4
    for i, (rad, hgt) in enumerate([(2.8, 3.2), (2.4, 2.9), (2.0, 2.6), (1.5, 2.3), (1.0, 2.0)]):
        b.cone(rad, hgt, (0, 0, z + hgt / 2), 'Z', seg=9, mi=1, smooth=False)
        # snow cap on each tier (smaller, offset up)
        b.cone(rad * 0.78, hgt * 0.7, (0, 0, z + hgt * 0.62), 'Z', seg=9, mi=2, smooth=False)
        z += hgt * 0.62
    b.cone(0.5, 1.4, (0, 0, z + 1.0), 'Z', seg=7, mi=2, smooth=False)
    return b.to_obj("Tree_Pine")


def cactus():
    b = MB([cactus_m, cactus_f, bark])
    b.cyl(0.55, 0.45, 7.0, (0, 0, 3.4), 'Z', seg=8, mi=0, smooth=False)
    b.sphere((0.45, 0.45, 0.4), (0, 0, 6.9), seg=8, rings=5, mi=0, smooth=False)
    for sgn, z0, ln in ((1, 2.4, 2.4), (-1, 3.6, 2.0)):
        pts = [V((0.3 * sgn, 0, z0)), V((1.5 * sgn, 0, z0 + 0.2)), V((2.0 * sgn, 0.0, z0 + 1.4)), V((2.05 * sgn, 0, z0 + ln + 1.4))]
        b.tube(pts, [0.32, 0.30, 0.28, 0.24], seg=8, mi=0, smooth=False)
        b.sphere(0.27, pts[-1], seg=8, rings=5, mi=0, smooth=False)
        b.sphere(0.12, pts[-1] + V((0, 0, 0.25)), seg=6, rings=4, mi=1)
    b.sphere(0.2, (0, 0, 7.3), seg=8, rings=5, mi=1)
    for i in range(8):   # spines
        a = i * 0.9
        b.box((0.03, 0.03, 0.18), (math.cos(a) * 0.5, math.sin(a) * 0.5, 1.5 + i * 0.7), 2)
    return b.to_obj("Cactus")


def dead_tree():
    b = MB([bark_pale])
    r = R(3)
    pts = [V((0, 0, -0.4)), V((0.3, 0.1, 2.0)), V((-0.2, 0.0, 4.0)), V((0.2, -0.1, 6.0))]
    b.tube(pts, [0.42, 0.32, 0.22, 0.12], seg=7, smooth=False)
    for i in range(7):
        a = i * 2.4 + 0.5
        z0 = 1.8 + i * 0.6
        dirv = V((math.cos(a), math.sin(a), 0.7 + r.uniform(0, 0.5))).normalized()
        p1 = V((0, 0, z0)) + dirv * r.uniform(1.6, 2.8)
        p2 = p1 + (dirv + V((0, 0, 0.6))).normalized() * 1.2
        b.tube([V((0, 0, z0)), p1, p2], [0.12, 0.08, 0.03], seg=5, smooth=False)
    return b.to_obj("Tree_Dead")


def mushroom():
    b = MB([stalk_m, cap_m, gill_m, glowgreen])
    sec = [dict(p=(0, 0, -0.3), rx=0.9, ry=0.9), dict(p=(0, 0, 0.8), rx=0.55, ry=0.55), dict(p=(0, 0, 4.0), rx=0.42, ry=0.42),
           dict(p=(0, 0, 7.0), rx=0.5, ry=0.5)]
    b.loft(sec, seg=12, axis='Z', mi=0)
    # cap: flattened hemisphere-ish
    b.sphere((3.6, 3.6, 2.2), (0, 0, 7.4), seg=18, rings=10, mi=1)
    b.cyl(3.5, 0.6, 0.5, (0, 0, 7.0), 'Z', seg=18, mi=2, smooth=False)     # gill underside
    r = R(8)
    for i in range(14):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.4, 2.9)
        z = 7.4 + math.sqrt(max(0.1, 1.0 - (d / 3.6) ** 2)) * 2.2 - 0.15
        b.sphere(0.2 + r.uniform(0, 0.15), (math.cos(a) * d, math.sin(a) * d, z), seg=8, rings=5, mi=3)
    return b.to_obj("Mushroom_Giant")


def mushroom_small():
    b = MB([stalk_m, cap_m, gill_m, glowgreen])
    r = R(2)
    for i, (x, y, s) in enumerate([(0, 0, 1.0), (0.9, 0.4, 0.65), (-0.6, 0.8, 0.5), (0.2, -0.9, 0.55)]):
        b.cyl(0.10 * s, 0.14 * s, 1.2 * s, (x, y, 0.6 * s), 'Z', seg=7, mi=0)
        b.sphere((0.55 * s, 0.55 * s, 0.32 * s), (x, y, 1.25 * s), seg=10, rings=6, mi=1)
        b.sphere(0.07 * s, (x + 0.1 * s, y, 1.5 * s), seg=6, rings=4, mi=3)
    return b.to_obj("Mushroom_Small")


def flower_glow():
    b = MB([leaf_a, glowcyan, leaf_b, glowpink])
    pts = [V((0, 0, 0)), V((0.2, 0.0, 0.7)), V((0.0, 0.1, 1.4)), V((-0.15, 0.0, 2.0))]
    b.tube(pts, [0.05, 0.045, 0.04, 0.035], seg=5, mi=0)
    b.sphere((0.30, 0.30, 0.38), (-0.15, 0, 2.3), seg=10, rings=8, mi=1)
    for i in range(6):
        a = i * math.pi / 3
        seg_cyl(b, (-0.15, 0, 2.05), (-0.15 + math.cos(a) * 0.38, math.sin(a) * 0.38, 2.45), 0.08, 0.0, seg=4, mi=3, smooth=False)
    for i in range(3):
        a = i * 2.1 + 0.3
        seg_cyl(b, (0.05, 0, 0.3), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.9), 0.07, 0.0, seg=3, mi=2, smooth=False)
    return b.to_obj("Flower_Glow")


def grass_tuft():
    b = MB([leaf_a, leaf_b])
    r = R(4)
    for i in range(11):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.0, 0.18)
        lean = r.uniform(0.15, 0.6)
        dirv = V((math.cos(a) * lean, math.sin(a) * lean, 1.0))
        blade(b, V((math.cos(a) * d, math.sin(a) * d, 0)), dirv, r.uniform(0.5, 1.15), 0.045, i % 2)
    return b.to_obj("Grass_Tuft")


def bush():
    b = MB([leaf_a, leaf_b, glowpink, bark])
    r = R(6)
    for i in range(6):
        a = i * 1.05
        d = 0.0 if i == 0 else r.uniform(0.5, 0.9)
        b.ico((0.8, 0.8, 0.6), (math.cos(a) * d, math.sin(a) * d, 0.55 + r.uniform(0, 0.2)), sub=2, mi=i % 2, noise=0.18, seed=i, flat=True)
    for i in range(8):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.2, 1.0)
        b.sphere(0.075, (math.cos(a) * d, math.sin(a) * d, 0.7 + r.uniform(0, 0.4)), seg=6, rings=4, mi=2)
    return b.to_obj("Bush")


def crystal_cluster():
    b = MB([crystal, crystal_core, rock_dark])
    r = R(13)
    b.ico((1.6, 1.4, 0.45), (0, 0, 0.1), sub=1, mi=2, noise=0.2, seed=4, flat=True)
    specs = [(0, 0, 4.2, 0.55, 0.0, 0), (0.9, 0.3, 3.0, 0.38, 0.35, 1.0), (-0.8, 0.5, 2.6, 0.35, -0.4, 2.2), (0.3, -0.9, 2.2, 0.32, 0.5, 4.0),
             (-0.5, -0.7, 1.7, 0.28, -0.55, 3.5), (1.2, -0.4, 1.4, 0.25, 0.8, 5.0), (-1.2, -0.1, 1.2, 0.22, -0.8, 1.2)]
    for (x, y, h, rad, tilt, az) in specs:
        dirv = V((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))
        base = V((x, y, 0.0))
        tip = base + dirv * h
        seg_cyl(b, base, base + dirv * (h * 0.78), rad, rad, seg=6, mi=0, smooth=False)
        seg_cyl(b, base + dirv * (h * 0.78), tip, rad, 0.0, seg=6, mi=0, smooth=False)
        seg_cyl(b, base, base + dirv * (h * 0.5), rad * 0.4, rad * 0.4, seg=6, mi=1, smooth=False)
    return b.to_obj("Crystal_Cluster")


def ice_spire():
    b = MB([ice, crystal_core, snow])
    r = R(21)
    for i in range(9):
        a = r.uniform(0, 6.28)
        d = 0.0 if i == 0 else r.uniform(0.5, 1.8)
        h = 7.5 if i == 0 else r.uniform(1.8, 5.0)
        rad = 0.8 if i == 0 else r.uniform(0.3, 0.6)
        base = V((math.cos(a) * d, math.sin(a) * d, -0.3))
        lean = V((r.uniform(-0.25, 0.25), r.uniform(-0.25, 0.25), 1.0)).normalized()
        seg_cyl(b, base, base + lean * h * 0.72, rad, rad * 0.85, seg=5, mi=0, smooth=False)
        seg_cyl(b, base + lean * h * 0.72, base + lean * h, rad * 0.85, 0.0, seg=5, mi=0, smooth=False)
    b.ico((2.0, 1.8, 0.35), (0, 0, 0.0), sub=1, mi=2, noise=0.15, seed=3, flat=True)
    return b.to_obj("Ice_Spire")


def lava_spike():
    b = MB([obsid, glowor, rock_dark])
    r = R(17)
    b.ico((2.0, 1.8, 0.7), (0, 0, 0.1), sub=1, mi=2, noise=0.2, seed=9, flat=True)
    for i in range(7):
        a = r.uniform(0, 6.28)
        d = 0.0 if i == 0 else r.uniform(0.5, 1.5)
        h = 6.0 if i == 0 else r.uniform(1.6, 4.2)
        rad = 0.9 if i == 0 else r.uniform(0.35, 0.65)
        base = V((math.cos(a) * d, math.sin(a) * d, 0.0))
        lean = V((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), 1.0)).normalized()
        seg_cyl(b, base, base + lean * h, rad, 0.0, seg=5, mi=0, smooth=False)
        # glowing vein on one side
        side = V((lean.y, -lean.x, 0)).normalized() * rad * 0.8
        seg_cyl(b, base + side, base + lean * h * 0.8 + side * 0.15, 0.06, 0.02, seg=4, mi=1, smooth=False)
    return b.to_obj("Lava_Spike")


def vent_cone():
    b = MB([rock_dark, glowor, obsid])
    b.cyl(2.6, 1.0, 2.2, (0, 0, 1.0), 'Z', seg=10, mi=0, smooth=False)
    b.cyl(1.0, 0.9, 0.3, (0, 0, 2.15), 'Z', seg=10, mi=2, smooth=False)
    b.cyl(0.85, 0.85, 0.05, (0, 0, 2.3), 'Z', seg=10, mi=1)
    r = R(5)
    for i in range(8):
        a = i * 0.78
        seg_cyl(b, (math.cos(a) * 1.1, math.sin(a) * 1.1, 2.0), (math.cos(a) * 2.5, math.sin(a) * 2.5, 0.5), 0.07, 0.04, seg=4, mi=1)
    return b.to_obj("Vent_Cone")


def spore_pod():
    b = MB([stalk_m, cap_m, glowgreen, leaf_a])
    r = R(12)
    b.sphere((1.0, 1.0, 1.4), (0, 0, 1.6), seg=12, rings=9, mi=1)
    b.sphere((0.5, 0.5, 0.6), (0, 0, 2.9), seg=10, rings=7, mi=2)
    for i in range(7):
        a = i * 0.9
        p0 = V((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.4))
        p1 = V((math.cos(a) * 1.8, math.sin(a) * 1.8, 1.0 + r.uniform(0, 0.8)))
        p2 = V((math.cos(a) * 2.6, math.sin(a) * 2.6, 0.2))
        b.tube([p0, p1, p2], [0.12, 0.09, 0.05], seg=5, mi=3)
        b.sphere(0.10, p2, seg=6, rings=4, mi=2)
    b.cyl(0.5, 0.7, 0.8, (0, 0, 0.3), 'Z', seg=10, mi=0)
    return b.to_obj("Spore_Pod")


def coral_tower():
    b = MB([cap_m, glowpink, stalk_m])
    r = R(31)
    for i in range(6):
        a = r.uniform(0, 6.28)
        d = 0.0 if i == 0 else r.uniform(0.6, 1.8)
        base = V((math.cos(a) * d, math.sin(a) * d, -0.2))
        h = 5.0 if i == 0 else r.uniform(2.0, 4.0)
        pts = [base, base + V((r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), h * 0.5)), base + V((r.uniform(-0.8, 0.8), r.uniform(-0.8, 0.8), h))]
        b.tube(pts, [0.5, 0.38, 0.18], seg=7, mi=0)
        b.sphere(0.35, pts[-1], seg=8, rings=6, mi=1)
        for k in range(3):
            q = pts[1] + V((r.uniform(-0.9, 0.9), r.uniform(-0.9, 0.9), r.uniform(0.2, 1.4)))
            seg_cyl(b, pts[1], q, 0.16, 0.07, seg=5, mi=0)
            b.sphere(0.16, q, seg=6, rings=4, mi=1)
    return b.to_obj("Coral_Tower")


made = [("tree_lush", tree_lush, "tree_lush"), ("tree_umbrella", tree_umbrella, None), ("tree_pine", tree_pine, None), ("cactus", cactus, None),
        ("tree_dead", dead_tree, None), ("mushroom_giant", mushroom, None), ("mushroom_small", mushroom_small, None),
        ("flower_glow", flower_glow, None), ("grass_tuft", grass_tuft, None), ("bush", bush, None), ("crystal_cluster", crystal_cluster, None),
        ("ice_spire", ice_spire, None), ("lava_spike", lava_spike, None), ("vent_cone", vent_cone, None), ("spore_pod", spore_pod, None),
        ("coral_tower", coral_tower, None)]
for name, _, _ in made:
    clear_prefix(name.title().replace("_", "_"))
for o in list(bpy.data.objects):
    if o.get("asset") in [m[0] for m in made]:
        bpy.data.objects.remove(o, do_unlink=True)
for i, (name, fn, pv) in enumerate(made):
    o = fn()
    finish(name, [o], i % 8, i // 8 + 3, pv=name in ("tree_lush", "cactus", "mushroom_giant", "crystal_cluster", "tree_pine", "lava_spike", "tree_umbrella", "flower_glow"), cam=(1, -1.3, 0.45))
bpy.ops.wm.save_mainfile()
