"""Builds assets/models/manifest_ship.json from the exported .glb files of the `ship` group (pure python, no Blender needed).
   python tools/ship_manifest.py
Sizes are the world AABB of all mesh nodes in glTF/Godot axes (x right, y up, z back) excluding nodes named EngineGlow*.
"""
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "assets", "models")


def load_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    off = 12
    js = None
    while off < len(data):
        ln, ctype = struct.unpack("<I4s", data[off:off + 8])
        if ctype == b"JSON":
            js = json.loads(data[off + 8:off + 8 + ln].decode("utf-8"))
        off += 8 + ln
    return js


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def node_matrix(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0])
    q = n.get("rotation", [0, 0, 0, 1])
    s = n.get("scale", [1, 1, 1])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    m = [[r[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]
    return m


def analyse(fn, skip_prefix=("EngineGlow",)):
    js = load_glb(os.path.join(MODELS, fn))
    nodes = js["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i

    def world(i):
        m = node_matrix(nodes[i])
        while i in parent:
            i = parent[i]
            m = mat_mul(node_matrix(nodes[i]), m)
        return m

    mn = [1e9] * 3
    mx = [-1e9] * 3
    tris = 0
    mats = set()
    per_node = {}
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        me = js["meshes"][n["mesh"]]
        t = 0
        for pr in me["primitives"]:
            acc = js["accessors"][pr["attributes"]["POSITION"]]
            if "indices" in pr:
                t += js["accessors"][pr["indices"]]["count"] // 3
            else:
                t += acc["count"] // 3
            if "material" in pr:
                mats.add(js["materials"][pr["material"]].get("name", "?"))
            if n["name"].startswith(skip_prefix):
                continue
            lo, hi = acc["min"], acc["max"]
            wm = world(i)
            for cx in (lo[0], hi[0]):
                for cy in (lo[1], hi[1]):
                    for cz in (lo[2], hi[2]):
                        p = [sum(wm[r][k] * v for k, v in enumerate((cx, cy, cz))) + wm[r][3] for r in range(3)]
                        for a in range(3):
                            mn[a] = min(mn[a], p[a])
                            mx[a] = max(mx[a], p[a])
        tris += t
        per_node[n["name"]] = t
    return dict(size=[round(mx[a] - mn[a], 2) for a in range(3)], min=[round(v, 2) for v in mn], max=[round(v, 2) for v in mx], tris=tris,
                nodes=[n["name"] for n in nodes], per_node=per_node, materials=sorted(mats))


def entry(mid, kind, size_note, collider, notes, nodes=None, tintable=None):
    a = analyse(mid + ".glb")
    e = {"id": mid, "file": mid + ".glb", "kind": kind, "biomes": ["any"], "size": a["size"], "base_y": a["min"][1], "collider": collider,
         "tris": a["tris"]}
    if tintable:
        e["tintable"] = tintable
    if nodes:
        e["nodes"] = nodes
    e["notes"] = notes
    e["aabb_min"] = a["min"]
    e["aabb_max"] = a["max"]
    e["materials"] = a["materials"]
    return e


models = []
models.append(entry(
    "ship_player", "ship", "", {"shape": "box", "size": [11.2, 2.0, 12.8], "offset_y": -0.15},
    "Wanderer hero ship, nose along Godot -Z (Blender +Y), origin = centre of mass, 1 unit = 1 m. Scene root = importer node named after the file, "
    "its only child is `Ship` (empty at the origin); every other node is a flat child of `Ship`. AABB excludes the engine glow cones "
    "(size above = hull + gear incl. deployed gear; base_y = lowest foot pad). "
    "ENGINE GLOW: EngineGlow_L/R origin = centre of the nozzle exit plane; the node is rotated (-90 deg about Blender X) so that its LOCAL -Y axis points "
    "to the rear of the ship; the cone mesh runs along local -Y (length 2.8 m, radius 0.6 m at the nozzle). Scale the node's local Y (scale.y, 0..1.2) "
    "for thrust; x/z scale = flame width. Two surfaces: surface0 translucent outer (alpha 0.45), surface1 hot inner core. "
    "GEAR (exported deployed, hinge point = node origin): Gear_Front retracts by rotating about local X by -90 deg (rotation.x = -PI/2, folds aft into the belly); "
    "Gear_L rotates about local Z by +90 deg, Gear_R about local Z by -90 deg (rotation.z = +/-PI/2; both fold inward into the engine nacelles / wing roots) "
    "[deviation from the spec text: side gear uses local Z (= Blender Y, longitudinal) instead of local Y, a vertical axis cannot lift a foot]. Fully retracted nothing "
    "sticks out of the hull. Foot contact points: Anchor_GearContact_* at y=-1.90 (deployed). "
    "RAMP: RampDoor is the left (-X) boarding hatch, hinge = bottom edge of the hatch (origin (-1.51,-0.55,-1.36)); open it by rotating about local Z by +90 deg "
    "(rotation.z = +PI/2): it swings out/down into a horizontal ramp pointing to -X. "
    "CANOPY: translucent blue glass (alpha 0.35, BLEND) over `CockpitInterior` (seat, sticks, dash with emissive screens); the glass is single sided so the cockpit camera sees through it. "
    "ANCHORS (Godot coords, relative to Ship): Anchor_ChaseCam (0,4.5,16), Anchor_Cockpit (0,1.15,-2.75) eye point looking along -Z, "
    "Anchor_Exit (-3.3,-1.9,-1.36) ground point beside the left door, Anchor_Engine_L/R (+-1.95,0.02,6.8) emitter points 0.35 m behind the nozzles, "
    "Anchor_GearContact_Front (0,-1.9,-3.51), _L (-3.3,-1.9,2.3), _R (3.3,-1.9,2.3). "
    "NavLight_L (red, port/-X wingtip), NavLight_R (green), NavLight_Tail (white): small emissive spheres, blink by toggling visibility / material emission. "
    "Hull has 6 material slots: ship_player_hull (warm white), _dark (graphite underside), _accent (orange), _metal, _glow (cyan strips/engine core), _trim (grey). "
    "Tintable: swap ship_player_accent for another colour.",
    nodes={"root": "Ship", "hull": "Hull", "canopy": "Canopy", "cockpit": "CockpitInterior", "engines": ["Engine_L", "Engine_R"],
           "engine_glow": ["EngineGlow_L", "EngineGlow_R"], "nav_lights": ["NavLight_L", "NavLight_R", "NavLight_Tail"],
           "gear": ["Gear_Front", "Gear_L", "Gear_R"], "ramp": ["RampDoor"],
           "anchors": ["Anchor_ChaseCam", "Anchor_Cockpit", "Anchor_Exit", "Anchor_GearContact_Front", "Anchor_GearContact_L",
                       "Anchor_GearContact_R", "Anchor_Engine_L", "Anchor_Engine_R"]},
    tintable=["accent"]))
models.append(entry(
    "ship_freighter", "space", "", {"shape": "box", "size": [40.0, 40.0, 142.0], "offset_y": 11.0},
    "Decorative capital cargo ship ~148 m long (size[2]; nose along Godot -Z, origin mid-ship; bridge tower at the rear). Root `Freighter`; children Hull, Containers (6 colour slots), Engines, "
    "EngineGlow_0..4 (same convention as the Wanderer: origin = nozzle exit plane, node rotated so LOCAL -Y points astern, mesh runs along local -Y, scale.y = flame length, "
    "base length 24 m x scale (centre engine r=3.3 m, the four outer ones 0.66x)), NavLight_L/R/Tail, BlinkLight and BlinkLight_2 (red beacons on the masts). "
    "AABB excludes the glow cones. Windows are emissive (ship_freighter_window).",
    nodes={"root": "Freighter", "engine_glow": ["EngineGlow_0", "EngineGlow_1", "EngineGlow_2", "EngineGlow_3", "EngineGlow_4"],
           "nav_lights": ["NavLight_L", "NavLight_R", "NavLight_Tail"], "blink": ["BlinkLight", "BlinkLight_2"]},
    tintable=["cont_"]))
models.append(entry(
    "station_orbital", "space", "", {"shape": "none"},
    "Orbital station ~217 m across. Root `Station`; children Hub (stationary: body, docking arms, antennas), Ring (habitat wheel + 6 spokes, origin = hub centre), SolarPanels, "
    "NavLight_L/R, BlinkLight, Anchor_Dock. STATION AXIS = Blender Y = Godot Z (the docking bay at the front tip faces Godot -Z). "
    "SPIN `Ring` about its LOCAL Z axis in Godot (rotate_object_local(Vector3.BACK, angle)); about 0.01-0.03 rad/s looks right. "
    "Anchor_Dock = centre of the front docking port (0,0,-63) looking out along -Z. Windows are emissive (station_orbital_window), ring windows are on the +-Z faces and outer face.",
    nodes={"root": "Station", "spin": "Ring", "static": ["Hub", "SolarPanels"], "anchors": ["Anchor_Dock"], "blink": ["BlinkLight"],
           "nav_lights": ["NavLight_L", "NavLight_R"]}))
models.append(entry(
    "satellite_a", "space", "", {"shape": "box", "size": [7.0, 3.4, 2.8], "offset_y": 0.9},   # QA: was 0.3 (box did not cover the dish; AABB centre y = 0.89)
    "Small comms satellite ~7 m span, origin at the centre of the bus. Root `Satellite`; children Body (gold-foil bus, dish pointing toward -Z/+Y, antennas), SolarPanels (spin/tilt if wanted), "
    "BlinkLight (red emissive sphere on a mast, origin at the sphere centre; toggle visibility to blink).",
    nodes={"root": "Satellite", "blink": ["BlinkLight"]}))
for ch, desc in (("a", "lumpy elongated potato, 8 craters"), ("b", "angular plane-cut fragment"), ("c", "bilobed contact-binary with a large crater")):
    mid = "asteroid_" + ch
    a = analyse(mid + ".glb")
    rad = round(0.4 * sum(a["size"]) / 3.0, 1)
    models.append(entry(mid, "space", "", {"shape": "sphere", "radius": rad, "offset_y": 0.0},
                        "Asteroid fragment (%s), flat shaded low-poly, origin at the centre (centre of mass; the AABB centre is up to ~3 m off it). Root `Asteroid_Root` > `Asteroid` "
                        "(4 materials: asteroid_rock_dark / asteroid_rock_mid / asteroid_rock_light = three-tone rock patches, all tintable via 'rock'; asteroid_ore = raised "
                        "metallic ore veins with pinched ends)." % desc,
                        nodes={"root": "Asteroid_Root", "mesh": "Asteroid"}, tintable=["rock"]))

out = {"group": "ship", "models": models}
with open(os.path.join(MODELS, "manifest_ship.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2)
for m in models:
    print(m["id"], "size", m["size"], "base_y", m["base_y"], "tris", m["tris"])
