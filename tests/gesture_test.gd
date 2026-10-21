extends "res://tests/scene_test.gd"
## Headless scripted test of the guests' gestures: every character can wave, point down,
## hold up fingers and mime each place; the poses do what they say (a raised hand is up,
## a bite reaches the mouth); the fingers, suitcase and glass show only while they're
## used; a Spanish guest acts out the hint you read under their bubble; and walking stops
## a gesture.
##
## Run: tests/run.sh gesture_test

const MIMES: Array[String] = [Gestures.SUITCASE, Gestures.EATING, Gestures.SWIMMING, Gestures.SHOULDER, Gestures.DRINKING]


func _run() -> void:
	_shift.spawning = false
	_guests.chat_chance = 0.0 # chats have their own test
	_guests.patience_scale = 10.0
	_test_every_model()
	_test_poses()
	await _test_props()
	await _test_spanish_hints()
	await _test_walking()


func _test_every_model() -> void:
	var all: Array[String] = [Gestures.WAVE, Gestures.POINT_DOWN]
	all.append_array(MIMES)
	for n in range(1, Gestures.MAX_FINGERS + 1):
		all.append(Gestures.fingers(n))
	var colours := {}
	for model in Guest.MODELS:
		var body := _character(model)
		var player := _player(body)
		var missing := all.filter(func(a: String) -> bool: return not player.has_animation(a))
		_check(missing.is_empty(), "%s has every gesture (missing: %s)" % [model.get_file(), missing])
		var idle_right := _first_key(player.get_animation(Guest.IDLE), Gestures.ARM_RIGHT)
		var unsettled := all.filter(func(a: String) -> bool: return not _starts_and_ends_idle(player.get_animation(a), idle_right))
		_check(unsettled.is_empty(), "%s starts and ends every gesture standing idle (not: %s)" % [model.get_file(), unsettled])
		var finger := _skeleton(body).get_node("HandRight/Fingers/Finger1") as MeshInstance3D
		colours[((finger.mesh as BoxMesh).material as StandardMaterial3D).albedo_color.to_html(false)] = true
		body.free()
	_check(colours.size() >= 3, "fingers take the colour of each character's hand (%d colours)" % colours.size())


func _test_poses() -> void:
	var body := _character(Guest.MODELS[6])
	var player := _player(body)
	var sk := _skeleton(body)
	var head := _bone(sk, Gestures.HEAD)
	var shoulder := _bone(sk, Gestures.ARM_RIGHT)

	_pose(player, Gestures.WAVE, 0.25)
	_check(_fist(sk, true).y > head.y, "waving: the hand is up above the shoulders")
	_pose(player, Gestures.fingers(3), 0.75)
	_check(_fist(sk, true).y > head.y, "three fingers: one hand held up")
	_check(_fist(sk, false).y < shoulder.y, "and the other one down")
	_pose(player, Gestures.fingers(6), 0.75)
	_check(_fist(sk, true).y > head.y and _fist(sk, false).y > head.y, "six fingers: both hands held up")
	_pose(player, Gestures.POINT_DOWN, 0.3)
	_check(_fist(sk, true).y < shoulder.y and _fist(sk, true).z > shoulder.z + 0.1, "pointing down: the hand is low, out in front")
	_pose(player, Gestures.SUITCASE, 0.7)
	_check(_fist(sk, true).z > shoulder.z + 0.15, "showing a suitcase: holding it out in front")
	_pose(player, Gestures.EATING, 0.6)
	_check(_fist(sk, true).distance_to(head) < 0.22, "eating: a bite reaches the mouth")
	_pose(player, Gestures.EATING, 0.3)
	_check(_fist(sk, true).distance_to(head) > 0.25, "and goes back to the plate")
	_pose(player, Gestures.DRINKING, 1.0)
	_check(_fist(sk, true).distance_to(head) < 0.22, "drinking: the glass is at the mouth")
	_pose(player, Gestures.SWIMMING, 0.2)
	_check(_fist(sk, true).y > head.y and _fist(sk, false).y < shoulder.y, "swimming: one arm up as the other is down")
	_pose(player, Gestures.SWIMMING, 0.6)
	_check(_fist(sk, true).y < shoulder.y and _fist(sk, false).y > head.y, "and then the other way round")
	_pose(player, Gestures.SHOULDER, 0.35)
	_check(_fist(sk, true).distance_to(_bone(sk, Gestures.ARM_LEFT)) < 0.2, "a sore shoulder: the right hand on the left shoulder")
	body.free()


func _test_props() -> void:
	var g := _guests.spawn_guest(1, 0)
	await _wait_until(func() -> bool: return g.state == Guest.State.WAITING)
	var sk := g.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_check(Gestures.props_showing(sk).is_empty(), "a guest standing idle has nothing in their hands")
	for n in [1, 3, 5, 6]:
		g.act(Gestures.fingers(n))
		var showing := Gestures.props_showing(sk)
		_check(showing.count("Finger") == n and showing.size() == n, "holding up %d finger%s shows %d (%s)" % [n, "" if n == 1 else "s", n, showing])
	g.act(Gestures.POINT_DOWN)
	_check(Gestures.props_showing(sk) == ["Finger"], "pointing shows one finger")
	g.act(Gestures.SUITCASE)
	_check(Gestures.props_showing(sk) == ["Suitcase"], "showing a suitcase shows a suitcase")
	await _wait_seconds(0.7)
	var suitcase := sk.get_node("HandRight/Suitcase") as Node3D
	_check(suitcase.global_basis.y.normalized().dot(Vector3.UP) > 0.99, "which hangs straight down while the arm holds it out")
	_check(await _wait_until(func() -> bool: return g.animation == Guest.IDLE), "after the gesture they stand idle again")
	_check(Gestures.props_showing(sk).is_empty(), "with empty hands")
	g.act(Gestures.DRINKING)
	_check(Gestures.props_showing(sk) == ["Glass"], "drinking shows a glass")
	g.act(Guest.HEAD_SHAKE)
	_check(Gestures.props_showing(sk).is_empty(), "which goes when they do something else")
	_remove(g)


func _test_spanish_hints() -> void:
	_guests.spanish_share = 1.0
	var g := _guests.spawn_guest(1, 0)
	await _wait_until(func() -> bool: return g.state == Guest.State.WAITING)
	g.helpfulness = "helpful"
	g.spanish_line = Spanish.LINES[0][0]
	_guests.rng.seed = _seed_where(func(r: RandomNumberGenerator) -> bool:
		Spanish.hear(g.spanish_line, 0, r)
		r.randf()
		return r.randf() < Spanish.HELPFULNESS.helpful.gesture and r.randf() >= 0.3) # a mime
	g.press()
	_check(g.under_text().contains(Spanish.MIMES[0]) and g.animation == Spanish.MIME_GESTURES[0], "a guest who mimes acts it out: %s (%s)" % [g.under_text(), g.animation])
	g.press()
	_check(g.under_text().contains(Spanish.FINGERS[0]) and g.animation == Gestures.POINT_DOWN, "asked again, a helpful guest points down to the ground floor (%s)" % g.under_text())
	_guests.rng.seed = _seed_where(func(r: RandomNumberGenerator) -> bool:
		Spanish.hear(g.spanish_line, 0, r)
		r.randf()
		return r.randf() >= Spanish.HELPFULNESS.helpful.gesture) # no gesture
	g.asked = 0
	g.press()
	_check(g.animation == Guest.WAVE and not g.under_text().contains("("), "a guest who shows nothing just waves (%s)" % g.under_text())
	_remove(g)

	_guests.spanish_share = 0.0
	var english := _guests.spawn_guest(2, 1)
	await _wait_until(func() -> bool: return english.state == Guest.State.WAITING)
	english.press()
	_check(english.animation == Guest.WAVE, "an English guest waves as they tell you their floor")
	_remove(english)


func _test_walking() -> void:
	var g := _guests.spawn_guest(1, 0)
	await _wait_until(func() -> bool: return g.state == Guest.State.WAITING)
	var sk := g.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	g.act(Gestures.SWIMMING)
	g.walk([g.global_position + Vector3(0.5, 0, 0)])
	await _wait_until(func() -> bool: return g.animation != Gestures.SWIMMING, 0.5)
	_check(g.animation == Guest.WALK and Gestures.props_showing(sk).is_empty(), "a guest who starts walking stops their gesture")
	g.act(Gestures.fingers(2))
	_check(g.animation == Guest.WALK and Gestures.props_showing(sk).is_empty(), "and doesn't start one while walking")
	g.act(Guest.NOD)
	_check(g.animation == Guest.NOD, "though they still nod")
	_remove(g)


## A character on its own, with its gestures, standing at the origin.
func _character(model: String) -> Node3D:
	var body: Node3D = (load(model) as PackedScene).instantiate()
	root.add_child(body)
	Gestures.setup(_player(body))
	return body


func _player(body: Node3D) -> AnimationPlayer:
	return body.find_children("*", "AnimationPlayer", true, false)[0]


func _skeleton(body: Node3D) -> Skeleton3D:
	return body.find_children("*", "Skeleton3D", true, false)[0]


func _pose(player: AnimationPlayer, animation: String, at: float) -> void:
	player.play(animation)
	player.seek(at, true)


## Where [param bone]'s joint is, in the character's coordinates.
func _bone(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin


## Where the right (or left) fist is, in the character's coordinates.
func _fist(sk: Skeleton3D, right: bool) -> Vector3:
	var pose := sk.get_bone_global_pose(sk.find_bone(Gestures.ARM_RIGHT if right else Gestures.ARM_LEFT))
	return pose * Vector3((-1 if right else 1) * Gestures.FIST, 0, 0)


func _first_key(animation: Animation, bone: String) -> Quaternion:
	for t in animation.get_track_count():
		if str(animation.track_get_path(t)).ends_with(":" + bone) and animation.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			return animation.track_get_key_value(t, 0)
	return Quaternion()


func _starts_and_ends_idle(animation: Animation, idle_right: Quaternion) -> bool:
	for t in animation.get_track_count():
		var first: Quaternion = animation.track_get_key_value(t, 0)
		var last: Quaternion = animation.track_get_key_value(t, animation.track_get_key_count(t) - 1)
		if absf(first.dot(last)) < 0.9999 or not is_equal_approx(animation.track_get_key_time(t, animation.track_get_key_count(t) - 1), animation.length):
			return false
	return absf(_first_key(animation, Gestures.ARM_RIGHT).dot(idle_right)) > 0.9999


## A seed for which [param condition] holds on a fresh generator.
func _seed_where(condition: Callable) -> int:
	var r := RandomNumberGenerator.new()
	for s in 1000:
		r.seed = s
		if condition.call(r):
			return s
	_check(false, "found a seed")
	return 0


func _remove(g: Guest) -> void:
	_guests._guests.erase(g)
	g.queue_free()
