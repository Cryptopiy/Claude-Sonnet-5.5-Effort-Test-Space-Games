"""Per-agent sandbox copies of the Godot project (so parallel agents never break each other's runs).

  python tools/sandbox.py create <module>     # copy the main project to _sandbox/<module>/ and import it
  python tools/sandbox.py pull   <module>     # copy everything from main that you do NOT own into your sandbox (others' latest work) + import
  python tools/sandbox.py push   <module>     # copy the files you OWN from your sandbox into the main project
  python tools/sandbox.py status <module>     # which owned files differ between sandbox and main
  python tools/sandbox.py path   <module>     # print the sandbox project path

<module> is a key of tools/modules.json (it defines the files you own). Run Godot against your sandbox with
  powershell -NoProfile -File tools/godot.ps1 -Project "<sandbox path>" -Mode run ...
Never edit files you do not own inside the MAIN project. In your sandbox you may temporarily patch core files to test, but they are never pushed:
write change requests for core files (Game/Frame/Universe/...) into your final report instead.
"""
import fnmatch
import json
import os
import shutil
import subprocess
import sys

MAIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SB_ROOT = os.path.join(MAIN, "_sandbox")
MODULES = json.load(open(os.path.join(MAIN, "tools", "modules.json"), encoding="utf-8"))
SKIP_DIRS = {"_sandbox", ".git", ".previews", ".logs", ".timing", ".godot", "blender", "__pycache__"}
SKIP_FILES = ("*.blend", "*.blend1", "*.import", "PROMPT.md", "*.tmp", ".bmcp.lock")


def rel(p, root):
    return os.path.relpath(p, root).replace("\\", "/")


def is_owned(relpath, owned):
    for pat in owned:
        if pat.endswith("/**"):
            base = pat[:-3]
            if relpath == base or relpath.startswith(base + "/"):
                return True
        elif fnmatch.fnmatch(relpath, pat):
            return True
    return False


def walk_files(root):
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for f in fns:
            if any(fnmatch.fnmatch(f, pat) for pat in SKIP_FILES):
                continue
            yield os.path.join(dp, f)


def differs(a, b):
    if not os.path.exists(b):
        return True
    sa, sb = os.stat(a), os.stat(b)
    if sa.st_size != sb.st_size:
        return True
    if int(sa.st_mtime) == int(sb.st_mtime):
        return False
    with open(a, "rb") as fa, open(b, "rb") as fb:
        return fa.read() != fb.read()


def copy_file(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


import re as _re

def _class_names(root):
    """map class_name -> relative path for every .gd under root (skipping sandboxes/backups)"""
    out = {}
    for src in walk_files(root):
        if not src.endswith(".gd"):
            continue
        try:
            for line in open(src, encoding="utf-8"):
                m = _re.match(r"\s*class_name\s+(\w+)", line)
                if m:
                    out[m.group(1)] = rel(src, root)
                    break
        except OSError:
            pass
    return out


def sandbox_path(mod):
    return os.path.join(SB_ROOT, mod)


def do_import(mod):
    ps = os.path.join(MAIN, "tools", "godot.ps1")
    subprocess.run(["powershell", "-NoProfile", "-File", ps, "-Project", sandbox_path(mod), "-Mode", "import"], check=False)


def cmd_create(mod):
    owned = MODULES[mod]["owned"]
    sb = sandbox_path(mod)
    if os.path.isdir(sb) and os.path.exists(os.path.join(sb, "project.godot")):
        # SAFE: an existing sandbox holds your work. Never overwrite owned files: behave like `pull`.
        print("sandbox exists -> pulling others' files only (your owned files are kept)")
        cmd_pull(mod)
        return
    os.makedirs(SB_ROOT, exist_ok=True)
    open(os.path.join(SB_ROOT, ".gdignore"), "a").close()
    n = 0
    for src in walk_files(MAIN):
        r = rel(src, MAIN)
        dst = os.path.join(sb, r)
        if differs(src, dst):
            copy_file(src, dst)
            n += 1
    print("created/updated sandbox %s (%d files copied)" % (sb, n))
    do_import(mod)


def cmd_pull(mod):
    owned = MODULES[mod]["owned"]
    sb = sandbox_path(mod)
    n = 0
    for src in walk_files(MAIN):
        r = rel(src, MAIN)
        if is_owned(r, owned):
            continue
        dst = os.path.join(sb, r)
        if differs(src, dst):
            copy_file(src, dst)
            print("  pulled", r)
            n += 1
    print("pulled %d files into %s" % (n, sb))
    if n:
        do_import(mod)


def cmd_push(mod):
    owned = MODULES[mod]["owned"]
    sb = sandbox_path(mod)
    n = 0
    main_classes = _class_names(MAIN)
    for src in walk_files(sb):
        r = rel(src, sb)
        if not is_owned(r, owned):
            continue
        dst = os.path.join(MAIN, r)
        if differs(src, dst):
            if src.endswith(".gd"):
                cn = None
                for line in open(src, encoding="utf-8"):
                    m = _re.match(r"\s*class_name\s+(\w+)", line)
                    if m:
                        cn = m.group(1)
                        break
                if cn and cn in main_classes and main_classes[cn] != r:
                    print("  REFUSED %s: class_name %s is already declared by %s (duplicate class_name shadows the real class!). Rename it." % (r, cn, main_classes[cn]))
                    continue
            copy_file(src, dst)
            print("  pushed", r)
            n += 1
    print("pushed %d files to main" % n)


def cmd_status(mod):
    owned = MODULES[mod]["owned"]
    sb = sandbox_path(mod)
    for src in walk_files(sb):
        r = rel(src, sb)
        if is_owned(r, owned) and differs(src, os.path.join(MAIN, r)):
            print("  differs:", r)


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[2] not in MODULES:
        print(__doc__)
        print("modules:", ", ".join(MODULES))
        sys.exit(1)
    {"create": cmd_create, "pull": cmd_pull, "push": cmd_push, "status": cmd_status, "path": lambda m: print(sandbox_path(m))}[sys.argv[1]](sys.argv[2])
