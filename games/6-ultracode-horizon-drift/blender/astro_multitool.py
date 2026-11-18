"""astro_multitool.py - hand-held mining/scanning multitool.  Origin at the grip, barrel along +Y, Empty 'Muzzle' at the tip.
Run:  python tools/bmcp.py file blender/astro_multitool.py
"""
import sys, importlib
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
import lib_common as L; importlib.reload(L)
import astro_lib as A; importlib.reload(A)
import astro_parts as P; importlib.reload(P)
from astro_lib import *

M = A.Model("multitool")
mats = P.tool_materials(M)
bm, muzzle = P.build_multitool(1.0)
M.add("Multitool", bm, mats, (0, 0, 0), smooth_deg=40)
M.empty("Muzzle", muzzle, parent="Multitool", size=0.03)
M.report()
M.preview("multitool", views=((150, 18), (90, 10), (30, 25), (0, 10), (180, 10), (0, 85)), size=(420, 300), cols=3, dist_mult=1.25)
M.export("Multitool")
M.manifest("tool", ["any"], {"shape": "none"},
           nodes={"root": ["Multitool"], "anchors": ["Muzzle"]},
           notes="Hand-held multitool ~0.57 m. Origin at the grip (centre of the handle), barrel along Blender +Y (Godot -Z). Empty 'Muzzle' at "
                 "the barrel tip (emissive cyan lens). Materials multitool_body/dark/accent(orange)/glow(cyan emissive).",
           tintable=["accent", "glow"])
L.save_blend()
