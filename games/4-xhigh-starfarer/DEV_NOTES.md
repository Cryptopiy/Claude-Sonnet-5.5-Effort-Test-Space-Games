# DEV NOTES (internal, for me) — Starfarer (NMS-style) in Godot 4.7.2

Port 9880 / Blender file xhigh_effort.blend / project dir = this folder. Start time in .timing/start.txt
Blender client: `python tools/bmcp.py run <script.py>` (socket 9880 only). Scripts in blender_scripts/ (lib.py = helpers).
Montage helper: tools/montage.py (PIL available).

## Models (assets/models/*.glb) — all made via Blender MCP
ship (Ship_Body, Ship_Glass, Ship_Gear_Front/L/R, Ship_Flame_L/R/C; nose=-Z in Godot), astronaut (Astro_* hierarchy + jet flames + Astro_HandR),
multitool, tree_lush, tree_umbrella, tree_pine, cactus, tree_dead, mushroom_giant, mushroom_small, flower_glow, grass_tuft, bush,
crystal_cluster, ice_spire, lava_spike, vent_cone, spore_pod, coral_tower, rock_a/b/c, pebbles, rock_arch, hoodoo, asteroid_a/b/c,
landing_pad, outpost, monolith, radio_tower, crate_stack, ore_node, wreck, space_station, creature_strider/floater/flyer.

## Architecture (decided)
- Everything near the camera: render origin == focus (ship or player) every frame; bodies' abs positions are doubles (DV), subtract origin in double.
- Planets: GPU-displaced cube-sphere quadtree chunks (vertex shader evaluates terrain_height(dir)); CPU twin in scripts/core/tnoise.gd + planet_data.gd
  (bit-exact integer-hash Perlin) for collisions/prop placement. NO Godot physics for terrain; analytic collisions in ship/player controllers.
- Ship/player live either in SPACE (system frame) or in a planet's local rotating frame (within frame altitude).
- Atmosphere = shell mesh shader (additive scattering) + env fog; sky shader draws stars/galaxy.
- Black hole = billboard quad with Schwarzschild geodesic raymarch shader + accretion disc.

## Status log
(see bottom; updated as I go)
- [x] Blender models exported (38 glb)

## !! TEST-ONLY STATE (user is recording video; no windows may appear on screen) !!
- Godot test runs: 8x8 transparent borderless no-focus window, transparent_bg (DO NOT minimise: Godot stops drawing when minimised); rendering goes to a SubViewport (tests/stealth.gd). user://test_override.cfg holds the window flags.
  File: %APPDATA%\Godot\app_userdata\Sonnet 5.5 - Xhigh Effort\test_override.cfg  -> MUST DELETE before finishing (it makes the real game unfocusable).
- Helper: tools/gorun.sh (bash) launches Godot this way. ALWAYS run `--headless --import` after adding class_name scripts, else scenes silently fail to load and hang.

## PAUSED by user (2026-10-31 ~13:30 local) — RESUME HERE
Start time: .timing/start.txt (11:06:40 +01:00). Keep tracking elapsed time; the pause itself should be mentioned in RESULTS.md.
Test override was DISABLED: rename `%APPDATA%\Godot\app_userdata\Sonnet 5.5 - Xhigh Effort\test_override.cfg.off` -> `test_override.cfg`
before running stealth tests again (and DELETE it for good before finishing; it makes the real game unfocusable).
`project.godot` still references user://test_override.cfg (harmless if the file is absent; remove that line at the end).

### Done & verified
- 38 Blender models exported (assets/models), blend saved.
- GPU terrain (cube-sphere quadtree, CPU/GPU parity <1.5 cm), atmosphere/clouds/water/lava shaders, sky, star+corona, black hole (geodesic raymarch), gas giant+rings.
- World loop (floating origin, doubles), ship (pulse, boost, frames, landing), player (walk/jetpack/swim), HUD, menus, galaxy map, prop manager (flora threads, resources, POIs, fauna, weather, scanner), procedural audio.
- Flow test (tests via `tools/gorun.sh res://scenes/main.tscn -- --stealth --scn=flow|foot|bh|jump|ground|orbit|menu --out=shots`):
  pulse -> atmosphere entry -> auto-landing -> exit ship -> sprint -> jetpack all OK; black hole zones 2/3/4 + transit trigger OK.

### Open items / next steps (in order)
1. `--scn=foot` was running when paused: verify walking back + board_ship (previous run printed boarded: on_foot=true => board failed; read MSG output, probably distance >9 m or frame mismatch), take-off, leave atmosphere.
2. `--scn=bh` (escape test from 30 km, fall-in, transit, arrival in new system `Nena`?), `--scn=jump` (galaxy map + hyperjump) — both written, never run.
3. Visual tuning: terrain colours flat/saturated green, atmosphere in-scatter washes out planets from orbit (lower exposure), water looks black from far, sky grey-teal, ship engine glow; check all 7 biomes from ground + orbit, props visible, day/night, weather.
4. Perf check (ground ~100 fps earlier; watch hitches from prop cell apply), check for script errors/warnings in console.
5. Space station/asteroid belt (models exist: space_station, asteroid_a/b/c) not yet placed in the world. Creatures exist but untested visually.
6. README.md, RESULTS.md (time, tokens from ~/.claude/projects jsonl, API cost), delete test override + project_settings_override line, final full test run.

## FINISHED (2026-10-31 ~13:49 local)
All MUST items implemented and verified by scripted runs (flow/jump/biomes/mine/space/ui/extras/perf/jitter/entry). README.md + RESULTS.md written.
Test-only window config removed (user://test_override.cfg gone, project_settings_override line removed); xhigh_effort.blend.import set to `skip`.

## EXE build
build/Starfarer.exe exported (release, embedded pck, 110 MB) via export_presets.cfg; verified by running the exe in hidden stealth mode (ui scenario).
