# Modelling run 2 – flora, rocks and resource nodes for the 7 biomes

Read `blender/CONVENTIONS.md` first (binding rules, conventions, export procedure), then look at `blender/lib.py` (helpers written in run 1) and one or two
finished `blender/model_*.py` scripts for style. **Reuse lib.py** and extend it with the helpers you need (blob/rock generator with noise displacement,
tube/branch along a curve, leaf-cluster, bent blade strip, crystal prism cluster, cone stack, ...).
Work autonomously, export each model as soon as it looks good, and continue **in the order below** (most important first) until all are done.
Update `blender/PROGRESS.md` after every model. **Never open any visible window** (Godot only with `--headless`; previews only through `blender/preview.py` + the Read tool).

## Global rules for this run
* Style: chunky, stylised, readable silhouette, No Man's Sky / low-poly-with-bevel feel. Smooth shading with angle limit. Each model looks different from its siblings.
* Origin = ground-contact point at the bottom centre, +Z up in Blender, nothing below the origin plane except a few cm of roots so it sits in the ground.
* **Tint contract (important):** the game recolours materials *by name prefix* per planet. Create these materials ONCE in `lib.py` with identical settings for all models:
  `Foliage_A` (light desaturated green-grey, value ≈ 0.62), `Foliage_B` (slightly darker variant ≈ 0.5), `Foliage_Flower` (near white, value 0.85) – tinted by the game;
  `Crystal_Main` (near-white, rough 0.1, Alpha 0.7 where translucent), `Glow_Main` (white emission strength 3, base dark) – tinted by the game;
  `Rock_A`, `Rock_B` (neutral warm grey-brown, rough 0.9; value 0.4–0.5) – tinted by the game; `Bark` (neutral brown). Fixed colours (not tinted): `Obsidian` (near-black glossy),
  `Glow_Lava` (orange emission), `Snow` (white, rough 0.6), `Res_*` (see resources), `Metal`, etc. Never bake the final planet colour into the tinted materials.
* Triangle budgets from CONVENTIONS.md (trees ≤ 2 500, rocks/small plants ≤ 600, grass tuft ≤ 60). Collision hints (Godot axes, metres) as in CONVENTIONS.md.
* Scale: as given in the "size" column (height in metres). The game scales instances 0.6×–1.8× randomly, so keep proportions natural.

## Models (file name = collection name)

### A. Lush world ("Verdant") – broadleaf forests, meadows
| name | size | description | collision |
|---|---|---|---|
| `tree_lush_a` | ~9 m tall | broadleaf tree: gnarly tapering trunk with flared roots, 3–4 big branches, crown of 5–7 lumpy leaf blobs (`Foliage_A` + `Foliage_B`), trunk `Bark` | cylinder r 0.5, h 5 |
| `tree_lush_b` | ~14 m | tall slender tree, slightly leaning trunk, **3 layered umbrella-like canopy tiers** (`Foliage_A/B`) | cylinder r 0.45, h 7 |
| `tree_lush_c` | ~8 m | alien tree: thick short trunk, one big flat parasol canopy with drooping edges and hanging vines/pods; `Foliage_Flower` blossoms on the canopy | cylinder r 0.7, h 4 |
| `bush_lush` | ~1.4 m | rounded bush of 6–8 leaf blobs, a few twigs | none |
| `fern` | ~1.1 m | 9 arching fronds (bent strips, 4 segments each) from a small base | none |
| `flower_cluster` | ~0.6 m | 5 stems with big colourful heads (`Foliage_Flower`) + few leaves (`Foliage_A`) | none |
| `grass_tuft` | ~0.7 m | 9–11 bent blades, **≤ 60 triangles**, `Foliage_A` | none |

### B. Generic rocks (used on every planet, tinted by `Rock_A/Rock_B`)
`rock_a` rounded boulder ~2 m (sphere 1.1 collision) · `rock_b` angular slab ~2.5 m (box) · `rock_c` cluster of three stones ~3 m (sphere 1.5) ·
`rock_d` tall pointed rock/spire ~3.5 m (cylinder r 0.9 h 3) · `boulder_big` ~7 m boulder with ledges and a flat top (box) – all ≤ 600 tris (boulder_big ≤ 900),
noise-displaced low-poly look with a few flat facets and chipped edges.

### C. Resource nodes (fixed colours, readable from afar, each ~1–1.4 m, collision none or small sphere)
* `resource_sodium` – cluster of 5–7 amber/yellow glowing crystals (`Res_Sodium`: orange-yellow emission strength 2.5)
* `resource_ferrite` – rocky lump with embedded metallic orange-brown ore veins and shiny flecks (`Res_Ferrite`, metallic 0.9)
* `resource_carbon` – squat plant with dark purple bulbs and a faintly glowing green tip (`Res_Carbon` + small emission)

### D. Desert ("Arid")
`cactus_a` saguaro ~4.5 m with 2 upturned arms (ribbed, `Foliage_A`, cylinder r 0.45 h 4) · `cactus_b` cluster of barrel/prickly-pear pads ~1.4 m (`Foliage_A`, flowers `Foliage_Flower`) ·
`dead_tree` twisted bare tree ~5 m (`Bark`, cylinder r 0.4 h 4) · `desert_shrub` ~0.8 m spiky dry shrub (`Foliage_B`) · `mesa_rock` banded tiered rock tower ~9 m (`Rock_A/B` alternating layers, box 5×8×5) ·
`rock_arch` natural stone arch ~10 m (optional, collision two boxes → just `box`).

### E. Frozen ("Glacial")
`tree_pine_snow` snow-laden conifer ~10 m (4–5 drooping tiers, `Foliage_A` with `Snow` caps, cylinder r 0.5 h 5) · `tree_pine_snow_b` smaller conifer ~6 m ·
`ice_spire` cluster of translucent ice crystal spires ~5 m (`Crystal_Main`, alpha 0.7, sphere/cylinder r 1.2) · `ice_boulder` ~2 m faceted translucent ice rock (`Crystal_Main`) ·
`frost_shrub` ~1 m frosted bush (`Foliage_B` + `Snow`) · `snow_rock` rock ~2 m with a snow cap (`Rock_A` + `Snow`).

### F. Volcanic ("Scorched")
`obsidian_spire` cluster of glassy black shards ~6 m (`Obsidian`, glossy, cylinder r 1.2 h 5) · `lava_rock` dark rock ~2 m with glowing orange cracks (`Rock_B` + `Glow_Lava`, sphere r 1.1) ·
`charred_tree` burnt trunk with broken branches ~5 m (very dark `Bark`, ember `Glow_Lava` spots, cylinder r 0.4 h 4) · `vent_cone` small volcanic cone ~3 m with a glowing crater (`Rock_B` + `Glow_Lava`, cylinder r 1.8 h 2.5).

### G. Toxic swamp
`mushroom_giant` ~12 m mushroom tree: thick stalk, huge cap with spots, **glowing gills under the cap** (`Glow_Main`), cap `Foliage_B`, stalk `Bark`-ish pale (cylinder r 0.7 h 6) ·
`mushroom_small` cluster of 4–5 mushrooms ~1.2 m (`Glow_Main` caps) · `spore_pod` bulb plant ~2 m: curved stem, big pod with glowing tip (`Foliage_A` + `Glow_Main`) ·
`tentacle_plant` ~3 m: 5–6 thick curved tentacles from a fleshy base (`Foliage_B`, tips `Glow_Main`) · `toxic_crystal` ~2 m crystals with inner glow (`Crystal_Main` + `Glow_Main`, sphere r 1).

### H. Dead moon / airless
`moon_rock_a` sharp angular regolith rock ~1.6 m · `moon_rock_b` flat shard-like rock ~2.4 m (both `Rock_A`, no smooth shading, crisp facets, sphere r 1) ·
`probe_wreck` old crashed probe ~3 m: dish, boxy body, one bent solar panel, antenna, scorched metal (`Metal`, `Hull_Dark`, a tiny `Emissive_Light`), box collision.

### I. Irradiated
`crystal_cluster_a` ~3 m, `crystal_cluster_b` ~2 m (wide, many small), `crystal_cluster_c` ~4.5 m (tall): glowing crystal prisms at varied angles (`Crystal_Main` outside + `Glow_Main` core, sphere/cylinder collision) ·
`rad_fungus` ~1 m glowing shelf fungus on a short stump (`Glow_Main` shelves, no collision).

## Deliverables
`assets/models/<name>.glb` for every model + manifest entries (via `export_model`), `blender/model_<name>.py` (or a few scripts that build several models), PROGRESS.md lines, `max_effort.blend` saved,
Godot `--headless` import + `inspect_glb.gd` verification of a sample of ~8 models (names, materials with the right prefixes). Final message: SHORT list (name, tris) + deviations.
