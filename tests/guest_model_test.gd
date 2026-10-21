extends "res://tests/scene_test.gd"
## Headless scripted test of how guests look and move: a Kenney character each, walking to
## the cab, standing idle while they wait, waving when they tell you their floor, nodding
## when they thank you and shaking their head when they give up.
##
## Run: tests/run.sh guest_model_test


func _run() -> void:
	_shift.spawning = false
	_guests.chat_chance = 0.0 # chats have their own test
	_guests.patience_scale = 10.0
	_test_variety()
	await _test_animations()
	await _test_giving_up()
	await _test_nearest_bubble_on_top()


func _test_variety() -> void:
	var present: Array[Guest] = []
	for f in 3:
		for i in 3:
			var g := _guests.spawn_guest(f, (f + 1) % 3)
			if g:
				present.append(g)
	var looks := present.map(func(g: Guest) -> String: return g.model)
	_check(present.size() >= 6 and looks.all(func(m: String) -> bool: return looks.count(m) == 1), "no two guests in the hotel look the same (%d guests)" % present.size())
	for g in present:
		_remove(g)

	var models := {}
	for i in 24:
		var g := _guests.spawn_guest(2, 1)
		if g == null:
			break
		models[g.model] = true
		_check(Guest.MODELS.has(g.model) and g.find_child("Body", false, false) != null, "guest %d is one of the Kenney characters (%s)" % [i, g.model.get_file()])
		_remove(g)
	_check(models.size() >= 4, "guests come in different looks (%d of %d models)" % [models.size(), Guest.MODELS.size()])


func _test_animations() -> void:
	# On floor 1, so the walk to the cab's floor-0 doors doesn't start straight away.
	var g := _guests.spawn_guest(1, 0)
	await physics_frame
	_check(g.animation == Guest.WALK, "a guest walks to the elevator")
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.WAITING), "and waits there")
	_check(g.animation == Guest.IDLE, "standing idle")
	g.press()
	_check(g.animation == Guest.WAVE, "clicking them makes them wave as they say their floor")
	_check(await _wait_until(func() -> bool: return g.animation == Guest.IDLE), "and then they stand idle again")

	await _ride_to(1)
	_check(await _wait_until(func() -> bool: return g.state == Guest.State.RIDING), "they board")
	await _ride_to(0)
	_check(await _wait_until(func() -> bool: return g.animation == Guest.NOD), "they nod when they thank you")
	_check(await _wait_until(func() -> bool: return g.animation == Guest.WALK), "and walk out after")
	await _wait_until(_gone(g))


func _test_giving_up() -> void:
	var g := _guests.spawn_guest(2, 1)
	await _wait_until(func() -> bool: return g.state == Guest.State.WAITING)
	g.waited = g.patience
	_check(await _wait_until(func() -> bool: return g.animation == Guest.HEAD_SHAKE), "a guest who gives up shakes their head")
	_check(await _wait_until(func() -> bool: return g.animation == Guest.WALK), "and then walks off")


func _test_nearest_bubble_on_top() -> void:
	# Two guests talk at once in the open cab; the nearer one's bubble covers the other's.
	var near := _guests.spawn_guest(0, 1)
	var far := _guests.spawn_guest(0, 2)
	far.say("Floor 2, please.")
	near.say("Floor 1, please.")
	for i in 3:
		near.global_position = Vector3(0.3, 0, 1.0)
		far.global_position = Vector3(-0.5, 0, 3.0)
		await process_frame
	_check(near._bubble.visible and far._bubble.visible, "both bubbles show")
	_check(near._bubble.render_priority > far._bubble.render_priority,
			"the nearer guest's bubble draws on top (%d over %d)" % [near._bubble.render_priority, far._bubble.render_priority])
	_remove(near)
	_remove(far)


func _remove(g: Guest) -> void:
	_guests._guests.erase(g)
	g.queue_free()
