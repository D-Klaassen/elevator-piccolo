#!/usr/bin/env bash
# Runs the headless tests and fails unless each one exits with 0 and prints "<name>: PASS".
# When a test script fails to load, for example on a parse error in the test or in a game
# script it uses, Godot prints the error and exits with 0 without running a single check,
# so the exit code alone is not enough.
#
# Usage: tests/run.sh [name ...]   With no names it runs every tests/*_test.gd.
# Set GODOT to use a Godot binary other than the one on PATH.

set -u
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"

if [ $# -eq 0 ]; then
	for file in tests/*_test.gd; do
		name=$(basename "$file" .gd)
		# The shared base every test extends, not a test of its own.
		[ "$name" = scene_test ] || set -- "$@" "$name"
	done
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT
failed=""
for name in "$@"; do
	"$godot" --headless --path . --fixed-fps 60 --script "tests/$name.gd" 2>&1 | tee "$log"
	code=${PIPESTATUS[0]}
	if [ "$code" -ne 0 ] || ! grep -qx "$name: PASS" "$log"; then
		echo "$name: did not pass (exit code $code)"
		failed="$failed $name"
	fi
done

if [ -n "$failed" ]; then
	echo "Failed:$failed"
	exit 1
fi
echo "All $# tests passed"
