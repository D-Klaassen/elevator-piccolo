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
	"shows their suitcase", "", "", "mimes eating", "mimes swimming", "rubs their shoulders", "mimes drinking",
]
## Per floor: what a guest shows with their hands.
const FINGERS: Array[String] = [
	"points down", "holds up one finger", "holds up two fingers", "holds up three fingers",
	"holds up four fingers", "holds up five fingers", "holds up six fingers",
]
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
		"para": "for", "poco": "little", "mucha": "much",
	}},
	{"name": "common verbs", "words": {
		"quiero": "I want", "voy": "I go", "ir": "to go", "vamos": "we go", "nadar": "swim",
		"cenar": "dine", "tomar": "have", "relajarme": "relax", "tengo": "I have", "espera": "waits",
		"esta": "is",
	}},
	{"name": "floors and numbers", "words": {
		"primer": "first", "segundo": "second", "piso": "floor", "planta": "floor", "baja": "ground",
		"arriba": "up", "todo": "all",
	}},
	{"name": "hotel places", "words": {
		"recepcion": "reception", "habitacion": "room", "restaurante": "restaurant", "piscina": "pool",
		"azotea": "rooftop", "terraza": "terrace", "masaje": "massage", "hambre": "hunger",
		"ninos": "kids", "copa": "drink", "cita": "appointment", "taxi": "taxi",
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


static func _strip_accents(text: String) -> String:
	for accented: String in ACCENTS:
		text = text.replace(accented, ACCENTS[accented])
	return text
