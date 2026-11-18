import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise

ID = "exotic_fan_plant_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_stem", "#6a2fa3", rough=0.6),
    F.M(ID + "_leaf", "#10d6b6", rough=0.5),
    F.M(ID + "_leaf_b", "#0b8fc4", rough=0.5),
    F.M(ID + "_edge", "#ff2f8e", rough=0.45, emit="#ff3d9a", emit_strength=2.0),
    F.M(ID + "_glow", "#ffc02e", rough=0.4, emit="#ffb020", emit_strength=4.0),
]
STEM, LEAF, LEAFB, EDGE, GLOW = range(5)
b = F.Builder(mats, seed=44)
b.flat = {LEAF, LEAFB, EDGE}
rng = b.rng


def fan(base, d, R, spread=math.radians(78), pleats=7, rows=4, amp=0.12, droop=0.32, cup=0.18):
    d = Vector(d).normalized()
    s = d.cross(Vector((0, 0, 1)))
    if s.length < 1e-3:
        s = Vector((1, 0, 0))
    s.normalize()
    n = s.cross(d).normalized()
    cols = pleats * 2 + 1
    grid = []
    fr = (0.0, 0.3, 0.62, 0.86, 1.0)
    for i in range(rows + 1):
        r = R * fr[i]
        row = []
        for j in range(cols):
            th = -spread + 2 * spread * j / (cols - 1)
            rr = r
            if i == rows:
                rr = r * (0.9 + 0.1 * (1 if j % 2 == 0 else 0.0)) * (1.0 - 0.1 * abs(th) / spread)
            pos = base + d * (rr * math.cos(th)) + s * (rr * math.sin(th))
            k = rr / R
            pos += n * (amp * k * (1 if j % 2 == 0 else -1))        # accordion folds
            pos -= n * (droop * R * k * k)                           # tip droop
            pos += n * (cup * R * k * k * (abs(th) / spread) ** 2)   # edges curl up a bit
            row.append(pos)
        grid.append(row)

    def matfn(i, j):
        if i == rows - 1:
            return EDGE
        return LEAF if j % 2 == 0 else LEAFB
    b.surface(grid, double=True, matfn=matfn)


# ---- bulb base ---------------------------------------------------------------------------------------------------------
b.blob((0, 0, 0.36), (0.6, 0.6, 0.5), subdiv=2, amt=0.22, freq=1.2, seed=3, mat=STEM, flat_bottom=0.6)

# ---- petioles + fans ----------------------------------------------------------------------------------------------------
specs = []
for i in range(3):
    specs.append((i * 2.094 + 0.2, 3.6, 10 + rng.uniform(0, 8), 1.7, 0.4))
for i in range(3):
    specs.append((i * 2.094 + 1.1, 3.0, 24 + rng.uniform(0, 8), 2.0, 0.4))
for i in range(4):
    specs.append((i * 1.571 + 0.55 + rng.uniform(-0.15, 0.15), 2.4, 40 + rng.uniform(0, 8), 2.1, 0.35))
for (a, L_, psi1, R, z0) in specs:
    psi0 = math.radians(8)
    p1 = math.radians(psi1)
    steps = 7
    p = Vector((math.cos(a) * 0.1, math.sin(a) * 0.1, z0))
    pts = [p.copy()]
    for k in range(steps):
        t = (k + 0.5) / steps
        psi = psi0 + (p1 - psi0) * (t ** 1.4)
        dv = Vector((math.sin(psi) * math.cos(a), math.sin(psi) * math.sin(a), math.cos(psi)))
        p = p + dv * (L_ / steps)
        pts.append(p.copy())
    b.tube(pts, (0.085, 0.04), segs=6, mat=STEM, cap1=True, nz=0.0)
    dend = Vector((math.sin(p1) * math.cos(a), math.sin(p1) * math.sin(a), math.cos(p1)))
    fan(pts[-1] - dend * 0.05, dend, R)

# ---- glowing bloom spike ------------------------------------------------------------------------------------------------
sp = F.spline([(0, 0, 0.4), (0.12, 0.05, 1.9), (-0.05, 0.1, 3.6), (0.05, 0.0, 5.2)], 5)
b.tube(sp, (0.065, 0.03), segs=6, mat=STEM, cap1=True)
b.blob(sp[-1] + Vector((0, 0, 0.12)), (0.2, 0.2, 0.32), subdiv=2, amt=0.1, seed=9, mat=GLOW)
for i in range(3):
    a = i * 2.09 + 0.7
    q0 = sp[int(len(sp) * 0.72)]
    q1 = q0 + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.35))
    tpts = F.spline([q0, q0.lerp(q1, 0.5) + Vector((0, 0, 0.1)), q1], 3)
    b.tube(tpts, (0.02, 0.012), segs=5, mat=STEM, cap1=True)
    b.blob(q1 + Vector((0, 0, 0.06)), 0.1, subdiv=2, amt=0.1, seed=20 + i, mat=GLOW)

ob = b.finish(ID + "_mesh", col, flat_mats=(LEAF, LEAFB, EDGE))
info = F.publish(ID, [ob], "flora", ["exotic"],
                 {"shape": "cylinder", "radius": 0.6, "height": 3.0, "offset_y": 0.0},
                 tintable=["leaf", "edge"],
                 notes="Origin at the bulb base. 10 giant accordion-folded fan leaves (flat shaded, two-sided) on purple petioles; teal/blue stripes with emissive magenta rim (edge), glowing orange bloom spike (glow, emissive 4.0) poking ~0.4 m above the leaf crown. Leaf crown ~5.4 m, total ~5.6 m tall, ~5.3 m wide.")
print(info)
