# HORIZON DRIFT

> **Как запустить готовую сборку / How to run the ready-made build:** см. / see [HOW_TO_PLAY.md](../../HOW_TO_PLAY.md) в корне репозитория / in the repository root. Если ниже упоминаются другие файлы запуска — их в этом репозитории нет / if other launch files are mentioned below, they are not part of this repository.

A No Man's Sky-style space exploration game built in **Godot 4.7.2** (GDScript, Forward+, Jolt). A seeded galaxy of 720 stars, procedurally generated
star systems, **spherical planets you can walk around**, seamless space -> atmosphere -> landing -> walking -> take-off, a flyable ship with a pulse drive,
and **black holes** that carry you across the galaxy. Every custom 3D model (ship, astronaut, flora, rocks, structures, creatures, asteroids, station) was
modelled in **Blender through the Blender MCP** (port 9882) and exported as `.glb` into `assets/models/`.

> **Status in one paragraph (please read).** Everything built by the module agents is merged and verified in three ways: (1) a headless end-to-end test
> (`tests/final_flow_headless.gd`, 17 checks) runs start pad -> walking -> take-off -> space -> planet capture -> black hole -> second system -> hyperdrive
> back; (2) a headless feature sweep (`tests/final_features_headless.gd`: overlays, pause, cameras, gear, crash, gas-giant barrier, scanner, interaction, mining,
> death/respawn, quit to menu and restart) finishes with 0 failed checks and **0 script errors**; (3) screenshots of every UI screen, every biome at ground level,
> space, planets/gas giant/star/black hole from orbit and atmospheric entry (`docs/screenshots/`). What is **not** done: no human has play-tested the build end to end,
> the audio has only been analysed numerically (never listened to), and development was disrupted by three PC freezes (see *Known limitations*).

---------------------------------------------------------------------------------------------------------------------------------

## 1. How to run

* Requirements: Godot **4.7.2** (standard build, not .NET), a Vulkan-capable GPU. Nothing else: no add-ons, no external assets.
* **Just play: double-click `build\HorizonDrift.exe`** (Windows 64-bit release build, a single file with the game data embedded, ~115 MB; no Godot installation needed).
  It was built with `Godot --headless --path . --export-release "Windows Desktop" build/HorizonDrift.exe` (preset in `export_presets.cfg`; tests, docs and the `.blend` are excluded)
  and smoke-tested: it starts from the embedded package with 0 script errors and renders the start scene.
* Or open `project.godot` in the Godot editor and press **F5** (main scene is set to `res://scenes/main.tscn`), **or** from a shell:
  `Godot_v4.7.2-stable_win64.exe --path "<this folder>"`.
* The imported-asset cache (`.godot/`) is part of the folder. If you copy the project somewhere else (or the first launch complains about unknown
  classes / missing `.glb`), import once: `Godot --headless --path "<folder>" --import --quit`, then run normally.
* The game starts at a **main menu**. *Start* spawns you inside your landed ship on a landing pad on the lush planet **Verdant**, at dawn.
* Keyboard + mouse only (the mouse is captured while playing; `Esc` pauses and frees it).

## 2. Controls (also shown in-game: `F1`, main menu, pause menu)

| Key | On foot | In the ship |
|---|---|---|
| Mouse | look | pitch / yaw |
| `W` `S` | walk | thrust forward / back |
| `A` `D` | strafe | strafe |
| `Space` | jump; **hold in the air = jetpack** | ascend / take off |
| `Ctrl` | crouch | descend |
| `Shift` | sprint | boost |
| `Q` `E` | - | roll |
| `X` | - | **pulse drive** on/off (interplanetary cruise, up to ~40 km/s) |
| `G` | - | landing gear (also auto-deploys when low and slow) |
| `F` | interact (enter ship, open crates, activate monoliths) | exit the ship (when landed) |
| Left mouse (hold) | **mining beam** (resource nodes) | - |
| `C` | **scanner pulse** (marks points of interest / resources) | scan |
| `L` | flashlight | - |
| `V` | first / third person | chase / cockpit camera |
| `M` | **galaxy map** (hyperdrive jumps) | same |
| `N` / `T` | system map / cycle navigation target | same |
| `I` | inventory | same |
| `F1` / `F12` / `Esc` | controls / screenshot / pause | same |

## 3. What is in the game

**Galaxy.** `Universe` generates 720 stars on a two-arm logarithmic spiral with a central bulge (seed `20261031`), each with a spectral class (O..M, colour, size)
and its own seeded planetary system, generated on demand and identical on every visit. The sky has a procedural star field and a Milky-Way band. The
**galaxy map** (`M`) shows the whole spiral as ~720 selectable stars with info cards, the current system, the black-hole link, and warp cost
(1 warp cell + 1 per 6000 ly; craft cells from Voidstone, 3 = 1 cell).

**Star systems.** Home system *Aurelia* (G-class, hand-authored for variety) has 9 bodies: **Cinder** (volcanic), **Verdant** (lush, start) with its moon **Pale**
(barren), **Dune** (desert), **Boreas** (frozen), the ringed gas giant **Colossus** with moons **Miasma** (toxic) and **Prism** (exotic), and the black hole
**Charon's Gate**. That is 7 landable worlds in 7 distinct biomes. Orbits are visible (system map animates them), planets rotate (day/night cycle of 8-25 min),
and the star is a glowing disc with corona. The second hand-made system *Kepler's Rest* (K-class, orange) has different procedural planets; every other star
generates a valid system (5-9 bodies, >= 4 landable, >= 4 distinct biomes - checked by the generator and by the test).

**Planets.** 10 biome profiles (lush, desert, frozen, volcanic, toxic, barren/airless, ocean, exotic, swamp, radioactive) + gas giants. Each differs in
terrain shape (dunes, craters, lava basins, ridges, islands, ...), palette, sky/atmosphere colour, flora and rocks, weather particles, gravity, temperature
and hazards. All of it derives from the planet's seed (`SeedUtil`), so a planet is the same every time.
Planets are **real spheres** (radius 2-11 km) rendered as a cube-sphere quadtree with threaded chunk generation, geomorphing, skirts and a
collision patch around the player; gravity points to the planet centre and "up" follows the surface.

**Seamless flow.** Space -> atmosphere -> landing -> walking -> back to the ship -> take-off, no loading screens. Atmosphere is an analytic scattering
post-process (limb glow from space, blue sky / sunsets on the ground, stars at night), with atmospheric entry heat and shake. Landing is detected with three
gear contact points (safe speed / slope limits, damage and bounce otherwise).

**Numerical precision at planetary and interplanetary scale** (the central engineering problem; `autoload/frame.gd`): absolute positions live in double precision
(`DVec`); rendering/physics use a *local frame*. In space it is a floating origin re-centred on the ship (never more than ~2 km away). Inside 14 planet radii it
switches to the planet's rotating frame in which **the planet is fixed at (0,0,0)** (millimetre precision on the surface, the sun and stars sweep across the sky).
Frame switches are one rigid transform applied to every frame object, so nothing pops. Camera clip planes obey a measured far/near <= 2e7 rule.

**Ship "Wanderer".** Arcade 6-DOF flight with flight assist, boost, **pulse drive** for interplanetary distances (auto-limits near bodies, consumes Zyrite fuel),
landing gear animation, atmospheric speed limit and entry heat, gas-giant crushing-pressure barrier, chase and cockpit cameras, engine/pulse VFX.

**On foot.** Walk, sprint, jump, jetpack, crouch, wade; first-person view model and third-person astronaut with procedural animation; **mining beam**,
**scanner**, flashlight, vitals + hazards (heat, cold, toxic air, radiation) per biome, inventory, enter/exit the ship.

**Things to do.** Resource nodes (Ferrite, Zyrite, Sodium, Voidstone), landing pads, outposts, towers, ancient monoliths, supply caches, crashed ships, ruins,
weather, fauna (creatures that wander and flee), an orbital station, freighter, satellites and asteroid fields. Collected Zyrite refuels the pulse drive,
Sodium recharges hazard protection, Voidstone crafts warp cells (3 = 1 cell), Ferrite repairs the hull (inventory button or the pad terminals).

**Black hole** - see section 4.

**Interface.** Main menu, HUD (speed, altitude, state, fuel/hull, vitals, resources, compass, world markers for planets/star/black hole, context hints, toasts, black-hole
warnings), pause menu with settings, controls overview, galaxy map, system map, inventory.

**Audio.** All sounds are synthesised in code (`audio/`, see `audio/README.md`); output is muted in windowless/test runs.

**Models (Blender MCP).** 92 `.glb` models in `assets/models/` (+ `manifest_*.json`): the player ship, astronaut, multitool and first-person view model, 4 creatures,
~65 flora/rock/resource models for all biomes, 13 structures, freighter, orbital station, satellite and 3 asteroids. Built by Python scripts (`blender/*.py`) run
through the MCP socket (`tools/bmcp.py`, port 9882); the scenes are in `ultracode_effort.blend` (one collection per model). No external models or generators were used.

## 4. The black hole (design and reasoning)

*Reference:* in No Man's Sky black holes are fixed objects that teleport you ~7,000 ly toward the galactic centre. Here each hand-made system has one:
**Charon's Gate** in Aurelia leads to **Kepler's Rest** (placed ~7,000 ly closer to the core on the galaxy map) and its **Return Gate** leads home; ~10 % of the
other stars have one that leads ~7,000 ly toward the centre.

*Visuals* (`world/blackhole/`, `shaders/blackhole_*.gdshader`): a pitch-black event horizon with photon ring, a glowing accretion disc (white-hot inner edge to
deep red, Doppler beaming: one side brighter), the far side of the disc bent over the top and under the bottom, and **gravitational lensing of the background**
by a full-screen ray-marching shader that integrates bent light paths (Binet acceleration) and samples the already-rendered frame at the deflected
direction. A near-field post effect adds chromatic aberration, vignette and a red-shift tint. Worst-case cost measured by the module test: ~2 ms at 720p.

*Mechanics* (all numbers in `core/blackhole_params.gd`): the pull is `a = MU / r^2` (MU = 6e10) applied to the ship. Zones:

| zone | distance | effect |
|---|---|---|
| influence | 420 km | lensing + pull begin |
| caution | 300 km | HUD warning "gravitational anomaly", rumble |
| danger | 120 km | pulse drive locked, shake, controls begin to fade, red HUD panel |
| **point of no return** | 22 km | pull (~124 m/s^2) exceeds the ship's thrust; a capture field takes over; alarm |
| event horizon | 2.1 km | spaghettification / white-out, then **transport** |

*Why:* the ship's full thrust is ~150 m/s^2, the pull reaches that at ~20 km, so the point of no return is a real, computable threshold (you can still
escape before it; not after). The warnings give a pilot at boost speed minutes to react. Crossing the horizon plays a red vortex tunnel and a white-out, loads the
destination system and ejects you from *its* singularity at 500 m/s (a "white hole" shock ring), with its pull faded in slowly so you can fly away. The
hyperdrive (galaxy map) uses a blue-white star-streak tunnel instead. Full design notes, numbers and test list: `world/blackhole/README.md`.

## 5. Project layout

```
autoload/   events, universe (galaxy + systems + orbits), frame (floating origin / planet frames), game (state, input, warps), debug_cli
core/       DVec, SeedUtil, BodyDef/StarDef/SystemDef, BiomeDB, ResourceDB, ModelLib (glb loader), BlackHoleParams
world/      planet (terrain quadtree), sky + atmosphere + star + ocean + clouds + gas giant, blackhole, content (scatter, POIs, weather, fauna, extras)
ship/  player/  ui/  audio/  shaders/
assets/models/*.glb + manifest_*.json     blender/*.py (model generators)     ultracode_effort.blend
docs/ARCHITECTURE.md  docs/MODELS_SPEC.md  docs/RESUME.md      tests/ (module tests)      tools/ (runner, screenshot + sandbox tooling)
```
`docs/screenshots/` has contact sheets of the final build. `_backup/` is a safety copy of the pre-merge state.

## 6. Testing

* Headless logic test (no GPU): `tools\godot.ps1 -Mode run -Headless -GodotArgs "-- --autostart --preset=landed --test=res://tests/final_flow_headless.gd"`
  -> `FLOW SUMMARY: 0 failed checks` (start frame, exit ship, walk on the sphere, enter ship, take-off, floating origin, planet capture, black-hole warnings
  to the point of no return, transport to Kepler's Rest, arrival near its gate, hyperdrive back, valid destination systems).
* Headless feature sweep (no GPU): `... --test=res://tests/final_features_headless.gd` -> `FEAT SUMMARY: 0 failed checks`.
* `tools\godot.ps1` runs Godot windowless. It **refuses to render** unless the env var `HD_ALLOW_RENDER=1` is set (rendering was disabled for agents after the PC freezes);
  render runs are capped at 20 fps / 1024x576, one at a time, with a GPU-temperature guard. Use `-Headless` for logic tests.
* Visual checks: `DebugCLI` (`autoload/debug_cli.gd`) provides `--autostart --preset=air:1:300 --shot=path@seconds --keys=... --log-tel=...` for scripted screenshots
  and input injection; `tools/shot_batch.ps1` + `tools/make_sheets.py` produce contact sheets of every biome and space scene.
* Module tests live in `tests/` (`terrain_*`, `ship_*`, `player_*`, `bh_*`, `ui_*`, `content_*`, `life_*`, `audio_*`, `sky_*`).

## 7. Known limitations (honest list)

* **Art left to polish.** The exotic biome is extremely saturated (magenta ground, violet sky), toxic is a strong green wash, and the gas giant is a fairly
  small disc from long range; clouds and ocean were only checked from a few angles. The planet-from-orbit view is good (atmosphere rim, clouds) but the HUD labels crowd it.
* **Not play-tested by a human end to end**; feel numbers (flight handling, jetpack, pulse approach speed) are tuned by test scripts and screenshots only.
  **Audio** was only analysed numerically (levels, loops), never listened to.
* Swamp / radioactive biomes appear in other generated systems but received less tuning than the main biomes; the `.blend` was last saved before the final model reviews finished, so a few model tweaks exist only in the exported `.glb` files (the generator scripts in `blender/` are the source of truth).
* The gas giant is not landable (the ship is pushed back by "crushing pressure").
* Bodies farther than the camera far plane (2e6 m on foot, 6e6 m in the ship) vanish (only the star is always visible); the black-hole lens samples the already-rendered frame.
* The headless test needs `--headless`; with a window the same flow runs but was only spot-checked with screenshots.
* **Hardware warning.** During development the PC hard-froze three times (Windows logs: GPU timeout events 117/141 from the NVIDIA driver) while many
  Godot/Blender sessions rendered at once. The game itself is light (30-180 fps in tests; the black-hole lens costs ~2 ms), but if your GPU driver is
  unstable, lower the resolution and MSAA (`project.godot`, `rendering/anti_aliasing/quality/msaa_3d`) and do not record while loading assets.

## 8. Credits / rules compliance

All 3D models were generated by code inside Blender via the Blender MCP socket on port 9882; none were downloaded, no asset packs, no Poly Haven / Sketchfab /
Hyper3D / Hunyuan integrations. Terrain, star, sky, atmosphere, black hole, particles, shaders, UI and audio are created in Godot.
