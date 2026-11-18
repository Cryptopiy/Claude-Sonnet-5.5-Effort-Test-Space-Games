# SOLACE - a No Man's Sky-style space exploration game (Godot 4.7.2)

> **Как запустить готовую сборку / How to run the ready-made build:** см. / see [HOW_TO_PLAY.md](../../HOW_TO_PLAY.md) в корне репозитория / in the repository root. Если ниже упоминаются другие файлы запуска — их в этом репозитории нет / if other launch files are mentioned below, they are not part of this repository.

## Run
Open the folder in Godot 4.7.2 and press F5 (main scene `res://scenes/main.tscn`), or:
`Godot_v4.7.2-stable_win64.exe --path "<this folder>"`. No extra installation.

## Controls
| Ship | |
|---|---|
| Mouse | pitch / yaw |
| W / S | throttle forward / reverse |
| A / D | roll |
| Space / Ctrl | vertical thrusters up / down (take-off, landing) |
| Shift | boost |
| F | pulse drive (fast cruise; auto-slows near bodies) |
| V | chase / cockpit camera |
| E | exit ship (when landed) |
| M / Tab | galaxy map (click star, Enter = hyperjump) |

| On foot | |
|---|---|
| WASD, Shift | walk, sprint |
| Space | jump, hold for jetpack |
| E | collect resource / scan beacon / board ship (within 9 m) |
| F | scanner pulse (marks outposts, pads, resources) |
| V | first / third person |
Esc = pause menu (also has controls overview).

## What was built
- **Galaxy**: 900 seeded stars on a two-arm spiral, classes M-B with colours/sizes; procedural sky shader (stars + galactic band, tinted per system); interactive galaxy map with jump range and black-hole link.
- **Star systems**: generated from the star index. Home system "Solace" (G star) has 8 bodies: Cinder (volcanic), Verdance (lush) + moon Lumen (barren, airless), Dune (desert), Mycelia (toxic swamp), Aurora (gas giant with rings), Glacia (frozen), Vesper (exotic). Other systems are generated with biomes depending on star luminosity and orbit. Planets orbit and spin (day/night cycle 8-15 min).
- **Planets**: spherical cube-sphere quadtree terrain LOD (up to ~0.6 m cells, generated on worker threads, skirts hide cracks), seeded height noise per biome (hills/ridges, mesas, craters, lava lakes, seas), vertex-colour palettes with triplanar detail, water, atmosphere shell, altitude-dependent sky/fog, per-biome gravity, hazards (heat, cold, toxic, radiation), weather particles (rain, snow, ash, dust, spores), instanced flora, landing pad + outpost + beacon on each world, collectible resources. Everything derives from seeds, so planets are identical on every visit.
- **Seamless flight**: space -> orbit frame -> atmosphere/surface frame (rotating with the planet) with no loading; re-entry glow, speed limited by altitude, auto-levelling, landing detection (hard impacts damage the hull).
- **Precision**: floating-origin design. In space the ship sits at the render origin; near a planet all coordinates are planet-local (<= a few km), so there is no jitter. Reverse-Z depth with near 0.1 m.
- **Black hole** (one per system, ~200 km from the star): dark horizon sphere, animated accretion disc with Doppler asymmetry, screen-space gravitational lensing + photon ring. Mechanics: pull `a = K/d²` starts at 48 km (HUD warning, camera shake and FOV stretch grow); the pulse drive is jammed within 30 km; thrust authority is reduced by 2.2x the pull, so below about 8 km you drift in and at about 6 km (point of no return) even boost cannot escape. Crossing the horizon (1.15 km) plays a transit effect and teleports you to the fixed destination system roughly 7000 ly closer to the galactic centre (see `Galaxy.bh_target`), as in No Man's Sky's black hole travel. Reasoning: a smooth, readable escalation with clear warnings and a fair, physical point of no return.
- **Hyperjump**: galaxy map -> Enter, needs open space, range 14000 ly; arrival in a freshly generated system.
- **Models (Blender MCP, port 9878, `medium_effort.blend`)**: ship, astronaut, lush tree, alien tree, cactus, ice spikes, two crystals, two rocks, mushroom, dead tree, lava spire, grass, landing pad, outpost, beacon, resource. Script in `tools/models.py`; exported to `assets/models/*.glb`. No external assets.
- UI: main menu, pause menu, controls panel, HUD (speed, altitude, status, location, gravity, hazard, bars, inventory, nav markers, star lens flare).

## Decisions / limitations
- Ship uses an arcade flight model with anti-gravity hover (no gravity on the ship); player has real gravity.
- Terrain/ship collision is analytic (height function); flora has no collision. No audio, no fauna.
- Orbital periods are long (about 45-90 min), so orbital motion is slow but visible over minutes.
- Test harness: `-- --test=full|ui|space|bhfull --shot=<prefix>` user args drive automated runs and screenshots.
