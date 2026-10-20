class_name Career
extends RefCounted
## What carries over from one shift to the next: the bank balance, the star rating of
## every finished shift and the upgrades bought in the staff room. Saved to disk at the end of every shift and loaded when a shift
## starts, so it survives both playing on and quitting the game.

const DEFAULT_PATH := "user://career.cfg"
const AVERAGE_OVER := 3 ## the hotel unlock looks at the average of this many recent shifts

## Where the career is saved. Tests point this at a temporary file so they never touch
## the real save.
static var save_path := DEFAULT_PATH

var balance := 0.0
## The star rating of every finished shift, oldest first, fired or not.
var ratings: Array[float] = []
## Shifts finished without being fired; a shift you got fired from is tried again.
var shifts_done := 0
## The level of every upgrade bought, by [Upgrades] id. Missing means level 0.
var upgrades := {}


## The saved career, or a fresh one if there is no save yet.
static func load_saved() -> Career:
	var career := Career.new()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return career
	career.balance = file.get_value("career", "balance", 0.0)
	career.ratings.assign(file.get_value("career", "ratings", []))
	career.shifts_done = file.get_value("career", "shifts_done", 0)
	career.upgrades = file.get_value("career", "upgrades", {})
	return career


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("career", "balance", balance)
	file.set_value("career", "ratings", ratings)
	file.set_value("career", "shifts_done", shifts_done)
	file.set_value("career", "upgrades", upgrades)
	return file.save(save_path)


## Banks a finished shift's money and keeps its rating.
func record(shift: Shift) -> void:
	balance += shift.money()
	ratings.append(shift.stars)
	if not shift.is_fired():
		shifts_done += 1


## The average rating of the last [param count] shifts (fewer if you haven't worked that
## many yet), or 0 before the first shift.
func average_rating(count := AVERAGE_OVER) -> float:
	var recent := ratings.slice(-count)
	if recent.is_empty():
		return 0.0
	var total := 0.0
	for r in recent:
		total += r
	return total / recent.size()


func level(id: String) -> int:
	return upgrades.get(id, 0)


## What the next level of [param id] costs, or -1 when it is at the top level.
func next_price(id: String) -> float:
	var l := level(id)
	if l >= Upgrades.max_level(id):
		return -1.0
	return Upgrades.find(id).prices[l]


func can_buy(id: String) -> bool:
	var price := next_price(id)
	return price >= 0.0 and balance >= price


## Pays for the next level of [param id]. Returns false, and changes nothing, when it is
## at the top level or the balance is too low.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	balance -= next_price(id)
	upgrades[id] = level(id) + 1
	return true
