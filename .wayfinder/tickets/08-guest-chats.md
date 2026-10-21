---
title: How do guest chats work?
label: wayfinder:grilling
status: closed
assignee: D-Klaassen
blocked_by: [02,03]
---

## Question

Chats were switched off (commit 2fc1a7c) because answering felt clunky: a guest spoke up on their own a few seconds into the ride, a HUD form freed the mouse, you picked with 1–3 or a click within 10 s, and only then clicked again for their floor. There was no controller support. How should chats work so they feel like talking to that guest and fit the 5-minute playtest?

## Resolution

- **Trigger:** a chat starts only when you ask. The first time you click a guest (English or Spanish, in the hallway or in the cab), there's a 20% chance they strike up a chat before naming their floor. Asking again just gets the floor, never a second chat. Guests never start a chat on their own.
- **While you talk:** you can't walk away, and the view eases onto the guest's face (~0.3 s) and stays there. Every guest's patience, waiting or riding, pauses. The shift clock and the cab keep going. Esc or Start still pauses.
- **Where it shows:** the guest's line is in their own speech bubble. The replies are in a list low on the HUD with one highlighted, plus a bar for the time left.
- **Input:** W/S, the mouse wheel, the D-pad or the left stick move the highlight; a left click, E or A says it; 1–3 say one straight away. The mouse stays captured.
- **Time:** 6 s. Then you **blurt** out one of the replies on offer: good 30%, neutral 30%, bad 40%, a little worse than picking blind. The HUD shows what you said, and it counts as if you had picked it.
- **After the reply:** the guest reacts and then names their floor, in one bubble (*"Ha! Now that's service. Floor 2, please."*). A Spanish guest reacts in Spanish and then says their usual half-heard floor line, with the same clue-word and gesture chances as before.
- **Spanish chats:** you half-hear the line by your lessons, as with floor lines. Speaking comes harder than hearing, so the **speaking ladder** limits what you can say: 0–1 lessons, "Sí, sí…" (neutral) plus 1 of the 3 real replies; 2–3 lessons, "Sí, sí…" plus 2; 4–5 lessons, all 3. The real replies on offer are picked at random, so the good one may not be among them. They show in English: what you'd try to say.
- **Economy unchanged:** a good reply adds €2 to the tip (capped at €6), a neutral one nothing, a bad one halves it with a 50% chance of a complaint (−½ star). A complaint now shows on the HUD only; the guest's bubble keeps their reaction and floor.
- **Content:** the 8 English chats, with every reply at most 45 characters so it reads at a glance; 10 Spanish chats, with every word in them and in the Spanish reactions taught by one of the lessons.

## Future

- More chat lines in both languages: 8 English and 10 Spanish get repetitive over a 45–60 minute demo.
- Chats for the later hotels' languages, with their own speaking ladder.
- Chats that tie into the hotel (the floor they're going to, the time of day, the lunch rush).
