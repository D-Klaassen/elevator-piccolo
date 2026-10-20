---
title: How does guessing a guest's floor in an unknown language feel?
label: wayfinder:prototype
status: closed
assignee: D-Klaassen
blocked_by: []
---

## Question

Prototype the dialogue moment: guest speaks unreadable/foreign text with hints (gestures, numbers on fingers, items like a swimsuit → pool floor). Player picks a floor/reply. Does guessing feel fun, fair, and learnable?

## Resolution

Validated with a playable test (branch `prototype/language-guessing`, file `prototypes/PROTOTYPE-language-guessing.html`).

- **Known language:** the player starts with English. English guests are fully understood.
- **Foreign guests speak the real language** (Spanish first). Lines are correct, translatable Spanish, but the player only *half-hears* them: some words are missed ("…") and the rest are spelled the way they sound (no accents, "kiero", "abitasion").
- **Guest helpfulness varies:** helpful, neutral or doesn't try. Hints are deliberately hard: an occasional English *clue* word (never the floor name: "hungry", "water"), mostly mimes. Pointing or holding up fingers mainly comes when you ask a helpful guest again ("Sorry, again?" costs patience).
- **Learning a language takes 5 lessons** (an upgrade), not a toggle. Each lesson helps only a little, and the useful words come late: small words → verbs → floors & numbers → places → fluent. Known words appear spelled correctly in the speech bubble, with their English shown *under* the text (unknown words appear there as "…"). You miss fewer words per lesson but can still miss known ones until lesson 5, which gives the full English subtitle.
- Speech is shown in a speech bubble (not a bottom-of-screen subtitle).
