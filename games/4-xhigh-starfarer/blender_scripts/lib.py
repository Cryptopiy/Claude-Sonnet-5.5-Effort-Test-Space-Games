# Shared helper library for all Blender MCP modelling scripts (Blender 5.2, bmesh based).
# Every script does:  exec(open(r"<project>\blender_scripts\lib.py").read())
# Conventions: 1 unit = 1 m, model "forward" = +Y, up = +Z  (glTF export turns this into Godot -Z forward, +Y up).
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler, Quaternion

PROJECT = r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort"
MODELS = PROJECT + r"\assets\models"
os.makedirs(MODELS, exist_ok=True)

V = Vector


# ----------------------------------------------------------------------------- materials
def mat(name, color=(0.5, 0.5, 0.5), metallic=0.0, rough=0.5, emit=None, emit_strength=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        b.inputs["Emission Strength"].default_value = emit_strength
    else:
        b.inputs["Emission Strength"].default_value = 0.0
    b.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        m.surface_render_method = 'BLENDED'
    m.diffuse_color = (color[0], color[1], color[2], alpha)
    return m


# ----------------------------------------------------------------------------- mesh builder
def _xf(center=(0, 0, 0), rot=None, scale=(1, 1, 1)):
    m = Matrix.Translation(Vector(center))
    if rot is not None:
        if isinstance(rot, (tuple, list)):
            rot = Euler(tuple(rot), 'XYZ')
        m = m @ rot.to_matrix().to_4x4()
    m = m @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    return m


_AXIS_ROT = {
    'Z': Euler((0, 0, 0)),
    'Y': Euler((math.radians(-90), 0, 0)),   # local +Z -> +Y
    'X': Euler((0, math.radians(90), 0)),    # local +Z -> +X
}


class MB:
    """Mesh builder: accumulate primitives (with material index + smooth flag) into one bmesh."""

    def __init__(self, mats):
        self.bm = bmesh.new()
        self.mats = list(mats)

    # -- helpers
    def _tag(self, start, mi, smooth):
        self.bm.faces.ensure_lookup_table()
        for f in self.bm.faces[start:]:
            f.material_index = mi
            f.smooth = smooth

    def _n(self):
        self.bm.faces.ensure_lookup_table()
        return len(self.bm.faces)

    # -- primitives
    def box(self, size, center=(0, 0, 0), mi=0, rot=None, smooth=False, bevel=0.0):
        s = self._n()
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=_xf(center, rot, size))
        if bevel > 0:
            edges = list({e for v in r['verts'] for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=2, affect='EDGES', clamp_overlap=True)
        self._tag(s, mi, smooth)

    def cyl(self, r1, r2, h, center=(0, 0, 0), axis='Z', seg=16, mi=0, smooth=True, caps=True, rot=None, scale=(1, 1, 1)):
        s = self._n()
        base = _AXIS_ROT[axis].to_matrix().to_4x4()
        M = _xf(center, rot, scale) @ base
        bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h, matrix=M)
        self._tag(s, mi, smooth)

    def sphere(self, radii, center=(0, 0, 0), seg=16, rings=10, mi=0, smooth=True, rot=None):
        s = self._n()
        if isinstance(radii, (int, float)):
            radii = (radii, radii, radii)
        bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0, matrix=_xf(center, rot, radii))
        self._tag(s, mi, smooth)

    def ico(self, radii, center=(0, 0, 0), sub=2, mi=0, smooth=True, rot=None, noise=0.0, seed=0, flat=False):
        s = self._n()
        if isinstance(radii, (int, float)):
            radii = (radii, radii, radii)
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0, matrix=_xf(center, rot, radii))
        if noise > 0:
            rnd = random.Random(seed)
            c = Vector(center)
            for v in r['verts']:
                d = v.co - c
                v.co = c + d * (1.0 + rnd.uniform(-noise, noise))
        self._tag(s, mi, smooth and not flat)

    def cone(self, r, h, center=(0, 0, 0), axis='Z', seg=12, mi=0, smooth=True, rot=None):
        self.cyl(r, 0.0, h, center, axis, seg, mi, smooth, True, rot)

    def prism(self, pts, thickness, plane='XY', offset=0.0, mi=0, smooth=False, scale3=None):
        """Extrude a 2D polygon. plane XY: pts=(x,y), extrude along Z; YZ: pts=(y,z) along X; XZ: pts=(x,z) along Y."""
        s = self._n()
        bm = self.bm

        def p3(a, b, c):
            if plane == 'XY':
                return Vector((a, b, c))
            if plane == 'YZ':
                return Vector((c, a, b))
            return Vector((a, c, b))
        t0, t1 = offset - thickness / 2, offset + thickness / 2
        bot = [bm.verts.new(p3(a, b, t0)) for a, b in pts]
        top = [bm.verts.new(p3(a, b, t1)) for a, b in pts]
        n = len(pts)
        try:
            bm.faces.new(bot[::-1])
            bm.faces.new(top)
        except ValueError:
            pass
        for i in range(n):
            j = (i + 1) % n
            try:
                bm.faces.new([bot[i], bot[j], top[j], top[i]])
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[s:])
        self._tag(s, mi, smooth)

    def loft(self, sections, seg=16, mi=0, smooth=True, axis='Y', cap_start=True, cap_end=True, mi_cap=None):
        """sections: list of dict(p=(x,y,z), rx=, ry=, n=2.0, rot=0). Rings lie perpendicular to `axis`.
        For axis 'Y' the ring is in the XZ plane (rx along X, ry along Z); for 'Z' in XY (rx along X, ry along Y)."""
        bm = self.bm
        if mi_cap is None:
            mi_cap = mi
        s = self._n()
        rings = []
        for sec in sections:
            p = Vector(sec['p'])
            rx, ry = sec['rx'], sec['ry']
            n = sec.get('n', 2.0)
            ox, oy = sec.get('off', (0.0, 0.0))
            ring = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                c, sn = math.cos(a), math.sin(a)
                x = math.copysign(abs(c) ** (2.0 / n), c) * rx + ox
                y = math.copysign(abs(sn) ** (2.0 / n), sn) * ry + oy
                if axis == 'Y':
                    ring.append(p + Vector((x, 0, y)))
                elif axis == 'Z':
                    ring.append(p + Vector((x, y, 0)))
                else:
                    ring.append(p + Vector((0, x, y)))
            rings.append(ring)
        vr = [[bm.verts.new(co) for co in ring] for ring in rings]
        for k in range(len(vr) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                try:
                    if axis == 'Y':
                        bm.faces.new([vr[k][i], vr[k + 1][i], vr[k + 1][j], vr[k][j]])
                    else:
                        bm.faces.new([vr[k][i], vr[k][j], vr[k + 1][j], vr[k + 1][i]])
                except ValueError:
                    pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[s:])
        self._tag(s, mi, smooth)
        # flat caps with their own vertices
        for first, idx in ((cap_start, 0), (cap_end, -1)):
            if not first:
                continue
            s2 = self._n()
            cv = [bm.verts.new(co) for co in rings[idx]]
            try:
                f = bm.faces.new(cv)
            except ValueError:
                continue
            bmesh.ops.recalc_face_normals(bm, faces=[f])
            c0 = sum((v.co for v in cv), Vector()) / len(cv)
            # make sure the cap faces away from the other end
            other = Vector(sum((v for v in rings[1 if idx == 0 else -2]), Vector())) / seg
            if (f.normal.dot(c0 - other)) < 0:
                f.normal_flip()
            self._tag(s2, mi_cap, False)

    def tube(self, pts, radii, seg=8, mi=0, smooth=True, caps=True):
        """Tube along a polyline pts (list of Vector) with per-point radius (float or (rx,ry)). Parallel-transported ring frames."""
        bm = self.bm
        s = self._n()
        pts = [Vector(p) for p in pts]
        rings = []
        up = Vector((0, 0, 1))
        prev_t = None
        prev_u = None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - p).normalized()
            elif i == len(pts) - 1:
                t = (p - pts[i - 1]).normalized()
            else:
                t = (pts[i + 1] - pts[i - 1]).normalized()
            if prev_u is None:
                u = up if abs(t.dot(up)) < 0.95 else Vector((1, 0, 0))
                u = (u - t * u.dot(t)).normalized()
            else:
                u = (prev_u - t * prev_u.dot(t)).normalized()
            w = t.cross(u).normalized()
            prev_u = u
            r = radii[i] if isinstance(radii, (list, tuple)) else radii
            rx, ry = (r, r) if not isinstance(r, (list, tuple)) else r
            ring = []
            for k in range(seg):
                a = 2 * math.pi * k / seg
                ring.append(p + u * (math.cos(a) * rx) + w * (math.sin(a) * ry))
            rings.append(ring)
        vr = [[bm.verts.new(co) for co in ring] for ring in rings]
        for k in range(len(vr) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                try:
                    bm.faces.new([vr[k][i], vr[k][j], vr[k + 1][j], vr[k + 1][i]])
                except ValueError:
                    pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[s:])
        self._tag(s, mi, smooth)
        if caps:
            for idx in (0, -1):
                s2 = self._n()
                cv = [bm.verts.new(co) for co in rings[idx]]
                try:
                    f = bm.faces.new(cv)
                except ValueError:
                    continue
                bmesh.ops.recalc_face_normals(bm, faces=[f])
                self._tag(s2, mi, False)

    def mirror_x(self, from_face_index=0):
        """Duplicate all geometry from face index `from_face_index` on, mirrored across x=0."""
        bm = self.bm
        bm.faces.ensure_lookup_table()
        faces = bm.faces[from_face_index:]
        geom = list(faces)
        verts = list({v for f in faces for v in f.verts})
        edges = list({e for f in faces for e in f.edges})
        ret = bmesh.ops.duplicate(bm, geom=verts + edges + geom)
        nv = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.scale(bm, vec=Vector((-1, 1, 1)), verts=nv)
        nf = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=nf)

    def transform(self, matrix, from_face_index=0):
        bm = self.bm
        bm.faces.ensure_lookup_table()
        verts = list({v for f in bm.faces[from_face_index:] for v in f.verts})
        bmesh.ops.transform(bm, matrix=matrix, verts=verts)

    def jitter(self, amount, seed=0, from_face_index=0, axes=(1, 1, 1)):
        rnd = random.Random(seed)
        bm = self.bm
        bm.faces.ensure_lookup_table()
        verts = list({v for f in bm.faces[from_face_index:] for v in f.verts})
        for v in verts:
            v.co += Vector((rnd.uniform(-amount, amount) * axes[0], rnd.uniform(-amount, amount) * axes[1], rnd.uniform(-amount, amount) * axes[2]))

    def to_obj(self, name, loc=(0, 0, 0), parent=None, rot=None, collection=None):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        for m in self.mats:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(name, mesh)
        (collection or bpy.context.scene.collection).objects.link(obj)
        obj.location = loc
        if rot is not None:
            obj.rotation_euler = rot
        if parent is not None:
            obj.parent = parent
        return obj


# ----------------------------------------------------------------------------- scene helpers
def clear_prefix(prefix):
    for o in list(bpy.data.objects):
        if o.name.startswith(prefix):
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def empty(name, loc=(0, 0, 0), parent=None, rot=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    if rot is not None:
        e.rotation_euler = rot
    if parent is not None:
        e.parent = parent
    return e


def tree_objs(root):
    out = [root]
    for c in root.children:
        out += tree_objs(c)
    return out


def export_glb(name, objs):
    """Export given objects (parents must be included) to assets/models/<name>.glb with the asset at the origin."""
    path = os.path.join(MODELS, name + ".glb")
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format='GLB', export_apply=True,
                              export_cameras=False, export_lights=False, export_yup=True)
    return path


def shelf(objs, x, y=0.0):
    """Move top-level objects to a gallery slot (after export)."""
    for o in objs:
        if o.parent is None:
            o.location.x += x
            o.location.y += y


def preview(objs, path, cam_dir=(1, -1.2, 0.7), dist=None, size=(640, 480), focus=None, lens=50, engine='BLENDER_WORKBENCH'):
    """Render a quick workbench preview of the given objects to a png."""
    sc = bpy.context.scene
    sc.render.engine = engine
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.image_settings.file_format = 'PNG'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_specular_highlight = True
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("W")
    pts = []
    for o in objs:
        if o.type == 'MESH':
            for c in o.bound_box:
                pts.append(o.matrix_world @ Vector(c))
    if not pts:
        return
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (mn + mx) / 2 if focus is None else Vector(focus)
    rad = (mx - mn).length / 2
    cam = bpy.data.objects.get("_pvcam")
    if cam is None:
        cd = bpy.data.cameras.new("_pvcam")
        cam = bpy.data.objects.new("_pvcam", cd)
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    d = dist or rad * 2.6 * (50.0 / lens) + 1.0
    dirv = Vector(cam_dir).normalized()
    cam.location = ctr + dirv * d
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    # hide other objects from the render
    hidden = []
    for o in bpy.data.objects:
        if o not in objs and o.type == 'MESH' and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    sc.render.filepath = path
    try:
        bpy.context.preferences.view.render_display_type = 'NONE'
    except Exception:
        pass
    bpy.ops.render.render(write_still=True)
    for o in hidden:
        o.hide_render = False
    return path


# ----------------------------------------------------------------------------- extra helpers
def aim_euler(direction):
    """Euler rotation taking local +Z to `direction`."""
    d = Vector(direction).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    return q.to_euler()


def seg_cyl(b, p0, p1, r0, r1, seg=8, mi=0, smooth=True, caps=True):
    """Cylinder/cone frustum between two points (r0 at p0, r1 at p1)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    if L < 1e-5:
        return
    # create_cone puts radius1 at local -Z and radius2 at local +Z; +Z is aimed along d
    b.cyl(r0, r1, L, (p0 + p1) / 2, 'Z', seg=seg, mi=mi, smooth=smooth, caps=caps, rot=aim_euler(d))


def blade(b, base, direction, h, r, mi, seg=3):
    seg_cyl(b, base, Vector(base) + Vector(direction).normalized() * h, r, 0.0, seg=seg, mi=mi, smooth=False)


def finish(name, objs, slot, row=0, pv=None, cam=(1, -1.2, 0.6), dist=None, lens=50):
    for o in objs:
        o["asset"] = name
    export_glb(name, objs)
    if pv:
        preview(objs, os.path.join(PROJECT, "blender_scripts", "_pv_" + name + ".png"), cam_dir=cam, dist=dist, lens=lens)
    shelf(objs, slot * 22.0 - 100.0, row * 22.0 + 30.0)
    tris = sum(len(o.data.polygons) for o in objs if o.type == 'MESH')
    print("OK", name, "tris", tris)
