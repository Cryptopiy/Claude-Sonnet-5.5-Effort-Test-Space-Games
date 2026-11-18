"""Regenerates sections 1-3 (time, tokens, cost) of RESULTS.md; section 4 (self-assessment) is kept as it is.

Usage: python tools/make_results.py        (the end time is "now"; pauses are the interruptions listed in .timing/pauses.txt)
Token numbers come from tools/sum_tokens.py (session transcripts of the main session and its sub-agents).
"""
import datetime
import glob
import importlib.util
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = r"C:\Users\Cryptopiy\.claude\projects\W--YouTube-Sonnet-5-5-Effort-Test-5--Max-Effort"

spec = importlib.util.spec_from_file_location("sum_tokens", os.path.join(ROOT, "tools", "sum_tokens.py"))
st = importlib.util.module_from_spec(spec)
spec.loader.exec_module(st)

start = datetime.datetime(2026, 10, 31, 11, 7, 28)
end = datetime.datetime.now().replace(microsecond=0)
pauses = [
    ("12:32:20", "13:20:40", "the user asked me to stop and wait while recording a video"),
    ("14:10:00", "14:16:30", "the PC froze (hard reset) - first restart"),
    ("15:14:00", "15:20:00", "the PC froze again - second restart"),
    ("16:14:50", "16:19:30", "the PC froze a third time - the user asked me to analyse and wrap up"),
    ("16:27:00", "21:28:00", "waiting: the user told me to stop for now and wrote again five hours later"),
    ("21:37:00", "21:52:00", "waiting for the user (approx.): a question, then the request to build the exe"),
]


def hms(td):
    s = int(td.total_seconds())
    return "%02d:%02d:%02d" % (s // 3600, (s % 3600) // 60, s % 60)


def parse(t):
    h, m, s = [int(x) for x in t.split(":")]
    return datetime.datetime(2026, 10, 31, h, m, s)


total_pause = datetime.timedelta()
rows = []
for a, b, why in pauses:
    d = parse(b) - parse(a)
    total_pause += d
    rows.append("| %s - %s | %s | %s |" % (a, b, hms(d), why))
gross = end - start
net = gross - total_pause

files = sorted(glob.glob(os.path.join(TR, "*.jsonl")) + glob.glob(os.path.join(TR, "*", "subagents", "*.jsonl")))
FIELDS = st.FIELDS + ("w1h", "w5m")
grand = {f: 0 for f in FIELDS}
trows = []
calls = 0
for path in files:
    msgs = st.read_file(path)
    tot = {f: 0 for f in FIELDS}
    for m in msgs.values():
        for f in FIELDS:
            tot[f] += m[f]
    for f in FIELDS:
        grand[f] += tot[f]
    calls += len(msgs)
    rel = os.path.relpath(path, TR).replace("\\", "/")
    label = "main session" if "/" not in rel else "sub-agent " + os.path.basename(path)[6:-6]
    trows.append("| %s | `%s` | %d | %s | %s | %s | %s |" % (label, rel.split("/")[-1], len(msgs), format(tot["input_tokens"], ","), format(tot["cache_creation_input_tokens"], ","),
                                                         format(tot["cache_read_input_tokens"], ","), format(tot["output_tokens"], ",")))
inp = grand["input_tokens"]
cw = grand["cache_creation_input_tokens"]
cr = grand["cache_read_input_tokens"]
out = grand["output_tokens"]
w1 = grand["w1h"]
w5 = max(cw - w1, 0)
P = st.PRICE
c_in = inp / 1e6 * P["input"]
c_w1 = w1 / 1e6 * P["cache_write_1h"]
c_w5 = w5 / 1e6 * P["cache_write_5m"]
c_cr = cr / 1e6 * P["cache_read"]
c_out = out / 1e6 * P["output"]
total = c_in + c_w1 + c_w5 + c_cr + c_out
allt = inp + cw + cr + out

tokens_md = """Summed from the `usage` fields of the Claude Code session transcripts in `C:\\Users\\Cryptopiy\\.claude\\projects\\W--YouTube-Sonnet-5-5-Effort-Test-5--Max-Effort\\` -
the main session file plus the four sub-agent files in its `subagents\\` folder (the Blender modelling was done by four sub-agent runs; a PC restart killed one of them in the middle and a new sub-agent continued its brief). The script is `tools/sum_tokens.py` (every assistant message is logged on several lines with the same `message.id`; the maximum of each usage field per id is taken, then everything is summed).

| Transcript | File | API calls | Input (uncached) | Cache write | Cache read | Output |
|---|---|---|---|---|---|---|
%s
| **Total** | %d files | **%s** | **%s** | **%s** | **%s** | **%s** |

* **Input tokens (uncached): %s**
* **Cache-write (cache creation) tokens: %s** (1-hour tier, main session: %s; 5-minute tier, sub-agents: %s)
* **Cache-read tokens: %s**
* **Output tokens: %s**
* Sum of all categories: %s tokens.

Notes: the numbers lag by the few thousand tokens spent on writing this report and the final message (computed at %s). Cache reads dominate because the main session ran with a very large context (hundreds of thousands of tokens per call) for about five hours.""" % (
    "\n".join(trows), len(files), format(calls, ","), format(inp, ","), format(cw, ","), format(cr, ","), format(out, ","),
    format(inp, ","), format(cw, ","), format(w1, ","), format(w5, ","), format(cr, ","), format(out, ","), format(allt, ","), end.strftime("%H:%M:%S"))

cost_md = """Prices for **Claude Sonnet 5.5 (`claude-sonnet-5-5`)** from the official Anthropic pricing page, table "Model pricing", row "Claude Sonnet 5.5" - https://platform.claude.com/docs/en/about-claude/pricing (fetched 2026-10-31): base input **$2 / MTok**, 5-minute cache write **$2.50 / MTok**, 1-hour cache write **$4 / MTok**, cache read (hit) **$0.10 / MTok** (0.05x base input), output **$10 / MTok**. The full 1M context window is billed at the standard rate for this model (no long-context surcharge); no batch discount applies.

| Category | Tokens | Price | Cost |
|---|---|---|---|
| Input (uncached) | %s | $2.00 / MTok | $%.2f |
| Cache write, 1-hour tier (main session) | %s | $4.00 / MTok | $%.2f |
| Cache write, 5-minute tier (sub-agents) | %s | $2.50 / MTok | $%.2f |
| Cache read | %s | $0.10 / MTok | $%.2f |
| Output | %s | $10.00 / MTok | $%.2f |
| **Total** | %s | | **$%.2f** |

Calculation: tokens / 1,000,000 x price, per category, then summed (reproduce with `python tools/sum_tokens.py`).""" % (
    format(inp, ","), c_in, format(w1, ","), c_w1, format(w5, ","), c_w5, format(cr, ","), c_cr, format(out, ","), c_out, format(allt, ","), total)

time_md = """| | |
|---|---|
| Start | 2026-10-31 **11:07:28** (+01:00) - from `.timing/start.txt` |
| End | 2026-10-31 **%s** (+01:00) |
| **Elapsed, wall clock (gross)** | **%s** |
| Interruptions (not working time, see below) | %s |
| **Elapsed without the interruptions (net)** | **%s** |

Interruptions (also logged in `.timing/pauses.txt`):

| Time | Length | Reason |
|---|---|---|
%s""" % (end.strftime("%H:%M:%S"), hms(gross), hms(total_pause), hms(net), "\n".join(rows))

path = os.path.join(ROOT, "RESULTS.md")
txt = open(path, encoding="utf-8").read()
head = txt.split("## 1. Time spent")[0]
selfa = txt.split("## 4. Self-assessment")[1]
new = head + "## 1. Time spent\n\n" + time_md + "\n\n## 2. Tokens\n\n" + tokens_md + "\n\n## 3. Cost at API-equivalent prices (`claude-sonnet-5-5`)\n\n" + cost_md + \
    "\n\n## 4. Self-assessment" + selfa
open(path, "w", encoding="utf-8", newline="\n").write(new)
print("end", end, "gross", hms(gross), "net", hms(net), "pauses", hms(total_pause))
print("tokens in/cw/cr/out", inp, cw, cr, out, "total", allt, "cost %.2f" % total)
