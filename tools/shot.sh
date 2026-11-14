#!/usr/bin/env bash
# Render a scene under Xvfb (software GL) and save a screenshot.
# Usage: tools/shot.sh <scene> <out.png> [extra game args...]
set -e
scene="$1"; out="$2"; shift 2
timeout 180 xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 "$scene" -- --screenshot="$out" "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR: [^C1I]|Parse Error|screenshot saved|PERF" | grep -v "resources still" || true
