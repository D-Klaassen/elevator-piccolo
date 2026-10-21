class_name DebugOptions
## Switches that bend the rules for testing, in the Settings menu's Debug section, only in
## debug builds: Infinite money, Skip hotel requirements and the game speed. They live
## only as long as the game runs, so every start begins with them off.

const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]

## True in debug builds, where the Debug section shows. Tests set it to false to play a
## release build.
static var available := OS.is_debug_build()
## Upgrades and moving up cost nothing, and the balance stays as it is.
static var infinite_money := false
## Moving up to the next hotel (or applying to the Grand Hotel) needs no rating.
static var skip_hotel_requirements := false
## How fast the whole game runs: one of [constant SPEEDS].
static var speed := 1.0:
	set(value):
		speed = value
		Engine.time_scale = value


## True while any option bends the rules.
static func any_on() -> bool:
	return infinite_money or skip_hotel_requirements or speed != 1.0


## The label for the corner of the HUD while any option is on, such as "DEBUG ×4", else "".
static func label() -> String:
	if not any_on():
		return ""
	return "DEBUG" if speed == 1.0 else "DEBUG ×%d" % speed


## The next of [constant SPEEDS] after the current one, back to ×1 after the last.
static func next_speed() -> float:
	return SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()]


## Everything off and the game at normal speed, as at the start of the game.
static func reset() -> void:
	infinite_money = false
	skip_hotel_requirements = false
	speed = 1.0
