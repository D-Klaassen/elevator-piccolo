#!/usr/bin/env bash
# Measures how heavy the game is to draw at full HD (1920x1080) in a full Pension Bellevue:
# fps, CPU and GPU time per frame and draw calls, from a few views. Needs a window and a
# GPU. Vulkan, because Metal reports no GPU time. See scripts/benchmark.gd; an exported
# build runs it too: ElevatorPiccolo.exe -- --benchmark on Windows.
#
# Usage: tools/benchmark.sh
# Set GODOT to use a Godot binary other than the one on PATH.

set -eu
cd "$(dirname "$0")/.."
"${GODOT:-godot}" --path . --rendering-driver vulkan --resolution 1920x1080 -- --benchmark
