# Black holes & hyperspace (module M5)

Files: `world/blackhole/black_hole.gd` (visual node + mechanics), `world/blackhole/warp_effect.gd` (tunnel / white-out overlay),
`shaders/blackhole_lens.gdshader`, `shaders/blackhole_post.gdshader`, `shaders/warp_tunnel.gdshader`, `core/blackhole_params.gd` (every number),
tests `tests/bh_*.gd`.

The game has two ways to leave the current star system, and both end in the same overlay:

| way | cost | what you see | arrival |
|---|---|---|---|
| **Black hole** ("Charon's Gate" in Aurelia, "Return Gate" in Kepler's Rest, ~10 % of the other systems) | free, but you have to fly into the singularity | lensed sky, accretion disc, the pull, a red tunnel, a warm white-out | next to the destination system's own singularity, ejected outward at 500 m/s |
| **Hyperdrive** (galaxy map `M` -> WARP, `Game.try_hyperdrive(id)`) | warp cells (`1 + ly/6000`) | blue-white star-streak tunnel, white flash | 2.2 capture radii from the destination's arrival planet |

## 1. Visuals

### 1.1 Lensing quad (`blackhole_lens.gdshader`)
A child `MeshInstance3D` of the BlackHole node: a 2x2 `QuadMesh` whose vertex shader writes `POSITION = vec4(VERTEX.xy, 1.0, 1.0)`, i.e. a full-screen
quad drawn in front of everything (`unshaded, depth_test_disabled`, `render_priority = -100`, huge `custom_aabb` so it is never frustum-culled). Everything
is derived from the built-in matrices at draw time (`MODEL_MATRIX[3]` = singularity, `INV_VIEW_MATRIX[3]` = camera), so there are **no stale uniforms
while Frame re-bases the world** (the ship moves, the node transform is rewritten by Frame every frame, the shader never notices).

For each pixel the shader builds the view ray and works in BH-local space in units of the Schwarzschild radius (`rs = 1`):

* **Light path.** `trace()` integrates the null geodesic with the Binet acceleration `a = -1.5 h^2 pos / |pos|^5` (`h = |pos x vel|` conserved). That
  reproduces the Schwarzschild photon sphere (1.5 rs) and shadow radius (2.6 rs). Step length `0.065 r` (clamped 0.015..60 rs), at most 224 steps
  (`max_steps_u` uniform), early out when the ray has fallen in, left the disc region, or became opaque.
* **Event horizon.** rays with `r < 1` are captured: pure black (alpha 1, no background). Inside the horizon the whole quad is black.
* **Accretion disc.** a thin disc with tilt (`_build_disc_orientation`: seen from ~10-18 degrees above the plane when approaching from the star side, so you
  get the Interstellar look: the far side of the disc is lensed over the top and under the bottom). Plane crossings add emission and absorb light.
  Colour from a black-body ramp (hot inner white-yellow -> orange -> deep red), Kepler angular speed (inner parts rotate faster), two cross-faded noise
  phases so the pattern never "pops", noise octaves fade by pixel footprint (no shimmering from far away), **relativistic beaming + gravitational
  redshift** (one side brighter and bluer: `g = dop * grav`, brightness ~ `g^2`), an optically-thin gas haze around the plane, and extra jittered rays
  (3) on pixels that hug the photon sphere for clean edges (`aa_k`).
* **Photon ring.** rays that linger near r = 1.5 accumulate a thin warm glow (only on escaping rays: it appears right at the shadow edge).
* **Lensed sky.** an escaping ray gets its asymptotic direction from `residual_deflect` (weak-field closed form for the remaining path), is projected back
  to the screen, and samples `hint_screen_texture` there (mip-level from the derivative so the star field does not alias). Directions that leave the screen
  fall back to a procedural star field; the foreground (ship, planets) is protected with the depth texture: an opaque object nearer than the hole is never
  distorted and never smeared into the lensed image.
* **Far field.** beyond `B_HI` impact parameters the cheap analytic deflection `2 rs / b` is used; both are cross-faded, and the deflection is windowed to
  zero at `INFLUENCE` (420 km) so there is no visible boundary of the effect.
* **Findable from far away.** beyond 260 km (fully at 1000 km) the shader adds an "ember halo": a tight bright core (the disc seen from afar) plus a wide
  faint corona (angular radius `0.85 * disc_outer / distance`, x3.6 for the corona). In Aurelia the hole is ~2900 km from the home planet: from there
  it is a small orange ember with a dark centre, ringed by warped stars, with the HUD marker (M6) on top.
* **Shock ring.** the destination hole plays an expanding "white hole" ring (`shock_t`) when a ship has just come out of it (starts when the white-out
  dissolves, not while it hides the screen).

### 1.2 Near-field post effect (`blackhole_post.gdshader`)
A `CanvasLayer` (layer 2: above the 3D view, **below** the HUD on layer 10 and the warp overlay on 20, so the UI is never distorted) with a full-rect
`ColorRect` shader: chromatic aberration, vignette, FOV stretch that grows toward the edges, a red-shift tint, and in the last 9 km a radial streak
toward the singularity (the sky collapsing into the ring). The shader parameters `near_k`, `fall_k`, `tint_k` come from the distance in
`black_hole.gd`; `bh_uv` (the singularity's screen position) is computed in `RenderingServer.frame_pre_draw` so it is exact for the frame being drawn.
It is hidden entirely (`visible = false`) when the effect is ~0.

### 1.3 Performance (measured with `tests/bh_perf.gd`, RTX 5070, 1280x720)
| distance | lens cost (GPU) |
|---|---|
| 400 km | 0.3 ms |
| 150 km | 0.4 ms |
| 45 km | 0.8 ms |
| 15 km (worst: whole screen is bent light, disc fills it) | 2.1 ms |
| 5 km | 0.6 ms |

The cost scales with pixels, so at 1080p expect <= ~4.7 ms in the worst spot (budget 6 ms). The quad is hidden when the hole is outside the view cone
and farther than the influence radius. `max_steps_u` and `aa_k` are the quality knobs. The black hole script itself costs ~0.05 ms CPU per frame.

**Frame re-basing.** `tests/bh_perf.gd` flies past the hole at 20 km/s: 105 rebases in 14 s, and `|BlackHole.global_position - Frame.to_local(abs)|`
stays 0.0000 m. The swept horizon test keeps the previous *local* ship position, so `black_hole.gd` follows `Frame.origin_shifted` (adds the shift)
and drops it on `frame_changed`: a rebase can never fake or hide a crossing.

## 2. Mechanics

`MU = 6e10`, `a(r) = MU / r^2` toward the singularity, applied through the ship contract (`ship.external_accel`, local frame; Frame rotates it on frame
switches). All numbers live in `core/blackhole_params.gd`.

| zone | radius | acceleration | what happens |
|---|---|---|---|
| influence | 420 km | 0.34 m/s^2 | lensing quad active, pull starts, the gravity well interdicts too-fast pulse runs |
| **WARN** (level 1) | 300 km | 0.67 | toast "Gravitational anomaly ahead", rumble loop, tiny shake |
| **DANGER** (level 2) | 120 km | 4.2 | toast "pulse drive offline", `pulse_locked`, shake grows, control authority starts to fade, red-shift tint, HUD panel |
| **POINT OF NO RETURN** (level 3) | 22 km | 124 | alarm loop, toast + hint "POINT OF NO RETURN", the capture field takes over |
| **HORIZON** (level 4) | `1.05 * RS` = 2.1 km | 13 600 | `Events.blackhole_entered`, `Game.warp_to_system(def.bh_dest_system, "blackhole")` |

`Events.blackhole_warning(level, distance)` is emitted when the level changes and then every 0.25 s while the level is > 0; `Game.tel` gets `bh_dist`,
`bh_level`, `bh_pull`. Hysteresis (4 %) stops the level flickering at a boundary.

**Why these numbers.** The ship's full-boost thrust is ~150-200 m/s^2 (`ACC_BOOST` 520 x 0.4 while a pull is active, x control authority). The pull
reaches that at `r = sqrt(MU / 150)` = 20 km, so the point of no return is placed at 22 km: before it a pilot who turns round immediately can fly away
(the escape test confirms it), after it nothing the ship can do beats the pull. 120 km is where 4 m/s^2 starts to be felt on the speed readout and 300 km
is early enough to react at boost speed (1.2 km/s = 4 minutes of flying from the warning to the horizon).

**Pulse drive.** The pulse drive is dropped by the gravity well: inside the influence radius an inbound speed above 80 % of the safe limit
`v_cap = 300 + sqrt(2 * 60 * (r - 1.3 PONR))` (the speed a ship braking at 60 m/s^2 can still shed before the point of no return) sets `pulse_locked`, so the
ship drops out of pulse ("gravity well interference") and the excess speed is shed by the ship's own pulse-exit. Inside DANGER the lock is
unconditional. A player pulsing in from 2000 km therefore drops out at the edge of the well (~420 km) and finishes the approach under impulse/boost.
Over-fast boost runs are slowed by an interdiction field (`INTERDICT_GAIN`) with a toast ("Gravity well interdiction").

**Control fade.** `control_authority` 1.0 at DANGER -> 0.8 at the PONR -> 0.12 at the horizon; `extra_shake` 0.04 -> 0.32 -> 1.0.

**Capture field (inside the PONR).** `acc += dir * (v_free - v_in) * CAPTURE_RATE * capture` drives the inbound speed toward the free-fall speed (so
thrusting does not help) and `DISC_DRAG` bleeds tangential speed (orbits decay: nothing circles forever). Combined with the swept horizon test a ship
cannot tunnel through the horizon at any speed (even 40 km/s).

**Horizon crossing.** `captured = true`, level 4, `Events.blackhole_entered`, audio hit, and `Game.warp_to_system(def.bh_dest_system, "blackhole")`.
During the last 9 km `fall_k` rises (post effect: radial streak, vignette, red tint), then WarpEffect covers the screen with the red vortex and the
warm white-out. While the transition runs (`Game.mode == WARP`) all contract fields are reset and the warnings are 0.

**Arrival.** `Game` places the ship `SPAWN_DISTANCE` = 140 km from the destination singularity on the star side, heading away from it at
`ARRIVAL_ENTRY_SPEED` = 500 m/s. The new BlackHole node sees `Game.warping` + `warp_fx.last_kind == "blackhole"` and enters *arrival mode*:
the pull is zero for 5 s and fades in until 28 s (`ARRIVAL_GRACE`); the ejection speed is *held* and coasts down quadratically to 0 over
`ARRIVAL_EJECT_TIME` = 8 s (without this the ship's flight assist would eat the 500 m/s in about two seconds and the ejection would be invisible);
the shock ring plays. The timers wait until the white-out is over.

**Escaping.** Before the PONR: reverse + boost. After it: impossible, by design. Back through the Return Gate gets you home (`black_hole_destination`
is symmetric for the two hand-made systems; the other holes lead ~7000 ly toward the centre).

**Note on `_ref_vel`.** The ship's flight assist measures its velocity relative to nearby planets (`_ref_vel`): near a planet the ship drifts with that planet's
orbital velocity (hundreds of m/s), so a straight "point the nose at the hole" approach in a busy system arrives with a lateral miss of tens of km.
That is what the HUD velocity marker / the player's steering are for (the e2e test aims with `heading * speed - ref_vel`).

## 3. WarpEffect (`warp_effect.gd`, `warp_tunnel.gdshader`)

`Control` full-rect on the Overlay layer (20, `PROCESS_MODE_ALWAYS` so it keeps running under a paused tree). One `ColorRect` with the tunnel shader. API used
by `Game.warp_to_system`: `await play_out(kind)` (covers the screen in ~2 s: the scene is zoom-blurred toward the centre while star streaks fly out
and the tunnel walls fade in, then a flash; returns when the screen is completely covered, so the world can be swapped) and `await play_in(kind)`
(arrival flash dissolving into the new scene in ~1.5-1.9 s). Kinds: `hyperdrive` = blue-white straight streaks, `blackhole` = red/orange spiral vortex
ending in a warm white-out. Extras: `is_playing()`, `last_kind`, `show_progress(p)` (manual drive), `reveal_count` (watchdog rescues).

**The screen can never stay covered.** The overlay is opaque, so a warp that dies after `play_out` would leave the game white forever. A watchdog in
`_process` (time clamped per frame, so a long blocking system build counts as one frame) releases the screen when
* the overlay is fully opaque, nothing animates and `Game.warping` is still true after 12 s (the arrival never came), or
* it is opaque and `Game.warping` is *false* after 1.5 s (nobody owns the overlay any more);

it then fades the world back in (0.9 s) and logs a warning. As a very last resort, if `Game.warping` is still stuck 30 s after a rescue it is released
so the player is not left frozen (tested by `tests/bh_hyper.gd --watchdog=1`).

## 4. Tests (all windowless via `tools/godot.ps1`; keep them short, one at a time)

| test | what it proves |
|---|---|
| `bh_e2e.gd` | real ship + real input: 400 km approach with a pulse attempt, every warning level + HUD toast, pulse lock, authority/shake, PONR, horizon, white-out, arrival at the Return Gate (140 km, ejected at 500 m/s coasting down), flying back to Aurelia, overlay released |
| `bh_perf.gd` | lens GPU cost at 400/150/45/15/5 km; singularity stays glued to its absolute position across 100+ Frame rebases at 20 km/s |
| `bh_hyper.gd` | `Game.try_hyperdrive` refusals, galaxy-map WARP button -> tunnel -> arrival, cell bookkeeping, "already charging", back jump, the watchdog |
| `bh_fly.gd` | scenarios `dive`, `escape` (45 km out, thrust away: gets out), `trap` (17 km, inside the PONR: captured anyway), `pulse` |
| `bh_far.gd` | screenshots of the hole from the home planet / 2000 / 1000 / 600 km |
| `bh_shots.gd`, `bh_warp.gd` | visual sheets of the hole at several distances/angles; tunnel frames over time |

Run the e2e test with `--timescale=1.5` (with the 30 fps cap that is exactly `dt = 0.05`, the gameplay clamp).

## 5. Known limits
* The lens samples the already-rendered frame, so lensed images of things outside the screen come from the procedural star fallback, and a bright
  planet that is behind the hole is only lensed while it is on screen.
* One black hole per system (the Universe generator guarantees it); several simultaneous lens quads would each cost a full-screen pass.
* Distances inside the horizon (< 2 km) are only reachable for a few frames: the transition starts at 1.05 RS by design.
