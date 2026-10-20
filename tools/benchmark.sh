#!/usr/bin/env bash
# Measures how heavy the game is to draw at the Steam Deck's resolution (1280x800) in a full
# Pension Bellevue: fps, CPU and GPU time per frame and draw calls, from a few views. Needs
# a window and a GPU. Vulkan, because Metal reports no GPU time. See scripts/benchmark.gd;
# on the Deck itself, run the exported build: ./ElevatorPiccolo.x86_64 -- --benchmark
#
# Usage: tools/benchmark.sh
# Set GODOT to use a Godot binary other than the one on PATH.

set -eu
cd "$(dirname "$0")/.."
"${GODOT:-godot}" --path . --rendering-driver vulkan --resolution 1280x800 -- --benchmark
