import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import structures_common as S; importlib.reload(S)
import bpy, math

def top(cid):
    return [o for o in bpy.data.collections[cid].objects if o.parent is None]

print(S.shots(top("drop_pod_a"), "z_pod", [((3.5, 6.5, 3.0), (0, 0.5, 1.8)), ((-6, 2, 3), (0, 0, 2)), ((6, -9, 4), (-1.6, -5.5, 0.5)), ((0, 9, 7), (0, 0, 1.5))], ground_z=-0.3, lens=35))
print(S.shots(top("ruin_arch_a"), "z_ruin", [((0, 14, 5), (0, 0, 5)), ((9, 7, 4), (0, 1, 3)), ((-9, -5, 7), (0, 0, 8)), ((0, 5.5, 3.5), (0, 0, 2.5))], ground_z=-0.5, lens=35))
print(S.shots(top("solar_array_a"), "z_solar", [((0, 11, 4), (-1, 0, 1.2)), ((-13, 5, 4), (-8.5, 0, 1.2)), ((6, -8, 3.5), (3, 0, 1.4)), ((-2, 5, 6), (-2, 0, 1))], ground_z=-0.25, lens=35))
print(S.shots(top("comm_dish_a"), "z_dish", [((0, 12, 6), (0, 0, 4.5)), ((-9, 7, 4), (-5.2, 0.4, 1.8)), ((8, -6, 6), (0, 0, 4)), ((9, 9, 3), (5.4, 1.4, 1.5))], ground_z=-0.5, lens=35))
print(S.shots(top("wind_turbine_a"), "z_wind", [((0, 10, 13), (0, 2, 11.5)), ((5, 5, 3), (1, 0, 1.5)), ((8, -8, 12), (0, 0, 11)), ((-7, 9, 6), (0, 0, 8))], ground_z=-0.55, lens=35))
print(S.shots(top("fuel_depot_a"), "z_fuel", [((8, 12, 5), (5.4, 3.6, 1.8)), ((-9, 9, 6), (-4.4, 2.3, 3)), ((0, -10, 4), (-2, -3, 1.5)), ((12, 2, 4), (6, -2, 1.5))], ground_z=-0.5, lens=35))
