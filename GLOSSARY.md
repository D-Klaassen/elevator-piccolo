# Elevator Piccolo

A first-person game about running a hotel elevator: you take guests to their floors, shift after shift, and work your way up to better hotels.

## Language

### Assets

**Asset**:
Anything the game shows or plays that could be judged and changed on its own: a Kenney model, a piece built in code (cab, door panel, floor display, call button, lamp, trim), a hotel's surface pattern, or a sound made in code.
_Avoid_: Model (only one kind of asset), resource, prop

**Asset name**:
The readable name an asset goes by in the Asset room, such as `loungeSofa`, `door panel` or `Pension Bellevue wallpaper wall`; the name you quote to ask for a change. An asset that looks the same everywhere has the same name everywhere; one that differs per hotel carries the hotel's name.
_Avoid_: Asset code, asset ID

**Asset room**:
A room, reached from the Settings menu in debug builds, where every asset is laid out at in-game size to walk past, look at and comment on.
_Avoid_: Gallery, showroom, asset testing scene, test level

**Sample corner**:
A small piece of hallway in the Asset room built in one hotel's style, so that hotel's surfaces and trim are seen together.
_Avoid_: Swatch, style sample

### Debugging

**Debug options**:
Switches and actions in the Settings menu's Debug section, only in debug builds, that bend the rules for testing: Infinite money, Skip hotel requirements, game speed and End shift now. They are off again every time the game starts.
_Avoid_: Cheats, dev mode
