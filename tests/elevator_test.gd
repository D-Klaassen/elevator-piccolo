extends "res://tests/scene_test.gd"
## Headless scripted test of the cab's controls: lit buttons, queued floors, doors that
## open by themselves at stops with more floors queued, and closing doors that reopen.
##
## Run: godot --headless --path . --fixed-fps 60 --script tests/elevator_test.gd


func _run() -> void:
	_shift.spawning = false
	await _test_queue_in_order()
	await _test_stops_on_the_way()
	await _test_door_lights()


func _test_queue_in_order() -> void:
	# On floor 0 with the doors open: press 1, then 2.
	_press("1")
	_press("2")
	_check(_elevator.queued_floors() == [1, 2], "floors queue in the order pressed")
	await physics_frame
	_check(_elevator.is_lit("1") and _elevator.is_lit("2"), "pressed floor buttons stay lit")
	await _wait_seconds(1)
	_check(_elevator.doors_open and not _elevator._moving, "the cab waits while the doors are open")

	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator._moving), "closing the doors sends the cab off")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 1 and not _elevator._moving), "it stops at floor 1 first")
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest()), "with 2 still queued, the doors open by themselves on floor 1")
	_check(not _elevator.is_lit("1") and _elevator.is_lit("2"), "the 1 light goes out, 2 stays lit")
	await _wait_seconds(3)
	_check(_elevator.current_floor == 1 and _elevator.doors_open, "it waits on floor 1 until the doors are closed")

	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 2 and not _elevator._moving), "after closing it goes on to floor 2")
	_check(not _elevator.is_lit("2") and _elevator.queued_floors().is_empty(), "nothing left in the queue")
	await _wait_seconds(2)
	_check(not _elevator.doors_open and not _elevator._doors_busy, "on the last queued floor the doors stay shut")
	_press("open")
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest()), "until you press open")


func _test_stops_on_the_way() -> void:
	# On floor 2: press 0 first, then 1. Going down, it stops at 1 on the way.
	_press("0")
	_press("1")
	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 1 and _elevator.is_open_at_rest()), "it stops at floor 1 on the way down")
	_check(_elevator.queued_floors() == [0], "floor 0 is still queued")
	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 0 and not _elevator._moving), "then it goes on to floor 0")
	_press("open")
	await _wait_until(func() -> bool: return _elevator.is_open_at_rest())

	_press("0")
	_check(_last_hint.contains("already on floor 0") and _elevator.queued_floors().is_empty(), "pressing the floor you're on does nothing")


func _test_door_lights() -> void:
	_press("close")
	await physics_frame
	_check(_elevator.is_lit("close"), "the close button stays lit while the doors close")
	_check(await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy), "the doors close")
	_check(not _elevator.is_lit("close"), "and its light goes out")

	_press("open")
	await physics_frame
	_check(_elevator.is_lit("open"), "the open button stays lit while the doors open")
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest()), "the doors open")
	_check(not _elevator.is_lit("open"), "and its light goes out")

	# Changing your mind halfway: open while the doors are closing.
	_press("close")
	await _wait_seconds(Elevator.DOOR_TIME / 2)
	_press("open")
	await physics_frame
	_check(_elevator.is_lit("open") and not _elevator.is_lit("close"), "open takes over from close")
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest(), Elevator.DOOR_TIME), "the closing doors reopen")

	# Open while riding is refused.
	_press("2")
	_press("close")
	await _wait_until(func() -> bool: return _elevator._moving)
	_press("open")
	_check(_last_hint.contains("Not while moving") and not _elevator.is_lit("open"), "open does nothing while riding")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 2 and not _elevator._moving), "the ride carries on")
