# HORIZON DRIFT - procedural audio (module M8)

Everything you hear is synthesised in code at start-up (no audio files, no external assets). The synthesis runs on a low-priority
background thread (`AudioSoundBank`), the finished `AudioStreamWAV` resources are handed to the mixer as they become ready.
A request for a sound that is not built yet is simply skipped (it never blocks, never errors).

Public API = the autoload `Audio` (`audio/audio_manager.gd`). Every function is safe to call at any time, with any argument.

| call | purpose |
|---|---|
| `Audio.sfx(name, pos := Vector3.INF, volume_db := 0.0)` | one-shot. `pos` is a LOCAL-frame position (3D, `AudioStreamPlayer3D` under `Game.local_root`, in group `frame_objects` so frame shifts move it); `INF` = 2D |
| `Audio.play_sfx(name, pos, volume_db, pitch) -> bool` | same with a pitch multiplier, returns whether a sound really started |
| `Audio.footstep(surface, sprint)` | picks one of 4 variants (never the same twice in a row) of `step_<surface>_<0..3>`; aliases: dirt/gravel/dust -> sand, ice -> snow, ... |
| `Audio.set_engine(throttle 0..1, boost, pulse, atmosphere_density 0..1, speed)` / `stop_engine()` | layered ship engine; call every frame while piloting |
| `Audio.set_loop(name, on, volume)` | continuous layers: `mining_beam`, `jetpack`, `alarm`, `blackhole_rumble`, `warp_tunnel`, `wind` |
| `Audio.set_ambient(biome, wind 0..1, night 0..1, in_space)` | planet ambience bed (the manager also probes the context itself when nobody calls this) |
| `Audio.set_master_volume(v 0..1)` | slider position; perceptual taper `dB = 20*log10(v^2)` (0.5 -> -12 dB, 0.25 -> -24 dB, 0 -> silence). Follows `Game.settings["volume"]` automatically |
| `Audio.duck(db, seconds)`, `set_paused_mix(bool)`, `reset_dynamic()` | ducking engine + ambience, muffled pause mix, stop all continuous layers |
| `Audio.status()`, `Audio.calls`, `Audio.missed`, `Audio.unknown_names` | counters for tests / debugging |

Output is **muted automatically in windowless / headless runs** (the user records video, automated runs must never make noise).
User args: `--audio` keep it audible (and build the sounds), `--audio-build` build the sounds while staying muted, env `HORIZON_AUDIO=1` = `--audio`.
Without any of these a `--no-window` run does not even synthesise the bank (no CPU spent, no counters).

## Architecture

```
audio/
  audio_manager.gd        autoload `Audio`: buses, pools (18 x 2D, 14 x 3D players), API, ducking, master volume, per-frame update
  sound_bank.gd           background-thread synthesis queue (priority order), thread-safe get_stream(), build statistics
  audio_engine_voice.gd   engine = 6 looped layers (rumble, roar, whine, boost, pulse, air rush) mixed from throttle/boost/pulse/density/speed
                          (+ take-off spool-up while landed; falls back to Game.tel / ship state when nobody calls set_engine)
  audio_ambience.gd       biome bed profiles + random one-shots (birds, frogs, ice creaks, geiger ...) around the camera; context probe
  audio_loop_voice.gd     one smoothed looping player (gain / pitch slew, lazy start, stop when silent)
  audio_event_hooks.gd    Events bus -> sounds (so the game sounds alive even if a module forgets a direct call)
  synth/audio_dsp.gd      DSP toolkit (noise, biquad/SVF filters, envelopes, sweeps, bells, Schroeder reverb, loopify, pack/to_stream)
  synth/audio_recipes.gd  catalog: META (bus, level, cooldown, pitch variation), ALIASES, VARIANTS, build order, dispatcher
  synth/recipes_ui.gd  recipes_ship.gd  recipes_engine.gd  recipes_world.gd     the recipes
```

* **Buses**: `SFX` (reverb, wet follows atmosphere density), `UI`, `Engine` (low-pass: dull in space, bright in air), `Ambience` (low-pass
  + -5 dB inside the cabin), all sending to `Master` which carries an `AudioEffectHardLimiter` (ceiling -1 dBFS, nothing can clip).
  Engine and Ambience are ducked by `Audio.duck()` (attack ~70 ms, release ~0.6 s): crash, landing, scan ping, warp, danger toasts, death.
* **Mix balance** (measured with `tests/audio_mix_test.gd`, see below): engine and ambience are beds (about -22 / -27 dBFS RMS at the master),
  UI sounds sit at -10..-17 dBFS peak, gameplay one-shots (landing, pulse, airlock) at -4..-11, footsteps -14, the big events (crash, warp jump,
  black-hole horizon) reach -2 dBFS and the limiter catches stacked worst cases at -1.0 dBFS.
* **Seamless loops**: noise loops are rendered longer and cross-faded onto themselves (`loopify`), tonal loops use integer cycles per loop
  (`snap`); every loop is DC-free and the seam jump is < 6x the average sample step (measured, test enforces < 8x).
* Sounds are deterministic (xorshift noise and `RandomNumberGenerator` seeded from the sound name): the same recipe always renders the same samples.
  Runtime variation (pitch jitter, random one-shot timing, loop start offsets) is audio-only and never touches world seeds.
* **No per-frame allocations** in the hot path (loop voices, engine mixer, ambience updater reuse their dictionaries); the bank is built on a
  worker thread (about 10 s of CPU for 106 sounds / 245 s of audio, nothing on the main thread except the cheap `AudioStreamWAV` hand-over).

## Event wiring (`audio_event_hooks.gd`) and who calls what directly

| source | sound |
|---|---|
| `Events.notify(kind)` | `notify` / `notify_good` / `notify_warn` / `notify_danger` (+duck) / `discover`; suppressed for 0.45 s after a dedicated sound |
| `Events.poi_discovered`, `Events.nav_target_changed` | `discover`, `interact` |
| `Events.game_started / game_paused / returned_to_menu` | `ui_start`, `ui_open`/`ui_back` + muffled pause mix, stop all dynamic layers |
| `Events.player_exited_ship / entered_ship` | `airlock` + `door` |
| `Events.ship_took_off / ship_landed / ship_crashed(sev)` | `takeoff`, `landed` (+duck), `crash` (level and duck scale with severity) |
| `Events.gear_changed / pulse_changed` | `gear_down`/`gear_up`, `pulse_on`/`pulse_off` |
| `Events.atmosphere_entered / left` | `atmo_enter` / `atmo_leave` |
| `Events.resource_collected(id, n)` | `resource_collect` (pitch by resource: ferrite low, zyrite high, voidstone lowest) |
| `Events.scan_pulse`, `Events.player_died`, health drop in `Game.tel` | `scan_ping` (+duck), `death` (+duck), `hurt` |
| `Events.warp_started / warp_finished` | fallback `warp_charge` -> `warp_jump` + `warp_tunnel` loop -> `warp_arrive` (only if `WarpEffect` did not play them itself) |
| `Events.blackhole_warning(level, d)` / `blackhole_entered` | fallback `blackhole_rumble` (0.22 / 0.5 / 0.85 / 1.0), `alarm` at levels 2-3, `warn_beep`, `blackhole_enter` |

Direct calls made by the other modules (all names exist in the catalog; `tests/audio_flow_test.gd` verifies them in the real game):
ship `Audio.set_engine / stop_engine`; player `jump`, `jetpack_puff`, `land_foot`, `Audio.footstep`, `resource_collect`, `scan_ping` (3D at each revealed
marker), `airlock`, `interact`, loops `mining_beam` + `jetpack`, `Audio.set_ambient`; black hole `warn_beep`, `blackhole_enter`, loops `blackhole_rumble` + `alarm`;
warp effect `warp_charge`, `warp_jump`, loop `warp_tunnel`; UI `ui_click`, `ui_open`, `ui_back`, `ui_warp_confirm`, `warn_beep`, `pickup`, `discover`.
Loops driven by another module win: the hooks only act as a fallback when nobody touched the loop during the last 1.5 s.

## Sound list (106 sounds, 245 s of audio, 26 loops)

`bus / level` = default bus and dB offset applied at play time (`AudioRecipes.META`). `sr` = sample rate of the synthesised stream. RMS in dBFS
of the stored stream (stereo = mean of both channels).

### UI (bus UI)
| name | length | description |
|---|---|---|
| `ui_click` (alias click, ui_select, ui_confirm) | 0.11 s | short glassy tick, 44.1 kHz |
| `ui_hover` (alias hover) | 0.06 s | very soft high tick |
| `ui_open` | 0.36 s | rising two-note whoosh for panels / pause |
| `ui_back` (alias ui_close) | 0.28 s | falling counterpart |
| `ui_error` | 0.30 s | low double buzz |
| `ui_warp_confirm` | 2.70 s | charging sweep + chord for the galaxy-map warp button |
| `ui_start` | 4.20 s | game-start swell (sub drop, shimmering chord) |
| `notify`, `notify_good`, `notify_warn`, `notify_danger` | 0.5-1.5 s | toast chimes: neutral bell, rising major pair, double warning, urgent triple |
| `pickup` | 0.40 s | inventory item blip |
| `resource_collect` (alias collect) | 0.90 s | bright crystalline arpeggio, pitch-shifted per resource |
| `discover` | 3.60 s | slow bell stack with shimmer (POI found) |
| `interact` (alias nav_set) | 0.28 s | soft two-tone confirm |
| `warn_beep` (alias warn, alert) | 0.42 s | sharp double beep (black-hole levels, invalid warp) |

### Ship (buses SFX / Engine)
| name | length | description |
|---|---|---|
| `eng_rumble` loop | 3.0 s | brown noise + sub-harmonics of a 42 Hz firing rate with slow throb (16 kHz) |
| `eng_roar` loop | 3.0 s | band-limited pink noise with flutter (exhaust) |
| `eng_whine` loop | 2.0 s | exactly periodic turbine tone with harmonics |
| `eng_boost` loop | 2.0 s | high band noise chopped at 80 Hz + buzzy tone (boost scream) |
| `eng_pulse` loop | 4.0 s | deep tones, throb, shimmering noise (pulse-drive cruise hum) |
| `eng_wind` loop | 3.0 s | air rushing past the hull (grows with speed x density) |
| `alarm` loop (bus UI) | 1.6 s | two-tone siren (black hole levels 2-3) |
| `gear_down`, `gear_up` | 1.9 / 1.8 s | servo whirr + clunk, 3D |
| `landed` | 2.2 s | thud, hydraulic settle, dust hiss, 3D |
| `crash` | 3.4 s | impact boom, metal debris, creaks |
| `takeoff` | 3.4 s | ignition, climbing roar, whoosh |
| `atmo_enter`, `atmo_leave` | 3.6 / 2.4 s | air rushing in with heat roar / fading out |
| `pulse_on`, `pulse_off` | 2.6 / 1.6 s | charge whine -> sub thump + shimmer; spin-down |
| `airlock`, `door` | 2.4 / 1.0 s | pressure hiss + seal clunks; door slide |
| `scan_ping` | 4.4 s | sonar ping with echo tail |
| `warp_charge` | 2.4 s | rising whine + sub swell |
| `warp_jump` | 3.0 s | detonating sweep, sub boom |
| `warp_tunnel` loop | 4.0 s | tunnel whoosh with beating tones |
| `warp_arrive` | 2.4 s | exit flash: falling sweep + shimmer |
| `blackhole_enter` | 6.0 s | horizon crossing: sub drone, stretched falling tones, white-out |
| `blackhole_rumble` loop | 6.0 s | 31 Hz-centred rumble with slow beating (16 kHz) |

### On foot (bus SFX)
| name | length | description |
|---|---|---|
| `step_<surface>_<0..3>` | 0.34 s | surfaces: `grass`, `sand`, `rock`, `snow`, `metal`, `ash`, `mud`, `splash` (4 variants each; aliases for dirt, gravel, dust, ice, water, regolith ...) |
| `jump`, `land_foot`, `jetpack_puff` | 0.45 / 0.45 / 0.5 s | suit push, boot thud, gas puff |
| `jetpack` loop | 1.6 s | wide hissing roar with low body |
| `mining_beam` loop | 2.0 s | electric hum with warble, buzz and sizzle |
| `hurt`, `death` | 0.5 / 2.2 s | impact grunt thump, flat-line decay |

### Ambience (bus Ambience; beds are mixed per biome from these loops by `audio_ambience.gd`)
| name | length | description |
|---|---|---|
| `amb_space` | 16 s | deep drone with slow beating (menu + space + very faint on foot) |
| `amb_suit` | 4 s | life-support hum + breathing (on foot) |
| `amb_wind_low`, `amb_wind_mid`, `amb_howl` | 8 s | wind: rumble / body / whistling howl, stereo, gusting |
| `amb_rustle` | 6 s | leaves / grass |
| `amb_crickets` | 4 s | night insects |
| `amb_rumble`, `amb_crackle` | 8 / 6 s | volcanic sub rumble, lava crackle |
| `amb_bubbles`, `amb_toxic` | 6 / 8 s | acid bubbling, toxic drone |
| `amb_waves` | 12 s | surf |
| `amb_crystal`, `amb_hum` | 12 / 6 s | exotic chime field, radioactive / machine hum |
| `amb_rain` | 6 s | rain (when the weather module reports rain on lush / ocean / swamp) |
| one-shots around the camera | 0.1-4.5 s | `bird_0..2`, `frog_0..1`, `ice_creak`, `geiger_tick` (rate follows `def.radiation`), `spore_pop`, `crystal_chime`, `wind_gust`, `thunder_far` |

Biome profiles (`audio_ambience.gd PROFILES`): lush = wind + rustle + birds by day / crickets + frogs at night, desert = strong wind + howl,
frozen = howl + ice creaks + far chimes, volcanic = rumble + crackle + gusts, toxic = drone + bubbles + spore pops, barren = silence (only suit hum),
ocean = surf + wind + gulls, exotic = crystal field + hum + chimes, swamp / radioactive / gas = their own mixes. `in_space` = faint drone only.

## Tests (all windowless; use `--audio-driver Dummy` so even an unmuted master bus cannot make sound)

```
godot.ps1 -Project <sandbox> -Mode run -TimeoutSec 170 -Tag audio    -GodotArgs "--audio-driver Dummy --resolution 640x360 -- --autostart --preset=air:1:900 --audio-build --test=res://tests/audio_test.gd"
godot.ps1 -Project <sandbox> -Mode run -TimeoutSec 300 -Tag mix      -GodotArgs "--audio-driver Dummy --resolution 640x360 -- --autostart --preset=air:1:900 --audio-build --test=res://tests/audio_mix_test.gd"
godot.ps1 -Project <sandbox> -Mode run -TimeoutSec 420 -Tag flow     -GodotArgs "--audio-driver Dummy --resolution 640x360 -- --autostart --preset=landed:1 --audio-build --test=res://tests/audio_flow_test.gd"
godot.ps1 -Project <sandbox> -Mode run -Script res://tests/audio_dump.gd -TimeoutSec 200 -GodotArgs "--"     # WAVs to .previews/audio, then: python tests/audio_analyze.py .previews/audio .previews/audio_sheets
```
* `audio_test.gd` - synthesises every sound, checks duration, peak < 1, RMS, DC, NaN, loop seams, API robustness (nonsense names / arguments), engine / ambience
  layer reactions, every Events hook, master taper.
* `audio_mix_test.gd` - real mixer: per-bus true peak + RMS (capture effects), every one-shot over a bed, loops, scenes, ducking, taper, limiter worst case.
* `audio_flow_test.gd` - the real game: take-off with spool-up, flight + boost, landing + gear, exit, footsteps, jump, jetpack, scan, mining, pickup, re-enter,
  pulse drive on/off, hyperdrive warp, black-hole dive (warning levels, rumble, alarm, horizon, warp) and checks the counters.
* `audio_dump.gd` + `audio_analyze.py` - WAV export, spectrogram sheets, level / DC / seam table.
