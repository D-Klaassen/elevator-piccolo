extends "res://tests/scene_test.gd"
## Headless scripted test of the debug options: Infinite money and Skip hotel requirements
## bend the career's rules while they are on and leave the save honest; the Settings menu
## has a Debug section with them only in debug builds, with the game speed and End shift
## now, and the HUD says DEBUG while any is on.
##
## Run: tests/run.sh debug_test


func _run() -> void:
	_shift.spawning = false
	_test_infinite_money()
	_test_skip_hotel_requirements()
	await _test_menu()
	await _test_end_shift_now()
	await _test_release_build()


func _test_infinite_money() -> void:
	DebugOptions.reset()
	var c := Career.new()
	c.balance = 10.0
	_check(not c.can_buy(Upgrades.MUSIC), "without the option €10 doesn't buy the music box")
	DebugOptions.infinite_money = true
	_check(c.can_buy(Upgrades.MUSIC) and c.buy(Upgrades.MUSIC), "with Infinite money it does")
	_check(c.level(Upgrades.MUSIC) == 1 and c.balance == 10.0, "the music box is in, and the balance stays as it is")

	c.ratings.assign([4.0, 4.0, 4.0])
	_check(c.can_move() and c.move_up(), "moving up needs no fee either")
	_check(c.hotel == 1 and c.balance == 10.0, "and costs nothing")

	DebugOptions.infinite_money = false
	c.balance = 10.0
	_check(not c.can_buy(Upgrades.CAB), "switched off, the prices count again")
	DebugOptions.reset()


func _test_skip_hotel_requirements() -> void:
	DebugOptions.reset()
	var c := Career.new()
	c.balance = 1000.0
	c.ratings.assign([1.0])
	_check(not c.can_move(), "one shift at 1 star isn't enough to move up")
	DebugOptions.skip_hotel_requirements = true
	_check(c.can_move() and c.move_up(), "with Skip hotel requirements it is")
	_check(c.hotel == 1 and c.balance == 1000.0 - Hotels.at(1).fee, "and the fee is still paid")
	_check(c.can_finish_demo(), "at the last hotel you can apply to the Grand Hotel straight away")

	DebugOptions.skip_hotel_requirements = false
	_check(not c.can_finish_demo(), "switched off, the rating counts again")
	DebugOptions.reset()


func _test_menu() -> void:
	await _escape()
	var debug := _menu().find_child("Debug", true, false) as Control
	_check(debug != null and debug.is_visible_in_tree(), "the pause menu has a Debug section")
	_check(_debug_label().text == "", "with everything off the HUD doesn't say DEBUG")

	(_menu().find_child("InfiniteMoney", true, false) as BaseButton).button_pressed = true
	_check(DebugOptions.infinite_money and _debug_label().text == "DEBUG", "Infinite money switches on, and the HUD says DEBUG")
	(_menu().find_child("SkipHotelRequirements", true, false) as BaseButton).button_pressed = true
	_check(DebugOptions.skip_hotel_requirements, "so does Skip hotel requirements")

	var speed := _menu().find_child("GameSpeed", true, false) as Button
	_check(speed.text == "Game speed: ×1", "the game runs at ×1")
	for i in 2:
		speed.pressed.emit()
	_check(speed.text == "Game speed: ×4" and Engine.time_scale == 4.0, "pressing it twice runs the game at ×4")
	_check(_debug_label().text == "DEBUG ×4", "and the HUD says DEBUG ×4")
	speed.pressed.emit()
	speed.pressed.emit()
	_check(speed.text == "Game speed: ×1" and Engine.time_scale == 1.0, "after ×8 it goes back to ×1")
	await _escape()


func _test_end_shift_now() -> void:
	DebugOptions.reset()
	_guests.spawn_guest(1, 0)
	_guests.spawn_guest(2, 0)
	_shift.fares = 4.0
	_shift.tips = 3.0
	_shift.stars = 3.5
	await _escape()
	(_menu().find_child("EndShiftNow", true, false) as Button).pressed.emit()
	await process_frame
	var report := _scene.find_child("ShiftReport", true, false) as Control
	_check(_shift.is_over and report.visible and not _menu().visible, "End shift now ends the shift and shows the report")
	_check(_guests.guests().is_empty() and _shift.lost == 0 and _shift.stars == 3.5, "the guests are gone, without complaints")
	var saved := Career.load_saved()
	_check(saved.balance == 4.0 + 3.0 + Shift.WAGE and saved.ratings.size() == 1 and saved.ratings[0] == 3.5, "the shift counts as it stood: €12.00 with the wage, 3.5 ★")

	(report.find_child("Continue", true, false) as Button).pressed.emit()
	(_scene.find_child("StaffRoom", true, false).find_child("Settings", true, false) as Button).pressed.emit()
	var end := _menu().find_child("EndShiftNow", true, false) as Control
	_check(end == null or not end.is_visible_in_tree(), "the staff room's settings have no End shift now")
	(_menu().find_child("Close", true, false) as Button).pressed.emit()
	(_scene.find_child("StaffRoom", true, false).find_child("StartShift", true, false) as Button).pressed.emit()
	_load_scene(await _wait_for_new_scene())
	_shift.spawning = false


func _wait_for_new_scene() -> Node3D:
	var old_id := _scene.get_instance_id()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene


func _test_release_build() -> void:
	DebugOptions.available = false
	_load_scene(await _reload())
	_shift.spawning = false
	await _escape()
	var debug := _menu().find_child("Debug", true, false) as Control
	_check(debug == null or not debug.is_visible_in_tree(), "a release build has no Debug section")
	await _escape()
	DebugOptions.available = true


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _reload() -> Node3D:
	reload_current_scene()
	return await _wait_for_new_scene()


func _menu() -> SettingsMenu:
	return _scene.find_child("SettingsMenu", true, false)


func _debug_label() -> Label:
	return _scene.find_child("DebugLabel", true, false)
