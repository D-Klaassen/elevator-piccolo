#!/usr/bin/env bash
# Exports the game for Windows and macOS into build/, using the presets in
# export_presets.cfg. The Linux preset (for the Steam Deck, later) builds when named.
# Needs Godot's export templates for the same version as the editor: in the editor,
# Editor > Manage Export Templates > Download and Install.
#
# Usage: tools/build.sh [preset ...]   With no names it builds Windows and macOS.
# Set GODOT to use a Godot binary other than the one on PATH.

set -u
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"

[ $# -eq 0 ] && set -- Windows macOS

"$godot" --headless --path . --import > /dev/null 2>&1

failed=""
for preset in "$@"; do
	path=$(awk -v name="name=\"$preset\"" '
		$0 == name { found = 1 }
		found && /^export_path=/ { sub(/^export_path="/, ""); sub(/"$/, ""); print; exit }
	' export_presets.cfg)
	if [ -z "$path" ]; then
		echo "$preset: no such preset in export_presets.cfg"
		failed="$failed $preset"
		continue
	fi
	mkdir -p "$(dirname "$path")"
	rm -f "$path"
	echo "Building $preset into $path"
	# Godot can exit with 0 even when the export fails, so check the file is there too.
	if ! "$godot" --headless --path . --export-release "$preset" "$path" || [ ! -s "$path" ]; then
		echo "$preset: build failed"
		failed="$failed $preset"
	fi
done

if [ -n "$failed" ]; then
	echo "Failed:$failed"
	exit 1
fi
echo "Built $# presets into build/"
