"""Shared export helper. In Blender (via tools/bl.py file ...):

    exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\export_lib.py').read(), 'export_lib', 'exec'))
    export_model("tree_lush_a", category="flora", collision={"shape":"cylinder","radius":0.4,"height":5,"offset":[0,2.5,0]}, notes="...")

The model = every object (meshes AND empties) inside the Blender collection named exactly like the model.
Writes assets/models/<name>.glb and merges an entry into assets/models/manifest.json.
Axis convention: Blender +Z up, +Y forward (nose / front of the model)  ->  glTF/Godot +Y up, -Z forward.
"""
import bpy, os, json, mathutils

PROJECT = r"W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort"
MODELS = os.path.join(PROJECT, "assets", "models")
MANIFEST = os.path.join(MODELS, "manifest.json")


def _stats(objs):
    deps = bpy.context.evaluated_depsgraph_get()
    tris = 0
    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    mats = []
    for o in objs:
        if o.type != 'MESH':
            continue
        eo = o.evaluated_get(deps)
        me = eo.to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        mw = o.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            g = (w.x, w.z, -w.y)          # Blender -> Godot axes
            for i in range(3):
                if g[i] < mn[i]: mn[i] = g[i]
                if g[i] > mx[i]: mx[i] = g[i]
        eo.to_mesh_clear()
        for s in o.material_slots:
            if s.material and s.material.name not in mats:
                mats.append(s.material.name)
    if tris == 0:
        mn = mx = [0, 0, 0]
    return tris, mn, mx, mats


def export_model(name, category="prop", collision=None, notes="", extra=None, dest=MODELS):
    if name not in bpy.data.collections:
        raise RuntimeError("No collection named %r - put all objects of the model in a collection with that exact name" % name)
    coll = bpy.data.collections[name]
    objs = [o for o in coll.all_objects]
    if not objs:
        raise RuntimeError("collection %r is empty" % name)
    # make sure everything is selectable / visible
    for o in objs:
        o.hide_set(False); o.hide_viewport = False; o.hide_render = False
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = [o for o in objs if o.type == 'MESH'][0] if any(o.type == 'MESH' for o in objs) else objs[0]
    os.makedirs(dest, exist_ok=True)
    path = os.path.join(dest, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True,
        export_cameras=False, export_lights=False, export_animations=False,
        export_materials='EXPORT', export_normals=True, export_texcoords=True,
        export_vertex_color='ACTIVE', export_extras=False,
    )
    tris, mn, mx, mats = _stats(objs)
    nodes = [o.name for o in objs]
    entry = {
        "file": name + ".glb", "category": category, "tris": tris,
        "size": [round(mx[i] - mn[i], 3) for i in range(3)],      # Godot axes (x, y-up, z)
        "min": [round(v, 3) for v in mn], "max": [round(v, 3) for v in mx],
        "nodes": nodes, "materials": mats,
        "collision": collision or {"shape": "none"}, "notes": notes,
    }
    if extra:
        entry.update(extra)
    man = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, "r", encoding="utf-8") as f:
            try: man = json.load(f)
            except Exception: man = {}
    man[name] = entry
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(man, f, indent=1)
    print("EXPORTED %s: %d tris, size(godot xyz)=%s, %d nodes, %d bytes" % (name, tris, entry["size"], len(nodes), os.path.getsize(path)))
    return entry
