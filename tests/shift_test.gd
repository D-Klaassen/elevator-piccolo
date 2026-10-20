extends "res://tests/scene_test.gd"
## Headless scripted test of a shift: the clock, patience, pay and tips, the end-of-shift
## report and playing again, then a whole shift played by an autopilot through the buttons.
##
## Run: tests/run.sh shift_test


func _run() -> void:
	_test_rules()
	_shift.spawning = false
	await _test_clock()
	await _test_patience()
	await _test_pay()
	await _test_ride_patience()
	await _test_end_and_play_again()
	await _test_full_shift()


func _test_rules() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var times := Shift.make_schedule(r)
	_check(times.size() == Shift.GUESTS, "%d guests per shift" % Shift.GUESTS)
	_check(times == _sorted(times), "the schedule is in order")
	_check(times[0] == Shift.FIRST_GUEST_AT, "the first guest calls at %s" % Shift.format_clock(times[0]))
	_check(times.all(func(t: float) -> bool: return t >= Shift.START and t < Shift.END), "every guest comes between 08:00 and 18:00")
	var lunch := times.filter(func(t: float) -> bool: return t >= Shift.LUNCH_START and t < Shift.LUNCH_END).size()
	var lunch_rate := lunch / float(Shift.LUNCH_END - Shift.LUNCH_START)
	var other_rate := (times.size() - lunch) / float(Shift.END - Shift.START - (Shift.LUNCH_END - Shift.LUNCH_START))
	_check(lunch >= Shift.LUNCH_GUESTS and lunch_rate > 2 * other_rate, "a lunch rush (%d guests in 12:00-13:30)" % lunch)

	_check(Shift.tip_for_wait(0, 45) == 4 and Shift.tip_for_wait(9, 45) == 4, "a quick pick-up earns the full €4 wait tip")
	_check(Shift.tip_for_wait(27, 45) == 2, "27 s of a 45 s patience earns half the wait tip")
	_check(Shift.tip_for_wait(45, 45) == 0, "a guest at the end of their patience tips nothing")
	_check(Shift.tip_for_wait(20, 30) < Shift.tip_for_wait(20, 60), "the same wait earns less from a hasty guest")
	var waits := Guest.TEMPERAMENTS.map(func(t: Dictionary) -> float: return t.wait)
	_check(waits.min() < waits.max(), "some guests are more patient than others (%s)" % [waits])
	_check(Shift.tip_for(0, 45, Guest.Reply.NEUTRAL) == 4, "a neutral reply (or none) leaves the tip alone")
	_check(Shift.tip_for(0, 45, Guest.Reply.GOOD) == Shift.MAX_TIP, "quick, with a good reply, earns the full €6 tip")
	_check(Shift.tip_for(27, 45, Guest.Reply.GOOD) == 4, "a good reply makes up for some waiting")
	_check(Shift.tip_for(0, 45, Guest.Reply.BAD) == 2 and Shift.tip_for(27, 45, Guest.Reply.BAD) == 1, "a bad reply halves the tip")
	_check(Shift.tip_for(45, 45, Guest.Reply.BAD) == 0, "a bad reply never costs more than the tip")
	_check(Shift.format_clock(8 * 60 + 5) == "08:05", "the clock reads 08:05")


func _test_clock() -> void:
	_check(int(_shift.minutes) == Shift.START, "the shift starts at 08:00")
	await _wait_seconds(_shift.length_seconds / 100.0)
	_check(_shift.minutes > Shift.START + 5, "the clock runs (%s)" % Shift.format_clock(_shift.minutes))


func _test_patience() -> void:
	# A guest on floor 2 while the cab stays on floor 0.
	var p := _guests.spawn_guest(2, 0)
	p.patience = 45
	await _wait_seconds(p.patience * Guest.IMPATIENT_SHARE - 1)
	_check(_elevator.call_state(2) == Elevator.CallLamp.ON and not p.is_impatient(), "the call lamp is steady at first")
	await _wait_seconds(2)
	_check(_elevator.call_state(2) == Elevator.CallLamp.BLINKING, "the call lamp blinks once the guest gets impatient")
	_check(p._marker.visible, "a red ! shows above the impatient guest")
	_check(await _wait_until(func() -> bool: return p.state == Guest.State.LEAVING, p.patience), "the guest gives up after %d s" % p.patience)
	_check(_elevator.call_state(2) == Elevator.CallLamp.OFF, "the call lamp goes out when they leave")
	_check(_last_said.contains("stairs"), "they say they'll take the stairs (%s)" % _last_said)
	_check(_shift.lost == 1 and _shift.stars == Shift.START_STARS - Shift.COMPLAINT, "a complaint costs half a star")
	_check(_shift.money() == 0, "a guest who gave up pays nothing")
	_check(await _wait_until(_gone(p)), "they walk off and disappear")


func _test_pay() -> void:
	# Quick service: boards straight away on floor 0, out on floor 1.
	var q := _guests.spawn_guest(0, 1)
	q.patience = 45
	q.ride_patience = 60
	await _wait_until(func() -> bool: return q.state == Guest.State.RIDING)
	await _ride_to(1)
	_check(await _wait_until(_gone(q)), "quick guest delivered")
	_check(_shift.fares == Shift.FARE and _shift.tips == Shift.WAIT_TIP, "fare €2 + full wait tip €4 (got €%.2f + €%.2f)" % [_shift.fares, _shift.tips])
	_check(_last_said.contains("+€2 fare, +€4 tip"), "the pay shows in the HUD (%s)" % _last_said)

	# Slow service: the cab only comes back for them after 30 s.
	var r := _guests.spawn_guest(0, 1)
	r.patience = 60
	r.ride_patience = 60
	await _wait_seconds(30)
	await _ride_to(0)
	await _wait_until(func() -> bool: return r.state == Guest.State.RIDING)
	var expected := Shift.tip_for_wait(r.waited, r.patience)
	await _ride_to(1)
	_check(await _wait_until(_gone(r)), "slow guest delivered")
	var tip := _shift.tips - Shift.WAIT_TIP
	_check(tip == expected and tip > 0 and tip < Shift.WAIT_TIP, "a slow pick-up earns a smaller tip (€%.2f)" % tip)
	_check(_shift.served == 2, "two guests served")


func _test_ride_patience() -> void:
	# A guest boards on floor 1 for floor 0, but the cab heads up to floor 2 instead.
	var f := _guests.spawn_guest(1, 0)
	f.patience = 60
	f.ride_patience = 4
	await _wait_until(func() -> bool: return f.state == Guest.State.RIDING)
	var lost := _shift.lost
	var money := _shift.money()
	await _ride_to(2)
	_check(f.fed_up and _shift.lost == lost + 1, "a guest who rides too long complains")
	_check(_last_said.contains("next stop"), "they want out at the next stop (%s)" % _last_said)
	_check(await _wait_until(_gone(f)), "they get out on floor 2, not their floor, and disappear")
	_check(_shift.money() == money and _shift.served == 2, "a fed-up rider pays nothing")


func _test_end_and_play_again() -> void:
	var before := _shift.money()
	_shift.minutes = Shift.END - 0.1
	_check(await _wait_until(func() -> bool: return _shift.is_over), "the shift ends at 18:00 with nobody waiting")
	var report: ShiftReport = _scene.find_child("ShiftReport", true, false)
	_check(report.visible, "the end-of-shift report shows")
	_check(paused, "the game pauses behind the report")
	_check(_shift.wage == Shift.WAGE and _shift.money() == before + Shift.WAGE, "the base wage is paid at the end")
	var text := _all_text(report)
	_check(text.contains("Shift 1 over") and text.contains("Guests served: 2") and text.contains("took the stairs: 2") and text.contains("your replies: 0") and text.contains("4.0 ★"), "the report sums up the day")
	_check(not _shift.is_fired(), "4 stars keeps the job")
	_shift.stars = 1.5
	_check(_shift.is_fired(), "below 2 stars you're fired")

	var old_id := _scene.get_instance_id() # an id, because the old scene gets freed
	(report.find_child("Continue", true, false) as Button).pressed.emit()
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready()), "play again reloads the scene")
	_load_scene(current_scene)
	_check(not paused and int(_shift.minutes) == Shift.START and _shift.money() == 0 and _shift.stars == Shift.START_STARS, "a fresh shift starts at 08:00 with €0 and 5 stars")


func _test_full_shift() -> void:
	# The autopilot answers calls and delivers riders, nearest floor first,. Chats are off by
	# default, so nobody should chat.
	_shift.spawning = true
	var temperaments := {}
	var first := {} # floor and clock time of the first guest
	_guests.child_entered_tree.connect(func(node: Node) -> void:
		if node is Guest:
			temperaments[node.temperament] = true
			if first.is_empty():
				first.merge({"floor": node.home_floor, "minutes": _shift.minutes}))
	var rides := 0
	var chats := [0] # an array, so the lambda can count
	_guests.chatting.connect(func(_guest: Guest) -> void:
		chats[0] += 1
		_guests.reply.call_deferred(Guest.Reply.GOOD))
	while not _shift.is_over:
		var target := _next_floor()
		if target < 0 or not _elevator.is_open_at_rest() or _elevator.door_blockers > 0:
			await physics_frame
			continue
		await _ride_to(target, false)
		await _wait_seconds(0.3) # let guests on this floor start boarding
		rides += 1
	print("     autopilot made %d rides and answered %d chats" % [rides, chats[0]])

	_check(_shift.is_over, "a whole shift can be played to the end")
	_check(first.floor == Shift.FIRST_GUEST_FLOOR and first.minutes < Shift.FIRST_GUEST_AT + 1,
		"the first guest turns up on floor %d at %s" % [first.floor, Shift.format_clock(first.minutes)])
	_check(_shift.spawned == Shift.GUESTS, "all %d guests turned up (%d)" % [Shift.GUESTS, _shift.spawned])
	_check(_shift.served + _shift.lost == _shift.spawned, "every guest was served or gave up (%d + %d)" % [_shift.served, _shift.lost])
	_check(_shift.served >= Shift.GUESTS / 2, "the autopilot serves most guests (%d)" % _shift.served)
	_check(chats[0] == 0, "chats are off: nobody chats (%d)" % chats[0])
	_check(temperaments.size() >= 2, "guests come with different temperaments (%s)" % [temperaments.keys()])
	_check(is_equal_approx(_shift.money(), _shift.fares + _shift.tips + Shift.WAGE), "money adds up: €%.2f" % _shift.money())
	_check(_shift.stars == Shift.START_STARS - Shift.COMPLAINT * _shift.lost, "stars: %.1f" % _shift.stars)
	_check((_scene.find_child("ShiftReport", true, false) as ShiftReport).visible, "the report shows after a full shift")


## Where the autopilot goes next: the nearest rider destination, else the nearest
## other floor with someone calling, or -1 to stay put.
func _next_floor() -> int:
	var here := _elevator.current_floor
	var riding := _guests.guests().filter(func(g: Guest) -> bool: return g.state == Guest.State.RIDING)
	var floors: Array = riding.map(func(g: Guest) -> int: return g.destination)
	if floors.is_empty():
		var calling := _guests.guests().filter(func(g: Guest) -> bool:
			return g.state == Guest.State.WAITING or g.state == Guest.State.ARRIVING)
		floors = calling.map(func(g: Guest) -> int: return g.home_floor).filter(func(f: int) -> bool: return f != here)
	if floors.is_empty():
		return -1
	floors.sort_custom(func(x: int, y: int) -> bool: return absi(x - here) < absi(y - here))
	return floors[0]


func _all_text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text


func _sorted(values: Array[float]) -> Array[float]:
	var copy := values.duplicate()
	copy.sort()
	return copy
