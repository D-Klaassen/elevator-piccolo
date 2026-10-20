class_name GuestManager
extends Node3D
## Spawns guests on random floors, lights the call panel, and walks guests in and out
## of the cab whenever its doors stand open on their floor. Guests who wait too long give up.
## Guests greet you one at a time and wait a moment for your [method reply].
## When guests turn up is up to the [Shift].

signal said(text: String)
signal delivered(guest: Guest)
signal gave_up(guest: Guest)
signal greeted(guest: Guest) ## a guest greets you and waits for your reply
signal replied(guest: Guest)
signal reply_closed ## the reply choices can go: answered, no answer in time, or the guest left

const MAX_WAITING := 4
## Where guests wait in each hallway, relative to the floor (x, 0, z): in view of the open doors.
const WAIT_SPOTS: Array[Vector3] = [Vector3(-0.55, 0, 2.3), Vector3(0.55, 0, 2.3), Vector3(0, 0, 3.1)]
## Where guests stand in the cab, in cab coordinates. One slot per guest, so this is the capacity.
const CAB_SLOTS: Array[Vector3] = [Vector3(0.55, 0, -0.55), Vector3(-0.55, 0, -0.55), Vector3(0.55, 0, 0.3)]
const LANDING_Z := 1.8 ## just in front of the landing opening
const CAB_DOOR_Z := 0.5 ## just inside the cab doors
const HALL_END_Z := 4.4 ## where guests come from and go to
const REPLY_TIME := 10.0 ## seconds a guest waits for your reply; no reply counts as neutral

## Multiplies every guest's patience. Upgrades (music and the like) will raise it.
@export var patience_scale := 1.0

var elevator: Elevator
var rng := RandomNumberGenerator.new()
## The guest who greeted you and waits for your reply, or null.
var talking_to: Guest

var _guests: Array[Guest] = []
var _greet_queue: Array[Guest] = [] ## guests who want to greet you once [member talking_to] is done
var _reply_left := 0.0


func _process(delta: float) -> void:
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
	_update_calls()

	if talking_to:
		_reply_left -= delta
		if _reply_left <= 0.0:
			_close_talk() # no answer: neutral

	if elevator.is_open_at_rest():
		_unload_and_load(elevator.current_floor)


func guests() -> Array[Guest]:
	return _guests.duplicate()


## Answers the guest who is waiting for a reply. Does nothing when nobody is.
func reply(choice: Guest.Reply) -> void:
	if talking_to == null:
		return
	var guest := talking_to
	guest.reply = choice
	guest.answered = true
	said.emit('You: "%s"' % guest.reply_line(choice))
	replied.emit(guest)
	_close_talk()


## Spawns a guest on a random floor with a free spot, going to another random floor.
func spawn_random() -> Guest:
	if _guests.filter(func(g: Guest) -> bool: return _is_calling(g)).size() >= MAX_WAITING:
		return null
	var floors := range(elevator.floor_count).filter(func(f: int) -> bool: return _free_wait_spot(f) >= 0)
	if floors.is_empty():
		return null
	var home: int = floors[rng.randi_range(0, floors.size() - 1)]
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
	guest.setup(home, destination, Color.from_hsv(rng.randf(), 0.45, 0.85), Guest.LINES.pick_random())
	guest.greeting = Guest.GREETINGS.pick_random()
	var temperament: Dictionary = Guest.TEMPERAMENTS[rng.randi_range(0, Guest.TEMPERAMENTS.size() - 1)]
	guest.temperament = temperament.name
	guest.patience = temperament.wait * patience_scale
	guest.ride_patience = temperament.ride * patience_scale
	guest.wait_spot = spot
	add_child(guest)
	var y := _floor_y(home)
	guest.global_position = Vector3(_random_side(), y, HALL_END_Z)
	guest.spoke.connect(func(text: String) -> void: said.emit('Guest: "%s"' % text))
	guest.talk_requested.connect(_greet.bind(guest, true))
	_guests.append(guest)

	var wait_at := WAIT_SPOTS[spot] + Vector3(0, y, 0)
	guest.walk([wait_at], _on_waiting.bind(guest))
	_update_calls()
	elevator.ding()
	return guest


func _on_waiting(guest: Guest) -> void:
	guest.state = Guest.State.WAITING
	guest.face(Vector3(0, guest.global_position.y, 0))


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
	_greet(guest)


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


## Lines [param guest] up to greet you, or at the front of the line when you clicked them.
func _greet(guest: Guest, clicked := false) -> void:
	if guest.greeted:
		return
	_greet_queue.erase(guest)
	if clicked:
		_greet_queue.push_front(guest)
	else:
		_greet_queue.append(guest)
	if talking_to == null:
		_next_greeting()


func _next_greeting() -> void:
	if _greet_queue.is_empty():
		return
	talking_to = _greet_queue.pop_front()
	talking_to.greeted = true
	_reply_left = REPLY_TIME
	greeted.emit(talking_to)


func _close_talk() -> void:
	talking_to = null
	reply_closed.emit()
	_next_greeting()


## Drops [param guest] from the conversation when they leave. An unanswered greeting counts as neutral.
func _forget_talk(guest: Guest) -> void:
	_greet_queue.erase(guest)
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
	for slot in CAB_SLOTS.size():
		if not _guests.any(func(g: Guest) -> bool: return g.cab_slot == slot):
			return slot
	return -1


func _floor_y(f: int) -> float:
	return f * Elevator.FLOOR_HEIGHT


func _random_side() -> float:
	return 2.3 if rng.randf() < 0.5 else -2.3
