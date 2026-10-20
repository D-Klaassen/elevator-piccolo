extends "res://tests/scene_test.gd"
## Headless scripted test of chats: now and then a riding guest strikes up a chat, the HUD
## offers three replies in a shuffled order, and how well your reply lands changes the
## tip (and a bad one may cost a complaint).
##
## Run: tests/run.sh chat_test

var _replies: ReplyChoices


func _run() -> void:
	_shift.spawning = false
	_replies = _scene.find_child("ReplyChoices", true, false)
	_test_content()
	_test_shuffled()
	await _test_quiet_guest()
	await _test_good_reply_by_key()
	await _test_bad_reply_by_click()
	await _test_no_answer()
	await _test_one_at_a_time()


func _test_content() -> void:
	_check(Guest.CHATS.all(func(c: Dictionary) -> bool: return c.replies.size() == Guest.Reply.size()), "every chat offers %d replies" % Guest.Reply.size())
	var longest_is_good := Guest.CHATS.filter(func(c: Dictionary) -> bool:
		var lengths: Array = c.replies.map(func(t: String) -> int: return t.length())
		return lengths.max() == lengths[Guest.Reply.GOOD])
	_check(longest_is_good.size() <= Guest.CHATS.size() / 2, "the good reply isn't always the longest (%d of %d)" % [longest_is_good.size(), Guest.CHATS.size()])


func _test_shuffled() -> void:
	_guests.chat_chance = 1.0
	var orders := {}
	for i in 30:
		var g := _guests.spawn_guest(2, 0)
		orders[g.reply_order] = true
		_guests._remove(g)
	_check(orders.size() > 1, "the replies come in a different order from guest to guest (%d orders)" % orders.size())


func _test_quiet_guest() -> void:
	_guests.chat_chance = 0.0
	var g := _guests.spawn_guest(0, 1)
	g.patience = 600
	g.ride_patience = 600
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "a quiet guest boards")
	g.press()
	_check(_last_said.to_lower().contains("floor 1"), "clicking a guest names their floor straight away (%s)" % _last_said)
	await _wait_seconds(GuestManager.CHAT_DELAY_MAX + 1)
	_check(_guests.talking_to == null and not _replies.visible, "a quiet guest doesn't chat")
	await _ride_to(1)
	_check(await _wait_until(_gone(g)), "quiet guest delivered")
	_check(_shift.tips == Shift.WAIT_TIP, "a quiet guest tips for the wait alone (got €%.2f)" % _shift.tips)


func _test_good_reply_by_key() -> void:
	var g := _chatty_guest(1, 2)
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "a chatty guest boards")
	_check(await _wait_until(func() -> bool: return _guests.talking_to == g, GuestManager.CHAT_DELAY_MAX + 1), "a little into the ride they strike up a chat")
	_check(g.rode >= GuestManager.CHAT_DELAY_MIN, "not straight away (%.1f s after boarding)" % g.rode)
	_check(_replies.visible, "the HUD shows the reply choices")
	var text := _all_text(_replies)
	_check(text.contains(g.chat.line), "the HUD shows what they said (%s)" % g.chat.line)
	for i in g.reply_order.size():
		var line := g.reply_line(g.reply_order[i])
		_check(text.contains('%d   "%s"' % [i + 1, line]), "reply %d is on offer: %s" % [i + 1, line])
	g.press()
	_check(_last_said.to_lower().contains("floor 2") and _replies.visible, "clicking them still names their floor, and the choices stay up")

	_press_key(KEY_1 + g.reply_order.find(Guest.Reply.GOOD))
	_check(g.answered and g.reply == Guest.Reply.GOOD, "the number key of the good reply picks it")
	_check(not _replies.visible and _guests.talking_to == null, "the choices go away after replying")
	_check(Guest.REACTIONS[Guest.Reply.GOOD].any(func(r: String) -> bool: return _last_said.contains(r)), "the guest reacts (%s)" % _last_said)

	var tips := _shift.tips
	await _ride_to(2)
	_check(await _wait_until(_gone(g)), "chatty guest delivered")
	_check(_shift.tips - tips == Shift.MAX_TIP, "quick, with a good reply, earns the full €6 tip (got €%.2f)" % (_shift.tips - tips))
	_check(_last_said.contains("+€2 fare, +€6 tip"), "the pay shows in the HUD (%s)" % _last_said)


func _test_bad_reply_by_click() -> void:
	var g := _chatty_guest(2, 0)
	g.reply_order = [Guest.Reply.BAD, Guest.Reply.GOOD, Guest.Reply.NEUTRAL] as Array[Guest.Reply]
	await _wait_until(func() -> bool: return _guests.talking_to == g, 30)
	_check(_all_text(_replies).contains('1   "%s"' % g.reply_line(Guest.Reply.BAD)), "the HUD lists the replies in the guest's order")
	_shift.rng.seed = _seed_where(func(roll: float) -> bool: return roll < Shift.BAD_REPLY_COMPLAINT_CHANCE)
	var stars := _shift.stars
	(_replies.find_child("Reply1", true, false) as Button).pressed.emit()
	_check(g.answered and g.reply == Guest.Reply.BAD, "clicking the top reply picks the one listed there")
	_check(_shift.reply_complaints == 1 and _shift.stars == stars - Shift.COMPLAINT, "the bad reply gets a complaint: -½ star")
	_check(_last_said.contains("manager"), "the guest says so (%s)" % _last_said)

	var tips := _shift.tips
	await _ride_to(0)
	_check(await _wait_until(_gone(g)), "guest with a bad reply delivered")
	var tip := _shift.tips - tips
	_check(tip == floorf(Shift.WAIT_TIP * Shift.BAD_REPLY_TIP_SHARE), "a bad reply halves the tip (got €%.2f)" % tip)

	# Another bad reply, without a complaint this time.
	var h := _chatty_guest(0, 1)
	await _wait_until(func() -> bool: return _guests.talking_to == h, 30)
	_shift.rng.seed = _seed_where(func(roll: float) -> bool: return roll >= Shift.BAD_REPLY_COMPLAINT_CHANCE)
	stars = _shift.stars
	_guests.reply(Guest.Reply.BAD)
	_check(_shift.stars == stars and _shift.reply_complaints == 1, "a bad reply doesn't always get a complaint")
	_press_key(KEY_1)
	_check(h.reply == Guest.Reply.BAD, "number keys do nothing when nobody waits for a reply")
	await _ride_to(1)
	await _wait_until(_gone(h))


func _test_no_answer() -> void:
	var g := _chatty_guest(1, 2)
	await _wait_until(func() -> bool: return _guests.talking_to == g, 30)
	_check(await _wait_until(func() -> bool: return _guests.talking_to == null, GuestManager.REPLY_TIME + 1), "the guest stops waiting for a reply after %d s" % GuestManager.REPLY_TIME)
	_check(not _replies.visible, "the choices go away")
	_check(not g.answered and g.reply == Guest.Reply.NEUTRAL, "no answer counts as neutral")
	var tips := _shift.tips
	await _ride_to(2)
	_check(await _wait_until(_gone(g)), "unanswered guest delivered")
	_check(_shift.tips - tips == Shift.WAIT_TIP, "no answer leaves the tip alone (got €%.2f)" % (_shift.tips - tips))


func _test_one_at_a_time() -> void:
	# Two chatty guests board together on floor 2 and speak up at the same moment.
	var f := _chatty_guest(2, 0)
	var h := _chatty_guest(2, 1)
	_check(await _wait_until(func() -> bool: return f.state == Guest.State.RIDING and h.state == Guest.State.RIDING), "two chatty guests board")
	for g in [f, h]:
		g.chat_at = g.rode + 0.5
	await _wait_until(func() -> bool: return _guests.talking_to != null, 5)
	var first := _guests.talking_to
	var second := h if first == f else f
	_check(first in [f, h] and not second.chatted, "one chats, the other waits their turn")
	_press_key(KEY_1 + first.reply_order.find(Guest.Reply.NEUTRAL))
	_check(first.reply == Guest.Reply.NEUTRAL and first.answered, "the first gets their reply")
	_check(await _wait_until(func() -> bool: return _guests.talking_to == second, 2), "then the second one chats")
	_check(_all_text(_replies).contains(second.chat.line), "with their own line")

	# The cab gets to the second guest's floor before you answer.
	await _ride_to(second.destination)
	_check(await _wait_until(func() -> bool: return _guests.talking_to == null and not _replies.visible), "the choices go away when the guest gets out")
	_check(not second.answered, "their chat went unanswered")


## A guest who will chat early in the ride, and won't give up during the test.
func _chatty_guest(home: int, destination: int) -> Guest:
	_guests.chat_chance = 1.0
	var g := _guests.spawn_guest(home, destination)
	g.patience = 600
	g.ride_patience = 600
	return g


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
