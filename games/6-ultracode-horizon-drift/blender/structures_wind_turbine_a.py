import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
from mathutils import Vector, Matrix

ID = "wind_turbine_a"
col = L.fresh_collection(ID)
D2R = math.pi / 180.0
TAU = math.tau
V = Vector
rnd = random.Random(21)

M = S.mats(ID, {
    "hull": dict(color=(0.55, 0.55, 0.53), metallic=0.08, roughness=0.42),
    "hull2": dict(color=(0.34, 0.36, 0.40), metallic=0.3, roughness=0.5),
    "frame": "graphite",
    "steel": "steel",
    "accent": "orange",
    "base": "dconcrete",
    "lamp": "window_warm",
})
Mblink = S.mats(ID, {"blink": "emit_red"})

HUB = V((0.0, 2.05, 11.5))       # hub centre (rotor origin)
R_BLADE = 5.3

# ===================================================== tower ==================================================================
b = S.MB(M)
b.lathe([(0, -0.55), (2.45, -0.55), (2.45, 0.35), (2.15, 0.55), (0, 0.55)], segs=32, mat="base")
b.lathe([(1.25, 0.54), (1.25, 0.62), (1.05, 0.62), (1.05, 0.54), (1.25, 0.54)], segs=24, mat="steel")
for k in range(16):
    a = TAU * k / 16
    b.cyl((1.15 * math.cos(a), 1.15 * math.sin(a), 0.7), 0.045, 0.045, 0.16, segs=6, mat="steel")
# shaft sections (lathe, 14 segs)
zs = [0.62, 3.9, 7.3, 10.7]
rs = [0.98, 0.78, 0.6, 0.44]
for i in range(3):
    mat = "hull"
    b.lathe([(0, zs[i]), (rs[i], zs[i]), (rs[i + 1] * 1.02 if False else (rs[i] + (rs[i + 1] - rs[i]) * 0.985), zs[i + 1]), (0, zs[i + 1])], segs=14, mat=mat)
for i in (1, 2):
    z = zs[i]
    r = rs[i]
    b.lathe([(0, z - 0.1), (r + 0.1, z - 0.1), (r + 0.1, z + 0.1), (0, z + 0.1)], segs=14, mat="steel")
    for k in range(14):
        a = TAU * (k + 0.5) / 14
        b.cyl(((r + 0.1) * math.cos(a), (r + 0.1) * math.sin(a), z + 0.1), 0.03, 0.03, 0.05, segs=6, mat="frame")
# orange safety band at the bottom + white/orange at the top
b.lathe([(rs[0] - 0.005, 0.62), (rs[0] + 0.03, 0.62), (rs[0] + 0.0, 1.5), (rs[0] - 0.02, 1.5), (rs[0] - 0.005, 0.62)], segs=14, mat="accent")
b.lathe([(0.45, 10.2), (0.48, 10.2), (0.475, 10.7), (0.44, 10.7), (0.45, 10.2)], segs=14, mat="accent")
# door (front +Y)
dy = 0.0
fy = rs[0] * 0.97
b.box((0, fy + 0.02, 1.35), (0.95, 0.16, 1.95), mat="frame", bevel=0.04)
b.box((0, fy + 0.1, 1.28), (0.78, 0.1, 1.75), mat="hull2", bevel=0.03)
b.box((0.25, fy + 0.18, 1.3), (0.06, 0.06, 0.3), mat="steel")
b.box((0, fy + 0.2, 2.4), (0.5, 0.06, 0.1), mat="lamp")
b.box((0, fy + 0.45, 0.4), (1.5, 0.9, 0.12), mat="base", bevel=0.03)
b.box((0, fy + 1.05, 0.2), (1.3, 0.5, 0.12), mat="base", bevel=0.03)
# transformer kiosk
b.box((3.1, 0.0, 0.95), (1.7, 1.3, 1.8), mat="hull2", bevel=0.06)
b.box((3.1, 0.0, 1.9), (1.85, 1.45, 0.12), mat="frame", bevel=0.03)
b.box((3.1, 0.67, 1.0), (1.4, 0.04, 1.4), mat="hull", bevel=0.02)
b.vent((3.45, 0.7, 1.25), 0.5, 0.8, n=6, mat_slat="frame", mat_back="frame")
b.box((2.8, 0.69, 1.65), (0.3, 0.03, 0.2), mat="lamp")
b.box((3.1, 0.69, 0.35), (1.4, 0.03, 0.08), mat="accent")
b.pipe([V((2.25, 0.0, 0.5)), V((1.6, 0.0, 0.5)), V((1.2, 0.0, 0.4)), V((0.95, 0.0, 0.9))], 0.07, segs=6, mat="frame", bend=0.3)
# ladder / cable on the back of the tower up to the nacelle
b.pipe([V((0.0, -rs[0] - 0.05, 0.8)), V((0.0, -0.52, 5.0)), V((0.0, -0.4, 10.6))], 0.035, segs=6, mat="frame", bend=0.3)
b.pipe([V((0.1, -rs[0] - 0.05, 0.8)), V((0.1, -0.52, 5.0)), V((0.1, -0.4, 10.6))], 0.03, segs=6, mat="frame", bend=0.3)
# yaw bearing
b.lathe([(0.0, 10.65), (0.62, 10.65), (0.66, 10.78), (0.66, 10.9), (0.0, 10.9)], segs=20, mat="steel")
b.lathe([(0.0, 10.88), (0.58, 10.88), (0.58, 10.98), (0.0, 10.98)], segs=20, mat="frame")

# ===================================================== nacelle ================================================================
def sup(c, s, n):
    return math.copysign(abs(c) ** (2.0 / n), c), math.copysign(abs(s) ** (2.0 / n), s)


def ring_pts(y, a, bb, zc, segs=20, n=3.0):
    out = []
    for j in range(segs):
        phi = -TAU * j / segs
        cx, sz = sup(math.cos(phi), math.sin(phi), n)
        out.append(V((a * cx, y, zc + bb * sz)))
    return out


stations = [(-2.5, 0.38, 0.38, 0.0), (-2.2, 0.7, 0.66, 0.02), (-1.5, 0.88, 0.82, 0.04), (0.2, 0.9, 0.86, 0.04), (1.0, 0.82, 0.8, 0.02), (1.45, 0.62, 0.62, 0.0)]
zc0 = 11.5
rings = [ring_pts(y, a, bb, zc0 + dz) for (y, a, bb, dz) in stations]
b.loft(rings, mat="hull", closed=True, cap0=True, cap1=True)
# panel seams on the nacelle
for (y, a, bb, dz) in ((-1.0, 0.89, 0.84, 0.04), (0.0, 0.9, 0.86, 0.04)):
    ring = ring_pts(y, a * 1.012, bb * 1.012, zc0 + dz)
    for j in range(len(ring)):
        b.beam(ring[j], ring[(j + 1) % len(ring)], 0.03, 0.03, mat="hull2")
b.box((0, -0.3, zc0 + 0.9), (0.9, 1.6, 0.06), mat="hull2", bevel=0.02)                  # roof hatch
b.vent((0, -1.45, zc0 + 0.62), 0.8, 0.5, n=5, rot=(math.radians(90), 0, 0), mat_slat="frame", mat_back="frame")
b.box((0.88, -0.2, zc0 - 0.05), (0.04, 1.6, 0.4), mat="accent")
b.box((-0.88, -0.2, zc0 - 0.05), (0.04, 1.6, 0.4), mat="accent")
# front shroud ring around the hub
b.lathe([(0.0, 0), (0.7, 0.0), (0.7, 0.12), (0.0, 0.12)], segs=20, c=(0, 1.42, zc0), rot=(-math.pi / 2, 0, 0), mat="steel")
# anemometer mast
b.cyl((0.5, -1.2, zc0 + 1.15), 0.03, 0.03, 0.9, segs=6, mat="frame")
for k in range(3):
    a = TAU * k / 3
    b.cyl((0.5 + 0.18 * math.cos(a), -1.2 + 0.18 * math.sin(a), zc0 + 1.6), 0.04, 0.04, 0.05, segs=6, mat="steel")
b.box((0.5, -1.45, zc0 + 1.2), (0.03, 0.55, 0.15), mat="steel")
b.cyl((-0.5, -1.2, zc0 + 1.05), 0.025, 0.02, 0.7, segs=6, mat="frame")
b.sphere((-0.5, -1.2, zc0 + 1.42), 0.04, u=6, v=4, mat="lamp")

tower = b.build(S.nm(ID, "Tower"), col, smooth=40)

# ===================================================== rotor ==================================================================
rb = S.MB(M)
# hub: body + spinner (axis = local +Z, front)
rb.lathe([(0.0, -0.45), (0.58, -0.45), (0.62, -0.2), (0.62, 0.35), (0.5, 0.65), (0.3, 1.0), (0.12, 1.25), (0.0, 1.32)], segs=16, mat="hull")
rb.lathe([(0.5, 0.64), (0.54, 0.64), (0.56, 0.8), (0.5, 0.8), (0.5, 0.64)][::1], segs=16, mat="accent") if False else None
rb.lathe([(0.0, -0.5), (0.4, -0.5), (0.4, -0.45), (0.0, -0.45)], segs=12, mat="steel")


def chord(r):
    if r < 1.5:
        return 0.52 + (0.95 - 0.52) * (r - 0.55) / 0.95
    return 0.95 - (0.95 - 0.13) * min(1.0, ((r - 1.5) / (R_BLADE - 1.5))) ** 0.85


def blade_rings(segs_per_side=7):
    rr = [0.5, 0.85, 1.3, 1.9, 2.6, 3.4, 4.2, 4.8, 5.15, R_BLADE]
    rings = []
    for r in rr:
        c = chord(r)
        t = 0.19 * c
        beta = 21.0 * D2R * max(0.0, 1 - (r - 0.5) / 4.8) ** 1.2
        Rm = Matrix.Rotation(beta, 3, "Y")
        pts2 = []
        lower = []
        for k in range(segs_per_side + 1):
            u = k / segs_per_side
            shp = (1 - (2 * u - 1) ** 2) ** 0.65 * (1 - 0.3 * u) if 0 < u < 1 else 0.0
            lower.append(((0.3 - u) * c, -t * shp * 0.7))
        upper = []
        for k in range(segs_per_side, -1, -1):
            u = k / segs_per_side
            shp = (1 - (2 * u - 1) ** 2) ** 0.65 * (1 - 0.3 * u) if 0 < u < 1 else 0.0
            upper.append(((0.3 - u) * c, t * shp))
        pts2 = lower + upper[1:-1]
        ring = []
        for (x, z) in pts2:
            p = Rm @ V((x, 0, z))
            ring.append(V((p.x, r, p.z)))
        rings.append(ring)
    return rings


br = blade_rings()
rr_list = [0.5, 0.85, 1.3, 1.9, 2.6, 3.4, 4.2, 4.8, 5.15, R_BLADE]


def bmat(i, j):
    return "accent" if rr_list[i] >= 4.1 and rr_list[i] < 4.8 else "hull"


for k in range(3):
    ang = (180 + k * 120) * D2R
    Rz = Matrix.Rotation(ang, 4, "Z")          # blade 0 points local -Y (= world up at rest)
    tmp = S.MB(M)
    tmp.loft(br, mat=bmat, closed=True, cap0=False, cap1=True, cap_mat="hull")
    # root cuff + pitch bearing
    tmp.cyl((0, 0.55, 0.0), 0.34, 0.34, 0.5, segs=14, axis="Y", mat="steel")
    tmp.cyl((0, 0.82, 0.0), 0.37, 0.37, 0.12, segs=14, axis="Y", mat="accent")
    rb.append(tmp, Rz)
rotor = rb.build(S.nm(ID, "Rotor"), col, smooth=40)
rotor.location = HUB
rotor.rotation_euler = (-math.pi / 2, 0, 0)
S.parent_to(rotor, tower)

bl = S.MB(Mblink)
bl.sphere((0, 0, 0), 0.11, u=10, v=7, mat="blink")
blink = bl.build(S.nm(ID, "BlinkLight"), col, smooth=None)
blink.location = (0.0, -1.55, zc0 + 0.92)
S.parent_to(blink, tower)

a_door = L.empty(S.nm(ID, "Anchor_Door"), col, (0, fy + 2.2, 0.0), size=0.4)
a_top = L.empty(S.nm(ID, "Anchor_Top"), col, (0, -0.2, zc0 + 1.3), size=0.4)
objs = [tower, a_door, a_top]
entry = S.finish(
    objs, ID, biomes=["any"],
    collider={"shape": "cylinder", "radius": 1.2, "height": 11.0, "offset_y": -0.55, "center": [0, 5.0, 0]},
    colliders=[{"shape": "cylinder", "radius": 1.2, "height": 11.0, "offset_y": -0.55, "center": [0, 5.0, 0], "note": "tower + foundation"},
               {"shape": "box", "size": [1.7, 1.8, 1.3], "offset_y": 0.0, "center": [3.1, 0.9, 0.0], "note": "kiosk"}],
    nodes={"rotor": ["Rotor"], "blink": ["BlinkLight"], "meshes": ["Tower"], "anchors": ["Anchor_Door", "Anchor_Top"]},
    notes="Wind turbine ~16.9 m (hub y=11.5, blade length 5.3). Rotor faces Blender +Y (Godot -Z). `Rotor` is a child of `Tower`: its origin = the hub centre and its node is pre-rotated (-90 deg about X) so that its "
          "LOCAL Y AXIS (Godot) IS THE SHAFT: spin it with rotate_object_local(Vector3.UP, dt * speed). 3 blades (orange tips). BlinkLight = red emissive sphere on the nacelle roof (own material *_blink). "
          "Foundation sinks 0.55 m below y=0; kiosk on the +X side; Anchor_Door in front of the base door.",
    preview_kw=dict(dist_mult=1.5),
)
print(entry["size"], entry["tris"])
