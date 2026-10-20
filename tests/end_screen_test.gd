extends "res://tests/scene_test.gd"
## Headless scripted test of the end of the demo: at Pension Bellevue, the last hotel, the
## staff room offers the Grand Hotel once the rating is there; applying shows the "to be
## continued" screen, and from there you can go back and keep working.
##
## Run: tests/run.sh end_screen_test


func _run() -> void:
	_shift.spawning = false
	var c := Career.new()
	c.hotel = 1
	c.balance = 100.0
	c.ratings.assign([3.0, 5.0])
	c.shifts_done = 2
	c.upgrades = {Upgrades.SPANISH: 3, Upgrades.MUSIC: 2}
	c.save()
	_load_scene(await _reload())
	_shift.spawning = false
	_check(_shift.hotel.id == "bellevue", "a career at Pension Bellevue")

	# A poor shift: the average stays under 4 stars.
	await _finish_shift(3.0)
	var room := _room()
	var apply := room.find_child("MoveUp", true, false) as Button
	_check(_text(room).contains("Move up to Grand Hotel (12 floors)"), "at Pension Bellevue the staff room offers the Grand Hotel")
	_check(apply.is_visible_in_tree() and apply.disabled, "but %.1f ★ isn't enough to apply" % Career.load_saved().average_rating())
	apply.pressed.emit()
	_check(not _end().visible and room.visible, "and pressing anyway does nothing")

	# A great shift lifts the last three to 4 stars or more.
	await _start_shift()
	await _finish_shift(5.0)
	room = _room()
	apply = room.find_child("MoveUp", true, false) as Button
	_check(not apply.disabled and apply.text == "Apply", "with %.1f ★ you can apply, without a fee" % Career.load_saved().average_rating())
	var balance := Career.load_saved().balance
	apply.pressed.emit()
	var end := _end()
	_check(end.visible and not room.visible, "applying shows the end screen")
	var text := _text(end)
	_check(text.contains("To be continued: Grand Hotel"), "to be continued at the Grand Hotel")
	_check(text.contains("Thanks for playing"), "it thanks you for playing")
	_check(text.contains("Spanish lessons: 3 of 5") and text.contains("Music: level 2 of 3"), "and shows how far you got")
	_check(text.contains("Bank balance: €%.2f" % balance), "with your bank balance")
	var saved := Career.load_saved()
	_check(saved.hotel == 1 and saved.balance == balance, "you stay at Pension Bellevue, and keep your money")

	var keep := end.find_child("KeepPlaying", true, false) as Button
	_check(keep.text == "Keep working at Pension Bellevue", "you can keep working there")
	keep.pressed.emit()
	_check(room.visible and not end.visible, "which takes you back to the staff room")
	await _start_shift()
	_check(_shift.hotel.id == "bellevue", "and the next shift is at Pension Bellevue")


## Ends the current shift with [param stars] and goes on to the staff room.
func _finish_shift(stars: float) -> void:
	_shift.stars = stars
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()


## Loads the scene afresh from the save and returns it.
func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene


func _start_shift() -> void:
	var old_id := _scene.get_instance_id()
	(_room().find_child("StartShift", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	_load_scene(current_scene)
	_shift.spawning = false


func _room() -> StaffRoom:
	return _scene.find_child("StaffRoom", true, false)


func _end() -> EndScreen:
	return _scene.find_child("EndScreen", true, false)


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
