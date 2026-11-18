import sys
from PIL import Image
out = sys.argv[1]; files = sys.argv[2:]
imgs = [Image.open(f).convert("RGB") for f in files]
w, h = imgs[0].size
cols = 2 if len(imgs) <= 4 else 3
rows = (len(imgs) + cols - 1) // cols
scale = 0.5 if cols == 3 else 0.75
tw, th = int(w * scale), int(h * scale)
sheet = Image.new("RGB", (tw * cols, th * rows))
for i, im in enumerate(imgs):
    sheet.paste(im.resize((tw, th)), ((i % cols) * tw, (i // cols) * th))
sheet.save(out)
print(out, sheet.size)
