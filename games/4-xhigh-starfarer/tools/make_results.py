import datetime as dt
import json
import subprocess
import sys

root = r"W:\YouTube\Sonnet 5.5 Effort Test\4. Xhigh Effort"
tz = dt.timezone(dt.timedelta(hours=1))
start = dt.datetime(2026, 10, 31, 11, 6, 40, tzinfo=tz)          # from .timing/start.txt
end = dt.datetime.now(tz).replace(microsecond=0)
pause_start = dt.datetime(2026, 10, 31, 12, 30, 49, tzinfo=tz)   # user paused the session (file timestamp of the pause note)
pause_end = dt.datetime(2026, 10, 31, 13, 20, 30, tzinfo=tz)     # user wrote "continue" (first output written after the pause: 13:20:43)


def hms(td):
    s = int(td.total_seconds())
    return "%02d:%02d:%02d" % (s // 3600, (s % 3600) // 60, s % 60)


elapsed = end - start
pause = pause_end - pause_start
active = elapsed - pause

out = subprocess.run([sys.executable, root + r"\tools\token_report.py"], capture_output=True, text=True).stdout
t = json.loads(out)
P_IN, P_CW5, P_CW1, P_CR, P_OUT = 2.0, 2.5, 4.0, 0.10, 10.0
c_in = t["input_uncached"] * P_IN / 1e6
c_cw5 = t["cache_write_5m"] * P_CW5 / 1e6
c_cw1 = t["cache_write_1h"] * P_CW1 / 1e6
c_cr = t["cache_read"] * P_CR / 1e6
c_out = t["output"] * P_OUT / 1e6
total = c_in + c_cw5 + c_cw1 + c_cr + c_out
tot_tokens = t["input_uncached"] + t["cache_write_total"] + t["cache_read"] + t["output"]

md = f"""# RESULTS — Sonnet 5.5, **Xhigh** effort

Project: STARFARER (No Man's Sky–style space exploration game, Godot 4.7.2). Blender MCP port 9880, file `xhigh_effort.blend`.

## 1. Time spent

| | |
|---|---|
| Start (from `.timing/start.txt`) | 2026-10-31 {start:%H:%M:%S} (+01:00)  (UTC 10:06:40) |
| End | 2026-10-31 {end:%H:%M:%S} (+01:00) |
| **Total elapsed wall-clock** | **{hms(elapsed)}** |
| of which paused by the user | ≈ {hms(pause)} (session stopped at {pause_start:%H:%M:%S}, resumed ≈ {pause_end:%H:%M:%S}; the user was recording a video and asked me to stop) |
| Active working time (elapsed − pause) | ≈ {hms(active)} |

The pause window is derived from file timestamps (pause note written 12:30:49, first output after "continue" 13:20:43), so it is accurate to about a minute.

## 2. Tokens used (whole task, no subagents were launched)

Source: `C:\\Users\\Cryptopiy\\.claude\\projects\\W--YouTube-Sonnet-5-5-Effort-Test-4--Xhigh-Effort\\0b521e80-0d27-491a-8587-83e0aa2f70ce.jsonl`
(the only transcript file of this project folder; there is no subagent transcript). Script: `tools/token_report.py` — sums `message.usage` of all
`assistant` records, de-duplicated by message id (a response is logged several times while streaming; the record with the largest usage wins).
{t["api_responses"]} distinct API responses, all by `claude-sonnet-5-5`.

| Category | Tokens |
|---|---:|
| Input (uncached) | {t["input_uncached"]:,} |
| Cache write (cache creation) — 5-minute tier | {t["cache_write_5m"]:,} |
| Cache write (cache creation) — 1-hour tier | {t["cache_write_1h"]:,} |
| Cache read | {t["cache_read"]:,} |
| Output | {t["output"]:,} |
| **Total** | **{tot_tokens:,}** |

These are exact transcript numbers at the moment this file was generated; the few tokens spent afterwards (writing this report, the final message) are not included.
Cache-read volume is large because the conversation context was long (hundreds of thousands of tokens re-read on every turn).

## 3. Cost at API-equivalent prices (`claude-sonnet-5-5`)

Prices (USD per million tokens), from the official pricing page <https://platform.claude.com/docs/en/about-claude/pricing> (fetched {end:%Y-%m-%d}):
base input **$2**, 5-minute cache write **$2.50**, 1-hour cache write **$4**, cache read/hit **$0.10** (0.05× base), output **$10**.
Standard pricing applies to the whole context window (no long-context surcharge for this model).

| Category | Tokens | Price / MTok | Cost |
|---|---:|---:|---:|
| Input (uncached) | {t["input_uncached"]:,} | $2.00 | ${c_in:.4f} |
| Cache write 5 m | {t["cache_write_5m"]:,} | $2.50 | ${c_cw5:.4f} |
| Cache write 1 h | {t["cache_write_1h"]:,} | $4.00 | ${c_cw1:.4f} |
| Cache read | {t["cache_read"]:,} | $0.10 | ${c_cr:.4f} |
| Output | {t["output"]:,} | $10.00 | ${c_out:.4f} |
| **Total** | | | **${total:.2f}** |

Calculation: {t["input_uncached"]:,}×2/1e6 + {t["cache_write_1h"]:,}×4/1e6 + {t["cache_read"]:,}×0.10/1e6 + {t["output"]:,}×10/1e6 = ${total:.4f}.

## 4. Self-assessment

**What works (all verified by scripted runs and screenshots, see `docs/screenshots/` and README "Testing")**
* Complete core loop with no loading screens: start → fly (throttle/boost/pulse drive) → approach a planet → atmospheric entry (plasma, heat, shake) → landing mode with automatic
  descent and touchdown detection → exit the ship → walk/sprint/jump/jetpack/swim → mine resources, scan, use outposts/monoliths/wrecks → board → take off → leave the atmosphere →
  pulse to another planet, the orbital station, the asteroid belt (collisions) or the black hole.
* Seven clearly different landable biomes in the home system (+ gas giant with rings), each with its own terrain shape, palette, sky, atmosphere, liquid, flora, weather, hazard and gravity;
  fully seed-determined; GPU terrain whose heights match the CPU collision function to ≤ 1.5 cm; no visible jitter on a planet moving at 265 m/s (0.2 mm); ~140 fps average on the test machine.
* A 420-star galaxy with a 3D map and hyperdrive to other, differently generated systems; black holes link systems ~7,000 ly apart.
* A convincing black hole (ray-marched Schwarzschild lensing, accretion disc with Doppler beaming, photon ring) with a designed gameplay arc: warnings → pulse lock → pull → point of no return
  → transit → arrival (escape verified with boost, fall-in verified); full HUD, menus, controls overview, pause, settings, procedural audio.
* 38 models made through the Blender MCP only (no downloaded assets).

**What does not / limitations**
* I could not do a visible, interactive play-through: the user was recording video, so all runs used an invisible off-screen viewport and injected inputs (the polling-based input path and every
  gameplay function were exercised; the normal start-up path was also smoke-tested headlessly with no script errors). Mouse-capture behaviour and OS-level key events in a real window are therefore untested.
* No docking, no ship interior, no crafting/trading, wildlife is ambient only, props are not solid for the ship, no geomorphing in the terrain LOD (small pops), no underwater view,
  single-scattering atmosphere, clouds cast no shadows, planets are compressed in scale (km, not thousands of km).
* Ground detail is stylised low-poly + procedural grain; there are no photographic textures. Terrain palettes are tuned but not art-directed per region.

**What I would improve with more time**
* Interactive tuning with real mouse/keyboard feel (camera lag, landing assist), more points of interest (caves, abandoned bases, space encounters), station docking and ship interior.
* Terrain LOD geomorphing, impostor trees for long view distances, cloud shadows and god rays, underwater rendering, rivers/erosion, better biome transitions, texture-based ground detail.
* Save/load, an inventory/crafting loop that gates the hyperdrive, performance scaling options for weaker GPUs, and a proper audio pass with authored sounds/music.
"""
open(root + r"\RESULTS.md", "w", encoding="utf-8").write(md)
print(md[:2600])
