extends "res://tests/scene_test.gd"
## Headless scripted test of what carries over between shifts: the bank balance and the
## star ratings, through the save file and a reload of the scene, over four shifts with
## one firing in between.
##
## Run: godot --headless --path . --fixed-fps 60 --script tests/career_test.gd


func _run() -> void:
	_test_average()
	_test_save_file()
	_shift.spawning = false
	await _test_shifts()


func _test_average() -> void:
	var c := Career.new()
	_check(c.average_rating() == 0.0, "no average before the first shift")
	c.ratings.assign([4.0])
	_check(c.average_rating() == 4.0, "after one shift the average is that shift")
	c.ratings.assign([5.0, 3.0])
	_check(c.average_rating() == 4.0, "after two shifts the average is of those two")
	c.ratings.assign([1.0, 5.0, 3.0, 4.0])
	_check(c.average_rating() == 4.0, "the average looks only at the last 3 shifts")


func _test_save_file() -> void:
	_check(Career.save_path != Career.DEFAULT_PATH and Career.save_path.begins_with(OS.get_temp_dir()), "the test saves to a temporary file (%s)" % Career.save_path)
	var fresh := Career.load_saved()
	_check(fresh.balance == 0.0 and fresh.ratings.is_empty() and fresh.shifts_done == 0, "without a save the career starts at €0 with no ratings")

	var c := Career.new()
	c.balance = 12.5
	c.ratings.assign([4.5, 3.0])
	c.shifts_done = 2
	_check(c.save() == OK and FileAccess.file_exists(Career.save_path), "the career saves")
	var loaded := Career.load_saved()
	_check(loaded.balance == 12.5 and loaded.ratings == [4.5, 3.0] and loaded.shifts_done == 2, "the saved career loads back the same")
	DirAccess.remove_absolute(Career.save_path)


func _test_shifts() -> void:
	# Shift 1: one quick guest, no complaints.
	var q := _guests.spawn_guest(0, 1)
	q.patience = 45
	q.ride_patience = 60
	await _wait_until(func() -> bool: return q.state == Guest.State.RIDING)
	await _ride_to(1)
	await _wait_until(_gone(q))
	var text := await _end_shift()
	var first := _shift.money()
	_check(first == Shift.FARE + Shift.WAIT_TIP + Shift.WAGE, "shift 1 earns fare, tip and wage (€%.2f)" % first)
	_check(text.contains("Shift 1 over") and text.contains("Hotel rating: 5.0 ★   average so far: 5.0 ★"), "the report shows the shift's rating next to the average")
	_check(text.contains("Bank balance: €%.2f" % first), "the report shows the bank balance")
	_check(_button_text() == "Next shift", "the button goes on to the next shift")
	var saved := Career.load_saved()
	_check(saved.balance == first and saved.ratings == [5.0] and saved.shifts_done == 1, "the end of the shift saved the career")

	# Shift 2: a fresh scene picks the balance up from the save.
	await _next()
	_check(_shift.money() == 0 and _shift.stars == Shift.START_STARS, "the next shift starts at €0 and 5 stars")
	_shift.stars = 3.0
	text = await _end_shift()
	_check(text.contains("Shift 2 over") and text.contains("Hotel rating: 3.0 ★   average so far: 4.0 ★"), "the average now covers two shifts")
	_check(text.contains("Bank balance: €%.2f" % (first + Shift.WAGE)), "the wage adds to the balance")

	# Shift 3: fired. The money and the rating still count, but the shift is tried again.
	await _next()
	_shift.stars = 1.5
	text = await _end_shift()
	_check(text.contains("You're fired!") and text.contains("Hotel rating: 1.5 ★   last 3 shifts: 3.2 ★"), "being fired counts towards the average")
	_check(text.contains("Bank balance: €%.2f" % (first + 2 * Shift.WAGE)), "being fired keeps the shift's pay")
	_check(_button_text() == "Play the shift again", "after being fired you play the shift again")

	# Shift 3 again: the oldest rating drops out of the average.
	await _next()
	_shift.stars = 4.5
	text = await _end_shift()
	_check(text.contains("Shift 3 over") and text.contains("Hotel rating: 4.5 ★   last 3 shifts: 3.0 ★"), "the retried shift counts as shift 3, and shift 1 drops out of the average")
	saved = Career.load_saved()
	_check(saved.balance == first + 3 * Shift.WAGE and saved.ratings == [5.0, 3.0, 1.5, 4.5] and saved.shifts_done == 3, "the save holds all four shifts (€%.2f)" % saved.balance)


## Runs the clock out on an empty cabin and returns the report's text.
func _end_shift() -> String:
	_shift.minutes = Shift.END - 0.1
	var ended := await _wait_until(func() -> bool: return _shift.is_over)
	var report := _report()
	_check(ended and report.visible, "the shift ends and the report shows")
	var text := ""
	for child in report.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text


## Presses the report's button and waits for the reloaded scene.
func _next() -> void:
	var old_id := _scene.get_instance_id() # an id, because the old scene gets freed
	(_report().find_child("Continue", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	_load_scene(current_scene)
	_shift.spawning = false


func _report() -> ShiftReport:
	return _scene.find_child("ShiftReport", true, false)


func _button_text() -> String:
	return (_report().find_child("Continue", true, false) as Button).text
