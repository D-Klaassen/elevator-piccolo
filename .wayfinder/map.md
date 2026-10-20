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

## Not yet specified

- Progression: upgrade catalogue (faster doors, phrasebooks/language lessons, better music, bigger cab), and what "moving to a bigger hotel" means mechanically.
- Language system depth: how many languages, how learning works (exposure vs buying), how guesses are scored.
- Guest variety: archetypes, patience, VIPs, groups, multiple guests with different floors in one ride.
- Art pipeline: asset sources (store packs vs Blender), characters and animation for guests.
- Save system, settings, controller/Steam Deck input.
- Steam release: Steamworks integration, store page, demo, pricing (beyond the slice — likely next map).

## Out of scope

- Multiplayer.
