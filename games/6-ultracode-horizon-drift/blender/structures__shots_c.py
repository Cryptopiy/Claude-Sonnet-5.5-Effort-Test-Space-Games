import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy, math
def top(cid):
    return [o for o in bpy.data.collections[cid].objects if o.parent is None]
print(S.shots(top("comm_dish_a"), "z_dish2", [((0, 12, 6), (0, 0, 4.5)), ((-8, -6, 7), (0, 0, 4.5)), ((9, 8, 6), (0, 1, 4.8)), ((0, 8, 14), (0, 0, 3))], ground_z=-0.5, lens=35))
print(S.shots(top("drop_pod_a"), "z_pod2", [((3.5, 6.5, 3.0), (0, 0.5, 1.8)), ((-6, 2, 3), (0, 0, 2))], ground_z=-0.3, lens=35, cols=2))
