extends "res://tests/scene_test.gd"
## Headless scripted test of the guest loop: serves three guests in a row by pressing
## the cab's buttons and talking to the guests, the way a player would.
##
## Run: godot --headless --path . --fixed-fps 60 --script tests/guest_loop_test.gd


func _run() -> void:
	_shift.spawning = false
	_guests.patience_scale = 10.0 # nobody gives up during this test
	_guests.chat_chance = 0.0 # chats have their own test

	# Guest A on floor 0 (the cab is here, doors open) going to floor 1.
	var a := _guests.spawn_guest(0, 1)
	_check(_elevator.dings == 1, "a new guest rings the call bell")
	_check(_call_lit(0), "floor 0 call lamp lights up")
	_check(await _wait_until(func() -> bool: return a.state == Guest.State.BOARDING), "guest A walks to the open cab")
	_press("close")
	_check(_last_hint.contains("doorway"), "the doors won't close on a boarding guest")
	_check(_elevator.is_lit("close") and _elevator.doors_open, "the close button stays lit while the doorway is busy")
	_check(await _wait_until(func() -> bool: return a.state == Guest.State.RIDING), "guest A rides")
	_check(await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy), "the doors close once the doorway is clear")
	_check(not _elevator.is_lit("close"), "the close light goes out once the doors are shut")
	_check(not _call_lit(0), "floor 0 call lamp goes out once A boards")
	_check(a.get_parent() == _elevator.get_cab(), "guest A rides inside the cab")
	a.press()
	_check(_last_said.to_lower().contains("floor 1"), "guest A names floor 1 (said: %s)" % _last_said)

	# Guests B on floor 1 going to floor 2, and C on floor 2 going to floor 0.
	var b := _guests.spawn_guest(1, 2)
	var c := _guests.spawn_guest(2, 0)
	_check(_elevator.dings == 3, "each new guest rings the bell")
	_check(_call_lit(1) and _call_lit(2), "floor 1 and 2 call lamps light up")
	c.press()
	_check(_last_said.to_lower().contains("floor 0"), "a waiting guest names their floor too (said: %s)" % _last_said)

	# Floor 1: A gets out, B gets in.
	await _ride_to(1)
	_check(await _wait_until(_gone(a)), "guest A walks out and disappears on floor 1")
	_check(_shift.served == 1, "one guest served")
	_check(await _wait_until(func() -> bool: return b.state == Guest.State.RIDING), "guest B boards on floor 1")

	# Floor 2: B gets out, C gets in.
	await _ride_to(2)
	_check(await _wait_until(_gone(b)), "guest B walks out on floor 2")
	_check(await _wait_until(func() -> bool: return c.state == Guest.State.RIDING), "guest C boards on floor 2")
	_check(not _call_lit(2), "floor 2 call lamp goes out")

	# Floor 0: C gets out.
	await _ride_to(0)
	_check(await _wait_until(_gone(c)), "guest C walks out on floor 0")
	_check(_shift.served == 3, "three guests served in a row")
	_check(_guests.guests().is_empty(), "no guests left")
