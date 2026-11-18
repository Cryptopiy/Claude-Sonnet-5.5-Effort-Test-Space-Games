#!/bin/bash
# Parse-check every GDScript file (headless, no window). Usage: tools/check.sh
cd "W:/YouTube/Sonnet 5.5 Effort Test/4. Xhigh Effort"
G="/w/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --import >/dev/null 2>&1
for f in $(find scripts tests -name "*.gd" | sort); do
  out=$("$G" --headless --path . --check-only --script "res://$f" 2>&1 | grep -E "Parse Error|SCRIPT ERROR|Compile Error" | grep -v "Failed to compile depended")
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -5; fi
done
echo "check done"
