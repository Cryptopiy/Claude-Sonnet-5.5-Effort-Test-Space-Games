# Modelling run 3 – creatures and space objects

Read `blender/CONVENTIONS.md` first, then `blender/lib.py` and `blender/PROGRESS.md` (earlier runs already built ship, astronaut, outposts, flora, rocks). Reuse lib.py.
Work autonomously, export each model as soon as it looks good, update `blender/PROGRESS.md`, never open any visible window (Godot only `--headless`).

## Creatures (the game animates them procedurally by rotating the named joint nodes, so the **node names, hierarchy and pivots are binding**)
All creatures: stylised, friendly-weird, bold colour blocking with fixed colours (these are NOT tinted by the game; use `Fur_*`, `Skin_*`, `Shell_*`, `Horn` ... names plus `Glow_Main` for emissive parts which the game may tint).
Front of the creature = **+Y in Blender** (−Z in Godot). Origin = ground contact point under the body centre (flyers/floaters: the body centre). All joints: origin ON the joint, rotation 0, scale 1, rest pose = neutral standing/flying.

| name | size | description | required node names |
|---|---|---|---|
| `creature_grazer` | ~2.2 m long, 1.4 m tall | chunky four-legged herbivore: barrel body, short neck, big gentle head with curved horns or crest, tufted tail, two-tone fur (tan/cream) with coloured markings (teal or orange) | `Body` (root mesh), `Head` (pivot at the neck), `Tail` (pivot at the tail root), `Leg_FL`, `Leg_FR`, `Leg_BL`, `Leg_BR` (pivot at hip/shoulder, whole leg incl. foot as one mesh) |
| `creature_floater` | bell Ø ~3 m, tentacles ~4 m | jellyfish-like sky drifter: translucent bell (`Glow_Main` inner glow + translucent `Skin_Bell`, alpha 0.5–0.7), 8 hanging tentacles, 2–3 frilly oral arms | `Bell` (root mesh, pivot at bell centre), `Tentacle_01` … `Tentacle_08` (each pivot at its attachment point on the bell rim, hanging down ≈ 4 m; children of `Bell` or siblings) |
| `creature_flyer` | wingspan ~2.6 m | manta-ray / pterosaur-like glider: flat body with a head crest and a long tail with a fin, two broad wings | `Body` (root mesh), `Wing_L`, `Wing_R` (pivot on the body's side at wing root; wings extend outwards ±X), `Tail` (optional) |
| `creature_crawler` | ~0.9 m wide | beetle/crab: armoured carapace (`Shell_*`) with glowing spots (`Glow_Main`), two eye stalks, small pincers, **six legs** | `Body` (root), `Leg_1` … `Leg_6` (pivot at hip; 1,3,5 on the left side front-to-back, 2,4,6 right side) |

Budgets: ≤ 3 500 triangles each. Collision hint: `none` for flyer/floater, `capsule`/`box` small for grazer & crawler.

## Space objects (real-world metre sizes; the game scales them up where needed)
| name | size | description |
|---|---|---|
| `asteroid_a`, `asteroid_b`, `asteroid_c` | ~30 m | lumpy noise-displaced rocks with craters, ridges, a few chunks stuck on; three clearly different silhouettes (elongated, round-pitted, cracked/two-lobed); material `Rock_A`/`Rock_B` (neutral grey-brown, the game tints), ≤ 1 200 tris each |
| `space_station` | ring Ø ~150 m | orbital hub: **rotating habitat ring** with window strips (`Emissive_Window` warm lights) and docking port lights, 4 spokes to a central hub with antennas and a big docking arm/bay with `Emissive_Light` guide lights, solar-panel wings, hard-surface greebles, white + grey + orange accent colours. Node names: `Station` (root mesh = hub, spokes, arms, solar), `Ring` (the rotating ring, pivot exactly at the hub centre, rotation 0 — the game spins it around its Y axis), `Marker_Dock` (empty at the docking bay mouth, +Y forward = pointing out of the bay). ≤ 20 000 tris |
| `satellite` | ~8 m | derelict comms satellite: box body, big dish, bent solar panels, antenna, scorched metal; ≤ 3 000 tris |

Collision hints: `none` for all space objects (the game handles proximity itself).

## Deliverables
`assets/models/<name>.glb` for every model, manifest entries (`export_model`), model scripts in `blender/`, PROGRESS.md lines, `max_effort.blend` saved,
Godot `--headless` import + `tools/inspect_glb.gd` verification of names/pivots (especially the creature joint names and `Ring`). Final message: SHORT list + deviations.
