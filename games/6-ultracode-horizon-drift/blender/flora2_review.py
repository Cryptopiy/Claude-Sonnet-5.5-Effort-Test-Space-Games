"""flora2 review helper: close-up 2x2 montage of existing models (does not rebuild or export anything).
Edit IDS / VIEWS then run through bmcp."""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import flora2_lib as F
importlib.reload(F)
import bpy
L = F.L

IDS = ["cactus_a"]
VIEWS = ((20, 20), (110, 20), (200, 20), (290, 20))
DIST = 1.15

for mid in IDS:
    ob = bpy.data.objects.get(mid)
    if ob is None:
        print("missing", mid)
        continue
    paths = F.preview_only([ob], mid + "_close", views=VIEWS, size=(640, 520), dist_mult=DIST)
    print(L.montage(paths, mid + "_close_sheet", cols=2))
