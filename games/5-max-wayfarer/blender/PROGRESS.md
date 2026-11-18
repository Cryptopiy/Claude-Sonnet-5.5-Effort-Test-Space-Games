# Modelling progress (name | tris | size in Godot axes x,y,z (m) | status / notes)

Brief 1 (hero assets + structures) - all exported to assets/models/*.glb, listed in assets/models/manifest.json, imported and inspected in Godot 4.7.2 headless.
Scripts: blender/lib.py (shared helpers), blender/model_<name>.py (one per model; container + container_b share model_outpost_container.py),
blender/export_ship_explorer.py, blender/export_astronaut.py, blender/export_batch.py (all other models; per-model material overrides + `Body` node naming).
Blender object names are file-global, so finished models are "parked" (objects get the suffix `__<collection>`); the export scripts unpark -> export -> park.

- ship_explorer | 28150 | 12.9 x 6.2 x 14.2 (incl. gear + glow tip) | exported + verified in Godot. Gear retract = rotate Gear_Front/Gear_RearL/Gear_RearR about local X by -90 deg (Godot rotation.x = -PI/2): feet swing to +Z (tail) and up into the hull
- astronaut | 20848 | 1.05 x 1.8 x 0.60 | exported + verified in Godot. A-pose, origin between feet; jointed meshes with pivots on the joints, exact names as in the brief
- landing_pad | 7725 | 16.0 x 3.35 x 16.0 | exported (inset ship glyph, hazard ring, 12 rim lights, 3 pylons, service hatch + step); mesh node `Body`
- outpost_hab | 7462 | 9.3 x 7.75 x 9.9 | exported (airlock door faces +Y Blender = -Z Godot); mesh node `Body`
- outpost_tower | 6732 | 8.8 x 18.9 x 5.1 | exported; mesh node `Body` + child `Light_Top` (red lamp)
- outpost_container | 5808 | 6.1 x 3.55 x 2.8 | exported (orange, doors +X); mesh node `Body`
- outpost_container_b | 7756 | 9.1 x 3.55 x 2.8 | exported (9 m teal/white, stencil marks, doors +X); mesh node `Body`
- outpost_tank | 7752 | 21.8 x 8.7 x 6.5 | exported (3 tanks, catwalk, caged ladder, manifold, pump house); mesh node `Body`
- outpost_solar | 6684 | 12.1 x 4.0 x 5.4 | exported (panel field ~7.8 x 5.2 m + battery box + mast); mesh node `Body`
- beacon_pylon | 1704 | 2.7 x 7.9 x 2.7 | exported (Glow_Beacon crystal + ring, Emissive_Light base accents); mesh node `Body`
- monolith | 5190 | 8.6 x 7.8 x 8.7 | exported (slab 2.4 x 0.9 x 7 m + ring base r 3.95 m, Glow_Rune glyphs); mesh node `Body`
- crate_supply | 2684 | 1.5 x 1.7 x 1.35 | exported; mesh node `Body`
- wreck_ship | 6836 | 6.3 x 4.6 x 10.3 | exported (tilt baked in, origin at lowest centre point, weathered Hull_Paint/Hull_Accent values in this GLB); mesh node `Body`

Notes for the programmer
- Material names are global in Blender; per-model colours of `Emissive_Light` (cyan on ship/astronaut/beacon, white on the pad, mint on hab/tank, red on the tower lamp, green on solar/crate, orange embers on the wreck)
  and the weathered `Hull_Paint` of the wreck are baked into each GLB at export time.
- Extra material names used (all Principled BSDF): Emissive_Amber, Emissive_ScreenAmber, Emissive_NavRed, Emissive_NavGreen, Emissive_Beacon, Emissive_Jet, Pad_*, Hazard_*, Container_*, Solar_*, Stone_*, Concrete, Pipe_Steel, Glow_Beacon, Glow_Rune.

Brief 2 (flora, rocks, resource nodes, biome props): scripts blender/model_flora_*.py, model_rocks.py, model_toxic.py, model_frozen.py, model_volcanic.py, model_irradiated.py, model_moon.py ... (several models per script), export via blender/export_nature.py; helpers in blender/lib_nature.py (loaded by lib.py).
Tint contract (shared materials created once by nature_palette()): Foliage_A/B/Flower, Crystal_Main, Glow_Main, Rock_A/B, Bark(_Pale) are recoloured by the game; Snow, Obsidian, Emissive_Lava, Res_* keep their colour.

- tree_lush_a | 2016 | 6.9 x 9.1 x 6.0 | exported; mesh node Body; origin at ground contact
- tree_lush_b | 1801 | 7.0 x 14.4 x 7.4 | exported; mesh node Body; origin at ground contact
- tree_lush_c | 2100 | 10.3 x 7.6 x 10.1 | exported; mesh node Body; origin at ground contact
- bush_lush | 545 | 1.9 x 1.5 x 2.0 | exported; mesh node Body; origin at ground contact
- fern | 431 | 2.0 x 1.2 x 2.2 | exported; mesh node Body; origin at ground contact
- flower_cluster | 360 | 0.8 x 0.7 x 0.7 | exported; mesh node Body; origin at ground contact
- grass_tuft | 55 | 1.0 x 0.7 x 1.3 | exported; mesh node Body; origin at ground contact
- rock_a | 320 | 2.1 x 1.8 x 1.9 | exported; mesh node Body; origin at ground contact
- rock_b | 104 | 2.7 x 1.6 x 2.4 | exported; mesh node Body; origin at ground contact
- rock_c | 426 | 3.3 x 1.6 x 2.9 | exported; mesh node Body; origin at ground contact
- rock_d | 157 | 2.7 x 3.6 x 2.3 | exported; mesh node Body; origin at ground contact
- boulder_big | 439 | 8.8 x 6.1 x 7.0 | exported; mesh node Body; origin at ground contact
- resource_sodium | 237 | 1.2 x 1.4 x 1.1 | exported; mesh node Body; origin at ground contact
- resource_ferrite | 688 | 1.8 x 1.3 x 1.4 | exported; mesh node Body; origin at ground contact
- resource_carbon | 590 | 2.1 x 1.3 x 2.0 | exported; mesh node Body; origin at ground contact
- cactus_a | 1080 | 2.2 x 4.8 x 1.3 | exported; mesh node Body; origin at ground contact
- cactus_b | 803 | 1.8 x 1.3 x 1.7 | exported; mesh node Body; origin at ground contact
- dead_tree | 1036 | 2.7 x 5.4 x 1.3 | exported; mesh node Body; origin at ground contact
- desert_shrub | 310 | 1.5 x 1.0 x 1.5 | exported; mesh node Body; origin at ground contact
- mesa_rock | 524 | 9.5 x 9.4 x 8.8 | exported; mesh node Body; origin at ground contact
- rock_arch | 624 | 13.1 x 10.2 x 4.6 | exported; mesh node Body; origin at ground contact
- mushroom_giant | 1972 | 10.9 x 12.1 x 10.9 | exported; mesh node Body; cap Foliage_B + glowing Glow_Main gills, Bark_Pale stalk/spots; walk-under height ~8 m; collision = stalk only
- mushroom_small | 740 | 1.4 x 1.2 x 1.1 | exported; mesh node Body; 5 Glow_Main caps on Bark_Pale stems
- spore_pod | 709 | 2.4 x 2.5 x 1.6 | exported; mesh node Body; ~2.5 m incl. spore motes; Foliage_A pod + Glow_Main tip
- tentacle_plant | 1324 | 3.0 x 2.6 x 3.2 | exported; mesh node Body; 6 Foliage_B tentacles, Glow_Main tips (2.6 m high, 3 m wide)
- toxic_crystal | 420 | 1.8 x 2.1 x 1.8 | exported; mesh node Body; Crystal_Main shells with Glow_Main cores + glow puddle
- tree_pine_snow | 1514 | 7.3 x 10.5 x 5.9 | exported; mesh node Body; 5 drooping tiers (Foliage_A/B) with Snow caps; collision = trunk
- tree_pine_snow_b | 1177 | 5.1 x 6.5 x 4.6 | exported; mesh node Body; squat 4-tier fir, heavy Snow; collision = trunk
- ice_spire | 480 | 3.1 x 5.3 x 3.2 | exported; mesh node Body; Crystal_Main alpha 0.7 + Snow base
- ice_boulder | 312 | 3.2 x 2.1 x 2.6 | exported; mesh node Body; 3.2 m wide incl. fused 2nd boulder + shards (main rock ~2.2 m)
- frost_shrub | 415 | 1.6 x 1.1 x 1.8 | exported; mesh node Body; Foliage_B blades with Snow tips, no collision
- snow_rock | 255 | 3.7 x 2.3 x 3.4 | exported; mesh node Body; 3.7 m wide incl. companion stone + drifts (main rock ~2 m)
- obsidian_spire | 326 | 3.7 x 6.4 x 3.5 | exported; mesh node Body; Obsidian blade shards (+ Rock_B rubble, 3 tiny Glow_Lava glints)
- lava_rock | 494 | 3.3 x 2.2 x 2.6 | exported; mesh node Body; Rock_B/Rock_A crust plates with gaps over a Glow_Lava core
- charred_tree | 804 | 1.8 x 4.9 x 2.2 | exported; mesh node Body; Bark only (wood tint makes it black) + Glow_Lava embers
- vent_cone | 780 | 5.9 x 3.2 x 5.6 | exported; mesh node Body; Rock_B/Rock_A cone, Glow_Lava crater lake + 4 flank tongues
- crystal_cluster_a | 405 | 2.4 x 3.2 x 2.5 | exported; mesh node Body; Crystal_Main shells + Glow_Main cores
- crystal_cluster_b | 664 | 2.8 x 1.3 x 2.4 | exported; mesh node Body; 15 small crystals, 2.8 m wide bed (1.3 m high)
- crystal_cluster_c | 359 | 2.4 x 4.7 x 2.6 | exported; mesh node Body; tall towers ~4.7 m
- rad_fungus | 572 | 1.2 x 0.9 x 1.1 | exported; mesh node Body; Glow_Main shelves on a Bark stump, no collision
- moon_rock_a | 182 | 2.6 x 1.5 x 1.9 | exported; mesh node Body; flat shaded Rock_A
- moon_rock_b | 76 | 2.9 x 1.6 x 2.7 | exported; mesh node Body; flat shaded Rock_A shards; box collision
- probe_wreck | 2496 | 5.9 x 3.7 x 3.5 | exported; mesh node Body; Metal/Hull_Dark + red Emissive_Light (baked into this GLB); 5.9 m wide because of dish + solar array, mast 3.5 m; box collision around bus/dish only

Brief 3 (creatures + space objects): scripts blender/model_space_station.py, model_creatures.py (+ lib_creature.py), model_asteroids.py, model_satellite.py; export via blender/export_fauna_space.py (specs; reuses export_nature.run).
Creature joint nodes follow scripts/world/fauna.gd (fixed Fur_/Skin_/Shell_ colours, Glow_Main default colour baked per model); Ring pivot = hub centre.
- space_station | 15280 | 153.6 x 120.9 x 184.7 | exported; nodes Station > Ring (pivot at hub centre, spins about local Y) + Marker_Dock (bay mouth, -Z Godot = out); no collision
- creature_grazer | 2336 | 1.0 x 1.5 x 2.4 | exported; nodes Body > Head, Tail, Leg_FL/FR/BL/BR (hip pivots); ~2.4 m long, 1.5 m tall; box collision
- creature_flyer | 1314 | 2.7 x 0.6 x 2.9 | exported; nodes Body > Wing_L/Wing_R (root pivots, flap about Z Godot), Tail; wingspan 2.7 m; no collision
- creature_floater | 2166 | 3.4 x 5.4 x 3.4 | exported; nodes Bell > Tentacle_01..08 (rim pivots); bell dia 3.3 m, tentacles up to 4.1 m; translucent Skin_Bell; no collision
- creature_crawler | 1960 | 1.0 x 0.5 x 1.2 | exported; nodes Body > Leg_1..Leg_6 (hip pivots, 1/3/5 left); 0.95 m wide; box collision
- asteroid_a | 1050 | 33.4 x 15.3 x 17.4 | exported; elongated ~33 x 15 x 17 m; Rock_A/Rock_B; no collision
- asteroid_b | 1050 | 29.4 x 28.7 x 30.3 | exported; round pitted ~29 m; Rock_A/Rock_B; no collision
- asteroid_c | 1048 | 32.3 x 22.1 x 20.8 | exported; two lobes + crack ~32 x 22 x 21 m; Rock_A/Rock_B; no collision
- satellite | 1782 | 9.5 x 7.0 x 4.8 | exported; ~9.5 m wide derelict comms sat (dish, bent + torn solar wings, scorched foil); no collision
