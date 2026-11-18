import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import bpy
import lib_common as L, ship_lib as S
importlib.reload(S)
col = bpy.data.collections["ship_player"]
S.begin(col)
root = bpy.data.objects["ship_player__Ship"]
import json
cfg = json.load(open(r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\.previews\view_cfg.json"))
S.preview_set(root, cfg.get("name","spv"), views=[tuple(v) for v in cfg["views"]], size=tuple(cfg.get("size",(900,640))), cols=cfg.get("cols",2),
              dist_mult=cfg.get("dist",1.0), ground=cfg.get("ground", False), bg=tuple(cfg.get("bg",(0.10,0.12,0.16))))
S.end(col)
