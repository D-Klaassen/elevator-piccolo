extends "res://tests/scene_test.gd"
## Headless scripted test of moving up from the rustic cabin to Pension Bellevue: what it
## takes (a 4-star average over the last 3 shifts and the application fee), applying from
## the staff room, and what changes there: 7 floors, more guests, better pay, full upgrade
## prices, the music box along and the rest of the cab starting over.
##
## Run: tests/run.sh hotel_test


func _run() -> void:
	_test_rules()
	_shift.spawning = false
	_check(_shift.hotel.id == "cabin" and _elevator.floor_count == 3, "a fresh career starts in the 3-floor rustic cabin")
	await _test_apply()
	await _test_bellevue()


func _test_rules() -> void:
	var c := Career.new()
	c.balance = 1000.0
	_check(not c.can_move(), "no move before a single shift")
	c.ratings.assign([5.0, 5.0])
	_check(not c.can_move(), "two great shifts aren't enough: it takes %d" % Career.AVERAGE_OVER)
	c.ratings.assign([5.0, 5.0, 3.5])
	_check(c.can_move(), "three shifts averaging %.2f ★ are" % c.average_rating())
	c.ratings.assign([5.0, 4.0, 3.5, 4.0])
	_check(not c.can_move(), "only the last 3 count (%.2f ★)" % c.average_rating())
	c.ratings.assign([4.0, 4.0, 4.0])
	c.balance = Hotels.at(1).fee - 1
	_check(not c.can_move() and not c.move_up() and c.hotel == 0, "short of the fee you stay put")

	c.balance = Hotels.at(1).fee + 500
	c.upgrades = {Upgrades.MUSIC: 2, Upgrades.CAB: 1, Upgrades.DOORS: 2, Upgrades.CALLS: 1}
	c.shifts_done = 3
	var music_price := c.next_price(Upgrades.MUSIC)
	_check(c.move_up(), "with the rating and the fee you move up")
	_check(c.hotel == 1 and c.hotel_info().name == "Pension Bellevue", "to Pension Bellevue")
	_check(c.balance == 500, "the fee is paid")
	_check(c.ratings.is_empty() and c.shifts_done == 0, "ratings and shifts start afresh")
	_check(c.level(Upgrades.MUSIC) == 2, "the music box comes along")
	_check(c.level(Upgrades.CAB) == 0 and c.level(Upgrades.DOORS) == 0 and c.level(Upgrades.CALLS) == 0, "the cab, doors and call panel stay behind")
	_check(c.next_price(Upgrades.MUSIC) == 2 * music_price, "upgrades cost twice the cabin's price (€%d)" % c.next_price(Upgrades.MUSIC))
	c.ratings.assign([5.0, 5.0, 5.0])
	_check(not c.can_move(), "Pension Bellevue is the last hotel for now")


func _test_apply() -> void:
	var c := Career.new()
	c.balance = Hotels.at(1).fee - Shift.WAGE + 20 # the shift's wage tips it over the fee
	c.ratings.assign([4.5, 4.0])
	c.shifts_done = 2
	c.upgrades = {Upgrades.MUSIC: 1, Upgrades.CALLS: 2}
	c.save()
	_load_scene(await _reload())
	_shift.spawning = false
	_shift.stars = 4.0
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	var report: ShiftReport = _scene.find_child("ShiftReport", true, false)
	_check(_text(report).contains("Rustic cabin"), "the report names the hotel")
	(report.find_child("Continue", true, false) as Button).pressed.emit()

	var room: StaffRoom = _scene.find_child("StaffRoom", true, false)
	var text := _text(room)
	_check(text.contains("Staff room · Rustic cabin"), "the staff room says where you are")
	_check(text.contains("Move up to Pension Bellevue (7 floors)"), "and offers the next hotel")
	_check(text.contains("Last 3 shifts: 4.2 ★") and text.contains("application fee of €%d" % Hotels.at(1).fee), "with the rating and the fee it takes")
	var apply := room.find_child("MoveUp", true, false) as Button
	_check(not apply.disabled, "both are met, so you can apply")
	apply.pressed.emit()
	text = _text(room)
	_check(text.contains("Staff room · Pension Bellevue") and text.contains("Bank balance: €20.00"), "after applying you're at Pension Bellevue with the fee paid")
	_check(not room.find_child("MoveUp", true, false).is_visible_in_tree(), "and there's no further hotel to apply to yet")
	_check(text.contains("Music   level 1 of 3") and text.contains("Call panel   level 0 of 2"), "the music box came along, the call panel didn't")
	var saved := Career.load_saved()
	_check(saved.hotel == 1 and saved.balance == 20.0, "the move is saved straight away")

	var old_id := _scene.get_instance_id()
	(room.find_child("StartShift", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	_load_scene(current_scene)
	_shift.spawning = false


func _test_bellevue() -> void:
	_check(_shift.hotel.id == "bellevue", "the next shift is at Pension Bellevue")
	_check(_elevator.floor_count == 7 and _elevator._buttons.has("6") and not _elevator._buttons.has("7"), "with 7 floors, and a button for each")
	_check(_text(_scene).contains("Pension Bellevue"), "the clock shows the hotel")
	_check(_elevator.music_level == 1 and _elevator.call_panel_level == 0, "a music box but no call panel")
	_check(_guests.ride_patience_scale == Upgrades.RIDE_PATIENCE[1] * Hotels.at(1).ride_patience, "guests put up with longer rides in the taller shaft")

	var g := _guests.spawn_guest(0, 6)
	g.patience = 600
	g.ride_patience = 600
	await _wait_until(func() -> bool: return g.state == Guest.State.RIDING)
	await _ride_to(6)
	_check(await _wait_until(_gone(g)), "a guest rides up to floor 6")
	_check(_shift.fares == Shift.FARE * 1.5 and _shift.tips == Shift.WAIT_TIP * 1.5, "and pays half as much again: €%.2f fare, €%.2f tip" % [_shift.fares, _shift.tips])


## Loads the scene afresh from the save and returns it.
func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
