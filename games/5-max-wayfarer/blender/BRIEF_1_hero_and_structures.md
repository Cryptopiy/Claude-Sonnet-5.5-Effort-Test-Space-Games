# Modelling run 1 – hero assets (ship, astronaut) and structures

Read `blender/CONVENTIONS.md` first (rules, tools, conventions, export). Then build the models below **in this order**, exporting each one as soon as it is good.
Quality matters most for the first two (they are on screen all the time). Work autonomously, do not ask questions, do not stop until every model is exported or a model is truly impossible.

Create `blender/lib.py` first (materials factory, parenting-keeping-world-position, bevel/smooth helper, loft through cross-sections, lathe, tube, mirror helper, etc.) – reused by later runs.

---

## 1. `ship_explorer` – the player's spaceship (HERO ASSET)

A sleek, chunky, retro-futuristic **explorer shuttle** (No Man's Sky "Explorer/Shuttle" feel; think a lifting-body fuselage with swept wings and big engines).
* Size: length ≈ **14 m** (nose at Blender y ≈ +7, tail ≈ −7), wingspan ≈ **13 m**, fuselage height ≈ 2.8 m, canopy top ≈ 3.4 m above the belly, with the landing gear extended the belly is ≈ 1.6 m above the ground. **Origin of the hull = the centre of the ship** (roughly the centre of mass, at the middle of the fuselage height).
* Silhouette: rounded blunt-but-elegant nose, **bubble canopy** on the front top, broad wings swept back with upturned winglets, **two large engine pods** at the rear (integrated in the wing roots) with big nozzles, a tail fin or twin fins, belly intakes, dorsal spine with antennas/vents. Asymmetric small details are welcome (greebles, panel lines, hatches, a small radar dish).
* Colour blocking: off-white painted hull (`Hull_Paint`, rough ≈ 0.45, metal ≈ 0.25), **orange accent** stripes/wingtips (`Hull_Accent`), dark gunmetal belly + engine housings (`Hull_Dark`, metal ≈ 0.8, rough ≈ 0.45), raw `Metal` details, `Rubber` tyres on the gear, glowing `Emissive_Engine` (cyan-blue-white, strength ≈ 6–10) inside the nozzles, `Emissive_Light` accents (light strips on wings, small cyan/amber), red/green wingtip nav lights, `Glass` canopy (alpha ≈ 0.25, bluish).
* **Cockpit interior visible through the canopy** (must also look right from the pilot's eye): pilot seat, dashboard/console with `Emissive_Screen` panels (cyan/amber), canopy frame struts. Put the interior in its own node so the game can hide it.
* **Exact node names** (hierarchy: everything is a descendant of `Hull`; `Hull` is the only top-level mesh):
  * `Hull` (root mesh; fuselage + fixed wings/fins/details)
  * `Cockpit_Glass`, `Cockpit_Interior`
  * `Engine_L`, `Engine_R` (the engine pods, may be separate meshes), each with a child `Engine_Glow_L` / `Engine_Glow_R` = the emissive nozzle-exit disc/cone (material `Emissive_Engine`)
  * `Gear_Front`, `Gear_RearL`, `Gear_RearR` = landing legs **with feet pads**, **origin exactly at the hinge** where the leg attaches to the hull, rotation 0, leg hanging straight down in the rest pose (= gear extended). Add a strut/piston and a wheel or pad. (L = −X side when looking at the ship from behind with the nose away… i.e. `_L` is the ship's left = Blender −X when the nose points to +Y.)
  * `Light_Nav_L` (red), `Light_Nav_R` (green) small emissive meshes at the wingtips, `Light_Beacon` (small emissive on the fin)
  * Marker empties: `Marker_Eye` (pilot's eye position in the cockpit, ~0.65 m above the seat), `Marker_EngineL`, `Marker_EngineR` (centre of the nozzle exit plane), `Marker_Exit` (point on the ground-contact plane ≈ 3 m to the ship's left of the hull, where the astronaut appears when leaving the ship), `Marker_FootFront`, `Marker_FootRearL`, `Marker_FootRearR` (bottom-centre of each foot pad = ground-contact points; all at the same height), `Marker_Headlight_L`, `Marker_Headlight_R` (front, at the nose), `Marker_Hatch` (the side hatch the astronaut uses, on the left side).
* ≤ 30 000 triangles. Collision hint: `box` ≈ fuselage size.
* Note in the manifest `notes`: which direction each gear leg should rotate to retract (you can test by rotating in Blender: legs fold up/back into the hull).

## 2. `astronaut` – the player character (HERO ASSET)

Chunky stylised exosuit explorer (No Man's Sky "Traveller" feel): rounded helmet with a big dark-gold/amber reflective visor, white/light-grey padded suit with **orange** accents, shoulder pads, chest panel with a small `Emissive_Light` light, belt with pouches, rugged boots and gloves, a **jetpack backpack** with two vertical thruster nozzles and a glowing core. Slightly heroic proportions (large head ≈ 1/6.5 of the height, broad shoulders). **Height 1.8 m**, standing in a relaxed **A-pose** (arms hanging slightly away from the body, palms inward, knees straight), facing **+Y**.
* **Scene origin (0,0,0) = on the ground between the feet.** (Feet soles at height 0.)
* All joints are separate meshes with their **origin on the joint**, rotation 0, scale 1, nested exactly like this (names exact):
  ```
  Pelvis                      origin at hip centre (≈ 0.95 m above the ground)
   ├─ Torso                   origin at the waist / base of the spine
   │   ├─ Head                origin at the neck (helmet; the visor is the child below)
   │   │    └─ Visor          the visor glass mesh, material `Visor` (metal 0.9, rough 0.08, dark gold/amber base colour) – it must be a separate mesh
   │   ├─ Arm_L_Upper         origin at the shoulder joint
   │   │    └─ Arm_L_Lower    origin at the elbow
   │   │         └─ Hand_L    origin at the wrist (glove)
   │   ├─ Arm_R_Upper → Arm_R_Lower → Hand_R   (same, +X side)
   │   ├─ Backpack            jetpack, origin at the centre of its back-plate
   │   │    ├─ Marker_JetL, Marker_JetR   empties at the nozzle exits (pointing down)
   │   ├─ Chest_Light         tiny emissive mesh on the chest (material `Emissive_Light`)
   │   └─ Marker_Eye          empty at the eye level inside the helmet (first-person camera)
   ├─ Leg_L_Upper             origin at the hip joint
   │    └─ Leg_L_Lower        origin at the knee
   │         └─ Foot_L        origin at the ankle (boot)
   └─ Leg_R_Upper → Leg_R_Lower → Foot_R
  ```
  `_L` = the character's left = **−X** (the character faces +Y, so its right hand is at +X).
  Also add `Marker_Tool` (empty, child of `Hand_R`, at the palm) for a hand-held tool.
* Material names: `Suit_White` (rough ≈ 0.6), `Suit_Accent` (orange), `Suit_Dark` (grey rubber/fabric), `Metal`, `Visor`, `Emissive_Light`, `Emissive_Jet` (the glowing core, cyan-white).
* The limbs must bend convincingly when the game rotates the nodes around the X axis (walk cycle) and Z axis (arms out): no gaps at the joints (overlap the rounded ends – use spheres/capsules at the joints), no body parts that would intersect badly when swinging ±45°.
* ≤ 25 000 triangles. Collision hint: `capsule` radius 0.35 height 1.8.

## 3. `landing_pad` – ship landing platform
Round pad Ø ≈ **16 m**, thick plate (top surface at **y = 0 in Godot = z = 0 in Blender**, the pad body extends **down to −1.2 m** so it can sink into sloped ground), chamfered rim, hazard-stripe ring (yellow/black), a large inset ship glyph or "H" mark, concentric panel rings, 12 recessed `Emissive_Light` edge lights (amber/white), 3 small light pylons on the rim, a small service hatch with a ladder-less step. Origin = pad centre at the top surface. Collision: `cylinder` radius 8 height 1.2 offset (0,−0.6,0).

## 4. Outpost kit (each its own model; origin at the ground-contact centre; structures extend ~0.8 m below the origin plane so they can be embedded in slopes)
* `outpost_hab` – habitat module: dome/capsule ≈ 8 m wide × 4.5 m high on a rim base, airlock door with `Emissive_Light` frame, 4–5 `Emissive_Window` windows (warm amber), roof vents/antenna, utility pipes, a front step. Door faces **+Y in Blender (−Z in Godot)**. Collision `box`.
* `outpost_tower` – lattice communications tower ≈ **18 m** tall with a dish, antennae, ladder, a red blinking `Emissive_Light` lamp on top (separate node `Light_Top`) and a small equipment hut at the base. Collision: cylinder around the base.
* `outpost_container` and `outpost_container_b` – shipping containers 6 × 2.5 × 2.6 m (corrugated sides, door bars, corner castings, bevels) in two colour schemes (orange; teal/white with stencil-like marks via small inset strips), slightly weathered (vary roughness). `_b` can be a different shape: e.g. two stacked half-height crates or a longer 9 m container. Collision `box`.
* `outpost_tank` – group of 2–3 cylindrical storage tanks (≈ 4 m Ø × 6 m) with catwalk, pipes, ladders, a pump house. Collision: box.
* `outpost_solar` – field of 6–8 tilted solar panels on stands (blue-black glass cells with subtle grid via thin strips, light frame) plus a small battery box. ≈ 8 × 6 m footprint. Collision: box.
* `beacon_pylon` – slim tapered pylon ≈ 7 m tall with a glowing crystal/ring on top (`Glow_Beacon`, tintable), base plate with `Emissive_Light` accents. Collision: cylinder.
* `monolith` – ancient alien monolith ≈ 7 m tall, a slightly irregular slab of dark stone with etched glyph lines (`Glow_Rune` material, tintable emission) running up the face and a sunken ring base. Collision: box.
* `crate_supply` – a small (≈ 1.2 m) supply crate/drop-pod with rounded corners, lid, `Emissive_Light` indicator. Collision: box.
* `wreck_ship` – crashed small ship hull ≈ 10 m: bent wing, torn plating exposing ribs, one engine missing, scorched dark paint (`Hull_Paint` weathered + `Hull_Dark`), a few glowing `Emissive_Light` embers/sparks, tilted ~15° and meant to sit half buried (origin at its lowest centre point). Collision: box.

---

## Deliverables / done criteria
* `assets/models/<name>.glb` for every model above + `assets/models/manifest.json` entries (via `export_model`), `blender/PROGRESS.md` updated, `blender/lib.py` + `blender/model_<name>.py` for each model, `max_effort.blend` saved.
* Godot `--headless --import` + `inspect_glb.gd` run on every new GLB: node names / pivots / materials as specified.
* Final message (short!): list of exported models with triangle counts, anything that deviates from this brief, and for the ship which way each gear leg should rotate to retract.
