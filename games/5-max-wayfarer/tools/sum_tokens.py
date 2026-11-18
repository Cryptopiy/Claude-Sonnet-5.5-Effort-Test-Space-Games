"""Sums the token usage of a Claude Code session (main transcript + all subagent transcripts) and prices it.

Usage:  python tools/sum_tokens.py [project transcript folder]

Every assistant message of a transcript may be logged on several lines (one per content block) with the same
`message.id`; the usage numbers of those lines are partial/identical, so for each message id the MAXIMUM of every
usage field is taken (the last streamed value), then everything is summed.

Prices: claude-sonnet-5-5, USD per million tokens, from https://platform.claude.com/docs/en/about-claude/pricing
(table "Model pricing", row "Claude Sonnet 5.5", fetched 2026-10-31): base input $2, 5-minute cache write $2.50,
1-hour cache write $4, cache read (hit) $0.10 (0.05x base input), output $10. The full 1M context window is billed at the
standard rate (no long-context surcharge for this model).
"""
import glob
import json
import os
import sys

DEFAULT = r"C:\Users\Cryptopiy\.claude\projects\W--YouTube-Sonnet-5-5-Effort-Test-5--Max-Effort"
FIELDS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")
PRICE = {"input": 2.00, "cache_write_5m": 2.50, "cache_write_1h": 4.00, "cache_read": 0.10, "output": 10.00}


def read_file(path):
    msgs = {}
    anon = 0
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            msg = rec.get("message")
            if not isinstance(msg, dict):
                continue
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            mid = msg.get("id")
            if not mid:
                anon += 1
                mid = "anon-%d" % anon
            cur = msgs.setdefault(mid, {f: 0 for f in FIELDS + ("w1h", "w5m")})
            for f in FIELDS:
                v = usage.get(f)
                if isinstance(v, int) and v > cur[f]:
                    cur[f] = v
            cc = usage.get("cache_creation")
            if isinstance(cc, dict):
                for key, name in (("ephemeral_1h_input_tokens", "w1h"), ("ephemeral_5m_input_tokens", "w5m")):
                    v = cc.get(key)
                    if isinstance(v, int) and v > cur[name]:
                        cur[name] = v
    return msgs


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    files = sorted(glob.glob(os.path.join(root, "*.jsonl")) + glob.glob(os.path.join(root, "*", "subagents", "*.jsonl")))
    grand = {f: 0 for f in FIELDS + ("w1h", "w5m")}
    calls = 0
    for path in files:
        msgs = read_file(path)
        tot = {f: 0 for f in FIELDS + ("w1h", "w5m")}
        for m in msgs.values():
            for f in tot:
                tot[f] += m[f]
        for f in tot:
            grand[f] += tot[f]
        calls += len(msgs)
        print("%-90s msgs=%5d in=%8d cw=%10d cr=%12d out=%8d" % (os.path.relpath(path, root), len(msgs), tot["input_tokens"],
              tot["cache_creation_input_tokens"], tot["cache_read_input_tokens"], tot["output_tokens"]))
    # cache writes without a TTL breakdown are priced as 5-minute writes (the cheaper tier would understate, the 1h tier overstate)
    w_known = grand["w1h"] + grand["w5m"]
    w_unknown = max(grand["cache_creation_input_tokens"] - w_known, 0)
    w5 = grand["w5m"] + w_unknown
    w1 = grand["w1h"]
    cost = {
        "input (uncached)": grand["input_tokens"] / 1e6 * PRICE["input"],
        "cache write 1h": w1 / 1e6 * PRICE["cache_write_1h"],
        "cache write 5m": w5 / 1e6 * PRICE["cache_write_5m"],
        "cache read": grand["cache_read_input_tokens"] / 1e6 * PRICE["cache_read"],
        "output": grand["output_tokens"] / 1e6 * PRICE["output"],
    }
    print()
    print("files: %d   assistant messages (API calls): %d" % (len(files), calls))
    print("input (uncached)      : %14d tokens  x $%.2f/M = $%.4f" % (grand["input_tokens"], PRICE["input"], cost["input (uncached)"]))
    print("cache write (creation): %14d tokens   (1h tier %d x $%.2f/M = $%.4f ; 5m tier %d x $%.2f/M = $%.4f)" % (
        grand["cache_creation_input_tokens"], w1, PRICE["cache_write_1h"], cost["cache write 1h"], w5, PRICE["cache_write_5m"], cost["cache write 5m"]))
    print("cache read            : %14d tokens  x $%.2f/M = $%.4f" % (grand["cache_read_input_tokens"], PRICE["cache_read"], cost["cache read"]))
    print("output                : %14d tokens  x $%.2f/M = $%.4f" % (grand["output_tokens"], PRICE["output"], cost["output"]))
    print("total tokens          : %14d" % sum(grand[f] for f in FIELDS))
    print("TOTAL COST (API-equivalent, claude-sonnet-5-5): $%.2f" % sum(cost.values()))


if __name__ == "__main__":
    main()
