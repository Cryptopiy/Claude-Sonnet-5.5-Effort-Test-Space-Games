"""flora1_lib.py - helper layer for the flora1 group (lush / swamp / ocean / exotic flora).

Use from a model script (run with `python tools/bmcp.py file blender/flora1_<model>.py`):

    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import lib_common as L; importlib.reload(L)
    import flora1_lib as F; importlib.reload(F)

Everything here only builds geometry in a private bmesh; nothing touches other agents' data.
Conventions: Blender Z up, 1 unit = 1 m, origin at ground contact.
"""
import sys
import os
import math
import random
import json

BLENDER_DIR = r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender"
if BLENDER_DIR not in sys.path:
    sys.path.insert(0, BLENDER_DIR)

import bpy
import bmesh
import lib_common as L
from mathutils import Vector, Matrix, Euler, noise

Z = Vector((0, 0, 1))
X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
TAU = math.tau


# ----------------------------------------------------------------------------------------------------------------
# colour / material helpers
# ----------------------------------------------------------------------------------------------------------------
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def srgb(h, gain=1.0):
    """'#rrggbb' (sRGB, what you see in a colour picker) -> linear RGB tuple for Blender/glTF."""
    h = h.lstrip("#")
    r, g, b = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return (_lin(r) * gain, _lin(g) * gain, _lin(b) * gain)


def M(name, color, rough=0.7, metal=0.0, emit=None, emit_strength=0.0, alpha=1.0, spec=0.5, cull=True):
    """Principled material from sRGB hex colours. Backface culling is ON by default (foliage is modelled two-sided)."""
    col = srgb(color) if isinstance(color, str) else color
    ec = srgb(emit) if isinstance(emit, str) else emit
    m = L.mat(name, col, metallic=metal, roughness=rough, emission=ec, emission_strength=emit_strength, alpha=alpha,
              specular=spec)
    try:
        m.use_backface_culling = cull
    except Exception:
        pass
    return m


# ----------------------------------------------------------------------------------------------------------------
# small math helpers
# ----------------------------------------------------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a)) if b != a else 0.0
    return t * t * (3 - 2 * t)


def spline(pts, n=6):
    """Catmull-Rom curve passing through pts, n samples per segment. Returns list of Vectors."""
    P = [Vector(p) for p in pts]
    if len(P) < 3:
        out = []
        for i in range(n * (len(P) - 1)):
            t = i / float(n * (len(P) - 1))
            out.append(P[0].lerp(P[-1], t))
        out.append(P[-1])
        return out
    ext = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(n):
            t = s / float(n)
            out.append(0.5 * ((p1 * 2) + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (t * t) +
                              (p1 * 3 - p0 - p2 * 3 + p3) * (t * t * t)))
    out.append(P[-1])
    return out


def polyline_at(pts, t):
    """Position and unit tangent at arc-length fraction t (0..1) of a polyline."""
    P = [Vector(p) for p in pts]
    lens = [(P[i + 1] - P[i]).length for i in range(len(P) - 1)]
    total = sum(lens)
    target = clamp(t) * total
    acc = 0.0
    for i, l in enumerate(lens):
        if acc + l >= target or i == len(lens) - 1:
            u = (target - acc) / l if l > 1e-9 else 0.0
            u = clamp(u)
            return P[i].lerp(P[i + 1], u), (P[i + 1] - P[i]).normalized()
        acc += l
    return P[-1], (P[-1] - P[-2]).normalized()


def rand_unit(rng):
    while True:
        v = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        if 0.05 < v.length_squared <= 1.0:
            return v.normalized()


def fbm(p, octaves=2, lac=2.1, gain=0.5):
    s = 0.0
    a = 1.0
    f = 1.0
    for _ in range(octaves):
        s += a * noise.noise(p * f)
        a *= gain
        f *= lac
    return s


def aim(direction, up=Z):
    """Rotation matrix (3x3) whose local +Z points along direction (for building things along +Z then orienting)."""
    d = Vector(direction).normalized()
    q = Z.rotation_difference(d)
    return q.to_matrix()


# ----------------------------------------------------------------------------------------------------------------
# mesh builder
# ----------------------------------------------------------------------------------------------------------------
class TubeInfo(object):
    def __init__(self, rings, pts, T, R, apex=None):
        self.rings = rings
        self.pts = pts
        self.T = T
        self.R = R
        self.apex = apex


class Builder(object):
    """Collects geometry in one bmesh with material indices. mats = list of materials (slot order)."""

    def __init__(self, mats, seed=1):
        self.bm = bmesh.new()
        self.mats = list(mats)
        self.rng = random.Random(seed)
        self.flat = set()  # material indices that are flat shaded (crystals / hard faces)

    # -- low level -------------------------------------------------------------------------------------------
    def _face(self, verts, mat):
        try:
            f = self.bm.faces.new(verts)
            f.material_index = mat
            return f
        except ValueError:
            return None

    def tri(self, a, b, c, mat=0):
        return self._face((a, b, c), mat)

    def quad(self, a, b, c, d, mat=0):
        return self._face((a, b, c, d), mat)

    def vert(self, p):
        return self.bm.verts.new(Vector(p))

    # -- tapered tube along a polyline ---------------------------------------------------------------------------
    def tube(self, pts, radii, segs=8, mat=0, cap0=False, cap1=True, apex=None, ell=1.0, rmod=None, up=None,
             nz=0.0, nf=1.0, seed=0, ang0=0.0, twist=0.0):
        """Tube along `pts` (list of points, >=2). radii: number | (r0, r1) | list | callable(t).
        mat: int or callable(ring_index, seg_index). rmod(t, angle, k) multiplies the radius (ridges, bumps).
        apex: Vector (absolute) or float (distance beyond the last point along the tangent) -> pointed tip.
        nz/nf: radial noise amount/frequency (gnarly bark). Returns TubeInfo."""
        bm = self.bm
        P = [Vector(p) for p in pts]
        n = len(P)
        if isinstance(radii, (int, float)):
            radii = (radii, radii)
        if callable(radii):
            R = [radii(i / float(n - 1)) for i in range(n)]
        elif len(radii) == 2 and n != 2:
            R = [lerp(radii[0], radii[1], i / float(n - 1)) for i in range(n)]
        else:
            R = list(radii)
        T = []
        for i in range(n):
            if i == 0:
                t = P[1] - P[0]
            elif i == n - 1:
                t = P[-1] - P[-2]
            else:
                t = P[i + 1] - P[i - 1]
            if t.length < 1e-9:
                t = T[-1].copy() if T else Z.copy()
            T.append(t.normalized())
        ref = Vector(up) if up is not None else Z.copy()
        if abs(T[0].dot(ref)) > 0.92:
            ref = X.copy() if abs(T[0].dot(X)) < 0.9 else Y.copy()
        N = ref - T[0] * ref.dot(T[0])
        N.normalize()
        off = Vector((seed * 13.7, seed * 7.1, seed * 3.3))
        rings = []
        for i in range(n):
            if i > 0:
                N = N - T[i] * N.dot(T[i])
                if N.length < 1e-6:
                    N = T[i].orthogonal()
                N.normalize()
            B = T[i].cross(N)
            ring = []
            for k in range(segs):
                a = ang0 + TAU * k / segs + twist * (i / float(n - 1))
                r = R[i]
                dirv = N * (math.cos(a) * ell) + B * math.sin(a)
                if rmod is not None:
                    r *= rmod(i / float(n - 1), a, k)
                if nz:
                    r *= 1.0 + nz * noise.noise((P[i] + dirv * r) * nf + off)
                ring.append(bm.verts.new(P[i] + dirv * r))
            rings.append(ring)
        for i in range(n - 1):
            a, b = rings[i], rings[i + 1]
            for k in range(segs):
                k1 = (k + 1) % segs
                m = mat(i, k) if callable(mat) else mat
                self._face((a[k], a[k1], b[k1], b[k]), m)
        m0 = mat(0, 0) if callable(mat) else mat
        m1 = mat(n - 2, 0) if callable(mat) else mat
        if cap0:
            c0 = bm.verts.new(P[0])
            for k in range(segs):
                self._face((c0, rings[0][(k + 1) % segs], rings[0][k]), m0)
        apex_v = None
        if apex is not None:
            if isinstance(apex, (int, float)):
                ap = P[-1] + T[-1] * apex
            else:
                ap = Vector(apex)
            apex_v = bm.verts.new(ap)
            for k in range(segs):
                self._face((apex_v, rings[-1][k], rings[-1][(k + 1) % segs]), m1)
        elif cap1:
            c1 = bm.verts.new(P[-1])
            for k in range(segs):
                self._face((c1, rings[-1][k], rings[-1][(k + 1) % segs]), m1)
        return TubeInfo(rings, P, T, R, apex_v)

    def branch(self, start, direction, length, r0, r1, bend=None, bend_amt=0.0, wobble=0.0, steps=6, segs=7, mat=0,
               nz=0.0, nf=1.0, seed=0, cap1=True, apex=None, rmod=None, curl=None):
        """Curved tapered limb. bend: world vector the limb curves towards (e.g. +Z for upward, -Z droop).
        Returns (end_point, end_tangent, TubeInfo). curl: (axis Vector, total angle) extra rotation along the limb."""
        rng = self.rng
        d = Vector(direction).normalized()
        p = Vector(start)
        pts = [p.copy()]
        seg_len = length / steps
        for i in range(steps):
            if bend is not None:
                d = (d + Vector(bend).normalized() * (bend_amt / steps)).normalized()
            if wobble:
                d = (d + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * wobble).normalized()
            if curl is not None:
                axis, ang = curl
                d = (Matrix.Rotation(ang / steps, 3, axis) @ d).normalized()
            p = p + d * seg_len
            pts.append(p.copy())
        info = self.tube(pts, (r0, r1), segs=segs, mat=mat, cap1=cap1, apex=apex, nz=nz, nf=nf, seed=seed, rmod=rmod)
        return p, d, info

    # -- noisy blobs (canopies, rocks, bulbs) -------------------------------------------------------------------------
    def blob(self, c, r, subdiv=2, amt=0.18, freq=1.2, seed=0, mat=0, matfn=None, squash=1.0, flat_bottom=0.0,
             rot=None, oct2=0.5, stretch=None):
        """Displaced icosphere centred at c with radius r (number or (rx, ry, rz)). matfn(normal, centre)->mat index.
        Returns list of (position, normal) of the created vertices (handy for scattering leaf cards / spikes)."""
        bm = self.bm
        if isinstance(r, (int, float)):
            rv = Vector((r, r, r * squash))
        else:
            rv = Vector(r)
        res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        verts = res["verts"]
        faces = set()
        for v in verts:
            for f in v.link_faces:
                faces.add(f)
        off = Vector((seed * 17.3, seed * 5.7, seed * 11.1))
        c = Vector(c)
        out = []
        for v in verts:
            u = v.co.normalized()
            d = noise.noise(u * freq + off) + oct2 * noise.noise(u * freq * 2.3 + off * 1.7)
            s = 1.0 + amt * d
            p = Vector((u.x * rv.x * s, u.y * rv.y * s, u.z * rv.z * s))
            if flat_bottom and p.z < -flat_bottom * rv.z:
                p.z = -flat_bottom * rv.z + (p.z + flat_bottom * rv.z) * 0.3
            if rot is not None:
                p = rot @ p
            v.co = c + p
        for v in verts:
            out.append((v.co.copy(), (v.co - c).normalized()))
        for f in faces:
            f.normal_update()
            f.material_index = matfn(f.normal.copy(), f.calc_center_median()) if matfn else mat
        return out

    # -- leaves and surfaces -----------------------------------------------------------------------------------
    def leaf(self, base, d, length, width, mat=0, up=Z, fold=0.18, droop=0.25, roll=0.0, double=True, mid=0.42):
        """Folded 4-triangle leaf (two-sided). d: growth direction. fold>0 = ridge up (tent), <0 = valley."""
        d = Vector(d).normalized()
        base = Vector(base)
        w = d.cross(up)
        if w.length < 1e-4:
            w = d.cross(X)
        w.normalize()
        n = w.cross(d)
        if roll:
            rm = Matrix.Rotation(roll, 3, d)
            w = rm @ w
            n = rm @ n
        B = base
        M_ = base + d * (length * mid) + n * (width * fold)
        L_ = base + d * (length * (mid + 0.04)) + w * (width * 0.5) - n * (width * fold * 0.5)
        R_ = base + d * (length * (mid + 0.04)) - w * (width * 0.5) - n * (width * fold * 0.5)
        T_ = base + d * (length * 0.97) - Z * (droop * length)
        bm = self.bm
        v = [bm.verts.new(p) for p in (B, L_, M_, R_, T_)]
        b, l, m, r, t = v
        self.tri(b, l, m, mat)
        self.tri(b, m, r, mat)
        self.tri(l, t, m, mat)
        self.tri(m, t, r, mat)
        if double:
            v2 = [bm.verts.new(p) for p in (B, L_, M_, R_, T_)]
            b, l, m, r, t = v2
            self.tri(b, m, l, mat)
            self.tri(b, r, m, mat)
            self.tri(l, m, t, mat)
            self.tri(m, r, t, mat)

    def surface(self, grid, mat=0, double=True, matfn=None):
        """Quad surface from a grid[i][j] of Vectors. Front normal = (dj) x (di). Consecutive duplicate points collapse
        a quad into a triangle (use for pointed tips). matfn(i, j) -> mat index per quad."""
        bm = self.bm
        rows = len(grid)
        cols = len(grid[0])
        for side in ((0, 1) if double else (0,)):
            V = [[bm.verts.new(Vector(grid[i][j])) for j in range(cols)] for i in range(rows)]
            for i in range(rows - 1):
                for j in range(cols - 1):
                    q = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
                    uniq = []
                    for (a, b) in q:
                        if uniq and (grid[a][b] - grid[uniq[-1][0]][uniq[-1][1]]).length < 1e-6:
                            continue
                        uniq.append((a, b))
                    if len(uniq) > 1 and (grid[uniq[0][0]][uniq[0][1]] - grid[uniq[-1][0]][uniq[-1][1]]).length < 1e-6:
                        uniq.pop()
                    if len(uniq) < 3:
                        continue
                    vs = [V[a][b] for (a, b) in uniq]
                    if side == 1:
                        vs.reverse()
                    m = matfn(i, j) if matfn else mat
                    self._face(tuple(vs), m)

    def ribbon(self, pts, widths, normal_hint=Z, mat=0, double=True, tip=True, matfn=None):
        """Flat strip along pts (like a blade / vine ribbon). widths: list/(w0,w1)/callable(t). Width axis =
        tangent x normal_hint. Last row collapses to a point when tip=True."""
        P = [Vector(p) for p in pts]
        n = len(P)
        if isinstance(widths, (int, float)):
            widths = (widths, widths)
        if callable(widths):
            W = [widths(i / float(n - 1)) for i in range(n)]
        elif len(widths) == 2 and n != 2:
            W = [lerp(widths[0], widths[1], i / float(n - 1)) for i in range(n)]
        else:
            W = list(widths)
        grid = []
        for i in range(n):
            if i == 0:
                t = P[1] - P[0]
            elif i == n - 1:
                t = P[-1] - P[-2]
            else:
                t = P[i + 1] - P[i - 1]
            t.normalize()
            w = t.cross(normal_hint)
            if w.length < 1e-4:
                w = t.cross(X)
            w.normalize()
            if tip and i == n - 1:
                grid.append([P[i], P[i]])
            else:
                grid.append([P[i] - w * (W[i] * 0.5), P[i] + w * (W[i] * 0.5)])
        # surface(): front normal = dj x di  (dj = across, di = along)
        self.surface(grid, mat=mat, double=double, matfn=matfn)

    def crystal(self, base, d, length, radius, sides=6, tip=0.28, taper=0.8, mat=0, jitter=0.12, cap0=True, seed=0):
        """Hexagonal-ish crystal shard: prism from base along d, pointed tip. Flat-shade the material you pass."""
        d = Vector(d).normalized()
        base = Vector(base)
        rng = random.Random(seed + 77)
        body = length * (1.0 - tip)
        jit = [1.0 + rng.uniform(-jitter, jitter) for _ in range(sides)]
        pts = [base, base + d * (body * 0.5), base + d * body]
        rr = (radius, radius * lerp(1, taper, 0.5), radius * taper)
        return self.tube(pts, rr, segs=sides, mat=mat, cap0=cap0, apex=base + d * length,
                         rmod=lambda t, a, k: jit[k % sides], ang0=rng.uniform(0, TAU))

    # -- foliage cluster (blob core + satellite blobs + leaf cards) ------------------------------------------------------
    def canopy_cluster(self, centre, rad, mats, seed=0, squash=0.78, subdiv=2, amt=0.22, freq=1.2, n_sat=2,
                       sat_scale=(0.55, 0.7), n_fringe=9, n_top=6, leaf_len=(0.8, 1.2), leaf_w=0.55, flat_bottom=0.5,
                       droop=0.3, bands=(-0.3, 0.3), top_leaf_scale=0.8, sat_spread=0.8, sat_subdiv=2, fringe_zmin=-1.0, fringe_down=0.45):
        """mats = (dark, mid, light) material indices. Returns list of (pos, normal) of the core blob (for fruit etc.)."""
        rng = self.rng
        dark, mid, light = mats
        centre = Vector(centre)
        sx = Vector((seed * 3.1, 0.0, 0.0))

        def make_fn(c, rz):
            def fn(nrm, ctr):
                h = (ctr.z - c.z) / max(rz, 1e-3)
                s = h + 0.4 * noise.noise(ctr * 0.7 + sx)
                return dark if s < bands[0] else (mid if s < bands[1] else light)
            return fn

        verts = self.blob(centre, rad, subdiv=subdiv, amt=amt, freq=freq, seed=seed, matfn=make_fn(centre, rad * squash),
                          squash=squash, flat_bottom=flat_bottom)
        for s in range(n_sat):
            ang = rng.uniform(0, TAU)
            off = Vector((math.cos(ang), math.sin(ang), rng.uniform(-0.15, 0.4))) * (rad * sat_spread)
            sr = rad * rng.uniform(*sat_scale)
            sc = centre + off
            self.blob(sc, sr, subdiv=sat_subdiv, amt=amt * 1.1, freq=freq * 1.3, seed=seed * 5 + s + 40,
                      matfn=make_fn(sc, sr * squash), squash=squash, flat_bottom=flat_bottom)
        cand = [(p, n) for (p, n) in verts if fringe_zmin < n.z < 0.45]
        rng.shuffle(cand)
        for (p, n) in cand[:n_fringe]:
            dl = (n + Vector((0, 0, -fringe_down))).normalized()
            self.leaf(p - n * 0.08, dl, rng.uniform(*leaf_len), rng.uniform(*leaf_len) * leaf_w,
                      mat=dark if n.z < 0.0 else mid, fold=0.22, droop=droop, roll=rng.uniform(-0.5, 0.5))
        cand = [(p, n) for (p, n) in verts if n.z >= 0.2]
        rng.shuffle(cand)
        for (p, n) in cand[:n_top]:
            dl = (n * 1.0 + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0.0))).normalized()
            ll = rng.uniform(*leaf_len) * top_leaf_scale
            self.leaf(p - n * 0.1, dl, ll, ll * leaf_w, mat=light if n.z > 0.5 else mid, fold=0.25, droop=droop * 0.5,
                      roll=rng.uniform(-0.6, 0.6))
        return verts

    def blade(self, base, d, length, width, mat=0, up=Z, droop=0.0, mid=0.4, double=True):
        """Flat 2-triangle diamond leaflet (4 tris when two-sided). Front normal = w x d with w = d x up."""
        d = Vector(d).normalized()
        base = Vector(base)
        w = d.cross(up)
        if w.length < 1e-4:
            w = d.cross(X)
        w.normalize()
        L_ = base + d * (length * mid) + w * (width * 0.5)
        R_ = base + d * (length * mid) - w * (width * 0.5)
        T_ = base + d * length - Z * (droop * length)
        bm = self.bm
        b, l, t, r = [bm.verts.new(p) for p in (base, L_, T_, R_)]
        self.tri(b, l, t, mat)
        self.tri(b, t, r, mat)
        if double:
            b, l, t, r = [bm.verts.new(p) for p in (base, L_, T_, R_)]
            self.tri(b, t, l, mat)
            self.tri(b, r, t, mat)

    def paint_by_normal(self, from_mat, to_mat, zmin, noise_amt=0.0, nscale=1.0, seed=0):
        """Re-assign faces of material `from_mat` whose (noisy) normal.z exceeds zmin to `to_mat` (moss on top, etc.)."""
        off = Vector((seed * 3.3, seed * 1.7, seed * 2.9))
        for f in self.bm.faces:
            if f.material_index != from_mat:
                continue
            f.normal_update()
            c = f.calc_center_median()
            v = f.normal.z + (noise_amt * noise.noise(c * nscale + off) if noise_amt else 0.0)
            if v > zmin:
                f.material_index = to_mat

    def ground(self, z=0.0):
        """Translate everything so that the lowest vertex sits at height z."""
        mn = min(v.co.z for v in self.bm.verts)
        for v in self.bm.verts:
            v.co.z += (z - mn)

    def clamp_min_z(self, zmin):
        for v in self.bm.verts:
            if v.co.z < zmin:
                v.co.z = zmin

    # -- finish ------------------------------------------------------------------------------------------------
    def finish(self, name, col, flat_mats=(), smooth=True, shade_angle=None):
        bm = self.bm
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        self.bm = None
        for m in self.mats:
            me.materials.append(m)
        flat = set(flat_mats) | self.flat
        for p in me.polygons:
            p.use_smooth = bool(smooth) and (p.material_index not in flat)
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        if shade_angle is not None:
            L.set_smooth_by_angle(ob, shade_angle)
            if flat:
                for p in me.polygons:
                    if p.material_index in flat:
                        p.use_smooth = False
        return ob


# ----------------------------------------------------------------------------------------------------------------
# publish: report + preview + export + manifest + save
# ----------------------------------------------------------------------------------------------------------------
MANIFEST = os.path.join(L.MODELS_DIR, "manifest_flora1.json")
VIEWS6 = ((35, 18), (125, 18), (215, 18), (305, 18), (0, 82), (80, 2))


def manifest_add(entry):
    data = {"group": "flora1", "models": []}
    if os.path.exists(MANIFEST):
        try:
            with open(MANIFEST, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            pass
    data["models"] = [m for m in data.get("models", []) if m.get("id") != entry["id"]]
    data["models"].append(entry)
    order = {}
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return MANIFEST


def new_collection(name):
    """Fresh (emptied) collection `name`, guaranteed to be linked to the scene and enabled in the view layer."""
    col = L.fresh_collection(name)
    sc = bpy.context.scene
    if col.name not in [c.name for c in sc.collection.children]:
        try:
            sc.collection.children.link(col)
        except Exception:
            pass
    ensure_enabled(col)
    return col


def ensure_enabled(col):
    """Make sure the collection is not excluded / hidden in the current view layer (other agents may toggle layers)."""
    def walk(lc):
        if lc.collection == col:
            lc.exclude = False
            lc.hide_viewport = False
            return True
        for c in lc.children:
            if walk(c):
                return True
        return False
    try:
        walk(bpy.context.view_layer.layer_collection)
    except Exception:
        pass


def isolated_preview(meshes, name, **kw):
    """L.preview, but every object that is not part of `meshes` is hidden from the render meanwhile (other agents share
    this Blender scene), then restored."""
    mine = set(meshes)
    hidden = []
    for o in bpy.data.objects:
        if o not in mine and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    try:
        return L.preview(meshes, name, **kw)
    finally:
        for o in hidden:
            try:
                o.hide_render = False
            except Exception:
                pass


def publish(model_id, objects, kind, biomes, collider, tintable=(), notes="", preview=True, export=True,
            views=VIEWS6, dist_mult=1.9, cols=3, size=(480, 400), ground=True, sun_energy=3.5):
    """Report, preview montage, glb export, manifest entry, save. Returns dict with the numbers."""
    objs = list(objects)
    allm = []

    def collect(o):
        allm.append(o)
        for c in o.children:
            collect(c)

    for o in objs:
        collect(o)
    meshes = [o for o in allm if o.type == "MESH"]
    for o in allm:
        for c in o.users_collection:
            ensure_enabled(c)
    tris = L.tri_count(meshes)
    mn, mx = L.bounds(meshes)
    sz = mx - mn
    print("[%s] tris=%d blender-size(x,y,z)=(%.2f, %.2f, %.2f) min_z=%.3f max_z=%.3f" % (model_id, tris, sz.x, sz.y, sz.z, mn.z, mx.z))
    if preview:
        paths = isolated_preview(meshes, model_id, views=views, size=size, dist_mult=dist_mult, ground=ground, sun_energy=sun_energy)
        print(L.montage(paths, model_id + "_sheet", cols=cols))
    info = {"tris": tris, "size": [round(sz.x, 2), round(sz.z, 2), round(sz.y, 2)], "base_y": round(mn.z, 3)}
    if export:
        print(L.export_glb(objs, model_id))
        entry = {
            "id": model_id,
            "file": model_id + ".glb",
            "kind": kind,
            "biomes": list(biomes),
            "size": info["size"],
            "base_y": info["base_y"],
            "collider": collider,
            "tris": tris,
            "tintable": list(tintable),
            "nodes": {"mesh": [model_id + "_mesh"]},
            "notes": notes,
        }
        manifest_add(entry)
    L.save_blend()
    return info
