extends "res://tests/scene_test.gd"
## Headless scripted test of the staff room between shifts: buying upgrades from the bank
## balance, saving them, and finding them in the cab the next shift: a music box that makes
## guests put up with a longer ride, a bigger cab, faster doors and a call panel.
##
## Run: tests/run.sh staff_room_test


func _run() -> void:
	_test_buying()
	_shift.spawning = false
	_check(_elevator.door_time == Elevator.DOOR_TIME and _guests.capacity == 3 and _guests.ride_patience_scale == 1.0, "a fresh career starts with the standard cab")
	_check(_scene.find_child("MusicBox", true, false) == null, "and a silent one")
	await _test_no_call_panel()
	await _test_staff_room()
	await _test_bigger_cab()
	await _test_call_panel()


func _test_buying() -> void:
	var c := Career.new()
	c.balance = 100.0
	_check(c.level(Upgrades.MUSIC) == 0 and c.next_price(Upgrades.MUSIC) == 40.0, "music starts at level 0 and the music box costs €40")
	_check(c.buy(Upgrades.MUSIC) and c.level(Upgrades.MUSIC) == 1 and c.balance == 60.0, "buying it pays from the balance")
	_check(not c.can_buy(Upgrades.MUSIC) and not c.buy(Upgrades.MUSIC) and c.balance == 60.0, "the next level (€100) is out of reach with €60, and nothing changes")
	c.balance = 1000.0
	_check(c.buy(Upgrades.DOORS) and c.buy(Upgrades.DOORS), "two levels of faster doors")
	_check(c.next_price(Upgrades.DOORS) < 0 and not c.buy(Upgrades.DOORS), "and then the doors are at the top")
	_check(c.balance == 1000.0 - 50.0 - 125.0, "each level costs its own price")
	for upgrade in Upgrades.CATALOGUE:
		_check(upgrade.effects.size() == upgrade.prices.size(), "%s describes every level it sells" % upgrade.name)


func _test_no_call_panel() -> void:
	_check(_elevator.call_panel_level == 0 and _scene.find_child("CallPanel", true, false) == null, "a fresh cab has no call panel")
	_check(_text(_scene).contains("A ding means a guest is calling"), "so the shift starts by pointing at the ding")
	var g := _guests.spawn_guest(2, 0)
	_check(_elevator.dings == 1 and _elevator.call_state(2) != Elevator.CallLamp.OFF, "a guest still calls, with a ding")
	_check(not _elevator.is_call_lamp_lit(2), "but no lamp shows where")
	g.queue_free()
	_guests._guests.erase(g)


func _test_staff_room() -> void:
	# Earn a shift's wage, with €60 in the bank from before.
	var c := Career.new()
	c.balance = 60.0
	_check(c.save() == OK, "a career with €60 saved")
	_load_scene(await _reload())
	_shift.spawning = false
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	(_report().find_child("Continue", true, false) as Button).pressed.emit()
	var room := _room()
	_check(room.visible and not _report().visible, "after the report comes the staff room")
	_check(_text(room).contains("Bank balance: €%.2f" % (60.0 + Shift.WAGE)), "it shows the bank balance")
	_check(_text(room).contains("Next: A music box"), "it says what the next level does")
	_check(_buy_button(Upgrades.MUSIC).text == "Buy €40" and not _buy_button(Upgrades.MUSIC).disabled, "the music box is for sale at €40")
	_check(_buy_button(Upgrades.CAB).text == "Buy €75" and _buy_button(Upgrades.CAB).disabled, "the bigger cab (€75) is out of reach")

	_buy_button(Upgrades.MUSIC).pressed.emit()
	var left := 60.0 + Shift.WAGE - 40.0
	_check(_text(room).contains("Bank balance: €%.2f" % left), "buying takes the price off the balance")
	_check(_text(room).contains("Music   level 1 of 3"), "and raises the level")
	var saved := Career.load_saved()
	_check(saved.level(Upgrades.MUSIC) == 1 and saved.balance == left, "the purchase is saved straight away")

	_check(_buy_button(Upgrades.DOORS).disabled, "now the faster doors (€50) are out of reach")
	_buy_button(Upgrades.DOORS).pressed.emit()
	_check(Career.load_saved().level(Upgrades.DOORS) == 0, "and pressing anyway buys nothing")
	_check(_text(room).contains("Bank balance: €%.2f" % left), "nor costs anything")

	# Pretend you saved up for the doors as well.
	var saved_up := Career.load_saved()
	saved_up.upgrades[Upgrades.DOORS] = 1
	saved_up.save()
	await _start_shift()

	_check(_elevator.music_level == 1 and _scene.find_child("MusicBox", true, false) != null, "the next shift there's a music box in the cab")
	_check(_elevator.door_time == Upgrades.DOOR_TIME[1], "and the doors are faster")
	var started := Time.get_ticks_msec()
	_press("close")
	await _wait_until(func() -> bool: return not _elevator.doors_open and not _elevator._doors_busy)
	_check(Time.get_ticks_msec() - started < Elevator.DOOR_TIME * 1000, "they close in under %.1f s" % Elevator.DOOR_TIME)
	_press("open")
	await _wait_until(func() -> bool: return _elevator.is_open_at_rest())

	var g := _guests.spawn_guest(0, 1)
	var temperament: Dictionary = Guest.TEMPERAMENTS.filter(func(t: Dictionary) -> bool: return t.name == g.temperament)[0]
	_check(is_equal_approx(g.ride_patience, temperament.ride * Upgrades.RIDE_PATIENCE[1]), "with music a %s guest puts up with a %.1f s ride (%.1f s without)" % [g.temperament, g.ride_patience, temperament.ride])
	_check(is_equal_approx(g.patience, temperament.wait), "music doesn't change how long they wait for the cab")


func _test_bigger_cab() -> void:
	var c := Career.load_saved()
	c.upgrades[Upgrades.CAB] = 1
	c.save()
	_load_scene(await _reload())
	_shift.spawning = false
	_guests.patience_scale = 10.0
	_check(_guests.capacity == 4 and _elevator.capacity == 4, "the bigger cab holds 4 guests")
	_check(_all_text(_elevator).contains("Max 4 persons"), "the plate by the buttons says so")
	var floor_1: Array[Guest] = []
	for i in 3:
		floor_1.append(_guests.spawn_guest(1, 0))
	var floor_2: Array[Guest] = []
	for i in 2:
		floor_2.append(_guests.spawn_guest(2, 0))
	await _ride_to(1)
	_check(await _wait_until(func() -> bool: return floor_1.all(func(g: Guest) -> bool: return g.state == Guest.State.RIDING)), "three guests board on floor 1")
	await _ride_to(2)
	await _wait_seconds(3)
	var riding := floor_2.filter(func(g: Guest) -> bool: return g.state == Guest.State.RIDING)
	_check(riding.size() == 1, "on floor 2 only one more fits: four aboard (%d boarded)" % riding.size())


func _test_call_panel() -> void:
	for level in [1, 2]:
		var c := Career.load_saved()
		c.upgrades[Upgrades.CALLS] = level
		c.save()
		_load_scene(await _reload())
		_shift.spawning = false
		_check(_scene.find_child("CallPanel", true, false) != null, "call panel level %d: the panel is in the cab" % level)
		_check(_text(_scene).contains("watch the Calls lamps"), "and the shift starts by pointing at it")
		var g := _guests.spawn_guest(2, 0)
		_check(_elevator.is_call_lamp_lit(2), "a guest calling on floor 2 lights its lamp")
		g.waited = g.patience * Guest.IMPATIENT_SHARE + 0.1
		await _wait_until(func() -> bool: return _elevator.call_state(2) == Elevator.CallLamp.BLINKING)
		var dark := false
		for i in Engine.physics_ticks_per_second:
			dark = dark or not _elevator.is_call_lamp_lit(2)
			await physics_frame
		if level == 1:
			_check(not dark, "level 1: the lamp stays lit when the guest gets impatient")
		else:
			_check(dark, "level 2: the lamp blinks when the guest gets impatient")


## Loads the scene afresh, the way the staff room starts a shift, and returns it.
func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene


func _start_shift() -> void:
	var old_id := _scene.get_instance_id()
	(_room().find_child("StartShift", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	_check(not paused, "the shift starts")
	_load_scene(current_scene)
	_shift.spawning = false


func _room() -> StaffRoom:
	return _scene.find_child("StaffRoom", true, false)


func _report() -> ShiftReport:
	return _scene.find_child("ShiftReport", true, false)


func _buy_button(id: String) -> Button:
	return _room().find_child("Buy_%s" % id, true, false)


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text


func _all_text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label3D", true, false):
		text += (child as Label3D).text + "\n"
	return text
