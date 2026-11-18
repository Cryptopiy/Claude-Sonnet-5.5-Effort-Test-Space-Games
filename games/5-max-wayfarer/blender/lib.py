"""WAYFARER shared modelling library (Blender 5.2, bmesh based, no operators needed).

Usage inside Blender (via tools/bl.py file ...):
    exec(compile(open(r'W:\\YouTube\\Sonnet 5.5 Effort Test\\5. Max Effort\\blender\\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

Main pieces
  * colour / material factory:   mat(name, ...), palette()  (Principled BSDF only)
  * MB  - mesh builder holding one bmesh + material slot list:
        loft(rings), lathe(profile), sphere/ellipsoid/cyl/cone/capsule/torus, rbox (bevelled box),
        slab (extruded 2D polygon), tube (circle swept along a path), strip decals, paint helpers ...
        finish(name, coll, ...)  -> bpy object (smooth shading + sharp edges by angle + optional weighted normals)
  * parenting that keeps the world position, set_origin(), fresh_collection(), empties
  * interpolation helpers (pchip), airfoil / superellipse outlines
  * preview helpers (shot / sheet) and a mesh health report (check)
"""
import bpy, bmesh, math, random, os, json, time
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.bvhtree import BVHTree
from mathutils import geometry as mgeo

PROJECT = r"W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort"
V = Vector
PI = math.pi
TAU = 2 * math.pi
EPS = 1e-7


# ----------------------------------------------------------------------------------------------
# small math helpers
# ----------------------------------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, a=0.0, b=1.0):
    return a if x < a else (b if x > b else x)


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a)) if b != a else 0.0
    return t * t * (3 - 2 * t)


def rad(d):
    return math.radians(d)


def srgb(h):
    """'#RRGGBB' or (r,g,b) 0-255 sRGB -> linear RGBA tuple for Blender."""
    if isinstance(h, str):
        h = h.lstrip('#')
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    else:
        r, g, b = h[:3]

    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)


def pchip(xs, ys):
    """Monotone cubic (Fritsch-Carlson) interpolant; clamps outside the range. Returns f(x)."""
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    if n == 2:
        m = [d[0], d[0]]
    else:
        for i in range(1, n - 1):
            if d[i - 1] * d[i] > 0:
                w1 = 2 * h[i] + h[i - 1]
                w2 = h[i] + 2 * h[i - 1]
                m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
            else:
                m[i] = 0.0
        m[0] = ((2 * h[0] + h[1]) * d[0] - h[0] * d[1]) / (h[0] + h[1])
        if m[0] * d[0] <= 0:
            m[0] = 0.0
        elif d[0] * d[1] <= 0 and abs(m[0]) > abs(3 * d[0]):
            m[0] = 3 * d[0]
        m[-1] = ((2 * h[-1] + h[-2]) * d[-1] - h[-1] * d[-2]) / (h[-1] + h[-2])
        if m[-1] * d[-1] <= 0:
            m[-1] = 0.0
        elif d[-1] * d[-2] <= 0 and abs(m[-1]) > abs(3 * d[-1]):
            m[-1] = 3 * d[-1]

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        lo, hi = 0, n - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if xs[mid] <= x:
                lo = mid
            else:
                hi = mid
        i = lo
        t = (x - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i] +
                (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])
    return f


def spow(x, p):
    """signed power"""
    return math.copysign(abs(x) ** p, x)


def superellipse(n_pts, a, b, n=2.0, start=0.0, cx=0.0, cy=0.0):
    """closed ccw outline (x,y) pairs of |x/a|^n+|y/b|^n=1"""
    out = []
    for k in range(n_pts):
        t = start + TAU * k / n_pts
        c, s = math.cos(t), math.sin(t)
        out.append((cx + a * spow(c, 2.0 / n), cy + b * spow(s, 2.0 / n)))
    return out


def circle_pts(n, r, cx=0.0, cy=0.0, start=0.0):
    return [(cx + r * math.cos(start + TAU * k / n), cy + r * math.sin(start + TAU * k / n)) for k in range(n)]


def airfoil(n_half, t, te=0.01, camber=0.0, flat_bottom=0.0):
    """Closed airfoil outline in unit chord: starts at the upper trailing edge (x=1), runs over the top to the
    leading edge (x=0) and back along the underside. 2*n_half+1 points of (x, z). t = thickness ratio,
    te = half thickness added at the trailing edge, flat_bottom 0..1 flattens the underside."""
    top, bot = [], []
    for i in range(n_half + 1):
        beta = PI * i / n_half
        x = 0.5 * (1 + math.cos(beta))
        yt = 5 * t * (0.2969 * math.sqrt(x) - 0.1260 * x - 0.3516 * x * x + 0.2843 * x ** 3 - 0.1015 * x ** 4) + te * x
        yc = camber * 4 * x * (1 - x)
        top.append((x, yc + yt))
        yb = yc - yt
        yb = lerp(yb, 0.0, flat_bottom * smoothstep(0.0, 0.3, x))
        bot.append((x, yb))
    return top + list(reversed(bot[:-1]))


# ----------------------------------------------------------------------------------------------
# scene / collection helpers
# ----------------------------------------------------------------------------------------------
def fresh_collection(name):
    """delete collection + its objects (and orphaned meshes) and create it new under the scene collection"""
    c = bpy.data.collections.get(name)
    if c:
        for o in list(c.all_objects):
            me = o.data if o.type == 'MESH' else None
            bpy.data.objects.remove(o, do_unlink=True)
            if me is not None and me.users == 0:
                bpy.data.meshes.remove(me)
        bpy.data.collections.remove(c)
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


def park(coll_name):
    """Blender object names are unique per file but every model needs its exact brief names (Marker_Eye, Hull ...).
    A finished model is therefore 'parked': its objects get the suffix '__<collection>'.  unpark() strips it again
    (only needed while exporting / re-editing).  Model scripts delete their own collection first, so parked objects never block them."""
    c = bpy.data.collections.get(coll_name)
    if not c:
        return
    suf = "__" + coll_name
    for o in c.all_objects:
        if not o.name.endswith(suf):
            o.name = o.name + suf


def unpark(coll_name):
    c = bpy.data.collections.get(coll_name)
    if not c:
        return
    suf = "__" + coll_name
    for o in c.all_objects:
        if o.name.endswith(suf):
            o.name = o.name[:-len(suf)]


def export_parked(name, **kw):
    """unpark -> export_model (needs export_lib.py exec'd) -> park again"""
    unpark(name)
    try:
        return export_model(name, **kw)
    finally:
        park(name)


def purge_orphans():
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def empty(name, loc, coll, parent=None, size=0.25, kind='PLAIN_AXES'):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    e.location = Vector(loc)
    coll.objects.link(e)
    if parent is not None:
        parent_keep(e, parent)
    return e


def parent_keep(child, parent):
    """parent while keeping the world transform (child must have no stale parent)."""
    bpy.context.view_layer.update()
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    child.matrix_world = mw
    return child


def set_origin(obj, point):
    """move the object origin to the world point without moving the geometry (object must have rot=0, scale=1)."""
    bpy.context.view_layer.update()
    p = Vector(point)
    delta_world = p - obj.matrix_world.translation
    if obj.type == 'MESH':
        me = obj.data
        inv = obj.matrix_world.to_3x3().inverted()
        me.transform(Matrix.Translation(-(inv @ delta_world)))
        me.update()
    if obj.parent is None:
        obj.location = p
    else:
        # children keep their world positions
        kids = list(obj.children)
        kid_mw = [k.matrix_world.copy() for k in kids]
        obj.matrix_world = Matrix.Translation(p)
        bpy.context.view_layer.update()
        for k, m in zip(kids, kid_mw):
            k.matrix_world = m
    return obj


def link_obj(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)


def tri_count(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    ev.to_mesh_clear()
    return n


def apply_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    new_me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = new_me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


# ----------------------------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------------------------
def mat(name, color="#CCCCCC", metal=0.0, rough=0.5, emit=None, emit_strength=0.0, alpha=1.0, blended=False,
        cull=True, ior=None):
    """get-or-create a Principled BSDF material and (re)set its values. color/emit: '#RRGGBB' sRGB hex."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = None
    for n in nt.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            bsdf = n
    if bsdf is None:
        nt.nodes.clear()
        bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
        out = nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value = srgb(color) if not isinstance(color, tuple) or max(color) > 1.0 else color
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Alpha'].default_value = alpha
    if ior is not None:
        bsdf.inputs['IOR'].default_value = ior
    if emit is not None and emit_strength > 0:
        bsdf.inputs['Emission Color'].default_value = srgb(emit)
        bsdf.inputs['Emission Strength'].default_value = emit_strength
    else:
        bsdf.inputs['Emission Color'].default_value = (0, 0, 0, 1)
        bsdf.inputs['Emission Strength'].default_value = 0.0
    m.surface_render_method = 'BLENDED' if blended else 'DITHERED'
    m.use_backface_culling = bool(cull)
    return m


def palette():
    """the common hull / structure materials (idempotent)."""
    P = {}
    P['Hull_Paint'] = mat('Hull_Paint', '#E9E6DE', metal=0.25, rough=0.45)
    P['Hull_Accent'] = mat('Hull_Accent', '#F26A14', metal=0.2, rough=0.45)
    P['Hull_Dark'] = mat('Hull_Dark', '#3A3F48', metal=0.8, rough=0.45)
    P['Metal'] = mat('Metal', '#A8ADB4', metal=1.0, rough=0.35)
    P['Rubber'] = mat('Rubber', '#232426', metal=0.0, rough=0.9)
    P['Glass'] = mat('Glass', '#9CC4F0', metal=0.0, rough=0.05, alpha=0.25, blended=True, cull=False)
    P['Emissive_Engine'] = mat('Emissive_Engine', '#BFE6FF', rough=0.4, emit='#3AA9FF', emit_strength=8.0)
    P['Emissive_Light'] = mat('Emissive_Light', '#CFF6FF', rough=0.4, emit='#4FCFFF', emit_strength=2.4)
    P['Emissive_Amber'] = mat('Emissive_Amber', '#FFD08A', rough=0.4, emit='#FFA21F', emit_strength=3.0)
    P['Emissive_Screen'] = mat('Emissive_Screen', '#BFF6FF', rough=0.3, emit='#25C8FF', emit_strength=2.2)
    P['Emissive_ScreenAmber'] = mat('Emissive_ScreenAmber', '#FFE0A0', rough=0.3, emit='#FFA81C', emit_strength=2.5)
    P['Emissive_NavRed'] = mat('Emissive_NavRed', '#FF8080', rough=0.4, emit='#FF1010', emit_strength=6.0)
    P['Emissive_NavGreen'] = mat('Emissive_NavGreen', '#80FF98', rough=0.4, emit='#10FF40', emit_strength=6.0)
    P['Emissive_Window'] = mat('Emissive_Window', '#FFD99A', rough=0.3, emit='#FFA83A', emit_strength=2.5)
    return P


# ----------------------------------------------------------------------------------------------
# mesh builder
# ----------------------------------------------------------------------------------------------
class Part:
    """handle for a created island: ring vertices, faces per band etc."""

    def __init__(self):
        self.R = []        # list of rings (list of BMVert)
        self.bands = []    # list (per band) of list (per column) of BMFace/None
        self.faces = []
        self.verts = []
        self.caps = []

    def band_faces(self, i0, i1, cols=None):
        out = []
        for bi in range(max(0, i0), min(len(self.bands), i1)):
            band = self.bands[bi]
            for k, f in enumerate(band):
                if f is not None and (cols is None or k in cols):
                    out.append(f)
        return out


class MB:
    def __init__(self, name="mesh"):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    # --- materials ------------------------------------------------------------------------
    def mi(self, m):
        name = m if isinstance(m, str) else m.name
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    # --- low level ------------------------------------------------------------------------
    def grid(self, rings, closed=True, mat='Hull_Paint', smooth=True, cap_a=False, cap_b=False,
             cap_kind='fan', outward=True, loop_rings=False):
        """rings: list of equal-length lists of points. Degenerate rings (all points equal) become poles."""
        bm = self.bm
        mi = self.mi(mat)
        part = Part()
        n = len(rings[0])
        R = []
        for ring in rings:
            p0 = Vector(ring[0])
            degenerate = all((Vector(p) - p0).length < 1e-6 for p in ring)
            if degenerate:
                v = bm.verts.new(p0)
                R.append([v] * n)
            else:
                R.append([bm.verts.new(Vector(p)) for p in ring])
        part.R = R
        faces = []
        nb = len(rings) if loop_rings else len(rings) - 1
        for i in range(nb):
            band = []
            kmax = n if closed else n - 1
            i2 = (i + 1) % len(rings)
            for k in range(kmax):
                k2 = (k + 1) % n
                quad = (R[i][k], R[i][k2], R[i2][k2], R[i2][k])
                vs = []
                for v in quad:
                    if v not in vs:
                        vs.append(v)
                f = None
                if len(vs) >= 3:
                    try:
                        f = bm.faces.new(vs)
                        f.material_index = mi
                        f.smooth = smooth
                        faces.append(f)
                    except ValueError:
                        f = None
                band.append(f)
            part.bands.append(band)
        for (flag, ring, first) in ((cap_a, R[0], True), (cap_b, R[-1], False)):
            if not flag or not closed:
                continue
            uniq = []
            for v in ring:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) < 3:
                continue
            m_ = len(uniq)
            if cap_kind == 'fan':
                c = sum((v.co for v in uniq), Vector()) / m_
                cv = bm.verts.new(c)
                for k in range(m_):
                    a, b = uniq[k], uniq[(k + 1) % m_]
                    try:
                        f = bm.faces.new((cv, b, a) if first else (cv, a, b))
                        f.material_index = mi
                        f.smooth = smooth
                        faces.append(f)
                        part.caps.append(f)
                    except ValueError:
                        pass
            else:
                try:
                    f = bm.faces.new(list(reversed(uniq)) if first else uniq)
                    f.material_index = mi
                    f.smooth = smooth
                    faces.append(f)
                    part.caps.append(f)
                except ValueError:
                    pass
        part.faces = faces
        vs = set()
        for f in faces:
            for v in f.verts:
                vs.add(v)
        part.verts = list(vs)
        if outward:
            self.fix_outward(part.faces)
        return part

    def fix_outward(self, faces):
        """flip the winding of the whole island if its signed volume is negative."""
        vol = 0.0
        for f in faces:
            vs = f.verts
            c0 = vs[0].co
            for i in range(1, len(vs) - 1):
                a, b = vs[i].co, vs[i + 1].co
                vol += c0.dot(a.cross(b)) / 6.0
        if vol < 0:
            for f in faces:
                f.normal_flip()
        return vol

    # --- generic lofts --------------------------------------------------------------------
    def loft(self, rings, mat='Hull_Paint', cap_a=True, cap_b=True, closed=True, smooth=True, cap_kind='fan'):
        return self.grid(rings, closed=closed, mat=mat, smooth=smooth, cap_a=cap_a, cap_b=cap_b, cap_kind=cap_kind)

    def lathe(self, profile, segs=24, m=None, mat='Hull_Paint', cap_a=None, cap_b=None, smooth=True, closed=True,
              a0=0.0, a1=TAU, cap_kind='fan'):
        """profile: [(r, h), ...] revolved around local Z. m: Matrix 4x4 placing it. Caps are automatic
        when the end radius is > 0 (set cap_a/cap_b False to keep it open)."""
        m = m if m is not None else Matrix.Identity(4)
        if closed and abs((a1 - a0) - TAU) > 1e-6:
            closed = False
        nseg = segs if closed else segs + 1
        rings = []
        for (r, h) in profile:
            ring = []
            for k in range(nseg):
                a = a0 + (a1 - a0) * k / (segs if not closed else segs)
                ring.append(m @ Vector((r * math.cos(a), r * math.sin(a), h)))
            rings.append(ring)
        if cap_a is None:
            cap_a = profile[0][0] > 1e-6
        if cap_b is None:
            cap_b = profile[-1][0] > 1e-6
        return self.grid(rings, closed=closed, mat=mat, smooth=smooth, cap_a=cap_a, cap_b=cap_b, cap_kind=cap_kind)

    def lathe_mats(self, profile, segs=24, m=None, cap_a=None, cap_b=None, smooth=True, closed=True, a0=0.0, a1=TAU):
        """lathe whose profile entries are (r, h, mat): mat colours the band ARRIVING at that point."""
        part = self.lathe([(r, h) for (r, h, _) in profile], segs, m, mat=profile[1][2], cap_a=cap_a, cap_b=cap_b,
                          smooth=smooth, closed=closed, a0=a0, a1=a1)
        for bi, band in enumerate(part.bands):
            mi = self.mi(profile[bi + 1][2])
            for f in band:
                if f is not None:
                    f.material_index = mi
        return part

    # --- primitives ----------------------------------------------------------------------
    @staticmethod
    def xf(center=(0, 0, 0), rot=None, scale=(1, 1, 1)):
        """build a transform matrix. rot = Euler (radians) tuple or Quaternion or Matrix3 or None."""
        m = Matrix.Translation(Vector(center))
        if rot is not None:
            if isinstance(rot, Quaternion):
                m = m @ rot.to_matrix().to_4x4()
            elif isinstance(rot, Matrix):
                m = m @ rot.to_4x4()
            else:
                m = m @ Euler(rot, 'XYZ').to_matrix().to_4x4()
        if tuple(scale) != (1, 1, 1):
            m = m @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        return m

    @staticmethod
    def aim(direction, up=(0, 0, 1)):
        """rotation matrix (3x3) whose local +Z points along direction."""
        z = Vector(direction).normalized()
        u = Vector(up)
        if abs(z.dot(u.normalized())) > 0.999:
            u = Vector((1, 0, 0))
        x = u.cross(z).normalized()
        y = z.cross(x)
        return Matrix((x, y, z)).transposed()

    def sphere(self, r, center=(0, 0, 0), segs=16, rings=None, mat='Hull_Paint', scale=(1, 1, 1), rot=None, smooth=True):
        rings = rings or max(4, segs // 2)
        prof = [(r * math.sin(PI * i / rings), -r * math.cos(PI * i / rings)) for i in range(rings + 1)]
        prof[0] = (0.0, prof[0][1])
        prof[-1] = (0.0, prof[-1][1])
        return self.lathe(prof, segs, self.xf(center, rot, scale), mat=mat, smooth=smooth)

    def hemi(self, r, center=(0, 0, 0), segs=16, rings=6, mat='Hull_Paint', scale=(1, 1, 1), rot=None, cap=True, lat0=0.0):
        """dome: upper hemisphere (local +Z); lat0 = start latitude (rad above equator; negative goes below)"""
        prof = []
        for i in range(rings + 1):
            lat = lat0 + (PI / 2 - lat0) * i / rings
            prof.append((r * math.cos(lat), r * math.sin(lat)))
        prof[-1] = (0.0, prof[-1][1])
        return self.lathe(prof, segs, self.xf(center, rot, scale), mat=mat, cap_a=cap, cap_b=False)

    def cyl(self, r, h, center=(0, 0, 0), segs=16, mat='Hull_Paint', rot=None, r2=None, bevel=0.0, bsegs=2, caps=True,
            smooth=True, scale=(1, 1, 1), centered=True):
        """cylinder/cone frustum along local Z. center = middle of the axis (centered) or bottom centre."""
        r2 = r if r2 is None else r2
        z0 = -h / 2 if centered else 0.0
        prof = []
        if bevel > 0 and caps:
            b = min(bevel, r * 0.49, (r2 * 0.49 if r2 > 0 else bevel), h * 0.49)
            prof.append((0.0, z0))
            for i in range(bsegs + 1):
                a = (PI / 2) * i / bsegs
                prof.append((max(0.0, r - b + b * math.sin(a)), z0 + b * (1 - math.cos(a))))
            for i in range(bsegs + 1):
                a = (PI / 2) * i / bsegs
                prof.append((max(0.0, r2 - b + b * math.cos(a)), z0 + h - b + b * math.sin(a)))
            prof.append((0.0, z0 + h))
            # fix slanted wall for r2 != r: first/last wall points are correct; ok
            prof = [(p[0], p[1]) for p in prof]
            return self.lathe(prof, segs, self.xf(center, rot, scale), mat=mat, cap_a=False, cap_b=False, smooth=smooth)
        prof = [(r, z0), (r2, z0 + h)]
        if caps:
            prof = [(0.0, z0)] + prof + [(0.0, z0 + h)]
        return self.lathe(prof, segs, self.xf(center, rot, scale), mat=mat, cap_a=False, cap_b=False, smooth=smooth)

    def capsule(self, r, length, center=(0, 0, 0), segs=14, mat='Hull_Paint', rot=None, r2=None, rings=5, scale=(1, 1, 1)):
        """capsule along local Z: total length = length (including both round ends). r2 = radius of the top end."""
        r2 = r if r2 is None else r2
        prof = []
        z0 = -length / 2
        # bottom hemisphere
        for i in range(rings + 1):
            a = -PI / 2 + (PI / 2) * i / rings
            prof.append((r * math.cos(a), z0 + r + r * math.sin(a)))
        for i in range(rings + 1):
            a = (PI / 2) * i / rings
            prof.append((r2 * math.cos(a), z0 + length - r2 + r2 * math.sin(a)))
        prof[0] = (0.0, prof[0][1])
        prof[-1] = (0.0, prof[-1][1])
        return self.lathe(prof, segs, self.xf(center, rot, scale), mat=mat)

    def torus(self, R, r, center=(0, 0, 0), segs=24, tsegs=8, mat='Hull_Paint', rot=None, a0=0.0, a1=TAU, scale=(1, 1, 1)):
        m = self.xf(center, rot, scale)
        closed = abs((a1 - a0) - TAU) < 1e-6
        nseg = segs if closed else segs + 1
        rings = []
        for k in range(nseg):
            a = a0 + (a1 - a0) * k / segs
            ring = []
            for j in range(tsegs):
                b = TAU * j / tsegs
                rr = R + r * math.cos(b)
                ring.append(m @ Vector((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
            rings.append(ring)
        if closed:
            part = self.grid(rings, closed=True, mat=mat, outward=False, loop_rings=True)
        else:
            part = self.grid(rings, closed=True, mat=mat, cap_a=True, cap_b=True, outward=False)
        self.fix_outward(part.faces)
        return part

    def rbox(self, size, center=(0, 0, 0), rot=None, bevel=0.03, bsegs=2, mat='Hull_Paint', smooth=True, taper=None):
        """bevelled box. size=(x,y,z). taper=(sx,sy): scale of the top face (z+) relative to bottom -> frustum."""
        sx, sy, sz = size
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        for v in t.verts:
            fx, fy, fz = v.co.x, v.co.y, v.co.z
            k = 1.0
            if taper is not None:
                u = fz + 0.5
                k_x = lerp(1.0, taper[0], u)
                k_y = lerp(1.0, taper[1], u)
                v.co = Vector((fx * sx * k_x, fy * sy * k_y, fz * sz))
            else:
                v.co = Vector((fx * sx, fy * sy, fz * sz))
        if bevel > 0:
            b = min(bevel, min(sx, sy, sz) * 0.49)
            bmesh.ops.bevel(t, geom=list(t.edges), offset=b, offset_type='OFFSET', segments=bsegs, profile=0.5,
                            affect='EDGES', clamp_overlap=True)
        m = self.xf(center, rot)
        return self.append_bm(t, m, mat, smooth)

    def append_bm(self, src, m, mat, smooth=True, mat_map=None):
        """copy another bmesh into this builder (transformed by m)."""
        bm = self.bm
        mi = self.mi(mat) if mat is not None else 0
        vmap = {}
        part = Part()
        for v in src.verts:
            vmap[v] = bm.verts.new(m @ v.co)
        for f in src.faces:
            try:
                nf = bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mi
            nf.smooth = smooth
            part.faces.append(nf)
        part.verts = list(vmap.values())
        src.free()
        self.fix_outward(part.faces)
        return part

    def slab(self, poly, thick, mat='Hull_Paint', m=None, z0=0.0, bevel=0.0, bsegs=1, smooth=False, holes=None):
        """extrude a 2D polygon [(x,y),...] (in local XY, any winding) from z0 to z0+thick, placed by matrix m.
        holes: list of polygons (not supported with bevel)."""
        m = m if m is not None else Matrix.Identity(4)
        t = bmesh.new()

        def area2(pl):
            return sum(pl[i][0] * pl[(i + 1) % len(pl)][1] - pl[(i + 1) % len(pl)][0] * pl[i][1] for i in range(len(pl)))
        outer = list(poly)
        if area2(outer) < 0:
            outer.reverse()
        polys = [outer]
        for h in (holes or []):
            h = list(h)
            if area2(h) > 0:
                h.reverse()
            polys.append(h)
        tris = mgeo.tessellate_polygon([[Vector((x, y, 0)) for (x, y) in pl] for pl in polys])
        flat = [p for pl in polys for p in pl]
        bot = [t.verts.new(Vector((x, y, z0))) for (x, y) in flat]
        top = [t.verts.new(Vector((x, y, z0 + thick))) for (x, y) in flat]
        for tri in tris:
            tri = list(tri)
            ax, ay = flat[tri[0]]
            bx, by = flat[tri[1]]
            cx, cy = flat[tri[2]]
            if (bx - ax) * (cy - ay) - (cx - ax) * (by - ay) < 0:
                tri.reverse()
            try:
                t.faces.new([top[i] for i in tri])
                t.faces.new([bot[i] for i in reversed(tri)])
            except ValueError:
                pass
        off = 0
        for pl in polys:
            n = len(pl)
            for i in range(n):
                a, b = off + i, off + (i + 1) % n
                try:
                    t.faces.new((bot[a], bot[b], top[b], top[a]))
                except ValueError:
                    pass
            off += n
        if bevel > 0:
            bmesh.ops.bevel(t, geom=list(t.edges), offset=min(bevel, thick * 0.45), offset_type='OFFSET', segments=bsegs,
                            profile=0.5, affect='EDGES', clamp_overlap=True)
        return self.append_bm(t, m, mat, smooth)

    def tube(self, path, radii, segs=10, mat='Hull_Paint', cap_a=True, cap_b=True, up=(0, 0, 1), close=False, smooth=True,
             fixed_up=False, squash=1.0):
        """circle swept along a polyline path (list of points). radii: float or list per point.
        close=True makes a closed loop (no caps). fixed_up=True builds each frame from `up` (no propagation)."""
        pts = [Vector(p) for p in path]
        n = len(pts)
        if not isinstance(radii, (list, tuple)):
            radii = [radii] * n
        rings = []
        prev_x = None
        for i, p in enumerate(pts):
            if close:
                t = (pts[(i + 1) % n] - pts[i]).normalized() + (pts[i] - pts[(i - 1) % n]).normalized()
            elif i == 0:
                t = pts[1] - pts[0]
            elif i == n - 1:
                t = pts[-1] - pts[-2]
            else:
                t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
            t = t.normalized()
            u = Vector(up)
            if fixed_up or prev_x is None:
                if abs(t.dot(u.normalized())) > 0.99:
                    u = Vector((1, 0, 0))
                x = u.cross(t).normalized()
            else:
                x = prev_x - t * prev_x.dot(t)
                if x.length < 1e-6:
                    x = Vector((1, 0, 0)).cross(t)
                x = x.normalized()
            y = t.cross(x)
            prev_x = x
            ring = [p + (x * math.cos(TAU * k / segs) + y * math.sin(TAU * k / segs) * squash) * radii[i] for k in range(segs)]
            rings.append(ring)
        if close:
            return self.grid(rings, closed=True, mat=mat, smooth=smooth, loop_rings=True)
        return self.grid(rings, closed=True, mat=mat, cap_a=cap_a, cap_b=cap_b, smooth=smooth)

    # --- painting -------------------------------------------------------------------------
    def paint(self, faces, mat):
        mi = self.mi(mat)
        for f in faces:
            if f is not None and f.is_valid:
                f.material_index = mi

    def faces_where(self, pred):
        return [f for f in self.bm.faces if pred(f.calc_center_median(), f)]

    def paint_where(self, pred, mat, only_mats=None):
        mi = self.mi(mat)
        om = None if only_mats is None else set(self.mi(m) for m in only_mats)
        for f in self.bm.faces:
            if om is not None and f.material_index not in om:
                continue
            if pred(f.calc_center_median(), f):
                f.material_index = mi

    def cut_plane(self, point, normal, dist=1e-5, faces=None):
        """bisect all (or given) faces with a plane so material boundaries can follow it"""
        bm = self.bm
        geom = list(bm.faces) + list(bm.edges) + list(bm.verts) if faces is None else \
            list(faces) + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
        r = bmesh.ops.bisect_plane(bm, geom=geom, dist=dist, plane_co=Vector(point), plane_no=Vector(normal))
        return r

    # --- output ---------------------------------------------------------------------------
    def to_mesh(self, name=None):
        me = bpy.data.meshes.new(name or self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        used = sorted(set(p.material_index for p in me.polygons))
        # compact material slots
        remap = {}
        slots = []
        for u in used:
            remap[u] = len(slots)
            slots.append(self.mats[u] if u < len(self.mats) else self.mats[0])
        for p in me.polygons:
            p.material_index = remap.get(p.material_index, 0)
        for s in slots:
            me.materials.append(bpy.data.materials[s])
        return me

    def finish(self, name, coll, smooth_angle=40.0, weighted=True, loc=(0, 0, 0), merge_dist=None, wn_weight=50,
               parent=None, tag_seams=False):
        """create the object, apply smooth shading by angle (+ optional weighted normals)."""
        bm = self.bm
        if merge_dist:
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=merge_dist)
        # sharp edges by angle
        thr = rad(smooth_angle)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                try:
                    ang = e.calc_face_angle(0.0)
                except ValueError:
                    ang = 0.0
                e.smooth = ang < thr
            else:
                e.smooth = True
        # drop degenerate faces and loose geometry
        zero = [f for f in bm.faces if f.calc_area() < 1e-10]
        if zero:
            bmesh.ops.delete(bm, geom=zero, context='FACES')
        wire = [e for e in bm.edges if not e.link_faces]
        if wire:
            bmesh.ops.delete(bm, geom=wire, context='EDGES')
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context='VERTS')
        me = self.to_mesh(name)
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        ob.location = Vector(loc)
        if weighted:
            wn = ob.modifiers.new("WN", 'WEIGHTED_NORMAL')
            wn.keep_sharp = True
            wn.weight = wn_weight
            wn.mode = 'FACE_AREA'
            apply_modifiers(ob)
        self.bm.free()
        if parent is not None:
            parent_keep(ob, parent)
        return ob


def move_verts(verts, m):
    for v in verts:
        v.co = m @ v.co


# ----------------------------------------------------------------------------------------------
# surface projection (decal strips on curved hulls)
# ----------------------------------------------------------------------------------------------
class Surf:
    """BVH over a bmesh (or a list of BMFaces) for projecting points onto it."""

    def __init__(self, bm=None, faces=None):
        if faces is not None:
            vmap, verts, polys = {}, [], []
            for f in faces:
                idx = []
                for v in f.verts:
                    if v not in vmap:
                        vmap[v] = len(verts)
                        verts.append(v.co.copy())
                    idx.append(vmap[v])
                polys.append(idx)
            self.bvh = BVHTree.FromPolygons(verts, polys)
        else:
            bm.verts.ensure_lookup_table()
            self.bvh = BVHTree.FromBMesh(bm)

    def cast(self, origin, direction, maxd=60.0):
        hit = self.bvh.ray_cast(Vector(origin), Vector(direction).normalized(), maxd)
        if hit[0] is None:
            return None
        return hit[0], hit[1]

    def nearest(self, p):
        r = self.bvh.find_nearest(Vector(p))
        return (r[0], r[1]) if r[0] is not None else None


def _densify(pts, step):
    dense = [Vector(pts[0])]
    for a, b in zip(pts[:-1], pts[1:]):
        a, b = Vector(a), Vector(b)
        L = (b - a).length
        n = max(1, int(math.ceil(L / step)))
        for i in range(1, n + 1):
            dense.append(a.lerp(b, i / n))
    return dense


def _ndot(f, v):
    """dot of the (freshly recomputed) face normal with v"""
    f.normal_update()
    return f.normal.dot(v)


def strip_on_surface(mb, surf, pts, width, mat, lift=0.010, direction=(0, 0, -1), start_off=4.0, step=0.12, height=0.0, rows=None):
    """Ribbon following the polyline pts projected along `direction` onto surf (rays start at pt - direction*start_off).
    width: float or f(t in 0..1). lift: offset along the surface normal. height>0 makes a low raised bar with side walls.
    rows: number of vertex rows across the width (auto by default) so wide ribbons follow curved surfaces.
    Returns the list of faces."""
    d = Vector(direction).normalized()
    dense = _densify(pts, step)
    n = len(dense)
    wf = (lambda t: width(t)) if callable(width) else (lambda t: width)
    wmax = max(wf(i / max(1, n - 1)) for i in range(n))
    nr = rows or max(2, min(7, int(math.ceil(wmax / 0.09)) + 1))
    G = []
    for i, p in enumerate(dense):
        t = (dense[min(i + 1, n - 1)] - dense[max(i - 1, 0)])
        t = t.normalized() if t.length > 0 else Vector((0, 1, 0))
        lat = t.cross(d).normalized()
        w = wf(i / max(1, n - 1))
        row = []
        for k in range(nr):
            s_ = -0.5 + k / (nr - 1)
            q = p + lat * (w * s_)
            h = surf.cast(q - d * start_off, d, start_off * 2 + 8)
            row.append(None if h is None else (h[0], h[1].normalized()))
        G.append((w, row))
    bm = mb.bm
    mi = mb.mi(mat)
    top = height + lift
    V = []
    for (w, row) in G:
        if w < 1e-4 and row[0] is not None:
            v = bm.verts.new(row[0][0] + row[0][1] * top)
            V.append([v] * nr)
        else:
            V.append([None if g is None else bm.verts.new(g[0] + g[1] * top) for g in row])
    faces = []
    for i in range(n - 1):
        for k in range(nr - 1):
            quad = [V[i][k], V[i][k + 1], V[i + 1][k + 1], V[i + 1][k]]
            if any(q is None for q in quad):
                continue
            vs = []
            for q in quad:
                if q not in vs:
                    vs.append(q)
            if len(vs) < 3:
                continue
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = mi
            f.smooth = True
            c = f.calc_center_median()
            nn = surf.nearest(c)
            if nn and _ndot(f, nn[1]) < 0:
                f.normal_flip()
            faces.append(f)
    if height > 0:
        for kk in (0, nr - 1):
            vb = [None if (G[i][1][kk] is None) else bm.verts.new(G[i][1][kk][0] - G[i][1][kk][1] * 0.006) for i in range(n)]
            for i in range(n - 1):
                quad = [V[i][kk], vb[i], vb[i + 1], V[i + 1][kk]]
                if any(q is None for q in quad):
                    continue
                vs = []
                for q in quad:
                    if q not in vs:
                        vs.append(q)
                if len(vs) < 3:
                    continue
                try:
                    f = bm.faces.new(vs)
                except ValueError:
                    continue
                f.material_index = mi
                f.smooth = False
                c = f.calc_center_median()
                ends_ = [q_ for q_ in (V[i][0], V[i][nr - 1]) if q_ is not None]
                if not ends_:
                    continue
                mid = sum((q_.co for q_ in ends_), Vector()) / len(ends_)
                if _ndot(f, c - mid) < 0:
                    f.normal_flip()
                faces.append(f)
    return faces


def plate_on_surface(mb, surf, center, size, rot_deg, lift, mat, direction=(0, 0, -1), nu=6, nv=6, start_off=4.0,
                     chamfer=True, skirt=0.012, smooth=True):
    """Raised rectangular plate (size=(su, sv) across the projection direction) conforming to surf. Axes: u is the
    world X (or Y when the direction is along X) rotated by rot_deg about the projection direction."""
    bm = mb.bm
    d = Vector(direction).normalized()
    ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    u0 = (ref - d * ref.dot(d)).normalized()
    v0 = d.cross(u0).normalized()
    r = rad(rot_deg)
    u = u0 * math.cos(r) + v0 * math.sin(r)
    v = -u0 * math.sin(r) + v0 * math.cos(r)
    C = Vector(center)
    su, sv = size
    grid = {}
    for i in range(nu + 1):
        for j in range(nv + 1):
            fu, fv = i / nu - 0.5, j / nv - 0.5
            if chamfer and i in (0, nu) and j in (0, nv):
                fu = math.copysign(0.5 - 0.5 / nu, fu)
                fv = math.copysign(0.5 - 0.5 / nv, fv)
            p = C + u * (fu * su) + v * (fv * sv)
            h = surf.cast(p - d * start_off, d, start_off * 2 + 8)
            grid[(i, j)] = None if h is None else (h[0], h[1].normalized())
    mi = mb.mi(mat)
    vt = {k: bm.verts.new(g[0] + g[1] * lift) for k, g in grid.items() if g is not None}
    faces = []
    for i in range(nu):
        for j in range(nv):
            keys = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if any(k not in vt for k in keys):
                continue
            try:
                f = bm.faces.new([vt[k] for k in keys])
            except ValueError:
                continue
            f.material_index = mi
            f.smooth = smooth
            nsum = sum((grid[k][1] for k in keys), Vector())
            if _ndot(f, nsum) < 0:
                f.normal_flip()
            faces.append(f)
    ctop = sum((vt[k].co for k in vt), Vector()) / max(1, len(vt))
    vb = {}

    def bot(k):
        if k not in vb:
            g = grid[k]
            vb[k] = bm.verts.new(g[0] - g[1] * skirt)
        return vb[k]
    border = []
    for i in range(nu):
        border.append(((i, 0), (i + 1, 0)))
        border.append(((i, nv), (i + 1, nv)))
    for j in range(nv):
        border.append(((0, j), (0, j + 1)))
        border.append(((nu, j), (nu, j + 1)))
    for (ka, kb) in border:
        if ka not in vt or kb not in vt:
            continue
        try:
            f = bm.faces.new([vt[ka], bot(ka), bot(kb), vt[kb]])
        except ValueError:
            continue
        f.material_index = mi
        f.smooth = False
        mid = (vt[ka].co + vt[kb].co) / 2
        if _ndot(f, mid - ctop) < 0:
            f.normal_flip()
        faces.append(f)
    return faces


# ----------------------------------------------------------------------------------------------
# structure helpers
# ----------------------------------------------------------------------------------------------
def rrect_pts(w, h, r, n=5, cx=0.0, cy=0.0):
    """counter-clockwise rounded rectangle outline [(x, y), ...]"""
    pts = []
    for (ox, oy, a0) in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90.0 * k / n)
            pts.append((cx + ox + r * math.cos(a), cy + oy + r * math.sin(a)))
    return pts


def ladder(mb, a, b, width=0.5, spacing=0.3, r_rail=0.025, r_rung=0.014, mat='Metal', up=(0, 0, 1), side=None):
    """ladder from point a (bottom) to b (top); rails + rungs. side: lateral axis (default horizontal, perpendicular)"""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    dn = d.normalized()
    sd = Vector(side).normalized() if side is not None else dn.cross(Vector(up)).normalized()
    for s_ in (-0.5, 0.5):
        mb.tube([a + sd * width * s_, b + sd * width * s_], r_rail, segs=6, mat=mat)
    n = int(L / spacing)
    for i in range(n):
        pnt = a + dn * (spacing * (i + 0.6))
        mb.tube([pnt - sd * width * 0.5, pnt + sd * width * 0.5], r_rung, segs=4, mat=mat, cap_a=False, cap_b=False, smooth=False)


def railing(mb, pts, h=1.05, post_r=0.03, spacing=1.0, rails=(0.55, 1.05), mat='Metal', rail_r=0.022, closed=False):
    """handrail along a polyline of floor points: posts every `spacing` + horizontal rails"""
    pts = [Vector(p) for p in pts]
    if closed:
        pts = pts + [pts[0]]
    dense = _densify(pts, spacing)
    for p in dense:
        mb.cyl(post_r, h, center=p + Vector((0, 0, h / 2)), segs=6, mat=mat, caps=False)
    for z in rails:
        mb.tube([p + Vector((0, 0, z)) for p in pts], rail_r, segs=5, mat=mat, cap_a=True, cap_b=True)


def corrugated_poly(length, pitch, depth, thick):
    """closed polygon (x, y) of a corrugated strip along x: wavy front line (y 0..depth) and a flat back line at y=-thick"""
    n = max(1, int(round(length / pitch)))
    pp = length / n
    x0 = -length / 2
    front = [(x0, 0.0)]
    for i in range(n):
        xa = x0 + i * pp
        front += [(xa + 0.25 * pp, 0.0), (xa + 0.40 * pp, depth), (xa + 0.65 * pp, depth), (xa + 0.80 * pp, 0.0), (xa + pp, 0.0)]
    pts = front + [(-x0, -thick), (x0, -thick)]
    clean = [pts[0]]
    for q in pts[1:]:
        if abs(q[0] - clean[-1][0]) > 1e-9 or abs(q[1] - clean[-1][1]) > 1e-9:
            clean.append(q)
    return clean


MAT_DEFAULTS = {}


def set_material_overrides(ov):
    """ov = {name: dict(color=.., metal=.., rough=.., emit=.., emit_strength=..)}: temporarily change global materials
    (a glTF export captures the values current at export time).  restore_materials() brings the palette back."""
    for n, kw in ov.items():
        mat(n, **kw)


def restore_materials():
    palette()


# ----------------------------------------------------------------------------------------------
# checking and previews
# ----------------------------------------------------------------------------------------------
def check(coll_name, verbose=True):
    """health report for a collection: tris, non-manifold edges, loose verts, n-gons, zero-area faces, transforms."""
    c = bpy.data.collections[coll_name]
    rep = []
    tot = 0
    for o in sorted(c.all_objects, key=lambda x: x.name):
        line = [o.name, o.type]
        if o.type == 'MESH':
            me = o.data
            bm = bmesh.new()
            bm.from_mesh(me)
            nm = sum(1 for e in bm.edges if len(e.link_faces) != 2)
            loose = sum(1 for v in bm.verts if not v.link_faces)
            ng = sum(1 for f in bm.faces if len(f.verts) > 4)
            zero = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
            bm.free()
            t = tri_count(o)
            tot += t
            line += ["tris=%d" % t, "open_edges=%d" % nm, "loose=%d" % loose, "ngon5+=%d" % ng, "zero=%d" % zero,
                     "mats=%s" % [s.material.name for s in o.material_slots]]
        rot = o.rotation_euler
        sc = o.scale
        if max(abs(rot.x), abs(rot.y), abs(rot.z)) > 1e-6 or max(abs(sc.x - 1), abs(sc.y - 1), abs(sc.z - 1)) > 1e-6:
            line.append("TRANSFORM rot=%s scale=%s" % (tuple(round(a, 3) for a in rot), tuple(round(a, 3) for a in sc)))
        line.append("loc=%s" % (tuple(round(a, 3) for a in o.matrix_world.translation),))
        if o.parent:
            line.append("parent=" + o.parent.name)
        rep.append(" | ".join(str(x) for x in line))
    if verbose:
        print("\n".join(rep))
        print("TOTAL tris:", tot)
    return tot


def _all_children(o):
    return [o] + list(o.children_recursive)


def _bounds_of(objs):
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    got = False
    for o in objs:
        if o.type != 'MESH':
            continue
        for cc in o.bound_box:
            w = o.matrix_world @ Vector(cc)
            mn = Vector((min(mn[i], w[i]) for i in range(3)))
            mx = Vector((max(mx[i], w[i]) for i in range(3)))
            got = True
    return (mn, mx) if got else (Vector((-1, -1, -1)), Vector((1, 1, 1)))


def _setup_render(res, bg, samples=16):
    sc = bpy.context.scene
    names = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in names else names[0]
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = 'Standard'
    except Exception:
        pass
    try:
        sc.eevee.taa_render_samples = samples
    except Exception:
        pass
    w = sc.world or bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    bgn = w.node_tree.nodes.get("Background")
    if bgn:
        bgn.inputs[0].default_value = (bg[0], bg[1], bg[2], 1)
        bgn.inputs[1].default_value = 1.0


def shot(names, path, cam_loc, target, lens=50, res=(960, 640), bg=(0.18, 0.2, 0.24), sun_boost=1.0, hide=None, clip=0.05):
    """render one image of the named objects/collections (+children) from cam_loc looking at target."""
    sc = bpy.context.scene
    objs = []
    for n in names:
        if n in bpy.data.objects:
            objs += _all_children(bpy.data.objects[n])
        elif n in bpy.data.collections:
            objs += list(bpy.data.collections[n].all_objects)
    keep = set(o.name for o in objs)
    hidden_before = {}
    for o in bpy.data.objects:
        if o.name.startswith("__PV"):
            continue
        hidden_before[o.name] = o.hide_render
        o.hide_render = (o.name not in keep) or (hide is not None and o.name in hide)
    _setup_render(res, bg)
    cd = bpy.data.cameras.new("__PVcam")
    cam = bpy.data.objects.new("__PVcam", cd)
    sc.collection.objects.link(cam)
    cd.lens = lens
    cd.clip_start = clip
    cd.clip_end = 500
    cam.location = Vector(cam_loc)
    look = (Vector(target) - Vector(cam_loc)).normalized()
    cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    mn, mx = _bounds_of(objs)
    ctr = (mn + mx) / 2
    rd = max((mx - mn).length / 2, 0.5)
    lights = []

    def addl(kind, loc, energy, rot, color=(1, 1, 1)):
        ld = bpy.data.lights.new("__PVl" + kind, kind)
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new("__PVl" + kind, ld)
        sc.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = rot
        lights.append(lo)
    addl('SUN', ctr + Vector((rd, -rd, rd * 1.5)), 3.2 * sun_boost, (rad(50), 0, rad(35)))
    addl('SUN', ctr + Vector((-rd, rd, rd)), 1.2 * sun_boost, (rad(60), 0, rad(215)), (0.8, 0.9, 1.0))
    addl('SUN', ctr + Vector((0, 0, -rd)), 0.6 * sun_boost, (rad(180), 0, 0), (1.0, 0.95, 0.9))
    sc.render.filepath = path
    sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    for lo in lights:
        ld = lo.data
        bpy.data.objects.remove(lo)
        bpy.data.lights.remove(ld)
    bpy.data.objects.remove(cam)
    bpy.data.cameras.remove(cd)
    for n, hv in hidden_before.items():
        if n in bpy.data.objects:
            bpy.data.objects[n].hide_render = hv
    print("shot:", path)


def views_for(names, dirs, path, res=(640, 480), lens=50, fill=1.0, bg=(0.18, 0.2, 0.24), center=None, radius=None, tile_cols=2):
    """render several named directions (dict name->dir vector) auto-framed and tile them in one PNG."""
    import numpy as np
    objs = []
    for n in names:
        if n in bpy.data.objects:
            objs += _all_children(bpy.data.objects[n])
        elif n in bpy.data.collections:
            objs += list(bpy.data.collections[n].all_objects)
    mn, mx = _bounds_of(objs)
    ctr = (mn + mx) / 2 if center is None else Vector(center)
    rd = (max((mx - mn).length / 2, 0.3)) if radius is None else radius
    tmp_files = []
    fov_v = 2 * math.atan((18.0 * min(res[1], res[0]) / max(res[0], res[1])) / lens)
    dist = rd / math.sin(fov_v / 2) * fill
    for i, (vn, dv) in enumerate(dirs):
        d = Vector(dv).normalized()
        tp = os.path.join(os.path.dirname(path), "__pv%d.png" % i)
        shot(names, tp, ctr + d * dist, ctr, lens=lens, res=res, bg=bg)
        tmp_files.append(tp)
    w, h = res
    cols = tile_cols if len(tmp_files) > 1 else 1
    rows = (len(tmp_files) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for i, p in enumerate(tmp_files):
        im = bpy.data.images.load(p)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * h
        sheet[y0:y0 + h, c * w:(c + 1) * w, :] = a
        bpy.data.images.remove(im)
    out = bpy.data.images.new("__sheet", cols * w, rows * h, alpha=True)
    out.pixels = sheet.ravel().tolist()
    out.filepath_raw = path
    out.file_format = 'PNG'
    out.save()
    bpy.data.images.remove(out)
    for p in tmp_files:
        try:
            os.remove(p)
        except Exception:
            pass
    print("sheet saved:", path)


STD_VIEWS = {
    'front': (0, -1, 0.0), 'back': (0, 1, 0.0), 'right': (1, 0, 0.0), 'left': (-1, 0, 0), 'top': (0, -0.001, 1),
    'bottom': (0, -0.001, -1),
    'iso': (0.8, -1, 0.6), 'iso2': (-0.8, 1, 0.5), 'iso3': (0.9, 0.8, 0.5), 'iso4': (-0.9, -0.8, 0.5),
    'low': (0.7, -1, -0.25), 'low2': (-0.7, 1, -0.3),
}


def sheet(names, path, views=('front', 'right', 'top', 'iso'), res=(640, 480), lens=50, fill=1.0, **kw):
    views_for(names, [(v, STD_VIEWS[v]) for v in views], path, res=res, lens=lens, fill=fill, **kw)


# run 2 (flora / rocks / crystals / resource nodes): helpers live in lib_nature.py and are loaded on top of this library
_NATURE = os.path.join(PROJECT, "blender", "lib_nature.py")
if os.path.exists(_NATURE):
    exec(compile(open(_NATURE, encoding='utf-8').read(), 'lib_nature', 'exec'))

print("lib.py loaded")
