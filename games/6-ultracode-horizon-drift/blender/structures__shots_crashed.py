import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy
objs = [o for o in bpy.data.collections["crashed_ship_a"].objects if o.parent is None]
print(S.shots(objs, "crashed_ship_a", [((-9, 8, 5), (0.3, 3, 0.6)), ((7, -9, 4.5), (-0.5, -2.5, 1.0)), ((8, 7, 3.5), (0, 3, 1.0)), ((-6, -9, 3.5), (-1, -3, 1.2))], ground_z=-0.001))
