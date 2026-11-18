"""Small procedural-modelling library used inside Blender (via the Blender MCP socket).

Everything is pure Python + bpy: a mesh builder that accumulates primitives
(boxes, cylinders, ellipsoids, lofts, lathes) into one mesh with per-face material
slots, plus helpers for materials, empties, export and preview renders.
Blender +Y is the model's forward axis (-> Godot -Z after glTF export), +Z is up.
"""
import bpy, math, random, os
from mathutils import Vector, Matrix, Euler

PROJECT = r"W:\YouTube\Sonnet 5.5 Effort Test\3. High Effort"
MODEL_DIR = os.path.join(PROJECT, "assets", "models")

_mats = {}


def mat(name, color=(0.5, 0.5, 0.5), metallic=0.0, roughness=0.6, emit=None, emit_strength=0.0, alpha=1.0):
    """Create (or reuse) a Principled BSDF material."""
    if name in _mats and _mats[name].name in bpy.data.materials:
        return _mats[name]
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    m.diffuse_color = (color[0], color[1], color[2], alpha)
    _mats[name] = m
    return m


def rot_matrix(rot):
    """rot: (rx, ry, rz) degrees, XYZ euler."""
    return Euler([math.radians(a) for a in rot], 'XYZ').to_matrix().to_4x4()


class MB:
    """Mesh builder. Vertices are never shared between primitives."""

    def __init__(self, name):
        self.name = name
        self.v = []
        self.f = []  # (indices, mat_idx, smooth)
        self.mats = []

    def mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _add(self, pts, faces, m, smooth):
        base = len(self.v)
        self.v.extend(pts)
        mi = self.mi(m)
        for fc in faces:
            self.f.append((tuple(base + i for i in fc), mi, smooth))

    def poly(self, pts, m, smooth=False):
        self._add(pts, [list(range(len(pts)))], m, smooth)

    # -- primitives ----------------------------------------------------
    def box(self, center=(0, 0, 0), size=(1, 1, 1), rot=(0, 0, 0), m=None, taper=(1.0, 1.0)):
        """Box. taper=(tx,ty) scales the +Y end (x,z) so it can build wedges/noses."""
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        tx, tz = taper
        pts = []
        for y in (-1, 1):
            k = (1.0, 1.0) if y < 0 else (tx, tz)
            for z in (-1, 1):
                for x in (-1, 1):
                    pts.append(Vector((x * sx * k[0], y * sy, z * sz * k[1])))
        # index = (y*4 + z*2 + x) with -1->0, +1->1
        def I(x, y, z):
            return (1 if y > 0 else 0) * 4 + (1 if z > 0 else 0) * 2 + (1 if x > 0 else 0)
        faces = [
            [I(-1, -1, -1), I(-1, -1, 1), I(1, -1, 1), I(1, -1, -1)],  # -Y
            [I(-1, 1, -1), I(1, 1, -1), I(1, 1, 1), I(-1, 1, 1)],  # +Y
            [I(-1, -1, -1), I(-1, 1, -1), I(-1, 1, 1), I(-1, -1, 1)],  # -X
            [I(1, -1, -1), I(1, -1, 1), I(1, 1, 1), I(1, 1, -1)],  # +X
            [I(-1, -1, -1), I(1, -1, -1), I(1, 1, -1), I(-1, 1, -1)],  # -Z
            [I(-1, -1, 1), I(-1, 1, 1), I(1, 1, 1), I(1, -1, 1)],  # +Z
        ]
        M = Matrix.Translation(center) @ rot_matrix(rot)
        self._add([M @ p for p in pts], faces, m, False)

    def cyl(self, center=(0, 0, 0), r1=0.5, r2=None, h=1.0, seg=12, rot=(0, 0, 0), m=None,
            caps=True, smooth=True, scale=(1, 1), cap_m=None):
        """Cylinder / cone frustum along local Z (r1 at -Z end, r2 at +Z end)."""
        if r2 is None:
            r2 = r1
        pts = []
        for ring, (r, z) in enumerate(((r1, -h / 2), (r2, h / 2))):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                pts.append(Vector((math.cos(a) * r * scale[0], math.sin(a) * r * scale[1], z)))
        faces = [[i, (i + 1) % seg, seg + (i + 1) % seg, seg + i] for i in range(seg)]
        M = Matrix.Translation(center) @ rot_matrix(rot)
        self._add([M @ p for p in pts], faces, m, smooth)
        if caps:
            cm = cap_m or m
            if r1 > 1e-5:
                ring = [M @ Vector((math.cos(2 * math.pi * i / seg) * r1 * scale[0], math.sin(2 * math.pi * i / seg) * r1 * scale[1], -h / 2)) for i in range(seg)]
                self.poly(list(reversed(ring)), cm, False)
            if r2 > 1e-5:
                ring = [M @ Vector((math.cos(2 * math.pi * i / seg) * r2 * scale[0], math.sin(2 * math.pi * i / seg) * r2 * scale[1], h / 2)) for i in range(seg)]
                self.poly(ring, cm, False)

    def sphere(self, center=(0, 0, 0), radii=(1, 1, 1), seg=14, rings=8, rot=(0, 0, 0), m=None,
               smooth=True, jitter=0.0, seed=0, top_cut=0.0, bottom_cut=0.0):
        """Ellipsoid (UV sphere). jitter randomises vertex radii (rocks)."""
        rnd = random.Random(seed)
        pts = []
        jit = {}
        pts.append(None)  # placeholder bottom pole
        rows = []
        for r in range(1, rings):
            phi = math.pi * r / rings  # 0 top -> pi bottom
            row = []
            for i in range(seg):
                th = 2 * math.pi * i / seg
                k = 1.0 + (rnd.uniform(-jitter, jitter) if jitter else 0.0)
                p = Vector((math.sin(phi) * math.cos(th) * radii[0] * k,
                            math.sin(phi) * math.sin(th) * radii[1] * k,
                            math.cos(phi) * radii[2] * k))
                row.append(len(pts))
                pts.append(p)
            rows.append(row)
        top = len(pts)
        pts.append(Vector((0, 0, radii[2])))
        pts[0] = Vector((0, 0, -radii[2]))
        faces = []
        for i in range(seg):
            j = (i + 1) % seg
            faces.append([top, rows[0][j], rows[0][i]])
            faces.append([0, rows[-1][i], rows[-1][j]])
        for r in range(len(rows) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                faces.append([rows[r][i], rows[r][j], rows[r + 1][j], rows[r + 1][i]])
        M = Matrix.Translation(center) @ rot_matrix(rot)
        self._add([M @ p for p in pts], faces, m, smooth)

    def loft(self, rings, m=None, close_start=True, close_end=True, smooth=True, center=(0, 0, 0), rot=(0, 0, 0),
             loop=True):
        """rings: list of lists of Vector (same length). Connect consecutive rings."""
        n = len(rings[0])
        pts = []
        for r in rings:
            pts.extend(r)
        faces = []
        for k in range(len(rings) - 1):
            for i in range(n):
                j = (i + 1) % n
                if not loop and j == 0:
                    continue
                a, b = k * n + i, k * n + j
                faces.append([a, a + n, b + n, b])
        M = Matrix.Translation(center) @ rot_matrix(rot)
        self._add([M @ Vector(p) for p in pts], faces, m, smooth)
        if close_start:
            self.poly([M @ Vector(p) for p in reversed(rings[0])], m, False)
        if close_end:
            self.poly([M @ Vector(p) for p in rings[-1]], m, False)

    def lathe(self, profile, seg=16, m=None, smooth=True, center=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1)):
        """profile: list of (radius, z). Revolve around Z."""
        rings = []
        for (r, z) in profile:
            rings.append([Vector((math.cos(2 * math.pi * i / seg) * r * scale[0], math.sin(2 * math.pi * i / seg) * r * scale[1], z)) for i in range(seg)])
        self.loft(rings, m=m, close_start=profile[0][0] > 1e-5, close_end=profile[-1][0] > 1e-5, smooth=smooth, center=center, rot=rot)

    # -- finish ---------------------------------------------------------
    def build(self, parent=None, location=(0, 0, 0)):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(p) for p in self.v], [], [f[0] for f in self.f])
        me.update()
        for m in self.mats:
            me.materials.append(m)
        for poly, (idx, mi, sm) in zip(me.polygons, self.f):
            poly.material_index = mi
            poly.use_smooth = sm
        me.validate()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = location
        if parent is not None:
            ob.parent = parent
        return ob


def empty(name, location=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'PLAIN_AXES'
    e.location = location
    e.rotation_euler = [math.radians(a) for a in rot]
    bpy.context.scene.collection.objects.link(e)
    if parent is not None:
        e.parent = parent
    return e


def clear_all():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def remove_tree(name):
    """Delete a previously built model (root empty + children) so scripts are re-runnable."""
    r = bpy.data.objects.get(name)
    if r is None:
        return
    for o in reversed(descendants(r)):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def descendants(ob):
    out = [ob]
    for c in ob.children:
        out.extend(descendants(c))
    return out


def export(root, filename):
    """Export root object (+descendants) as GLB into assets/models."""
    bpy.ops.object.select_all(action='DESELECT')
    objs = descendants(root)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(MODEL_DIR, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_cameras=False,
                              export_lights=False, export_extras=False)
    return path


_slot = [0]


def stash(root):
    """Move an exported model away so the saved .blend shows a tidy gallery."""
    root.location = (_slot[0] * 24.0, 40.0, 0)
    _slot[0] += 1


def preview(root, filename, dist=None, elev=25, azim=-35, res=(640, 480), focus=None):
    """Workbench render of a model for quick visual checks (saved to project/.preview)."""
    d = os.path.join(PROJECT, ".preview")
    os.makedirs(d, exist_ok=True)
    sc = bpy.context.scene
    objs = [o for o in descendants(root) if o.type == 'MESH']
    pts = []
    for o in objs:
        for c in o.bound_box:
            pts.append(o.matrix_world @ Vector(c))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (mn + mx) / 2 if focus is None else Vector(focus)
    size = (mx - mn).length
    dist = dist or size * 1.15
    cam_data = bpy.data.cameras.new("pcam")
    cam = bpy.data.objects.new("pcam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam_data.lens = 45
    a, e = math.radians(azim), math.radians(elev)
    cam.location = ctr + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    dirv = ctr - cam.location
    cam.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_cavity = False
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.world.color = (0.12, 0.13, 0.16)
    sc.render.filepath = os.path.join(d, filename)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cam_data)
    return sc.render.filepath
