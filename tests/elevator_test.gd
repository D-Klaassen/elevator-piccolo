extends "res://tests/scene_test.gd"
## Headless scripted test of the cab's controls: lit buttons, queued floors, stops where
## the cab waits for you, doors that never open by themselves, and closing doors that reopen.
##
## Run: tests/run.sh elevator_test


func _run() -> void:
	_shift.spawning = false
	await _test_queue_in_order()
	await _test_stops_on_the_way()
	await _test_door_lights()
	await _test_doors_ride_along()


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
	_check(not _elevator.is_lit("1") and _elevator.is_lit("2"), "the 1 light goes out, 2 stays lit")
	_check(_last_hint.contains("close to go on to floor 2"), "the HUD says how to go on (%s)" % _last_hint)
	await _wait_seconds(3)
	_check(_elevator.current_floor == 1 and not _elevator.doors_open and not _elevator._doors_busy, "it waits on floor 1 with the doors shut")
	_press("open")
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest()), "you open the doors yourself")
	await _wait_seconds(2)
	_check(_elevator.current_floor == 1, "it stays on floor 1 while the doors are open")

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
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 1 and not _elevator._moving), "it stops at floor 1 on the way down")
	_check(_elevator.queued_floors() == [0], "floor 0 is still queued")
	await _wait_seconds(1)
	_check(_elevator.current_floor == 1 and not _elevator.doors_open, "it holds on floor 1 with the doors shut")
	_press("close") # skip this stop without opening
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 0 and not _elevator._moving), "close without opening skips on to floor 0")
	await _wait_seconds(1)
	_check(not _elevator.doors_open, "the doors stay shut on floor 0 too")
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


func _test_doors_ride_along() -> void:
	# Ride up with the doors shut: their collision has to come along, or you walk through them.
	var start := _elevator.current_floor
	var target := 1 if start != 1 else 2
	_press(str(target))
	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == target and not _elevator._moving), "it rides to floor %d" % target)
	await physics_frame
	for door: AnimatableBody3D in [_elevator._left_door, _elevator._right_door]:
		var body_y: float = PhysicsServer3D.body_get_state(door.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM).origin.y
		_check(absf(body_y - door.global_position.y) < 0.01, "%s's collision is where the door is (%.2f, %.2f)" % [door.name, body_y, door.global_position.y])
	_press("open")
	await _wait_until(func() -> bool: return _elevator.is_open_at_rest())
