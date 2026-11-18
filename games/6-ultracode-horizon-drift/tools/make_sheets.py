"""Contact sheets from tools/shot_batch.ps1 output.   python tools/make_sheets.py [project_dir]"""
import os
import sys
from PIL import Image, ImageDraw

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
prev = os.path.join(root, ".previews")


def sheet(names, out, cols=2, w=640, h=360):
    ims = []
    for n in names:
        p = os.path.join(prev, "batch_%s.png" % n)
        if os.path.exists(p):
            im = Image.open(p).convert("RGB").resize((w, h))
            d = ImageDraw.Draw(im)
            d.rectangle((0, 0, 150, 16), fill=(0, 0, 0))
            d.text((3, 2), n, fill=(255, 255, 0))
            ims.append(im)
    if not ims:
        return
    rows = (len(ims) + cols - 1) // cols
    S = Image.new("RGB", (cols * w, rows * h))
    for i, im in enumerate(ims):
        S.paste(im, ((i % cols) * w, (i // cols) * h))
    S.save(os.path.join(prev, out))


sheet(["b0_volcanic", "b1_lush", "b2_barren", "b3_desert"], "sheet_biomes_a.png")
sheet(["b4_frozen", "b6_toxic", "b7_exotic", "s_landed"], "sheet_biomes_b.png")
sheet(["s_planet", "s_star", "s_gas", "s_foot"], "sheet_space.png")
sheet(["s_bh", "s_bh_near"], "sheet_bh.png")
print("sheets written to", prev)
