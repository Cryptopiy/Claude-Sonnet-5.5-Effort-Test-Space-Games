import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "coral_rock_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_rock", "#8593a0", rough=0.92),
    F.M(ID + "_rock_dark", "#4a5868", rough=0.95),
    F.M(ID + "_coral_a", "#ff6a3a", rough=0.55),
    F.M(ID + "_coral_b", "#ff4f95", rough=0.55),
    F.M(ID + "_coral_c", "#8a5cff", rough=0.5),
    F.M(ID + "_glow", "#a6fbff", rough=0.35, emit="#6fe9ff", emit_strength=2.6),
]
ROCK, ROCKD, CA, CB, CC, GLOW = range(6)
b = F.Builder(mats, seed=26)
rng = b.rng


def rock_mat(nrm, ctr):
    return ROCKD if (ctr.z < 0.28 or nrm.z < -0.2) else ROCK


# ---- rock mass ---------------------------------------------------------------------------------------------------------------------
v_main = b.blob((0, 0, 0.45), (1.15, 0.95, 0.55), subdiv=3, amt=0.32, freq=1.2, seed=3, matfn=rock_mat, flat_bottom=0.65)
v2 = b.blob((0.95, -0.65, 0.25), (0.6, 0.5, 0.32), subdiv=2, amt=0.3, freq=1.5, seed=8, matfn=rock_mat, flat_bottom=0.6)
v3 = b.blob((-0.95, 0.55, 0.22), (0.55, 0.45, 0.3), subdiv=2, amt=0.3, freq=1.5, seed=12, matfn=rock_mat, flat_bottom=0.6)
tops = [(p, n) for (p, n) in v_main if n.z > 0.35 and p.z > 0.5]
sides = [(p, n) for (p, n) in v_main if 0.0 < n.z < 0.45 and p.z > 0.2]
tops2 = [(p, n) for (p, n) in v2 if n.z > 0.35]
tops3 = [(p, n) for (p, n) in v3 if n.z > 0.35]


def stag(start, d, length, r0, depth, mat_idx, nbranch=2):
    end, ed, info = b.branch(start, d, length, r0, r0 * 0.62, bend=(0, 0, 1), bend_amt=0.18, wobble=0.18, steps=2, segs=4, mat=mat_idx, cap1=True)
    if depth > 0:
        for j in range(nbranch):
            jit = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1)))
            nd = (ed * 1.0 + jit * 0.85).normalized()
            stag(end - ed * 0.03, nd, length * 0.74, r0 * 0.62, depth - 1, mat_idx, nbranch)
    else:
        b.blob(end + ed * 0.02, (r0 * 0.7), subdiv=1, amt=0.0, mat=GLOW)


# staghorn corals
for (src, mi, nb) in ((tops, CA, 2), (tops, CB, 2), (tops, CA, 2), (tops2, CB, 2), (tops3, CA, 2), (sides, CB, 2), (sides, CA, 2), (sides, CB, 2)):
    p, n = rng.choice(src)
    d = (n * 0.8 + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.7))).normalized()
    stag(p - n * 0.05, d, rng.uniform(0.6, 0.85), 0.09, 2, mi, nb)

# brain coral dome
p, n = rng.choice([t for t in tops if abs(t[0].x) < 0.9])
b.blob(p + Vector((0, 0, 0.12)), (0.5, 0.44, 0.34), subdiv=3, amt=0.11, freq=7.0, seed=5, mat=CC, flat_bottom=0.4, oct2=0.7)

# tube corals
cx, cy = -0.3, -0.45
for i in range(9):
    a = rng.uniform(0, math.tau)
    rr = rng.uniform(0.0, 0.2)
    base = Vector((cx + math.cos(a) * rr, cy + math.sin(a) * rr, 0.62 + rng.uniform(-0.05, 0.1)))
    h = rng.uniform(0.35, 0.8)
    top = base + Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), h))
    b.tube([base, base.lerp(top, 0.5), top], (0.075, 0.095), segs=6, mat=CC if i % 3 else CB, cap0=False, cap1=True, nz=0.05, nf=5.0, seed=i)
    b.blob(top + Vector((0, 0, 0.005)), (0.062, 0.062, 0.03), subdiv=1, amt=0.0, mat=GLOW)

# sea fan
fb = Vector((0.2, 0.45, 0.72))
fd = Vector((0.0, 0.2, 1.0)).normalized()
s_ax = Vector((1, 0, 0))
grid = []
fr = (0.0, 0.3, 0.6, 0.85, 1.0)
for i in range(5):
    row = []
    for j in range(13):
        th = -math.radians(70) + math.radians(140) * j / 12.0
        r = 1.0 * fr[i]
        if i == 4:
            r *= (0.93 + 0.07 * (1 if j % 2 == 0 else 0))
        pos = fb + fd * (r * math.cos(th)) + s_ax * (r * math.sin(th)) + Vector((0, 1, 0)) * (0.04 * (1 if j % 2 == 0 else -1) * fr[i])
        row.append(pos)
    grid.append(row)
b.surface(grid, double=True, matfn=lambda i, j: CB if (j % 2 == 0) else CC)

b.ground(0.0)
ob = b.finish(ID + "_mesh", col)
info = F.publish(ID, [ob], "flora", ["ocean"],
                 {"shape": "box", "size": [2.5, 1.1, 2.1], "offset_y": 0.0},
                 tintable=["coral"],
                 notes="Origin at ground centre. Blue-grey rock (rock, rock_dark) with branching staghorn corals (coral_a orange, coral_b pink), brain coral and tube corals / sea fan (coral_c purple) and small emissive cyan polyps/tips (glow 2.6). ~3 m wide, ~2 m high. Collider: use sphere/box around the rock mass.")
print(info)
