"""Shared helpers for building + exporting models through the Blender MCP.  (Blender 5.2, bpy)

Use from a script you run with `python tools/bmcp.py file blender/<your_script>.py`:

    import sys, importlib
    sys.path.insert(0, r"W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort\\blender")
    import lib_common as L; importlib.reload(L)

Conventions (see docs/ARCHITECTURE.md section "Models"):
  * 1 Blender unit = 1 metre.  Blender Z is up, Blender +Y is the model's FRONT (nose / facing direction).
    The glTF exporter (export_yup=True) turns that into Godot's Y-up with the front toward -Z. Correct.
  * Object origin = sensible pivot (usually bottom-centre for props so they sit on the ground at y=0).
  * One exported .glb per model; meshes may have several material slots.
  * Empties become Node3D in Godot (use them for anchor points like 'Muzzle', 'CameraAnchor_Chase').
  * Materials are plain Principled BSDF (base colour / metallic / roughness / emission / alpha): no image textures
    (they would not survive export robustly).  Use vertex colours sparingly: Godot imports them but our default
    materials ignore them unless the material is set to use them.
"""
import bpy
import bmesh
import math
import os
import random
import mathutils
from mathutils import Vector, Matrix, Euler

PROJECT = r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort"
MODELS_DIR = PROJECT + r"\assets\models"
PREVIEW_DIR = PROJECT + r"\.previews"
BLEND_PATH = PROJECT + r"\ultracode_effort.blend"


# ----------------------------------------------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------------------------------------------
def mat(name, color=(0.5, 0.5, 0.5), metallic=0.0, roughness=0.6, emission=None, emission_strength=0.0, alpha=1.0,
        specular=0.5, transmission=0.0):
    """Create (or fetch + update) a Principled BSDF material. color/emission are RGB(A) 0..1 in *linear* space-ish values
    (Blender treats them as scene-linear; for visually predictable results pick values and look at the preview)."""
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf is None:
        nt.nodes.clear()
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    c = tuple(color) + (1.0,) if len(color) == 3 else tuple(color)
    bsdf.inputs["Base Color"].default_value = c
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
    if emission is not None and emission_strength > 0:
        ec = tuple(emission) + (1.0,) if len(emission) == 3 else tuple(emission)
        bsdf.inputs["Emission Color"].default_value = ec
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    else:
        bsdf.inputs["Emission Strength"].default_value = 0.0
    bsdf.inputs["Alpha"].default_value = alpha
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if alpha < 1.0:
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
        try:
            m.blend_method = "BLEND"
        except Exception:
            pass
    return m


# ----------------------------------------------------------------------------------------------------------------
# collections / objects
# ----------------------------------------------------------------------------------------------------------------
def fresh_collection(name):
    """Return an empty collection `name` linked to the scene (deleting any previous objects of the same collection)."""
    col = bpy.data.collections.get(name)
    if col is not None:
        for o in list(col.objects):
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and getattr(data, "users", 1) == 0:
                try:
                    if isinstance(data, bpy.types.Mesh):
                        bpy.data.meshes.remove(data)
                except Exception:
                    pass
    else:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def link(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def empty(name, col, location=(0, 0, 0), parent=None, display="PLAIN_AXES", size=0.2):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = display
    e.empty_display_size = size
    e.location = location
    col.objects.link(e)
    if parent is not None:
        e.parent = parent
    return e


def obj_from_bm(name, bm, col, materials=(), smooth=True, auto_smooth_deg=None):
    """bmesh -> object in collection. materials: list of material datablocks (indices used by bm faces material_index)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m_ in materials:
        me.materials.append(m_)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    if auto_smooth_deg is not None:
        set_smooth_by_angle(ob, auto_smooth_deg)
    return ob


def obj_from_pydata(name, verts, faces, col, materials=(), smooth=False, mat_index=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    for m_ in materials:
        me.materials.append(m_)
    if mat_index is not None:
        for p, mi in zip(me.polygons, mat_index):
            p.material_index = mi
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob


def set_smooth_by_angle(ob, deg=40.0):
    """Smooth shade with an angle threshold (works in Blender 4.1+/5.x without operators)."""
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    # sharp edges by angle
    bm = bmesh.new()
    bm.from_mesh(me)
    lim = math.radians(deg)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0.0) < lim
        else:
            e.smooth = True
    bm.to_mesh(me)
    bm.free()


# ---- primitive builders (return bmesh, caller makes the object) -----------------------------------------------------
def bm_cylinder(r1, r2, depth, segs=12, cap_bottom=True, cap_top=True, matrix=None, mat_index=0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth)
    # create_cone centres on origin; shift so base is at z=0
    bmesh.ops.translate(bm, vec=(0, 0, depth * 0.5), verts=bm.verts)
    if cap_bottom or cap_top:
        # cap by hand to avoid degenerate zero-radius quads
        pass
    bm.faces.ensure_lookup_table()
    # cap holes
    edges_open = [e for e in bm.edges if len(e.link_faces) == 1]
    if edges_open:
        res = bmesh.ops.holes_fill(bm, edges=edges_open, sides=segs)
    for f in bm.faces:
        f.material_index = mat_index
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def bm_sphere(radius=0.5, subdiv=2, matrix=None, mat_index=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for f in bm.faces:
        f.material_index = mat_index
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def bm_uvsphere(radius=0.5, u=16, v=10, matrix=None, mat_index=0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
    for f in bm.faces:
        f.material_index = mat_index
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def bm_box(size=(1, 1, 1), matrix=None, mat_index=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    for f in bm.faces:
        f.material_index = mat_index
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def bm_merge(*bms):
    """Merge several bmeshes into the first one (others freed). Material indices are preserved."""
    base = bms[0]
    for other in bms[1:]:
        me = bpy.data.meshes.new("__tmp_merge")
        other.to_mesh(me)
        other.free()
        base.from_mesh(me)
        bpy.data.meshes.remove(me)
    return base


def xf(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """4x4 matrix from location, euler rotation (radians) and scale."""
    t = Matrix.Translation(Vector(loc))
    r = Euler(rot, "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal(Vector(list(scale) + [1.0]))
    return t @ r @ s


def look_rot(direction, up=(0, 0, 1)):
    """Euler rotation that points local +Z along `direction` (good for cones/cylinders built along +Z)."""
    d = Vector(direction).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    return q.to_euler()


def bm_branch(p0, p1, r0, r1, segs=7, mat_index=0):
    """Tapered cylinder from p0 to p1 (world positions)."""
    p0 = Vector(p0)
    p1 = Vector(p1)
    d = p1 - p0
    length = d.length
    m = Matrix.Translation(p0) @ look_rot(d).to_matrix().to_4x4()
    return bm_cylinder(r0, r1, length, segs=segs, matrix=m, mat_index=mat_index)


def noise_displace(bm, amount=0.1, scale=1.0, seed=0, axis_weights=(1, 1, 1)):
    """Displace vertices with mathutils noise (organic rocks, bark, blobs)."""
    from mathutils import noise
    off = Vector((seed * 17.31, seed * 5.77, seed * 11.13))
    for v in bm.verts:
        p = v.co * scale + off
        n = noise.noise_vector(p)
        v.co.x += n.x * amount * axis_weights[0]
        v.co.y += n.y * amount * axis_weights[1]
        v.co.z += n.z * amount * axis_weights[2]
    return bm


def recalc_normals(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ----------------------------------------------------------------------------------------------------------------
# info + export + preview
# ----------------------------------------------------------------------------------------------------------------
def tri_count(objects):
    n = 0
    for o in objects:
        if o.type == "MESH":
            me = o.data
            me.calc_loop_triangles()
            n += len(me.loop_triangles)
    return n


def bounds(objects):
    """World-space AABB over mesh objects: (min Vector, max Vector)."""
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    found = False
    for o in objects:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
            found = True
    if not found:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    return mn, mx


def export_glb(objects, filename, apply_modifiers=True):
    """Export exactly `objects` (and their children) to MODELS_DIR/filename (.glb). Returns the absolute path.
    Selection is set inside this call, so it is safe even if other agents also use Blender between your calls."""
    if not filename.endswith(".glb"):
        filename += ".glb"
    path = os.path.join(MODELS_DIR, filename)
    os.makedirs(MODELS_DIR, exist_ok=True)
    # collect objects + children
    allobjs = set()

    def add(o):
        allobjs.add(o)
        for c in o.children:
            add(c)

    for o in objects:
        add(o)
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for o in allobjs:
        o.select_set(True)
    view_layer = bpy.context.view_layer
    view_layer.objects.active = list(allobjs)[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=apply_modifiers,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=True,
        export_extras=False,
        export_animations=False,
        export_image_format="AUTO",
    )
    return path


def save_blend():
    try:
        bpy.ops.wm.save_mainfile()
        return True
    except Exception as e:  # pragma: no cover
        print("save failed:", e)
        return False


def preview(objects, name, views=((35, 20), (125, 20), (215, 20), (305, 20), (0, 85)), size=(480, 400), bg=(0.10, 0.12, 0.16),
            dist_mult=1.9, sun_energy=3.5, ground=True):
    """Render a quick contact-sheet-ish set of EEVEE previews (one png per view) and return the file paths.
    Temporary camera/lights/ground are created and removed again; scene render settings are restored.
    views = (azimuth_deg, elevation_deg) around the centre of the objects' bounds."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    sc = bpy.context.scene
    # never pop up a Render window on the user's screen (they may be recording): render without touching the UI
    _vp = bpy.context.preferences.view
    _saved_disp = _vp.render_display_type
    try:
        _vp.render_display_type = "NONE"
    except Exception:
        pass
    saved = dict(engine=sc.render.engine, rx=sc.render.resolution_x, ry=sc.render.resolution_y, pct=sc.render.resolution_percentage,
                 cam=sc.camera, fp=sc.render.filepath, world=sc.world, ff=sc.render.image_settings.file_format)
    mn, mx = bounds(objects)
    centre = (mn + mx) * 0.5
    ext = (mx - mn)
    radius = max(ext.length * 0.5, 0.3)
    created = []
    world = bpy.data.worlds.new("__prev_world")
    world.use_nodes = True
    bgn = world.node_tree.nodes.get("Background")
    bgn.inputs["Color"].default_value = (bg[0], bg[1], bg[2], 1)
    bgn.inputs["Strength"].default_value = 1.0
    sc.world = world
    cam_d = bpy.data.cameras.new("__prev_cam")
    cam_d.lens = 50
    cam_d.clip_start = 0.01
    cam_d.clip_end = 5000
    cam = bpy.data.objects.new("__prev_cam", cam_d)
    sc.collection.objects.link(cam)
    created.append(cam)
    sun_d = bpy.data.lights.new("__prev_sun", "SUN")
    sun_d.energy = sun_energy
    sun = bpy.data.objects.new("__prev_sun", sun_d)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    sc.collection.objects.link(sun)
    created.append(sun)
    fill_d = bpy.data.lights.new("__prev_fill", "SUN")
    fill_d.energy = 1.2
    fill = bpy.data.objects.new("__prev_fill", fill_d)
    fill.rotation_euler = (math.radians(70), math.radians(0), math.radians(-140))
    sc.collection.objects.link(fill)
    created.append(fill)
    gobj = None
    if ground:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=max(radius * 6, 3.0))
        gme = bpy.data.meshes.new("__prev_ground")
        bm.to_mesh(gme)
        bm.free()
        gobj = bpy.data.objects.new("__prev_ground", gme)
        gm = mat("__prev_ground_mat", (0.18, 0.2, 0.22), roughness=0.95)
        gme.materials.append(gm)
        gobj.location = (centre.x, centre.y, mn.z - 0.001)
        sc.collection.objects.link(gobj)
        created.append(gobj)
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    paths = []
    try:
        for i, (az, el) in enumerate(views):
            a = math.radians(az)
            e = math.radians(el)
            d = radius * dist_mult * 2.0
            pos = centre + Vector((math.sin(a) * math.cos(e) * d, -math.cos(a) * math.cos(e) * d, math.sin(e) * d))
            cam.location = pos
            direction = centre - pos
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            p = os.path.join(PREVIEW_DIR, "%s_%d.png" % (name, i))
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
            bpy.data.meshes.remove(bpy.data.meshes["__prev_ground"])
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
        try:
            _vp.render_display_type = _saved_disp
        except Exception:
            pass
    return paths


def montage(paths, out_name, cols=3):
    """Stitch preview pngs into one image (uses bpy.data.images pixels; fine for small previews)."""
    import numpy as np
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p)
        w, h = im.size
        arr = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        imgs.append(arr)
        bpy.data.images.remove(im)
    h, w = imgs[0].shape[:2]
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    sheet[..., 3] = 1.0
    for i, arr in enumerate(imgs):
        r, c = divmod(i, cols)
        sheet[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = arr
    out = os.path.join(PREVIEW_DIR, out_name + ".png")
    im = bpy.data.images.new("__sheet", cols * w, rows * h, alpha=True)
    im.pixels = sheet.flatten().tolist()
    im.filepath_raw = out
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    return out


def report(objects, name):
    mn, mx = bounds(objects)
    sz = mx - mn
    print("[%s] tris=%d size(x,y,z)=(%.2f, %.2f, %.2f) min_z=%.2f" % (name, tri_count(objects), sz.x, sz.y, sz.z, mn.z))
