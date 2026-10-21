# Credits

Where every asset in the game comes from, and under which license. Add a row when you add an asset.

## Models

| Asset | By | License | Source | In the repo |
|---|---|---|---|---|
| Furniture Kit 2.0 (2018): 25 pieces, for the hallways (furniture and ceiling lamps) and the cab's music box | Kenney | CC0 1.0 (credit not required) | [kenney.nl/assets/furniture-kit](https://kenney.nl/assets/furniture-kit), downloaded 2026-10-20 | `assets/kenney/furniture-kit/` (the `.glb` files the game uses, `License.txt`) |
| Mini Characters 1.0 (2024): the 12 characters, used as guests (their waving, pointing, fingers and mimes, and the props for them, are made in code: `scripts/gestures.gd`) | Kenney | CC0 1.0 (credit not required) | [kenney.nl/assets/mini-characters](https://kenney.nl/assets/mini-characters), downloaded 2026-10-20 | `assets/kenney/mini-characters/` (`character-*.glb`, `Textures/colormap.png`, `License.txt`) |

## Textures

PBR texture sets at 1K (colour, normal, and an ORM map packed from their AO, roughness and metalness), fetched with `tools/pbr_texture.sh`. All CC0 1.0, which needs no credit, but we give it anyway.

| Set | Used for | By | Source | In the repo |
|---|---|---|---|---|
| Wood Trunk Wall (turned a quarter turn) | the cabin's log walls | Amal Kumar, Poly Haven | [polyhaven.com/a/wood_trunk_wall](https://polyhaven.com/a/wood_trunk_wall), downloaded 2026-10-21 | `assets/textures/wood_trunk_wall/` |
| Old Wooden Floor 01 | the cabin's plank floors | Charlotte Baglioni and Dario Barresi, Poly Haven | [polyhaven.com/a/old_wooden_floor_01](https://polyhaven.com/a/old_wooden_floor_01), downloaded 2026-10-21 | `assets/textures/old_wooden_floor_01/` |
| Hinoki Planks | the cabin's ceilings | Charlotte Baglioni, Poly Haven | [polyhaven.com/a/hinoki_planks](https://polyhaven.com/a/hinoki_planks), downloaded 2026-10-21 | `assets/textures/hinoki_planks/` |
| Walnut Veneer | the wooden trim: the cabin's skirting and door frames, the frame round the cab's door | Jenelle van Heerden, Poly Haven | [polyhaven.com/a/walnut_veneer](https://polyhaven.com/a/walnut_veneer), downloaded 2026-10-21 | `assets/textures/walnut_veneer/` |
| Dark Paneled Wood | Pension Bellevue's wainscot | Dimitrios Savva, Poly Haven | [polyhaven.com/a/dark_paneled_wood](https://polyhaven.com/a/dark_paneled_wood), downloaded 2026-10-21 | `assets/textures/dark_paneled_wood/` |
| Wooden Panels | the cab's walls | Dimitrios Savva, Poly Haven | [polyhaven.com/a/wooden_panels](https://polyhaven.com/a/wooden_panels), downloaded 2026-10-21 | `assets/textures/wooden_panels/` |
| Carpet 013 | Pension Bellevue's carpet | ambientCG (Lennart Demes) | [ambientcg.com/view?id=Carpet013](https://ambientcg.com/view?id=Carpet013), downloaded 2026-10-21 | `assets/textures/Carpet013/` |
| Wallpaper 001 A | Pension Bellevue's wallpaper | ambientCG (Lennart Demes) | [ambientcg.com/view?id=Wallpaper001A](https://ambientcg.com/view?id=Wallpaper001A), downloaded 2026-10-21 | `assets/textures/Wallpaper001A/` |
| Painted Plaster 017 | Pension Bellevue's and the cab's ceilings | ambientCG (Lennart Demes) | [ambientcg.com/view?id=PaintedPlaster017](https://ambientcg.com/view?id=PaintedPlaster017), downloaded 2026-10-21 | `assets/textures/PaintedPlaster017/` |
| Tiles 012 | the cab's chequered marble floor | ambientCG (Lennart Demes) | [ambientcg.com/view?id=Tiles012](https://ambientcg.com/view?id=Tiles012), downloaded 2026-10-21 | `assets/textures/Tiles012/` |
| Metal 009 | brushed steel: the doors, door jambs, header, floor displays and call plates; the dark thresholds | ambientCG (Lennart Demes) | [ambientcg.com/view?id=Metal009](https://ambientcg.com/view?id=Metal009), downloaded 2026-10-21 | `assets/textures/Metal009/` |
| Metal 042 A | brass: Pension Bellevue's trim, the cab's handrail and light | ambientCG (Lennart Demes) | [ambientcg.com/view?id=Metal042A](https://ambientcg.com/view?id=Metal042A), downloaded 2026-10-21 | `assets/textures/Metal042A/` |

## Sound

The call ding and the arrival chime are generated in code (`scripts/elevator.gd`).

## Music

Placeholders for the vertical slice, all CC0, which needs no credit, but we give it anyway. Before release a composer writes the real music (see `.wayfinder/tickets/04-elevator-music.md`).

| Track | By | License | Source | In the repo |
|---|---|---|---|---|
| Bossa Nova (8-bit bossa, about 1 min), music level 1 | Joth | CC0 1.0 | [opengameart.org/content/bossa-nova](https://opengameart.org/content/bossa-nova), downloaded 2026-10-21 | `assets/music/joth-bossa-nova.mp3` |
| Somewhere in the Elevator (about 1 min), music level 2 | Peachtea (You're Perfect Studio) | CC0 1.0 (one of the licenses on offer; CC-BY is another) | [opengameart.org/content/somewhere-in-the-elevator](https://opengameart.org/content/somewhere-in-the-elevator), downloaded 2026-10-21 | `assets/music/peachtea-somewhere-in-the-elevator.ogg` |
| Two Left Socks (bossa nova, about 3 min), music level 3 | congusbongus | CC0 1.0 | [opengameart.org/content/two-left-socks](https://opengameart.org/content/two-left-socks), downloaded 2026-10-21 | `assets/music/congusbongus-two-left-socks.ogg` |
