# Elevator Piccolo

A Steam game about an elevator bellhop (piccolo): greet guests, figure out their floor (even in languages you don't speak), ride with elevator music, earn tips, upgrade to bigger hotels.

**Start here:** [docs/vertical-slice-spec.md](docs/vertical-slice-spec.md). The decisions behind it live in `.wayfinder/`.

## How to run

1. Install Godot 4 (4.7 or newer): `brew install --cask godot` on macOS, or download it from [godotengine.org](https://godotengine.org/download).
2. Open Godot, choose **Import**, and select `project.godot` in this folder. Or from a terminal: `godot --path . --editor`.
3. Press **F5** (Run Project). To play without the editor: `godot --path .`

Controls: **WASD** to walk, **mouse** to look, **left click** to press the button you're looking at, **Esc** to free the mouse (click again to recapture).

### What's in it so far

`scenes/cabin_greybox.tscn`: a greybox of the rustic cabin, with a 3-floor shaft, a hallway per floor and the elevator cab. The scene is built from code in `scripts/cabin_greybox.gd`. The elevator never moves on its own: close the doors with the `> <` button, pick a floor, and open the doors with `< >` when you arrive.
