extends "res://tests/scene_test.gd"
## Headless scripted test of playing with a controller: the right stick turns the view (as
## fast as the look sensitivity says), the left stick walks, A presses the button you look
## at, Start pauses, the D-pad moves through the menu and B closes it. In a chat the D-pad
## or the left stick moves through the replies and A says one, while the sticks can't walk
## you away or turn the view off the guest.
##
## Run: tests/run.sh controller_test


func _run() -> void:
	_shift.spawning = false
	await _test_look()
	await _test_walk()
	await _test_press()
	await _test_chat()
	await _test_menu()


func _test_look() -> void:
	var player := _player()
	var start := player.rotation.y
	await _hold_stick(JOY_AXIS_RIGHT_X, 1.0, 0.5)
	var turned := start - player.rotation.y
	_check(turned > 0.5, "the right stick turns the view right (%.2f rad in 0.5 s)" % turned)

	player.look_sensitivity = 2.0
	start = player.rotation.y
	await _hold_stick(JOY_AXIS_RIGHT_X, 1.0, 0.5)
	var faster := start - player.rotation.y
	_check(faster > 1.6 * turned, "twice the look sensitivity turns about twice as far (%.2f rad)" % faster)
	player.look_sensitivity = 1.0

	start = player.rotation.y
	await _hold_stick(JOY_AXIS_RIGHT_X, 0.1, 0.5)
	_check(player.rotation.y == start, "a slight tilt inside the deadzone does nothing")


func _test_walk() -> void:
	var player := _player()
	var start := player.global_position
	await _hold_stick(JOY_AXIS_LEFT_X, -1.0, 0.3)
	_check(player.global_position.distance_to(start) > 0.2, "the left stick walks")
	player.global_position = start


func _test_press() -> void:
	var button := _button("1")
	_aim_at(button)
	await physics_frame
	await physics_frame
	_check(_text(_scene).contains(button.display_name), "aiming at the floor 1 button shows its name")
	await _tap(JOY_BUTTON_A)
	_check(button.lit, "A presses it")


func _test_menu() -> void:
	var menu: SettingsMenu = _scene.find_child("SettingsMenu", true, false)
	await _tap(JOY_BUTTON_START)
	_check(menu.visible and paused, "Start pauses and opens the menu")
	var close := menu.find_child("Close", true, false) as Button
	var slider := menu.find_child("LookSensitivity", true, false) as HSlider
	var smooth := menu.find_child("AntiAliasing", true, false) as CheckButton
	_check(close.has_focus(), "with Resume focused")
	await _tap(JOY_BUTTON_DPAD_UP)
	_check(smooth.has_focus(), "D-pad up moves to the Smooth edges switch")
	await _tap(JOY_BUTTON_A)
	_check(not smooth.button_pressed and root.msaa_3d == Viewport.MSAA_DISABLED, "A switches it off")
	await _tap(JOY_BUTTON_A)
	_check(smooth.button_pressed and root.msaa_3d == Viewport.MSAA_2X, "and on again")
	await _tap(JOY_BUTTON_DPAD_UP)
	_check(slider.has_focus(), "D-pad up again moves to the look sensitivity slider")
	var before := slider.value
	await _tap(JOY_BUTTON_DPAD_LEFT)
	_check(slider.value < before, "D-pad left turns it down (%.2f to %.2f)" % [before, slider.value])
	await _tap(JOY_BUTTON_B)
	_check(not menu.visible and not paused, "B closes the menu and the shift goes on")

	await _tap(JOY_BUTTON_START)
	await _tap(JOY_BUTTON_A)
	_check(not menu.visible and not paused, "A on Resume does too")


func _test_chat() -> void:
	var player := _player()
	var replies: ReplyChoices = _scene.find_child("ReplyChoices", true, false)
	_guests.chat_chance = 1.0
	var g := _guests.spawn_guest(0, 2)
	g.patience = 600
	g.ride_patience = 600
	g.reply_order = [Guest.Reply.NEUTRAL, Guest.Reply.GOOD, Guest.Reply.BAD] as Array[Guest.Reply]
	_press("open")
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "a chatty guest boards")
	_aim_at_point(g.mouth())
	await physics_frame
	await physics_frame
	await _tap(JOY_BUTTON_A)
	_check(_guests.talking_to == g and replies.visible, "A on a guest asks their floor, and they strike up a chat")
	_check(not g.answered, "the same press doesn't say a reply")

	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check(replies.highlighted == 1, "D-pad down moves to the next reply")
	await _tap(JOY_BUTTON_DPAD_UP)
	await _hold_stick(JOY_AXIS_LEFT_Y, 1.0, 0.3)
	_check(replies.highlighted == 1, "D-pad up and the left stick move through them too")
	var start := player.global_position
	await _hold_stick(JOY_AXIS_LEFT_X, -1.0, 0.3)
	_check(player.global_position.distance_to(start) < 0.01, "the left stick doesn't walk you away")
	await _hold_stick(JOY_AXIS_RIGHT_X, 1.0, 0.5)
	var camera := player.get_viewport().get_camera_3d()
	var off := (-camera.global_basis.z).angle_to(g.mouth() - camera.global_position)
	_check(off < 0.15, "the right stick doesn't turn the view off the guest (%.2f rad off)" % off)

	await _tap(JOY_BUTTON_A)
	_check(g.answered and g.reply == Guest.Reply.GOOD, "A says the highlighted reply")
	_check(not replies.visible and _guests.talking_to == null, "and the chat is over")
	await _hold_stick(JOY_AXIS_LEFT_X, -1.0, 0.3)
	_check(player.global_position.distance_to(start) > 0.2, "the left stick walks again")
	player.global_position = start
	_guests.clear()
	_guests.chat_chance = 0.0


## Holds [param axis] at [param value] for [param seconds], then lets go.
func _hold_stick(axis: JoyAxis, value: float, seconds: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await _wait_seconds(seconds)
	var release := InputEventJoypadMotion.new()
	release.axis = axis
	release.axis_value = 0.0
	Input.parse_input_event(release)
	await physics_frame
	await physics_frame


func _tap(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


## Turns the player and tilts the camera to look straight at [param target].
func _aim_at(target: Node3D) -> void:
	_aim_at_point(target.global_position)


func _aim_at_point(point: Vector3) -> void:
	var player := _player()
	var camera := player.get_viewport().get_camera_3d()
	var to := point - camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _button(action: String) -> ElevatorButton:
	for child in _elevator.get_cab().get_children():
		if child is ElevatorButton and child.action == action:
			return child
	return null


func _player() -> Player:
	return _scene.find_child("Player", true, false)


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
