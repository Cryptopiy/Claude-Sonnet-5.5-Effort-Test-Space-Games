"""Generate RESULTS.md (time, tokens, cost, self-assessment).  python tools/make_results.py"""
import datetime
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import usage_report as U

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
start = datetime.datetime(2026, 10, 31, 11, 7, 58)       # .timing/start.txt (local, +01:00)
end = datetime.datetime.now().replace(microsecond=0)


def hms(td):
    s = int(td.total_seconds())
    return "%02d:%02d:%02d" % (s // 3600, (s % 3600) // 60, s % 60)


def at(h, m, s):
    return datetime.datetime(2026, 10, 31, h, m, s)


intervals = [
    ("user asked to pause, resumed on request", at(12, 33, 6), at(13, 20, 30)),
    ("PC hard freeze #1 (last good 13:59:43) until session resumed", at(13, 59, 43), at(14, 16, 2)),
    ("PC hard freeze #2 (last good 14:53:41) until session resumed", at(14, 53, 41), at(15, 19, 37)),
    ("PC hard freeze #3 (last good 15:55:17) until session resumed", at(15, 55, 17), at(16, 18, 6)),
    ("work stopped after the freezes, waiting for the user to say continue (wrap-up delivered 16:30)", at(16, 30, 5), at(21, 27, 26)),
]
gross = end - start
lost = sum((b - a for _, a, b in intervals), datetime.timedelta())
active = gross - lost

files, totals, per_file, n = U.scan()
P_IN, P_W1H, P_W5M, P_READ, P_OUT = 2.0, 4.0, 2.5, 0.10, 10.0
cin = totals["input_tokens"] / 1e6 * P_IN
cw = totals["cache_creation_input_tokens"] / 1e6 * P_W1H
cw5 = totals["cache_creation_input_tokens"] / 1e6 * P_W5M
cr = totals["cache_read_input_tokens"] / 1e6 * P_READ
co = totals["output_tokens"] / 1e6 * P_OUT
total = cin + cw + cr + co
total5 = cin + cw5 + cr + co

lines = []
a = lines.append
a("# RESULTS - Horizon Drift (effort label: **Ultracode**)")
a("")
a("Project: `W:\\YouTube\\Sonnet 5.5 Effort Test\\6. Ultracode Effort`  |  Model: `claude-sonnet-5-5`  |  Blender MCP port 9882")
a("")
a("## 1. Time spent")
a("")
a("| | |")
a("|---|---|")
a("| Start (local, from `.timing/start.txt`) | 2026-10-31 11:07:58 (+01:00)  =  10:07:58 UTC |")
a("| End (local) | %s |" % end.strftime("%Y-%m-%d %H:%M:%S"))
a("| **Total elapsed wall-clock** | **%s** |" % hms(gross))
a("| of which the machine was down / work was paused | %s |" % hms(lost))
a("| Net working time (elapsed minus pauses and freezes) | %s |" % hms(active))
a("")
a("Pauses/freezes excluded in the net figure:")
a("")
for name, x, y in intervals:
    a("* %s - %s: %s (%s)" % (x.strftime("%H:%M:%S"), y.strftime("%H:%M:%S"), name, hms(y - x)))
a("")
a("The work was stopped by the user after the third freeze (16:30), then continued at the user's request at 21:27 with strict GPU-safety rules (render only one process at a time, low resolution, temperature guard, agents headless-only).")
a("")
a("## 2. Tokens used (whole task, main session + all subagent / workflow-agent transcripts)")
a("")
a("| category | tokens |")
a("|---|---:|")
a("| input (uncached) | %s |" % format(totals["input_tokens"], ","))
a("| cache write (cache creation) | %s |" % format(totals["cache_creation_input_tokens"], ","))
a("| cache read | %s |" % format(totals["cache_read_input_tokens"], ","))
a("| output | %s |" % format(totals["output_tokens"], ","))
a("| **total** | **%s** |" % format(sum(totals.values()), ","))
a("")
a("Source: `python tools/usage_report.py` over every `*.jsonl` under `C:\\Users\\Cryptopiy\\.claude\\projects\\W--YouTube-Sonnet-5-5-Effort-Test-6--Ultracode-Effort\\` "
  "(the main session transcript `690a5c47-4f87-4ed6-b3a6-0d44b4e96c40.jsonl` and everything in its `subagents\\` and `subagents\\workflows\\wf_*\\` folders): "
  "%d transcript files, %d unique API messages. Each API message appears several times in a transcript (one line per content block, usage updated while streaming), "
  "so the script de-duplicates by `message.id` and takes the maximum of every counter. The numbers lag by the few tokens spent writing this report. "
  "Agents that were killed by the crashes had their usage logged up to the moment they stopped. Other agents' sessions (other effort levels) live in different "
  "folders and are not included." % (len(files), n))
a("")
a("## 3. Cost at API-equivalent prices (`claude-sonnet-5-5`)")
a("")
a("Prices (USD per million tokens), source: https://platform.claude.com/docs/en/about-claude/pricing (row *Claude Sonnet 5.5*, read 2026-10-31): "
  "base input **$2**, 5-minute cache write **$2.50**, 1-hour cache write **$4**, cache hits **$0.10** (0.05x base), output **$10**. "
  "This session's requests use the 1-hour cache TTL (stated by the harness), so cache writes are priced at $4.")
a("")
a("| category | tokens | price / MTok | cost |")
a("|---|---:|---:|---:|")
a("| input (uncached) | %s | $%.2f | $%.2f |" % (format(totals["input_tokens"], ","), P_IN, cin))
a("| cache write (1 h) | %s | $%.2f | $%.2f |" % (format(totals["cache_creation_input_tokens"], ","), P_W1H, cw))
a("| cache read | %s | $%.2f | $%.2f |" % (format(totals["cache_read_input_tokens"], ","), P_READ, cr))
a("| output | %s | $%.2f | $%.2f |" % (format(totals["output_tokens"], ","), P_OUT, co))
a("| **total** | | | **$%.2f** |" % total)
a("")
a("Calculation: tokens / 1,000,000 x price, per category, summed. If all cache writes were billed at the 5-minute price ($2.50) the total would be $%.2f." % total5)
a("")
a("## 4. Self-assessment")
a("")
a("**What works (verified):**")
a("")
a("* A complete, runnable game (`run/main_scene` set; main menu -> start). Headless end-to-end test `tests/final_flow_headless.gd` passes 17/17: start on the landing pad of Verdant, exit the ship, walk on the spherical planet, re-enter, take off, floating-origin space frame, capture into the planet's frame while flying in, "
  "black-hole warnings up to the point of no return, transport to *Kepler's Rest* (11 bodies, 8 landable, 5 biomes) arriving ~141 km from its gate, hyperdrive back to *Aurelia* (9 bodies, 7 landable, 7 biomes).")
a("* Headless feature sweep `tests/final_features_headless.gd` passes (overlays, pause/resume, camera and gear toggles, hard dive into the ground with hull damage, gas-giant pressure barrier, scanner, terminal interaction, mining (inventory 0 -> 6), death/emergency respawn, quit to menu and a fresh game) with **0 script errors**.")
a("* Screenshots of the final build (`docs/screenshots/`): polished UI (main menu with spiral galaxy, pause, settings, controls manual, galaxy map, system map, inventory, HUD), seven biomes at ground level with flora and distinct skies, "
  "planets from orbit with atmosphere rim, ringed gas giant, star with corona, black hole with lensing + warnings, atmospheric-entry heat shell, first-person view on the pad.")
a("* 92 Blender-MCP models used in game; 10 biome terrain profiles; procedural galaxy of 720 stars; synthesized audio bank (muted in headless runs by design); GPU-safe tooling (`tools/godot.ps1`).")
a("")
a("**What does not / is unverified:**")
a("")
a("* No human play-test: flight/jetpack feel is tuned by scripts and screenshots only; audio was analysed numerically, never listened to; no long windowed performance run (render tests were capped at 20 fps / 1024x576 for GPU safety; module tests measured the black-hole lens at ~2 ms worst case at 720p).")
a("* Art left to polish: exotic and toxic biomes are very saturated, gas giant small from long range, clouds/ocean checked from few angles. Swamp/radioactive got less tuning. The `.blend` was last saved before the final model reviews finished (the generator scripts in `blender/` and the exported `.glb` files are authoritative).")
a("* Three hard system freezes (GPU driver timeouts, Windows events 117/141) happened during parallel Godot/Blender rendering; the cause is not proven (my parallel test load is the prime suspect, other sessions share the GPU). About 1 h 05 min was lost to them.")
a("")
a("**With more time:** a real play-through + profiling on the target GPU, tune flight/jetpack feel, listen to and mix the audio, tone down exotic/toxic colours, more landmarks per planet, finish swamp/radioactive, re-run the Blender reviews so the `.blend` matches every export.")
a("")

open(os.path.join(ROOT, "RESULTS.md"), "w", encoding="utf-8").write("\n".join(lines))
print("\n".join(lines))
