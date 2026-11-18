"""structures_common - hard-surface helpers shared by all `structures_*.py` scripts (group `structures`).

Usage at the top of every script:
    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import lib_common as L; importlib.reload(L)
    import structures_common as S; importlib.reload(S)

Everything is built in one bmesh per Blender object (class MB), with named material keys.
Blender Z up, model front = +Y.  Origin = ground contact.
"""
import sys
import os
import math
import json
import random

sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy
import bmesh
import lib_common as L
from mathutils import Vector, Matrix, Euler, noise

PROJECT = L.PROJECT
MANIFEST_PATH = PROJECT + r"\assets\models\manifest_structures.json"
PI = math.pi
TAU = math.tau


# ----------------------------------------------------------------------------------------------------------------
# small math helpers
# ----------------------------------------------------------------------------------------------------------------
def M4(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if isinstance(rot, Matrix):
        r = rot.to_4x4() if len(rot) == 3 else rot
    else:
        r = Euler(rot, "XYZ").to_matrix().to_4x4()
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    s = Matrix.Diagonal(Vector(list(scale) + [1.0]))
    return Matrix.Translation(Vector(loc)) @ r @ s


def rot_to(direction, up_hint=(0, 0, 1)):
    """Rotation matrix (3x3) whose local +Z points along `direction`."""
    z = Vector(direction).normalized()
    up = Vector(up_hint)
    if abs(z.dot(up)) > 0.98:
        up = Vector((1, 0, 0))
    x = up.cross(z).normalized()
    y = z.cross(x)
    m = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))
    return m


def fbm(p, octaves=3, lac=2.0, gain=0.5):
    a = 1.0
    s = 0.0
    q = Vector(p)
    for _ in range(octaves):
        s += a * noise.noise(q)
        q = q * lac
        a *= gain
    return s


def lerp(a, b, t):
    return a + (b - a) * t


# ----------------------------------------------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------------------------------------------
PALETTE = {
    "white": dict(color=(0.50, 0.50, 0.48), metallic=0.12, roughness=0.5),
    "offwhite": dict(color=(0.62, 0.60, 0.55), metallic=0.1, roughness=0.55),
    "lgrey": dict(color=(0.30, 0.31, 0.33), metallic=0.25, roughness=0.55),
    "mgrey": dict(color=(0.15, 0.16, 0.18), metallic=0.35, roughness=0.55),
    "graphite": dict(color=(0.055, 0.06, 0.07), metallic=0.4, roughness=0.5),
    "steel": dict(color=(0.38, 0.40, 0.44), metallic=0.75, roughness=0.38),
    "concrete": dict(color=(0.25, 0.245, 0.23), metallic=0.0, roughness=0.92),
    "dconcrete": dict(color=(0.10, 0.10, 0.10), metallic=0.0, roughness=0.95),
    "orange": dict(color=(0.85, 0.20, 0.02), metallic=0.1, roughness=0.5),
    "yellow": dict(color=(0.95, 0.62, 0.02), metallic=0.1, roughness=0.5),
    "red": dict(color=(0.55, 0.03, 0.02), metallic=0.1, roughness=0.5),
    "rubber": dict(color=(0.018, 0.018, 0.02), metallic=0.0, roughness=0.9),
    "glass": dict(color=(0.10, 0.30, 0.45), metallic=0.0, roughness=0.06, alpha=0.38),
    "window_warm": dict(color=(0.35, 0.22, 0.06), emission=(1.0, 0.68, 0.28), emission_strength=3.0, roughness=0.3),
    "emit_cyan": dict(color=(0.05, 0.3, 0.4), emission=(0.15, 0.85, 1.0), emission_strength=5.0, roughness=0.3),
    "emit_amber": dict(color=(0.4, 0.2, 0.03), emission=(1.0, 0.55, 0.1), emission_strength=5.0, roughness=0.3),
    "emit_red": dict(color=(0.5, 0.02, 0.02), emission=(1.0, 0.05, 0.03), emission_strength=6.0, roughness=0.3),
    "emit_green": dict(color=(0.05, 0.4, 0.1), emission=(0.2, 1.0, 0.3), emission_strength=4.0, roughness=0.3),
    "emit_white": dict(color=(0.8, 0.8, 0.8), emission=(1.0, 0.97, 0.9), emission_strength=5.0, roughness=0.3),
    "soot": dict(color=(0.016, 0.015, 0.014), metallic=0.2, roughness=0.8),
    "burnt": dict(color=(0.07, 0.055, 0.045), metallic=0.5, roughness=0.62),
    "rust": dict(color=(0.30, 0.10, 0.035), metallic=0.4, roughness=0.8),
    "solar": dict(color=(0.02, 0.06, 0.18), metallic=0.7, roughness=0.18),
}


def mats(prefix, spec):
    """spec: {key: palette_name | dict(...)}.  Returns an ordered dict key -> material named '<prefix>_<key>'."""
    out = {}
    for key, v in spec.items():
        params = dict(PALETTE[v]) if isinstance(v, str) else dict(v)
        out[key] = L.mat("%s_%s" % (prefix, key), **params)
    return out


# ----------------------------------------------------------------------------------------------------------------
# mesh builder
# ----------------------------------------------------------------------------------------------------------------
def _bevel(t, off, only_caps=False):
    if only_caps:
        edges = [e for e in t.edges if any(len(f.verts) > 4 for f in e.link_faces)]
    else:
        edges = list(t.edges)
    if not edges:
        return
    bmesh.ops.bevel(t, geom=edges, offset=off, offset_type="OFFSET", profile=0.5, segments=1, affect="EDGES",
                    clamp_overlap=True)


class MB:
    """Multi-material single-bmesh builder."""

    def __init__(self, materials):
        self.keys = list(materials.keys())
        self.mats = [materials[k] for k in self.keys]
        self.bm = bmesh.new()

    # -- internals -----------------------------------------------------------------------------------------------
    def mi(self, m):
        if isinstance(m, int):
            return m
        return self.keys.index(m)

    def _add(self, t, mat, matrix=None, recalc=True):
        if matrix is not None:
            bmesh.ops.transform(t, matrix=matrix, verts=t.verts)
        if recalc:
            bmesh.ops.recalc_face_normals(t, faces=t.faces)
        mi = self.mi(mat)
        vm = {}
        bm = self.bm
        for v in t.verts:
            vm[v] = bm.verts.new(v.co)
        for f in t.faces:
            try:
                nf = bm.faces.new([vm[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mi
            nf.smooth = True
        t.free()

    # -- primitives ----------------------------------------------------------------------------------------------
    def box(self, c=(0, 0, 0), s=(1, 1, 1), rot=(0, 0, 0), mat=0, bevel=0.0, top=None, top_off=(0, 0), bottom=None):
        """Box centred at c, size s; `top`=(tx,ty) scale of the top face (taper), top_off=(ox,oy) shifts top face.
        `bottom`=(bx,by) scale of bottom face."""
        sx, sy, sz = s
        tx, ty = (1.0, 1.0) if top is None else top
        bx, by = (1.0, 1.0) if bottom is None else bottom
        ox, oy = top_off
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        pts = [(-hx * bx, -hy * by, -hz), (hx * bx, -hy * by, -hz), (hx * bx, hy * by, -hz), (-hx * bx, hy * by, -hz),
               (-hx * tx + ox, -hy * ty + oy, hz), (hx * tx + ox, -hy * ty + oy, hz),
               (hx * tx + ox, hy * ty + oy, hz), (-hx * tx + ox, hy * ty + oy, hz)]
        t = bmesh.new()
        vs = [t.verts.new(p) for p in pts]
        for idx in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            t.faces.new([vs[i] for i in idx])
        if bevel > 0:
            _bevel(t, bevel)
        self._add(t, mat, matrix=M4(c, rot))
        return self

    def cyl(self, c=(0, 0, 0), r1=1.0, r2=None, h=1.0, segs=16, rot=(0, 0, 0), mat=0, caps=True, bevel=0.0, axis="Z"):
        """Cone/cylinder centred at c, r1 at -axis end, r2 at +axis end."""
        r2 = r1 if r2 is None else r2
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=caps, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
        if bevel > 0 and caps:
            _bevel(t, bevel, only_caps=True)
        am = Matrix.Identity(4)
        if axis == "X":
            am = Euler((0, PI / 2, 0), "XYZ").to_matrix().to_4x4()
        elif axis == "Y":
            am = Euler((-PI / 2, 0, 0), "XYZ").to_matrix().to_4x4()
        self._add(t, mat, matrix=M4(c, rot) @ am, recalc=caps)
        return self

    def sphere(self, c=(0, 0, 0), r=0.5, scale=(1, 1, 1), u=16, v=10, rot=(0, 0, 0), mat=0):
        t = bmesh.new()
        bmesh.ops.create_uvsphere(t, u_segments=u, v_segments=v, radius=r)
        self._add(t, mat, matrix=M4(c, rot, scale))
        return self

    def dome(self, c=(0, 0, 0), r=1.0, scale=(1, 1, 1), u=16, v=8, rot=(0, 0, 0), mat=0, cap=True):
        """Upper hemisphere (v = rings over the full sphere, must be even)."""
        t = bmesh.new()
        bmesh.ops.create_uvsphere(t, u_segments=u, v_segments=v, radius=r)
        kill = [x for x in t.verts if x.co.z < -1e-5]
        bmesh.ops.delete(t, geom=kill, context="VERTS")
        if cap:
            edges = [e for e in t.edges if len(e.link_faces) == 1]
            if edges:
                bmesh.ops.holes_fill(t, edges=edges, sides=u)
        self._add(t, mat, matrix=M4(c, rot, scale), recalc=cap)
        return self

    def prism(self, pts, z0, z1, mat=0, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0):
        """Extrude 2D polygon pts (list of (x,y)) from z0 to z1."""
        t = bmesh.new()
        bot = [t.verts.new((x, y, z0)) for x, y in pts]
        top = [t.verts.new((x, y, z1)) for x, y in pts]
        n = len(pts)
        t.faces.new(bot[::-1])
        t.faces.new(top)
        for i in range(n):
            t.faces.new([bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]])
        if bevel > 0:
            _bevel(t, bevel)
        self._add(t, mat, matrix=M4(loc, rot))
        return self

    def lathe(self, profile, segs=16, c=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), mat=0, arc=None):
        """Revolve profile [(r, z), ...] around local Z.  Walk the profile counter-clockwise in the (r, z) plane
        (bottom: outward, outer wall: up, top: inward) for outward normals.  r == 0 points become apex vertices."""
        bm = self.bm
        mi = self.mi(mat)
        M = M4(c, rot, scale)
        rings = []
        for r, z in profile:
            if r < 1e-6:
                rings.append([bm.verts.new(M @ Vector((0, 0, z)))])
            else:
                rings.append([bm.verts.new(M @ Vector((r * math.cos(TAU * j / segs), r * math.sin(TAU * j / segs), z)))
                              for j in range(segs)])
        for k in range(len(profile) - 1):
            A, B = rings[k], rings[k + 1]
            if len(A) == 1 and len(B) == 1:
                continue
            for j in range(segs):
                j2 = (j + 1) % segs
                if len(A) == 1:
                    vs = [A[0], B[j2], B[j]]
                elif len(B) == 1:
                    vs = [A[j], A[j2], B[0]]
                else:
                    vs = [A[j], A[j2], B[j2], B[j]]
                try:
                    f = bm.faces.new(vs)
                    f.material_index = mi
                    f.smooth = True
                except ValueError:
                    pass
        return self

    def loft(self, rings, mat=0, closed=True, cap0=False, cap1=False, flip=False, matrix=None, cap_mat=None):
        """Rings: list of equal-length lists of points; ring CCW seen from the loft direction => outward normals."""
        bm = self.bm
        matfn = mat if callable(mat) else None
        mi = 0 if matfn else self.mi(mat)
        vr = []
        for ring in rings:
            pts = [Vector(p) for p in ring]
            if matrix is not None:
                pts = [matrix @ p for p in pts]
            vr.append([bm.verts.new(p) for p in pts])
        n = len(vr[0])
        for i in range(len(vr) - 1):
            for j in range(n if closed else n - 1):
                j2 = (j + 1) % n
                vs = [vr[i][j], vr[i][j2], vr[i + 1][j2], vr[i + 1][j]]
                if flip:
                    vs = vs[::-1]
                fm = matfn(i, j) if matfn else None
                if matfn and fm is None:
                    continue
                try:
                    f = bm.faces.new(vs)
                    f.material_index = self.mi(fm) if matfn else mi
                    f.smooth = True
                except ValueError:
                    pass
        if cap_mat is not None:
            mi = self.mi(cap_mat)
        elif matfn:
            mi = 0
        if cap0:
            try:
                f = bm.faces.new(vr[0][::-1] if not flip else vr[0])
                f.material_index = mi
            except ValueError:
                pass
        if cap1:
            try:
                f = bm.faces.new(vr[-1] if not flip else vr[-1][::-1])
                f.material_index = mi
            except ValueError:
                pass
        return self

    def quad(self, p0, p1, p2, p3, mat=0):
        bm = self.bm
        try:
            f = bm.faces.new([bm.verts.new(Vector(p)) for p in (p0, p1, p2, p3)])
            f.material_index = self.mi(mat)
            f.smooth = True
        except ValueError:
            pass
        return self

    def tri(self, p0, p1, p2, mat=0):
        bm = self.bm
        try:
            f = bm.faces.new([bm.verts.new(Vector(p)) for p in (p0, p1, p2)])
            f.material_index = self.mi(mat)
            f.smooth = True
        except ValueError:
            pass
        return self

    def panel(self, p0, p1, p2, p3, t=0.04, shrink=0.03, mat=0, base_shrink=0.0):
        """Thin raised slab on a (curved) quad surface.  Corners CCW seen from outside; extruded along the normal."""
        p0, p1, p2, p3 = [Vector(p) for p in (p0, p1, p2, p3)]
        c = (p0 + p1 + p2 + p3) * 0.25
        n = (p1 - p0).cross(p3 - p0)
        if n.length < 1e-9:
            n = (p2 - p0).cross(p3 - p1)
        n = n.normalized()
        bm = self.bm
        mi = self.mi(mat)
        bs = 1.0 - base_shrink - shrink
        ts = 1.0 - base_shrink - shrink * 2.2
        base = [bm.verts.new(c + (p - c) * bs) for p in (p0, p1, p2, p3)]
        top = [bm.verts.new(c + (p - c) * ts + n * t) for p in (p0, p1, p2, p3)]
        faces = [top] + [[base[i], base[(i + 1) % 4], top[(i + 1) % 4], top[i]] for i in range(4)]
        for vs in faces:
            try:
                f = bm.faces.new(vs)
                f.material_index = mi
                f.smooth = True
            except ValueError:
                pass
        return self

    def pipe(self, pts, r, segs=8, mat=0, bend=None, caps=True, r_end=None):
        """Swept round tube along a polyline with rounded corners."""
        P = [Vector(p) for p in pts]
        if bend is None:
            bend = r * 3.0
        path = [P[0]]
        for i in range(1, len(P) - 1):
            a, b, c_ = P[i - 1], P[i], P[i + 1]
            d1 = b - a
            d2 = c_ - b
            cut = min(bend, d1.length * 0.5, d2.length * 0.5)
            if cut < 1e-4:
                path.append(b)
                continue
            pin = b - d1.normalized() * cut
            pout = b + d2.normalized() * cut
            for k in range(5):
                tt = k / 4.0
                path.append(pin * (1 - tt) ** 2 + b * (2 * (1 - tt) * tt) + pout * (tt * tt))
        path.append(P[-1])
        clean = [path[0]]
        for p in path[1:]:
            if (p - clean[-1]).length > 1e-4:
                clean.append(p)
        path = clean
        T = []
        for i in range(len(path)):
            if i == 0:
                t = path[1] - path[0]
            elif i == len(path) - 1:
                t = path[-1] - path[-2]
            else:
                t = path[i + 1] - path[i - 1]
            T.append(t.normalized())
        up = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        N = T[0].cross(up).normalized()
        rings = []
        angs = [TAU * j / segs for j in range(segs)]
        for i, p in enumerate(path):
            if i > 0:
                N = (N - T[i] * N.dot(T[i]))
                N.normalize()
            B = T[i].cross(N)
            rr = r if r_end is None else lerp(r, r_end, i / max(1, len(path) - 1))
            rings.append([p + (N * math.cos(a) + B * math.sin(a)) * rr for a in angs])
        self.loft(rings, mat=mat, closed=True, cap0=caps, cap1=caps)
        return self

    # -- composite details ---------------------------------------------------------------------------------------
    def wall_panels(self, origin, u, v, nu, nv, gap=0.05, t=0.03, mats_=("white", "offwhite"), seed=0, skip=None,
                    jitter_t=0.0, bevel=0.0):
        """Tile a rectangle (origin, spans u and v; outward normal = u x v) with raised panels."""
        rnd = random.Random(seed)
        origin = Vector(origin)
        u = Vector(u)
        v = Vector(v)
        n = u.cross(v).normalized()
        du = u / nu
        dv = v / nv
        gu = du.normalized() * gap * 0.5
        gv = dv.normalized() * gap * 0.5
        for i in range(nu):
            for j in range(nv):
                if skip is not None and skip(i, j):
                    continue
                p = origin + du * i + dv * j
                m = mats_[(i + j + rnd.randint(0, 1)) % len(mats_)] if len(mats_) > 1 else mats_[0]
                a = p + gu + gv
                b = p + du - gu + gv
                c_ = p + du - gu + dv - gv
                d = p + gu + dv - gv
                tt = t + (rnd.random() * jitter_t)
                self.box_from_quad(a, b, c_, d, tt, m, bevel)
        return self

    def box_from_quad(self, a, b, c_, d, t, mat, bevel=0.0):
        """Slab with bottom quad (a,b,c,d) (CCW from outside) extruded outward by t (closed box, 12 tris)."""
        a, b, c_, d = [Vector(x) for x in (a, b, c_, d)]
        n = (b - a).cross(d - a).normalized() * t
        tb = bmesh.new()
        vs = [tb.verts.new(p) for p in (a, b, c_, d, a + n, b + n, c_ + n, d + n)]
        for idx in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            tb.faces.new([vs[i] for i in idx])
        if bevel > 0:
            _bevel(tb, bevel)
        self._add(tb, mat)
        return self

    def vent(self, c, w, h, n=5, rot=(0, 0, 0), mat_slat=0, mat_back=None, depth=0.06):
        """Louvred vent on a +Y facing wall (rotate with rot).  Centre c, size w x h."""
        if mat_back is not None:
            self.box(c, (w, depth * 0.5, h), rot, mat_back)
        for i in range(n):
            z = -h / 2 + (i + 0.5) * h / n
            m = M4(c, rot)
            p = m @ Vector((0, depth * 0.5, z))
            self.box(p, (w * 0.92, depth, h / n * 0.45), rot, mat_slat)
        return self

    def ladder(self, base, top, width=0.5, mat=0, rail=0.03, spacing=0.3, out=(0, 1, 0), rung=0.022, stand_off=0.0):
        base = Vector(base)
        top = Vector(top)
        d = top - base
        length = d.length
        dn = d.normalized()
        side = dn.cross(Vector(out)).normalized() * (width / 2)
        for s in (-1, 1):
            self.pipe([base + side * s, top + side * s], rail, segs=6, mat=mat, bend=0.01)
        k = 1
        while k * spacing < length - 0.05:
            p = base + dn * (k * spacing)
            self.pipe([p - side, p + side], rung, segs=6, mat=mat, bend=0.01)
            k += 1
        return self

    def rail(self, p0, p1, height=1.0, posts=None, mat=0, r=0.03, mid=True, post_r=0.03):
        p0 = Vector(p0)
        p1 = Vector(p1)
        L_ = (p1 - p0).length
        n_posts = posts if posts is not None else max(2, int(L_ / 1.2) + 1)
        up = Vector((0, 0, height))
        self.pipe([p0 + up, p1 + up], r, segs=6, mat=mat, bend=0.01)
        if mid:
            self.pipe([p0 + up * 0.5, p1 + up * 0.5], r * 0.8, segs=6, mat=mat, bend=0.01)
        for i in range(n_posts):
            p = p0.lerp(p1, i / (n_posts - 1))
            self.pipe([p, p + up], post_r, segs=6, mat=mat, bend=0.01)
        return self

    def bolts(self, pts, r=0.04, mat=0, h=0.03, normal=(0, 0, 1), segs=6):
        n = Vector(normal).normalized()
        rm = rot_to(n)
        for p in pts:
            self.cyl(Vector(p) + n * h * 0.5, r, r * 0.9, h, segs=segs, rot=rm, mat=mat)
        return self

    def beam(self, p0, p1, w=0.1, h=0.1, mat=0, bevel=0.0, up=(0, 0, 1)):
        """Rectangular beam between two points."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        self.box((p0 + p1) * 0.5, (w, h, d.length), rot=rot_to(d, up), mat=mat, bevel=bevel)
        return self

    def strut(self, p0, p1, r0, r1=None, segs=8, mat=0, caps=True):
        """Tapered round strut between two points."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        self.cyl((p0 + p1) * 0.5, r0, r0 if r1 is None else r1, d.length, segs=segs, rot=rot_to(d), mat=mat, caps=caps)
        return self

    def dish(self, c, direction, R, depth, mat=0, th=0.05, segs=20, n=6, rim_mat=None):
        """Parabolic dish shell, concave side facing `direction`, vertex at c."""
        prof = []
        for i in range(n + 1):
            r = R * i / n
            prof.append((r, depth * (r / R) ** 2))
        front = [(r, z + th) for (r, z) in prof][::-1]
        prof = prof + front
        self.lathe(prof, segs=segs, c=c, rot=rot_to(direction), mat=mat)
        return self

    def transform(self, matrix):
        bmesh.ops.transform(self.bm, matrix=matrix, verts=self.bm.verts)
        return self

    def append(self, other, matrix=None):
        """Copy the geometry of another MB (keys must be a subset of this builder's keys) with an optional transform."""
        bm = self.bm
        remap = {i: self.keys.index(k) for i, k in enumerate(other.keys)}
        vm = {}
        for v in other.bm.verts:
            vm[v] = bm.verts.new(matrix @ v.co if matrix is not None else v.co)
        flip = matrix is not None and matrix.determinant() < 0
        for f in other.bm.faces:
            vs = [vm[v] for v in f.verts]
            if flip:
                vs = vs[::-1]
            try:
                nf = bm.faces.new(vs)
                nf.material_index = remap[f.material_index]
                nf.smooth = True
            except ValueError:
                pass
        return self

    # -- finalise ------------------------------------------------------------------------------------------------
    def build(self, name, col, smooth=35, flat=False, merge_dist=None):
        bm = self.bm
        if merge_dist:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge_dist)
        used = sorted(set(f.material_index for f in bm.faces))
        remap = {old: new for new, old in enumerate(used)}
        for f in bm.faces:
            f.material_index = remap[f.material_index]
        use_mats = [self.mats[i] for i in used]
        ob = L.obj_from_bm(name, bm, col, use_mats, smooth=not flat)
        if flat:
            for p in ob.data.polygons:
                p.use_smooth = False
        elif smooth is not None:
            L.set_smooth_by_angle(ob, smooth)
        self.bm = None
        return ob


# ----------------------------------------------------------------------------------------------------------------
# scene helpers
# ----------------------------------------------------------------------------------------------------------------
def parent_to(child, parent):
    child.parent = parent
    child.matrix_parent_inverse = Matrix.Identity(4)
    return child


def all_descendants(objs):
    out = []

    def rec(o):
        out.append(o)
        for c in o.children:
            rec(c)

    for o in objs:
        rec(o)
    return out


def isolated_preview(objs, name, views=((35, 22), (125, 22), (215, 22), (305, 22), (0, 85), (20, 4)), cols=3, size=(480, 400),
                     dist_mult=1.7, hide_extra=(), **kw):
    """Render previews showing ONLY `objs` (+descendants); every other object is hidden from the render and restored."""
    keep = set(all_descendants(objs))
    saved = {}
    for o in bpy.data.objects:
        if o not in keep:
            saved[o] = o.hide_render
            o.hide_render = True
    try:
        meshes = [o for o in keep if o.type == "MESH"]
        bpy.context.view_layer.update()
        paths = L.preview(meshes, name, views=views, size=size, dist_mult=dist_mult, **kw)
    finally:
        for o, h in saved.items():
            try:
                o.hide_render = h
            except Exception:
                pass
    return L.montage(paths, name + "_sheet", cols=cols)



def nm(model_id, name):
    """Blender object name that is unique across agents; the '<id>|' prefix is stripped from the exported glb."""
    return "%s|%s" % (model_id, name)


def fix_glb_names(path):
    import struct
    with open(path, "rb") as f:
        b = f.read()
    magic, ver, total = struct.unpack("<III", b[:12])
    clen, ctype = struct.unpack("<II", b[12:20])
    js = json.loads(b[20:20 + clen].decode("utf-8"))
    for key in ("nodes", "meshes", "materials"):
        for n in js.get(key, []):
            if "name" in n and "|" in n["name"]:
                n["name"] = n["name"].split("|")[-1]
    raw = json.dumps(js, separators=(",", ":")).encode("utf-8")
    raw += b" " * ((4 - len(raw) % 4) % 4)
    rest = b[20 + clen:]
    out = struct.pack("<III", magic, ver, 12 + 8 + len(raw) + len(rest)) + struct.pack("<II", len(raw), ctype) + raw + rest
    with open(path, "wb") as f:
        f.write(out)


def export_clean(objs, model_id):
    path = L.export_glb(objs, model_id)
    fix_glb_names(path)
    return path


def tri_total(objs):
    return L.tri_count([o for o in all_descendants(objs) if o.type == "MESH"])


def write_manifest(entry):
    os.makedirs(os.path.dirname(MANIFEST_PATH), exist_ok=True)
    data = {"group": "structures", "models": []}
    if os.path.exists(MANIFEST_PATH):
        try:
            with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            pass
    data["conventions"] = ("Units: metres, Godot axes (x right, y up, z back; model front = -Z). Origin = ground contact / footprint centre (structures may sink below y=0: see base_y). "
                           "collider.offset_y = y of the collider BOTTOM relative to the model origin; collider.center = [x, y, z] of the collider CENTRE (Godot axes, relative to the model origin); "
                           "box: size = [x, y, z]; cylinder: radius + height. `colliders` (optional) = list of extra/finer parts in the same format. "
                           "aabb_center = centre of the whole visible model. Anchor_* nodes are Node3D markers (Anchor_Door = where the player stands to interact, Anchor_Top = top for beams/markers). "
                           "tintable = material-name substrings the game may recolour. Emissive materials use KHR_materials_emissive_strength.")
    data["models"] = [m for m in data.get("models", []) if m.get("id") != entry["id"]]
    data["models"].append(entry)
    data["models"].sort(key=lambda m: m["id"])
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def finish(objs, model_id, biomes, collider, notes, nodes=None, tintable=None, kind="structure", do_preview=True,
           do_export=True, colliders=None, views=None, preview_kw=None):
    """Report, preview montage, export glb, write manifest entry, save blend."""
    bpy.context.view_layer.update()
    desc = all_descendants(objs)
    meshes = [o for o in desc if o.type == "MESH"]
    mn, mx = L.bounds(meshes)
    sz = mx - mn
    tris = L.tri_count(meshes)
    L.report(meshes, model_id)
    out = {}
    if do_preview:
        kw = dict(preview_kw or {})
        if views:
            kw["views"] = views
        out["montage"] = isolated_preview(objs, model_id, **kw)
        print("MONTAGE:", out["montage"])
    if do_export:
        out["glb"] = export_clean(objs, model_id)
        print("EXPORTED:", out["glb"], os.path.getsize(out["glb"]), "bytes")
    # AABB centre in GODOT axes (x, y_up, z) = (bx, bz, -by)
    centre = [round((mn.x + mx.x) / 2, 3), round((mn.z + mx.z) / 2, 3), round(-(mn.y + mx.y) / 2, 3)]
    collider = dict(collider)
    entry = {
        "id": model_id,
        "file": model_id + ".glb",
        "kind": kind,
        "biomes": biomes,
        "size": [round(sz.x, 3), round(sz.z, 3), round(sz.y, 3)],
        "base_y": round(mn.z, 3),
        "aabb_center": centre,
        "collider": collider,
        "tris": int(tris),
        "notes": notes,
    }
    if colliders:
        entry["colliders"] = colliders
    if tintable is None:
        mnames = set()
        for o in meshes:
            for m_ in o.data.materials:
                if m_:
                    mnames.add(m_.name)
        tintable = [c for c in ("accent", "orange") if any(n.endswith("_" + c) for n in mnames)]
    if tintable:
        entry["tintable"] = tintable
    if nodes:
        entry["nodes"] = nodes
    if do_export:
        write_manifest(entry)
    L.save_blend()
    return entry


def shots(objs, name, cams, size=(720, 540), lens=40, bg=(0.10, 0.12, 0.16), sun_energy=3.5, ground_z=None, cols=2):
    """Close-up renders: cams = [(pos(x,y,z), target(x,y,z)), ...] (Blender world coords).  Only `objs` (+children) are rendered."""
    import numpy as _np
    os.makedirs(L.PREVIEW_DIR, exist_ok=True)
    keep = set(all_descendants(objs))
    saved_hide = {}
    for o in bpy.data.objects:
        if o not in keep:
            saved_hide[o] = o.hide_render
            o.hide_render = True
    sc = bpy.context.scene
    saved = dict(engine=sc.render.engine, rx=sc.render.resolution_x, ry=sc.render.resolution_y, pct=sc.render.resolution_percentage,
                 cam=sc.camera, fp=sc.render.filepath, world=sc.world)
    created = []
    world = bpy.data.worlds.new("__shot_world")
    world.use_nodes = True
    bgn = world.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (bg[0], bg[1], bg[2], 1)
    sc.world = world
    cam_d = bpy.data.cameras.new("__shot_cam")
    cam_d.lens = lens
    cam_d.clip_start = 0.05
    cam_d.clip_end = 3000
    cam = bpy.data.objects.new("__shot_cam", cam_d)
    sc.collection.objects.link(cam)
    created.append(cam)
    sun_d = bpy.data.lights.new("__shot_sun", "SUN")
    sun_d.energy = sun_energy
    sun = bpy.data.objects.new("__shot_sun", sun_d)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    sc.collection.objects.link(sun)
    created.append(sun)
    fill_d = bpy.data.lights.new("__shot_fill", "SUN")
    fill_d.energy = 1.2
    fill = bpy.data.objects.new("__shot_fill", fill_d)
    fill.rotation_euler = (math.radians(70), 0, math.radians(-140))
    sc.collection.objects.link(fill)
    created.append(fill)
    gobj = None
    if ground_z is not None:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60.0)
        gme = bpy.data.meshes.new("__shot_ground")
        bm.to_mesh(gme)
        bm.free()
        gobj = bpy.data.objects.new("__shot_ground", gme)
        gme.materials.append(L.mat("__shot_ground_mat", (0.18, 0.2, 0.22), roughness=0.95))
        gobj.location = (0, 0, ground_z)
        sc.collection.objects.link(gobj)
        created.append(gobj)
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    paths = []
    try:
        bpy.context.view_layer.update()
        for i, (pos, tgt) in enumerate(cams):
            cam.location = Vector(pos)
            d = Vector(tgt) - Vector(pos)
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            p = os.path.join(L.PREVIEW_DIR, "%s_shot%d.png" % (name, i))
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            paths.append(p)
    finally:
        for o in created:
            try:
                bpy.data.objects.remove(o, do_unlink=True)
            except Exception:
                pass
        for blk, coll in ((cam_d, bpy.data.cameras), (sun_d, bpy.data.lights), (fill_d, bpy.data.lights)):
            try:
                coll.remove(blk)
            except Exception:
                pass
        try:
            bpy.data.meshes.remove(bpy.data.meshes["__shot_ground"])
        except Exception:
            pass
        sc.world = saved["world"]
        try:
            bpy.data.worlds.remove(world)
        except Exception:
            pass
        sc.camera = saved["cam"]
        sc.render.engine = saved["engine"]
        sc.render.resolution_x, sc.render.resolution_y = saved["rx"], saved["ry"]
        sc.render.resolution_percentage = saved["pct"]
        sc.render.filepath = saved["fp"]
        for o, h in saved_hide.items():
            try:
                o.hide_render = h
            except Exception:
                pass
    return L.montage(paths, name + "_shots", cols=cols)
