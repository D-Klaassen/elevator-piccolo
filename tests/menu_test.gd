extends "res://tests/scene_test.gd"
## Headless scripted test of the menus: the title screen the game starts on, with Continue
## only when there is a career to go on with, New career (asking first when there is one to
## lose), the credits; the pause menu with the shift so far, Quit to title and Quit asking
## first; the shift pausing and the sound going quiet when the window goes to the
## background; and the menus growing with the window.
##
## Run: tests/run.sh menu_test


func _run() -> void:
	_test_scaling()
	await _test_title_without_save()
	await _test_credits()
	await _test_new_career_without_save()
	await _test_title_with_save()
	await _test_pause()
	await _test_quit_to_title()
	await _test_new_career_with_save()
	await _test_quit_asks()
	await _test_background()


func _test_scaling() -> void:
	_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND
			and root.content_scale_size == Vector2i(1280, 720), "the menus and the HUD are drawn at 1280 × 720 and grow with the window")


func _test_title_without_save() -> void:
	_check(not _menu().is_open() and not paused, "with the title screen switched off (as in tests) the shift starts straight away")
	await _restart_on_title()
	_check(_menu().screen == "main" and paused, "the game starts on the title screen, over the stopped hotel")
	_check(not (_scene.get_node("HUD") as CanvasLayer).visible, "without the HUD")
	var minutes := _shift.minutes
	await _wait_seconds(0.5)
	_check(_shift.minutes == minutes, "the clock stands still")
	_check(_text(_menu()).contains("Elevator Piccolo"), "it shows the game's name")
	_check(_button("Continue") == null, "without a career there is no Continue")
	_check(_button("NewCareer").has_focus(), "and New career is focused")
	for button_name in ["Settings", "Credits", "Quit"]:
		_check(_button(button_name) != null, "it has %s" % button_name)


func _test_credits() -> void:
	_button("Credits").pressed.emit()
	_check(_menu().screen == "credits" and _text(_menu()).contains("Kenney"), "Credits names who made the models")
	await _escape()
	_check(_menu().screen == "main" and _button("Credits").has_focus(), "Esc goes back, on Credits")


func _test_new_career_without_save() -> void:
	_button("NewCareer").pressed.emit()
	_check(_dialog() == null, "with no career to lose New career doesn't ask")
	_load_scene(await _new_scene())
	_check(not _menu().is_open() and not paused and _shift.minutes == Shift.START, "it starts the first shift")
	_check((_scene.get_node("HUD") as CanvasLayer).visible, "with the HUD")
	_shift.spawning = false


func _test_title_with_save() -> void:
	var career := Career.new()
	career.balance = 42.5
	career.shifts_done = 2
	career.save()
	await _restart_on_title()
	_check(_button("Continue") != null and _button("Continue").has_focus(), "with a saved career the title screen has Continue, focused")
	_check(_text(_menu()).contains("Rustic cabin · shift 3 · €42.50"), "with the career under it")
	_button("Continue").pressed.emit()
	_check(not _menu().is_open() and not paused, "Continue starts the shift")
	_check((_scene.get_node("HUD") as CanvasLayer).visible, "with the HUD")


func _test_pause() -> void:
	_shift.served = 2
	await _escape()
	_check(_menu().screen == "main" and paused and _button("Resume").has_focus(), "Esc pauses, with Resume focused")
	_check(_text(_menu()).contains("Paused") and _text(_menu()).contains("Rustic cabin · 08:") and _text(_menu()).contains("served 2"),
			"the pause menu shows the shift so far")
	_check(_button("QuitToTitle") != null and _button("LeaveAssetRoom") == null, "and Quit to title")
	_button("Resume").pressed.emit()
	_check(not _menu().is_open() and not paused, "Resume goes on with the shift")


func _test_quit_to_title() -> void:
	await _escape()
	_button("QuitToTitle").grab_focus()
	_button("QuitToTitle").pressed.emit()
	_check(_dialog() != null and _text(_dialog()).contains("The shift in progress is lost"), "Quit to title asks first")
	await process_frame
	_check((_dialog().find_child("No", true, false) as Button).has_focus(), "with No focused")
	(_dialog().find_child("No", true, false) as Button).pressed.emit()
	await process_frame
	_check(_dialog() == null and _menu().screen == "main" and _button("QuitToTitle").has_focus(), "No keeps the pause menu")
	_button("QuitToTitle").pressed.emit()
	await _escape()
	_check(_dialog() == null and _menu().screen == "main", "and so does Esc")
	_button("QuitToTitle").pressed.emit()
	(_dialog().find_child("Yes", true, false) as Button).pressed.emit()
	_load_scene(await _new_scene())
	_check(_menu().is_open() and _button("Continue") != null, "Yes goes back to the title screen")


func _test_new_career_with_save() -> void:
	_button("NewCareer").pressed.emit()
	_check(_dialog() != null and _text(_dialog()).contains("wiped"), "with a career to lose New career asks first")
	(_dialog().find_child("Yes", true, false) as Button).pressed.emit()
	_load_scene(await _new_scene())
	_check(not FileAccess.file_exists(Career.save_path), "Yes wipes the save")
	_check(not _menu().is_open() and not paused and Career.load_saved().balance == 0.0, "and starts a fresh career")
	_shift.spawning = false


func _test_quit_asks() -> void:
	await _escape()
	_button("Quit").pressed.emit()
	_check(_dialog() != null and _text(_dialog()).contains("Quit the game?"), "Quit asks first")
	(_dialog().find_child("No", true, false) as Button).pressed.emit()
	await _escape()
	_check(not _menu().is_open() and not paused, "No, then Esc, goes on with the shift")


func _test_background() -> void:
	_menu().notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(_menu().screen == "main" and paused, "the shift pauses when the window goes to the background")
	_check(AudioServer.is_bus_mute(0), "and goes quiet")
	_menu().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not AudioServer.is_bus_mute(0), "the sound comes back with the window")
	_button("Resume").pressed.emit()
	var settings := Settings.new()
	settings.pause_in_background = false
	settings.mute_in_background = false
	_menu().settings = settings
	_menu().notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _menu().is_open() and not paused and not AudioServer.is_bus_mute(0), "with both switched off it plays on")
	_menu().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


## Starts the game again as from the start, on the title screen.
func _restart_on_title() -> void:
	GameMenu.show_title = true
	reload_current_scene()
	_load_scene(await _new_scene())
	await process_frame


func _new_scene() -> Node3D:
	var old_id := _scene.get_instance_id()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	await process_frame
	return current_scene


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _menu() -> GameMenu:
	return _scene.find_child("GameMenu", true, false)


func _dialog() -> Control:
	var dialog := _menu().find_child("Confirm", true, false) as Control
	return dialog if dialog and dialog.visible else null


## The menu's button [param button_name] on the screen showing, or null.
func _button(button_name: String) -> Button:
	for button: Button in _menu().find_child("Screens", true, false).find_children(button_name, "Button", true, false):
		if button.is_visible_in_tree():
			return button
	return null


func _text(node: Node) -> String:
	var text := ""
	for child: Label in node.find_children("*", "Label", true, false):
		if child.is_visible_in_tree():
			text += child.text + "\n"
	return text
