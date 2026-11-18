"""asteroid_a / asteroid_b / asteroid_c -- irregular rock fragments (40..80 m).  Origin = centre of mass.  One mesh object `Asteroid` per glb.
  a: lumpy elongated potato with big craters   b: angular, plane-cut fragment   c: bilobed contact-binary with a big crater
Materials: rock_dark, rock_mid, rock_light (three-tone geology patches), ore (metallic veins).

Pipeline (v2): dense icosphere (5120 tris) -> large-scale shape (ellipsoid / two lobes / plane cuts) + lumps + bowl craters with raised rims
-> Decimate (collapse) down to ~2.2k tris, so the triangles gather where the shape has features (crater walls, rims, cut edges) and flat
areas stay cheap -> flat shading -> raised ore-vein ribbons.  Deterministic (fixed seeds).
v3 (QA): shard (b) gets plane cuts spread evenly over the sphere (no smooth ball-like patches left), bilobed (c) crater moved off the neck
(it made a pinched funnel), 3-tone rock, wider ore veins, ~2.2k tris.
v4 (QA): ore veins taper (pinched ends) instead of ending in square tabs.
"""
import sys, importlib, math, random
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy, bmesh
from mathutils import Vector, noise
import lib_common as L
import ship_lib as S
importlib.reload(L)
importlib.reload(S)
V = Vector
TAU = math.tau
DO_EXPORT = True

ROCK_D = L.mat("asteroid_rock_dark", (0.085, 0.075, 0.068), metallic=0.05, roughness=0.95)
ROCK_M = L.mat("asteroid_rock_mid", (0.135, 0.115, 0.097), metallic=0.05, roughness=0.93)
ROCK_L = L.mat("asteroid_rock_light", (0.205, 0.168, 0.133), metallic=0.05, roughness=0.92)
ORE = L.mat("asteroid_ore", (0.80, 0.42, 0.16), metallic=0.9, roughness=0.32)
MATS = [ROCK_D, ROCK_M, ROCK_L, ORE]
ORE_IDX = 3


def fbm(p, octaves=4, lac=2.1, gain=0.5):
    a = 1.0
    f = 1.0
    s = 0.0
    norm = 0.0
    for _ in range(octaves):
        s += a * noise.noise(p * f)
        norm += a
        a *= gain
        f *= lac
    return s / norm


def ridged(p, octaves=3, lac=2.2, gain=0.5):
    a = 1.0
    f = 1.0
    s = 0.0
    norm = 0.0
    for _ in range(octaves):
        n = 1.0 - abs(noise.noise(p * f))
        s += a * n * n
        norm += a
        a *= gain
        f *= lac
    return s / norm


def soft_union(vals, k=10.0):
    return (sum(v ** k for v in vals)) ** (1.0 / k)


def sphere_exit(u, c, R):
    """Distance from the origin along unit direction u to the far side of the sphere (centre c, radius R)."""
    b = u.dot(c)
    disc = b * b - (c.dot(c) - R * R)
    if disc < 0:
        return 0.0
    return max(b + math.sqrt(disc), 0.0)


def smin(a, b, k):
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25


def lobes_radius(u, lobes, k=0.30):
    """Radius along unit direction u (from the origin, inside the shape) where the smooth union of the sphere lobes ends (bisection)."""
    def f(r):
        p = u * r
        d = 1e9
        for (c, R) in lobes:
            q = (p - c).length - R
            d = q if d == 1e9 else smin(d, q, k)
        return d
    lo, hi = 0.0, 2.2
    for _ in range(26):
        mid = 0.5 * (lo + hi)
        if f(mid) < 0.0:
            lo = mid
        else:
            hi = mid
    return lo


def pick_craters(rng, n_big, n_small, big_rad, small_rad, sep=0.85, forced=()):
    """Non-overlapping craters on the unit sphere: (direction, angular radius, depth)."""
    out = [(d.normalized(), r, r * 0.42) for (d, r) in forced]
    tries = 0
    want = len(out) + n_big + n_small
    while len(out) < want and tries < 4000:
        tries += 1
        d = V((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        big = len(out) < len(forced) + n_big
        rad = rng.uniform(*big_rad) if big else rng.uniform(*small_rad)
        ok = True
        for (d2, r2, _) in out:
            ang = math.acos(max(-1.0, min(1.0, d.dot(d2))))
            if ang < (rad + r2) * sep:
                ok = False
                break
        if ok:
            out.append((d, rad, rad * rng.uniform(0.34, 0.50)))
    return out


def decimate(bm, col, target_tris):
    """Collapse-decimate a triangle bmesh to ~target_tris through a temporary object (evaluated depsgraph); returns a new bmesh."""
    me = bpy.data.meshes.new("tmp_ast_dec")
    bm.to_mesh(me)
    ob = bpy.data.objects.new("tmp_ast_dec", me)
    col.objects.link(ob)
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = min(1.0, target_tris / float(max(1, len(me.polygons))))
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me2 = bpy.data.meshes.new_from_object(ev)
    out = bmesh.new()
    out.from_mesh(me2)
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return out


def make(name, seed, size, kind="potato", n_big=4, n_small=7, big_rad=(0.42, 0.62), small_rad=(0.16, 0.26), lump=0.2, rough=0.05,
         planes=0, plane_d=(0.72, 0.9), nveins=6, dust_freq=0.8, target=2020, vein_steps=14, vein_step=0.07, forced=()):
    rng = random.Random(seed)
    col = L.fresh_collection(name)
    for o in list(bpy.data.objects):
        if o.name.startswith(name + "__"):
            bpy.data.objects.remove(o, do_unlink=True)
    S.begin(col)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=5, radius=1.0)
    off = V((seed * 3.17, seed * 1.91, seed * 2.53))
    craters = pick_craters(rng, n_big, n_small, big_rad, small_rad, forced=forced)
    cuts = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(planes):                               # fibonacci directions + jitter: every part of the sphere gets cut
        y = 1.0 - 2.0 * (i + 0.5) / planes
        rr = math.sqrt(max(0.0, 1.0 - y * y))
        th = golden * i + rng.uniform(-0.3, 0.3)
        d = (V((math.cos(th) * rr, y, math.sin(th) * rr)) + V((rng.gauss(0, 0.16), rng.gauss(0, 0.16), rng.gauss(0, 0.16)))).normalized()
        cuts.append((d, rng.uniform(plane_d[0], plane_d[1])))
    for v in bm.verts:
        u = v.co.normalized()
        r = 1.0
        if kind == "bilobed":
            r = max(lobes_radius(u, ((V((0.40, 0, 0)), 0.62), (V((-0.50, 0, 0.02)), 0.55)), 0.34), 0.3)
        r *= 1.0 + lump * fbm(u * 1.05 + off, 3)
        for (d, dist) in cuts:
            c = u.dot(d)
            if c > 1e-3:
                r = min(r, dist / c)
        for (d, rad, depth) in craters:
            ang = math.acos(max(-1.0, min(1.0, u.dot(d))))
            t = ang / rad
            if t < 1.0:
                r -= depth * (1.0 - t * t) ** 0.8                       # bowl
            elif t < 1.7:
                r += depth * 0.50 * math.exp(-((t - 1.07) / 0.17) ** 2)  # raised rim
        r += rough * (ridged(u * 2.4 + off * 1.3, 2) - 0.5) * (0.6 if planes else 1.0)
        v.co = u * r
    for v in bm.verts:
        v.co.x *= size[0] * 0.5
        v.co.y *= size[1] * 0.5
        v.co.z *= size[2] * 0.5
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    n_dense = len(bm.faces)
    bm = decimate(bm, col, target)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print(name, "dense", n_dense, "-> decimated", len(bm.faces))
    for f in bm.faces:                                   # large dust patches
        c = f.calc_center_median()
        p = V((c.x / size[0], c.y / size[1], c.z / size[2])) * 2.0
        n = fbm(p * dust_freq + off * 0.6, 2)
        f.material_index = 2 if n > 0.15 else (1 if n > -0.07 else 0)
    # ore veins: random walks on the surface, raised ribbons
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromBMesh(bm)
    for vi in range(nveins):
        u = V((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        tdir = V((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)))
        tdir = (tdir - u * tdir.dot(u)).normalized()
        for branch in range(2):
            uu = u.copy()
            td = tdir.copy() if branch == 0 else (-tdir + u.cross(tdir) * 0.6).normalized()
            pts, nrs = [], []
            for step in range(vein_steps):
                o = V((uu.x * size[0], uu.y * size[1], uu.z * size[2])) * 1.6
                hit, nrm, idx, dist = bvh.ray_cast(o, -o.normalized(), 1000.0)
                if hit is not None:
                    pts.append(hit)
                    nrs.append(nrm)
                td = (td + V((rng.gauss(0, 0.28), rng.gauss(0, 0.28), rng.gauss(0, 0.28)))).normalized()
                td = (td - uu * td.dot(uu)).normalized()
                uu = (uu + td * vein_step).normalized()
            if len(pts) >= 3:
                S.ribbon(bm, pts, nrs, rng.uniform(1.8, 3.0), 0.45, ORE_IDX, taper=0.3)   # v4 (QA): pinched vein ends, no square tabs
    root = L.empty(name + "__Asteroid_Root", col, (0, 0, 0), display="PLAIN_AXES", size=2.0)
    ob = S.finish("Asteroid", bm, col, MATS, parent=root, prefix=name + "__", flat=True)
    bpy.context.view_layer.update()
    tris = S.tri_report(root, name)
    if DO_EXPORT:
        path, names = S.export_named([root], name, name + "__")
        print("EXPORTED", path, names)
    S.end(col)
    return tris


make("asteroid_a", 3, (70.0, 46.0, 44.0), kind="potato", n_big=4, n_small=7, big_rad=(0.42, 0.60), small_rad=(0.16, 0.26),
     lump=0.26, rough=0.07, nveins=7)
make("asteroid_b", 11, (60.0, 54.0, 66.0), kind="potato", n_big=2, n_small=4, big_rad=(0.34, 0.46), small_rad=(0.14, 0.22),
     lump=0.12, rough=0.05, planes=11, plane_d=(0.56, 0.80), nveins=6)
make("asteroid_c", 29, (74.0, 60.0, 52.0), kind="bilobed", n_big=3, n_small=6, big_rad=(0.42, 0.58), small_rad=(0.16, 0.24),
     lump=0.16, rough=0.06, nveins=7,
     forced=((V((0.85, 0.25, 0.45)), 0.50),))
L.save_blend()
