"""flora3 helper library (group flora3: volcanic / toxic flora + resources).  Builds on lib_common (L).

Use from a model script:
    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import lib_common as L; importlib.reload(L)
    import flora3_lib as F; importlib.reload(F)

All builders return bmesh objects (material_index set), the caller merges with F.join / L.bm_merge and calls F.finish().
Z is up, +Y is the model front.
"""
import sys
import math
import random
import json
import os

PROJ = r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort"
if PROJ + r"\blender" not in sys.path:
    sys.path.insert(0, PROJ + r"\blender")
import bpy
import bmesh
import lib_common as L
from mathutils import Vector, Matrix, Euler, noise
from mathutils.bvhtree import BVHTree

EPS = 1e-4
MANIFEST = PROJ + r"\assets\models\manifest_flora3.json"


# ----------------------------------------------------------------------------------------------------------------
# small math helpers
# ----------------------------------------------------------------------------------------------------------------
def rot_to(d):
    """4x4 rotation taking +Z onto direction d."""
    d = Vector(d).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    return q.to_matrix().to_4x4()


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a) if b != a else 0.0))
    return t * t * (3 - 2 * t)


def bez(p0, p1, p2, p3, n):
    """Cubic bezier sampled at n+1 points (list of Vectors)."""
    p0, p1, p2, p3 = [Vector(p) for p in (p0, p1, p2, p3)]
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t))
    return out


def bez3(p0, p1, p2, n):
    p0, p1, p2 = [Vector(p) for p in (p0, p1, p2)]
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t))
    return out


def fbm(p, octaves=3, hurst=0.5, lac=2.0):
    return noise.fractal(Vector(p), hurst, lac, octaves)


def snoise(p):
    return noise.noise(Vector(p))


# ----------------------------------------------------------------------------------------------------------------
# frames + tube sweep
# ----------------------------------------------------------------------------------------------------------------
def frames(pts):
    n = len(pts)
    tans = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        if t.length < 1e-9:
            t = Vector((0, 0, 1))
        tans.append(t.normalized())
    t0 = tans[0]
    ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = t0.cross(ref).normalized()
    out = []
    for i, t in enumerate(tans):
        if i > 0:
            q = tans[i - 1].rotation_difference(t)
            nrm = q @ nrm
        nrm = (nrm - t * nrm.dot(t))
        if nrm.length < 1e-9:
            nrm = t.orthogonal()
        nrm.normalize()
        b = t.cross(nrm)
        out.append((t, nrm, b))
    return out


def tube(pts, radii, segs=8, mat=0, cap_start=True, cap_end=True, rough=0.0, seed=0, twist=0.0, aspect=1.0,
         mat_fn=None, ring_fn=None):
    """Sweep a (jittered) circle along `pts` with per-point `radii`. Radius <= EPS at an end makes a pointed apex.
    rough: random per-vertex radial jitter (0..1), twist: radians per ring, aspect: stretch along the frame normal.
    ring_fn(i, k, a) -> radial multiplier (extra shaping, e.g. fins / ridges)."""
    pts = [Vector(p) for p in pts]
    rng = random.Random(seed)
    fr = frames(pts)
    bm = bmesh.new()
    rings = []
    nR = len(pts)
    jit = [[1.0 + (rng.random() * 2 - 1) * rough for _ in range(segs)] for _ in range(nR)]
    for i, (p, (t, n, b)) in enumerate(zip(pts, fr)):
        r = radii[i]
        if r <= EPS:
            v = bm.verts.new(p)
            rings.append([v] * segs)
            continue
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs + twist * i
            m = jit[i][k]
            if ring_fn is not None:
                m *= ring_fn(i, k, a)
            off = (n * (math.cos(a) * aspect) + b * math.sin(a)) * (r * m)
            ring.append(bm.verts.new(p + off))
        rings.append(ring)
    for i in range(nR - 1):
        A, B = rings[i], rings[i + 1]
        mi = mat_fn(i) if mat_fn else mat
        for k in range(segs):
            k2 = (k + 1) % segs
            vs = [A[k], A[k2], B[k2], B[k]]
            uniq = []
            for v in vs:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    f = bm.faces.new(uniq)
                    f.material_index = mi
                except ValueError:
                    pass
    if cap_end and radii[-1] > EPS and segs >= 3:
        f = bm.faces.new(rings[-1])
        f.material_index = mat_fn(nR - 2) if mat_fn else mat
    if cap_start and radii[0] > EPS and segs >= 3:
        f = bm.faces.new(list(reversed(rings[0])))
        f.material_index = mat_fn(0) if mat_fn else mat
    return bm


def lathe(profile, segs=12, mat=0, rough=0.0, seed=0, cap_first=False, cap_last=False, mat_fn=None, ring_fn=None,
          center=(0, 0, 0), twist=0.0, z_fn=None):
    """Revolve a (r, z) profile (ordered bottom->top on the outside, i.e. outward-facing) around Z.
    r <= EPS gives a single apex vertex. ring_fn(i, k, a) -> radial multiplier."""
    rng = random.Random(seed)
    bm = bmesh.new()
    cx, cy, cz = center
    nR = len(profile)
    rings = []
    for i, (r, z) in enumerate(profile):
        if r <= EPS:
            v = bm.verts.new((cx, cy, cz + z))
            rings.append([v] * segs)
            continue
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs + twist * i
            m = 1.0 + (rng.random() * 2 - 1) * rough
            if ring_fn is not None:
                m *= ring_fn(i, k, a)
            zz = z + (z_fn(i, k, a) if z_fn is not None else 0.0)
            ring.append(bm.verts.new((cx + math.cos(a) * r * m, cy + math.sin(a) * r * m, cz + zz)))
        rings.append(ring)
    for i in range(nR - 1):
        A, B = rings[i], rings[i + 1]
        mi = mat_fn(i) if mat_fn else mat
        for k in range(segs):
            k2 = (k + 1) % segs
            vs = [A[k], A[k2], B[k2], B[k]]
            uniq = []
            for v in vs:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    f = bm.faces.new(uniq)
                    f.material_index = mi
                except ValueError:
                    pass
    if cap_last and profile[-1][0] > EPS:
        f = bm.faces.new(rings[-1])
        f.material_index = mat_fn(nR - 2) if mat_fn else mat
    if cap_first and profile[0][0] > EPS:
        f = bm.faces.new(list(reversed(rings[0])))
        f.material_index = mat_fn(0) if mat_fn else mat
    return bm


# ----------------------------------------------------------------------------------------------------------------
# crystals / rocks / blobs
# ----------------------------------------------------------------------------------------------------------------
def crystal(base, direction, length, radius, sides=6, tip_frac=0.28, taper=0.9, mat=0, mat_tip=None, seed=0,
            jitter=0.10, two_stage=True, roll=None, tip_shift=(0.0, 0.0), cap_base=True, stage2=0.55, mat_alt=None):
    """Hexagonal-style crystal: prism + (optionally chamfered) pointed tip. Local +Z -> `direction`, base at `base`."""
    rng = random.Random(seed)
    bm = bmesh.new()
    ang0 = rng.random() * math.tau if roll is None else roll
    rings = []
    zs = []
    rs = []
    zs.append(0.0)
    rs.append(radius)
    z1 = length * (1.0 - tip_frac)
    zs.append(z1)
    rs.append(radius * taper)
    if two_stage:
        zs.append(length * (1.0 - tip_frac * 0.45))
        rs.append(radius * taper * stage2)
    for z, r in zip(zs, rs):
        ring = []
        for k in range(sides):
            a = ang0 + math.tau * k / sides
            m = 1.0 + (rng.random() * 2 - 1) * jitter
            ring.append(bm.verts.new((math.cos(a) * r * m, math.sin(a) * r * m, z)))
        rings.append(ring)
    apex = bm.verts.new((tip_shift[0] * radius, tip_shift[1] * radius, length))
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new([A[k], A[k2], B[k2], B[k]])
            f.material_index = mat if (mat_tip is None or i == 0) else mat_tip
            if mat_alt is not None and (k % 2 == 1) and (mat_tip is None or i == 0):
                f.material_index = mat_alt
    top = rings[-1]
    for k in range(sides):
        k2 = (k + 1) % sides
        f = bm.faces.new([top[k], top[k2], apex])
        f.material_index = mat if mat_tip is None else mat_tip
    if cap_base:
        f = bm.faces.new(list(reversed(rings[0])))
        f.material_index = mat
    m = Matrix.Translation(Vector(base)) @ rot_to(direction)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def bipyramid(center, height, radius, sides=6, mat=0, mat_b=None, seed=0, jitter=0.1, waist=0.5, tilt=None):
    """Diamond: apex bottom + apex top with a girdle ring (and extra rings for facets)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    a0 = rng.random() * math.tau
    top = bm.verts.new((0, 0, height * 0.5))
    bot = bm.verts.new((0, 0, -height * 0.5))
    rings = []
    for z, r in ((height * 0.12, radius * 0.92 * waist + radius * 0.08), (0.0, radius), (-height * 0.12, radius * 0.92 * waist + radius * 0.08)):
        ring = []
        for k in range(sides):
            a = a0 + math.tau * k / sides
            m = 1 + (rng.random() * 2 - 1) * jitter
            ring.append(bm.verts.new((math.cos(a) * r * m, math.sin(a) * r * m, z)))
        rings.append(ring)
    # fix: use girdle widest
    for k in range(sides):
        k2 = (k + 1) % sides
        f = bm.faces.new([top, rings[0][k], rings[0][k2]])
        f.material_index = mat
        f = bm.faces.new([rings[0][k], rings[1][k], rings[1][k2], rings[0][k2]])
        f.material_index = mat if mat_b is None else mat_b
        f = bm.faces.new([rings[1][k], rings[2][k], rings[2][k2], rings[1][k2]])
        f.material_index = mat if mat_b is None else mat_b
        f = bm.faces.new([bot, rings[2][k2], rings[2][k]])
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if tilt is not None:
        bmesh.ops.transform(bm, matrix=Matrix(Euler(tilt, "XYZ").to_matrix()).to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return bm


def rock_blob(radius=1.0, subdiv=2, amount=0.25, freq=1.2, seed=0, scale=(1, 1, 1), flat_bottom=0.55, mat=0,
              octaves=3, ridged=0.0, center=(0, 0, 0), facet=0.0):
    """Noise displaced icosphere rock. flat_bottom: cut-plane (fraction of radius below centre, 0 = none) -> flat base at z=0.
    Result is shifted so min z == 0 (when flat_bottom) and centered in XY on `center`."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((seed * 17.31 + 5.2, seed * 5.77 + 1.1, seed * 11.13 + 3.3))
    for v in bm.verts:
        d = v.co.normalized()
        n = noise.fractal(d * freq + off, 0.55, 2.0, octaves)
        if ridged:
            n = n * (1 - ridged) + (1 - abs(snoise(d * freq * 1.7 + off)) * 2) * ridged * 0.8
        r = 1.0 + n * amount
        v.co = Vector((d.x * r * radius * scale[0], d.y * r * radius * scale[1], d.z * r * radius * scale[2]))
    if flat_bottom:
        zc = -flat_bottom * radius * scale[2]
        for v in bm.verts:
            if v.co.z < zc:
                v.co.z = zc
        bmesh.ops.translate(bm, vec=(0, 0, -zc), verts=bm.verts)
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    return bm


def cell_plates(bm, n_cells, seed=0, shrink=0.88, depth=0.18, centre=None, mat_top=0, mat_wall=1, sink_fn=None, bulge=0.0, bulge_rand=0.0):
    """Split the faces of a (closed, convex-ish) bm into Voronoi plates separated by V-grooves.
    Plate tops keep mat_top, groove walls get mat_wall (so the grooves can glow).  `depth`: how far the groove bottom sinks
    toward `centre` (fraction of its distance).  Returns bm (modified in place)."""
    rng = random.Random(seed)
    bm.faces.ensure_lookup_table()
    if centre is None:
        centre = Vector((0, 0, 0))
        for v in bm.verts:
            centre += v.co
        centre /= len(bm.verts)
    centre = Vector(centre)
    fc = {f: f.calc_center_median() for f in bm.faces}
    flist = list(bm.faces)
    cl = [fc[f] for f in flist]
    seeds = [cl[rng.randrange(len(cl))]]
    for _ in range(n_cells - 1):
        best, bd = None, -1
        for _t in range(30):
            c = cl[rng.randrange(len(cl))]
            d = min((c - s).length for s in seeds)
            if d > bd:
                bd, best = d, c
        seeds.append(best)
    cells = {}
    for f in flist:
        c = fc[f]
        j = min(range(len(seeds)), key=lambda q: (c - seeds[q]).length)
        cells.setdefault(j, []).append(f)
    cell_of = {}
    for j, fl in cells.items():
        for f in fl:
            cell_of[f] = j
    deep = set()
    top_by_cell = {}
    for j, faces in cells.items():
        vmap = {}

        def top(v, vmap=vmap):
            if v not in vmap:
                vmap[v] = bm.verts.new(v.co)
            return vmap[v]
        for f in faces:
            nf = bm.faces.new([top(v) for v in f.verts])
            nf.material_index = mat_top
        for f in faces:
            for l in f.loops:
                e = l.edge
                other = [x for x in e.link_faces if x is not f]
                if (not other) or cell_of.get(other[0]) != j:
                    a, b = l.vert, l.link_loop_next.vert
                    w = bm.faces.new([a, b, top(b), top(a)])
                    w.material_index = mat_wall
                    deep.add(a)
                    deep.add(b)
        top_by_cell[j] = list(vmap.values())
    bmesh.ops.delete(bm, geom=flist, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    for v in deep:
        if v.is_valid:
            k = depth if sink_fn is None else sink_fn(v, depth)
            v.co = centre + (v.co - centre) * (1.0 - k)
    for j, tv in top_by_cell.items():
        cen = Vector((0, 0, 0))
        for v in tv:
            cen += v.co
        cen /= max(1, len(tv))
        maxd = max(((v.co - cen).length for v in tv), default=1.0) or 1.0
        boost = rng.uniform(-bulge_rand, bulge_rand)
        for v in tv:
            dd = (v.co - cen).length / maxd
            v.co = cen + (v.co - cen) * shrink
            if bulge or bulge_rand:
                dirv = (v.co - centre)
                if dirv.length > 1e-6:
                    v.co += dirv.normalized() * (bulge * (1.0 - dd * dd) + boost)
    return bm


def ground(bm, z=0.0):
    """Translate so min z == z."""
    mn = min(v.co.z for v in bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, z - mn), verts=bm.verts)
    return bm


def two_sided(bm):
    """Duplicate all faces with flipped normals (new verts) so thin geometry shows from both sides."""
    geom = bmesh.ops.duplicate(bm, geom=list(bm.faces))
    newf = [g for g in geom["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.reverse_faces(bm, faces=newf)
    return bm


def displace_bm(bm, amount=0.1, freq=1.0, seed=0, vfilter=None):
    off = Vector((seed * 13.1 + 2.0, seed * 7.7 + 9.0, seed * 3.3 + 4.0))
    for v in bm.verts:
        if vfilter is not None and not vfilter(v):
            continue
        n = noise.noise_vector(v.co * freq + off)
        v.co += n * amount


def set_mat(bm, idx, fn=None):
    for f in bm.faces:
        if fn is None or fn(f):
            f.material_index = idx


def transform(bm, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    bmesh.ops.transform(bm, matrix=L.xf(loc, rot, scale), verts=bm.verts)
    return bm


# ----------------------------------------------------------------------------------------------------------------
# leaves (thin curved blades)
# ----------------------------------------------------------------------------------------------------------------
def leaf(base, direction, length, width, bend=0.5, droop=0.0, mat=0, segs=6, fold=0.12, sideways=0.0, width_fn=None,
         double=True, up=(0, 0, 1), twist=0.0, thick=0.0):
    """Curved leaf blade from `base` along `direction` (unit-ish), bending toward `-up` by `bend` (droop). V-folded midrib.
    width_fn(t) -> width multiplier along the length (0..1); default: lens shape. Two sided if `double`."""
    d = Vector(direction).normalized()
    up = Vector(up).normalized()
    side = d.cross(up)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    nrm = side.cross(d).normalized()
    bm = bmesh.new()
    pts = []
    for i in range(segs + 1):
        t = i / segs
        # arc: forward + lift/droop
        p = Vector(base) + d * (length * t) - up * (bend * length * t * t) + side * (sideways * length * t * t)
        pts.append(p)
    fr = frames(pts)
    left, right, mid = [], [], []
    for i, p in enumerate(pts):
        t = i / segs
        wm = width_fn(t) if width_fn else (math.sin(math.pi * min(1.0, t * 0.92 + 0.04)) ** 0.8) * (1.0 - 0.15 * t)
        w = width * 0.5 * wm
        tt, n_, b_ = fr[i]
        rot = Matrix.Rotation(twist * t, 3, tt)
        n2 = rot @ n_
        b2 = rot @ b_
        # use b2 as sideways direction approx: choose the vector most aligned with `side`
        sd = b2 if abs(b2.dot(side)) > abs(n2.dot(side)) else n2
        if sd.dot(side) < 0:
            sd = -sd
        nv = sd.cross(tt)
        if nv.dot(nrm) < 0:
            nv = -nv
        if w <= EPS * 0.5:
            v = bm.verts.new(p + nv * (fold * width * 0.2))
            left.append(v)
            right.append(v)
            mid.append(v)
        else:
            left.append(bm.verts.new(p - sd * w - nv * (fold * w * 0.3)))
            right.append(bm.verts.new(p + sd * w - nv * (fold * w * 0.3)))
            mid.append(bm.verts.new(p + nv * (fold * w * 1.0 + thick)))
    for i in range(segs):
        for (A, B) in ((left, mid), (mid, right)):
            vs = [A[i], A[i + 1], B[i + 1], B[i]]
            uniq = []
            for v in vs:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    f = bm.faces.new(uniq[::-1] if False else uniq)
                    f.material_index = mat
                except ValueError:
                    pass
    # orient: top faces toward nrm
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ok = sum(f.normal.dot(nrm) for f in bm.faces)
    if ok < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    if double:
        two_sided(bm)
    return bm


# ----------------------------------------------------------------------------------------------------------------
# surface veins / cracks
# ----------------------------------------------------------------------------------------------------------------
def bvh_of(bm):
    return BVHTree.FromBMesh(bm)


def surface_walk(bvh, start, steps, step_len, rng, wander=0.6, bias=None, bias_k=0.0):
    p, n, idx, dist = bvh.find_nearest(Vector(start))
    if p is None:
        return []
    t = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
    t = t - n * t.dot(n)
    if t.length < 1e-6:
        t = n.orthogonal()
    t.normalize()
    if bias is not None:
        t = t + Vector(bias) * 2.0
        t = (t - n * t.dot(n)).normalized()
    pts = [(p.copy(), n.copy())]
    for _ in range(steps):
        ang = rng.uniform(-wander, wander)
        t = Matrix.Rotation(ang, 3, n) @ t
        if bias is not None and bias_k:
            t = t + Vector(bias) * bias_k
            t = (t - n * t.dot(n))
            if t.length < 1e-6:
                t = n.orthogonal()
            t.normalize()
        q = p + t * step_len
        p2, n2, idx, dist = bvh.find_nearest(q)
        if p2 is None:
            break
        t2 = p2 - p
        if t2.length < 1e-6:
            break
        t = t2.normalized()
        p, n = p2, n2
        pts.append((p.copy(), n.copy()))
    return pts


def ribbon(pn, width, lift=0.0, sides=4, mat=0, env=None, min_frac=0.0):
    """Tapered tube along walked surface points [(pos, normal)], pushed out by `lift` along the normal."""
    if len(pn) < 2:
        return None
    pts = [p + n * lift for p, n in pn]
    m = len(pts)
    radii = []
    for i in range(m):
        t = i / (m - 1)
        e = env(t) if env else (math.sin(math.pi * t) ** 0.6)
        radii.append(max(width * e, 0.0 if (i in (0, m - 1) and min_frac == 0.0) else width * min_frac))
    return tube(pts, radii, segs=sides, mat=mat, cap_start=False, cap_end=False)


def vein_network(bm_surface, n_main, rng, width=0.04, lift=0.0, steps=(8, 14), step_len=0.18, wander=0.7, fork=0.35,
                 mat=0, start_fn=None, bias=None, bias_k=0.0, sides=4, fork_len=0.6):
    """Random crack / vein network hugging the surface of bm_surface. Returns a merged bmesh (or None)."""
    bvh = bvh_of(bm_surface)
    out = []
    verts = [v.co.copy() for v in bm_surface.verts]
    for _ in range(n_main):
        s = start_fn(rng, verts) if start_fn else rng.choice(verts)
        k = rng.randint(*steps)
        pn = surface_walk(bvh, s, k, step_len, rng, wander, bias, bias_k)
        r = ribbon(pn, width, lift, sides, mat)
        if r is not None:
            out.append(r)
        for j in range(2, len(pn) - 3):
            if rng.random() < fork:
                pn2 = surface_walk(bvh, pn[j][0], max(3, int(k * fork_len)), step_len, rng, wander * 1.2, bias, bias_k)
                r2 = ribbon(pn2, width * 0.7, lift, sides, mat)
                if r2 is not None:
                    out.append(r2)
    if not out:
        return None
    return L.bm_merge(*out) if len(out) > 1 else out[0]


# ----------------------------------------------------------------------------------------------------------------
# finishing / export / manifest
# ----------------------------------------------------------------------------------------------------------------
def join(*bms):
    bms = [b for b in bms if b is not None]
    return L.bm_merge(*bms) if len(bms) > 1 else bms[0]


def finish(name, bm, col, materials, smooth_deg=40.0, flat=False, recalc=True, floor=None):
    """bmesh -> mesh object `name` (smooth by angle, or flat when flat=True). floor: clamp vertices below this z."""
    if floor is not None:
        for v in bm.verts:
            if v.co.z < floor:
                v.co.z = floor
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = L.obj_from_bm(name, bm, col, materials, smooth=not flat)
    if flat:
        for p in ob.data.polygons:
            p.use_smooth = False
    elif smooth_deg is not None:
        L.set_smooth_by_angle(ob, smooth_deg)
    return ob


def purge_unused_materials(prefix):
    for m in list(bpy.data.materials):
        if m.name.startswith(prefix) and m.users == 0:
            bpy.data.materials.remove(m)


def godot_size(objs):
    mn, mx = L.bounds(objs)
    s = mx - mn
    return mn, mx, [round(s.x, 2), round(s.z, 2), round(s.y, 2)]  # Godot axes (x, y=up, z)


def write_manifest(objs, model_id, kind, biomes, collider, tintable=None, notes="", nodes=None):
    mn, mx, size = godot_size(objs)
    entry = {
        "id": model_id,
        "file": model_id + ".glb",
        "kind": kind,
        "biomes": biomes,
        "size": size,
        "base_y": round(mn.z, 3),
        "collider": collider,
        "tris": int(L.tri_count(objs)),
        "tintable": tintable or [],
        "notes": notes,
    }
    if nodes:
        entry["nodes"] = nodes
    data = {"group": "flora3", "models": []}
    try:
        if os.path.exists(MANIFEST):
            with open(MANIFEST, "r", encoding="utf-8") as f:
                data = json.load(f)
    except Exception:
        data = {"group": "flora3", "models": []}
    data["group"] = "flora3"
    data["models"] = [m for m in data.get("models", []) if m.get("id") != model_id]
    data["models"].append(entry)
    order = ["obsidian_spire_a", "rock_lava_a", "vent_stack_a", "tree_charred_a", "magma_crystal_a", "mushroom_toxic_a",
             "mushroom_toxic_b", "tentacle_plant_a", "spore_pod_a", "bulb_plant_a", "res_ore_ferrite", "res_fuel_crystal",
             "res_bulb_plant", "res_warp_crystal", "rock_basalt_a", "fungus_cap_a", "acid_pool_rim_a", "ash_tree_a"]
    data["models"].sort(key=lambda m: order.index(m["id"]) if m["id"] in order else 99)
    data["collider_note"] = ("collider.offset_y = height of the collider's BOTTOM above the model origin (ground contact); "
                             "radius/height/size in metres, shape centred on the model's vertical axis.")
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print("manifest entry:", json.dumps(entry))
    return entry


def run_standard(model_id, ob, views=None, size=(440, 380)):
    """report + preview + montage; returns montage path."""
    L.report([ob], model_id)
    kw = {}
    if views:
        kw["views"] = views
    paths = preview([ob], model_id, size=size, **kw)
    out = L.montage(paths, model_id + "_sheet", cols=3)
    print("MONTAGE:", out)
    return out


def preview(objects, name, views=((35, 20), (125, 20), (215, 20), (305, 20), (0, 85)), size=(440, 380), **kw):
    """L.preview but hides every other object (render-hide) during the call so only `objects` are rendered."""
    keep = set()

    def add(o):
        keep.add(o)
        for c in o.children:
            add(c)
    for o in objects:
        add(o)
    saved = []
    for o in bpy.data.objects:
        if o not in keep and not o.name.startswith("__prev"):
            saved.append((o, o.hide_render))
            o.hide_render = True
    try:
        return L.preview(objects, name, views=views, size=size, **kw)
    finally:
        for o, h in saved:
            try:
                o.hide_render = h
            except Exception:
                pass
