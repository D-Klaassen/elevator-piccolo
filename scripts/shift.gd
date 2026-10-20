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
const GUESTS := 15 ## guests per shift in the rustic cabin
const LUNCH_GUESTS := 5 ## of those, the ones who come during the lunch rush

const WAGE := 5.0 ## the near-nothing base pay, paid at the end of the shift
const FARE := 2.0
const MAX_TIP := 6.0
const FULL_TIP_SHARE := 0.2 ## boarding within this share of a guest's patience earns the full tip
const START_STARS := 5.0
const COMPLAINT := 0.5 ## stars lost for each guest who gave up, waiting or riding
const FIRED_BELOW := 2.0 ## stars

## Real seconds from 08:00 to 18:00.
@export var length_seconds := 540.0

var guests: GuestManager
## When false, the schedule doesn't spawn anyone (tests spawn guests by hand).
var spawning := true
var minutes := float(START)
var spawned := 0
var served := 0
var lost := 0
var fares := 0.0
var tips := 0.0
var wage := 0.0
var stars := START_STARS
var is_over := false
var rng := RandomNumberGenerator.new()

var _schedule: Array[float] = []


func _ready() -> void:
	rng.randomize()
	_schedule = make_schedule(rng)
	guests.delivered.connect(_on_delivered)
	guests.gave_up.connect(_on_gave_up)


func _process(delta: float) -> void:
	if is_over:
		return
	var before := int(minutes)
	minutes = minf(minutes + delta * (END - START) / length_seconds, END)
	if int(minutes) != before:
		clock_changed.emit(int(minutes))

	while spawning and not _schedule.is_empty() and _schedule[0] <= minutes and minutes < END:
		if guests.spawn_random() == null:
			break # no room in the hallways; try again next frame
		_schedule.pop_front()
		spawned += 1

	if minutes >= END and guests.guests().is_empty():
		_end()


func money() -> float:
	return fares + tips + wage


func is_lunch_rush() -> bool:
	return minutes >= LUNCH_START and minutes < LUNCH_END


func is_fired() -> bool:
	return stars < FIRED_BELOW


## When the guests of one shift call, in minutes since midnight, sorted.
static func make_schedule(r: RandomNumberGenerator) -> Array[float]:
	var times: Array[float] = []
	for i in GUESTS - LUNCH_GUESTS:
		times.append(r.randf_range(START + 5, END - 30))
	for i in LUNCH_GUESTS:
		times.append(r.randf_range(LUNCH_START, LUNCH_END))
	times.sort()
	return times


## The tip for a guest who waited [param wait] seconds between calling and boarding:
## the full tip early on, shrinking to nothing as they run out of [param patience].
static func tip_for_wait(wait: float, patience: float) -> float:
	var share := clampf((patience - wait) / (patience * (1.0 - FULL_TIP_SHARE)), 0.0, 1.0)
	return roundf(MAX_TIP * share)


static func format_clock(m: float) -> String:
	return "%02d:%02d" % [int(m) / 60, int(m) % 60]


func _on_delivered(guest: Guest) -> void:
	var tip := tip_for_wait(guest.waited, guest.patience)
	served += 1
	fares += FARE
	tips += tip
	stats_changed.emit()
	announced.emit('Guest: "Thanks!"   +€%d fare, +€%d tip' % [FARE, tip])


func _on_gave_up(guest: Guest) -> void:
	lost += 1
	stars = maxf(stars - COMPLAINT, 0.0)
	stats_changed.emit()
	var said := 'Guest: "That\'s it, I\'m getting out at the next stop!"' if guest.fed_up \
		else 'Floor %d: "Forget it, I\'ll take the stairs!"' % guest.home_floor
	announced.emit("%s   Complaint: -%.1f star" % [said, COMPLAINT])


func _end() -> void:
	is_over = true
	wage = WAGE
	stats_changed.emit()
	ended.emit()
