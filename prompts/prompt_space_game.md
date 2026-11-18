# TASK: Build a No Man's Sky–style space exploration game in Godot, with all 3D models made through Blender MCP

You are one of six AI agents running in parallel on the exact same task, each in its own folder with its own Blender instance. Work fully autonomously from start to finish. Do not ask the user questions; if something is ambiguous, make a sensible decision, note it in the README, and keep going. Keep working until the game is complete, tested and polished as far as you can take it.

---

## Autonomy: do not stop until the project is fully finished

You have **full freedom of action** inside your project folder and your own Blender instance. The user is not watching and will not answer.
- **Do not stop, pause or hand control back** until the project is completely finished: every MUST item implemented, tested and working, README and RESULTS written. Never end your turn with a plan, a partial result, "next steps", or an offer to continue.
- **Do not ask for approval, confirmation, permission, clarification or feedback**, at any point. Do not ask "should I continue?" or "which option do you prefer?". Choose the best option yourself and proceed.
- **No check-ins.** Do not wait for the user to review, test or approve anything. Run and verify everything yourself.
- If a command fails, a tool errors out, or an approach does not work, diagnose it and try another way until it works. Do not give up and do not report a blocker as a final answer unless the situation is truly impossible to solve with the resources you have.
- Install nothing system-wide and change no system settings; you do not need to, everything required is already on the machine.
- Only after the definition of done in section 5 is fully met, and the final report in section 7 is written, may you stop.

---

## 0. Your identity and resources (read this first, do not mix it up)

| Item | Value |
|---|---|
| Effort label (for the final report only; do not change how you work because of it) | **Low** |
| Your project folder (the only place you may write files) | `<local-path> 5.5 Effort Test\1. Low Effort` |
| Your Blender file | `<local-path> 5.5 Effort Test\1. Low Effort\low_effort.blend` |
| **Your Blender MCP port** | **9877** |
| Godot executable (GUI) | `W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` |
| Godot executable (console, use this for CLI runs) | `W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |
| Godot version | 4.7.2 stable |
| Blender executable | `W:\Blender\blender.exe` (Blender 5.2.2 LTS) |
| OS | Windows 11 |

The project folder already contains an empty Godot 4.7.2 project (`project.godot`, Forward Plus renderer) and your empty `.blend` file, which is already open in a running Blender instance with the Blender MCP add-on listening on your port.

**Port ownership.** Six agents work at the same time, each with a different Blender instance:

| Effort label | Blender MCP port |
|---|---|
| Low | 9877 |
| Medium | 9878 |
| High | 9879 |
| Xhigh | 9880 |
| Max | 9881 |
| Ultracode | 9882 |

**Your port is 9877.** Never send commands to any other port, never touch another agent's folder or Blender scene.
Before you create anything in Blender, verify that your Blender MCP is connected to the right instance: query the scene and run a short script that prints `bpy.data.filepath`. It must equal `<local-path> 5.5 Effort Test\1. Low Effort\low_effort.blend`. If it does not, stop modelling immediately, write the mismatch into `<local-path> 5.5 Effort Test\1. Low Effort\RESULTS.md`, and finish your report; do not modify a scene that is not yours.

Other agents are running Godot and Blender on the same machine right now:
- Never kill processes by name (`taskkill /im godot*`, `Stop-Process -Name godot`, etc.). Only stop processes you started yourself, by their PID.
- Keep every test run of the game short, and close it when you are done.
- Do not close, restart or "File > New" the Blender instance; save your `.blend` with `bpy.ops.wm.save_mainfile()` regularly.

---

## 1. First action: start the timer

Before anything else, record the start time, for example by writing the current local time and UTC timestamp to `<local-path> 5.5 Effort Test\1. Low Effort\.timing\start.txt` using the shell. You will need it for the final report (section 7).

---

## 2. What you are building

A playable 3D space exploration game in the spirit of **No Man's Sky**, built in Godot 4.7.2 (GDScript or C# is your choice, but it must run from the project as is without extra installation steps).

Reference facts about No Man's Sky, gathered from public sources, to use as inspiration (you do not have to copy everything; reproduce the *feel* and the core loop):
- The universe is procedurally generated from seeds: galaxy > regions > star systems > planets/moons. A planet is defined by its seed, so it is identical on every visit.
- A star system usually holds roughly 3 to 6 planets and moons around a star. The star's color and class influence what the system looks like and what its planets can be.
- Planets fall into biome types such as lush, barren, dead, frozen, lava/volcanic, scorched, toxic, radioactive, swamp, waterworld, exotic, plus gas giants. Each biome has its own terrain shapes, color palette, sky, atmosphere, flora, resources, weather and hazards (extreme temperature, toxic air, radiation, storms).
- The flow is seamless: fly in space, approach a planet, enter its atmosphere, land and take off again, all without loading screens. The player leaves the ship, explores on foot (exosuit with a jetpack and sprint), and returns to the ship.
- Planets have day/night cycles, gravity, and a visible horizon curving away on a spherical world.
- Interstellar travel uses a hyperdrive/warp. **Black holes** in No Man's Sky are fixed objects that transport the player to a fixed distant star system across the galaxy, roughly 7,000 light-years closer to the galactic centre (rarer "hyper" black holes jump much farther), and are tied to the Atlas story path. They are visually dominated by a dark core with a glowing accretion disc and strongly bent light.

---

## 3. Requirements

Items marked **MUST** are mandatory. Items marked **SHOULD** are expected if you can deliver them with good quality. Prioritise getting a complete, working loop first, then improve depth and polish.

### 3.1 Galaxy and star system
- **MUST** A galaxy: a procedurally generated star field/galaxy backdrop (for example a spiral of stars visible in the sky) plus a **galaxy map** the player can open that shows multiple stars.
- **MUST** At least one fully explorable **star system** with a **star** (emitting light, properly lit planets, a visible glowing star with corona/flare) and **at least 5 planets/moons** orbiting it. Orbits and rotation should be visible and plausible.
- **MUST** Everything procedural (planets, terrain, colors, flora placement) is derived from seeds so a given planet is consistent between visits.
- **SHOULD** At least a second star system (different star color, different planets) reachable through the black hole or the galaxy map.

### 3.2 Planets
- **MUST** The planets must be **clearly different from each other**: at least **4 distinct biomes** among the landable planets. Differences must be visible in terrain shape, color palette, sky/atmosphere, vegetation or props, lighting, weather or ambient effects, and gameplay values such as gravity or hazards.
- **MUST** Landable planets are **spherical worlds** the player can actually walk around (gravity points toward the planet centre, "up" follows the surface), not flat planes.
- **MUST** At least one non-landable body is allowed (for example a gas giant), but at least 4 planets/moons must be landable.
- **SHOULD** Day/night cycle, atmosphere that changes with altitude, weather or particle effects, and fauna or other life-like elements.

### 3.3 Ship, landing and on-foot gameplay
- **MUST** A flyable **spaceship** with thrust, rotation, boost and a fast "pulse"/cruise mode for interplanetary distances. Camera views suitable for flying (at minimum one good chase or cockpit view).
- **MUST** **Seamless transition** space > atmosphere > landing > take-off, with no loading screens. Includes visible atmospheric entry effects and a controlled landing (landing gear/landing detection).
- **MUST** The player can **exit the ship**, **walk on the planet** (walk, sprint, jump, jetpack or equivalent), look around, and **return to the ship** and take off again.
- **MUST** Numerical precision at planetary and interplanetary scale must hold up: no visible jitter, no broken physics, no z-fighting artefacts at normal play distances.
- **SHOULD** Something to do on the surface: resources to collect, points of interest, structures, or a simple scanner.

### 3.4 Black hole
- **MUST** At least one **black hole** exists in the galaxy and can be reached by flying the ship.
- **MUST** Its **visuals** are convincing: dark event horizon, glowing accretion disc, and light bending (gravitational lensing) or a convincing approximation of it.
- **MUST** You **design its mechanics yourself**, using the reference above as inspiration. At minimum: it exerts a gravitational pull on the ship that grows as you approach, the player gets feedback/warnings (HUD, camera effects, sound if you add audio), there is a point of no return, and entering it has a clear gameplay outcome (for example transport to a distant location or another system, with a transition effect). Describe the design and its reasoning in the README.

### 3.5 3D models must come from Blender MCP
- **MUST** All **custom 3D models** are created by you **through the Blender MCP connection on your port (9877)**, in your own `.blend` file, and exported as `.glb`/`.gltf` into the Godot project (for example under `assets/models/`), then used in the game. This includes at minimum: the **player spaceship**, the **astronaut/player character** (or visible first-person equipment), and **several props** such as flora, rocks, landing pad or outpost structures, and other objects that make the planets distinct.
- **MUST NOT** Do not download or import external 3D models or asset packs. Do not use the Blender MCP asset-search/generation integrations (Poly Haven, Sketchfab, Hyper3D/Rodin, Hunyuan3D or similar); model things yourself with Blender operations and scripts.
- Allowed without Blender: procedurally generated planet terrain and meshes, the star, sky, atmosphere, the black hole, particle effects, shaders and UI created in Godot.
- Give models proper materials (and textures if you want), sensible scale and pivots, and make sure the exported models look right in Godot. Keep your `.blend` saved.

### 3.6 Interface and usability
- **MUST** Main menu or a clear start state, in-game HUD (at least speed or status, current location/planet name, and context hints), a pause menu, and a controls overview.
- **MUST** The game starts by running the project (main scene set in `project.godot`), with keyboard and mouse as the default input.

### 3.7 Quality bar
- The game must run without script errors in the output at startup and during normal play, and at a playable frame rate on a typical modern gaming PC.
- Judge your result as a player would: visual variety, feel of the controls, readability of the HUD, and how convincing the planets, the star and the black hole look.

---

## 4. How to work and verify

- Godot's API changed over versions; you are on **4.7.2**. If you are unsure about an API, check the official documentation online or run Godot's CLI to verify, rather than guessing.
- Use the console executable for command-line runs, for example `Godot_..._console.exe --path "<local-path> 5.5 Effort Test\1. Low Effort" ...`. The headless mode does not render, so for visual checks run the game windowed (briefly), save screenshots from the viewport, and look at them.
- Test the real flow yourself: start > fly > approach planet > land > exit ship > walk > return > take off > black hole. Fix every error and every obviously broken thing you find. Do not declare the game finished without running it.
- Work only inside `<local-path> 5.5 Effort Test\1. Low Effort` (plus your Blender instance). Keep the project organised (scenes, scripts, assets, shaders in sensible folders).
- Write a `README.md` in the project folder: how to run the game, controls, what was built, how the planets and the black hole work, known limitations.

---

## 5. Definition of done

The task is complete when all MUST items above are implemented and tested, the game runs from `<local-path> 5.5 Effort Test\1. Low Effort` through Godot 4.7.2, the models were made via Blender MCP and are used in the game, and the README is written.

---

## 6. Rules summary

1. Your port is **9877**, your Blender file is `<local-path> 5.5 Effort Test\1. Low Effort\low_effort.blend`, your folder is `<local-path> 5.5 Effort Test\1. Low Effort`. Do not touch anything that belongs to another agent.
2. All custom 3D models through Blender MCP only. No external models, no model-generation or asset-download integrations.
3. Never kill processes by name; only close what you started.
4. No questions, no approvals, no check-ins; decide, document, and keep going until the project is fully finished.

---

## 7. Final step: time, tokens and cost report

When the game is finished, create `<local-path> 5.5 Effort Test\1. Low Effort\RESULTS.md` and also print the same information in your final message. It must contain:

1. **Time spent**: start time (from section 1), end time, and total elapsed wall-clock time as `HH:MM:SS`.
2. **Tokens used** in this whole task, split into: input tokens (uncached), cache-write (cache creation) tokens, cache-read tokens, and output tokens. Include the work of any subagents you launched. To get accurate numbers, read the `usage` fields from the session transcript `.jsonl` files of this session (and its subagents) under `<local-path>` (find the folder that corresponds to `<local-path> 5.5 Effort Test\1. Low Effort`), and sum them with a small script. Say which files you used. If you cannot get exact numbers, give your best estimate and clearly say it is an estimate and why.
3. **Cost in dollars at API-equivalent prices** for model `claude-sonnet-5-5`: look up the current official Anthropic API prices for this model (input, output, cache write, cache read), state the prices you used and their source, and show the calculation for each token category and the total.
4. A short **self-assessment**: what works, what does not, what you would improve with more time.

The numbers will naturally lag by the few tokens spent on writing the report itself; that is fine, just state it.
