"""Sum token usage over the session transcript(s) of this project (main session + all subagent / workflow-agent transcripts).

  python tools/usage_report.py            # prints a JSON-ish report
  python tools/usage_report.py --json out.json

Transcripts live in C:\\Users\\Cryptopiy\\.claude\\projects\\<project-folder>\\ (*.jsonl, plus subagents\\**\\*.jsonl).
A single API message is written several times (one line per content block, usage updated while streaming), so usage is de-duplicated by
message.id (taking the maximum of every counter per id). Entries without usage (user/tool lines) are ignored.
"""
import glob
import json
import os
import sys

ROOT = r"C:\Users\Cryptopiy\.claude\projects\W--YouTube-Sonnet-5-5-Effort-Test-6--Ultracode-Effort"
FIELDS = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"]


def scan(root=ROOT):
    files = glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True)
    per_msg = {}   # (file-group, message id) -> {field: max}
    by_file = {}
    models = {}
    for f in files:
        try:
            fh = open(f, "r", encoding="utf-8")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = d.get("message") if isinstance(d, dict) else None
                if not isinstance(msg, dict):
                    continue
                u = msg.get("usage")
                if not isinstance(u, dict):
                    continue
                mid = msg.get("id") or d.get("uuid")
                key = (mid,)
                cur = per_msg.setdefault(key, {k: 0 for k in FIELDS})
                for k in FIELDS:
                    v = u.get(k) or 0
                    if v > cur[k]:
                        cur[k] = v
                by_file.setdefault(key, f)
                if msg.get("model"):
                    models[msg["model"]] = models.get(msg["model"], 0) + 0
    totals = {k: 0 for k in FIELDS}
    per_file = {}
    for key, cur in per_msg.items():
        f = by_file[key]
        pf = per_file.setdefault(f, {k: 0 for k in FIELDS})
        for k in FIELDS:
            totals[k] += cur[k]
            pf[k] += cur[k]
    return files, totals, per_file, len(per_msg)


if __name__ == "__main__":
    files, totals, per_file, n = scan()
    report = {"transcript_files_scanned": len(files), "unique_api_messages": n, "totals": totals,
              "files_with_usage": {os.path.relpath(f, ROOT): v for f, v in per_file.items()}}
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        json.dump(report, open(out, "w", encoding="utf-8"), indent=2)
    print(json.dumps({k: report[k] for k in ("transcript_files_scanned", "unique_api_messages", "totals")}, indent=2))
