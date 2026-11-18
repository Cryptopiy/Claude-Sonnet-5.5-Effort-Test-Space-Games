"""Quick progress snapshot for the architect: models exported, manifests, recently changed files in MAIN, sandboxes."""
import glob
import os
import time

MAIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
now = time.time()
glbs = sorted(glob.glob(os.path.join(MAIN, "assets", "models", "*.glb")))
print("models exported: %d" % len(glbs))
for m in sorted(glob.glob(os.path.join(MAIN, "assets", "models", "manifest_*.json"))):
    print("  manifest:", os.path.basename(m), "age %.0f min" % ((now - os.path.getmtime(m)) / 60))
print("recently changed in MAIN (last 30 min), excluding assets/.godot/_sandbox:")
rows = []
for dp, dns, fns in os.walk(MAIN):
    dns[:] = [d for d in dns if d not in ("_sandbox", ".godot", ".previews", ".logs", "blender", ".git")]
    for f in fns:
        p = os.path.join(dp, f)
        rel = os.path.relpath(p, MAIN).replace("\\", "/")
        if rel.startswith("assets/"):
            continue
        age = (now - os.path.getmtime(p)) / 60
        if age < 30:
            rows.append((age, rel, os.path.getsize(p)))
for age, rel, sz in sorted(rows):
    print("  %5.1f min  %7d B  %s" % (age, sz, rel))
sb = os.path.join(MAIN, "_sandbox")
if os.path.isdir(sb):
    print("sandboxes:", ", ".join(sorted(d for d in os.listdir(sb) if os.path.isdir(os.path.join(sb, d)))))
bl = sorted(glob.glob(os.path.join(MAIN, "blender", "*.py")))
print("blender scripts: %d" % len(bl))
