# Engine choice for Elevator Piccolo

Answers [.wayfinder/tickets/01-engine-choice.md](../.wayfinder/tickets/01-engine-choice.md). Researched 2026-10-20 against primary sources.

## Recommendation: Godot 4 (currently 4.7), GDScript

For a two-person web-dev team building a small first-person interior on Steam (Windows, macOS, Steam Deck), Godot gives zero licensing cost forever, a small editor that's quick to learn, and a scripting language that suits people coming from the web. **Unity 6 is the strong runner-up.** Pick Unity instead if the art pipeline (no artist on the team) ends up relying heavily on store-bought characters, animation and dialogue plugins. **Unreal 5 is not recommended**: it's heavy, it means C++ or Blueprints, and its strengths (AAA rendering, large worlds) don't fit a single elevator cab.

## Comparison

| Criterion | Godot 4 | Unity 6 | Unreal 5 |
|---|---|---|---|
| Cost / license | MIT, free, no royalties; you only need to include the copyright/license notice [1] | Personal is free up to $200k revenue+funding; Runtime Fee canceled; splash screen optional in Unity 6 [2] | 5% royalty on lifetime gross above $1M per product; Epic Games Store revenue exempt [3] |
| Scripting | GDScript (Python-like, optional static typing) or C# (.NET 8+) [4] | C# | C++ / Blueprints |
| Learning curve for web devs | Low. Small editor, node/scene tree feels like a component tree | Medium. Large, mature docs and tutorial ecosystem | High |
| First-person small interior | More than enough (Forward+/Vulkan renderer) | More than enough | Overkill |
| macOS export | Official Universal 2 .app; signing and notarization need an Apple Developer ID, and it can be done from Win/Linux via rcodesign [5] | Supported | Supported (needs a Mac to build) |
| Steam Deck | Native Linux export (x86_64), Vulkan [4]. Valve recommends Vulkan and full controller support for Deck Verified [6] | Linux build or Proton | Linux build or Proton |
| Steamworks | Community GodotSteam extension (not first-party) | Community Steamworks.NET / Facepunch | Built-in Online Subsystem Steam |
| Asset store (low-poly hotel, characters) | Asset Library is small. Rely on engine-agnostic packs (glTF/FBX, e.g. Kenney, Quaternius, Synty) | Largest store; many low-poly + character packs | Fab marketplace, larger realistic assets |
| Dialogue tooling | Community plugins (Dialogue Manager, Dialogic); Ink via a plugin | Yarn Spinner, Ink, Dialogue System (paid) | Built-in dialogue assets are basic; plugins exist |

## Risks with Godot and how to handle them
- **Steamworks isn't first-party**: GodotSteam is widely used, but verify it supports the current 4.x at the time of integration (later map).
- **Asset Library is thin**: buy or download engine-agnostic glTF/FBX packs. Godot imports glTF natively.
- **C# can't export to the web** [4]. That doesn't matter for Steam, but GDScript is the default anyway.
- **macOS notarization** needs a paid Apple Developer account in every engine. Budget for it.

## Unity's license risk
The Runtime Fee was introduced and then withdrawn in 2024 [2], which shows terms can change. Godot's MIT license can't be revoked for versions you already have.

## Sources
1. Godot license: https://godotengine.org/license/
2. Unity pricing updates: https://unity.com/products/pricing-updates
3. Unreal Engine license: https://www.unrealengine.com/en-US/license (the page returned 403 to the fetcher; terms confirmed via Epic's search snippets, so double-check before deciding)
4. Godot list of features (4.7 docs): https://docs.godotengine.org/en/stable/about/list_of_features.html
5. Godot exporting for macOS: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html
6. Steam Deck recommendations (Steamworks): https://partner.steamgames.com/doc/steamdeck/recommendations

Not verified against primary sources: Steamworks/dialogue plugin compatibility and asset store inventory (marked as community/ecosystem judgements above).
