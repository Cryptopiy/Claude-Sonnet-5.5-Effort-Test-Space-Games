import sys, importlib, math
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import flora1_lib as F; importlib.reload(F)
import bmesh
from flora1_lib import Vector, Matrix, noise, Z, X, Y

ID = "floating_rock_a"
col = F.new_collection(ID)
mats = [
    F.M(ID + "_rock", "#7b7387", rough=0.9),
    F.M(ID + "_grass", "#43bd4a", rough=0.75),
    F.M(ID + "_leaf", "#1d7a45", rough=0.7),
    F.M(ID + "_root", "#6b4a35", rough=0.95),
    F.M(ID + "_crystal", "#5f7dff", rough=0.1, emit="#4a6bff", emit_strength=2.5, alpha=0.6, spec=0.5),
    F.M(ID + "_core", "#e8f0ff", rough=0.3, emit="#b7c9ff", emit_strength=6.0),
]
ROCK, GRASS, LEAF, ROOT, CRYS, CORE = range(6)
b = F.Builder(mats, seed=55)
b.flat = {CRYS, CORE}
rng = b.rng

# ---- island body: inverted-cone rock with a plateau ----------------------------------------------------------------------------
bm = b.bm
res = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
verts = res["verts"]
R = 3.0
ZMID = 4.0
for v in verts:
    u = v.co.copy()
    z = u.z
    n1 = noise.noise(u * 1.6 + Vector((5, 3, 1))) + 0.5 * noise.noise(u * 3.7 + Vector((2, 9, 4)))
    amt = 0.14 + (0.3 if z < 0 else 0.0)
    if z < 0:
        s = (1.0 + z) ** 0.4
        zz = ZMID + z * 2.75
    else:
        s = 1.0
        zz = ZMID + z * 0.5
        if z > 0.3:
            zz = ZMID + 0.15 + (z - 0.3) * 0.1
    x = u.x * R * s * (1.0 + amt * n1)
    y = u.y * R * s * (1.0 + amt * n1)
    zz = zz + 0.4 * n1 * (1.0 if z < 0.2 else 0.15)
    v.co = Vector((x, y, zz))
faces = set()
for v in verts:
    for f in v.link_faces:
        faces.add(f)
for f in faces:
    f.normal_update()
    f.material_index = ROCK
under = [(v.co.copy(), (v.co - Vector((0, 0, ZMID + 0.5))).normalized()) for v in verts if v.co.z < ZMID - 0.4]

# grass cap
b.blob((0, 0, ZMID + 0.2), (R * 0.97, R * 0.97, 0.3), subdiv=3, amt=0.1, freq=1.8, seed=6, mat=GRASS, flat_bottom=0.9)
TOP = ZMID + 0.45

# ---- hanging roots -------------------------------------------------------------------------------------------------------------
cands = [(p, n) for (p, n) in under if p.z < ZMID - 0.9]
rng.shuffle(cands)
root_tips = []
for (p, n) in cands[:11]:
    out = Vector((p.x, p.y, 0)).normalized() if (abs(p.x) + abs(p.y)) > 1e-3 else Vector((1, 0, 0))
    d = (out * 0.25 + Vector((0, 0, -1))).normalized()
    ln = rng.uniform(1.8, 3.0)
    end, ed, info = b.branch(p + Vector((0, 0, 0.1)), d, ln, 0.17, 0.015, bend=(0, 0, -1), bend_amt=0.25, wobble=0.22, steps=6, segs=5,
                             mat=ROOT, nz=0.15, nf=2.5, seed=int(p.x * 10),
                             curl=(Vector((0, 0, 1)), rng.choice((-1, 1)) * rng.uniform(0.5, 1.4)))
    root_tips.append(end)
    for k in range(2):
        q = info.pts[2 + k * 2]
        sd = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), -0.5)).normalized()
        b.branch(q, sd, rng.uniform(0.4, 0.8), 0.035, 0.008, bend=(0, 0, -1), bend_amt=0.2, wobble=0.15, steps=3, segs=4, mat=ROOT, seed=k)
for end in root_tips[:4]:
    b.blob(end - Vector((0, 0, 0.04)), (0.08, 0.08, 0.1), subdiv=1, amt=0.0, mat=CORE)


# ---- crystals (translucent with glowing cores) ----------------------------------------------------------------------------------
def crystal_cluster(cx, cy, n, lmin, lmax, spread):
    for i in range(n):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, spread)
        base = Vector((cx + math.cos(a) * rr, cy + math.sin(a) * rr, TOP - 0.15))
        tilt = Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 1.0)).normalized()
        ln = rng.uniform(lmin, lmax)
        rad = 0.11 + 0.1 * (ln / lmax)
        b.crystal(base, tilt, ln, rad, sides=6, tip=0.3, mat=CRYS, seed=i + int(cx * 10))
        b.crystal(base + tilt * 0.05, tilt, ln * 0.82, rad * 0.3, sides=4, tip=0.3, mat=CORE, cap0=False, seed=i + 40)


crystal_cluster(1.1, 0.5, 6, 0.9, 2.4, 0.6)
crystal_cluster(-1.2, -0.9, 4, 0.5, 1.3, 0.45)

# ---- bushes and grass tufts on top --------------------------------------------------------------------------------------------------
for i, (bx, by, br) in enumerate(((-1.1, 0.9, 0.62), (0.0, -1.6, 0.5), (1.7, -0.9, 0.42))):
    b.canopy_cluster((bx, by, TOP + br * 0.45), br, (LEAF, LEAF, GRASS), seed=i + 70, subdiv=2, squash=0.9, amt=0.25, freq=1.4, n_sat=1,
                     sat_scale=(0.55, 0.7), n_fringe=4, n_top=5, fringe_zmin=-0.1, fringe_down=0.1, leaf_len=(0.3, 0.5), leaf_w=0.55,
                     flat_bottom=0.8, droop=0.25)
for i in range(6):
    a = rng.uniform(0, math.tau)
    rr = rng.uniform(0.6, 2.4)
    cx, cy = math.cos(a) * rr, math.sin(a) * rr
    for k in range(7):
        aa = rng.uniform(0, math.tau)
        h = rng.uniform(0.3, 0.55)
        lean = rng.uniform(0.05, 0.28)
        la = aa + rng.uniform(-0.5, 0.5)
        pts = [Vector((cx + math.cos(aa) * 0.05 + math.cos(la) * lean * t ** 1.8,
                       cy + math.sin(aa) * 0.05 + math.sin(la) * lean * t ** 1.8,
                       TOP - 0.05 + h * (t - 0.1 * t ** 3))) for t in (0.0, 0.5, 1.0)]
        b.ribbon(pts, (0.04, 0.01), normal_hint=Vector((math.cos(la + 1.2), math.sin(la + 1.2), 0)), mat=GRASS)

b.ground(0.0)
ob = b.finish(ID + "_mesh", col, flat_mats=(CRYS, CORE))
info = F.publish(ID, [ob], "flora", ["exotic"],
                 {"shape": "cylinder", "radius": 2.8, "height": 3.0, "offset_y": 2.5},
                 tintable=["grass", "leaf", "crystal"],
                 notes="Origin = lowest point (root tips) at z=0 directly under the island centre; the island itself floats ~1-3 m above (the game should hover it: y_offset as needed). ~6 m wide, ~6 m tall incl. crystals. Collider cylinder spans y = 2.5 .. 5.5 (the rock mass); crystals/roots have no collider. Materials: rock, grass, leaf, root, crystal (translucent, emissive 2.5), core (emissive 6).")
print(info)
