"""astro_lib: helpers for the 'astro' group (astronaut, multitool, fp viewmodel, creatures).  Builds on lib_common.

Usage in a script run through tools/bmcp.py:
    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import lib_common as L; importlib.reload(L)
    import astro_lib as A; importlib.reload(A)

Key ideas
  * Geometry is built in WORLD (model) coordinates as bmeshes (loft / tube / ellipsoid / rbox ...), then `Model.add()` moves the
    mesh so that the object origin sits at the requested pivot and parents the object WITHOUT a parent-inverse, so
    local position == pivot - parent_pivot (all rotations are zero in the rest pose).  Godot gets clean joint pivots.
  * Objects are named "<model_id>__<NodeName>" inside Blender (the .blend is shared with other agents and object names are
    global), and `Model.export()` temporarily renames them to the plain node names for the glTF export, then renames back.
"""
import sys
import os
import math
import json
import bpy
import bmesh
from math import sin, cos, pi, copysign
from mathutils import Vector, Matrix, Euler, noise

sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L  # noqa: E402

V = Vector
MANIFEST = os.path.join(L.MODELS_DIR, "manifest_astro.json")


# ----------------------------------------------------------------------------------------------------------------
# small math helpers
# ----------------------------------------------------------------------------------------------------------------
def sgnpow(d, e):
    return copysign(abs(d) ** e, d)


def lerp(a, b, t):
    return a + (b - a) * t


def basis(origin, fwd, up=(0, 0, 1), scale=(1, 1, 1)):
    """4x4 matrix whose local +Y is `fwd`, +Z ~ `up`, +X = right.  Translation = origin."""
    f = Vector(fwd).normalized()
    u = Vector(up)
    r = f.cross(u)
    if r.length < 1e-5:
        u = Vector((0, 1, 0)) if abs(f.z) > 0.9 else Vector((0, 0, 1))
        r = f.cross(u)
    r.normalize()
    u2 = r.cross(f).normalized()
    m = Matrix(((r.x, f.x, u2.x, origin[0]), (r.y, f.y, u2.y, origin[1]), (r.z, f.z, u2.z, origin[2]), (0, 0, 0, 1)))
    return m @ Matrix.Diagonal(Vector(list(scale) + [1.0]))


def basis_z(origin, zdir, xhint=(1, 0, 0), scale=(1, 1, 1)):
    """4x4 matrix whose local +Z is `zdir` (cylinders / cones built along +Z)."""
    z = Vector(zdir).normalized()
    x = Vector(xhint)
    y = z.cross(x)
    if y.length < 1e-5:
        x = Vector((0, 1, 0))
        y = z.cross(x)
    y.normalize()
    x2 = y.cross(z).normalized()
    m = Matrix(((x2.x, y.x, z.x, origin[0]), (x2.y, y.y, z.y, origin[1]), (x2.z, y.z, z.z, origin[2]), (0, 0, 0, 1)))
    return m @ Matrix.Diagonal(Vector(list(scale) + [1.0]))


def set_mat(bm, mat):
    for f in bm.faces:
        f.material_index = mat
    return bm


def xform(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def translate(bm, vec):
    bmesh.ops.translate(bm, vec=Vector(vec), verts=bm.verts)
    return bm


def merge(*bms):
    return L.bm_merge(*bms)


def fix_normals(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ----------------------------------------------------------------------------------------------------------------
# geometry builders (all return a bmesh)
# ----------------------------------------------------------------------------------------------------------------
def ring_pts(cx, cy, z, rx, ry, n=16, p=2.0, rot=0.0):
    """Superellipse ring at height z around (cx, cy).  p=2 ellipse, p>2 squarer."""
    pts = []
    ex = 2.0 / p
    for i in range(n):
        a = rot + 2 * pi * i / n
        c, s = cos(a), sin(a)
        pts.append(Vector((cx + rx * sgnpow(c, ex), cy + ry * sgnpow(s, ex), z)))
    return pts


def ring_xz(y, cx, cz, rx, rz, n=16, p=2.0, rot=0.0):
    """Superellipse ring in the XZ plane at depth y (for bodies lofted along Y)."""
    pts = []
    ex = 2.0 / p
    for i in range(n):
        a = rot + 2 * pi * i / n
        c, s = cos(a), sin(a)
        pts.append(Vector((cx + rx * sgnpow(c, ex), y, cz + rz * sgnpow(s, ex))))
    return pts


def torus(center, R, r, segs_major=20, segs_minor=6, mat=0, wobble=None):
    """Torus lying in the XY plane around `center`.  wobble(phi) -> (dR, dz) optional radial / vertical offsets."""
    rings = []
    for i in range(segs_major):
        phi = 2 * pi * i / segs_major
        dR, dz = (0.0, 0.0) if wobble is None else wobble(phi)
        c = Vector(center) + Vector((cos(phi) * (R + dR), sin(phi) * (R + dR), dz))
        out = Vector((cos(phi), sin(phi), 0))
        ring = []
        for j in range(segs_minor):
            a = 2 * pi * j / segs_minor
            ring.append(c + out * (r * cos(a)) + Vector((0, 0, r * sin(a))))
        rings.append(ring)
    return loft(rings, closed=True, mat=mat)


def loft(rings, cap_start=True, cap_end=True, mat=0, closed=False):
    """Skin a list of rings (list of Vector lists with equal length; a ring whose points coincide becomes a pole).
    closed=True also joins the last ring to the first (torus-like loops)."""
    bm = bmesh.new()
    vr = []
    for ring in rings:
        pts = [Vector(p) for p in ring]
        c = sum(pts, Vector()) / len(pts)
        if max((p - c).length for p in pts) < 1e-6:
            vr.append([bm.verts.new(c)])
        else:
            vr.append([bm.verts.new(p) for p in pts])
    nloops = len(vr) if closed else len(vr) - 1
    for i in range(nloops):
        a, b = vr[i], vr[(i + 1) % len(vr)]
        na, nb = len(a), len(b)
        if na == 1 and nb == 1:
            continue
        if na == 1:
            for j in range(nb):
                bm.faces.new((a[0], b[(j + 1) % nb], b[j]))
        elif nb == 1:
            for j in range(na):
                bm.faces.new((a[j], a[(j + 1) % na], b[0]))
        else:
            for j in range(na):
                j2 = (j + 1) % na
                bm.faces.new((a[j], a[j2], b[j2], b[j]))
    if cap_start and not closed and len(vr[0]) > 2:
        bm.faces.new(vr[0])
    if cap_end and not closed and len(vr[-1]) > 2:
        bm.faces.new(vr[-1][::-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    fix_normals(bm)
    set_mat(bm, mat)
    return bm


def tube(pts, radii, segs=8, cap_start=True, cap_end=True, round_start=0, round_end=0, up=(0, 0, 1), rot0=0.0, mat=0, p=2.0):
    """Tapered tube along a polyline with parallel-transport frames.  radii: float or (rx, ry) per point.
    round_start / round_end = number of intermediate rings used to close the end with a hemisphere-ish cap (0 = flat cap)."""
    pts = [Vector(q) for q in pts]
    n = len(pts)
    rr = []
    for r in radii:
        rr.append((float(r), float(r)) if not isinstance(r, (tuple, list)) else (float(r[0]), float(r[1])))
    assert len(rr) == n, "tube: radii/pts mismatch"
    # tangents
    tans = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        tans.append(t.normalized())
    # frames
    upv = Vector(up)
    nrm = upv - tans[0] * upv.dot(tans[0])
    if nrm.length < 1e-4:
        nrm = Vector((1, 0, 0)) - tans[0] * tans[0].x
    nrm.normalize()
    frames = []
    for i in range(n):
        if i > 0:
            nrm = nrm - tans[i] * nrm.dot(tans[i])
            if nrm.length < 1e-5:
                nrm = tans[i].orthogonal()
            nrm.normalize()
        frames.append((tans[i], nrm.copy(), tans[i].cross(nrm).normalized()))

    def ring(c, fr, rx, ry):
        out = []
        ex = 2.0 / p
        for k in range(segs):
            a = rot0 + 2 * pi * k / segs
            ca, sa = cos(a), sin(a)
            out.append(c + fr[1] * (rx * sgnpow(ca, ex)) + fr[2] * (ry * sgnpow(sa, ex)))
        return out

    rings = []
    if round_start:
        rs = max(rr[0])
        for j in range(round_start, 0, -1):
            a = (pi / 2) * (j / (round_start + 1))
            rings.append(ring(pts[0] - frames[0][0] * (rs * sin(a)), frames[0], rr[0][0] * cos(a), rr[0][1] * cos(a)))
        # pole
        pole = pts[0] - frames[0][0] * rs
        rings.insert(0, [pole.copy() for _ in range(segs)])
    for i in range(n):
        rings.append(ring(pts[i], frames[i], rr[i][0], rr[i][1]))
    if round_end:
        re_ = max(rr[-1])
        for j in range(1, round_end + 1):
            a = (pi / 2) * (j / (round_end + 1))
            rings.append(ring(pts[-1] + frames[-1][0] * (re_ * sin(a)), frames[-1], rr[-1][0] * cos(a), rr[-1][1] * cos(a)))
        pole = pts[-1] + frames[-1][0] * re_
        rings.append([pole.copy() for _ in range(segs)])
    cs = cap_start and not round_start
    ce = cap_end and not round_end
    return loft(rings, cap_start=cs, cap_end=ce, mat=mat)


def cyl(p0, p1, r0, r1=None, segs=10, mat=0, cap0=True, cap1=True, ellipse=None):
    """Cylinder / cone frustum between two points (radius r0 at p0, r1 at p1)."""
    r1 = r0 if r1 is None else r1
    if ellipse is not None:
        return tube([p0, p1], [(r0 * ellipse[0], r0 * ellipse[1]), (r1 * ellipse[0], r1 * ellipse[1])], segs=segs, mat=mat,
                    cap_start=cap0, cap_end=cap1)
    return tube([p0, p1], [r0, r1], segs=segs, mat=mat, cap_start=cap0, cap_end=cap1)


def ellipsoid(center, radii, u=16, v=10, e=1.0, mat=0, matrix=None):
    """(Super)ellipsoid; e<1 boxier.  Optional matrix applied after scaling (rotation/translation)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vt in bm.verts:
        x, y, z = vt.co
        if e != 1.0:
            x, y, z = sgnpow(x, e), sgnpow(y, e), sgnpow(z, e)
        vt.co = Vector((x * radii[0], y * radii[1], z * radii[2]))
    if matrix is not None:
        xform(bm, matrix)
    translate(bm, center)
    fix_normals(bm)
    set_mat(bm, mat)
    return bm


def rbox(center, size, r=0.02, segs=2, matrix=None, mat=0, taper=None):
    """Box with rounded (beveled) edges.  taper=(sx, sy): scale of the +Z face relative to the -Z face."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vt in bm.verts:
        vt.co = Vector((vt.co.x * size[0], vt.co.y * size[1], vt.co.z * size[2]))
        if taper is not None and vt.co.z > 0:
            vt.co.x *= taper[0]
            vt.co.y *= taper[1]
    r = min(r, min(size) * 0.48)
    if r > 1e-5:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, offset_type='OFFSET', segments=segs, profile=0.5, affect='EDGES',
                        clamp_overlap=True)
    if matrix is not None:
        xform(bm, matrix)
    translate(bm, center)
    fix_normals(bm)
    set_mat(bm, mat)
    return bm


def box(center, size, matrix=None, mat=0):
    bm = L.bm_box(size)
    if matrix is not None:
        xform(bm, matrix)
    translate(bm, center)
    set_mat(bm, mat)
    return bm


def cone(base, tip, r, segs=10, mat=0, cap=True):
    return tube([base, tip], [r, 0.0], segs=segs, mat=mat, cap_start=cap, cap_end=False)


def displace(bm, amount=0.02, scale=3.0, seed=0, weights=(1, 1, 1)):
    L.noise_displace(bm, amount=amount, scale=scale, seed=seed, axis_weights=weights)
    return bm


def mirror_x(bm):
    """Mirror a bmesh across X=0 (flip winding)."""
    for vt in bm.verts:
        vt.co.x = -vt.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return bm


def face_mat_by(bm, fn, mat):
    """Set material index of faces for which fn(face_center) is True."""
    for f in bm.faces:
        if fn(f.calc_center_median()):
            f.material_index = mat
    return bm


def grid_surface(rows, mat=0, flip=False, double=False):
    """Open surface from a 2D list of points rows[i][j] (quads between neighbours).  double=True adds back faces."""
    bm = bmesh.new()
    vv = [[bm.verts.new(p) for p in row] for row in rows]
    for i in range(len(vv) - 1):
        for j in range(len(vv[i]) - 1):
            q = (vv[i][j], vv[i][j + 1], vv[i + 1][j + 1], vv[i + 1][j])
            if flip:
                q = q[::-1]
            try:
                bm.faces.new(q)
                if double:
                    bm.faces.new(q[::-1])
            except ValueError:
                pass
    set_mat(bm, mat)
    return bm


def hull(points, mat=0):
    """Convex hull of a point list (thin fins, wedges, plates)."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in points]
    bmesh.ops.convex_hull(bm, input=vs)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    fix_normals(bm)
    set_mat(bm, mat)
    return bm


# ----------------------------------------------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------------------------------------------
def lin(r, g, b):
    return (r, g, b)


# ----------------------------------------------------------------------------------------------------------------
# model container: naming, pivots, parenting, export, manifest
# ----------------------------------------------------------------------------------------------------------------
class Model:
    def __init__(self, mid):
        self.id = mid
        self.prefix = mid + "__"
        self.col = L.fresh_collection(mid)
        for lc in bpy.context.view_layer.layer_collection.children:
            if lc.collection == self.col:
                lc.exclude = False
                lc.hide_viewport = False
        self.obj = {}
        self.pivot = {}

    # materials -----------------------------------------------------------------------------------------------
    def m(self, key, color=(0.5, 0.5, 0.5), metallic=0.0, roughness=0.6, emission=None, emission_strength=0.0, alpha=1.0,
          double_sided=False, **kw):
        mt = L.mat("%s_%s" % (self.id, key), color, metallic=metallic, roughness=roughness, emission=emission,
                   emission_strength=emission_strength, alpha=alpha, **kw)
        if double_sided:
            mt.use_backface_culling = False
        return mt

    # objects --------------------------------------------------------------------------------------------------
    def add(self, gname, bm, mats, pivot=(0, 0, 0), parent=None, smooth_deg=35.0, smooth=True):
        """Create mesh object `gname`; bm is in model coordinates; origin placed at `pivot` (model coords)."""
        pv = Vector(pivot)
        bmesh.ops.translate(bm, vec=-pv, verts=bm.verts)
        ob = L.obj_from_bm(self.prefix + gname, bm, self.col, list(mats), smooth=smooth)
        if smooth and smooth_deg is not None:
            L.set_smooth_by_angle(ob, smooth_deg)
        self._attach(gname, ob, pv, parent)
        return ob

    def empty(self, gname, pos=(0, 0, 0), parent=None, display="PLAIN_AXES", size=0.05):
        e = L.empty(self.prefix + gname, self.col, location=(0, 0, 0), display=display, size=size)
        self._attach(gname, e, Vector(pos), parent)
        return e

    def _attach(self, gname, ob, pv, parent):
        if isinstance(parent, str):
            parent = self.obj[parent]
        if parent is not None:
            ob.parent = parent
            ob.location = pv - self.pivot[parent.name[len(self.prefix):]]
        else:
            ob.location = pv
        self.obj[gname] = ob
        self.pivot[gname] = pv

    def meshes(self):
        return [o for o in self.col.objects if o.type == "MESH"]

    def update(self):
        bpy.context.view_layer.update()

    # info -----------------------------------------------------------------------------------------------------
    def stats(self):
        self.update()
        ms = self.meshes()
        mn, mx = L.bounds(ms)
        return dict(tris=L.tri_count(ms), mn=mn, mx=mx, size=mx - mn)

    def report(self):
        s = self.stats()
        print("[%s] tris=%d size_blender(x,y,z)=(%.3f, %.3f, %.3f) min=(%.3f,%.3f,%.3f) max=(%.3f,%.3f,%.3f)" % (
            self.id, s["tris"], s["size"].x, s["size"].y, s["size"].z, s["mn"].x, s["mn"].y, s["mn"].z, s["mx"].x, s["mx"].y,
            s["mx"].z))
        for o in sorted(self.meshes(), key=lambda o: o.name):
            o.data.calc_loop_triangles()
            print("   %-28s tris=%5d mats=%s" % (o.name[len(self.prefix):], len(o.data.loop_triangles),
                                                  [m.name.replace(self.id + "_", "") for m in o.data.materials]))
        return s

    # preview --------------------------------------------------------------------------------------------------
    def preview(self, name=None, views=None, size=(400, 400), cols=3, dist_mult=1.55, bg=(0.11, 0.13, 0.18), ground=True, focus=None):
        name = name or self.id
        if views is None:
            views = ((150, 14), (90, 8), (0, 14), (210, 14), (180, 4), (0, 85))
        self.update()
        fobjs = [self.obj[g] for g in focus] if focus else self.meshes()
        with self.isolated():
            paths = L.preview(fobjs, name, views=views, size=size, dist_mult=dist_mult, bg=bg, ground=ground)
            sheet = L.montage(paths, name + "_sheet", cols=cols)
        print("PREVIEW:", sheet)
        return sheet

    # isolation + custom camera render ----------------------------------------------------------------------------
    def isolated(self):
        """Context manager: render only this model's collection (other collections / loose objects hidden), exception-safe."""
        from contextlib import contextmanager

        @contextmanager
        def _cm():
            vl = bpy.context.view_layer
            saved = []
            hidden = []
            try:
                def walk(lc):
                    for c in lc.children:
                        saved.append((c, c.exclude))
                        walk(c)

                walk(vl.layer_collection)
                for o in bpy.context.scene.collection.objects:
                    if o.name not in self.col.objects:
                        hidden.append((o, o.hide_render))
                for lc, ex in saved:
                    lc.exclude = (lc.collection != self.col)
                for o, h in hidden:
                    o.hide_render = True
                yield
            finally:
                for lc, ex in saved:
                    try:
                        lc.exclude = ex
                    except Exception:
                        pass
                for o, h in hidden:
                    try:
                        o.hide_render = h
                    except Exception:
                        pass
        return _cm()

    def render_view(self, name, loc, target, fov=70.0, size=(800, 450), bg=(0.12, 0.14, 0.18), sun_energy=3.5, up=(0, 0, 1)):
        """Render one image from a custom camera (vertical FOV in degrees).  Returns the png path."""
        os.makedirs(L.PREVIEW_DIR, exist_ok=True)
        self.update()
        sc = bpy.context.scene
        saved = dict(engine=sc.render.engine, rx=sc.render.resolution_x, ry=sc.render.resolution_y, pct=sc.render.resolution_percentage,
                     cam=sc.camera, fp=sc.render.filepath, world=sc.world)
        world = bpy.data.worlds.new("__rv_world")
        world.use_nodes = True
        bgn = world.node_tree.nodes.get("Background")
        bgn.inputs["Color"].default_value = (bg[0], bg[1], bg[2], 1)
        bgn.inputs["Strength"].default_value = 1.0
        sc.world = world
        cam_d = bpy.data.cameras.new("__rv_cam")
        cam_d.sensor_fit = 'VERTICAL'
        cam_d.angle = math.radians(fov)
        cam_d.clip_start = 0.02
        cam_d.clip_end = 500
        cam = bpy.data.objects.new("__rv_cam", cam_d)
        sc.collection.objects.link(cam)
        sun_d = bpy.data.lights.new("__rv_sun", "SUN")
        sun_d.energy = sun_energy
        sun = bpy.data.objects.new("__rv_sun", sun_d)
        sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
        sc.collection.objects.link(sun)
        fill_d = bpy.data.lights.new("__rv_fill", "SUN")
        fill_d.energy = 1.2
        fill = bpy.data.objects.new("__rv_fill", fill_d)
        fill.rotation_euler = (math.radians(70), 0, math.radians(-140))
        sc.collection.objects.link(fill)
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler() if up == (0, 0, 1) else             (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.camera = cam
        sc.render.engine = "BLENDER_EEVEE"
        sc.render.resolution_x, sc.render.resolution_y = size
        sc.render.resolution_percentage = 100
        sc.render.image_settings.file_format = "PNG"
        path = os.path.join(L.PREVIEW_DIR, name + ".png")
        sc.render.filepath = path
        try:
            with self.isolated():
                bpy.ops.render.render(write_still=True)
        finally:
            for o in (cam, sun, fill):
                try:
                    bpy.data.objects.remove(o, do_unlink=True)
                except Exception:
                    pass
            for blk, coll in ((cam_d, bpy.data.cameras), (sun_d, bpy.data.lights), (fill_d, bpy.data.lights)):
                try:
                    coll.remove(blk)
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
        print("RENDER:", path)
        return path

    # export ---------------------------------------------------------------------------------------------------
    def export(self, root_gnames):
        """Export one or several root objects (str or list of gnames) + their children to <id>.glb."""
        if isinstance(root_gnames, str):
            root_gnames = [root_gnames]
        roots = [self.obj[g] for g in root_gnames]
        self.update()
        allobjs = []

        def add(o):
            allobjs.append(o)
            for c in o.children:
                add(c)

        for r in roots:
            add(r)
        mine = set(allobjs)
        renamed = []
        foreign = []
        try:
            for o in allobjs:
                final = o.name[len(self.prefix):]
                other = bpy.data.objects.get(final)
                if other is not None and other not in mine:
                    old = other.name
                    other.name = "__tmp_foreign_%d" % len(foreign)
                    foreign.append((other, old))
                renamed.append((o, o.name))
                o.name = final
            path = L.export_glb(roots, self.id)
        finally:
            for o, old in renamed:
                o.name = old
            for o, old in foreign:
                o.name = old
        print("EXPORTED:", path, os.path.getsize(path), "bytes")
        return path

    # manifest -------------------------------------------------------------------------------------------------
    def manifest(self, kind, biomes, collider, nodes=None, notes="", tintable=None):
        s = self.stats()
        size = [round(s["size"].x, 3), round(s["size"].z, 3), round(s["size"].y, 3)]
        entry = {
            "id": self.id,
            "file": self.id + ".glb",
            "kind": kind,
            "biomes": biomes,
            "size": size,
            "base_y": round(s["mn"].z, 3),
            "collider": collider,
            "tris": s["tris"],
        }
        if tintable:
            entry["tintable"] = tintable
        if nodes:
            entry["nodes"] = nodes
        entry["notes"] = notes
        data = {"group": "astro", "models": []}
        if os.path.exists(MANIFEST):
            try:
                with open(MANIFEST, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                pass
        data["group"] = "astro"
        data["models"] = [m for m in data.get("models", []) if m.get("id") != self.id] + [entry]
        order = ["astronaut", "multitool", "fp_viewmodel", "creature_quadruped_a", "creature_floater_a", "creature_flyer_a",
                 "creature_crawler_a"]
        data["models"].sort(key=lambda m: order.index(m["id"]) if m["id"] in order else 99)
        with open(MANIFEST, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print("MANIFEST updated:", entry["id"], size, "tris", entry["tris"])
        return entry
