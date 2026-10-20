extends "res://tests/scene_test.gd"
## Headless scripted test of the landing doors and the call buttons: every hallway's
## opening has doors that open and close with the cab's on the floor the cab is at and stay
## shut elsewhere, so you can't walk into the empty shaft; and when you've shut yourself out
## in a hallway, its call button brings the cab back and opens up.
##
## Run: tests/run.sh landing_door_test

var _player: Player


func _run() -> void:
	_shift.spawning = false
	_player = _scene.get_node("Player")
	await _test_doors_follow_the_cab()
	await _test_shut_out()
	await _test_cab_elsewhere()
	await _test_cab_open_elsewhere()


func _test_doors_follow_the_cab() -> void:
	_check(_landing_open(0) and not _landing_open(1) and not _landing_open(2), "at the start the ground floor's landing doors are open with the cab's, the others shut")
	_check(_elevator.call_button(1) != null and _elevator.call_button(1).display_name == "Call the elevator", "every hallway has a call button")
	_press("close")
	await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy)
	_check(not _landing_open(0), "closing the cab's doors closes the landing doors too")
	_check(_blocked(0), "and they block the way into the shaft")
	await _ride_to(1)
	_check(_landing_open(1) and not _landing_open(0), "on floor 1 its landing doors open with the cab's, the ground floor's stay shut")
	_check(not _blocked(1) and _blocked(0), "so you can step out on floor 1 but not into the shaft on floor 0")


## What went wrong before: you step out, the doors close, and you're stuck in the hallway.
func _test_shut_out() -> void:
	_put_player_in_hallway(1)
	_press("close")
	await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy)
	var z := _player.global_position.z
	Input.action_press("move_forward")
	await _wait_seconds(1.5)
	Input.action_release("move_forward")
	_check(_player.global_position.z > _elevator.landing_z, "walking at the shut landing doors, you stay in the hallway (z %.2f → %.2f)" % [z, _player.global_position.z])
	_elevator.call_button(1).press()
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest()), "the call button opens the doors when the cab is here")
	_check(_landing_open(1), "landing doors and all")
	Input.action_press("move_forward")
	_check(await _wait_until(func() -> bool: return _player.global_position.z < Elevator.CAB_HALF_WIDTH - 0.2, 4.0), "and you can walk back in")
	Input.action_release("move_forward")


func _test_cab_elsewhere() -> void:
	# Send the cab up to floor 2 without you, then call it back from floor 1.
	_put_player_in_hallway(1)
	_press("2")
	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 2 and not _elevator._moving, 20.0), "the cab leaves without you")
	_check(not _landing_open(1) and _blocked(1), "and floor 1's landing doors stay shut behind it")
	_elevator.call_button(1).press()
	_check(_elevator.call_button(1).lit and _elevator.is_called_from_hall(1), "pressing call lights it up")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 1 and _elevator.is_open_at_rest(), 20.0), "the cab comes back to floor 1 and opens up by itself")
	_check(_landing_open(1) and not _elevator.call_button(1).lit, "landing doors open, and the call button goes out")


func _test_cab_open_elsewhere() -> void:
	# The cab stands open on floor 1, and someone calls from the ground floor.
	_put_player_in_hallway(0)
	_elevator.call_button(0).press()
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 0 and _elevator.is_open_at_rest(), 20.0), "a call shuts the cab's doors wherever it stands open, and it comes")

	# Stopped on the way with more floors queued, the cab waits for a close press; a call
	# from a hallway doesn't.
	_press("2")
	_press("1")
	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 1 and not _elevator._moving, 20.0), "stopping on floor 1 on the way to 2")
	_check(_elevator._holding, "it waits there for a close press")
	_elevator.call_button(0).press()
	_check(await _wait_until(func() -> bool: return not _elevator._holding and _elevator._moving, 5.0), "but a call from the ground floor sends it on")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 0 and _elevator.is_open_at_rest(), 30.0), "and it ends up open on the ground floor")


func _landing_open(f: int) -> bool:
	var left: Node3D = _elevator.landing_doors(f)[0]
	return left.position.x < -Elevator.DOOR_OPENING / 2


## True if something solid stands in floor [param f]'s landing opening, at waist height.
func _blocked(f: int) -> bool:
	var y := f * Elevator.FLOOR_HEIGHT + 1.0
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, y, _elevator.landing_z + 0.4), Vector3(0, y, _elevator.landing_z - 0.03), 1)
	var hit := _scene.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and (hit.collider as Node).get_parent().name.begins_with("Landing")


## Puts you in floor [param f]'s hallway, facing the elevator.
func _put_player_in_hallway(f: int) -> void:
	_player.global_position = Vector3(0.3, f * Elevator.FLOOR_HEIGHT + 0.05, _elevator.landing_z + 0.6)
	_player.rotation_degrees.y = 0.0 # facing -Z, towards the elevator
	_player.velocity = Vector3.ZERO
