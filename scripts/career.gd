class_name Career
extends RefCounted
## What carries over from one shift to the next: the bank balance and the star rating of
## every finished shift. Saved to disk at the end of every shift and loaded when a shift
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


## The saved career, or a fresh one if there is no save yet.
static func load_saved() -> Career:
	var career := Career.new()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return career
	career.balance = file.get_value("career", "balance", 0.0)
	career.ratings.assign(file.get_value("career", "ratings", []))
	career.shifts_done = file.get_value("career", "shifts_done", 0)
	return career


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("career", "balance", balance)
	file.set_value("career", "ratings", ratings)
	file.set_value("career", "shifts_done", shifts_done)
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
