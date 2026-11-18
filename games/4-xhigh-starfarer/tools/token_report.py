"""Sum token usage from Claude Code session transcripts of this task (main session + any subagent transcripts).
Usage: python tools/token_report.py   (prints a JSON summary)
Transcript lines of type 'assistant' carry message.usage; the same API response can be logged several times
(streamed chunks), so usage is de-duplicated by message id (the last/largest record per id wins)."""
import glob
import json
import os
import sys

ROOT = os.path.expanduser(r"~\.claude\projects\W--YouTube-Sonnet-5-5-Effort-Test-4--Xhigh-Effort")
files = sorted(glob.glob(os.path.join(ROOT, "**", "*.jsonl"), recursive=True))
best = {}
n_lines = 0
for f in files:
    with open(f, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            n_lines += 1
            try:
                d = json.loads(line)
            except Exception:
                continue
            msg = d.get("message") if isinstance(d, dict) else None
            if not isinstance(msg, dict):
                continue
            u = msg.get("usage")
            if not isinstance(u, dict):
                continue
            if d.get("type") != "assistant":
                continue
            mid = msg.get("id") or d.get("uuid")
            key = (f, mid)
            tot = (u.get("input_tokens", 0) or 0) + (u.get("cache_creation_input_tokens", 0) or 0) + (u.get("cache_read_input_tokens", 0) or 0) + (u.get("output_tokens", 0) or 0)
            if key not in best or tot >= best[key][0]:
                best[key] = (tot, u, msg.get("model"))

inp = cw = cr = out = cw5 = cw1 = 0
models = {}
for (_, _), (_, u, model) in best.items():
    inp += u.get("input_tokens", 0) or 0
    cwt = u.get("cache_creation_input_tokens", 0) or 0
    cw += cwt
    cc = u.get("cache_creation") or {}
    if cc:
        cw5 += cc.get("ephemeral_5m_input_tokens", 0) or 0
        cw1 += cc.get("ephemeral_1h_input_tokens", 0) or 0
    else:
        cw5 += cwt
    cr += u.get("cache_read_input_tokens", 0) or 0
    out += u.get("output_tokens", 0) or 0
    models[model] = models.get(model, 0) + 1

res = {"files": files, "lines": n_lines, "api_responses": len(best), "models": models,
       "input_uncached": inp, "cache_write_total": cw, "cache_write_5m": cw5, "cache_write_1h": cw1,
       "cache_read": cr, "output": out}
print(json.dumps(res, indent=2))
