"""Sums assistant `usage` fields from the Claude Code session transcript(s) (deduplicated by message id)."""
import json, glob, sys, os
root = r"C:\Users\Cryptopiy\.claude\projects\W--YouTube-Sonnet-5-5-Effort-Test-3--High-Effort"
files = glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True)
seen = {}
for f in files:
    for line in open(f, encoding="utf8"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        m = d.get("message") or {}
        u = m.get("usage")
        if not u or d.get("type") != "assistant":
            continue
        key = m.get("id") or d.get("uuid")
        seen[key] = u  # last record per message wins (final usage)
tot = dict(inp=0, cw=0, cw5=0, cw1=0, cr=0, out=0)
for u in seen.values():
    tot["inp"] += u.get("input_tokens", 0)
    cc = u.get("cache_creation") or {}
    c5 = cc.get("ephemeral_5m_input_tokens", 0); c1 = cc.get("ephemeral_1h_input_tokens", 0)
    tot["cw"] += u.get("cache_creation_input_tokens", 0)
    tot["cw5"] += c5; tot["cw1"] += c1
    tot["cr"] += u.get("cache_read_input_tokens", 0)
    tot["out"] += u.get("output_tokens", 0)
print("files:", files)
print("messages:", len(seen))
print(tot)
P = dict(inp=2.0, cw5=2.5, cw1=4.0, cr=0.10, out=10.0)
cw1 = tot["cw1"] if tot["cw5"] + tot["cw1"] else tot["cw"]
cw5 = tot["cw5"]
costs = {
 "input": tot["inp"]/1e6*P["inp"], "cache_write_5m": cw5/1e6*P["cw5"], "cache_write_1h": cw1/1e6*P["cw1"],
 "cache_read": tot["cr"]/1e6*P["cr"], "output": tot["out"]/1e6*P["out"]}
for k, v in costs.items(): print(f"{k}: ${v:.4f}")
print("TOTAL $%.2f" % sum(costs.values()))
