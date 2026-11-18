# Blender modelling conventions (WAYFARER – a No Man's Sky style game in Godot 4.7)

Read this whole file before touching Blender. It applies to every modelling run.

## 0. Hard rules (non-negotiable)

* You may talk to **exactly one Blender: port 9881** (helper: `python tools/bl.py ...`, never edit the port).
* **First thing in a run:** `python tools/bl.py code "import bpy; print(bpy.data.filepath)"` must print
  `<local-path> 5.5 Effort Test\5. Max Effort\max_effort.blend`. If it does not: STOP, write the mismatch into
  `<local-path> 5.5 Effort Test\5. Max Effort\RESULTS.md` and report. Do not touch any other scene.
* **All geometry is built by you with bpy/bmesh scripts.** NO downloaded/imported models, NO asset packs, NO textures from the
  internet, NO Blender-MCP asset integrations (Poly Haven, Sketchfab, Hyper3D/Rodin, Hunyuan3D, ...). Procedural materials, vertex colours and
  small generated textures are fine, but flat PBR colours + good silhouettes are preferred (no image textures needed).
* Never kill processes by name. Never close / restart / File>New the Blender instance. Do not change system settings, install nothing.
* Only write inside `<local-path> 5.5 Effort Test\5. Max Effort`: scripts in `blender/`, exports in `assets/models/`, temp in `scratch/`.
* Save the .blend regularly: `bpy.ops.wm.save_mainfile()` (after each finished model).
* Do not ask questions; decide and keep going. Do not edit files outside `blender/`, `assets/models/`, `scratch/`.

## 1. Tools that already exist

| What | How |
|---|---|
| Run python inside Blender | `python tools/bl.py code "print(1+1)"` or `python tools/bl.py file blender/my_script.py` (scripts are `exec`-ed in Blender's main thread; stdout is returned) |
| Scene info / viewport screenshot | `python tools/bl.py info`, `python tools/bl.py shot scratch/x.png 800` |
| Multi-angle preview sheet (EEVEE) | inside Blender: `exec(compile(open(r'<local-path> 5.5 Effort Test\5. Max Effort\blender\preview.py').read(),'p','exec'))` then `preview(["collection_or_object_name"], r"...\scratch\x.png", views=("front","side","top","iso"), res=(480,360))` then open the PNG with the Read tool and LOOK at it. Other views: `"back"`, `"iso2"`, `"low"`. |
| Export + manifest | inside Blender: `exec(compile(open(r'...\blender\export_lib.py').read(),'e','exec'))` then `export_model("collection_name", category=..., collision={...}, notes=...)` |
| Verify the GLB inside Godot (node names, pivots, materials) | `& "W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "<local-path> 5.5 Effort Test\5. Max Effort" --import` (once after new GLBs), then `... --headless --path "<proj>" --script res://tools/inspect_glb.gd -- res://assets/models/NAME.glb` |

Do **not** run Godot windowed – other agents share the machine. Headless inspect is fine.

Write your generic helpers (materials, parenting with preserved world position, bevel+smooth shading, lofts/lathes/tubes, array helpers, noise
displacement...) into **`blender/lib.py`** and `exec` it from each model script, so later runs can reuse them. Keep one script per model:
`blender/model_<name>.py` that (re)builds that model from scratch (delete its collection first so the script is idempotent).

## 2. Conventions every model must follow

1. **Units = metres, real-world scale.** 1 Blender unit = 1 m.
2. **Axes.** Blender is Z-up, the model's *front/nose* points to **+Y**. The exporter converts to glTF/Godot (+Y up, front = −Z). So when you look at the model
   from Blender's *Back* view (Ctrl+Numpad1) you look at its face/nose; from the front view you see the tail.
3. **Origin / pivots.** Each brief says where the model origin is (usually the ground-contact point of the base, or the centre of mass for the ship).
   Moving parts (landing gear, limbs, rotors...) are **separate objects whose origin sits exactly on their hinge/joint**, with **rotation = (0,0,0) and scale = (1,1,1)**
   (bake any rotation/scale into the mesh with transform_apply, keep only the location!). That way a rotation in Godot swings the part about the hinge.
   Build such parts by creating the mesh in world position, then setting the object origin to the hinge (`bpy.ops.object.origin_set(type='ORIGIN_CURSOR')` with the cursor on the hinge, or by offsetting the mesh vertices by −hinge and setting `obj.location = hinge`).
4. **Hierarchy.** Parent child parts to their logical parent **keeping world position** (`child.parent = p; child.matrix_parent_inverse = p.matrix_world.inverted()`).
   Hierarchy is exported to glTF and arrives in Godot as nested nodes; Godot code looks nodes up **by exact name**, so use the exact names given in the brief.
   Names must be unique inside a model and must not contain dots or spaces (use underscores).
5. **Empties as markers.** Marker empties (`Marker_*`, e.g. `Marker_Eye`, `Marker_Exit`) are created with `bpy.data.objects.new(name, None)`, are part of the collection and the hierarchy, and are exported as plain nodes.
6. **One collection per model**, named exactly like the output file without extension (e.g. collection `tree_lush_a` -> `assets/models/tree_lush_a.glb`). Put *every* object of the model in that collection (meshes + empties). Keep working geometry for different models in separate collections; hide finished collections with `hide_viewport`/`hide_render` only if you need to (export_lib un-hides the collection it exports).
7. **No leftover modifiers in the export**: the exporter applies them (`export_apply=True`), but the result must be clean: no n-gons that shade badly, no inverted normals, no loose vertices, no zero-area faces, no duplicate overlapping faces. Recalculate normals outside.
8. **Shading.** Use smooth shading with an angle limit (bevelled hard-surface look: Bevel modifier 2–3 segments with *Harden normals* or `shade_smooth_by_angle(angle=radians(35))`; organic: smooth). No visibly faceted spheres/cylinders unless the low-poly style is intended.
9. **Materials = Principled BSDF** with sensible values (`Base Color`, `Metallic`, `Roughness`, optional `Emission Color`+`Emission Strength`, optional `Alpha`).
   Material naming matters because the game re-colours / animates by name:
   * `Foliage*`  – leaves/needles/grass/fronds. **Mid-light desaturated base colour (value ≈ 0.55–0.75, saturation low)** – the game multiplies it by a per-planet foliage tint.
   * `Crystal*`  – crystals / ice. Light neutral base colour, roughness 0.05–0.2; game tints them. Use `Alpha` ≈ 0.55–0.85 for ice crystals if you like (set `surface_render_method='BLENDED'`).
   * `Glow*`     – emissive plant/creature parts, white-ish `Emission Color` (game tints it); strength 2–6.
   * `Emissive*` – emissive machine lights/screens/engines with their *own fixed colour* (`Emissive_Engine`, `Emissive_Light`, `Emissive_Screen`, `Emissive_Window`).
   * `Glass*`    – transparent glass (`Alpha` 0.2–0.35, Roughness ≈ 0.05, `surface_render_method='BLENDED'`).
   * everything else: free names (`Hull_Paint`, `Hull_Accent`, `Hull_Dark`, `Bark`, `Rock`, `Metal`, `Rubber`, ...).
   Re-use materials across a model (don't create 30 near-identical ones). Rock/organic materials should be rough (0.7–0.95); painted metal 0.35–0.55.
   A dark **grey-brown or neutral** base colour is better than pure black/white (pure black 0.0 and pure white 1.0 look wrong in a PBR renderer).
10. **Budgets.** Hero assets (ship, astronaut) up to ~30 000 triangles. Structures ≤ 8 000. Trees ≤ 2 500. Rocks/small plants ≤ 600. Grass tufts ≤ 60 (they are instanced by the thousand).
    Creatures ≤ 4 000. Be generous with silhouette interest, stingy with invisible detail.
11. **Look.** Stylised, chunky, readable, saturated colour-blocking, strong silhouettes – the No Man's Sky / Astroneer feel. Avoid plain boxes: bevel everything, add panel lines
    (thin dark inset strips), vents, bolts, lights, asymmetry and small details that catch the light. Organic things get irregular proportions and variation (several
    random-seeded variants of the same family are better than one copy).
12. **No animations needed** (the game animates by rotating the named pivot nodes).

## 3. Collision hints and manifest

`export_model(name, category, collision, notes)` writes `assets/models/<name>.glb` and merges an entry into `assets/models/manifest.json`
(triangles, size in Godot axes, node + material names, collision hint). The `collision` hint is in **Godot axes (Y up, front = −Z)** and in metres:

* `{"shape":"cylinder","radius":0.4,"height":5.0,"offset":[0,2.5,0]}`  (offset = centre of the shape relative to the model origin)
* `{"shape":"box","size":[x,y,z],"offset":[0,y/2,0]}`
* `{"shape":"sphere","radius":1.2,"offset":[0,1.2,0]}`
* `{"shape":"capsule","radius":0.4,"height":1.8,"offset":[0,0.9,0]}`
* `{"shape":"none"}` for things you walk through (grass, small flowers).
Give a collision hint that matches what a player would bump into (a tree = its trunk only, a rock = a slightly shrunk sphere/box, a hab = box).

Also write `notes` that mention anything the programmer must know (e.g. "dome door faces +Z in Godot", "tint materials: Foliage_A, Foliage_B").

## 4. Process (every model)

1. Build in a fresh collection with a re-runnable script (`blender/model_<name>.py`).
2. `preview(...)` → **look at the PNG** → fix proportions/materials → repeat until it looks good. (At least 2–3 look/fix cycles for hero assets.)
3. `export_model(...)`, then `bpy.ops.wm.save_mainfile()`.
4. Append a line to `blender/PROGRESS.md`: `- name | tris | size | status/notes`.
5. After the last model: run Godot `--import` and `inspect_glb.gd` on each new GLB to confirm names/pivots/materials arrived as expected; fix and re-export if not.
