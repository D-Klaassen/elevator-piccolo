# Elevator Piccolo

A Steam game about an elevator bellhop (piccolo): greet guests, figure out their floor (even in languages you don't speak), ride with elevator music, earn tips, upgrade to bigger hotels.

**Start here:** [docs/vertical-slice-spec.md](docs/vertical-slice-spec.md). The decisions behind it live in `.wayfinder/`.

## How to run

1. Install Godot 4 (4.7 or newer): `brew install --cask godot` on macOS, or download it from [godotengine.org](https://godotengine.org/download).
2. Open Godot, choose **Import**, and select `project.godot` in this folder. Or from a terminal: `godot --path . --editor`.
3. Press **F5** (Run Project). To play without the editor: `godot --path .`

Controls: **WASD** to walk, **mouse** to look, **left click** to press the button or talk to the guest you're looking at, **Esc** to free the mouse (click again to recapture).

### What's in it so far

`scenes/cabin_greybox.tscn`: a greybox of the rustic cabin, with a 3-floor shaft, a hallway per floor and the elevator cab. The scene is built from code in `scripts/cabin_greybox.gd`. The elevator never moves on its own: close the doors with the `> <` button, pick a floor, and open the doors with `< >` when you arrive.

Guests (capsule placeholders) turn up in the hallways and wait by the elevator. The **Calls** lamps next to the buttons show which floors have someone waiting, with a ding for every new call. Open the doors on their floor and they walk in (up to 3 at a time); look at a guest and click to hear which floor they want. Open the doors on that floor and they walk out. Guests are spawned and moved by `scripts/guest_manager.gd`; no money, tips or patience yet.

## Tests

A headless scripted test serves three guests in a row by pressing the cab's buttons:

```bash
godot --headless --path . --fixed-fps 60 --script tests/guest_loop_test.gd
```

It prints one line per check and exits with 1 if any check fails.
