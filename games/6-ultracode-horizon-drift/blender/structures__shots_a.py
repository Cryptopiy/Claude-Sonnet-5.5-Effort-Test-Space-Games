import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy, math

def top(cid):
    return [o for o in bpy.data.collections[cid].objects if o.parent is None]

print(S.shots(top("landing_pad_a"), "z_pad", [((-2.5, 3.2, 2.2), (-5.7, 5.7, 0.7)), ((0, -9.5, 5.5), (0, 0, 0)), ((9, 5, 3), (-2, -1, 0.2)), ((-9, -3, 3.5), (3, 4, 0.5))], ground_z=-0.002, lens=35))
print(S.shots(top("outpost_hab_a"), "z_hab_a", [((3.5, 12.5, 3.0), (0, 6.5, 1.8)), ((7, -6, 10), (0, -1.7, 6.5)), ((-9, 6, 3), (-2, 2, 2.0)), ((0, 11, 8), (0, 0, 2.5))], ground_z=-0.002, lens=35))
print(S.shots(top("outpost_hab_b"), "z_hab_b", [((0, 14, 5), (0, 0, 2)), ((16, 10, 4), (8, 3, 1.8)), ((-4, -9, 6), (-4, -3, 2.5)), ((-14, 8, 4), (-8, 0, 2))], ground_z=-0.002, lens=35))
print(S.shots(top("outpost_tower_a"), "z_tower", [((6, 10, 12.5), (0, 2.3, 11.6)), ((9, 6, 4), (3, 0, 1.6)), ((5, -6, 15), (0, 0, 15)), ((10, 10, 8), (0, 0, 8))], ground_z=-0.002, lens=35))
print(S.shots(top("beacon_monolith_a"), "z_mono", [((0, 8.5, 5.0), (0, 0, 3.8)), ((4.5, 5.5, 2.2), (0, 0, 1.5)), ((-5, -6, 4.5), (0, 0, 3.8)), ((3, 3, 9), (0, 0, 5.5))], ground_z=-0.8 + 0.001, lens=35))
# container with the lid open
body = bpy.data.objects["supply_container_a|Body"]
lid = bpy.data.objects["supply_container_a|Lid"]
old = lid.rotation_euler.copy()
lid.rotation_euler.x = math.radians(105)
try:
    print(S.shots(top("supply_container_a"), "z_cont_open", [((3, 3.5, 2.6), (0, 0, 0.6)), ((-3, 3.5, 2.0), (0, 0, 0.7)), ((0, 4.0, 1.2), (0, 0, 0.7)), ((3.5, -3, 3), (0, 0, 0.7))], ground_z=-0.002, lens=35))
finally:
    lid.rotation_euler = old
