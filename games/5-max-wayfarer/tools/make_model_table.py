"""Builds the Markdown model table of the README from blender/PROGRESS.md (+ assets/models/*.glb).

Usage:  python tools/make_model_table.py            -> prints the table
        python tools/make_model_table.py --write    -> replaces MODEL_TABLE_PLACEHOLDER in README.md (or the previous table between
                                                       the <!-- MODELS --> markers)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

GROUPS = [
    ("Player ship and character", ["ship_explorer", "astronaut"]),
    ("Outposts, landing pad and points of interest", ["landing_pad", "outpost_hab", "outpost_tower", "outpost_container", "outpost_container_b", "outpost_tank",
                                                       "outpost_solar", "beacon_pylon", "monolith", "crate_supply", "wreck_ship", "probe_wreck"]),
    ("Verdant flora", ["tree_lush_a", "tree_lush_b", "tree_lush_c", "bush_lush", "fern", "flower_cluster", "grass_tuft"]),
    ("Arid flora and rock formations", ["cactus_a", "cactus_b", "dead_tree", "desert_shrub", "mesa_rock", "rock_arch"]),
    ("Glacial flora and ice", ["tree_pine_snow", "tree_pine_snow_b", "ice_spire", "ice_boulder", "frost_shrub", "snow_rock"]),
    ("Scorched (volcanic)", ["obsidian_spire", "lava_rock", "charred_tree", "vent_cone"]),
    ("Toxic swamp", ["mushroom_giant", "mushroom_small", "spore_pod", "tentacle_plant", "toxic_crystal"]),
    ("Irradiated", ["crystal_cluster_a", "crystal_cluster_b", "crystal_cluster_c", "rad_fungus"]),
    ("Rocks (every biome) and moon rocks", ["rock_a", "rock_b", "rock_c", "rock_d", "boulder_big", "moon_rock_a", "moon_rock_b"]),
    ("Resource nodes", ["resource_sodium", "resource_ferrite", "resource_carbon"]),
    ("Wildlife", ["creature_grazer", "creature_flyer", "creature_floater", "creature_crawler"]),
    ("Space objects", ["space_station", "asteroid_a", "asteroid_b", "asteroid_c", "satellite"]),
]


def parse_progress():
    rows = {}
    path = os.path.join(ROOT, "blender", "PROGRESS.md")
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^- ([a-z0-9_]+) \| (\d+) \| ([^|]+) \|", line)
        if m:
            size = re.sub(r"\s*\(.*?\)\s*", " ", m.group(3)).strip()
            rows[m.group(1)] = (int(m.group(2)), size)
    return rows


def build():
    rows = parse_progress()
    glbs = {f[:-4] for f in os.listdir(os.path.join(ROOT, "assets", "models")) if f.endswith(".glb")}
    out = ["<!-- MODELS -->", "| Model (`assets/models/<name>.glb`) | Triangles | Size W x H x D (m) |", "|---|---|---|"]
    total = 0
    count = 0
    listed = set()
    for title, names in GROUPS:
        present = [n for n in names if n in glbs]
        if not present:
            continue
        out.append("| **%s** | | |" % title)
        for n in present:
            tris, size = rows.get(n, (0, "-"))
            total += tris
            count += 1
            listed.add(n)
            out.append("| `%s` | %s | %s |" % (n, "{:,}".format(tris).replace(",", " ") if tris else "-", size))
    missing = sorted(glbs - listed)
    if missing:
        out.append("| **Other** | | |")
        for n in missing:
            tris, size = rows.get(n, (0, "-"))
            total += tris
            count += 1
            out.append("| `%s` | %s | %s |" % (n, tris or "-", size))
    out.append("")
    out.append("**%d models, %s triangles in total**, all modelled in Blender through the MCP socket (port 9881)." % (count, "{:,}".format(total).replace(",", " ")))
    out.append("<!-- /MODELS -->")
    return "\n".join(out)


def main():
    table = build()
    if "--write" in sys.argv:
        path = os.path.join(ROOT, "README.md")
        txt = open(path, encoding="utf-8").read()
        if "MODEL_TABLE_PLACEHOLDER" in txt:
            txt = txt.replace("MODEL_TABLE_PLACEHOLDER", table)
        else:
            txt = re.sub(r"<!-- MODELS -->.*?<!-- /MODELS -->", lambda m: table, txt, flags=re.S)
        open(path, "w", encoding="utf-8", newline="\n").write(txt)
        print("README.md updated")
    else:
        print(table)


if __name__ == "__main__":
    main()
