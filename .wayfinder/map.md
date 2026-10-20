---
label: wayfinder:map
title: Elevator Piccolo — vertical slice spec
---

## Destination

A game design + tech spec for a playable **vertical slice**: engine chosen, first-person 3D elevator, one hotel, the greet → chat → guess floor → ride (with elevator music) → drop off loop, tips/speed economy, one foreign-language barrier, a few upgrades. Ready to hand off and start building.

## Notes

- Team: Dion + Thijs, web-dev background, new to game engines but want to learn a real one. No dedicated artist.
- Perspective: **3D first-person** — you are standing in the elevator.
- Chat: **scripted dialogue choices**; foreign languages shown as unreadable text/gibberish + gestures/hints you must interpret. LLM-driven guests = possible stretch goal, not slice.
- Platforms: Steam on Windows, macOS, Steam Deck. Prefer free engine; revenue share only with high threshold.
- Tracker: local markdown in `.wayfinder/` (tickets in `tickets/`, blocking via `blocked_by:` frontmatter, claim via `assignee:`).
- Each ticket session: call `grilling` + `domain-modeling` skills when in doubt.

## Decisions so far

- [Which game engine do we build on?](tickets/01-engine-choice.md): Godot 4 + GDScript; Unity 6 as fallback if we lean heavily on store assets
- [How do we source elevator music we may ship on Steam?](tickets/04-elevator-music.md): CC0/Pixabay for prototyping, commissioned stems with full rights for release
- [What is the core loop and how is a shift scored?](tickets/02-core-loop.md): a timed day shift, call panel, physical buttons, capacity 3, fare plus tip, star rating unlocks hotels, music adds patience
- [How does guessing a guest's floor in an unknown language feel?](tickets/03-language-guessing.md): real misheard Spanish, hard indirect hints, 5 lessons that each help a little, known-word translations under the text
- [Which upgrades exist and what do they cost?](tickets/06-upgrades.md): minimum wage + fares/tips (~€80–180 per shift), 6 upgrade lines incl. music that starts silent, staff-room shop, languages and music carry over between hotels

## Not yet specified

- Language roster: which languages beyond Spanish, and which hotel introduces each.
- Guest variety: archetypes, patience, VIPs, groups, multiple guests with different floors in one ride.
- Art pipeline: asset sources (store packs vs Blender), characters and animation for guests.
- Save system, settings, controller/Steam Deck input.
- Steam release: Steamworks integration, store page, demo, pricing (beyond the slice — likely next map).

## Out of scope

- Multiplayer.
- Cosmetics (uniform, cab decoration): no gameplay effect, decided against for the demo in the upgrades ticket.
