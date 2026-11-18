"""Flora, rocks and alien vegetation props. Re-runnable: each model is rebuilt and re-exported."""
import math, random
from mathutils import Vector
exec(open(r"W:\YouTube\Sonnet 5.5 Effort Test\3. High Effort\tools\blender\blib.py").read())


def two_sided(m):
    m.use_backface_culling = False
    return m


bark = mat("bark", (0.32, 0.2, 0.12), 0.0, 0.9)
bark_pale = mat("bark_pale", (0.62, 0.56, 0.48), 0.0, 0.85)
leaf_green = two_sided(mat("leaf_green", (0.2, 0.55, 0.16), 0.0, 0.7))
leaf_light = two_sided(mat("leaf_light", (0.42, 0.72, 0.2), 0.0, 0.7))
leaf_pine = mat("leaf_pine", (0.08, 0.34, 0.2), 0.0, 0.75)
leaf_pink = mat("leaf_pink", (0.92, 0.45, 0.62), 0.0, 0.65)
snow_white = mat("snow_white", (0.93, 0.96, 1.0), 0.0, 0.5)
rock_grey = mat("rock_grey", (0.55, 0.54, 0.52), 0.0, 0.92)
rock_dark = mat("rock_dark", (0.2, 0.19, 0.2), 0.1, 0.8)
grass_m = two_sided(mat("grass_blade", (0.75, 0.85, 0.62), 0.0, 0.8))
cactus_m = mat("cactus_green", (0.3, 0.52, 0.28), 0.0, 0.7)
flower_a = mat("flower_red", (0.95, 0.15, 0.2), 0.0, 0.6)
flower_b = mat("flower_yellow", (1.0, 0.85, 0.15), 0.0, 0.6)
flower_c = mat("flower_blue", (0.35, 0.45, 1.0), 0.0, 0.6)
stem_m = mat("stem_green", (0.15, 0.4, 0.12), 0.0, 0.8)
ice_m = mat("ice_blue", (0.55, 0.8, 1.0), 0.0, 0.08, emit=(0.2, 0.5, 0.9), emit_strength=0.35, alpha=0.85)
obsidian = mat("obsidian", (0.04, 0.03, 0.05), 0.4, 0.12)
lava_glow = mat("lava_glow", (1.0, 0.3, 0.05), 0.0, 0.5, emit=(1.0, 0.28, 0.04), emit_strength=7.0)
mush_cap = mat("mushroom_cap", (0.55, 0.15, 0.7), 0.0, 0.5, emit=(0.5, 0.1, 0.8), emit_strength=0.6)
mush_stem = mat("mushroom_stem", (0.75, 0.7, 0.55), 0.0, 0.7)
bio_glow = mat("bio_glow", (0.3, 1.0, 0.55), 0.0, 0.4, emit=(0.2, 1.0, 0.5), emit_strength=4.0)
crystal_m = mat("crystal_glow", (0.85, 0.95, 1.0), 0.0, 0.15, emit=(0.85, 0.95, 1.0), emit_strength=2.5, alpha=0.95)
ore_vein = mat("ore_vein", (1.0, 0.8, 0.3), 0.0, 0.4, emit=(1.0, 0.8, 0.3), emit_strength=3.0)


def blob(b, c, r, m, seed, seg=8, rings=5, jit=0.18, squash=1.0):
    b.sphere(c, (r, r, r * squash), seg=seg, rings=rings, m=m, smooth=False, jitter=jit, seed=seed)


def blade(b, base, h, lean_dir, w=0.05, m=grass_m, lean=0.25):
    bx, by = base
    dx, dy = math.cos(lean_dir), math.sin(lean_dir)
    px, py = -dy, dx
    L = lean * h
    mid = (bx + dx * L * 0.35, by + dy * L * 0.35, h * 0.5)
    tip = (bx + dx * L, by + dy * L, h)
    pts = [Vector((bx - px * w, by - py * w, 0)), Vector((bx + px * w, by + py * w, 0)),
           Vector((mid[0] + px * w * 0.6, mid[1] + py * w * 0.6, mid[2])), Vector((mid[0] - px * w * 0.6, mid[1] - py * w * 0.6, mid[2])),
           Vector(tip)]
    b._add(pts, [[0, 1, 2, 3], [3, 2, 4]], m, False)


def publish(root, fname, **kw):
    export(root, fname)
    if kw.get("prev", True):
        preview(root, fname.replace(".glb", ".png"), elev=kw.get("elev", 18), azim=kw.get("azim", -35), res=(420, 420))
    stash(root)


def new(name):
    remove_tree(name)
    return empty(name)


# ---------------- LUSH
r = new("tree_broad")
b = MB("tree_broad_m")
pr = [(0.45, 0.0), (0.38, 1.5), (0.3, 3.2), (0.18, 4.4)]
b.lathe(pr, seg=9, m=bark, center=(0, 0, 0))
b.cyl((0.45, 0.2, 3.7), 0.12, 0.08, 1.8, seg=6, rot=(0, 40, 0), m=bark)
b.cyl((-0.4, -0.1, 3.5), 0.12, 0.08, 1.6, seg=6, rot=(0, -45, 0), m=bark)
for i, (c, rad, mm) in enumerate([((0, 0, 5.8), 2.1, leaf_green), ((1.6, 0.4, 5.0), 1.5, leaf_light), ((-1.5, -0.5, 4.9), 1.55, leaf_green),
                                  ((0.3, 1.4, 6.5), 1.3, leaf_light), ((-0.5, -1.3, 6.3), 1.2, leaf_green)]):
    blob(b, c, rad, mm, i + 3, squash=0.78)
b.build(parent=r)
publish(r, "tree_broad.glb")

r = new("tree_conifer")
b = MB("tree_conifer_m")
b.lathe([(0.35, 0), (0.28, 1.5), (0.1, 3.0)], seg=8, m=bark)
for i, (z, rad, h) in enumerate([(1.4, 2.2, 2.4), (2.8, 1.8, 2.2), (4.1, 1.4, 2.0), (5.3, 1.0, 1.8), (6.4, 0.6, 1.6)]):
    b.cyl((0, 0, z + h / 2), rad, 0.02, h, seg=9, m=leaf_pine, caps=True, smooth=False)
b.build(parent=r)
publish(r, "tree_conifer.glb")

r = new("tree_blossom")
b = MB("tree_blossom_m")
b.lathe([(0.4, 0), (0.3, 2.0), (0.22, 3.6)], seg=8, m=bark_pale)
b.cyl((0.8, 0, 3.6), 0.18, 0.1, 1.9, seg=6, rot=(0, 55, 0), m=bark_pale)
b.cyl((-0.8, 0.2, 3.5), 0.16, 0.1, 1.8, seg=6, rot=(0, -55, 0), m=bark_pale)
for i, (c, rad) in enumerate([((0, 0, 4.9), 2.4), ((2.0, 0, 4.6), 1.7), ((-2.0, 0.3, 4.4), 1.7), ((0, 1.8, 4.3), 1.4), ((0.4, -1.8, 4.6), 1.5)]):
    blob(b, c, rad, leaf_pink, 20 + i, squash=0.5, jit=0.12)
b.build(parent=r)
publish(r, "tree_blossom.glb")

r = new("bush")
b = MB("bush_m")
for i, (c, rad, mm) in enumerate([((0, 0, 0.5), 0.8, leaf_green), ((0.7, 0.3, 0.4), 0.55, leaf_light), ((-0.6, -0.3, 0.35), 0.5, leaf_green), ((0.1, -0.7, 0.3), 0.4, leaf_light)]):
    blob(b, c, rad, mm, 40 + i, squash=0.75)
b.build(parent=r)
publish(r, "bush.glb")

r = new("grass_tuft")
b = MB("grass_tuft_m")
rn = random.Random(5)
for i in range(11):
    a = rn.uniform(0, 6.28)
    d = rn.uniform(0.0, 0.18)
    blade(b, (math.cos(a) * d, math.sin(a) * d), rn.uniform(0.55, 1.0), a + rn.uniform(-0.5, 0.5), w=0.045)
b.build(parent=r)
publish(r, "grass_tuft.glb")

r = new("flowers")
b = MB("flowers_m")
rn = random.Random(11)
for i, fm in enumerate([flower_a, flower_b, flower_c, flower_a, flower_b, flower_c]):
    a = rn.uniform(0, 6.28)
    d = rn.uniform(0.1, 0.5)
    x, y = math.cos(a) * d, math.sin(a) * d
    h = rn.uniform(0.35, 0.7)
    b.cyl((x, y, h / 2), 0.012, 0.01, h, seg=5, m=stem_m, caps=False)
    for k in range(5):
        pa = 2 * math.pi * k / 5
        b.sphere((x + math.cos(pa) * 0.06, y + math.sin(pa) * 0.06, h + 0.02), (0.045, 0.045, 0.02), seg=6, rings=4, m=fm)
    b.sphere((x, y, h + 0.03), (0.03, 0.03, 0.03), seg=6, rings=4, m=flower_b)
for i in range(5):
    a = rn.uniform(0, 6.28)
    blade(b, (math.cos(a) * 0.1, math.sin(a) * 0.1), 0.35, a, w=0.05, m=leaf_green)
b.build(parent=r)
publish(r, "flowers.glb")

# ---------------- ROCKS (neutral grey; tinted in-engine per biome)
for nm, seed, sc, jit in (("rock_a", 1, (1.4, 1.1, 0.9), 0.28), ("rock_b", 2, (1.0, 1.6, 1.2), 0.22), ("rock_c", 3, (2.2, 1.7, 1.4), 0.3)):
    r = new(nm)
    b = MB(nm + "_m")
    b.sphere((0, 0, sc[2] * 0.55), sc, seg=8, rings=5, m=rock_grey, smooth=False, jitter=jit, seed=seed)
    if nm == "rock_c":
        b.sphere((1.5, 0.6, 0.5), (0.8, 0.7, 0.6), seg=7, rings=4, m=rock_grey, smooth=False, jitter=0.3, seed=9)
    b.build(parent=r)
    publish(r, nm + ".glb")

r = new("rock_spire")
b = MB("rock_spire_m")
b.cyl((0, 0, 3.5), 1.4, 0.25, 7.0, seg=7, m=rock_grey, smooth=False)
b.cyl((1.2, 0.5, 2.0), 0.9, 0.2, 4.0, seg=6, rot=(8, -6, 0), m=rock_grey, smooth=False)
b.cyl((-1.0, -0.5, 1.5), 0.8, 0.15, 3.0, seg=6, rot=(-6, 8, 0), m=rock_grey, smooth=False)
b.build(parent=r)
publish(r, "rock_spire.glb")

r = new("rock_arch")
b = MB("rock_arch_m")
b.cyl((-3.2, 0, 3.0), 1.6, 1.1, 6.0, seg=8, m=rock_grey, smooth=False)
b.cyl((3.2, 0, 3.0), 1.6, 1.1, 6.0, seg=8, m=rock_grey, smooth=False)
b.box((0, 0, 6.2), (9.5, 2.6, 1.8), m=rock_grey, taper=(0.9, 0.9))
b.sphere((0, 0, 6.8), (3.6, 1.3, 0.9), seg=8, rings=4, m=rock_grey, smooth=False, jitter=0.1, seed=3)
b.build(parent=r)
publish(r, "rock_arch.glb", azim=-20, elev=10)

# ---------------- DESERT
r = new("cactus")
b = MB("cactus_m")
b.lathe([(0.01, 0), (0.45, 0.1), (0.5, 1.0), (0.45, 3.2), (0.28, 3.9), (0.0, 4.1)], seg=10, m=cactus_m)
b.cyl((0.9, 0, 2.0), 0.28, 0.26, 1.5, seg=8, m=cactus_m, rot=(0, 90, 0))
b.cyl((1.5, 0, 2.9), 0.26, 0.2, 1.8, seg=8, m=cactus_m)
b.sphere((1.5, 0, 3.85), (0.2, 0.2, 0.2), seg=8, rings=4, m=cactus_m)
b.cyl((-0.85, 0, 1.4), 0.26, 0.24, 1.3, seg=8, m=cactus_m, rot=(0, -90, 0))
b.cyl((-1.4, 0, 2.1), 0.23, 0.18, 1.5, seg=8, m=cactus_m)
b.sphere((-1.4, 0, 2.88), (0.18, 0.18, 0.18), seg=8, rings=4, m=cactus_m)
b.sphere((0, 0, 4.1), (0.4, 0.4, 0.15), seg=8, rings=4, m=flower_a)
b.build(parent=r)
publish(r, "cactus.glb")

r = new("dead_tree")
b = MB("dead_tree_m")
b.lathe([(0.4, 0), (0.32, 1.5), (0.2, 3.0), (0.06, 4.2)], seg=7, m=bark_pale)
for (z, ang, ln) in ((2.2, 50, 1.8), (3.0, -55, 1.5), (3.6, 20, 1.1), (1.6, -60, 1.2)):
    b.cyl((math.sin(math.radians(ang)) * ln * 0.45, 0, z + math.cos(math.radians(ang)) * ln * 0.45), 0.09, 0.03, ln, seg=5, rot=(0, ang, 0), m=bark_pale)
b.build(parent=r)
publish(r, "dead_tree.glb")

# ---------------- FROZEN
r = new("ice_crystals")
b = MB("ice_crystals_m")
rn = random.Random(7)
for i in range(7):
    a = rn.uniform(0, 6.28)
    d = 0.0 if i == 0 else rn.uniform(0.5, 1.3)
    h = rn.uniform(2.5, 5.0) if i == 0 else rn.uniform(1.0, 3.0)
    tilt = 0 if i == 0 else rn.uniform(10, 35)
    w = h * 0.12
    x, y = math.cos(a) * d, math.sin(a) * d
    b.cyl((x, y, h / 2 - 0.1), w, 0.01, h, seg=6, rot=(tilt * math.sin(a), -tilt * math.cos(a), 0), m=ice_m, smooth=False)
b.build(parent=r)
publish(r, "ice_crystals.glb")

r = new("snow_pine")
b = MB("snow_pine_m")
b.lathe([(0.3, 0), (0.25, 1.5), (0.1, 2.6)], seg=8, m=bark)
for i, (z, rad, h) in enumerate([(1.2, 2.0, 2.2), (2.5, 1.6, 2.0), (3.7, 1.2, 1.8), (4.8, 0.8, 1.6)]):
    b.cyl((0, 0, z + h / 2), rad, 0.02, h, seg=8, m=snow_white, smooth=False)
    b.cyl((0, 0, z + h * 0.38), rad * 0.9, 0.02, h * 0.8, seg=8, m=leaf_pine, smooth=False, caps=False)
b.build(parent=r)
publish(r, "snow_pine.glb")

# ---------------- VOLCANIC
r = new("obsidian_spikes")
b = MB("obsidian_spikes_m")
rn = random.Random(13)
for i in range(6):
    a = rn.uniform(0, 6.28)
    d = 0.0 if i == 0 else rn.uniform(0.6, 1.6)
    h = rn.uniform(3.5, 6.0) if i == 0 else rn.uniform(1.2, 3.5)
    tilt = 0 if i == 0 else rn.uniform(8, 28)
    x, y = math.cos(a) * d, math.sin(a) * d
    b.cyl((x, y, h / 2 - 0.1), h * 0.18, 0.01, h, seg=5, rot=(tilt * math.sin(a), -tilt * math.cos(a), 0), m=obsidian, smooth=False)
b.cyl((0, 0, 0.1), 0.9, 0.5, 0.25, seg=7, m=lava_glow, smooth=False)
b.build(parent=r)
publish(r, "obsidian_spikes.glb")

r = new("lava_vent")
b = MB("lava_vent_m")
b.lathe([(3.4, 0.0), (2.4, 1.2), (1.5, 2.1), (1.2, 2.2)], seg=12, m=obsidian, smooth=True)
b.cyl((0, 0, 2.18), 1.15, 1.15, 0.06, seg=12, m=lava_glow, caps=True)
b.sphere((0, 0, 1.9), (0.5, 0.5, 0.2), seg=8, rings=4, m=lava_glow)
b.build(parent=r)
publish(r, "lava_vent.glb")

# ---------------- TOXIC
r = new("mushroom_giant")
b = MB("mushroom_giant_m")
b.lathe([(0.55, 0), (0.4, 1.0), (0.32, 3.0), (0.35, 4.2)], seg=10, m=mush_stem)
b.lathe([(0.35, 4.0), (1.4, 4.2), (2.6, 4.8), (3.0, 5.4), (2.4, 6.0), (1.2, 6.4), (0.0, 6.5)], seg=14, m=mush_cap)
b.lathe([(0.35, 4.0), (1.2, 4.1), (2.4, 4.7)], seg=14, m=leaf_pink, smooth=True)
for i in range(7):
    a = 2 * math.pi * i / 7
    b.sphere((math.cos(a) * 1.5, math.sin(a) * 1.5, 6.0 - 0.1 * (i % 2)), (0.28, 0.28, 0.12), seg=7, rings=4, m=bio_glow)
b.build(parent=r)
publish(r, "mushroom_giant.glb")

r = new("spore_bulb")
b = MB("spore_bulb_m")
b.lathe([(0.2, 0), (0.12, 1.0), (0.1, 2.0)], seg=7, m=stem_m)
b.sphere((0, 0, 2.5), (0.55, 0.55, 0.7), seg=10, rings=7, m=bio_glow)
for i in range(4):
    a = 2 * math.pi * i / 4
    b.cyl((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.7), 0.06, 0.03, 1.4, seg=5, rot=(math.sin(a) * 30, -math.cos(a) * 30, 0), m=stem_m)
b.build(parent=r)
publish(r, "spore_bulb.glb")

r = new("tentacle_plant")
b = MB("tentacle_plant_m")
rn = random.Random(3)
for i in range(7):
    a = rn.uniform(0, 6.28)
    ln = rn.uniform(1.8, 3.2)
    ang = rn.uniform(10, 40)
    pts = []
    rings = []
    for k in range(6):
        t = k / 5
        rad = 0.14 * (1 - t) + 0.02
        cx = math.cos(a) * (t * ln * math.sin(math.radians(ang)) + 0.15 * t * t * ln)
        cy = math.sin(a) * (t * ln * math.sin(math.radians(ang)) + 0.15 * t * t * ln)
        cz = t * ln * math.cos(math.radians(ang))
        rings.append([Vector((cx + math.cos(q * 6.283 / 6) * rad, cy + math.sin(q * 6.283 / 6) * rad, cz)) for q in range(6)])
    b.loft(rings, m=mush_cap, close_start=False, close_end=True)
    b.sphere(rings[-1][0] + Vector((0, 0, 0.05)), (0.09, 0.09, 0.09), seg=6, rings=4, m=bio_glow)
b.build(parent=r)
publish(r, "tentacle_plant.glb")

# ---------------- RESOURCES
r = new("resource_crystal")
b = MB("resource_crystal_m")
rn = random.Random(21)
for i in range(5):
    a = rn.uniform(0, 6.28)
    d = 0.0 if i == 0 else rn.uniform(0.25, 0.5)
    h = rn.uniform(1.1, 1.6) if i == 0 else rn.uniform(0.5, 1.0)
    tilt = 0 if i == 0 else rn.uniform(10, 30)
    x, y = math.cos(a) * d, math.sin(a) * d
    b.cyl((x, y, h / 2 - 0.05), h * 0.16, 0.01, h, seg=6, rot=(tilt * math.sin(a), -tilt * math.cos(a), 0), m=crystal_m, smooth=False)
b.sphere((0, 0, 0.08), (0.55, 0.55, 0.18), seg=8, rings=4, m=rock_dark, smooth=False, jitter=0.2, seed=5)
b.build(parent=r)
publish(r, "resource_crystal.glb")

r = new("ore_node")
b = MB("ore_node_m")
b.sphere((0, 0, 0.7), (1.1, 0.95, 0.8), seg=8, rings=5, m=rock_dark, smooth=False, jitter=0.22, seed=8)
for i in range(6):
    a = 2 * math.pi * i / 6 + 0.3
    b.box((math.cos(a) * 0.75, math.sin(a) * 0.65, 0.85 + 0.1 * (i % 3)), (0.28, 0.2, 0.3), rot=(10 * i, 20 * i, 30 * i), m=ore_vein)
b.build(parent=r)
publish(r, "ore_node.glb")

print("flora done")
