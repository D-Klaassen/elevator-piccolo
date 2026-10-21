#!/usr/bin/env bash
# Downloads a CC0 PBR texture set at 1K from Poly Haven or ambientCG into
# assets/textures/<id>/ as the three maps scripts/interior.gd reads: albedo.jpg,
# normal.jpg (OpenGL, Y+, as Godot wants it) and orm.jpg (red AO, green roughness, blue
# metalness), then imports them with VRAM compression and mipmaps, the normal map as one.
# Write an id as <id>:turn to turn the set a quarter turn, for boards or logs that run
# the wrong way. Add a row to CREDITS.md for every set you add.
#
# Usage: tools/pbr_texture.sh polyhaven <id>[:turn] | ambientcg <id>[:turn] ...
#   e.g. tools/pbr_texture.sh polyhaven wood_trunk_wall:turn ambientcg Carpet013
# Set GODOT to use a Godot binary other than the one on PATH.

set -eu
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
root=$(pwd)

if [ $# -eq 0 ] || [ $(($# % 2)) -ne 0 ]; then
	sed -n '2,12p' "$0"
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

ids=""
while [ $# -gt 0 ]; do
	source=$1 id=${2%:turn}
	turn=$([ "$2" != "$id" ] && echo 1 || true)
	shift 2
	out="assets/textures/$id"
	mkdir -p "$out"
	dir="$work/$id"
	mkdir -p "$dir"
	case $source in
	polyhaven)
		base="https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/$id/${id}"
		curl -fsSL -o "$out/albedo.jpg" "${base}_diff_1k.jpg"
		curl -fsSL -o "$out/normal.jpg" "${base}_nor_gl_1k.jpg"
		curl -fsSL -o "$out/orm.jpg" "${base}_arm_1k.jpg" # Poly Haven's ARM is ORM already
		;;
	ambientcg)
		curl -fsSL -o "$dir/set.zip" "https://ambientcg.com/get?file=${id}_1K-JPG.zip"
		unzip -q -o "$dir/set.zip" -d "$dir/maps"
		map() { find "$dir/maps" -name "*_$1.jpg" | head -1; }
		cp "$(map Color)" "$out/albedo.jpg"
		cp "$(map NormalGL)" "$out/normal.jpg"
		ao=$(map AmbientOcclusion) metal=$(map Metalness)
		"$godot" --headless --script "$root/tools/pbr_maps.gd" -- orm "$root/$out/orm.jpg" "$(map Roughness)" "${ao:--}" "${metal:--}" > /dev/null
		;;
	*)
		echo "Unknown source $source: polyhaven or ambientcg"
		exit 1
		;;
	esac
	if [ -n "$turn" ]; then
		"$godot" --headless --script "$root/tools/pbr_maps.gd" -- turn "$root/$out" > /dev/null
	fi
	echo "$id: $(du -sh "$out" | cut -f1)"
	ids="$ids $id"
done

# Godot imports the maps with the settings in their .import files, written here first:
# VRAM compression with mipmaps, the normal map as one. (The editor only picks those by
# itself for textures it sees used in a 3D scene; ours are loaded from code.)
for id in $ids; do
	for map in albedo normal orm; do
		normal=$([ $map = normal ] && echo 1 || echo 0)
		printf '[params]\n\ncompress/mode=2\ncompress/normal_map=%s\nmipmaps/generate=true\ndetect_3d/compress_to=0\n' "$normal" \
			> "assets/textures/$id/$map.jpg.import"
	done
done
"$godot" --headless --path . --import > /dev/null 2>&1
