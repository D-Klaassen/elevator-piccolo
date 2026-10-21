class_name GuestManager
extends Node3D
## Spawns guests on random floors, lights the call panel, and walks guests in and out
## of the cab whenever its doors stand open on their floor. Guests who wait too long give up.
## Now and then a guest you ask for their floor strikes up a chat first and waits a moment
## for your [method reply]; while they do, every guest's patience waits too.
## When guests turn up is up to the [Shift]. Some guests speak Spanish: click them and they
## answer in a speech bubble, as much of it as your lessons let you catch. Clicking again
## asks "Sorry, again?", which costs them patience.

signal said(text: String)
signal delivered(guest: Guest)
signal gave_up(guest: Guest)
signal chatting(guest: Guest) ## a guest starts a chat and waits for your reply
signal replied(guest: Guest)
signal reply_closed ## the chat is over: answered, blurted out, or the guest left

const MAX_WAITING := 4
## Where guests wait in each hallway, relative to the floor (x, 0, z): in view of the open doors.
const WAIT_SPOTS: Array[Vector3] = [Vector3(-0.55, 0, 2.3), Vector3(0.55, 0, 2.3), Vector3(0, 0, 3.1)]
## Where guests stand in the cab, in cab coordinates, one slot per guest: enough for the
## biggest cab. A cab of [member capacity] uses the first that many.
const CAB_SLOTS: Array[Vector3] = [
	Vector3(0.55, 0, -0.55), Vector3(-0.55, 0, -0.55), Vector3(0.55, 0, 0.3),
	Vector3(0, 0, -0.72), Vector3(0.62, 0, -0.12),
]
const LANDING_Z := 1.8 ## just in front of the landing opening
const CAB_DOOR_Z := 0.5 ## just inside the cab doors
const HALL_END_Z := 4.4 ## where guests come from and go to
const REPLY_TIME := 6.0 ## seconds a guest waits for your reply by default, after which you blurt one out
## How likely you blurt out each kind of reply when time runs out, by [enum Guest.Reply]:
## a little worse than picking blind.
const BLURT_ODDS: Array[float] = [0.3, 0.3, 0.4]
const AGAIN_COST := 5.0 ## seconds of patience it costs a guest to say it again

## Multiplies every guest's patience, both waiting and riding.
@export var patience_scale := 1.0
## Multiplies how long guests put up with a ride, on top of [member patience_scale]. Music raises it.
@export var ride_patience_scale := 1.0
## How many guests fit in the cab. A bigger cab raises it, up to [constant CAB_SLOTS].
@export var capacity := 3
## Share of guests who strike up a chat when you first ask their floor.
@export var chat_chance := 0.2
## Share of guests who speak Spanish. Only for floors [constant Spanish.LINES] has lines for.
@export var spanish_share := 0.0
## Spanish lessons taken: how much of a Spanish guest you catch.
@export var spanish_lessons := 0
## Seconds a guest waits for your reply before you blurt one out; 0 waits for ever. Set from
## [method Settings.reply_seconds].
@export var reply_time := REPLY_TIME

var elevator: Elevator
var rng := RandomNumberGenerator.new()
## The guest who started a chat and waits for your reply, or null. Nobody's patience runs
## out meanwhile.
var talking_to: Guest

var _guests: Array[Guest] = []
var _reply_left := 0.0


func _process(delta: float) -> void:
	if talking_to == null: # while you talk, everyone's patience waits
		_lose_patience(delta)
	_update_calls()

	if talking_to and reply_time > 0.0:
		_reply_left -= delta
		if _reply_left <= 0.0:
			_blurt()

	if elevator.is_open_at_rest():
		_unload_and_load(elevator.current_floor)


func guests() -> Array[Guest]:
	return _guests.duplicate()


## Takes every guest out of the hotel at once, without a word: none pays or complains.
func clear() -> void:
	for guest in _guests.duplicate():
		_remove(guest)
	_update_calls()


## Says the reply at [param i] of [member Guest.offers] to the guest who is waiting for
## one; they react and name their floor. Does nothing when nobody is waiting.
func reply(i: int) -> void:
	if talking_to == null or i < 0 or i >= talking_to.offers.size():
		return
	var guest := talking_to
	var offer: Dictionary = guest.offers[i]
	guest.reply = offer.reply
	guest.answered = true
	_close_talk()
	_tell_floor(guest, offer.reply)
	replied.emit(guest)


## Which of [param offers] you blurt out when time runs out, by [constant BLURT_ODDS].
static func blurt(offers: Array[Dictionary], r: RandomNumberGenerator) -> int:
	var odds := PackedFloat32Array(offers.map(func(o: Dictionary) -> float: return BLURT_ODDS[o.reply]))
	return r.rand_weighted(odds)


## Spawns a guest going to a random other floor, on floor [param home] or, when that is -1,
## on a random floor with a free spot.
func spawn_random(home := -1) -> Guest:
	if _guests.filter(func(g: Guest) -> bool: return _is_calling(g)).size() >= MAX_WAITING:
		return null
	if home < 0:
		var floors := range(elevator.floor_count).filter(func(f: int) -> bool: return _free_wait_spot(f) >= 0)
		if floors.is_empty():
			return null
		home = floors[rng.randi_range(0, floors.size() - 1)]
	var destination := rng.randi_range(0, elevator.floor_count - 2)
	if destination >= home:
		destination += 1
	return spawn_guest(home, destination)


## Spawns a guest at the end of the [param home] hallway who walks to a free spot by the
## elevator and calls it. Returns null when that hallway has no free spot.
func spawn_guest(home: int, destination: int) -> Guest:
	var spot := _free_wait_spot(home)
	if spot < 0:
		return null
	var guest := Guest.new()
	guest.setup(home, destination, _pick_model(), Guest.LINES.pick_random())
	if destination < Spanish.LINES.size() and rng.randf() < spanish_share:
		guest.language = "es"
		guest.helpfulness = Spanish.HELPFULNESS.keys()[rng.randi_range(0, Spanish.HELPFULNESS.size() - 1)]
		guest.spanish_line = Spanish.LINES[destination][rng.randi_range(0, 1)]
		guest.display_name = "Spanish guest (click to talk)"
	if rng.randf() < chat_chance:
		guest.chat = (Spanish.CHATS if guest.language == "es" else Guest.CHATS).pick_random()
		guest.reply_order.shuffle()
	var temperament: Dictionary = Guest.TEMPERAMENTS[rng.randi_range(0, Guest.TEMPERAMENTS.size() - 1)]
	guest.temperament = temperament.name
	guest.patience = temperament.wait * patience_scale
	guest.ride_patience = temperament.ride * patience_scale * ride_patience_scale
	guest.wait_spot = spot
	add_child(guest)
	var y := _floor_y(home)
	guest.global_position = Vector3(_random_side(), y, HALL_END_Z)
	guest.talked_to.connect(_on_talked_to.bind(guest))
	_guests.append(guest)

	var wait_at := WAIT_SPOTS[spot] + Vector3(0, y, 0)
	guest.walk([wait_at], _on_waiting.bind(guest))
	_update_calls()
	elevator.ding()
	return guest


## One of [constant Guest.MODELS] that no guest in the hotel is wearing right now, if there
## is one, so you don't meet twins.
func _pick_model() -> String:
	var worn := _guests.map(func(g: Guest) -> String: return g.model)
	var free := Guest.MODELS.filter(func(m: String) -> bool: return not worn.has(m))
	var models: Array = free if not free.is_empty() else Guest.MODELS
	return models[rng.randi_range(0, models.size() - 1)]


## A chatty guest you ask for the first time strikes up their chat. Otherwise a Spanish
## guest answers in a speech bubble (an English one names their floor themselves). Asking a
## Spanish guest again costs them patience.
func _on_talked_to(guest: Guest) -> void:
	if guest.has_chat_to_start():
		if talking_to == null:
			_start_chat(guest)
		else:
			_tell_floor(guest) # one chat at a time: they keep theirs for later
		return
	if guest.language != "es":
		return
	var again := guest.asked > 1
	if again:
		said.emit('You: "Sorry, again?"')
		if _is_calling(guest):
			guest.waited += AGAIN_COST
		elif _is_aboard(guest):
			guest.rode += AGAIN_COST
	_tell_floor(guest, -1, again)


## [param guest] names their floor, after their reaction to your reply when [param reaction]
## is one of [enum Guest.Reply]. A Spanish guest answers with what you catch of their line,
## now and then an English clue word, and maybe a gesture; asked [param again], a helpful
## guest shows it on their fingers.
func _tell_floor(guest: Guest, reaction := -1, again := false) -> void:
	if guest.language != "es":
		var text := guest.line
		if reaction >= 0:
			text = "%s %s" % [Guest.REACTIONS[reaction].pick_random(), text]
		guest.say(text)
		return
	var line := guest.spanish_line
	if reaction >= 0:
		var said_back: Array = Spanish.REACTIONS[reaction][rng.randi_range(0, Spanish.REACTIONS[reaction].size() - 1)]
		line = [said_back[0] + " " + line[0], said_back[1] + " " + line[1]]
	var help: Dictionary = Spanish.HELPFULNESS[guest.helpfulness]
	var heard := Spanish.hear(line, spanish_lessons, rng)
	var text: String = heard.heard
	if rng.randf() < help.clue:
		text += "  %s %s" % [Spanish.MISS, Spanish.CLUES[guest.destination].pick_random()]
	# What they show you, if anything: [what you see, their gesture].
	var d := guest.destination
	var shown := []
	if again and guest.helpfulness == "helpful":
		shown = [Spanish.FINGERS[d], Gestures.fingers(d)]
	elif rng.randf() < help.gesture:
		if Spanish.MIMES[d] and rng.randf() >= 0.3:
			shown = [Spanish.MIMES[d], Spanish.MIME_GESTURES[d]]
		else:
			shown = [Spanish.FINGERS[d], Gestures.fingers(d)]
	var under: String = heard.understood
	if shown:
		under += ("\n" if under else "") + "(%s)" % shown[0]
		guest.act(shown[1])
	guest.say(text, under)


func _on_waiting(guest: Guest) -> void:
	guest.state = Guest.State.WAITING
	guest.face(Vector3(0, guest.global_position.y, 0))


func _lose_patience(delta: float) -> void:
	for guest in _guests.duplicate():
		if _is_calling(guest):
			guest.waited += delta
			if guest.waited >= guest.patience:
				_give_up(guest)
		elif _is_aboard(guest) and not guest.fed_up:
			guest.rode += delta
			if guest.rode >= guest.ride_patience:
				guest.fed_up = true # they get out at the next open doors
				gave_up.emit(guest)


func _give_up(guest: Guest) -> void:
	_forget_talk(guest)
	guest.state = Guest.State.LEAVING
	guest.wait_spot = -1
	_update_calls()
	gave_up.emit(guest)
	guest.walk([Vector3(_random_side(), guest.global_position.y, HALL_END_Z)], _remove.bind(guest))


func _unload_and_load(f: int) -> void:
	for guest in _guests.duplicate():
		if guest.state == Guest.State.RIDING and (guest.destination == f or guest.fed_up):
			_unload(guest)

	var delay := 0.0
	for guest in _guests:
		if guest.state != Guest.State.WAITING or guest.home_floor != f:
			continue
		var slot := _free_cab_slot()
		if slot < 0:
			break
		_board(guest, slot, delay)
		delay += 0.6


func _board(guest: Guest, slot: int, delay: float) -> void:
	guest.state = Guest.State.BOARDING
	guest.wait_spot = -1
	guest.cab_slot = slot
	elevator.door_blockers += 1
	_update_calls()

	var cab := elevator.get_cab()
	guest.reparent(cab)
	var y := guest.global_position.y
	var path: Array[Vector3] = [Vector3(0, y, LANDING_Z), Vector3(0, y, CAB_DOOR_Z), cab.to_global(CAB_SLOTS[slot])]
	guest.walk(path, _on_boarded.bind(guest), delay)


func _on_boarded(guest: Guest) -> void:
	guest.state = Guest.State.RIDING
	elevator.door_blockers -= 1
	guest.face(guest.global_position + Vector3.BACK) # face the doors (+Z)


func _unload(guest: Guest) -> void:
	_forget_talk(guest)
	guest.state = Guest.State.LEAVING
	guest.cab_slot = -1
	elevator.door_blockers += 1
	if not guest.fed_up:
		delivered.emit(guest)

	guest.reparent(self)
	var y := guest.global_position.y
	var path: Array[Vector3] = [Vector3(0, y, CAB_DOOR_Z), Vector3(0, y, LANDING_Z)]
	guest.walk(path, _on_left_cab.bind(guest))


func _on_left_cab(guest: Guest) -> void:
	elevator.door_blockers -= 1
	var y := guest.global_position.y
	guest.walk([Vector3(_random_side(), y, HALL_END_Z)], _remove.bind(guest))


func _remove(guest: Guest) -> void:
	_forget_talk(guest)
	_guests.erase(guest)
	guest.queue_free()


## [param guest] says their chat line, as much of it as you catch, and waits for your reply.
func _start_chat(guest: Guest) -> void:
	talking_to = guest
	guest.chatted = true
	guest.offers = _offers_for(guest)
	_reply_left = reply_time
	if guest.language == "es":
		var heard := Spanish.hear(guest.chat.line, spanish_lessons, rng)
		guest.say(heard.heard, heard.understood)
	else:
		guest.say(guest.chat.line)
	chatting.emit(guest)


## The replies you can give [param guest], in their shuffled order. In Spanish you can say
## only as many as your lessons allow, plus a nod along.
func _offers_for(guest: Guest) -> Array[Dictionary]:
	var count := Guest.Reply.size()
	if guest.language == "es":
		count = Spanish.replies_you_can_say(spanish_lessons)
	var offers: Array[Dictionary] = []
	for r in guest.reply_order.slice(0, count):
		offers.append({"reply": r, "text": guest.reply_line(r)})
	if count < Guest.Reply.size():
		offers.insert(rng.randi_range(0, offers.size()), {"reply": Guest.Reply.NEUTRAL, "text": Spanish.SI_SI})
	return offers


## Time's up: you blurt out one of the replies, a little more often a bad one.
func _blurt() -> void:
	var i := blurt(talking_to.offers, rng)
	said.emit('You: "%s"' % talking_to.offers[i].text)
	reply(i)


func _close_talk() -> void:
	talking_to = null
	reply_closed.emit()


## Ends the chat when [param guest] leaves before replying. It counts as neutral.
func _forget_talk(guest: Guest) -> void:
	if talking_to == guest:
		_close_talk()


func _update_calls() -> void:
	for f in elevator.floor_count:
		var calling := _guests.filter(func(g: Guest) -> bool: return g.home_floor == f and _is_calling(g))
		if calling.is_empty():
			elevator.set_call(f, Elevator.CallLamp.OFF)
		elif calling.any(func(g: Guest) -> bool: return g.is_impatient()):
			elevator.set_call(f, Elevator.CallLamp.BLINKING)
		else:
			elevator.set_call(f, Elevator.CallLamp.ON)


func _is_calling(guest: Guest) -> bool:
	return guest.state == Guest.State.ARRIVING or guest.state == Guest.State.WAITING


func _is_aboard(guest: Guest) -> bool:
	return guest.state == Guest.State.BOARDING or guest.state == Guest.State.RIDING


func _free_wait_spot(f: int) -> int:
	for spot in WAIT_SPOTS.size():
		if not _guests.any(func(g: Guest) -> bool: return g.home_floor == f and g.wait_spot == spot):
			return spot
	return -1


func _free_cab_slot() -> int:
	for slot in mini(capacity, CAB_SLOTS.size()):
		if not _guests.any(func(g: Guest) -> bool: return g.cab_slot == slot):
			return slot
	return -1


func _floor_y(f: int) -> float:
	return f * Elevator.FLOOR_HEIGHT


func _random_side() -> float:
	return 2.3 if rng.randf() < 0.5 else -2.3
