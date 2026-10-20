extends "res://tests/scene_test.gd"
## Headless scripted test of Spanish guests at Pension Bellevue: how much of their Spanish
## you catch per lesson, the speech bubble with what you understood underneath, the hints,
## asking "Sorry, again?" and the lessons in the staff room.
##
## Run: tests/run.sh spanish_test


func _run() -> void:
	_test_hearing()
	_test_lines()
	await _test_cabin()
	await _test_bellevue()


func _test_hearing() -> void:
	var r := RandomNumberGenerator.new()
	var line: Array = Spanish.LINES[4][0] # ¿Dónde está la piscina? Quiero nadar.
	_check(Spanish.normalize("¿Dónde") == "donde" and Spanish.normalize("niños.") == "ninos", "words are looked up without accents or punctuation")
	_check(Spanish.sound_out("habitación") == "abitasion" and Spanish.sound_out("quiero") == "kiero", "unknown words come out spelled by ear")

	var missed := 0
	var phonetic := 0
	for i in 200:
		r.seed = i
		var h := Spanish.hear(line, 0, r)
		missed += 1 if h.heard.contains(Spanish.MISS) else 0
		phonetic += 1 if h.heard.contains("kiero") else 0
		if h.understood != "":
			_check(false, "without lessons you understand nothing (%s)" % h.understood)
			break
		if h.heard.contains("piscina") and h.heard.contains("Dónde"):
			_check(false, "without lessons nothing is spelled correctly (%s)" % h.heard)
			break
	_check(missed > 50 and missed < 200, "without lessons some words get lost (%d of 200 lines)" % missed)
	_check(phonetic > 0, "and some come out spelled by ear")

	var places_known := 0
	for i in 200:
		r.seed = i
		var h := Spanish.hear(line, 4, r)
		if h.heard.contains("piscina"):
			places_known += 1
			if not h.understood.contains("pool"):
				_check(false, "a known word shows its English underneath (%s / %s)" % [h.heard, h.understood])
				break
	_check(places_known > 100, "after 4 lessons \"piscina\" is mostly caught and understood (%d of 200)" % places_known)
	r.seed = 1
	var fluent := Spanish.hear(line, 5, r)
	_check(fluent.heard == line[0] and fluent.understood == line[1], "lesson 5 gives the full line and its subtitle")
	r.seed = 1
	_check(Spanish.hear(line, 1, r).understood.find("%s %s" % [Spanish.MISS, Spanish.MISS]) < 0, "runs of unknown words show as a single \"…\"")


func _test_lines() -> void:
	var places: Array = Hotels.at(1).places
	_check(Spanish.LINES.size() == places.size() and Spanish.CLUES.size() == places.size() and Spanish.FINGERS.size() == places.size(), "every Bellevue floor has lines, clues and fingers")
	for f in places.size():
		for clue: String in Spanish.CLUES[f]:
			if places[f].to_lower().contains(clue.to_lower()):
				_check(false, "a clue never names the floor (%s on %s)" % [clue, places[f]])


func _test_cabin() -> void:
	_shift.spawning = false
	_check(_guests.spanish_share == 0.0, "the cabin has no Spanish guests")
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()
	var room: StaffRoom = _scene.find_child("StaffRoom", true, false)
	_check(not (room.find_child("Buy_spanish", true, false) as Control).is_visible_in_tree(), "the cabin's staff room sells no Spanish lessons")
	var c := Career.new()
	c.balance = 1000.0
	_check(not c.buy(Upgrades.SPANISH), "and they can't be bought there")


func _test_bellevue() -> void:
	var c := Career.new()
	c.hotel = 1
	c.balance = 1000.0
	c.save()
	var old_id := _scene.get_instance_id()
	(_scene.find_child("StaffRoom", true, false).find_child("StartShift", true, false) as Button).pressed.emit()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	_load_scene(current_scene)
	_shift.spawning = false
	_check(_guests.spanish_share == Hotels.at(1).spanish and _guests.spanish_lessons == 0, "at Pension Bellevue guests speak Spanish, and you have no lessons yet")
	_check(_all_text(_scene).contains("Floor 4 · Pool"), "the hallway signs say what's on each floor")

	_guests.spanish_share = 1.0
	var g := _guests.spawn_guest(1, 4)
	_check(g.language == "es" and g.display_name.begins_with("Spanish guest"), "a Spanish guest calls")
	_check(Spanish.LINES[4].has(g.spanish_line), "with a line about floor 4")
	g.helpfulness = "helpful"
	_guests.rng.seed = _seed_where(func(r: RandomNumberGenerator) -> bool:
		Spanish.hear(g.spanish_line, 0, r)
		return r.randf() >= 0.35 and r.randf() >= 0.4) # no clue word and no gesture the first time
	_last_said = ""
	g.press()
	_check(g.bubble_text() != "" and _last_said == "", "they answer in a speech bubble (%s)" % g.bubble_text())
	_check(not g.bubble_text().contains("4") and not g.bubble_text().to_lower().contains("pool"), "and it doesn't give the floor away")
	_check(g.under_text() == "", "without lessons there's nothing underneath")

	var waited := g.waited
	g.press()
	_check(_last_said.contains("Sorry, again?"), "clicking again asks them to say it again")
	_check(g.waited >= waited + GuestManager.AGAIN_COST, "which costs them %d s of patience" % GuestManager.AGAIN_COST)
	_check(g.under_text().contains("finger"), "a helpful guest then shows it on their fingers (%s)" % g.under_text())

	_guests.spanish_lessons = 5
	g.press()
	_check(g.bubble_text().begins_with(g.spanish_line[0]) and g.under_text().begins_with(g.spanish_line[1]), "after 5 lessons you get the full line with its subtitle")

	var english := _guests.spawn_guest(2, 6)
	english.language = "en"
	english.press()
	_check(english.bubble_text().to_lower().contains("floor 6") and english.under_text() == "", "English guests name their floor in a bubble too, with nothing underneath")

	# The staff room at Bellevue sells the lessons.
	_shift.minutes = Shift.END - 0.1
	_guests.spanish_share = 0.0
	for guest in _guests.guests():
		guest.queue_free()
	_guests._guests.clear()
	await _wait_until(func() -> bool: return _shift.is_over)
	(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()
	var room: StaffRoom = _scene.find_child("StaffRoom", true, false)
	var buy := room.find_child("Buy_spanish", true, false) as Button
	_check(buy.is_visible_in_tree() and buy.text == "Buy €60", "the staff room sells the first lesson for €60")
	buy.pressed.emit()
	_check(Career.load_saved().level(Upgrades.SPANISH) == 1, "and buying it is saved")
	var row_text := ""
	for label in room.find_children("*", "Label", true, false):
		row_text += (label as Label).text + "\n"
	_check(row_text.contains("Spanish lessons   level 1 of 5") and row_text.contains("Next: Lesson 2: common verbs"), "the next lesson is common verbs")


## A seed for which [param condition] holds on a fresh generator.
func _seed_where(condition: Callable) -> int:
	var r := RandomNumberGenerator.new()
	for s in 1000:
		r.seed = s
		if condition.call(r):
			return s
	_check(false, "found a seed")
	return 0


func _all_text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label3D", true, false):
		text += (child as Label3D).text + "\n"
	return text
