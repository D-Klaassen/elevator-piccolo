#!/usr/bin/env bash
# PROTOTYPE, throw away. Starts the game with the menu prototype: three variants of the
# title screen, the pause menu and the settings, switchable with [ and ] or the pink bar.
#
# Usage: tools/menu_prototype.sh [A|B|C]   The letter picks the variant to start on.
# Set GODOT to use a Godot binary other than the one on PATH.

set -u
cd "$(dirname "$0")/.."
exec "${GODOT:-godot}" --path . -- --menu-prototype --menu-variant="${1:-A}"
