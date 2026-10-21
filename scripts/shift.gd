class_name Shift
extends Node
## One working day in the hotel, 08:00 to 18:00: the clock, when guests turn up (with a
## lunch rush), what you earn and the hotel's stars. The shift ends once the clock has
## run out and the last guest is gone.

signal clock_changed(minutes: int)
signal stats_changed
signal announced(text: String)
signal ended

const START := 8 * 60 ## minutes since midnight
const END := 18 * 60
const LUNCH_START := 12 * 60
const LUNCH_END := 13 * 60 + 30
## The first guest calls right away, from the ground floor where the cab starts, so a
## shift never opens with nothing to do.
const FIRST_GUEST_AT := START + 5
const FIRST_GUEST_FLOOR := 0

const WAGE := 5.0 ## the near-nothing base pay, paid at the end of the shift
## Fares and tips in the rustic cabin; better hotels pay more, see [Hotels].
const FARE := 2.0
const MAX_TIP := 6.0
const WAIT_TIP := 4.0 ## the most a guest tips for a quick pick-up alone
const FULL_TIP_SHARE := 0.2 ## boarding within this share of a guest's patience earns the full wait tip
const GOOD_REPLY_TIP := 2.0 ## a good reply to a guest's chat adds this to the tip, up to MAX_TIP
const BAD_REPLY_TIP_SHARE := 0.5 ## a bad reply leaves this share of the tip, rounded down
const BAD_REPLY_COMPLAINT_CHANCE := 0.5 ## chance that a bad reply gets you a complaint
const START_STARS := 5.0
const COMPLAINT := 0.5 ## stars lost for each complaint: a guest who gave up, waiting or riding, or a bad reply
const FIRED_BELOW := 2.0 ## stars

## Real seconds from 08:00 to 18:00.
@export var length_seconds := 540.0

var guests: GuestManager
## The hotel this shift is in, from [constant Hotels.LADDER]: how many guests come and what they pay.
var hotel: Dictionary = Hotels.at(0)
## When false, the schedule doesn't spawn anyone (tests spawn guests by hand).
var spawning := true
var minutes := float(START)
var spawned := 0
var served := 0
var lost := 0
var reply_complaints := 0
var fares := 0.0
var tips := 0.0
var wage := 0.0
var stars := START_STARS
var is_over := false
var rng := RandomNumberGenerator.new()

var _schedule: Array[float] = []


func _ready() -> void:
	rng.randomize()
	_schedule = make_schedule(rng, hotel.guests, hotel.lunch_guests)
	guests.delivered.connect(_on_delivered)
	guests.gave_up.connect(_on_gave_up)
	guests.replied.connect(_on_replied)


func _process(delta: float) -> void:
	if is_over:
		return
	var before := int(minutes)
	minutes = minf(minutes + delta * (END - START) / length_seconds, END)
	if int(minutes) != before:
		clock_changed.emit(int(minutes))

	while spawning and not _schedule.is_empty() and _schedule[0] <= minutes and minutes < END:
		var home := FIRST_GUEST_FLOOR if spawned == 0 else -1
		if guests.spawn_random(home) == null:
			break # no room in the hallways; try again next frame
		_schedule.pop_front()
		spawned += 1

	if minutes >= END and guests.guests().is_empty():
		_end()


## Ends the shift straight away, scored as it stands: the guests still in the hotel are
## gone without paying or complaining, and nobody else turns up. For
## [DebugOptions]' End shift now.
func end_now() -> void:
	if is_over:
		return
	_schedule.clear()
	guests.clear()
	minutes = END
	clock_changed.emit(END)
	_end()


func money() -> float:
	return fares + tips + wage


func is_lunch_rush() -> bool:
	return minutes >= LUNCH_START and minutes < LUNCH_END


func is_fired() -> bool:
	return stars < FIRED_BELOW


## When the [param count] guests of one shift call, in minutes since midnight, sorted.
## [param lunch_count] of them come during the lunch rush.
static func make_schedule(r: RandomNumberGenerator, count: int, lunch_count: int) -> Array[float]:
	var times: Array[float] = [float(FIRST_GUEST_AT)]
	for i in count - lunch_count - 1:
		times.append(r.randf_range(FIRST_GUEST_AT, END - 30))
	for i in lunch_count:
		times.append(r.randf_range(LUNCH_START, LUNCH_END))
	times.sort()
	return times


## The tip for a guest who waited [param wait] seconds between calling and boarding:
## the full wait tip early on, shrinking to nothing as they run out of [param patience].
static func tip_for_wait(wait: float, patience: float) -> float:
	var share := clampf((patience - wait) / (patience * (1.0 - FULL_TIP_SHARE)), 0.0, 1.0)
	return roundf(WAIT_TIP * share)


## The whole tip: the wait tip, raised by a good reply to their chat and cut by a bad one.
static func tip_for(wait: float, patience: float, reply: Guest.Reply) -> float:
	var tip := tip_for_wait(wait, patience)
	match reply:
		Guest.Reply.GOOD:
			tip = minf(tip + GOOD_REPLY_TIP, MAX_TIP)
		Guest.Reply.BAD:
			tip = floorf(tip * BAD_REPLY_TIP_SHARE)
	return tip


static func format_clock(m: float) -> String:
	return "%02d:%02d" % [int(m) / 60, int(m) % 60]


## A delivered guest's fare in this hotel.
func fare() -> float:
	return FARE * hotel.pay


func _on_delivered(guest: Guest) -> void:
	var tip := roundf(tip_for(guest.waited, guest.patience, guest.reply) * hotel.pay)
	served += 1
	fares += fare()
	tips += tip
	stats_changed.emit()
	guest.say("Thanks!")
	guest.act(Guest.NOD)
	announced.emit("+€%d fare, +€%d tip" % [fare(), tip])


func _on_gave_up(guest: Guest) -> void:
	lost += 1
	stars = maxf(stars - COMPLAINT, 0.0)
	stats_changed.emit()
	guest.act(Guest.HEAD_SHAKE)
	if guest.fed_up:
		guest.say("That's it, I'm getting out at the next stop!")
		announced.emit("A guest wants out at the next stop.   Complaint: -%.1f star" % COMPLAINT)
	else:
		guest.say("Forget it, I'll take the stairs!")
		announced.emit("A guest on floor %d took the stairs.   Complaint: -%.1f star" % [guest.home_floor, COMPLAINT])


func _on_replied(guest: Guest) -> void:
	if guest.reply != Guest.Reply.BAD or rng.randf() >= BAD_REPLY_COMPLAINT_CHANCE:
		return
	reply_complaints += 1
	stars = maxf(stars - COMPLAINT, 0.0)
	stats_changed.emit()
	guest.say("I'll be mentioning this to the manager.")
	guest.act(Guest.HEAD_SHAKE)
	announced.emit("An unhappy guest.   Complaint: -%.1f star" % COMPLAINT)


func _end() -> void:
	is_over = true
	wage = WAGE
	stats_changed.emit()
	ended.emit()
