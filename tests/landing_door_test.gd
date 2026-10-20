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
	_test_speed_curves()
	await _test_panels()
	await _test_doors_follow_the_cab()
	await _test_shut_out()
	await _test_cab_elsewhere()
	await _test_cab_open_elsewhere()


## Like a real elevator's: opening speeds up, glides and eases in; closing glides and then
## creeps the last bit.
func _test_speed_curves() -> void:
	var opening := Elevator.OPENING_SPEED
	var closing := Elevator.CLOSING_SPEED
	_check(is_zero_approx(Elevator.travelled(opening, 0.0)) and is_equal_approx(Elevator.travelled(opening, 1.0), 1.0), "a door move goes from start to end")
	_check(Elevator.travelled(opening, 0.15) < 0.08, "opening starts slowly (%.2f of the way after 15%% of the time)" % Elevator.travelled(opening, 0.15))
	_check(Elevator.travelled(opening, 0.6) - Elevator.travelled(opening, 0.4) > 0.25, "glides in the middle")
	_check(1.0 - Elevator.travelled(opening, 0.85) < 0.06, "and eases into the wall")
	var creep := 1.0 - Elevator.travelled(closing, 0.8)
	_check(creep < 0.1, "closing creeps the last bit: the last 20%% of the time covers %.0f%% of the way" % (creep * 100))


func _test_panels() -> void:
	var panels := _elevator.door_panels()
	_check(panels.size() == 4, "the cab's doors have two panels a side")
	_check(_stacked(panels), "open, each side's two panels are stacked beside the opening")
	_press("close")
	_check(await _wait_until(func() -> bool: return _elevator.door_amount < 0.5), "closing")
	var left_lead := absf(panels[0].position.x) - Elevator.PANEL_WIDTH * 0.5
	var left_trail := absf(panels[1].position.x) - Elevator.PANEL_WIDTH * 1.5
	_check(is_equal_approx(left_lead, 2.0 * left_trail), "they telescope: the leading panel is twice as far from shut as the trailing one (%.3f, %.3f)" % [left_lead, left_trail])
	await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy)
	var xs := panels.map(func(p: Node3D) -> float: return p.position.x)
	xs.sort()
	var tiled := true
	for i in xs.size():
		tiled = tiled and is_equal_approx(xs[i], -Elevator.DOOR_OPENING / 2 + Elevator.PANEL_WIDTH * (i + 0.5))
	_check(tiled, "shut, the four panels fill the opening side by side (%s)" % [xs])

	_press("open")
	_check(await _wait_until(func() -> bool: return _elevator.door_amount > 0.02), "opening")
	_check(not _landing_open(0) and absf(_elevator.landing_doors(0)[0].position.x + Elevator.PANEL_WIDTH / 2) < 0.001, "the cab's doors lead: the landing doors haven't moved yet")
	await _wait_until(func() -> bool: return _elevator.is_open_at_rest())
	_check(_stacked(_elevator.landing_doors(0)), "and the landing doors end up stacked in the wall too")


## True if each side's leading and trailing panel of [param panels] are stacked, beside the
## opening.
func _stacked(panels: Array) -> bool:
	for side in [0, 2]:
		var lead: Node3D = panels[side]
		var trail: Node3D = panels[side + 1]
		if not is_equal_approx(lead.position.x, trail.position.x) or absf(lead.position.x) - Elevator.PANEL_WIDTH / 2 < Elevator.DOOR_OPENING / 2 - 0.001:
			return false
	return true


func _test_doors_follow_the_cab() -> void:
	_check(_landing_open(0) and not _landing_open(1) and not _landing_open(2), "at the start the ground floor's landing doors are open with the cab's, the others shut")
	_check(_elevator.call_button(1) != null and _elevator.call_button(1).display_name == "Call the elevator", "every hallway has a call button")
	_check(_elevator.call_button(1).find_children("*", "Label3D", false, false).is_empty(), "a plain one, with no caption")
	var edges: Array = _elevator.landing_doors(0).map(func(p: Node3D) -> float: return absf(p.position.x) - Elevator.PANEL_WIDTH / 2)
	_check(edges.all(func(e: float) -> bool: return e > Elevator.DOOR_OPENING / 2 + 0.01), "open landing doors slide right into the wall, not flush with the opening's edge (%s)" % [edges])
	_press("close")
	await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy)
	_check(not _landing_open(0), "closing the cab's doors closes the landing doors too")
	_check(_blocked(0), "and they block the way into the shaft")
	var chimes := _elevator.chimes
	var displays := _elevator.floor_displays()
	_check(displays.size() == 1 + _elevator.floor_count, "a floor display over the cab's door and over every landing door")
	_check(displays.all(func(d: FloorDisplay) -> bool: return d.shown_floor() == "0" and d.shown_direction() == 0), "they all show floor 0, no arrow lit")
	_press("1")
	_press("close")
	await _wait_until(func() -> bool: return _elevator._moving)
	await process_frame
	_check(displays.all(func(d: FloorDisplay) -> bool: return d.shown_direction() == 1), "on the way up, the up arrows light")
	await _wait_until(func() -> bool: return _elevator.current_floor == 1 and not _elevator._moving)
	await process_frame
	_check(displays.all(func(d: FloorDisplay) -> bool: return d.shown_floor() == "1" and d.shown_direction() == 0), "arrived, they show floor 1 and the arrow goes out")
	_press("open")
	await _wait_until(func() -> bool: return _elevator.is_open_at_rest())
	_check(_elevator.chimes == chimes + 1, "arriving on the way up, the chime rings once")
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
	var chimes := _elevator.chimes
	_elevator.call_button(1).press()
	_check(_elevator.call_button(1).lit and _elevator.is_called_from_hall(1), "pressing call lights it up")
	_check(await _wait_until(func() -> bool: return _elevator.current_floor == 1 and not _elevator._moving, 20.0), "the cab comes back to floor 1")
	_check(_elevator.chimes == chimes + 2, "on the way down, the chime rings twice")
	_check(not _elevator._doors_busy and _elevator.door_amount == 0.0, "the doors wait for the chime")
	await _wait_seconds(Elevator.ARRIVAL_PAUSE / 2)
	_check(_elevator.door_amount == 0.0, "for a moment")
	_check(await _wait_until(func() -> bool: return _elevator.is_open_at_rest(), 5.0), "then open up by themselves")
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
