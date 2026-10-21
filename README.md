# Elevator Piccolo

A Steam game about an elevator bellhop (piccolo): greet guests, figure out their floor (even in languages you don't speak), ride with elevator music, earn tips, upgrade to bigger hotels.

**Start here:** [docs/vertical-slice-spec.md](docs/vertical-slice-spec.md). The decisions behind it live in `.wayfinder/`. Where the models come from, and their licenses: [CREDITS.md](CREDITS.md).

## How to run

1. Install Godot 4 (4.7 or newer): `brew install --cask godot` on macOS, or download it from [godotengine.org](https://godotengine.org/download).
2. Open Godot, choose **Import**, and select `project.godot` in this folder. Or from a terminal: `godot --path . --editor`.
3. Press **F5** (Run Project). To play without the editor: `godot --path .`

Controls: **WASD** to walk, **mouse** to look, **left click** (or **E**) to press the button or talk to the guest you're looking at, **Esc** to pause. With a controller (Xbox layout): **left stick** to walk, **right stick** to look, **A** to press or talk, **Start** to pause. In the menus the **D-pad** or left stick moves between buttons and sliders, **A** presses and **B** goes back. The help line in the corner switches to the controller while one is connected. The actions are set up in `scripts/controls.gd`.

Pausing opens the **settings**: a volume slider (0 mutes the game), a look sensitivity slider (×0.25 to ×3, for both the mouse and the right stick) and a **Smooth edges** switch, on by default, which turns 2× anti-aliasing (MSAA) on the 3D view on or off; turn it off on a computer that can't keep up. They take effect and are saved straight away, in `user://settings.cfg`, apart from the career. **Resume**, or Esc, Start or B, goes back to the shift; **Quit the game** quits without saving the shift in progress. The staff room has a **Settings** button for the same panel. The settings live in `scripts/settings.gd`, the panel in `scripts/settings_menu.gd`.

### Debug options and the Asset room

In debug builds (running from the editor, or a debug export) the settings panel has a **Debug** section, for testing; release builds don't show it. Its switches are off again every time the game starts, and while any is on the HUD says so in its top left corner (`DEBUG`, or `DEBUG ×4` at another speed):

- **Infinite money**: upgrades and moving up cost nothing, and your bank balance stays as it is, so the save stays honest.
- **Skip hotel requirements**: you can move up to the next hotel, or apply to the Grand Hotel, without the rating.
- **Game speed**: ×1, ×2, ×4 or ×8 for the whole game, the clock, the guests and the elevator alike.
- **End shift now** (during a shift): the shift ends straight away and counts as it stands, with the wage, the tips so far and the stars you have; guests still in the hotel just go.
- **Asset room**: a long room with every asset in it, at its in-game size, to look at and comment on. Look at an asset and its name shows under the crosshair: quote that name to ask for a change ("loungeSofa is too big"). The room has a sign per section and a 1.8 m pole to judge sizes by: the 12 characters (click one to go through its animations, each named in its speech bubble), the furniture, the parts of the cab and the doors (a side-opening and a centre-opening elevator door, each a piece of landing wall with the doors hanging behind it: click one to open or close it, and walk round it to see the doors slide in behind the wall; click a floor display to change what it shows), a sample corner per hotel (one of its hallways, built by the same code as the game's but open on the aisle side, with a working elevator in it), and the ding and the chimes (click a button to hear it). What looks the same everywhere has the same name everywhere (`door panel`, `cab handrail`); what differs per hotel carries the hotel's name (`Pension Bellevue carpet floor`). The models are picked up from the folders under `assets/`, so a new one shows up on its own. In its menu (Esc) a **Walk speed** slider lets you walk up to four times faster, until the game quits. Opening it during a shift drops that shift; **Leave the Asset room** (Esc) takes you back where you came from: the staff room, or a fresh start of the shift.

The options live in `scripts/debug_options.gd`, the room in `scripts/asset_room.gd` (`scenes/asset_room.tscn`).

### What's in it so far

`scenes/cabin_greybox.tscn`: the hotel you work in (the rustic cabin, with a 3-floor shaft, or Pension Bellevue with 7 floors), a hallway per floor and the elevator cab. The scene is built from code in `scripts/cabin_greybox.gd`, the shaft and the hallways in `scripts/hallway.gd`. The hallways are furnished with Kenney's Furniture Kit, to suit each floor at Pension Bellevue: sofas in the lobby, tables in the restaurant, loungers by the pool, a bar on the roof. The layouts live in `scripts/decor.gd`. Each hotel has its own look (`scripts/interior.gd`): the cabin has log walls and plank floors, Pension Bellevue striped wallpaper over wood panelling and a red patterned carpet, with skirting, a frame round the elevator, a ceiling lamp and a plate behind every floor sign. The cab has wood panelling, a chequered floor, a ceiling light and a brass handrail, and the same frame round its door as the hallways have. Its doors slide in between its front wall and an inner front wall, so from inside they sit in the opening just as they do from the hallway. Every door panel is a plain slab of satin steel, meeting the next in a thin seam. The patterns are small textures drawn in code, and the trim has no collision, so it never changes where anyone can walk. The elevator only goes where you send it. Press floor buttons to queue them; they stay lit until the cab gets there. Once the doors are closed (`> <`), the cab rides to the next queued floor, stopping at any queued floor on the way. The doors never open by themselves: at every stop you decide whether to press open. They move like a real elevator's: side-opening, as this is the smallest cab, with two telescoping panels that slide to the left as you face them from inside (to the right from the hallway), speeding up and easing into the wall when they open, creeping the last bit when they close, the cab's doors leading the landing doors; a chime rings on arrival, once going up and twice going down. The frame round the doors, the hotel's own on the hallway side and dark wood in the cab, laps over their outer edges and lines the opening right back to them, as a real jamb does, so they slide in behind it and never through the wall, a dark threshold runs under them, and over every door, inside the cab and in each hallway, a floor display shows in green where the cab is, with an up and a down arrow that light while it rides (`scripts/floor_display.gd`). Every hallway has landing doors, hung on the shaft side of the landing wall as a real elevator's are, that open and close with the cab's on the floor it's at and stay shut on the others, so nobody walks into the empty shaft, and a round yellow call button on a steel plate beside them. Shut yourself out and the call button brings the cab back: it opens up if the cab is there, and otherwise the cab shuts its doors, comes to you and opens on arrival (the one time the doors open by themselves). At a stop with more floors queued, the cab waits until you press close again, so you can open up for guests or press close straight away to skip on. The door buttons (`< >` open, `> <` close) stay lit until the doors have finished. Close waits for anyone in the doorway, and pressing open while the doors are closing reopens them.

Guests turn up in the hallways and wait by the elevator. Each is one of Kenney's 12 Mini Characters, and no two guests in the hotel look the same at once. They walk, stand idle, wave when they tell you their floor, nod when they thank you and shake their head when they give up or complain. Every new call rings a ding. Which floor it came from you have to find out yourself, until you buy the call panel in the staff room: its **Calls** lamps next to the buttons show which floors have someone waiting. Open the doors on their floor and they walk in (up to 3 at a time); look at a guest and click to hear which floor they want. Everything guests say (their floor, "Thanks!", "I'll take the stairs!") shows for a few seconds in a dark speech bubble with a gold border that comes out of their mouth (drawn in `scripts/speech_bubble.gd`), with a small badge at its top right for the language they speak (a red ES, a blue EN), hidden while a wall is in between; pay and complaints show at the bottom of the screen. Chats are switched off for now (`chat_chance` in `scripts/guest_manager.gd` is 0). When on, a guest strikes up a chat a few seconds into the ride, and the HUD offers three replies in a shuffled order. Which one lands well depends on what they said: a guest in a hurry wants a short answer, not a story. Pick one with **1–3** or click it (no controller support yet, as chats are off) (the mouse is freed while the choices show). One guest chats at a time; no reply within 10 s counts as neutral. Open the doors on that floor and they walk out. Guests are spawned and moved by `scripts/guest_manager.gd`.

A shift runs from 08:00 to 18:00 (about 9 real minutes, clock at the top) and brings 15 guests in the cabin (25 at Pension Bellevue), with a lunch rush around 12:00–13:30. The first guest always calls at 08:05 from the ground floor, where the cab starts, so there's something to do straight away. Guests come in three temperaments (hasty, normal, patient) that wait 45, 65 or 90 s for the cab and put up with 30, 40 or 55 s of riding. When a guest gets impatient, a red "!" shows above their head, and with the second level of the call panel their call lamp blinks. If they wait too long they take the stairs; if a ride takes too long they get out at the next stop. Either way they pay nothing and you get a complaint (−½ star). Each guest you deliver pays a €2 fare plus a tip of up to €6: up to €4 for a quick pick-up (less the closer they came to running out of patience), €2 more for a good reply to their chat (capped at €6), nothing extra for a neutral reply or none, and half for a bad one. A bad reply also has a 50% chance of a complaint (−½ star). The shift ends once the clock has run out and the last guest is gone; the report adds a €5 wage. Below 2 stars you're fired. The rules live in `scripts/shift.gd`.

Your money carries over from shift to shift. At the end of every shift its fares, tips and wage go into a bank balance, and its star rating is kept. Both are saved to `user://career.cfg` (on macOS: `~/Library/Application Support/Godot/app_userdata/Elevator Piccolo/`) and loaded again when the next shift starts, also after quitting the game. The report shows the bank balance and, next to the shift's own rating, the average of the last 3 shifts (the average so far before your third shift). Every shift still starts at 5 stars. **Next shift** goes on; after being fired the button reads **Play the shift again** and you retry the same shift, though its pay and rating still count. Delete the save file to start over. The career lives in `scripts/career.gd`.

After the report comes the **staff room**, where you spend your bank balance on upgrades before you **Start the shift**. Every purchase is saved straight away and shows up in the cab from the next shift on. At the cabin's prices: the **Call panel** (€40 / €100) adds a lamp per floor that lights while someone waits there, then makes it blink when a guest runs out of patience; **Music** (€40 / €100 / €225) puts a radio on a shelf high on the back wall (with a pair of speakers at level 2 and a second pair at level 3), and each level lets guests put up with a 25% longer ride; a **Bigger cab** (€75 / €200) takes 4, then 5 guests, shown on the plate by the buttons; **Faster doors** (€50 / €125) open in 0.85, then 0.55 s instead of 1.2 s (closing takes 30% longer). The music box is silent for now: there are no tracks yet. Spanish lessons come with the Spanish guests. The catalogue lives in `scripts/upgrades.gd`, the screen in `scripts/staff_room.gd`.

From the staff room you can also **move up** to the next hotel. Pension Bellevue opens up once your last 3 shifts in the cabin average 4 stars or more and you pay its €150 application fee. There's no going back. It has 7 floors and 25 guests a shift, pays half as much again in fares and tips (a €3 fare, tips up to €9), and its upgrades cost the full catalogue price, twice the cabin's. Guests there put up with a 50% longer ride, as the shaft is more than twice as tall. Your music box comes along; the call panel, cab size and doors start over. Ratings and shift numbers start afresh too. The hotels live in `scripts/hotels.gd`, as a list so more can be added.

At Pension Bellevue about 3 in 5 guests speak **Spanish**, and every hallway sign says what's on that floor (Lobby, Rooms, Restaurant, Pool, Spa, Rooftop bar). Click a Spanish guest and they answer in their speech bubble, with what you understood underneath. They speak real Spanish, but without lessons you only half-hear it: some words are lost ("…") and the rest come out spelled the way they sound ("kiero", "abitasion"). Guests are helpful, neutral or don't try. Now and then one mixes in an English clue word ("water", never the floor's name) or mimes something: they show their suitcase, eat from a plate, swim, rub a sore shoulder or drink from a glass, with what they do in brackets under their bubble. Click again to ask "Sorry, again?": it costs them 5 s of patience, and a helpful guest then holds up that many fingers, or points down for the ground floor. The character pack has no animations for these, so `scripts/gestures.gd` builds them from arm, head and torso turns, and puts fingers, a suitcase and a glass in the guest's hands while they use them. **Spanish lessons** (5 levels, €60 / €100 / €150 / €220 / €300) are sold in Pension Bellevue's staff room. Each one teaches a set of words: small words, common verbs, floors and numbers, hotel places. Words you know show spelled correctly, with their English underneath, and you miss fewer words. Lesson 5 makes you fluent, with full English subtitles. Lessons come with you to the next hotel. The lines and lessons live in `scripts/spanish.gd`, ported from the language-guessing prototype.

Pension Bellevue is as far as the demo goes. Its staff room offers the **Grand Hotel** (12 floors) next: with the same 4-star average over your last 3 shifts, and no fee, **Apply** shows the end screen ("To be continued: Grand Hotel") with your bank balance, Spanish lessons and music level. From there you can quit, or keep working at Pension Bellevue. The screen lives in `scripts/end_screen.gd`.

## Tests

Headless scripted tests drive the cab through its own buttons. `elevator_test` covers the lit buttons and the floor queue; `landing_door_test` checks the side-opening doors telescope, the landing doors hang behind the landing wall, follow the cab and block the shaft, and that the call button gets you back in when you've shut yourself out; `guest_loop_test` serves three guests in a row; `chat_test` covers chats, the shuffled reply choices and how each reply changes the tip; `shift_test` covers the clock, patience, pay and the end-of-shift report, then plays a whole shift with an autopilot; `career_test` carries the balance and the ratings through the save over four shifts; `staff_room_test` buys upgrades and checks what each one changes in the next shift; `hotel_test` moves up to Pension Bellevue and plays a ride there; `spanish_test` covers what you catch of Spanish per lesson, the speech bubble and its language badge, asking again and buying lessons; `end_screen_test` applies to the Grand Hotel from Pension Bellevue and checks the end screen; `guest_model_test` covers the guests' looks and animations; `gesture_test` checks every character's gestures and their poses, the props in their hands, and that a Spanish guest acts out their hint; `decor_test` checks every hallway is furnished, with nothing in the guests' way, and the music box at each level; `interior_test` checks each hotel's patterned walls and floors, that the trim is flat against the walls with no collision, the floor signs on their plates, and the cab's panelling, light and handrail, clear of the doors; `settings_test` pauses with Esc, moves the sliders, switches Smooth edges off and checks they are saved and used in the next shift; `controller_test` looks, walks, presses a button and works the pause menu with a simulated controller; `debug_test` checks what the debug options change, that the Debug section is only in debug builds, and that End shift now scores the shift as it stands; `asset_room_test` goes into the Asset room from a shift and from the staff room and back, finds every model under `assets/` in it by its name, plays a character's animations, the sounds, the elevator door models and a sample corner's doors, and walks faster with the Walk speed slider. The tests save the career and the settings to temporary files, never to your own. Run them all with the runner, which exits with 1 if any test fails:

```bash
tests/run.sh
```

Or run one or more by name:

```bash
tests/run.sh shift_test
```

Each test prints one line per check and ends with `<name>: PASS` or `<name>: <n> FAILED`. A script or engine error during the run also counts as a failed check, even if the test carries on past it. Warnings are printed but do not fail the test. The runner also fails a test that exits with 0 but prints no `PASS` line. That happens when the test script can't load, for example on a parse error: Godot prints the error and exits with 0 without running a check. On a fresh clone, run `godot --headless --path . --import` once before the first test run.

## Playthrough

`tools/playthrough.sh` plays the whole demo headless with an autopilot, from the first shift in the rustic cabin to the end screen, through the cab's buttons, the shift reports and the staff room. It prints every shift (stars, guests served and lost, money, upgrades) and then how many shifts and minutes the demo took and which Spanish lesson you were at, to check the demo against the spec: 45–60 minutes, ending around lesson 3. It takes a few minutes and exits with 1 if it never reaches the end screen. It is not one of the tests.

```bash
tools/playthrough.sh expert
```

The skill is `expert` (reacts at once and always knows a Spanish guest's floor) or `newcomer` (waits 3 s before every ride and often guesses a Spanish guest's floor wrong until the lessons help). In the staff room the autopilot saves for the next hotel, moves up as soon as it can, and buys music, Spanish lessons, a bigger cab and faster doors in a set order. The guests' schedules are random, so runs differ.

## Builds

`export_presets.cfg` has a preset per platform; `tools/build.sh` exports them into `build/` (ignored by git):

| Preset | Output | Notes |
|---|---|---|
| Windows | `build/windows/ElevatorPiccolo.exe` | x86_64, one file with the game packed in |
| macOS | `build/macos/ElevatorPiccolo.zip` | the `.app`, universal (Intel and Apple Silicon), signed ad hoc and not notarized: on another Mac, right-click > Open the first time |
| Linux | `build/linux/ElevatorPiccolo.x86_64` | x86_64, one file; for the Steam Deck later, so only built when named |

The tests are left out of every build. Building needs Godot's export templates for the editor's version, once per machine: in the editor, **Editor > Manage Export Templates > Download and Install** (about 1.3 GB). Then:

```bash
tools/build.sh
```

Or build one or more by preset name:

```bash
tools/build.sh macOS
```

Code signing for macOS (an Apple Developer account) and Steam builds come later.

## Performance

The spec asks for 60 fps on a typical Mac or Windows PC; the Steam Deck comes later. Start the game with `--benchmark` to measure it: it loads Pension Bellevue (the biggest hotel) with a temporary career and settings, so nothing of yours is touched, fills it with guests, gets them all talking, and measures four views for a few seconds each with vsync off. It prints frames per second, CPU and GPU time per frame and draw calls, then quits. On this machine, at 1920×1080:

```bash
tools/benchmark.sh
```

On Windows, from a terminal in the folder with the build:

```bash
ElevatorPiccolo.exe -- --benchmark
```

A frame at 60 fps has 16.7 ms. On an Apple M4 Pro at 1920×1080 the busiest view takes about 1.1 ms of GPU time with smooth edges on (about 0.85 ms with them off) and 0.2 ms of CPU time to draw, with 100–190 draw calls, which leaves plenty of room for slower computers; on one that still struggles, switching Smooth edges off saves about a fifth of the GPU time. The fps column stays around 150 on that Mac whatever the load, and now and then a view drops to 60–100 fps while its GPU time stays the same: that is the machine, not the game, so judge by the GPU and CPU time. Metal reports no GPU time, so `tools/benchmark.sh` uses Vulkan. The benchmark lives in `scripts/benchmark.gd`.
