import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy, bmesh
from mathutils import Vector, Matrix

ID = "drop_pod_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
TAU = math.tau
rnd = random.Random(909)


def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)


M = S.mats(ID, {
    "hull": dict(color=(0.48, 0.48, 0.46), metallic=0.15, roughness=0.5),
    "burnt": dict(color=(0.05, 0.04, 0.035), metallic=0.5, roughness=0.65),
    "accent": "orange",
    "steel": dict(color=(0.17, 0.18, 0.20), metallic=0.8, roughness=0.45),
    "lamp": "window_warm",
    "glow": "emit_cyan",
    "dirt": dict(color=(0.07, 0.055, 0.042), metallic=0.0, roughness=1.0),
    "chute_o": dict(color=(0.85, 0.22, 0.02), metallic=0.0, roughness=0.95),
    "chute_w": dict(color=(0.52, 0.51, 0.47), metallic=0.0, roughness=0.95),
})
Mblink = S.mats(ID, {"blink": "emit_red"})
Mlamp = S.mats(ID, {"ilight": dict(color=(0.4, 0.3, 0.1), emission=(1.0, 0.75, 0.35), emission_strength=4.0, roughness=0.4)})


def quad_out(mb, p0, p1, p2, p3, outward, mat):
    n = (p1 - p0).cross(p3 - p0)
    if n.dot(outward) < 0:
        mb.quad(p0, p3, p2, p1, mat=mat)
    else:
        mb.quad(p0, p1, p2, p3, mat=mat)


# ================================================== pod body (upright, local frame; tilted by the parent empty) ===================
SEG = 20
Zs = [0.0, 0.3, 0.7, 1.2, 1.8, 2.4, 2.9, 3.35, 3.7, 3.92]
Rs = [1.0, 1.4, 1.56, 1.58, 1.52, 1.35, 1.1, 0.75, 0.4, 0.05]
rings = []
for z, r in zip(Zs, Rs):
    ring = []
    for j in range(SEG):
        a = TAU * j / SEG
        n = S.fbm(V(math.cos(a) * 1.2, math.sin(a) * 1.2, z * 0.8) + V(3, 3, 3), 2) * 0.035
        ring.append(V(((r + n) * math.cos(a), (r + n) * math.sin(a), z)))
    rings.append(ring)
OPEN_I = (2, 3, 4)
OPEN_J = (4, 5, 6)


def opening(i, j):
    return i in OPEN_I and j in OPEN_J


def body_mat(i, j):
    if opening(i, j):
        return None
    if i <= 1:
        return "burnt"
    if i <= 3:
        return "burnt"
    if i == 4 and j % 3 == 0:
        return "burnt"
    if i == 5:
        return "accent"
    if i == 6 and j % 4 == 0:
        return "accent"
    return "hull"


mb = S.MB(M)
mb.loft(rings, mat=body_mat, closed=True, cap0=True, cap1=True, cap_mat="burnt")


def inset_ring(ring, c, amt):
    out = []
    for p in ring:
        d = V((p.x - c.x, p.y - c.y, 0))
        out.append(p - d.normalized() * amt)
    return out


inner = [inset_ring(r, V((0, 0, r[0].z)), 0.1) for r in rings]
mb.loft(inner, mat=lambda i, j: (None if opening(i, j) else "steel"), closed=True, flip=True)
# opening reveal (thickness) on the 4 edges
i0, i1, j0, j1 = OPEN_I[0], OPEN_I[-1] + 1, OPEN_J[0], OPEN_J[-1] + 1
for j in range(j0, j1):
    quad_out(mb, rings[i0][j], rings[i0][j + 1], inner[i0][j + 1], inner[i0][j], V((0, 0, -1)), "steel")
    quad_out(mb, rings[i1][j], rings[i1][j + 1], inner[i1][j + 1], inner[i1][j], V((0, 0, 1)), "steel")
for i in range(i0, i1):
    for jj, sgn in ((j0, -1), (j1, 1)):
        a = TAU * jj / SEG
        tang = V((-math.sin(a), math.cos(a), 0)) * sgn
        quad_out(mb, rings[i][jj], rings[i + 1][jj], inner[i + 1][jj], inner[i][jj], tang, "steel")
# frame beams around the opening
for j in range(j0, j1):
    mb.beam(rings[i0][j] * 1.0, rings[i0][j + 1], 0.1, 0.12, mat="accent")
    mb.beam(rings[i1][j], rings[i1][j + 1], 0.1, 0.12, mat="accent")
for jj in (j0, j1):
    for i in range(i0, i1):
        mb.beam(rings[i][jj], rings[i + 1][jj], 0.1, 0.12, mat="accent")
# interior
mb.lathe([(0, 0.0), (1.38, 0.0), (1.38, 0.08), (0, 0.08)], segs=20, c=(0, 0, 0.52), mat="steel")
mb.box((0, -0.25, 0.9), (0.85, 0.8, 0.34), mat="hull", bevel=0.07)
mb.box((0, -0.62, 1.45), (0.85, 0.18, 1.1), mat="hull", bevel=0.07, rot=(-0.12, 0, 0))
mb.box((0, -0.66, 2.1), (0.5, 0.14, 0.3), mat="accent", bevel=0.05)
for sx in (-1, 1):
    mb.box((sx * 0.3, -0.52, 1.4), (0.12, 0.05, 1.0), mat="accent", rot=(-0.12, 0, sx * 0.25))
    mb.box((sx * 1.15, 0.2, 1.55), (0.08, 0.9, 0.7), mat="steel", bevel=0.03, rot=(0, 0, sx * -0.18))
    mb.box((sx * 1.11, 0.2, 1.6), (0.03, 0.7, 0.4), mat="glow", rot=(0, 0, sx * -0.18))
mb.box((0, 0.75, 0.75), (0.7, 0.35, 0.3), mat="steel", bevel=0.04)
for k in range(4):
    a = TAU * k / 4 + 0.7
    mb.pipe([V((1.3 * math.cos(a), 1.3 * math.sin(a), 2.6)), V((1.1 * math.cos(a), 1.1 * math.sin(a), 1.8)), V((1.2 * math.cos(a), 1.2 * math.sin(a), 0.7))], 0.03, segs=6, mat="steel", bend=0.2)
# retro thrusters on the shoulder
for k in range(4):
    a = TAU * k / 4 + math.pi / 4
    p = V((1.18 * math.cos(a), 1.18 * math.sin(a), 2.85))
    d = V((math.cos(a) * 0.6, math.sin(a) * 0.6, -0.8)).normalized()
    mb.lathe([(0, 0.0), (0.2, 0.0), (0.3, -0.3), (0.34, -0.3), (0.26, 0.06), (0.0, 0.1)][::-1][::1], segs=10, c=p, rot=S.rot_to(-d), mat="burnt") if False else None
    mb.cyl(p + d * 0.12, 0.2, 0.13, 0.36, segs=10, rot=S.rot_to(-d), mat="steel")
    mb.cyl(p + d * 0.34, 0.14, 0.21, 0.12, segs=10, rot=S.rot_to(-d), mat="burnt")
# landing feet (bent)
for k in range(3):
    a = TAU * k / 3 + 0.4
    p0 = V((1.4 * math.cos(a), 1.4 * math.sin(a), 0.8))
    p1 = V((2.0 * math.cos(a), 2.0 * math.sin(a), 0.1 + 0.15 * k))
    mb.strut(p0, p1, 0.09, 0.07, segs=7, mat="steel")
    mb.box(p1 + V((0.1 * math.cos(a), 0.1 * math.sin(a), 0.0)), (0.5, 0.5, 0.08), rot=(0, 0, a), mat="steel", bevel=0.02)
# antenna + beacon ring
ant_b = V((0.45, -0.35, 3.82))
mb.cyl(ant_b + V((0, 0, 0.02)), 0.12, 0.1, 0.12, segs=8, mat="steel")
mb.cyl(ant_b + V((0, 0, 0.75)), 0.035, 0.02, 1.5, segs=6, mat="steel")
mb.box(ant_b + V((0, 0, 0.9)), (0.5, 0.03, 0.03), mat="steel")
mb.lathe([(1.1, 3.12), (1.13, 3.12), (1.12, 3.3), (1.08, 3.3), (1.1, 3.12)], segs=20, mat="lamp") if False else None
for k in range(6):
    a = TAU * k / 6
    mb.box(V((0.8 * math.cos(a), 0.8 * math.sin(a), 3.35)), (0.16, 0.16, 0.06), rot=(0, 0, a), mat="lamp", bevel=0.01)
body = mb.build(S.nm(ID, "Body"), col, smooth=38)

# ================================================== hatch (origin = hinge, hinge axis = local Z) ==================================
P = [[rings[i][j] for j in range(j0, j1 + 1)] for i in range(i0, i1 + 1)]
hinge = V((0, 0, 0))
for i in range(len(P)):
    hinge += P[i][0]
hinge = hinge / len(P)
hm = S.MB(M)
OUT, INN = 0.03, 0.035


def radial(p):
    return V((p.x, p.y, 0)).normalized()


outer = [[p + radial(p) * OUT - hinge for p in row] for row in P]
innerp = [[p - radial(p) * INN - hinge for p in row] for row in P]
for i in range(len(P) - 1):
    for j in range(len(P[0]) - 1):
        hm.quad(outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j], mat="hull")
        hm.quad(innerp[i][j], innerp[i + 1][j], innerp[i + 1][j + 1], innerp[i][j + 1], mat="steel")
ni, nj = len(P), len(P[0])
for j in range(nj - 1):
    quad_out(hm, outer[0][j], outer[0][j + 1], innerp[0][j + 1], innerp[0][j], V((0, 0, -1)), "steel")
    quad_out(hm, outer[ni - 1][j], outer[ni - 1][j + 1], innerp[ni - 1][j + 1], innerp[ni - 1][j], V((0, 0, 1)), "steel")
for i in range(ni - 1):
    quad_out(hm, outer[i][0], outer[i + 1][0], innerp[i + 1][0], innerp[i][0], V((0, 0, 0)) - (P[i][1] - P[i][0]), "steel")
    quad_out(hm, outer[i][nj - 1], outer[i + 1][nj - 1], innerp[i + 1][nj - 1], innerp[i][nj - 1], (P[i][nj - 1] - P[i][nj - 2]), "steel")
# hatch details
cc = V((0, 0, 0))
for row in outer:
    for p in row:
        cc += p
cc = cc / (ni * nj)
cn = radial(cc + hinge)
rm = S.rot_to(cn)
hm.cyl(cc + cn * 0.06, 0.34, 0.34, 0.1, segs=16, rot=rm, mat="steel", bevel=0.015)
hm.cyl(cc + cn * 0.1, 0.2, 0.2, 0.05, segs=12, rot=rm, mat="lamp")
for k in range(3):
    a = TAU * k / 3
    t1 = rm @ V((math.cos(a), math.sin(a), 0))
    hm.beam(cc + cn * 0.14, cc + cn * 0.14 + t1 * 0.3, 0.05, 0.05, mat="accent")
hm.box(cc + V((0, 0, 0.55)) + cn * 0.04, (0.5, 0.05, 0.18), rot=rm, mat="accent")
hm.box(cc - V((0, 0, 0.55)) + cn * 0.04, (0.5, 0.05, 0.18), rot=rm, mat="accent")
hatch = hm.build(S.nm(ID, "Hatch"), col, smooth=38)
hatch.location = hinge
hatch.rotation_euler = (0, 0, -105 * D2R)         # exported OPEN; rotation z = 0 is the closed pose

# ================================================== lights ====================================================================
bl = S.MB(Mblink)
bl.sphere((0, 0, 0), 0.09, u=10, v=7, mat="blink")
blink = bl.build(S.nm(ID, "BlinkLight"), col, smooth=None)
blink.location = ant_b + V((0, 0, 1.55))
il = S.MB(Mlamp)
il.cyl((0, 0, 0), 0.2, 0.2, 0.05, segs=12, mat="ilight")
ilight = il.build(S.nm(ID, "InteriorLight"), col, smooth=None)
ilight.location = (0, 0.15, 2.45)

# ================================================== Pod root (tilt) ===========================================================
pod = bpy.data.objects.new(S.nm(ID, "Pod"), None)
pod.empty_display_type = "PLAIN_AXES"
pod.empty_display_size = 0.5
col.objects.link(pod)
pod.location = (0, 0, -0.35)
pod.rotation_euler = (-7 * D2R, 5 * D2R, 12 * D2R)
for o in (body, hatch, blink, ilight):
    S.parent_to(o, pod)
bpy.context.view_layer.update()
PM = pod.matrix_world.copy()

# ================================================== crater + rocks (static ground) ================================================
cm = S.MB(M)
radii = [1.3, 1.8, 2.4, 3.0, 3.5, 4.2, 5.1]
heights = [-0.55, -0.5, -0.2, 0.42, 0.5, 0.15, -0.3]
CS = 30
crings = []
for r, h in zip(radii, heights):
    ring = []
    for j in range(CS):
        a = TAU * j / CS
        n1 = S.fbm(V(math.cos(a) * 1.5 + r * 0.2, math.sin(a) * 1.5, r * 0.3) + V(7, 1, 2), 3)
        rr = r * (1 + 0.12 * n1)
        hh = h + 0.22 * S.fbm(V(math.cos(a) * 2.2, math.sin(a) * 2.2, r * 0.5) + V(1, 5, 9), 3) * (0.3 if r < 2.2 else 1.0)
        ring.append(V((rr * math.cos(a), rr * math.sin(a), hh)))
    crings.append(ring)
cm.loft(crings, mat="dirt", closed=True, cap0=True, flip=True, cap_mat="dirt")
bm_ = cm.bm
bm_.normal_update()
for f in bm_.faces:
    if f.normal.z < 0:
        f.normal_flip()
# rocks around the rim
for k in range(9):
    a = rnd.uniform(0, TAU)
    r = rnd.uniform(3.2, 4.6)
    s = rnd.uniform(0.25, 0.6)
    rk = S.MB(M)
    rk.sphere((0, 0, 0), s, scale=(rnd.uniform(0.8, 1.3), rnd.uniform(0.8, 1.2), rnd.uniform(0.5, 0.8)), u=8, v=6, mat="dirt")
    L.noise_displace(rk.bm, amount=s * 0.28, scale=2.0, seed=k)
    rk.transform(S.M4((r * math.cos(a), r * math.sin(a), 0.2), (0, 0, rnd.uniform(0, 3))))
    cm.append(rk)
# scorch streak ribbon behind the pod (impact trail)
trail = []
for k in range(8):
    t = k / 7.0
    trail.append(V((-0.3 * t * 3, -2.5 - t * 6.5, 0.1 + 0.02 * t)))
for k in range(len(trail) - 1):
    w0 = 1.3 * (1 - k / 7.0) + 0.3
    w1 = 1.3 * (1 - (k + 1) / 7.0) + 0.3
    p0, p1 = trail[k], trail[k + 1]
    cm.quad(p0 + V((w0, 0, 0)), p0 + V((-w0, 0, 0)), p1 + V((-w1, 0, 0)), p1 + V((w1, 0, 0)), mat="burnt")
for f in cm.bm.faces:
    pass
crater = cm.build(S.nm(ID, "Crater"), col, smooth=45)

# ================================================== parachute (draped behind) =====================================================
cy = S.MB(M)
CR = 3.2
radsC = [0.08, 0.5, 1.1, 1.8, 2.5, 3.0, CR]
CSEG = 16
cring = []
for k, rr in enumerate(radsC):
    t = rr / CR
    ring = []
    for j in range(CSEG):
        a = TAU * j / CSEG
        n = S.fbm(V(math.cos(a) * rr * 0.5, math.sin(a) * rr * 0.5, 0) + V(2, 9, 4), 3)
        fold = 0.22 * math.sin(CSEG * 0.5 * a + 1.3 * n) * min(1.0, t * 2.0) * (1 - 0.4 * t)
        h = 0.7 * (1 - t ** 1.6) + 0.45 * n * (1 - t * 0.5) + fold + 0.18 * S.fbm(V(math.cos(a) * rr * 1.1, math.sin(a) * rr * 1.1, 4.0), 2)
        h = max(h, 0.02 + 0.05 * (1 - t))
        ring.append(V(((rr + 0.1 * n) * math.cos(a), (rr + 0.1 * n) * math.sin(a), 0.04 + h)))
    cring.append(ring)
cy.loft(cring, mat=lambda i, j: "chute_o" if j % 2 == 0 else "chute_w", closed=True, flip=True, cap0=True, cap_mat="chute_o")
cy.loft([[p - V((0, 0, 0.03)) for p in r] for r in cring], mat=lambda i, j: "chute_o" if j % 2 == 0 else "chute_w", closed=True, flip=False, cap0=False)
bmc = cy.bm
bmc.normal_update()
# shroud lines to the pod crown
crown = [PM @ V((0.9 * math.cos(a), 0.9 * math.sin(a), 3.2)) for a in [TAU * k / 6 + 0.3 for k in range(6)]]
cc_world = V((-1.6, -5.8, 0.0))
yaw = 20 * D2R
for k in range(6):
    jj = int(k * CSEG / 6)
    rimp = cring[-1][jj]
    q = cc_world + Matrix.Rotation(yaw, 3, "Z") @ rimp
    p0 = crown[k]
    mid = (p0 + q) * 0.5 + V((0, 0, -0.9))
    cy.pipe([p0 - cc_world, mid - cc_world, q - cc_world], 0.012, segs=4, mat="chute_w", bend=1.5) if False else None
chute = cy.build(S.nm(ID, "Chute"), col, smooth=None)
chute.location = cc_world
chute.rotation_euler = (0, 0, yaw)
# shroud lines as a separate small mesh in world coordinates
sl = S.MB(M)
for k in range(6):
    jj = int(k * CSEG / 6)
    rimp = cring[-1][jj]
    q = cc_world + Matrix.Rotation(yaw, 3, "Z") @ rimp
    p0 = crown[k]
    mid = (p0 + q) * 0.5
    mid.z = max(0.2, mid.z * 0.4)
    sl.pipe([p0, mid, q], 0.014, segs=4, mat="chute_w", bend=1.0)
lines = sl.build(S.nm(ID, "ChuteLines"), col, smooth=None)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (0.5, 3.6, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, tuple(PM @ (ant_b + V((0, 0, 1.7)))), size=0.4)
objs = [pod, crater, chute, lines, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "cylinder", "radius": 1.7, "height": 4.2, "offset_y": -0.3, "center": [0, 1.8, 0]},
    nodes={"hatch": ["Hatch"], "lights": ["InteriorLight", "BlinkLight"], "meshes": ["Body", "Crater", "Chute", "ChuteLines"], "root": ["Pod"],
           "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Escape pod ~4 m tall, tilted in an impact crater, hatch OPEN, parachute draped behind (-Y => Godot +Z). Hierarchy: `Pod` (tilted root, children Body / Hatch / BlinkLight / InteriorLight) + static Crater, Chute, ChuteLines. "
          "`Hatch` origin = hinge (vertical axis = local Y in Godot); exported open at rotation.y = -105 deg (Blender z) - set rotation to 0 for the closed pose. `InteriorLight` = warm emissive disc inside "
          "(own material *_ilight, put an OmniLight3D there), `BlinkLight` red on the antenna. Hatch faces Blender +Y (Godot -Z). Crater sinks to -0.55; Anchor_Door in front of the hatch.",
    preview_kw=dict(dist_mult=1.3),
)
print(entry["size"], entry["tris"])
