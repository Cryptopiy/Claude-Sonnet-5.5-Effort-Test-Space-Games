import bpy, bmesh
from mathutils import Matrix
print("ver", bpy.app.version_string)
bm = bmesh.new()
for fn in ("create_cube","create_cone","create_uvsphere","create_icosphere","create_circle","create_grid","bevel"):
    op = getattr(bmesh.ops, fn)
    print(fn, op.__doc__.split("\n")[0] if op.__doc__ else "")
import inspect
for fn in ("create_cone","create_uvsphere","create_icosphere","create_cube"):
    print(fn, getattr(bmesh.ops, fn).__doc__[:400].replace("\n"," | "))
bm.free()
print([e for e in dir(bpy.ops.export_scene) if 'gltf' in e])
m = bpy.data.materials.new("probe")
print(hasattr(m,"use_nodes"), hasattr(m,"surface_render_method"), hasattr(m, "blend_method"))
m.use_nodes = True
print([n.name for n in m.node_tree.nodes])
b = m.node_tree.nodes["Principled BSDF"]
print([i.name for i in b.inputs][:40])
print([e.identifier for e in bpy.types.Scene.bl_rna.properties['render'].fixed_type.properties['engine'].enum_items])
bpy.data.materials.remove(m)
