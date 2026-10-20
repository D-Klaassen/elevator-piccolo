#!/usr/bin/env bash
# Plays the whole demo headless with an autopilot and prints every shift and how long it
# took, to check the demo's length and economy against the spec. See tests/playthrough.gd.
#
# Usage: tools/playthrough.sh [expert|newcomer]
# Set GODOT to use a Godot binary other than the one on PATH.

set -eu
cd "$(dirname "$0")/.."
"${GODOT:-godot}" --headless --path . --fixed-fps 60 --script tests/playthrough.gd -- "${1:-expert}"
