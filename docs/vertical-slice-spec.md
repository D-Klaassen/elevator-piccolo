# Elevator Piccolo: vertical slice spec

The hand-off for building the first playable demo. Each section is a summary; the linked ticket in `.wayfinder/tickets/` holds the full decision.

## The game in one line

You are the elevator attendant (piccolo) in first person: greet guests, work out which floor they want (even when you don't speak their language), ride up with elevator music, earn fares and tips, buy upgrades and move up to bigger hotels.

## Engine

**Godot 4 with GDScript.** Builds for Windows and macOS; Steam Deck (Linux) later. Steam integration later via the GodotSteam add-on. Fallback: Unity 6. → [engine choice](../.wayfinder/tickets/01-engine-choice.md)

## Core loop

- A shift is one in-game day (08:00–18:00, about 8–10 real minutes) with a lunch rush.
- A call panel in the cab shows waiting floors; you pick the order.
- Everything goes through physical buttons: floor buttons, door open/close, and facing a guest to talk.
- The cab holds 3 guests at first, each going to their own floor.
- Pay: a near-nothing minimum wage + €2 fare per guest + a tip of up to €6 (wait time, right floor, friendliness).
- Hotel stars drop with complaints. Too low and you're fired (retry the shift); high enough and the next hotel opens up.

→ [core loop](../.wayfinder/tickets/02-core-loop.md)

## Languages

- You know English. English guests: greet, then you pick a friendly / neutral / rude reply.
- Spanish guests speak real Spanish that you only half-hear: missed words ("…") and words spelled the way they sound.
- Guests are helpful, neutral or don't try. Hints are hard: an occasional English clue word, mostly mimes; fingers when you ask a helpful guest again ("Sorry, again?" costs patience).
- Spanish takes 5 lessons. Each helps only a little, and the useful words come late. Known words appear spelled correctly, with their English underneath; lesson 5 gives full subtitles.

→ [language guessing](../.wayfinder/tickets/03-language-guessing.md) · playable reference: branch `prototype/language-guessing`

## Demo content

- **Hotels:** rustic cabin (3 floors, English only, ~15 guests per shift) → Pension Bellevue (7 floors, Spanish guests). Unlock: average ≥ 4 stars over the last 3 shifts + an application fee.
- **Upgrades** (bought in the staff room between shifts, visible in the cab):

| Upgrade | Levels | Pension Bellevue prices (cabin: half) |
|---|---|---|
| Music: starts silent, L1 installs a music box | 3 | €80 / €200 / €450 |
| Spanish lessons | 5 | €60 / €100 / €150 / €220 / €300 |
| Bigger cab (capacity 3 → 4 → 5) | 2 | €150 / €400 |
| Faster doors | 2 | €100 / €250 |

- Languages and music come with you to the next hotel; hardware starts over.
- **Length:** 45–60 minutes, ending around Spanish lesson 3 with "to be continued: Grand Hotel".
- **Art:** low-poly asset packs (Synty, Kenney); 4–6 guest models that wave, point and mime.
- **Music:** CC0 tracks for now; commission loopable stems before release. → [elevator music](../.wayfinder/tickets/04-elevator-music.md)
- **Tech:** save between shifts, volume and mouse sensitivity settings, controller support. No Steam features yet.

→ [upgrades](../.wayfinder/tickets/06-upgrades.md) · [hotel progression](../.wayfinder/tickets/07-hotel-progression.md) · [vertical slice](../.wayfinder/tickets/05-slice-scope.md)

## Done when

3–5 friends play without explanation, get the loop within 5 minutes and want "one more shift", and it runs at 60 fps on a typical Mac or Windows PC.

## Not in this demo

Faster motor, call panel+, the Grand Hotel and beyond, other languages, cosmetics, going back to earlier hotels, Steam integration, multiplayer.
