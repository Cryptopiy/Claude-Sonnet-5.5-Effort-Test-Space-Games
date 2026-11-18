"""Prints the node tree (names, translation, rotation, scale), meshes, materials and bounds of GLB files without starting Godot.

Usage: python tools/glb_info.py assets/models/space_station.glb [more.glb ...]
"""
import json
import struct
import sys


def read_glb(path):
    with open(path, "rb") as fh:
        data = fh.read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("not a GLB file")
    off = 12
    js = None
    bin_chunk = b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == b"JSON":
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == b"BIN\x00":
            bin_chunk = chunk
        off += 8 + clen
    return js, bin_chunk


def fmt(v, n=3):
    return "(" + ", ".join(("%." + str(n) + "f") % x for x in v) + ")"


def dump_node(js, idx, depth, out):
    n = js["nodes"][idx]
    t = n.get("translation")
    r = n.get("rotation")
    s = n.get("scale")
    extra = []
    if t:
        extra.append("t=" + fmt(t))
    if r and any(abs(x) > 1e-4 for x in r[:3]):
        extra.append("rot=" + fmt(r, 3))
    if s and any(abs(x - 1.0) > 1e-4 for x in s):
        extra.append("s=" + fmt(s))
    if "mesh" in n:
        extra.append("mesh#%d" % n["mesh"])
    out.append("%s%s %s" % ("  " * depth, n.get("name", "?"), " ".join(extra)))
    for c in n.get("children", []):
        dump_node(js, c, depth + 1, out)


def tri_count(js):
    total = 0
    per_mesh = []
    for m in js.get("meshes", []):
        tris = 0
        for p in m.get("primitives", []):
            if "indices" in p:
                tris += js["accessors"][p["indices"]]["count"] // 3
            else:
                tris += js["accessors"][p["attributes"]["POSITION"]]["count"] // 3
        per_mesh.append(tris)
    return per_mesh


def main():
    for path in sys.argv[1:]:
        js, _ = read_glb(path)
        print("=== %s" % path)
        scene = js["scenes"][js.get("scene", 0)]
        out = []
        for root in scene["nodes"]:
            dump_node(js, root, 0, out)
        print("\n".join(out))
        per = tri_count(js)
        print("meshes: %d  triangles: %d  materials: %s" % (len(per), sum(per), ", ".join(m.get("name", "?") for m in js.get("materials", []))))
        mins = [1e9] * 3
        maxs = [-1e9] * 3
        for a in js["accessors"]:
            if a.get("type") == "VEC3" and "min" in a and "max" in a and a.get("componentType") == 5126:
                for i in range(3):
                    mins[i] = min(mins[i], a["min"][i])
                    maxs[i] = max(maxs[i], a["max"][i])
        print("approx. local bounds (m, glTF axes, before node transforms): min=%s max=%s" % (fmt(mins, 2), fmt(maxs, 2)))


if __name__ == "__main__":
    main()
