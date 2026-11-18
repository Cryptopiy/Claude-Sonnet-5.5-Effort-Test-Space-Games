"""satellite (brief 3): derelict comms satellite ~8 m wide: gold-foil bus with white / dark modules and scorch marks, big dented dish on a mast,
two solar wings (one with a bent panel, one torn), whip antennas, a small side dish, thruster block with a nozzle, one dim red lamp.
Single mesh 'Body', origin = centre of the bus (the game spins it about a random axis).  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

palette()
NAME = 'satellite'
coll = fresh_collection(NAME)
FG = mat('Foil_Gold', '#C99A3C', metal=0.85, rough=0.32)
SCH = mat('Scorch', '#2A2522', metal=0.3, rough=0.85)
HP, HD, MT, SOL, SOLG, ER = 'Hull_Paint', 'Hull_Dark', 'Metal', 'Solar_Cell', 'Solar_Grid', 'Emissive_NavRed'
FGN, SCHN = 'Foil_Gold', 'Scorch'
mb = MB(NAME)
rng = random.Random(3)


def box(size, c, mat_, bevel=0.0, rot=None):
    return mb.rbox(size, center=c, rot=rot, bevel=bevel, bsegs=1, mat=mat_, smooth=False)


def dish(center, axis, R=1.3, depth=0.38, t=0.1, segs=18, mat_=HP, inner=MT):
    ks = [0.0, 0.27, 0.53, 0.78, 1.0]
    prof = [(R * k, depth * k * k, inner) for k in ks] + [(R, depth - t * 0.4, mat_)] + [(R * k, depth * k * k - t, mat_) for k in reversed(ks[:-1])]
    return mb.lathe_mats(prof, segs, MB.xf(center, MB.aim(axis)))


# ---- bus: gold foil core, white top module, dark bottom module, bands, scorch patches ----------------------------------
box((1.6, 1.6, 1.7), (0, 0, 0.0), FGN, 0.07)
box((1.7, 1.7, 0.45), (0, 0, 1.05), HP, 0.05)
box((1.7, 1.7, 0.4), (0, 0, -1.05), HD, 0.05)
for z in (0.42, -0.42):
    box((1.66, 1.66, 0.06), (0, 0, z), HD)
box((0.05, 1.1, 0.8), (0.82, 0.1, 0.25), SCHN)
box((1.0, 0.05, 0.7), (-0.2, 0.82, -0.2), SCHN)
box((0.05, 0.7, 1.0), (-0.82, -0.2, 0.4), SCHN)
for sx in (-1, 1):
    box((0.04, 0.5, 0.5), (sx * 0.83, -0.3, -0.35), HP)
    box((0.04, 0.8, 0.12), (sx * 0.83, 0.2, -0.55), MT)
# thruster block + nozzle
mb.cyl(0.42, 0.5, center=(0, 0, -1.6), segs=10, mat=HD, r2=0.2)
mb.cyl(0.22, 0.12, center=(0, 0, -1.9), segs=10, mat=MT, r2=0.3)
for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
    box((0.14, 0.14, 0.26), (sx * 0.72, sy * 0.72, -1.15), MT, 0.02)

# ---- dish on a mast (dented: tilted rim) ---------------------------------------------------------------------------------
mb.cyl(0.07, 1.0, center=(0.1, 0.0, 1.75), segs=6, mat=MT)
box((0.3, 0.3, 0.2), (0.1, 0.0, 2.2), HD, 0.03)
adir = Vector((0.25, 0.8, 0.55)).normalized()
dc = Vector((0.1, 0.0, 2.4))
dish(dc, adir)
for k in range(3):
    a = TAU * k / 3 + 0.5
    perp1 = adir.cross(Vector((0, 0, 1))).normalized()
    perp2 = adir.cross(perp1).normalized()
    p0 = dc + (perp1 * math.cos(a) + perp2 * math.sin(a)) * 1.1 + adir * 0.3
    mb.tube([p0, dc + adir * 0.95], [0.025, 0.02], segs=4, mat=MT)
mb.cyl(0.07, 0.3, center=dc + adir * 0.95, segs=6, mat=HD, rot=MB.aim(adir))
mb.sphere(0.1, center=dc + adir * 1.12, segs=6, mat=MT)
# side dish + whip antennas
dish(Vector((-0.95, -0.2, -0.3)), Vector((-1.0, -0.1, 0.1)), R=0.5, depth=0.14, t=0.05, segs=10)
mb.tube([(-0.8, -0.2, -0.3), (-0.95, -0.2, -0.3)], [0.04, 0.04], segs=5, mat=MT)
mb.tube([(0.5, 0.5, 1.28), (0.7, 0.7, 3.4), (0.95, 0.9, 5.0)], [0.035, 0.022, 0.012], segs=4, mat=MT)
mb.sphere(0.06, center=(0.95, 0.9, 5.0), segs=5, mat=MT)
mb.tube([(-0.6, -0.5, 1.28), (-0.7, -0.6, 2.6)], [0.03, 0.02], segs=4, mat=MT)
mb.tube([(0.6, -0.55, 1.28), (1.6, -1.6, 2.2), (2.5, -2.2, 2.6)], [0.03, 0.02, 0.008], segs=4, mat=MT)      # bent whip
mb.sphere(0.1, center=(0.0, 0.83, 0.9), segs=6, mat=ER)


# ---- solar wings: left = flat + bent panel, right = flat + torn stub --------------------------------------------------------
def panel(M, w=1.6, h=2.4, torn=False):
    def pb(size, c, m_, bevel=0.0):
        box(size, M @ Vector(c), m_, bevel, rot=M.to_3x3())
    if torn:
        w2 = w * 0.55
        pb((w2, 0.05, h), (-w * 0.5 + w2 / 2 + w / 2 - w / 2, 0, 0), SOL)
        pb((w2, 0.07, 0.07), (-w * 0.5 + w2 / 2 + w / 2 - w / 2, 0, h / 2 - 0.03), MT)
        pb((w2, 0.07, 0.07), (-w * 0.5 + w2 / 2 + w / 2 - w / 2, 0, -h / 2 + 0.03), MT)
        pb((0.07, 0.07, h), (-w * 0.5 + w2 / 2 + w / 2 - w / 2 - w2 / 2 + 0.03, 0, 0), MT)
        pb((0.3, 0.05, 0.5), (w2 * 0.9, 0, h * 0.18), SOL)             # a dangling shard
        return
    pb((w, 0.05, h), (0, 0, 0), SOL)
    pb((w + 0.06, 0.08, 0.07), (0, 0, h / 2), MT)
    pb((w + 0.06, 0.08, 0.07), (0, 0, -h / 2), MT)
    pb((0.07, 0.08, h), (-w / 2, 0, 0), MT)
    pb((0.07, 0.08, h), (w / 2, 0, 0), MT)
    pb((0.045, 0.07, h - 0.1), (0, 0, 0), SOLG)
    pb((w - 0.1, 0.07, 0.045), (0, 0, 0), SOLG)


W = 1.6
for sx in (-1, 1):
    mb.cyl(0.07, 2.7, center=(sx * 2.25, 0, 0), segs=6, mat=MT, rot=MB.aim((1, 0, 0)))
    box((0.5, 0.4, 0.4), (sx * 1.0, 0, 0), HD, 0.04)
# left wing (-X)
M1 = Matrix.Translation((-1.4 - W / 2, 0, 0))
panel(M1, W)
hinge = Vector((-1.4 - W - 0.08, 0, 0))
M2 = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(-38.0), 4, 'Z') @ Matrix.Translation((-W / 2, 0, 0))
panel(M2, W)
mb.cyl(0.05, 2.5, center=hinge, segs=5, mat=MT)
# right wing (+X)
M3 = Matrix.Translation((1.4 + W / 2, 0, 0))
panel(M3, W)
hinge2 = Vector((1.4 + W + 0.08, 0, 0))
M4 = Matrix.Translation(hinge2) @ Matrix.Rotation(math.radians(-62.0), 4, 'Z')
panel(Matrix.Translation(hinge2) @ Matrix.Rotation(math.radians(-62.0), 4, 'Z') @ Matrix.Translation((W / 2, 0, 0)), W, torn=True)
mb.cyl(0.05, 2.5, center=hinge2, segs=5, mat=MT)
mb.tube([hinge2 + Vector((0.6, 0.6, 0.9)), hinge2 + Vector((1.6, 1.9, 1.2)), hinge2 + Vector((2.0, 2.6, 0.5))], [0.02, 0.018, 0.012], segs=4, mat=HD)   # loose cable

ob = mb.finish('Body', coll, smooth_angle=38, weighted=True)
nature_check(NAME, budget=3000)
park(NAME)
print('built', NAME)
