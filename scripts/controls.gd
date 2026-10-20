class_name Controls
## The input actions, for keyboard and mouse and for a controller (Xbox layout, as on the
## Steam Deck): left stick or WASD to walk, right stick to look (the mouse is handled by
## [Player]), A or E to press what you look at, Start or Esc to pause. In menus the D-pad
## or left stick moves between buttons, A presses and B goes back.

const STICK_DEADZONE := 0.2


## Adds the actions to the [InputMap]. Safe to call more than once.
static func setup() -> void:
	_add_stick("move_left", JOY_AXIS_LEFT_X, -1.0, KEY_A)
	_add_stick("move_right", JOY_AXIS_LEFT_X, 1.0, KEY_D)
	_add_stick("move_forward", JOY_AXIS_LEFT_Y, -1.0, KEY_W)
	_add_stick("move_back", JOY_AXIS_LEFT_Y, 1.0, KEY_S)
	_add_stick("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_stick("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_stick("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_stick("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_buttons("interact", JOY_BUTTON_A, KEY_E)
	_add_buttons("pause", JOY_BUTTON_START, KEY_ESCAPE)
	# Godot's menu actions come with the D-pad and stick, but no buttons to press or go back.
	_add_buttons("ui_accept", JOY_BUTTON_A)
	_add_buttons("ui_cancel", JOY_BUTTON_B)


static func _add_stick(action: String, axis: JoyAxis, direction: float, key := KEY_NONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
		if key != KEY_NONE:
			InputMap.action_add_event(action, _key(key))
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = direction
	_add_event(action, motion)


static func _add_buttons(action: String, button: JoyButton, key := KEY_NONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		if key != KEY_NONE:
			InputMap.action_add_event(action, _key(key))
	var pad := InputEventJoypadButton.new()
	pad.button_index = button
	_add_event(action, pad)


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _add_event(action: String, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
