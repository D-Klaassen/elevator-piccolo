extends "res://tests/scene_test.gd"
## Headless scripted test of greetings: guests greet you when they board or when you
## first click them, the HUD offers a friendly, neutral and rude reply, and your reply
## changes the tip (and a rude one may cost a complaint).
##
## Run: godot --headless --path . --fixed-fps 60 --script tests/greeting_test.gd

var _replies: ReplyChoices


func _run() -> void:
	_shift.spawning = false
	_replies = _scene.find_child("ReplyChoices", true, false)
	await _test_friendly_by_key()
	await _test_rude_by_click()
	await _test_no_answer()
	await _test_click_to_greet()
	await _test_one_at_a_time()


func _test_friendly_by_key() -> void:
	# The cab stands open on floor 0: the guest boards straight away and greets.
	var g := _guests.spawn_guest(0, 1)
	g.patience = 600
	g.ride_patience = 600
	_check(not _replies.visible, "no reply choices before anyone greets")
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "the guest boards")
	_check(_guests.talking_to == g and g.greeted, "the guest greets on boarding")
	_check(_replies.visible, "the HUD shows the reply choices")
	var text := _all_text(_replies)
	_check(text.contains(g.greeting.line), "the HUD shows their greeting (%s)" % g.greeting.line)
	for r: Guest.Reply in Guest.Reply.values():
		_check(text.contains('%d   "%s"' % [r + 1, g.reply_line(r)]), "reply %d is on offer: %s" % [r + 1, g.reply_line(r)])

	_press_key(KEY_1)
	_check(g.answered and g.reply == Guest.Reply.FRIENDLY, "key 1 gives the friendly reply")
	_check(not _replies.visible and _guests.talking_to == null, "the choices go away after replying")
	_check(_last_said.begins_with("You: ") and _last_said.contains(g.reply_line(Guest.Reply.FRIENDLY)), "the HUD shows what you said (%s)" % _last_said)
	g.press()
	_check(_last_said.to_lower().contains("floor 1"), "after the greeting they name their floor (%s)" % _last_said)

	await _ride_to(1)
	_check(await _wait_until(_gone(g)), "friendly guest delivered")
	_check(_shift.tips == Shift.MAX_TIP, "quick and friendly earns the full €6 tip (got €%.2f)" % _shift.tips)
	_check(_last_said.contains("+€2 fare, +€6 tip"), "the pay shows in the HUD (%s)" % _last_said)


func _test_rude_by_click() -> void:
	var g := _guests.spawn_guest(1, 2)
	g.patience = 600
	g.ride_patience = 600
	await _wait_until(func() -> bool: return _guests.talking_to == g)
	_shift.rng.seed = _seed_where(func(roll: float) -> bool: return roll < Shift.RUDE_COMPLAINT_CHANCE)
	var tips := _shift.tips
	(_replies.find_child("Reply3", true, false) as Button).pressed.emit()
	_check(g.answered and g.reply == Guest.Reply.RUDE, "clicking reply 3 gives the rude reply")
	_check(_shift.rude_complaints == 1 and _shift.stars == Shift.START_STARS - Shift.COMPLAINT, "the rude reply gets a complaint: -½ star")
	_check(_last_said.contains("rude"), "the guest says so (%s)" % _last_said)

	await _ride_to(2)
	_check(await _wait_until(_gone(g)), "rude guest delivered")
	var tip := _shift.tips - tips
	_check(tip == floorf(Shift.WAIT_TIP * Shift.RUDE_TIP_SHARE), "a rude reply halves the tip (got €%.2f)" % tip)
	_check(_shift.fares == 2 * Shift.FARE, "a rude reply still pays the fare")


func _test_no_answer() -> void:
	var g := _guests.spawn_guest(2, 1)
	g.patience = 600
	g.ride_patience = 600
	await _wait_until(func() -> bool: return _guests.talking_to == g)
	_check(await _wait_until(func() -> bool: return _guests.talking_to == null, GuestManager.REPLY_TIME + 1), "the guest stops waiting for a reply after %d s" % GuestManager.REPLY_TIME)
	_check(not _replies.visible, "the choices go away")
	_check(not g.answered and g.reply == Guest.Reply.NEUTRAL, "no answer counts as neutral")
	var tips := _shift.tips
	await _ride_to(1)
	_check(await _wait_until(_gone(g)), "unanswered guest delivered")
	_check(_shift.tips - tips == Shift.WAIT_TIP, "no answer leaves the tip alone (got €%.2f)" % (_shift.tips - tips))


func _test_click_to_greet() -> void:
	# Two guests wait on floor 0 while the cab stands on floor 1.
	var d := _guests.spawn_guest(0, 2)
	d.patience = 600
	d.ride_patience = 600
	var e := _guests.spawn_guest(0, 1)
	e.patience = 600
	await _wait_until(func() -> bool: return d.state == Guest.State.WAITING and e.state == Guest.State.WAITING)
	_check(_guests.talking_to == null, "waiting guests don't greet by themselves")
	var said := _last_said
	d.press()
	_check(_guests.talking_to == d and _replies.visible, "clicking a guest the first time gets their greeting")
	_check(_last_said == said, "not their floor yet")

	_shift.rng.seed = _seed_where(func(roll: float) -> bool: return roll >= Shift.RUDE_COMPLAINT_CHANCE)
	var stars := _shift.stars
	_press_key(KEY_3)
	_check(d.reply == Guest.Reply.RUDE and _shift.stars == stars, "a rude reply doesn't always get a complaint")
	_press_key(KEY_1)
	_check(d.reply == Guest.Reply.RUDE, "number keys do nothing when nobody waits for a reply")

	e.press()
	_check(_guests.talking_to == e, "the other guest greets when clicked")
	e.patience = e.waited + 0.5
	_check(await _wait_until(func() -> bool: return e.state == Guest.State.LEAVING), "that guest gives up waiting")
	_check(_guests.talking_to == null and not _replies.visible, "the choices go away when the guest leaves")

	var tips := _shift.tips
	await _ride_to(0)
	await _wait_until(func() -> bool: return d.state == Guest.State.RIDING)
	_check(_guests.talking_to == null, "a guest who already greeted doesn't greet again on boarding")
	await _ride_to(2)
	_check(await _wait_until(_gone(d)), "rude guest from the hallway delivered")
	_check(_shift.tips - tips == floorf(Shift.WAIT_TIP * Shift.RUDE_TIP_SHARE), "the reply from the hallway counts at drop-off (got €%.2f)" % (_shift.tips - tips))


func _test_one_at_a_time() -> void:
	# Two guests board together on floor 2 and greet one after the other.
	var f := _guests.spawn_guest(2, 0)
	var h := _guests.spawn_guest(2, 1)
	for g in [f, h]:
		g.patience = 600
		g.ride_patience = 600
	_check(await _wait_until(func() -> bool: return f.state == Guest.State.RIDING and h.state == Guest.State.RIDING), "two guests board")
	# Whoever reached the cab first greets first.
	var first := _guests.talking_to
	var second := h if first == f else f
	_check(first in [f, h] and not second.answered, "the first one to board greets")
	_press_key(KEY_2)
	_check(first.reply == Guest.Reply.NEUTRAL and first.answered, "key 2 gives the neutral reply")
	_check(_guests.talking_to == second and _replies.visible, "then the second one greets")
	_check(_all_text(_replies).contains(second.greeting.line), "with their own greeting")
	_press_key(KEY_1)
	_check(second.reply == Guest.Reply.FRIENDLY and not _replies.visible, "and gets their own reply")


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate()
	release.pressed = false
	root.push_input(release)


## A seed for which the first [method RandomNumberGenerator.randf] passes [param test].
func _seed_where(test: Callable) -> int:
	var r := RandomNumberGenerator.new()
	for s in 1000:
		r.seed = s
		if test.call(r.randf()):
			return s
	return 0


func _all_text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "", true, false):
		if child is Label or child is Button:
			text += child.text + "\n"
	return text
