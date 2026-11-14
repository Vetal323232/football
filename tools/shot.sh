#!/usr/bin/env bash
# Render a scene under Xvfb (software GL) and save a screenshot.
# Usage: tools/shot.sh <scene> <out.png> [extra game args...]
# Exit: 0 only if the engine exited cleanly, reported no script error and wrote a real PNG.
#       2 usage / missing dependency, 3 engine failure or timeout, 4 script error, 5 missing or invalid image.
# Environment: GODOT (default "godot"), XVFB_RUN (default "xvfb-run").
set -u
if [ "$#" -lt 2 ]; then
	echo "usage: tools/shot.sh <scene> <out.png> [extra game args...]" >&2
	exit 2
fi
scene="$1"; out="$2"; shift 2
godot_bin="${GODOT:-godot}"
xvfb_bin="${XVFB_RUN:-xvfb-run}"
for dep in "$godot_bin" "$xvfb_bin" timeout; do
	if ! command -v "$dep" >/dev/null 2>&1; then
		echo "shot.sh: missing dependency: $dep" >&2
		exit 2
	fi
done
rm -f "$out"                       # a stale image must never count as this run's result
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
timeout 180 "$xvfb_bin" -a -s "-screen 0 1600x900x24" "$godot_bin" --rendering-driver opengl3 --resolution 1600x900 "$scene" -- --screenshot="$out" "$@" >"$log" 2>&1
status=$?
# Show only the relevant engine lines; filtering never changes the exit status.
grep -E "SCRIPT ERROR|ERROR: [^C1I]|Parse Error|screenshot saved|PERF" "$log" | grep -v "resources still"
if [ "$status" -ne 0 ]; then
	echo "shot.sh: engine exited with status $status" >&2
	exit 3
fi
if grep -q -E "SCRIPT ERROR|Parse Error" "$log"; then
	echo "shot.sh: script errors during the run" >&2
	exit 4
fi
if [ ! -s "$out" ] || [ "$(head -c 8 "$out" | od -An -tx1 | tr -d ' \n')" != "89504e470d0a1a0a" ]; then
	echo "shot.sh: no valid PNG at $out" >&2
	exit 5
fi
exit 0
