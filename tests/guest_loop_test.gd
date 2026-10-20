extends SceneTree
## Headless scripted test of the guest loop: serves three guests in a row by pressing
## the cab's buttons and talking to the guests, the way a player would.
##
## Run: godot --headless --path . --fixed-fps 60 --script tests/guest_loop_test.gd

var _failures := 0
var _last_said := ""
var _last_hint := ""
var _elevator: Elevator
var _guests: GuestManager


func _initialize() -> void:
	# Fail instead of hanging if a script error stops the run.
	create_timer(300.0).timeout.connect(func() -> void:
		print("guest loop test: TIMED OUT")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/cabin_greybox.tscn").instantiate()
	root.add_child(scene)
	_elevator = scene.get_node("Elevator")
	_guests = scene.get_node("Guests")
	_guests.auto_spawn = false
	_guests.said.connect(func(text: String) -> void: _last_said = text)
	_elevator.hint.connect(func(text: String) -> void: _last_hint = text)
	await physics_frame

	# Guest A on floor 0 (the cab is here, doors open) going to floor 1.
	var a := _guests.spawn_guest(0, 1)
	_check(_elevator.dings == 1, "a new guest rings the call bell")
	_check(_call_lit(0), "floor 0 call lamp lights up")
	_check(await _wait_until(func() -> bool: return a.state == Guest.State.BOARDING), "guest A walks to the open cab")
	_press("close")
	_check(_last_hint.contains("doorway"), "the doors won't close on a boarding guest")
	_check(await _wait_until(func() -> bool: return a.state == Guest.State.RIDING), "guest A rides")
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
	_check(_guests.served == 1, "one guest served")
	_check(await _wait_until(func() -> bool: return b.state == Guest.State.RIDING), "guest B boards on floor 1")

	# Floor 2: B gets out, C gets in.
	await _ride_to(2)
	_check(await _wait_until(_gone(b)), "guest B walks out on floor 2")
	_check(await _wait_until(func() -> bool: return c.state == Guest.State.RIDING), "guest C boards on floor 2")
	_check(not _call_lit(2), "floor 2 call lamp goes out")

	# Floor 0: C gets out.
	await _ride_to(0)
	_check(await _wait_until(_gone(c)), "guest C walks out on floor 0")
	_check(_guests.served == 3, "three guests served in a row")
	_check(_guests.guests().is_empty(), "no guests left")

	# Random spawning keeps the hallways stocked without breaking anything.
	_guests.auto_spawn = true
	await _wait_seconds(40.0)
	_check(_guests.guests().size() >= 2, "random guests keep calling (%d waiting)" % _guests.guests().size())
	for g in _guests.guests():
		_check(g.destination != g.home_floor, "a random guest wants another floor")

	print("guest loop test: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)


func _ride_to(f: int) -> void:
	_check(await _wait_until(func() -> bool: return _elevator.door_blockers == 0 and _elevator.is_open_at_rest()), "doorway clear before leaving")
	_press("close")
	await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy)
	_press(str(f))
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == f and not _elevator._moving), "cab arrives at floor %d" % f)
	_press("open")
	await _wait_until(func() -> bool: return _elevator.is_open_at_rest())


## A condition that turns true once [param guest] has been freed. It holds only the
## instance id, because a lambda capturing a freed object errors when called.
func _gone(guest: Guest) -> Callable:
	var id := guest.get_instance_id()
	return func() -> bool: return not is_instance_id_valid(id)


func _press(action: String) -> void:
	for child in _elevator.get_cab().get_children():
		if child is ElevatorButton and child.action == action:
			child.press()
			return
	_check(false, "button %s exists" % action)


func _call_lit(f: int) -> bool:
	var mat: StandardMaterial3D = _elevator._call_lamps[f].mesh.material
	return mat.emission_enabled


func _wait_until(condition: Callable, timeout := 20.0) -> bool:
	var frames := int(timeout * Engine.physics_ticks_per_second)
	for i in frames:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _wait_seconds(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
