#!/bin/bash
# Run the Godot GUI exe fully off-screen (no focus, far outside every monitor). Usage: tools/gorun.sh <scene or args...>
G="/w/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
cd "W:/YouTube/Sonnet 5.5 Effort Test/4. Xhigh Effort"
timeout ${GTIMEOUT:-150} "$G" --path . --resolution ${RES:-8x8} "$@" 2>&1 | grep -vE "leaked|BUG: Unref|Pages in use|^Godot Engine|^Vulkan|^$"
