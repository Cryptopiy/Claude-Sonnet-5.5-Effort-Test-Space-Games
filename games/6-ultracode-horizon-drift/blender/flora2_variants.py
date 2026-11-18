"""flora2 variants: re-run a base script with seed / scale / mirror overrides to get extra scatter variety.
Edit VARIANTS and run through bmcp.  Each entry: (new_id, base_script_without_prefix, overrides)."""
import sys, os, json
sys.path.insert(0, r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender")
BLENDER_DIR = r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\blender"
MANIFEST = r"W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort\assets\models\manifest_flora2.json"

VARIANTS = [
    ("tree_frost_b", "tree_frost_a", {"seed": 2024, "scale": 0.72}),
    ("tree_frost_c", "tree_frost_a", {"seed": 31, "scale": 0.55, "mirror": True}),
    ("dead_tree_b", "dead_tree_a", {"seed": 88, "scale": 0.82, "mirror": True}),
    ("cactus_c", "cactus_a", {"seed": 23, "scale": 0.7, "mirror": True}),
    ("rock_sandstone_c", "rock_sandstone_a", {"seed": 55, "scale": 0.8, "mirror": True}),
    ("ice_crystal_b", "ice_crystal_a", {"seed": 12, "scale": 0.55}),
    ("rock_moon_d", "rock_moon_b", {"seed": 8303, "scale": 0.55}),
    ("rock_moon_e", "rock_moon_a", {"seed": 8404, "scale": 0.6, "mirror": True}),
    ("rock_snow_b", "rock_snow_a", {"seed": 707, "scale": 0.62, "mirror": True}),
    ("shrub_dry_b", "shrub_dry_a", {"seed": 41, "scale": 0.8}),
    ("ice_spike_b", "ice_spike_a", {"seed": 5, "scale": 0.55}),
    ("spire_regolith_b", "spire_regolith_a", {"seed": 7101, "scale": 0.6, "mirror": True}),
    ("dune_grass_b", "dune_grass_a", {"seed": 5, "scale": 0.8}),
]


def run(new_id, base, ovr):
    ovr = dict(ovr)
    ovr["MID"] = new_id
    path = os.path.join(BLENDER_DIR, "flora2_%s.py" % base)
    src = open(path, encoding="utf-8").read()
    g = {"OVR": ovr, "__name__": "__main__", "__file__": path}
    exec(compile(src, path, "exec"), g)
    # annotate manifest entry
    data = json.load(open(MANIFEST, encoding="utf-8"))
    for m in data["models"]:
        if m["id"] == new_id:
            m["variant_of"] = base
            m["notes"] = "VARIANT of %s (seed=%s, scale=%s, mirror=%s). " % (base, ovr.get("seed"), ovr.get("scale", 1.0), ovr.get("mirror", False)) + m.get("notes", "")
    json.dump(data, open(MANIFEST, "w", encoding="utf-8"), indent=2)


ONLY = globals().get("ONLY")
for nid, base, ovr in VARIANTS:
    if ONLY and nid not in ONLY:
        continue
    print("=== variant", nid)
    run(nid, base, ovr)
