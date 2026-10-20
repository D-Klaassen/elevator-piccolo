# Elevator music sourcing for a paid Steam game

Answers `.wayfinder/tickets/04-elevator-music.md`. Researched 2026-10-20 from primary license and terms pages. This is not legal advice.

## Options

| Option | Commercial use in a paid game | Attribution | Risks | Source |
|---|---|---|---|---|
| CC0 tracks | Yes, "for any purpose whatsoever, including ... commercial" | Not required | Trademark and patent rights are not waived, and third-party rights are not cleared. Check where each track came from. | [CC0 1.0 legal code](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en) |
| Kevin MacLeod (incompetech), CC BY | Yes | Required (credits) | Very widely used, so it sounds familiar. The paid "Standard License" that removes attribution has no price listed and does not mention games. | [incompetech licenses](https://incompetech.com/music/royalty-free/licenses/) |
| Pixabay Music | Allowed, and modifying it into new works is permitted | Not required | You may not redistribute it on a "Standalone basis", so no soundtrack DLC of unmodified tracks. Third-party rights may apply, and the binding text is the full ToS. | [Pixabay license summary](https://pixabay.com/service/license-summary/), [ToS](https://pixabay.com/service/terms/) |
| AI generation (e.g. Suno) | Paid Pro/Premier tiers only, and only for downloaded output. Free/Basic is personal use only. | n/a | Suno makes "no representation ... that any copyright will vest in any Output". Similar output may go to other users, so the game cannot claim exclusivity. Steam requires disclosing pre-generated AI content in the Content Survey. | [Suno ToS](https://suno.com/terms), [Steam Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey) |
| Commissioning a composer | Whatever the contract grants | Negotiable | Costs money. The contract should be a buyout or exclusive license that includes game distribution, trailers and soundtrack DLC. | (contract-based, no public source) |

Not verified: subscription libraries such as Epidemic Sound (their ToS URL returned 404). Read the game and software clauses and check whether the license survives cancellation before using one.

## Dynamic music (per upgrade/hotel)

Whichever source we pick, we need stems or loopable layers. Then the engine can crossfade or add layers per upgrade tier or hotel theme, for example bass and pads at tier 1 and adding melody and swing at higher tiers. CC0 and Pixabay allow modification, and CC BY allows it with credit. With a commission we can specify the stems in the contract.

## Recommendation

1. **Prototype/vertical slice:** use CC0 tracks, or Pixabay as a fallback, and keep a provenance log for each track (URL, license, date). This costs nothing and has no attribution burden.
2. **Ship:** commission a short loopable lounge suite with stems from a composer, under a buyout/exclusive license that covers soundtrack DLC. This gives a unique sound, clean rights and native layered dynamic music.
3. Avoid AI-generated music as the primary score: copyright is uncertain, there is no exclusivity and Steam requires a disclosure. Avoid incompetech unless we accept credits and that very familiar sound.
