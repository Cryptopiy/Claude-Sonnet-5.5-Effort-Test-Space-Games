"""Helpers for the `ship` group (ship_player, freighter, station, satellite, asteroids).  Blender 5.2 / bpy / bmesh.

    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import lib_common as L; import ship_lib as S; importlib.reload(L); importlib.reload(S)

Everything here builds geometry in *world-ish model space* (Blender axes, Z up, +Y front) as bmesh data and
finishes objects with `S.finish()` which re-centres the mesh on a chosen origin.
Object names inside Blender are prefixed (`ship_player__Hull`) so they never collide with other agents' objects; the
prefix is stripped from the node names inside the exported .glb by `S.export_named()`.
"""
import sys
import os
import math
import json
import struct
import bisect
import random

import bpy
import bmesh
from mathutils import Vector, Matrix, Euler, noise
from mathutils.bvhtree import BVHTree

sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L

V = Vector
TAU = math.tau


# ----------------------------------------------------------------------------------------------------------------
# numeric helpers
# ----------------------------------------------------------------------------------------------------------------
def clamp(x, a=0.0, b=1.0):
    return a if x < a else (b if x > b else x)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a)) if b != a else 0.0
    return t * t * (3 - 2 * t)


class Mono:
    """Monotone cubic Hermite interpolation (no overshoot).  xs ascending."""

    def __init__(self, xs, ys):
        self.xs = list(xs)
        self.ys = list(ys)
        n = len(xs)
        h = [xs[i + 1] - xs[i] for i in range(n - 1)]
        d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
        m = [0.0] * n
        m[0] = d[0]
        m[-1] = d[-1]
        for i in range(1, n - 1):
            if d[i - 1] * d[i] <= 0:
                m[i] = 0.0
            else:
                w1 = 2 * h[i] + h[i - 1]
                w2 = h[i] + 2 * h[i - 1]
                m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
        self.m = m
        self.h = h

    def __call__(self, x):
        xs, ys, m, h = self.xs, self.ys, self.m, self.h
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, x) - 1
        t = (x - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
                + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])


def spow(x, p):
    return math.copysign(abs(x) ** p, x)


# ----------------------------------------------------------------------------------------------------------------
# object helpers
# ----------------------------------------------------------------------------------------------------------------
def finish(name, bm, col, mats, origin=(0, 0, 0), parent=None, smooth_deg=40, prefix="", recalc=False, flat=False):
    """bmesh (model-space coords) -> object whose origin sits at `origin`; the mesh is shifted so that nothing moves in world.
    Name is prefix+name.  parent: object (identity parent-inverse, parent assumed at world origin)."""
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = Vector(origin)
    if o.length > 0:
        bmesh.ops.translate(bm, vec=-o, verts=bm.verts)
    me = bpy.data.meshes.new(prefix + name)
    bm.to_mesh(me)
    bm.free()
    for m_ in mats:
        me.materials.append(m_)
    ob = bpy.data.objects.new(prefix + name, me)
    col.objects.link(ob)
    ob.location = o
    if parent is not None:
        ob.parent = parent
    if flat:
        for p in me.polygons:
            p.use_smooth = False
    else:
        L.set_smooth_by_angle(ob, smooth_deg)
    return ob


def make_empty(name, col, loc, parent=None, prefix="", display="PLAIN_AXES", size=0.3):
    e = L.empty(prefix + name, col, loc, parent=parent, display=display, size=size)
    return e


def mirror_x(bm, reverse=True):
    """Return a mirrored (x -> -x) copy of the whole bmesh as a new bmesh."""
    c = bm.copy()
    bmesh.ops.transform(c, matrix=Matrix.Diagonal(Vector((-1, 1, 1, 1))), verts=c.verts)
    if reverse:
        bmesh.ops.reverse_faces(c, faces=c.faces)
    return c


def add_mirrored(bm, reverse=True):
    """bm += mirror(bm); returns bm."""
    m = mirror_x(bm, reverse)
    return L.bm_merge(bm, m)


def set_mat(bm, idx):
    for f in bm.faces:
        f.material_index = idx
    return bm


def xform(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def translate(bm, v):
    bmesh.ops.translate(bm, vec=Vector(v), verts=bm.verts)
    return bm


# ----------------------------------------------------------------------------------------------------------------
# lofts
# ----------------------------------------------------------------------------------------------------------------
def grid_from_rings(bm, rings, closed=True, mat=0, cap_start=False, cap_end=False):
    """rings: list of equal-length lists of 3D points.  Returns (grid[i][j] BMVerts, faces dict {(i,j): face})."""
    G = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    F = {}
    for i in range(len(rings) - 1):
        for j in range(n if closed else n - 1):
            j2 = (j + 1) % n
            try:
                f = bm.faces.new((G[i][j], G[i][j2], G[i + 1][j2], G[i + 1][j]))
            except ValueError:
                continue
            f.material_index = mat
            F[(i, j)] = f
    if cap_start:
        try:
            f = bm.faces.new(G[0])
            f.material_index = mat
            F["cap0"] = f
        except ValueError:
            pass
    if cap_end:
        try:
            f = bm.faces.new(list(reversed(G[-1])))
            f.material_index = mat
            F["cap1"] = f
        except ValueError:
            pass
    return G, F


def superellipse_pt(theta, hw, zt, zc, zb, nt, nb):
    """Point on a lopsided super-ellipse: widest at height zc, top at zt, bottom at zb."""
    c = math.cos(theta)
    s = math.sin(theta)
    n = nt if s >= 0 else nb
    e = 2.0 / n
    x = hw * math.copysign(abs(c) ** e, c)
    sv = abs(s) ** e
    if s >= 0:
        z = zc + (zt - zc) * sv
    else:
        z = zc - (zc - zb) * sv
    return x, z


# airfoil thickness distribution (NACA 00xx shape, closed trailing edge), normalised to max = 1
def _naca(u):
    return 5 * (0.2969 * math.sqrt(u) - 0.1260 * u - 0.3516 * u * u + 0.2843 * u ** 3 - 0.1036 * u ** 4)


_NACA_MAX = max(_naca(i / 400.0) for i in range(401))


def foil_ring(le, te, up, thick, nchord=10, lower_scale=1.0, camber=0.0):
    """Closed airfoil loop: starts at the trailing edge (upper), runs to the leading edge, back along the lower side.
    le/te: 3D points; up: unit vector for 'thickness' direction; thick: max total thickness in metres."""
    le = Vector(le)
    te = Vector(te)
    up = Vector(up)
    us = [(1 - math.cos(math.pi * k / nchord)) / 2 for k in range(nchord + 1)]  # 0..1 (LE..TE)
    upper = []
    lower = []
    for u in us:
        yt = _naca(u) / _NACA_MAX * 0.5 * thick
        base = le.lerp(te, u)
        cam = camber * 4 * u * (1 - u) * thick
        upper.append(base + up * (yt + cam))
        lower.append(base - up * (yt * lower_scale - cam))
    # loop: TE upper -> ... -> LE -> ... -> TE lower (exclusive of duplicate TE and LE)
    ring = list(reversed(upper))  # TE .. LE
    ring += lower[1:-1]  # LE+1 .. TE-1
    return ring


def revolve_y(bm, profile, segs=16, centre=(0, 0, 0), mats=None, start_angle=0.0, cap_first=False, cap_last=False):
    """Body of revolution about a line parallel to Y through `centre` (x,z).  profile: [(y, r), ...].
    mats: list of material index per profile *segment* (len-1) (or an int)."""
    cx, cz = centre[0], centre[-1]
    rings = []
    for (y, r) in profile:
        ring = []
        for j in range(segs):
            a = start_angle + TAU * j / segs
            ring.append(Vector((cx + r * math.cos(a), y, cz + r * math.sin(a))))
        rings.append(ring)
    G, F = grid_from_rings(bm, rings, closed=True)
    for key, f in F.items():
        if isinstance(key, tuple):
            i = key[0]
            f.material_index = mats[i] if isinstance(mats, (list, tuple)) else (mats or 0)
    if cap_first:
        try:
            f = bm.faces.new(G[0])
            f.material_index = mats[0] if isinstance(mats, (list, tuple)) else (mats or 0)
        except ValueError:
            pass
    if cap_last:
        try:
            f = bm.faces.new(list(reversed(G[-1])))
            f.material_index = mats[-1] if isinstance(mats, (list, tuple)) else (mats or 0)
        except ValueError:
            pass
    return G, F


def revolve_axis(bm, profile, axis_p0, axis_p1, segs=16, mats=None, cap_first=False, cap_last=False):
    """Body of revolution about the axis p0->p1.  profile: [(t, r)] with t = distance along the axis from p0."""
    p0 = Vector(axis_p0)
    ax = (Vector(axis_p1) - p0).normalized()
    ref = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((1, 0, 0))
    u = ax.cross(ref).normalized()
    w = ax.cross(u).normalized()
    rings = []
    for (t, r) in profile:
        ring = []
        for j in range(segs):
            a = TAU * j / segs
            ring.append(p0 + ax * t + (u * math.cos(a) + w * math.sin(a)) * r)
        rings.append(ring)
    G, F = grid_from_rings(bm, rings, closed=True)
    for key, f in F.items():
        if isinstance(key, tuple):
            i = key[0]
            f.material_index = mats[i] if isinstance(mats, (list, tuple)) else (mats or 0)
    if cap_first:
        try:
            f = bm.faces.new(G[0])
            f.material_index = mats[0] if isinstance(mats, (list, tuple)) else (mats or 0)
        except ValueError:
            pass
    if cap_last:
        try:
            f = bm.faces.new(list(reversed(G[-1])))
            f.material_index = mats[-1] if isinstance(mats, (list, tuple)) else (mats or 0)
        except ValueError:
            pass
    return G, F


def box(center, size, mat=0, rot=None, taper=None):
    """A box as a new bmesh. rot: Euler tuple; size (x,y,z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if taper is not None:  # taper = (top_scale_x, top_scale_y): scale verts with z>0
        for v in bm.verts:
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
    if rot is not None:
        bmesh.ops.transform(bm, matrix=Euler(rot, "XYZ").to_matrix().to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    for f in bm.faces:
        f.material_index = mat
    return bm


def cyl(p0, p1, r0, r1=None, segs=10, mat=0, caps=True):
    """Tapered cylinder between two points."""
    if r1 is None:
        r1 = r0
    p0 = Vector(p0)
    p1 = Vector(p1)
    d = p1 - p0
    ln = d.length
    bm = bmesh.new()
    G, F = revolve_axis(bm, [(0, r0), (ln, r1)], p0, p1, segs=segs, mats=mat, cap_first=caps, cap_last=caps)
    for f in bm.faces:
        f.material_index = mat
    return bm


def uvsphere(center, radius, scale=(1, 1, 1), u=12, v=8, mat=0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    for f in bm.faces:
        f.material_index = mat
    return bm


def icosphere(center, radius, sub=1, mat=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    for f in bm.faces:
        f.material_index = mat
    return bm


def merge_all(bms):
    bms = [b for b in bms if b is not None]
    base = bms[0]
    if len(bms) > 1:
        L.bm_merge(*bms)
    return base


# ----------------------------------------------------------------------------------------------------------------
# surface projection + ribbons (panel lines)
# ----------------------------------------------------------------------------------------------------------------
class Surf:
    """Ray-cast helper on a bmesh shell (used to wrap panel lines / decals onto the hull)."""

    def __init__(self, bm):
        self.bvh = BVHTree.FromBMesh(bm)

    def ray(self, origin, direction):
        loc, nrm, idx, dist = self.bvh.ray_cast(Vector(origin), Vector(direction).normalized(), 200.0)
        return loc, nrm

    def last_ray(self, origin, direction):
        """Farthest hit along the ray (useful from inside a closed shell going out)."""
        o = Vector(origin)
        d = Vector(direction).normalized()
        best = (None, None)
        for _ in range(8):
            loc, nrm, idx, dist = self.bvh.ray_cast(o, d, 200.0)
            if loc is None:
                break
            best = (loc, nrm)
            o = loc + d * 1e-3
        return best


def ribbon(bm, pts, nrm, width, lift, mat=0, closed=False, taper=0.0):
    """Flat strip along a polyline of surface points (raised by `lift` along `nrm`).  Winding follows `nrm`.
    taper (0..0.5): fraction of the strip length at each open end over which the width shrinks to 25 % (pinched ends instead of square tabs)."""
    n = len(pts)
    if n < 2:
        return
    L_, R_ = [], []
    width0 = width
    for k in range(n):
        width = width0
        if taper > 0.0 and not closed and n > 2:
            u = min(k, n - 1 - k) / float(n - 1)
            width = width0 * (0.25 + 0.75 * min(1.0, u / taper))
        if closed:
            t = pts[(k + 1) % n] - pts[k - 1]
        else:
            t = pts[min(k + 1, n - 1)] - pts[max(k - 1, 0)]
        if t.length < 1e-9:
            t = Vector((0, 1, 0))
        t = t.normalized()
        nn = nrm[k].normalized()
        s = t.cross(nn)
        if s.length < 1e-9:
            s = Vector((1, 0, 0))
        s = s.normalized()
        c = pts[k] + nn * lift
        L_.append(bm.verts.new(c - s * (width * 0.5)))
        R_.append(bm.verts.new(c + s * (width * 0.5)))
    last = n if closed else n - 1
    for k in range(last):
        k2 = (k + 1) % n
        try:
            f = bm.faces.new((L_[k], R_[k], R_[k2], L_[k2]))
        except ValueError:
            continue
        f.material_index = mat
        f.normal_update()
        if f.normal.dot(nrm[k] + nrm[k2]) < 0:
            f.normal_flip()


def rounded_rect(a0, a1, b0, b1, r, per=4):
    """Polyline (closed) of a rounded rectangle in 2D (a, b) param space."""
    r = min(r, (a1 - a0) / 2, (b1 - b0) / 2)
    pts = []
    corners = [(a1 - r, b1 - r, 0), (a0 + r, b1 - r, 90), (a0 + r, b0 + r, 180), (a1 - r, b0 + r, 270)]
    for (ca, cb, ang) in corners:
        for k in range(per + 1):
            t = math.radians(ang + 90.0 * k / per)
            pts.append((ca + r * math.cos(t), cb + r * math.sin(t)))
    return pts


# ----------------------------------------------------------------------------------------------------------------
# GLB post-processing: strip the unique prefix from node names
# ----------------------------------------------------------------------------------------------------------------
def fix_glb_names(path, prefix, extra_rename=None):
    """Rewrites the JSON chunk of a .glb so node names lose the `prefix` (e.g. 'ship_player__Hull' -> 'Hull').
    Also strips Blender's '.001' style suffix if present and returns the final node-name list."""
    with open(path, "rb") as f:
        data = f.read()
    magic, ver, total = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF"
    off = 12
    chunks = []
    while off < len(data):
        ln, ctype = struct.unpack("<I4s", data[off:off + 8])
        chunks.append([ctype, data[off + 8:off + 8 + ln]])
        off += 8 + ln
    js = json.loads(chunks[0][1].decode("utf-8"))
    names = []
    for nd in js.get("nodes", []):
        nm = nd.get("name", "")
        if nm.startswith(prefix):
            nm = nm[len(prefix):]
        if extra_rename and nm in extra_rename:
            nm = extra_rename[nm]
        nd["name"] = nm
        names.append(nm)
    for ms in js.get("meshes", []):
        nm = ms.get("name", "")
        if nm.startswith(prefix):
            ms["name"] = nm[len(prefix):]
    raw = json.dumps(js, separators=(",", ":")).encode("utf-8")
    raw += b" " * ((4 - len(raw) % 4) % 4)
    chunks[0][1] = raw
    out = b""
    for ctype, cdata in chunks:
        out += struct.pack("<I4s", len(cdata), ctype) + cdata
    out = struct.pack("<4sII", b"glTF", 2, 12 + len(out)) + out
    with open(path, "wb") as f:
        f.write(out)
    return names


def export_named(root_objects, model_id, prefix):
    """Export `root_objects` (+children) to assets/models/<model_id>.glb and strip `prefix` from the node names."""
    path = L.export_glb(root_objects, model_id)
    names = fix_glb_names(path, prefix)
    return path, names


def collect(root):
    out = [root]
    for c in root.children:
        out += collect(c)
    return out


def tri_report(root, name):
    bpy.context.view_layer.update()
    objs = [o for o in collect(root) if o.type == "MESH"]
    L.report(objs, name)
    for o in objs:
        o.data.calc_loop_triangles()
        print("   ", o.name, "tris", len(o.data.loop_triangles), "mats", [m.name for m in o.data.materials])
    return sum(len(o.data.loop_triangles) for o in objs)


# ----------------------------------------------------------------------------------------------------------------
# preview wrapper: hides nothing, just calls L.preview on mesh objects of a hierarchy
# ----------------------------------------------------------------------------------------------------------------
def preview_set(root, name, views=None, size=(480, 400), cols=3, dist_mult=1.9, sun_energy=3.5, bg=(0.10, 0.12, 0.16), ground=True):
    """Render previews of a hierarchy.  Other agents' objects are hidden from the render for the duration of the call only."""
    bpy.context.view_layer.update()
    objs = [o for o in collect(root) if o.type == "MESH"]
    mine = set(collect(root))
    saved = {}
    for o in bpy.data.objects:
        if o not in mine:
            saved[o.name] = o.hide_render
            o.hide_render = True
    kw = dict(size=size, dist_mult=dist_mult, sun_energy=sun_energy, bg=bg, ground=ground)
    if views is not None:
        kw["views"] = views
    try:
        paths = L.preview(objs, name, **kw)
        sheet = L.montage(paths, name + "_sheet", cols=cols)
    finally:
        for nm, v in saved.items():
            o = bpy.data.objects.get(nm)
            if o is not None:
                o.hide_render = v
    print("MONTAGE:", sheet)
    return sheet


# ----------------------------------------------------------------------------------------------------------------
# more builders (added in a second pass)
# ----------------------------------------------------------------------------------------------------------------
def fairing(bm, surf, ys, wfn, hfn, nseg=10, n_exp=2.4, skirt=0.05, mats=0, x_off=0.0, zoff=0.0, hz=None, pointed_ends=True):
    """Lofted bubble/fairing sitting on a surface (rays from above).  ys: stations rear->front or any order; wfn(y)=half width,
    hfn(y)=height above the surface.  Returns (grid, faces).  Cross-section: half super-ellipse; base points ray-cast onto `surf`."""
    rings = []
    for y in ys:
        w = wfn(y)
        h = hfn(y)
        if w < 1e-4:
            w = 1e-3
        # base z from the surface at +-w and centre
        hl = surf.ray((x_off - w, y, 5.0), (0, 0, -1))[0]
        hr = surf.ray((x_off + w, y, 5.0), (0, 0, -1))[0]
        hc = surf.ray((x_off, y, 5.0), (0, 0, -1))[0]
        fallback = hc.z if hc is not None else 0.0
        zbase = hl.z if hl is not None else fallback
        zbase_r = hr.z if hr is not None else fallback
        ring = []
        for k in range(nseg + 1):
            a = math.pi * k / nseg  # 0..pi : right -> left
            c = math.cos(a)
            s = math.sin(a)
            e = 2.0 / n_exp
            x = x_off + w * math.copysign(abs(c) ** e, c)
            zb_k = S_lerp(zbase_r, zbase, k / nseg) - skirt
            z = zb_k + (h + skirt) * (abs(s) ** e) + zoff
            ring.append(Vector((x, y, z)))
        rings.append(ring)
    G, F = grid_from_rings(bm, rings, closed=False, mat=mats)
    return G, F


def S_lerp(a, b, t):
    return a + (b - a) * t


def slab_from_grid(bm, P, N, t_out, t_in, mat_out=0, mat_in=1, mat_edge=1):
    """P: 2D list [r][c] of surface points, N: matching normals.  Builds a closed thin slab (outer surface at +t_out, inner at -t_in)."""
    R = len(P)
    C = len(P[0])
    A = [[bm.verts.new(P[r][c] + N[r][c] * t_out) for c in range(C)] for r in range(R)]
    B = [[bm.verts.new(P[r][c] - N[r][c] * t_in) for c in range(C)] for r in range(R)]
    for r in range(R - 1):
        for c in range(C - 1):
            f = bm.faces.new((A[r][c], A[r][c + 1], A[r + 1][c + 1], A[r + 1][c]))
            f.material_index = mat_out
            f = bm.faces.new((B[r][c], B[r + 1][c], B[r + 1][c + 1], B[r][c + 1]))
            f.material_index = mat_in
    # edges
    for c in range(C - 1):
        f = bm.faces.new((A[0][c], B[0][c], B[0][c + 1], A[0][c + 1]))
        f.material_index = mat_edge
        f = bm.faces.new((A[R - 1][c], A[R - 1][c + 1], B[R - 1][c + 1], B[R - 1][c]))
        f.material_index = mat_edge
    for r in range(R - 1):
        f = bm.faces.new((A[r][0], A[r + 1][0], B[r + 1][0], B[r][0]))
        f.material_index = mat_edge
        f = bm.faces.new((A[r][C - 1], B[r][C - 1], B[r + 1][C - 1], A[r + 1][C - 1]))
        f.material_index = mat_edge
    return A, B


def prism_x(profile_yz, x0, x1, mat=0):
    """Extrude a closed (y, z) polygon along X from x0 to x1."""
    bm = bmesh.new()
    a = [bm.verts.new(Vector((x0, y, z))) for (y, z) in profile_yz]
    b = [bm.verts.new(Vector((x1, y, z))) for (y, z) in profile_yz]
    n = len(a)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = mat
    return bm


def prism_y(profile_xz, y0, y1, mat=0):
    """Extrude a closed (x, z) polygon along Y from y0 to y1."""
    bm = bmesh.new()
    a = [bm.verts.new(Vector((x, y0, z))) for (x, z) in profile_xz]
    b = [bm.verts.new(Vector((x, y1, z))) for (x, z) in profile_xz]
    n = len(a)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = mat
    return bm


def prism_z(profile_xy, z0, z1, mat=0):
    """Extrude a closed (x, y) polygon along Z from z0 to z1."""
    bm = bmesh.new()
    a = [bm.verts.new(Vector((x, y, z0))) for (x, y) in profile_xy]
    b = [bm.verts.new(Vector((x, y, z1))) for (x, y) in profile_xy]
    n = len(a)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = mat
    return bm


# ----------------------------------------------------------------------------------------------------------------
# view-layer handling: another agent's script may leave our collection excluded -> matrix_world stale, no render, no select
# ----------------------------------------------------------------------------------------------------------------
_STATE = {}


def layer_coll(name):
    def walk(l):
        if l.name == name:
            return l
        for c in l.children:
            r = walk(c)
            if r is not None:
                return r
        return None
    return walk(bpy.context.view_layer.layer_collection)


def begin(col):
    """Make sure collection `col` is part of the view layer (remember the old state)."""
    lc = layer_coll(col.name)
    if lc is not None:
        _STATE[col.name] = lc.exclude
        lc.exclude = False
    bpy.context.view_layer.update()


def end(col):
    lc = layer_coll(col.name)
    if lc is not None and col.name in _STATE:
        lc.exclude = _STATE.pop(col.name)


# ----------------------------------------------------------------------------------------------------------------
# freighter / station helpers
# ----------------------------------------------------------------------------------------------------------------
def quad(bm, center, normal, up, w, h, mat=0, lift=0.0):
    """A single flat quad (2 tris) facing `normal`, w wide (along normal x up), h tall (along up)."""
    c = Vector(center)
    n = Vector(normal).normalized()
    u = Vector(up)
    u = (u - n * u.dot(n)).normalized()
    r = u.cross(n).normalized()
    c = c + n * lift
    vs = [bm.verts.new(c + r * (-w / 2) + u * (-h / 2)), bm.verts.new(c + r * (w / 2) + u * (-h / 2)),
          bm.verts.new(c + r * (w / 2) + u * (h / 2)), bm.verts.new(c + r * (-w / 2) + u * (h / 2))]
    f = bm.faces.new(vs)
    f.material_index = mat
    f.normal_update()
    if f.normal.dot(n) < 0:
        f.normal_flip()
    return f


def loft_sections(bm, keys, ys, nseg=24, mat=0, caps=True, rot_ref=None):
    """Super-ellipse loft along Y.  keys: [(y, hw, zt, zc, zb, nt, nb)] ascending in y.  ys: station list (any order).
    Returns (grid, faces, rings_y)."""
    ks = sorted(keys)
    yk = [k[0] for k in ks]
    fn = [Mono(yk, [k[i] for k in ks]) for i in range(1, 7)]
    rings = []
    for y in ys:
        hw, zt, zc, zb, nt, nb = [f(y) for f in fn]
        ring = []
        for j in range(nseg):
            th = TAU * j / nseg
            x, z = superellipse_pt(th, max(hw, 1e-3), zt, zc, zb, nt, nb)
            ring.append(Vector((x, y, z)))
        rings.append(ring)
    G, F = grid_from_rings(bm, rings, closed=True, mat=mat, cap_start=caps, cap_end=caps)
    return G, F


def dish(center, axis, radius, depth, segs=16, rings=4, mat=0):
    """Parabolic dish opening along +axis (a bmesh, single sided + back)."""
    ax = Vector(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((1, 0, 0))
    u = ax.cross(ref).normalized()
    w = ax.cross(u).normalized()
    bm = bmesh.new()
    c = Vector(center)
    rs = []
    for k in range(rings + 1):
        t = k / rings
        r = radius * t
        a_off = depth * t * t
        rs.append((r, a_off))
    rings_ = []
    for (r, a_off) in rs:
        ring = []
        for j in range(segs):
            a = TAU * j / segs
            ring.append(c + ax * a_off + (u * math.cos(a) + w * math.sin(a)) * r)
        rings_.append(ring)
    # innermost "ring" is the centre point: collapse
    rings_[0] = [c + ax * 0.0 + (u * math.cos(TAU * j / segs) + w * math.sin(TAU * j / segs)) * 1e-3 for j in range(segs)]
    G, F = grid_from_rings(bm, rings_, closed=True, mat=mat, cap_start=True, cap_end=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm
