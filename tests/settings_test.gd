extends "res://tests/scene_test.gd"
## Headless scripted test of the settings: Esc pauses the shift and opens them, the volume
## and mouse sensitivity sliders take effect and are saved straight away, the next shift
## picks them up, and the staff room opens them too.
##
## Run: tests/run.sh settings_test


func _run() -> void:
	_test_saving()
	_shift.spawning = false
	await _test_pause_menu()
	await _test_next_shift()
	await _test_staff_room()


func _test_saving() -> void:
	var s := Settings.load_saved()
	_check(s.volume == 0.8 and s.mouse_sensitivity == 1.0, "without a save the settings are the defaults")
	s.volume = 1.5
	s.mouse_sensitivity = 10.0
	_check(s.volume == 1.0 and s.mouse_sensitivity == Settings.MAX_SENSITIVITY, "they stay within their range")
	s.volume = 0.0
	s.apply_volume()
	_check(AudioServer.is_bus_mute(0), "volume 0 mutes the game")
	s.volume = 0.8
	s.apply_volume()
	_check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.8)), "and turning it up unmutes it")


func _test_pause_menu() -> void:
	var menu := _menu()
	_check(not menu.visible and not paused, "the shift runs without the menu")
	await _escape()
	_check(menu.visible and paused, "Esc pauses the shift and opens the menu")
	_check(_text(menu).contains("Paused") and (menu.find_child("Close", true, false) as Button).text == "Resume", "as the pause menu")
	var minutes := _shift.minutes
	await _wait_seconds(1.0)
	_check(_shift.minutes == minutes, "the clock stands still")

	_slider("Volume").value = 0.4
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.4)), "the volume slider sets the volume")
	_check(_text(menu).contains("Volume: 40%"), "and shows it")
	_slider("MouseSensitivity").value = 2.0
	_check(_player().mouse_sensitivity == 2.0, "the sensitivity slider sets the mouse sensitivity")
	_check(_text(menu).contains("Mouse sensitivity: ×2.00"), "and shows it")
	var saved := Settings.load_saved()
	_check(is_equal_approx(saved.volume, 0.4) and saved.mouse_sensitivity == 2.0, "both are saved straight away")

	await _escape()
	_check(not menu.visible and not paused, "Esc again closes the menu and the shift goes on")
	await _escape()
	(menu.find_child("Close", true, false) as Button).pressed.emit()
	_check(not menu.visible and not paused, "and so does Resume")


func _test_next_shift() -> void:
	AudioServer.set_bus_volume_db(0, 0.0)
	_load_scene(await _reload())
	_shift.spawning = false
	_check(_player().mouse_sensitivity == 2.0, "the next shift keeps the mouse sensitivity")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.4)), "and the volume")


func _test_staff_room() -> void:
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()
	var room: StaffRoom = _scene.find_child("StaffRoom", true, false)
	await _escape()
	_check(room.visible and not _menu().visible, "Esc doesn't open the pause menu in the staff room")
	(room.find_child("Settings", true, false) as Button).pressed.emit()
	_check(_menu().visible and not room.visible and _text(_menu()).contains("Settings"), "its Settings button does")
	_check(_slider("MouseSensitivity").value == 2.0, "showing the saved settings")
	(_menu().find_child("Close", true, false) as Button).pressed.emit()
	_check(room.visible and not _menu().visible and paused, "Back returns to the staff room, still between shifts")


func _escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene


func _menu() -> SettingsMenu:
	return _scene.find_child("SettingsMenu", true, false)


func _slider(slider_name: String) -> HSlider:
	return _menu().find_child(slider_name, true, false)


func _player() -> Player:
	return _scene.find_child("Player", true, false)


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
