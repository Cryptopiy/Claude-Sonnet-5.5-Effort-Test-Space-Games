"""flora2 helper library (desert / frozen / barren props) built on lib_common.

Use inside a script run through `python tools/bmcp.py file blender/flora2_<model>.py`:

    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import flora2_lib as F; importlib.reload(F)
"""
import sys
import os
import math
import random
import json
import importlib

sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy
import bmesh
from mathutils import Vector, Matrix, noise
import lib_common as L

importlib.reload(L)

TAU = math.tau
GROUP = "flora2"
MANIFEST = os.path.join(L.MODELS_DIR, "manifest_flora2.json")


# ---------------------------------------------------------------------------------------------------------------
# small math / colour helpers
# ---------------------------------------------------------------------------------------------------------------
def clamp(x, a=0.0, b=1.0):
    return a if x < a else (b if x > b else x)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    if e1 == e0:
        return 0.0 if x < e0 else 1.0
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h, k=1.0):
    """'#rrggbb' (sRGB) -> scene-linear tuple (optionally multiplied by k)."""
    h = h.lstrip("#")
    r, g, b = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return (_lin(r) * k, _lin(g) * k, _lin(b) * k)


def n3(x, y, z, seed=0.0):
    return noise.noise(Vector((x + seed * 12.9898, y + seed * 78.233, z + seed * 37.719)))


def fbm3(x, y, z, seed=0.0, octaves=3, lac=2.03, gain=0.5):
    s = 0.0
    a = 1.0
    f = 1.0
    t = 0.0
    for i in range(octaves):
        s += a * n3(x * f, y * f, z * f, seed + i * 3.17)
        t += a
        a *= gain
        f *= lac
    return s / t


def ridged3(x, y, z, seed=0.0, octaves=3):
    s = 0.0
    a = 1.0
    f = 1.0
    t = 0.0
    for i in range(octaves):
        s += a * (1.0 - abs(n3(x * f, y * f, z * f, seed + i * 3.17))) ** 2
        t += a
        a *= 0.5
        f *= 2.0
    return s / t


def pw(x, pts):
    """Piecewise-linear interpolation through [(x0,y0),(x1,y1),...] (clamped)."""
    if x <= pts[0][0]:
        return pts[0][1]
    for i in range(1, len(pts)):
        if x <= pts[i][0]:
            t = (x - pts[i - 1][0]) / max(pts[i][0] - pts[i - 1][0], 1e-9)
            return pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * t
    return pts[-1][1]


def catmull(pts, n=6):
    """Catmull-Rom spline through pts (list of vec3) -> list of Vectors (n samples per segment)."""
    pts = [Vector(p) for p in pts]
    P = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for s in range(n):
            t = s / n
            t2 = t * t
            t3 = t2 * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


# ---------------------------------------------------------------------------------------------------------------
# generic lofting / tubes / lathes
# ---------------------------------------------------------------------------------------------------------------
def loft(bm, rings, closed=True, cap_a=None, cap_b=None, mat=0, mat_rows=None):
    """Quad-strip between consecutive rings (lists of Vector, equal length).
    cap_a / cap_b: None | 'flat' | Vector apex (fan).  Winding: ring runs CCW about the loft direction (outward normals)."""
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    faces = []
    for i in range(len(vr) - 1):
        mi = mat_rows[i] if mat_rows is not None else mat
        for k in range(n):
            k2 = (k + 1) % n
            if not closed and k2 == 0:
                continue
            try:
                f = bm.faces.new((vr[i][k], vr[i][k2], vr[i + 1][k2], vr[i + 1][k]))
            except ValueError:
                continue
            f.material_index = mi
            faces.append(f)
    first = vr[0]
    last = vr[-1]
    if cap_a is not None:
        if isinstance(cap_a, str):
            f = bm.faces.new(first[::-1])
            f.material_index = mat_rows[0] if mat_rows is not None else mat
        else:
            c = bm.verts.new(cap_a)
            for k in range(n):
                f = bm.faces.new((c, first[(k + 1) % n], first[k]))
                f.material_index = mat_rows[0] if mat_rows is not None else mat
    if cap_b is not None:
        if isinstance(cap_b, str):
            f = bm.faces.new(last)
            f.material_index = mat_rows[-1] if mat_rows is not None else mat
        else:
            c = bm.verts.new(cap_b)
            for k in range(n):
                f = bm.faces.new((last[k], last[(k + 1) % n], c))
                f.material_index = mat_rows[-1] if mat_rows is not None else mat
    return vr


def tube(bm, path, rfn, segs=8, mat=0, cap_a="flat", cap_b="flat", tip_b=0.0, tip_a=0.0, profile=None, twist=0.0, aspect=1.0,
         ref=None, mat_rows=None):
    """Tube along `path` (list of Vector) with radius rfn(u) (u = arclength fraction 0..1).
    profile(theta, u) -> radius multiplier (ribs etc).  aspect scales the second axis.  Returns info list per ring
    [{'p','t','n','b','r'}] so callers can place details on the surface."""
    path = [Vector(p) for p in path]
    N = len(path)
    # arclength
    cum = [0.0]
    for i in range(1, N):
        cum.append(cum[-1] + (path[i] - path[i - 1]).length)
    total = max(cum[-1], 1e-6)
    tangents = []
    for i in range(N):
        if i == 0:
            t = path[1] - path[0]
        elif i == N - 1:
            t = path[-1] - path[-2]
        else:
            t = path[i + 1] - path[i - 1]
        tangents.append(t.normalized())
    t0 = tangents[0]
    if ref is None:
        ref = Vector((0, 1, 0)) if abs(t0.y) < 0.9 else Vector((1, 0, 0))
    nrm = (ref - t0 * ref.dot(t0)).normalized()
    rings = []
    info = []
    for i in range(N):
        t = tangents[i]
        if i > 0:
            q = tangents[i - 1].rotation_difference(t)
            nrm = (q @ nrm)
            nrm = (nrm - t * nrm.dot(t)).normalized()
        b = t.cross(nrm)
        u = cum[i] / total
        r = rfn[i] if isinstance(rfn, (list, tuple)) else rfn(u)
        ring = []
        for k in range(segs):
            th = TAU * k / segs + twist * u
            m = profile(th, u) if profile else 1.0
            ring.append(path[i] + nrm * (math.cos(th) * r * m) + b * (math.sin(th) * r * m * aspect))
        rings.append(ring)
        info.append({"p": path[i], "t": t, "n": nrm.copy(), "b": b.copy(), "r": r, "u": u})
    ca = None
    cb = None
    if cap_a == "flat":
        ca = "flat"
    elif cap_a == "apex":
        ca = path[0] - tangents[0] * tip_a
    if cap_b == "flat":
        cb = "flat"
    elif cap_b == "apex":
        cb = path[-1] + tangents[-1] * tip_b
    loft(bm, rings, True, ca, cb, mat, mat_rows)
    return info


def lathe(bm, profile, segs=24, mod=None, centre=None, cap_top="flat", cap_bottom="flat", mat=0, mat_rows=None, rot0=0.0,
          top_dome=0.0, aspect=(1.0, 1.0), zmod=None):
    """Surface of revolution about +Z.  profile = [(z, r), ...] bottom -> top.
    mod(theta, z, r, i) -> new radius.  centre(z) -> (cx, cy).  cap_*: None | 'flat' | 'apex'.  Returns the ring vertex lists."""
    rings = []
    for i, (z, r) in enumerate(profile):
        cx, cy = centre(z) if centre else (0.0, 0.0)
        ring = []
        for k in range(segs):
            th = rot0 + TAU * k / segs
            rr = mod(th, z, r, i) if mod else r
            zz = z + (zmod(th, z, r, i) if zmod else 0.0)
            ring.append(Vector((cx + math.cos(th) * rr * aspect[0], cy + math.sin(th) * rr * aspect[1], zz)))
        rings.append(ring)
    ztop = profile[-1][0]
    zbot = profile[0][0]
    ctop = centre(ztop) if centre else (0.0, 0.0)
    cbot = centre(zbot) if centre else (0.0, 0.0)
    ca = None
    cb = None
    if cap_bottom == "flat":
        ca = "flat"
    elif cap_bottom == "apex":
        ca = Vector((cbot[0], cbot[1], zbot))
    if cap_top == "flat":
        cb = "flat"
    elif cap_top == "apex":
        cb = Vector((ctop[0], ctop[1], sum(v.z for v in rings[-1]) / len(rings[-1]) + top_dome))
    return loft(bm, rings, True, ca, cb, mat, mat_rows)


def ico_blob(radius=(1, 1, 1), subdiv=3, seed=0, amp=0.2, freq=1.3, octaves=3, ridged=0.0):
    """Noise-displaced ellipsoid (unit sphere displaced radially, then scaled)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        u = v.co.normalized()
        d = fbm3(u.x * freq, u.y * freq, u.z * freq, seed, octaves)
        if ridged:
            d = lerp(d, ridged3(u.x * freq, u.y * freq, u.z * freq, seed, octaves) - 0.6, ridged)
        s = 1.0 + amp * d
        v.co = Vector((u.x * s * radius[0], u.y * s * radius[1], u.z * s * radius[2]))
    return bm


def plane_cut(bm, planes):
    """Project vertices that lie beyond a plane onto it (chiselled, faceted rocks).  planes: [(point, normal)]."""
    pl = [(Vector(p), Vector(n).normalized()) for p, n in planes]
    for v in bm.verts:
        for p, n in pl:
            d = (v.co - p).dot(n)
            if d > 0:
                v.co -= n * d


def random_planes(rng, n, radius, zmin=-1e9, tilt_bias=None, jitter=0.25, up_bias=0.0):
    """n random cutting planes at distance ~radius (unit directions, optional bias toward +Z)."""
    out = []
    for _ in range(n):
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)))
        d.z += up_bias
        d.normalize()
        dist = radius * (1.0 - jitter * rng.random())
        out.append((d * dist, d))
    return out


def crater(bm, axis, centre_pt, radius, depth, rim=0.2, rim_w=0.35):
    """Dent a bowl crater into the surface around centre_pt, displacing along `axis` (a Vector)."""
    axis = Vector(axis).normalized()
    c = Vector(centre_pt)
    for v in bm.verts:
        d = (v.co - c).length
        t = d / radius
        if t < 1.0 + rim_w * 2:
            bowl = -depth * (1.0 - t * t) if t < 1.0 else 0.0
            rimh = depth * rim * math.exp(-(((t - 1.0) / rim_w) ** 2))
            v.co += axis * (bowl + rimh)


def flat_base(bm, z0=0.0, drop_bottom=True):
    """Clamp everything below z0 up to z0 and (optionally) delete the flat bottom faces."""
    for v in bm.verts:
        if v.co.z < z0:
            v.co.z = z0
    if drop_bottom:
        dead = [f for f in bm.faces if all(v.co.z <= z0 + 1e-4 for v in f.verts)]
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")


def sit_on_ground(bm, extra=0.0):
    mn = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z += -mn + extra


def assign_mat(bm, fn):
    for f in bm.faces:
        f.material_index = fn(f)


def face_center(f):
    c = Vector((0, 0, 0))
    for v in f.verts:
        c += v.co
    return c / len(f.verts)


def xf_bm(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def merge(*bms):
    return L.bm_merge(*bms)


def _angdiff(a, b):
    d = (a - b + math.pi) % TAU - math.pi
    return d


def strata(bm, H, R, rng, seed=0, layers=7, segs=28, aspect=(1.0, 1.0), taper=None, lean=(0.0, 0.0), offset=(0.0, 0.0), recess=0.12,
           amp=0.07, kz=0.45, kth=1.4, gullies=(), skirt=0.0, skirt_h=0.0, mats=(0, 1, 2), cap_mat=None, skirt_mat=None,
           cap_extra=0.0, lobes=0.12, thickness_var=0.5, top_round=0.03, mat_noise=0.8, hard_cap=None, zamp=0.0, skirt_amp=1.8, soft_slope=0.0):
    """Layered (sedimentary) column / boulder / mesa built as a lathe with ledges.  Returns (rings, info).
    taper(f) -> radius multiplier for height fraction f.  gullies: [(theta0, width, depth, f0, f1)]."""
    tap = taper or (lambda f: 1.0)
    ts = [1.0 + rng.uniform(-thickness_var, thickness_var) for _ in range(layers)]
    tot = sum(ts)
    ts = [t / tot * (H - skirt_h) for t in ts]
    hard = [rng.random() for _ in range(layers)]
    phi1 = rng.random() * TAU
    phi2 = rng.random() * TAU
    prof = []
    pm = []
    lid = []
    if skirt_h > 0:
        for sx in (0.0, 0.28, 0.6, 1.0):
            z = skirt_h * sx
            prof.append((z, R * tap(z / H) * (1.0 + skirt * (1.0 - sx) ** 1.6)))
            pm.append(skirt_mat if skirt_mat is not None else mats[0])
            lid.append(-1)
    z0 = skirt_h
    nm = len(mats)
    for i in range(layers):
        t = ts[i]
        z1 = z0 + t
        p = 1.0 + (hard[i] - 0.5) * 2.0 * recess
        if i == layers - 1:
            p += cap_extra
        gi = (i / max(layers - 1, 1)) * (nm - 1) + rng.uniform(-mat_noise, mat_noise)
        mi = mats[int(clamp(round(gi), 0, nm - 1))]
        if i == layers - 1 and cap_mat is not None:
            mi = cap_mat
        sf = 1.0 if hard[i] < 0.42 else 0.0
        for (zz, k) in ((z0, 0.94 + sf * soft_slope), (z0 + 0.12 * t, 1.0 - sf * soft_slope * 0.15),
                        (z0 + 0.88 * t, 1.0 - sf * soft_slope * 0.55), (z1, 0.975 - sf * soft_slope * 0.8)):
            prof.append((zz, R * tap(zz / H) * p * k))
            pm.append(mi)
            lid.append(i)
        z0 = z1
    ztop = z0
    rt = prof[-1][1]
    for (dz, k) in ((0.0, 0.97), (top_round * 0.35, 0.9), (top_round * 0.75, 0.72), (top_round, 0.5)):
        prof.append((ztop + dz * H, rt * k))
        pm.append(pm[-1])
        lid.append(layers - 1)
    mat_rows = pm[:-1]
    ph = [rng.random() * TAU for _ in range(layers)]

    def zmod(th, z, r, i):
        if zamp <= 0 or lid[min(i, len(lid) - 1)] < 0:
            return 0.0
        L_ = lid[min(i, len(lid) - 1)]
        return zamp * (0.65 * math.cos(th + ph[L_]) + 0.35 * n3(math.cos(th) * 1.1, math.sin(th) * 1.1, L_ * 3.1, seed))

    def mod(th, z, r, i):
        f = z / H
        n = fbm3(math.cos(th) * kth, math.sin(th) * kth, z * kz, seed, 3)
        m = 1.0 + amp * n * (skirt_amp if lid[min(i, len(lid) - 1)] < 0 else 1.0) * (1.0 + (1.0 - clamp(f * 3.0)) * 0.6)
        m += lobes * (0.6 * math.cos(2 * th + phi1) + 0.4 * math.cos(3 * th + phi2))
        for (t0, w, dep, f0, f1) in gullies:
            d = _angdiff(th, t0)
            m -= dep * math.exp(-((d / w) ** 2)) * smoothstep(f0 - 0.04, f0 + 0.04, f) * (1.0 - smoothstep(f1 - 0.04, f1 + 0.04, f))
        return r * m

    def centre(z):
        f = z / H
        return (offset[0] + lean[0] * f * f, offset[1] + lean[1] * f * f)

    rings = lathe(bm, prof, segs=segs, mod=mod, centre=centre, cap_top="apex", cap_bottom=None, mat=0, mat_rows=mat_rows, aspect=aspect,
                  top_dome=0.0, zmod=zmod)
    return rings


def rubble(bm, rng, n, rmin, rmax, ring_r, mat=0, seed=0, subdiv=2, squash=0.65, jitter=0.0, centre=(0.0, 0.0), ring_min=0.0, zoff=0.0):
    """Scatter n noise-displaced boulders (half sunk into the ground) around `centre`."""
    out = []
    for i in range(n):
        r = rng.uniform(rmin, rmax)
        a = rng.random() * TAU
        d = rng.uniform(ring_min, ring_r)
        b = ico_blob((r, r * rng.uniform(0.8, 1.2), r * squash), subdiv, seed + i * 3, 0.28, 1.5, 3)
        plane_cut(b, random_planes(rng, 4, r * 0.8, jitter=0.3, up_bias=0.5))
        for v in b.verts:
            v.co += Vector((centre[0] + math.cos(a) * d, centre[1] + math.sin(a) * d, zoff + r * squash * 0.45))
        for f in b.faces:
            f.material_index = mat
        out.append(b)
    for b in out:
        merge(bm, b)
    return bm


def top_z(bm, x, y, rad=1.0):
    best = None
    for v in bm.verts:
        if (v.co.x - x) ** 2 + (v.co.y - y) ** 2 < rad * rad and (best is None or v.co.z > best):
            best = v.co.z
    return best if best is not None else 0.0


def clean_mask(bm, mat, base=0, min_same=1, fill=3):
    """Remove isolated specks of material `mat` (revert to `base`) and fill single-face holes."""
    for _ in range(2):
        bm.faces.ensure_lookup_table()
        off = []
        on = []
        for f in bm.faces:
            same = 0
            for e in f.edges:
                for g in e.link_faces:
                    if g is not f and g.material_index == mat:
                        same += 1
            if f.material_index == mat:
                if same < min_same:
                    off.append(f)
            elif f.material_index == base and same >= fill:
                on.append(f)
        for f in off:
            f.material_index = base
        for f in on:
            f.material_index = mat


def snow_cap(bm, snow_mat, thick=0.06, threshold=0.5, noise_amp=0.25, seed=0, freq=1.5, only_mats=None, smooth_iter=2):
    """Mark up-facing faces as snow (material index `snow_mat`) and push them outward by `thick` so the snow has volume.
    The up-facing score uses neighbour-averaged vertex normals so the mask forms coherent patches, not speckle."""
    bm.normal_update()
    vn = {v: v.normal.copy() for v in bm.verts}
    for _ in range(smooth_iter):
        nv = {}
        for v in bm.verts:
            acc = vn[v].copy()
            for e in v.link_edges:
                acc += vn[e.other_vert(v)]
            nv[v] = acc.normalized() if acc.length > 1e-6 else acc
        vn = nv
    sf = set()
    for f in bm.faces:
        if only_mats is not None and f.material_index not in only_mats:
            continue
        c = face_center(f)
        nz = sum(vn[v].z for v in f.verts) / len(f.verts)
        score = nz + noise_amp * n3(c.x * freq, c.y * freq, c.z * freq, seed)
        if score > threshold:
            sf.add(f)
    for v in bm.verts:
        fl = v.link_faces
        if not fl:
            continue
        k = sum(1 for f in fl if f in sf)
        if k:
            w = k / len(fl)
            v.co += v.normal * thick * (1.0 if w > 0.99 else w * 0.55)
    base = None
    for f in sf:
        if base is None:
            base = f.material_index
        f.material_index = snow_mat
    clean_mask(bm, snow_mat, 0 if base is None else base, 2, 3)
    return len(sf)


def surface_point(bm, u):
    """Vertex position furthest along direction u (approximate surface point)."""
    u = Vector(u).normalized()
    best = None
    bd = -1e9
    for v in bm.verts:
        d = v.co.dot(u)
        if d > bd:
            bd = d
            best = v.co.copy()
    return best


def faceted_rock(radius, subdiv=3, seed=0, amp=0.2, freq=1.4, planes=6, plane_dist=0.85, up_bias=0.2, rng=None, ridged=0.0,
                 bottom=0.5, sink=0.0, craters=(), crater_rim=0.2, octaves=3, fine=(0.0, 5.0)):
    """Noise-displaced ellipsoid chiselled by random planes (+ optional bowl craters), standing on z=0 with a flat (deleted) bottom.
    craters: [(count, rmin, rmax, depth)]."""
    rng = rng or random.Random(seed)
    bm = ico_blob(radius, subdiv, seed, amp, freq, octaves, ridged)
    pls = []
    for _ in range(planes):
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)))
        d.z += up_bias
        d.normalize()
        sup = math.sqrt((radius[0] * d.x) ** 2 + (radius[1] * d.y) ** 2 + (radius[2] * d.z) ** 2)
        pls.append((d * sup * plane_dist * rng.uniform(0.85, 1.0), d))
    plane_cut(bm, pls)
    for (cnt, rmin, rmax, depth) in craters:
        for _ in range(cnt):
            u = Vector((rng.gauss(0, 1), rng.gauss(0, 1), abs(rng.gauss(0, 0.8)) + 0.1)).normalized()
            c = surface_point(bm, u)
            crater(bm, u, c, rng.uniform(rmin, rmax), depth, crater_rim)
    if fine[0] > 0:
        bm.normal_update()
        for v in bm.verts:
            p = v.co
            v.co = p + v.normal * (fine[0] * fbm3(p.x * fine[1], p.y * fine[1], p.z * fine[1], seed + 7.7, 2))
    for v in bm.verts:
        v.co.z += radius[2] * bottom - sink
    flat_base(bm, 0.0, True)
    return bm


def vein_bands(bm, mat, direction, freq, width, noise_amp=0.3, seed=0, only_mats=None, nfreq=1.2):
    d = Vector(direction).normalized()
    n = 0
    for f in bm.faces:
        if only_mats is not None and f.material_index not in only_mats:
            continue
        c = face_center(f)
        s = c.dot(d) * freq + noise_amp * n3(c.x * nfreq, c.y * nfreq, c.z * nfreq, seed)
        if (s - math.floor(s)) < width:
            f.material_index = mat
            n += 1
    clean_mask(bm, mat, 0, 1, 3)
    return n


def under_mat(bm, mat, nz=-0.2, only_mats=None):
    """Faces looking downward -> material (cheap ambient-occlusion look)."""
    bm.normal_update()
    for f in bm.faces:
        if only_mats is not None and f.material_index not in only_mats:
            continue
        if f.normal.z < nz:
            f.material_index = mat


def crack(bm, point, normal, width, depth, centre=(0.0, 0.0, 0.0)):
    """Carve a groove along the plane (point, normal): vertices near the plane are pulled toward the centre."""
    n = Vector(normal).normalized()
    p = Vector(point)
    c = Vector(centre)
    for v in bm.verts:
        d = (v.co - p).dot(n)
        g = math.exp(-((d / width) ** 2))
        if g > 0.01:
            v.co = c + (v.co - c) * (1.0 - depth * g)


# ---------------------------------------------------------------------------------------------------------------
# details
# ---------------------------------------------------------------------------------------------------------------
def quad2(bm, p0, p1, p2, p3, mat=0, two_sided=True, thick=0.0):
    """A quad (and an independent flipped copy so it is visible from both sides)."""
    f = bm.faces.new([bm.verts.new(p) for p in (p0, p1, p2, p3)])
    f.material_index = mat
    if two_sided:
        n = (Vector(p1) - Vector(p0)).cross(Vector(p3) - Vector(p0)).normalized() * thick
        g = bm.faces.new([bm.verts.new(Vector(p) + n) for p in (p3, p2, p1, p0)])
        g.material_index = mat


def tri2(bm, p0, p1, p2, mat=0, two_sided=True):
    f = bm.faces.new([bm.verts.new(p) for p in (p0, p1, p2)])
    f.material_index = mat
    if two_sided:
        g = bm.faces.new([bm.verts.new(p) for p in (p2, p1, p0)])
        g.material_index = mat


def spine_tuft(bm, base, out, up, n=3, length=0.12, width=0.012, spread=0.5, mat=0, rng=None, two_sided=True):
    """Tiny cluster of needle spines: thin two-sided triangles fanning out from `base` along `out`."""
    out = Vector(out).normalized()
    up = Vector(up).normalized()
    side = out.cross(up)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    for i in range(n):
        a = (i / max(n - 1, 1) - 0.5) * 2.0 * spread
        e = 0.35 * (i % 2)
        d = (out + side * a + up * (e - 0.25)).normalized()
        tip = Vector(base) + d * length * (0.8 + 0.4 * (rng.random() if rng else 0.5))
        w = side * width
        tri2(bm, Vector(base) - w, Vector(base) + w, tip, mat, two_sided)


def blade(bm, base, azimuth, length, width, lean, curve, mat=0, segs=3, tip_mat=None, thick=0.0):
    """Two-sided grass blade: ribbon that leans out along `azimuth` (radians) and bends over by `curve`."""
    base = Vector(base)
    dirh = Vector((math.cos(azimuth), math.sin(azimuth), 0.0))
    side = Vector((-math.sin(azimuth), math.cos(azimuth), 0.0))
    pos = [base]
    step = length / segs
    cur = base.copy()
    for i in range(segs):
        t = i / segs
        a = lean + curve * t
        cur = cur + (dirh * math.sin(a) + Vector((0, 0, 1)) * math.cos(a)) * step
        pos.append(cur.copy())
    for i in range(segs):
        w0 = width * (1.0 - i / segs) ** 0.9
        w1 = width * (1.0 - (i + 1) / segs) ** 0.9
        m = mat if (tip_mat is None or i < segs - 1) else tip_mat
        a, b = pos[i], pos[i + 1]
        if i == segs - 1:
            tri2(bm, a - side * w0, a + side * w0, b, m, True)
        else:
            quad2(bm, a - side * w0, a + side * w0, b + side * w1, b - side * w1, m, True)


def crystal(bm, base, direction, length, radius, sides=6, tip=0.28, mat=0, taper=0.88, rng=None, jitter=0.1, bevel=0.0,
            tip_mat=None, base_cap=False):
    """Hexagonal-prism crystal with a chiselled pyramid tip.  base/direction in model space."""
    rng = rng or random.Random(0)
    d = Vector(direction).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    base = Vector(base)
    tip_len = length * tip
    body = length - tip_len
    a0 = rng.random() * TAU
    rings = []
    rad_j = [1.0 + rng.uniform(-jitter, jitter) for _ in range(sides)]
    for (h, rs) in ((0.0, 1.0), (body * 0.5, 1.0 - (1.0 - taper) * 0.4), (body, taper)):
        ring = []
        for k in range(sides):
            th = a0 + TAU * k / sides
            rr = radius * rs * rad_j[k]
            ring.append(base + d * h + u * (math.cos(th) * rr) + v * (math.sin(th) * rr))
        rings.append(ring)
    # chamfer ring near the tip
    ring = []
    for k in range(sides):
        th = a0 + TAU * k / sides
        rr = radius * taper * 0.62 * rad_j[k]
        ring.append(base + d * (body + tip_len * 0.55) + u * (math.cos(th) * rr) + v * (math.sin(th) * rr))
    rings.append(ring)
    apex = base + d * length + u * (radius * jitter * rng.uniform(-1, 1)) + v * (radius * jitter * rng.uniform(-1, 1))
    mrows = [mat, mat, mat, tip_mat if tip_mat is not None else mat]
    loft(bm, rings, True, "flat" if base_cap else None, apex, mat, mat_rows=mrows)


def add_cone(bm, base, direction, length, radius, segs=6, mat=0, bend=None, rng=None, jitter=0.0, base_cap=True):
    d = Vector(direction).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    ring = []
    rng = rng or random.Random(0)
    for k in range(segs):
        th = TAU * k / segs
        rr = radius * (1.0 + rng.uniform(-jitter, jitter))
        ring.append(Vector(base) + u * (math.cos(th) * rr) + v * (math.sin(th) * rr))
    apex = Vector(base) + d * length
    loft(bm, [ring, [r.lerp(apex, 0.999) for r in ring]], True, "flat" if base_cap else None, apex, mat)


def extend_dome(path, radii, h, steps=4):
    """Append hemispherical-dome rings to a path/radii list (end cap).  Returns (path, radii, tip_b) for tube(cap_b='apex')."""
    path = [Vector(p) for p in path]
    radii = list(radii)
    t = (path[-1] - path[-2]).normalized()
    P = path[-1].copy()
    R = radii[-1]
    a = 0.0
    for i in range(1, steps + 1):
        a = (i / steps) * (math.pi / 2) * 0.93
        path.append(P + t * (h * math.sin(a)))
        radii.append(R * math.cos(a))
    tip_b = h - h * math.sin(a)
    return path, radii, tip_b


def flower(bm, pos, normal, size, mat=0, rng=None, petals=5, cup=0.55, two_sided=True, center_mat=None, center_size=0.3):
    rng = rng or random.Random(0)
    n = Vector(normal).normalized()
    ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    u = n.cross(ref).normalized()
    v = n.cross(u).normalized()
    pos = Vector(pos)
    a0 = rng.random() * TAU
    for i in range(petals):
        a = a0 + TAU * i / petals
        dp = u * math.cos(a) + v * math.sin(a)
        sd = -u * math.sin(a) + v * math.cos(a)
        tip = pos + dp * size + n * size * cup
        l = pos + dp * (0.5 * size) + sd * (0.4 * size) + n * (0.12 * size)
        r = pos + dp * (0.5 * size) - sd * (0.4 * size) + n * (0.12 * size)
        quad2(bm, pos + n * 0.004, l, tip, r, mat, two_sided)
    if center_mat is not None:
        top = pos + n * (size * 0.22)
        ring = [pos + n * (size * 0.08) + (u * math.cos(TAU * k / 6) + v * math.sin(TAU * k / 6)) * size * center_size for k in range(6)]
        cv = bm.verts.new(top)
        rv = [bm.verts.new(p) for p in ring]
        for k in range(6):
            f = bm.faces.new((cv, rv[k], rv[(k + 1) % 6]))
            f.material_index = center_mat


# ---------------------------------------------------------------------------------------------------------------
# object / export helpers
# ---------------------------------------------------------------------------------------------------------------
def build_obj(name, bm, col, mats, smooth_deg=35, flat_mats=(), all_flat=False, backface_cull_mats=()):
    ob = L.obj_from_bm(name, bm, col, mats, smooth=not all_flat)
    if not all_flat and smooth_deg:
        L.set_smooth_by_angle(ob, smooth_deg)
    if flat_mats:
        for p in ob.data.polygons:
            if p.material_index in flat_mats:
                p.use_smooth = False
    return ob


def mat_dbl(name, color, roughness=0.7, **kw):
    """Material for single-sided thin geometry (needles, petals, leaf cards): double sided (backface culling explicitly OFF)."""
    m = L.mat(name, color, roughness=roughness, **kw)
    m.use_backface_culling = False
    return m


def mat_foliage(name, color, roughness=0.7, **kw):
    """Material for hand-modelled two-sided foliage: backface culling ON (both sides are modelled)."""
    m = L.mat(name, color, roughness=roughness, **kw)
    m.use_backface_culling = True
    return m


def manifest_add(mid, kind, biomes, objs, collider, tintable=None, notes="", nodes=None, file=None):
    mn, mx = L.bounds(objs)
    sz = mx - mn
    if collider.get("shape") in ("cylinder", "sphere", "box"):
        h = collider.get("height", collider.get("size", [0, sz.z, 0])[1] if collider.get("shape") == "box" else 0)
        collider = dict(collider)
        collider["center_y"] = round(collider.get("offset_y", 0.0) + (h if collider["shape"] != "sphere" else 0) * 0.5 +
                                     (collider.get("radius", 0) if collider["shape"] == "sphere" else 0), 3)
    entry = {
        "id": mid,
        "file": file or (mid + ".glb"),
        "kind": kind,
        "biomes": biomes,
        "size": [round(sz.x, 3), round(sz.z, 3), round(sz.y, 3)],
        "base_y": round(mn.z, 3),
        "collider": collider,
        "tris": L.tri_count(objs),
        "tintable": tintable or [],
        "notes": notes,
    }
    if nodes:
        entry["nodes"] = nodes
    data = {"group": GROUP, "models": []}
    if os.path.exists(MANIFEST):
        try:
            with open(MANIFEST, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            pass
    data["models"] = [m for m in data.get("models", []) if m.get("id") != mid]
    data["models"].append(entry)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return entry


def apply_variant(bm, ovr):
    """Variant support: uniform scale (+ optional mirror in X) applied to the finished bmesh."""
    sc = ovr.get("scale", 1.0)
    mir = ovr.get("mirror", False)
    if sc != 1.0 or mir:
        m = Matrix.Diagonal(Vector((sc * (-1.0 if mir else 1.0), sc, sc, 1.0)))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        if mir:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return bm


def vc(collider, ovr):
    """Scale a collider dict for a variant."""
    sc = ovr.get("scale", 1.0)
    c = dict(collider)
    for k in ("radius", "height", "offset_y"):
        if k in c:
            c[k] = round(c[k] * sc, 3)
    if "size" in c:
        c["size"] = [round(x * sc, 3) for x in c["size"]]
    return c


def preview_only(objs, name, **kw):
    """L.preview, but every object that is not part of `objs` (other agents' models share this scene) is hidden for the render."""
    mine = set()

    def add(o):
        mine.add(o)
        for c in o.children:
            add(c)

    for o in objs:
        add(o)
    hidden = []
    for o in bpy.data.objects:
        if o not in mine and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    try:
        return L.preview(objs, name, **kw)
    finally:
        for o in hidden:
            try:
                o.hide_render = False
            except Exception:
                pass


def finish(mid, objs, kind, biomes, collider, tintable=None, notes="", nodes=None, preview=True, views=None, cols=3,
           size=(480, 400), dist_mult=1.9, export=True, bg=(0.10, 0.12, 0.16)):
    L.report(objs, mid)
    if os.environ.get("FLORA2_NO_PREVIEW"):
        preview = False   # GPU-friendly rebuilds: skip the Blender EEVEE contact sheet (verify in the Godot viewer instead)
    if preview:
        kw = {}
        if views:
            kw["views"] = views
        paths = preview_only(objs, mid, size=size, dist_mult=dist_mult, bg=bg, **kw)
        print("montage:", L.montage(paths, mid + "_sheet", cols=cols))
    if export:
        print("exported:", L.export_glb(objs, mid))
        manifest_add(mid, kind, biomes, objs, collider, tintable, notes, nodes)
    L.save_blend()
