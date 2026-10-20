# Elevator Piccolo

A Steam game about an elevator bellhop (piccolo): greet guests, figure out their floor (even in languages you don't speak), ride with elevator music, earn tips, upgrade to bigger hotels.

**Start here:** [docs/vertical-slice-spec.md](docs/vertical-slice-spec.md). The decisions behind it live in `.wayfinder/`.

## How to run

1. Install Godot 4 (4.7 or newer): `brew install --cask godot` on macOS, or download it from [godotengine.org](https://godotengine.org/download).
2. Open Godot, choose **Import**, and select `project.godot` in this folder. Or from a terminal: `godot --path . --editor`.
3. Press **F5** (Run Project). To play without the editor: `godot --path .`

Controls: **WASD** to walk, **mouse** to look, **left click** to press the button or talk to the guest you're looking at, **Esc** to free the mouse (click again to recapture).

### What's in it so far

`scenes/cabin_greybox.tscn`: a greybox of the rustic cabin, with a 3-floor shaft, a hallway per floor and the elevator cab. The scene is built from code in `scripts/cabin_greybox.gd`. The elevator only goes where you send it. Press floor buttons to queue them; they stay lit until the cab gets there. Once the doors are closed (`> <`), the cab rides to the next queued floor, stopping at any queued floor on the way. At a stop with more floors still queued, the doors open by themselves and the cab waits until you close them again. At the last queued floor the doors stay shut until you press open. The door buttons (`< >` open, `> <` close) stay lit until the doors have finished. Close waits for anyone in the doorway, and pressing open while the doors are closing reopens them.

Guests (capsule placeholders) turn up in the hallways and wait by the elevator. The **Calls** lamps next to the buttons show which floors have someone waiting, with a ding for every new call. Open the doors on their floor and they walk in (up to 3 at a time); look at a guest and click to hear which floor they want. Open the doors on that floor and they walk out. Guests are spawned and moved by `scripts/guest_manager.gd`.

A shift runs from 08:00 to 18:00 (about 9 real minutes, clock at the top) and brings 15 guests, with a lunch rush around 12:00–13:30. Guests come in three temperaments (hasty, normal, patient) that wait 30, 45 or 60 s for the cab and put up with 18, 25 or 35 s of riding. When a guest gets impatient, a red "!" shows above their head and their call lamp blinks. If they wait too long they take the stairs; if a ride takes too long they get out at the next stop. Either way they pay nothing and you get a complaint (−½ star). Each guest you deliver pays a €2 fare plus a tip of up to €6, less the closer they came to running out of patience. The shift ends once the clock has run out and the last guest is gone; the report adds a €5 wage and lets you play the shift again. Below 2 stars you're fired. The rules live in `scripts/shift.gd`.

## Tests

Headless scripted tests drive the cab through its own buttons. `elevator_test` covers the lit buttons and the floor queue; `guest_loop_test` serves three guests in a row; `shift_test` covers the clock, patience, pay and the end-of-shift report, then plays a whole shift with an autopilot:

```bash
godot --headless --path . --fixed-fps 60 --script tests/elevator_test.gd
```

```bash
godot --headless --path . --fixed-fps 60 --script tests/guest_loop_test.gd
```

```bash
godot --headless --path . --fixed-fps 60 --script tests/shift_test.gd
```

Each prints one line per check and exits with 1 if any check fails.
