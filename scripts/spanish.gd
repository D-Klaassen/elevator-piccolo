class_name Spanish
## What Spanish guests say and how much of it you catch. They speak real Spanish, but
## without lessons you only half-hear it: some words are lost ("…") and the rest come out
## spelled the way they sound. Each of the 5 lessons teaches a set of words, which then
## show spelled correctly with their English underneath; the fifth gives full subtitles.
## Hints are hard: an occasional English clue word, mostly mimes, and fingers when you ask
## a helpful guest again. Ported from the language-guessing prototype.

## Per floor of Pension Bellevue: two lines, each as [Spanish, English].
const LINES: Array[Array] = [
	[["Quiero ir a la recepción, por favor.", "I want to go to reception, please."],
		["Voy a la planta baja, me espera un taxi.", "I'm going to the ground floor, a taxi is waiting for me."]],
	[["Mi habitación está en el primer piso.", "My room is on the first floor."],
		["Al primer piso, gracias.", "To the first floor, thanks."]],
	[["Mi habitación está en el segundo piso.", "My room is on the second floor."],
		["Segundo piso, por favor.", "Second floor, please."]],
	[["Vamos al restaurante, tengo mucha hambre.", "We're going to the restaurant, I'm very hungry."],
		["¿Dónde se puede cenar aquí?", "Where can you have dinner here?"]],
	[["¿Dónde está la piscina? Quiero nadar.", "Where is the pool? I want to swim."],
		["Voy a la piscina con los niños.", "I'm going to the pool with the kids."]],
	[["Tengo una cita para un masaje.", "I have an appointment for a massage."],
		["Quiero relajarme un poco, por favor.", "I want to relax a little, please."]],
	[["Quiero tomar una copa en la azotea.", "I want to have a drink on the rooftop."],
		["Arriba del todo, a la terraza.", "All the way up, to the terrace."]],
]
## Per floor: English clue words a guest may mix in. Never the floor's name.
const CLUES: Array[Array] = [
	["taxi", "bags", "bye bye"], ["sleep", "bed"], ["sleep", "bed"], ["hungry", "dinner"],
	["water", "towel"], ["tired", "back hurts"], ["drink", "up, up", "sky"],
]
## Per floor: what a guest mimes, or "" when there is nothing to mime.
const MIMES: Array[String] = [
	"shows their suitcase", "", "", "mimes eating", "mimes swimming", "rubs their shoulder", "mimes drinking",
]
## Per floor: the [Gestures] animation for the mime in [constant MIMES].
const MIME_GESTURES: Array[String] = [
	Gestures.SUITCASE, "", "", Gestures.EATING, Gestures.SWIMMING, Gestures.SHOULDER, Gestures.DRINKING,
]
## Per floor: what a guest shows with their hands ([method Gestures.fingers] acts it out).
const FINGERS: Array[String] = [
	"points down", "holds up one finger", "holds up two fingers", "holds up three fingers",
	"holds up four fingers", "holds up five fingers", "holds up six fingers",
]
## What a chatty Spanish guest says, as [Spanish, English], and the replies you can try,
## in [enum Guest.Reply] order. They show in English: what you'd try to say. More will
## come, see [code].wayfinder/tickets/08-guest-chats.md[/code].
const CHATS: Array[Dictionary] = [
	{"line": ["¡Qué calor hace hoy!", "It's so hot today!"], "replies": [
		"The pool is nice and cool right now.",
		"Yes, it's warm.",
		"Tomorrow will be even hotter, they say.",
	]},
	{"line": ["Es mi primera vez en este hotel.", "It's my first time at this hotel."], "replies": [
		"Welcome! Try the rooftop at sunset.",
		"I hope you like it.",
		"The rooms are a bit small, I'm afraid.",
	]},
	{"line": ["Estoy muy cansado, el viaje fue largo.", "I'm very tired, the journey was long."], "replies": [
		"Then let's get you upstairs quickly.",
		"Long trips are tiring.",
		"Where did you travel from? Tell me all!",
	]},
	{"line": ["Mis hijos no quieren dormir.", "My kids don't want to sleep."], "replies": [
		"A swim tires them out, trust me.",
		"Kids are like that.",
		"Yes, we can hear them all over.",
	]},
	{"line": ["¿Hay un buen restaurante cerca?", "Is there a good restaurant nearby?"], "replies": [
		"Ours does a great paella. Book a table!",
		"There are a few in town.",
		"I just eat in the staff room.",
	]},
	{"line": ["Perdí mi llave otra vez.", "I lost my key again."], "replies": [
		"Reception will make you a new one.",
		"That happens.",
		"Again? That will cost you, I think.",
	]},
	{"line": ["¡Me encanta la música de este ascensor!", "I love the music in this elevator!"], "replies": [
		"Thank you! I picked it myself.",
		"It's not bad.",
		"Really? I can't stand it anymore.",
	]},
	{"line": ["Tengo prisa, mi taxi ya está aquí.", "I'm in a hurry, my taxi is already here."], "replies": [
		"Hold on, we're nearly there.",
		"Okay.",
		"Did you know this lift is a century old?",
	]},
	{"line": ["¿A qué hora cierra la piscina?", "What time does the pool close?"], "replies": [
		"At eight. Plenty of time for a swim.",
		"Best to ask at reception.",
		"Early. Too early, if you ask me.",
	]},
	{"line": ["Hace mucho frío en mi habitación.", "It's very cold in my room."], "replies": [
		"I'll have a heater sent up right away.",
		"Try the thermostat.",
		"Wear a jumper, that's what I do.",
	]},
]
## What a Spanish guest says back, by how well your reply landed, as [Spanish, English].
const REACTIONS: Array[Array] = [
	[["¡Muy amable!", "Very kind!"], ["¡Qué bien!", "How nice!"]],
	[["Vale.", "Okay."], ["Bueno.", "Well."]],
	[["¿Perdón?", "Pardon?"], ["¡Qué grosero!", "How rude!"]],
]
## What you can always say in a Spanish chat, however few lessons you've had. Counts as neutral.
const SI_SI := "Sí, sí… (nod along)"
## How many of a chat's real replies you can say, by lessons taken: speaking comes harder
## than hearing.
const SAYABLE: Array[int] = [1, 1, 2, 2, 3, 3]
## How hard a guest tries: the chance of an English clue word and of a gesture.
const HELPFULNESS := {
	"helpful": {"clue": 0.35, "gesture": 0.4},
	"neutral": {"clue": 0.15, "gesture": 0.1},
	"doesn't try": {"clue": 0.0, "gesture": 0.0},
}
## What each lesson teaches, as words (lowercase, no accents) and their English. The fifth
## lesson teaches no words of its own: it makes you fluent.
const LESSONS: Array[Dictionary] = [
	{"name": "small words", "words": {
		"por": "for", "favor": "please", "gracias": "thanks", "donde": "where", "mi": "my", "la": "the",
		"el": "the", "al": "to the", "a": "to", "en": "in", "un": "a", "una": "a", "con": "with",
		"los": "the", "del": "of the", "me": "me", "se": "one", "puede": "can", "aqui": "here",
		"para": "for", "poco": "little", "mucha": "much", "que": "what", "hoy": "today",
		"muy": "very", "este": "this", "mis": "my", "no": "not", "de": "of", "ya": "already",
		"otra": "another", "vez": "time", "cerca": "near", "mucho": "very", "vale": "okay",
		"bueno": "well", "bien": "nice", "perdon": "pardon", "amable": "kind", "grosero": "rude",
	}},
	{"name": "common verbs", "words": {
		"quiero": "I want", "voy": "I go", "ir": "to go", "vamos": "we go", "nadar": "swim",
		"cenar": "dine", "tomar": "have", "relajarme": "relax", "tengo": "I have", "espera": "waits",
		"esta": "is", "hace": "it is", "es": "is", "estoy": "I am", "fue": "was",
		"quieren": "want", "dormir": "sleep", "hay": "is there", "perdi": "I lost",
		"encanta": "love", "cierra": "closes",
	}},
	{"name": "floors and numbers", "words": {
		"primer": "first", "segundo": "second", "piso": "floor", "planta": "floor", "baja": "ground",
		"arriba": "up", "todo": "all", "primera": "first", "hora": "time",
	}},
	{"name": "hotel places", "words": {
		"recepcion": "reception", "habitacion": "room", "restaurante": "restaurant", "piscina": "pool",
		"azotea": "rooftop", "terraza": "terrace", "masaje": "massage", "hambre": "hunger",
		"ninos": "kids", "copa": "drink", "cita": "appointment", "taxi": "taxi", "hotel": "hotel",
		"ascensor": "elevator", "llave": "key", "musica": "music", "hijos": "kids", "viaje": "trip",
		"calor": "heat", "frio": "cold", "cansado": "tired", "largo": "long", "buen": "good",
		"prisa": "hurry",
	}},
	{"name": "fluent: full subtitles", "words": {}},
]
const MISS := "…"
const ACCENTS := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}


## [param word] in lowercase without accents or punctuation, the way [constant LESSONS] lists it.
static func normalize(word: String) -> String:
	var plain := _strip_accents(word.to_lower())
	for mark in ["¿", "¡", ".", ",", "?", "!"]:
		plain = plain.replace(mark, "")
	return plain


## The English of [param word] when one of the first [param lessons] lessons taught it, else "".
static func known_meaning(word: String, lessons: int) -> String:
	for i in mini(lessons, LESSONS.size() - 1):
		var meaning: String = LESSONS[i].words.get(normalize(word), "")
		if meaning:
			return meaning
	return ""


## How [param word] sounds to someone who doesn't know it: no accents, spelled by ear.
static func sound_out(word: String) -> String:
	var p := word.to_lower().replace("ñ", "ny")
	p = _strip_accents(p).replace("¿", "").replace("¡", "")
	if p.begins_with("h"):
		p = p.substr(1)
	for pair in [["qu", "k"], ["ll", "y"], ["v", "b"], ["z", "s"], ["j", "h"], ["cion", "sion"]]:
		p = p.replace(pair[0], pair[1])
	return p


## What you catch of [param line] ([Spanish, English]) after [param lessons] lessons:
## [code]heard[/code], the Spanish as it reached you, and [code]understood[/code], the
## English of the words you know with "…" for the rest, or "" when you know none.
static func hear(line: Array, lessons: int, rng: RandomNumberGenerator) -> Dictionary:
	if lessons >= LESSONS.size():
		return {"heard": line[0], "understood": line[1]}
	var fade := 1.0 - lessons / 8.0
	var heard: PackedStringArray = []
	var understood: PackedStringArray = []
	var knows_any := false
	for word: String in line[0].split(" "):
		if rng.randf() < 0.25 * fade:
			heard.append(MISS)
			understood.append(MISS)
			continue
		var meaning := known_meaning(word, lessons)
		if meaning:
			heard.append(word)
			understood.append(meaning)
			knows_any = true
		else:
			var plain := _strip_accents(word.to_lower()).replace("¿", "").replace("¡", "")
			heard.append(sound_out(word) if rng.randf() < 0.6 * fade else plain)
			understood.append(MISS)
	var english := " ".join(understood) if knows_any else ""
	while english.contains("%s %s" % [MISS, MISS]):
		english = english.replace("%s %s" % [MISS, MISS], MISS)
	return {"heard": " ".join(heard), "understood": english}


## How many of a chat's real replies you can say after [param lessons] lessons.
static func replies_you_can_say(lessons: int) -> int:
	return SAYABLE[clampi(lessons, 0, SAYABLE.size() - 1)]


static func _strip_accents(text: String) -> String:
	for accented: String in ACCENTS:
		text = text.replace(accented, ACCENTS[accented])
	return text
