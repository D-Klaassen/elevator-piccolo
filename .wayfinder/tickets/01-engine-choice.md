---
title: Which game engine do we build on?
label: wayfinder:research
status: closed
assignee:
blocked_by: []
---

## Question

Compare Godot 4, Unity 6, Unreal 5 (and any serious alternative) for: first-person 3D in a small interior, a small web-dev team new to engines, learning curve and docs, scripting language, Steamworks + Steam Deck + macOS export, licensing/cost, asset store availability (low-poly hotel/characters), dialogue tooling. Recommend one.

## Resolution

**Godot 4 (4.7) with GDScript.** Free (MIT), native macOS (Intel+Apple Silicon) and Linux/Steam Deck exports, Python-like scripting suits web devs, a small first-person interior is easily within reach. Runner-up: Unity 6 (free under $200k), if we end up leaning hard on store-bought characters/animation. Unreal 5 rejected (too heavy, C++/Blueprints). Watch-outs: Steam integration is the community GodotSteam add-on, dialogue tools are community plugins, the asset library is small (use engine-agnostic low-poly packs), macOS signing needs an Apple Developer account. Unverified: plugin compatibility and the Unreal license terms.

Findings: branch `research/engine-choice`, file `research/engine-choice.md`.
