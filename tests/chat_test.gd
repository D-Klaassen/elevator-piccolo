extends "res://tests/scene_test.gd"
## Headless scripted test of chats: now and then a guest you ask for their floor strikes up
## a chat first. While you talk, every guest's patience waits, you can't walk away and the
## view turns to them. You pick one of the replies on offer in time, or blurt one out, and
## how well it lands changes the tip (a bad one may cost a complaint). Then they name their
## floor. Spanish guests chat too, and how much you can say depends on your lessons.
##
## Run: tests/run.sh chat_test

const MAX_REPLY_LENGTH := 45 ## characters, so the replies read at a glance

var _replies: ReplyChoices
var _player: Player


func _run() -> void:
	_shift.spawning = false
	_replies = _scene.find_child("ReplyChoices", true, false)
	_player = _scene.find_child("Player", true, false)
	_test_content()
	_test_spanish_content()
	_test_shuffled()
	_test_blurt_odds()
	_test_speaking_ladder()
	await _test_quiet_guest()
	await _test_chat_when_asked()
	await _test_pick_with_highlight()
	await _test_no_answer()
	await _test_guest_leaves()
	await _test_spanish_chat()


func _test_content() -> void:
	_check(Guest.CHATS.all(func(c: Dictionary) -> bool: return c.replies.size() == Guest.Reply.size()), "every chat offers %d replies" % Guest.Reply.size())
	var longest_is_good := Guest.CHATS.filter(func(c: Dictionary) -> bool:
		var lengths: Array = c.replies.map(func(t: String) -> int: return t.length())
		return lengths.max() == lengths[Guest.Reply.GOOD])
	_check(longest_is_good.size() <= Guest.CHATS.size() / 2, "the good reply isn't always the longest (%d of %d)" % [longest_is_good.size(), Guest.CHATS.size()])
	_check_reply_lengths(Guest.CHATS)


func _test_spanish_content() -> void:
	_check(Spanish.CHATS.size() == 10, "there are 10 Spanish chats (%d)" % Spanish.CHATS.size())
	_check(Spanish.CHATS.all(func(c: Dictionary) -> bool: return c.line.size() == 2 and c.replies.size() == Guest.Reply.size()), "each has its line in Spanish and English, and %d replies" % Guest.Reply.size())
	_check_reply_lengths(Spanish.CHATS)
	_check(Spanish.REACTIONS.size() == Guest.Reply.size() and Spanish.REACTIONS.all(func(r: Array) -> bool: return r.all(func(l: Array) -> bool: return l.size() == 2)), "Spanish guests react in Spanish, with the English, for every kind of reply")
	var spoken: Array = Spanish.CHATS.map(func(c: Dictionary) -> String: return c.line[0])
	for kind: Array in Spanish.REACTIONS:
		spoken.append_array(kind.map(func(l: Array) -> String: return l[0]))
	var unknown := []
	for text: String in spoken:
		for word in text.split(" "):
			if Spanish.known_meaning(word, Spanish.LESSONS.size() - 1) == "":
				unknown.append(Spanish.normalize(word))
	_check(unknown.is_empty(), "the lessons teach every word of the chats and reactions (missing: %s)" % [unknown])


func _check_reply_lengths(chats: Array[Dictionary]) -> void:
	var long := []
	for c in chats:
		long.append_array(c.replies.filter(func(t: String) -> bool: return t.length() > MAX_REPLY_LENGTH))
	_check(long.is_empty(), "every reply fits in %d characters (too long: %s)" % [MAX_REPLY_LENGTH, long])


func _test_shuffled() -> void:
	_guests.chat_chance = 1.0
	var orders := {}
	for i in 30:
		var g := _guests.spawn_guest(2, 0)
		orders[g.reply_order] = true
		_guests._remove(g)
	_check(orders.size() > 1, "the replies come in a different order from guest to guest (%d orders)" % orders.size())


func _test_blurt_odds() -> void:
	var offers: Array[Dictionary] = []
	for r in [Guest.Reply.BAD, Guest.Reply.GOOD, Guest.Reply.NEUTRAL]:
		offers.append({"reply": r, "text": str(r)})
	var counts := [0, 0, 0]
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 3000:
		counts[offers[GuestManager.blurt(offers, r)].reply] += 1
	var share := func(reply: Guest.Reply) -> float: return counts[reply] / 3000.0
	_check(absf(share.call(Guest.Reply.GOOD) - 0.3) < 0.03 and absf(share.call(Guest.Reply.NEUTRAL) - 0.3) < 0.03 and absf(share.call(Guest.Reply.BAD) - 0.4) < 0.03,
		"a blurted reply is good 30%%, neutral 30%%, bad 40%% of the time (%s)" % [counts])


func _test_speaking_ladder() -> void:
	var said: Array = range(Spanish.LESSONS.size() + 1).map(func(l: int) -> int: return Spanish.replies_you_can_say(l))
	_check(said == [1, 1, 2, 2, 3, 3], "with 0-1 lessons you can say 1 real reply, with 2-3 two, with 4-5 all three (%s)" % [said])


func _test_quiet_guest() -> void:
	_guests.chat_chance = 0.0
	var g := _guests.spawn_guest(0, 1)
	g.patience = 600
	g.ride_patience = 600
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "a quiet guest boards")
	g.press()
	_check(g.bubble_text().to_lower().contains("floor 1"), "clicking a quiet guest names their floor straight away, in a bubble (%s)" % g.bubble_text())
	_check(_guests.talking_to == null and not _replies.visible, "without a chat")
	await _ride_to(1)
	_check(await _wait_until(_gone(g)), "quiet guest delivered")
	_check(_shift.tips == Shift.WAIT_TIP, "a quiet guest tips for the wait alone (got €%.2f)" % _shift.tips)


func _test_chat_when_asked() -> void:
	var g := _chatty_guest(1, 2)
	g.reply_order = [Guest.Reply.NEUTRAL, Guest.Reply.BAD, Guest.Reply.GOOD] as Array[Guest.Reply]
	var waiting := _guests.spawn_guest(0, 2) # someone calling on another floor
	waiting.patience = 600
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "a chatty guest boards")
	await _wait_seconds(3)
	_check(_guests.talking_to == null and not _replies.visible, "they don't start a chat on their own")

	g.press()
	_check(_guests.talking_to == g and _replies.visible, "asked for their floor, they strike up a chat instead")
	_check(g.bubble_text() == g.chat.line and not g.bubble_text().to_lower().contains("floor 2"), "what they say shows in their bubble, not their floor yet (%s)" % g.bubble_text())
	var text := _all_text(_replies)
	for i in g.offers.size():
		_check(text.contains('%d   "%s"' % [i + 1, g.offers[i].text]), "reply %d is on offer: %s" % [i + 1, g.offers[i].text])
	_check(g.offers.map(func(o: Dictionary) -> Guest.Reply: return o.reply) == [Guest.Reply.NEUTRAL, Guest.Reply.BAD, Guest.Reply.GOOD], "in the guest's order")

	# Their patience, and everyone else's, waits while you talk; the clock doesn't.
	var rode := g.rode
	var waited := waiting.waited
	var minutes := _shift.minutes
	var start := _player.global_position
	Input.action_press("move_forward")
	await _wait_seconds(1.0)
	Input.action_release("move_forward")
	_check(g.rode == rode and waiting.waited == waited, "every guest's patience waits during the chat (%.2f, %.2f)" % [g.rode - rode, waiting.waited - waited])
	_check(_shift.minutes > minutes, "the shift clock keeps running")
	_check(_player.global_position.distance_to(start) < 0.01, "you can't walk away")
	_check(_looking_at(g) < 0.15, "the view turns to the guest (%.2f rad off)" % _looking_at(g))

	_press_key(KEY_1 + g.offers.map(func(o: Dictionary) -> Guest.Reply: return o.reply).find(Guest.Reply.GOOD))
	_check(g.answered and g.reply == Guest.Reply.GOOD, "the number key of the good reply picks it")
	_check(not _replies.visible and _guests.talking_to == null, "the choices go away after replying")
	var reacted := Guest.REACTIONS[Guest.Reply.GOOD].any(func(r: String) -> bool: return g.bubble_text().begins_with(r))
	_check(reacted and g.bubble_text().to_lower().contains("floor 2"), "the guest reacts, then names their floor (%s)" % g.bubble_text())
	await _wait_seconds(0.5)
	_check(g.rode > rode, "their patience runs again")
	Input.action_press("move_forward")
	await _wait_seconds(0.3)
	Input.action_release("move_forward")
	_check(_player.global_position.distance_to(start) > 0.05, "and you can walk again")
	_player.global_position = start

	g.press()
	_check(_guests.talking_to == null and g.bubble_text().to_lower().contains("floor 2"), "asked again, they just repeat their floor")

	var tips := _shift.tips
	await _ride_to(2)
	_check(await _wait_until(_gone(g)), "chatty guest delivered")
	_check(_shift.tips - tips == Shift.MAX_TIP, "quick, with a good reply, earns the full €6 tip (got €%.2f)" % (_shift.tips - tips))
	_check(_last_said.contains("+€2 fare, +€6 tip"), "the pay shows in the HUD (%s)" % _last_said)
	_guests._remove(waiting)


func _test_pick_with_highlight() -> void:
	var g := _chatty_guest(0, 1)
	g.reply_order = [Guest.Reply.GOOD, Guest.Reply.NEUTRAL, Guest.Reply.BAD] as Array[Guest.Reply]
	await _wait_until(func() -> bool: return g.state == Guest.State.WAITING)
	g.press()
	_check(_replies.highlighted == 0, "the top reply is highlighted first")
	_press_key(KEY_S)
	_check(_replies.highlighted == 1, "S moves the highlight down")
	_scroll(MOUSE_BUTTON_WHEEL_DOWN)
	_check(_replies.highlighted == 2, "so does the mouse wheel")
	_scroll(MOUSE_BUTTON_WHEEL_DOWN)
	_check(_replies.highlighted == 2, "not past the bottom")
	_press_key(KEY_W)
	_scroll(MOUSE_BUTTON_WHEEL_UP)
	_scroll(MOUSE_BUTTON_WHEEL_DOWN)
	_check(_replies.highlighted == 1, "W and the wheel move it up again")
	_press_key(KEY_S)
	_check(_all_text(_replies).contains(ReplyChoices.MARK + ' 3   "%s"' % g.offers[2].text), "the highlighted reply is marked")

	_shift.rng.seed = _seed_where(func(roll: float) -> bool: return roll < Shift.BAD_REPLY_COMPLAINT_CHANCE)
	var stars := _shift.stars
	_click()
	_check(g.answered and g.reply == Guest.Reply.BAD, "a click says the highlighted reply")
	_check(_shift.reply_complaints == 1 and _shift.stars == stars - Shift.COMPLAINT, "the bad reply gets a complaint: -½ star")
	var reacted := Guest.REACTIONS[Guest.Reply.BAD].any(func(r: String) -> bool: return g.bubble_text().begins_with(r))
	_check(reacted and g.bubble_text().to_lower().contains("floor 1") and _last_said.contains("Complaint"), "the guest takes it badly but names their floor, and the HUD shows the complaint (%s)" % g.bubble_text())

	var tips := _shift.tips
	await _ride_to(0)
	await _ride_to(1)
	_check(await _wait_until(_gone(g)), "guest with a bad reply delivered")
	var tip := _shift.tips - tips
	_check(tip == floorf(Shift.WAIT_TIP * Shift.BAD_REPLY_TIP_SHARE), "a bad reply halves the tip (got €%.2f)" % tip)

	_press_key(KEY_1)
	_click()
	_check(_shift.reply_complaints == 1 and not _replies.visible, "keys and clicks say nothing when nobody is chatting")


func _test_no_answer() -> void:
	var g := _chatty_guest(1, 2)
	var said: Array[String] = []
	_guests.said.connect(func(text: String) -> void: said.append(text))
	await _wait_until(func() -> bool: return g.state == Guest.State.RIDING)
	g.press()
	_check(_replies.time_left() > GuestManager.REPLY_TIME - 0.1, "a bar shows the %d s you have to answer" % GuestManager.REPLY_TIME)
	await _wait_seconds(GuestManager.REPLY_TIME / 2)
	_check(_replies.visible and _replies.time_left() < GuestManager.REPLY_TIME / 2 + 0.1, "and runs down (%.1f s left)" % _replies.time_left())
	_check(await _wait_until(func() -> bool: return _guests.talking_to == null, GuestManager.REPLY_TIME), "after %d s the chat is cut off" % GuestManager.REPLY_TIME)
	_check(not _replies.visible, "the choices go away")
	_check(g.answered, "you blurt out one of the replies")
	var blurted: Array = g.offers.filter(func(o: Dictionary) -> bool: return o.reply == g.reply)
	_check(said.has('You: "%s"' % blurted[0].text), "the HUD shows what you blurted (%s)" % [said])
	_check(g.bubble_text().to_lower().contains("floor 2"), "and the guest names their floor (%s)" % g.bubble_text())
	await _ride_to(2)
	_check(await _wait_until(_gone(g)), "guest delivered")


func _test_guest_leaves() -> void:
	var g := _chatty_guest(1, 0)
	await _wait_until(func() -> bool: return g.state == Guest.State.WAITING)
	g.press()
	_check(_guests.talking_to == g, "a waiting guest in the hallway chats too")
	_guests.clear() # as End shift now does
	_check(_guests.talking_to == null and not _replies.visible, "the chat ends when the guest is gone")
	var start := _player.global_position
	Input.action_press("move_forward")
	await _wait_seconds(0.3)
	Input.action_release("move_forward")
	_check(_player.global_position.distance_to(start) > 0.05, "and you can walk again")
	_player.global_position = start


func _test_spanish_chat() -> void:
	_guests.spanish_share = 1.0
	var g := _chatty_guest(2, 1)
	_check(g.language == "es" and Spanish.CHATS.has(g.chat), "a Spanish guest can be chatty too")
	_check(g.spanish_line.size() == 2, "and still has a line about their floor")
	await _wait_until(func() -> bool: return g.state == Guest.State.RIDING)

	_guests.spanish_lessons = 0
	g.press()
	_check(_guests.talking_to == g and g.bubble_text() != "" and g.under_text() == "", "without lessons you only half-hear what they say (%s)" % g.bubble_text())
	_check(g.offers.size() == 2 and g.offers.any(func(o: Dictionary) -> bool: return o.text == Spanish.SI_SI), "and can only say \"%s\" or one real reply" % Spanish.SI_SI)
	var si := g.offers.map(func(o: Dictionary) -> String: return o.text).find(Spanish.SI_SI)
	_check(g.offers[si].reply == Guest.Reply.NEUTRAL, "nodding along counts as neutral")
	_guests.spanish_lessons = 5
	_guests.reply(si)
	_check(g.answered and g.reply == Guest.Reply.NEUTRAL, "you nod along")
	var reacted := Spanish.REACTIONS[Guest.Reply.NEUTRAL].any(func(l: Array) -> bool: return g.bubble_text().begins_with(l[0]))
	_check(reacted and g.bubble_text().contains(g.spanish_line[0]), "they react in Spanish, then give their floor line (%s)" % g.bubble_text())
	_remove(g)

	for lessons in [2, 4]:
		var h := _chatty_guest(2, 1)
		await _wait_until(func() -> bool: return h.state == Guest.State.RIDING)
		_guests.spanish_lessons = lessons
		h.press()
		var real := h.offers.filter(func(o: Dictionary) -> bool: return o.text != Spanish.SI_SI)
		_check(real.size() == Spanish.replies_you_can_say(lessons) and h.offers.size() == 3, "with %d lessons you can say %d real replies (%s)" % [lessons, real.size(), h.offers])
		_check(real.all(func(o: Dictionary) -> bool: return h.chat.replies[o.reply] == o.text), "each one of the chat's own")
		_guests.reply(0)
		_remove(h)
	_guests.spanish_share = 0.0
	_guests.spanish_lessons = 0


## A guest who will chat when asked, and won't give up during the test.
func _chatty_guest(home: int, destination: int) -> Guest:
	_guests.chat_chance = 1.0
	var g := _guests.spawn_guest(home, destination)
	g.patience = 600
	g.ride_patience = 600
	return g


func _remove(g: Guest) -> void:
	_guests._remove(g)


## Radians between where the camera looks and the guest's mouth.
func _looking_at(g: Guest) -> float:
	var camera := _player.get_viewport().get_camera_3d()
	var to := g.mouth() - camera.global_position
	return (-camera.global_basis.z).angle_to(to)


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate()
	release.pressed = false
	root.push_input(release)


func _scroll(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)


func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
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
