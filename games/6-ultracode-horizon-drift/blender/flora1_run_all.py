# Re-runs every flora1 model script inside the same Blender call (each script is self-contained).
import sys, importlib, os
BLENDER_DIR = r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender"
ORDER = ["tree_broadleaf_a", "tree_broadleaf_b", "tree_conifer_a", "bush_lush_a", "grass_tuft_a", "flower_cluster_a",
         "exotic_crystal_tree_a", "exotic_fan_plant_a", "tree_swamp_a", "reed_cluster_a", "fern_a", "palm_tree_a",
         "coral_rock_a", "exotic_spiral_horn_a", "floating_rock_a"]
for name in ORDER:
    path = os.path.join(BLENDER_DIR, "flora1_%s.py" % name)
    code = open(path, encoding="utf-8").read()
    g = {"__name__": "__main__"}
    try:
        exec(compile(code, path, "exec"), g)
    except Exception as e:
        import traceback
        print("FAILED", name, e)
        traceback.print_exc()
