"""Blender-side preview helper. Exec this file inside Blender (tools/bl.py file ...), then call:

    preview(["ObjectOrCollectionName", ...], r"W:\...\scratch\prev.png", views=("front","side","top","iso"), res=(480,360))

Renders the named objects (and their children) with an isolated studio lighting rig into a
single contact-sheet PNG. Everything not listed is hidden from render during the call.
Uses EEVEE. Camera is auto-framed on the bounding box of the listed objects.
"""
import bpy, math, mathutils, os

_RIG = "__PREVIEW_RIG__"

def _all_children(o):
    out = [o]
    for c in o.children_recursive:
        out.append(c)
    return out

def _collect(names):
    objs = []
    for n in names:
        if n in bpy.data.objects:
            objs += _all_children(bpy.data.objects[n])
        elif n in bpy.data.collections:
            objs += list(bpy.data.collections[n].all_objects)
    seen, uniq = set(), []
    for o in objs:
        if o.name not in seen:
            seen.add(o.name); uniq.append(o)
    return uniq

def _bounds(objs):
    mn = mathutils.Vector((1e9,)*3); mx = mathutils.Vector((-1e9,)*3)
    any_ = False
    for o in objs:
        if o.type not in {'MESH','CURVE','SURFACE','META','FONT'}:
            continue
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector((min(mn[i], w[i]) for i in range(3)))
            mx = mathutils.Vector((max(mx[i], w[i]) for i in range(3)))
            any_ = True
    if not any_:
        return mathutils.Vector((0,0,0)), 1.0
    return (mn+mx)/2, max((mx-mn).length/2, 0.01)

def _engine_name():
    items = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    for cand in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT', 'BLENDER_WORKBENCH'):
        if cand in items:
            return cand
    return items[0]

def preview(names, path, views=("front","side","top","iso"), res=(480,360), bg=(0.18,0.2,0.24)):
    scene = bpy.context.scene
    objs = _collect(names)
    if not objs:
        print("preview: nothing found for", names); return
    keep = set(o.name for o in objs)
    hidden_before = {}
    for o in bpy.data.objects:
        if o.name not in keep:
            hidden_before[o.name] = o.hide_render
            o.hide_render = True
    ctr, rad = _bounds(objs)
    # rig
    cam_data = bpy.data.cameras.new(_RIG+"cam"); cam = bpy.data.objects.new(_RIG+"cam", cam_data)
    scene.collection.objects.link(cam)
    cam_data.lens = 50
    lights = []
    def add_light(kind, loc, energy, rot=None, color=(1,1,1)):
        ld = bpy.data.lights.new(_RIG+kind, kind); ld.energy = energy; ld.color = color
        lo = bpy.data.objects.new(_RIG+kind, ld); scene.collection.objects.link(lo)
        lo.location = loc
        if rot: lo.rotation_euler = rot
        lights.append(lo); return lo
    d = rad*3.2
    add_light('SUN', ctr+mathutils.Vector((d,-d,d*1.5)), 3.2, rot=(math.radians(50),0,math.radians(35)))
    add_light('SUN', ctr+mathutils.Vector((-d,d,d)), 1.2, rot=(math.radians(60),0,math.radians(215)), color=(0.8,0.9,1.0))
    world = scene.world or bpy.data.worlds.new("W"); scene.world = world
    world.use_nodes = True
    bgn = world.node_tree.nodes.get("Background")
    if bgn:
        bgn.inputs[0].default_value = (bg[0], bg[1], bg[2], 1); bgn.inputs[1].default_value = 1.0
    scene.render.engine = _engine_name()
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = 'Standard'
    except Exception:
        pass
    scene.camera = cam
    dirs = {
        "front": (0,-1,0.0), "back": (0,1,0.0), "side": (1,0,0.0), "top": (0,-0.001,1),
        "iso": (0.8,-1,0.6), "iso2": (-0.8,1,0.5), "low": (0.7,-1,-0.25),
    }
    images = []
    for v in views:
        dv = mathutils.Vector(dirs[v]).normalized()
        dist = rad / math.tan(cam_data.angle/2) * 1.12 + rad*0.3
        cam.location = ctr + dv*dist
        look = (ctr - cam.location).normalized()
        cam.rotation_euler = look.to_track_quat('-Z','Y').to_euler()
        tmp = os.path.join(os.path.dirname(path), "__pv_%s.png" % v)
        scene.render.filepath = tmp
        scene.render.image_settings.file_format = 'PNG'
        bpy.ops.render.render(write_still=True)
        images.append(tmp)
    # tile with numpy via blender images
    try:
        import numpy as np
        w, h = res
        cols = 2 if len(images) > 1 else 1
        rows = (len(images)+cols-1)//cols
        sheet = np.zeros((rows*h, cols*w, 4), dtype=np.float32)
        for i, p in enumerate(images):
            im = bpy.data.images.load(p)
            a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
            r, c = divmod(i, cols)
            y0 = (rows-1-r)*h
            sheet[y0:y0+h, c*w:(c+1)*w, :] = a
            bpy.data.images.remove(im)
        out = bpy.data.images.new("__sheet", cols*w, rows*h, alpha=True)
        out.pixels = sheet.ravel().tolist()
        out.filepath_raw = path; out.file_format = 'PNG'; out.save()
        bpy.data.images.remove(out)
        for p in images:
            try: os.remove(p)
            except Exception: pass
    except Exception as e:
        print("tile failed:", e, images)
    # cleanup
    for lo in lights:
        ld = lo.data; bpy.data.objects.remove(lo); bpy.data.lights.remove(ld)
    bpy.data.objects.remove(cam); bpy.data.cameras.remove(cam_data)
    for n, hv in hidden_before.items():
        if n in bpy.data.objects:
            bpy.data.objects[n].hide_render = hv
    print("preview saved:", path)
