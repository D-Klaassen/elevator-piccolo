extends "res://tests/scene_test.gd"
## Headless scripted test of the Asset room: the settings' Debug tab takes you
## there from a shift or from the staff room, and leaving takes you back where you came
## from. Every model under assets/ stands in it, and looking at an asset shows its asset
## name; a character goes through its animations, the sound buttons play their sounds
## and the music box's tracks while the sample cabs stay quiet, the cab's doors work and
## the Debug tab's Walk speed slider makes you walk faster.
##
## Run: tests/run.sh asset_room_test

var _room: AssetRoom


func _run() -> void:
	_shift.spawning = false
	await _enter_from_shift()
	await _test_every_model()
	await _test_code_built()
	await _test_character()
	await _test_sounds()
	await _test_cab()
	await _test_elevator_doors()
	await _test_walk_speed()
	await _leave_to_shift()
	await _enter_and_leave_from_staff_room()


func _enter_from_shift() -> void:
	await _escape()
	(_menu().find_child("Screens", true, false).find_child("Settings", true, false) as Button).pressed.emit()
	(_menu().find_child("SettingsMenu", true, false) as SettingsMenu).select_tab("debug")
	var asset_room := _menu().find_child("AssetRoom", true, false) as Button
	_check(asset_room.is_visible_in_tree(), "the settings' Debug tab in a shift has an Asset room button")
	_check(not (_menu().find_child("WalkSpeedRow", true, false) as Control).visible, "but no Walk speed slider")
	asset_room.pressed.emit()
	_room = await _wait_for_room()
	_check(_room != null and not paused, "the Asset room button opens the Asset room")


func _test_every_model() -> void:
	var models := _model_files("res://assets")
	var missing := 0
	for path in models:
		var asset_name := path.get_file().get_basename()
		var found := _room.asset(asset_name)
		var seen := ""
		if found:
			seen = await _look_at(found, asset_name)
		if seen != asset_name:
			missing += 1
			_check(false, "%s is in the Asset room, its name shown when you look at it (it shows \"%s\")" % [asset_name, seen])
	_check(not models.is_empty() and missing == 0, "all %d models under assets/ are in the Asset room, named" % models.size())


func _test_code_built() -> void:
	for asset_name in [
		"door panel", "side-opening elevator door", "centre-opening elevator door", "floor display", "call button", "floor button", "1.8 m",
		"Rustic cabin logs wall", "Rustic cabin planks floor", "Rustic cabin skirting",
		"Pension Bellevue wallpaper wall", "Pension Bellevue carpet floor",
		"Pension Bellevue panels wainscot", "Pension Bellevue chair rail",
		"Pension Bellevue door frame", "Pension Bellevue floor sign plate",
		"Rustic cabin door frame", "cab handrail", "cab open button", "cab panels wall",
	]:
		var found := _room.asset(asset_name)
		_check(found != null and await _look_at(found, asset_name) == asset_name, "%s is in the Asset room, named" % asset_name)

	var display := _room.asset("floor display")
	var shown: Array[String] = []
	for i in 3:
		await _press_looked_at(display)
		var screen := display.get_parent() as FloorDisplay
		shown.append("%s %d" % [screen.shown_floor(), screen.shown_direction()])
	_check(shown[0] != shown[1] and shown[1] != shown[2], "pressing the floor display changes what it shows (%s)" % ", ".join(shown))


func _test_character() -> void:
	var guest := _room.asset("character-male-c") as Guest
	var played: Array[String] = []
	for i in 3:
		await _press_looked_at(guest)
		await _wait_seconds(0.1)
		played.append(guest.animation)
	_check(played[0] != played[1] and played[1] != played[2], "pressing a character goes through its animations (%s)" % ", ".join(played))
	_check(guest.bubble_text() == played[2], "and its speech bubble names the one playing")


func _test_sounds() -> void:
	var sounds: Array[String] = ["ding", "chime going up", "chime going down"]
	for track in MusicBox.TRACKS:
		sounds.append("music: %s" % track.name)
	for sound in sounds:
		var button := _room.asset(sound)
		var before := _room.played.size()
		await _press_looked_at(button)
		_check(_room.played.size() == before + 1 and _room.played.back() == sound, "the %s button plays the %s" % [sound, sound])
	var boxes := _room.find_children("MusicBox", "", true, false)
	_check(not boxes.is_empty() and boxes.all(func(box: MusicBox) -> bool: return not box.is_playing()), "and the sample cabs' music boxes stay quiet")


func _test_cab() -> void:
	var elevator := _room.find_children("*", "Elevator", true, false)[0] as Elevator
	_check(elevator.is_open_at_rest(), "a sample corner's cab stands open")
	for child in elevator.get_cab().get_children():
		if child is ElevatorButton and child.action == "close":
			child.press()
	_check(await _wait_until(func() -> bool: return elevator.door_amount == 0.0), "and its close button shuts the doors")


## The elevator door models open when pressed, sliding in behind their wall, and close again.
func _test_elevator_doors() -> void:
	for asset_name in ["side-opening elevator door", "centre-opening elevator door"]:
		var tag := _room.asset(asset_name)
		var door := tag.get_parent().find_child("Doors", false, false) as ElevatorDoor
		await _press_looked_at(tag)
		_check(await _wait_until(func() -> bool: return door.amount == 1.0, 5.0), "pressing the %s opens it" % asset_name)
		_check(door.panels().all(func(p: Node3D) -> bool: return p.position.z + Elevator.PANEL_THICKNESS / 2 < -Elevator.WALL / 2), "its doors hang behind the wall")
		await _press_looked_at(tag)
		_check(await _wait_until(func() -> bool: return door.amount == 0.0, 5.0), "and pressing it again shuts it")


func _test_walk_speed() -> void:
	var player := _room.find_child("Player", true, false) as Player
	var normal := await _walk(player)
	await _escape()
	var slider := _room.find_child("WalkSpeed", true, false) as HSlider
	_check((_room.find_child("WalkSpeedRow", true, false) as Control).visible and slider.value == 1.0,
			"the Debug tab in the Asset room has a Walk speed slider, at ×1")
	slider.value = 3.0
	await _escape()
	var fast := await _walk(player)
	_check(is_equal_approx(fast, 3.0 * normal) and is_equal_approx(normal, Player.SPEED),
			"with it at ×3 you walk three times as fast (%.2f m/s, was %.2f)" % [fast, normal])
	slider.value = 1.0


## Walks forward down the aisle for a moment; returns how fast, in metres per second.
func _walk(player: Player) -> float:
	player.global_position = Vector3(2.0, 0.0, 0.0)
	player.rotation.y = -PI / 2
	await physics_frame
	await physics_frame
	Input.action_press("move_forward")
	await physics_frame
	await physics_frame
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	await physics_frame
	return speed


func _leave_to_shift() -> void:
	await _escape()
	var menu := _room.find_child("GameMenu", true, false) as GameMenu
	_check(menu.screen == "main" and _text(menu).contains("Asset room"), "Esc opens the menu in the Asset room")
	_check(not (menu.find_child("AssetRoom", true, false) as Control).visible, "its Debug tab has no button to the Asset room")
	(menu.find_child("LeaveAssetRoom", true, false) as Button).pressed.emit()
	_load_scene(await _wait_for_hotel())
	_check(not paused and _shift.minutes == Shift.START and not _shift.is_over, "leaving starts the shift afresh")


func _enter_and_leave_from_staff_room() -> void:
	_shift.spawning = false
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()
	(_scene.find_child("StaffRoom", true, false).find_child("Settings", true, false) as Button).pressed.emit()
	(_menu().find_child("AssetRoom", true, false) as Button).pressed.emit()
	_room = await _wait_for_room()
	_check(_room != null, "the staff room's settings open the Asset room too")
	await _escape()
	(_room.find_child("LeaveAssetRoom", true, false) as Button).pressed.emit()
	_load_scene(await _wait_for_hotel())
	var staff_room := _scene.find_child("StaffRoom", true, false) as Control
	_check(staff_room.visible and paused, "leaving takes you back to the staff room")
	(staff_room.find_child("Settings", true, false) as Button).pressed.emit()
	(_menu().find_child("Back", true, false) as Button).pressed.emit()
	_check(staff_room.visible, "where the settings' Back still leads back to the staff room")
	(staff_room.find_child("StartShift", true, false) as Button).pressed.emit()
	_load_scene(await _wait_for_hotel())
	_check(not paused and not _shift.is_over, "and Start the shift starts one")


## Every .glb under [param dir], at any depth.
func _model_files(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "glb":
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_model_files(dir.path_join(sub)))
	return found


## Stands the player 1 m from a point on [param target] and looks at it: its middle first,
## from the aisle side first, then the other sides and points further along it, until the
## HUD shows [param expected] (something else may stand in front of its middle). Returns
## what the HUD says the player is looking at.
func _look_at(target: CollisionObject3D, expected := "") -> String:
	var player := _room.find_child("Player", true, false) as Player
	var shape := target.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
	var points: Array[Vector3] = [shape.global_position]
	if shape.shape is BoxShape3D:
		var size := (shape.shape as BoxShape3D).size
		for along: Vector3 in [Vector3(0.35 * size.x, 0, 0), Vector3(0, 0, 0.35 * size.z)]:
			points.append(shape.global_transform * along)
			points.append(shape.global_transform * -along)
	var seen := ""
	for point in points:
		var toward_aisle := Vector3(0, 0, 1.0 if point.z < 0.0 else -1.0)
		for side: Vector3 in [toward_aisle, -toward_aisle, Vector3.RIGHT, Vector3.LEFT]:
			player.global_position = Vector3(point.x, 0.0, point.z) + side
			player.velocity = Vector3.ZERO
			await physics_frame
			await physics_frame # settled on the floor: aim from where the eye ends up
			var to := point - player._camera.global_position
			player.rotation.y = atan2(-to.x, -to.z)
			player._camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
			await physics_frame
			await physics_frame
			seen = (_room.find_child("LookingAt", true, false) as Label).text
			if expected.is_empty() or seen == expected:
				return seen
	return seen


func _press_looked_at(target: CollisionObject3D) -> void:
	await _look_at(target, Player.name_of(target))
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _wait_for_room() -> AssetRoom:
	await _wait_until(func() -> bool: return current_scene is AssetRoom and current_scene.is_node_ready())
	return current_scene as AssetRoom


## Waits for a fresh hotel scene (a new shift, or the staff room between shifts).
func _wait_for_hotel() -> Node3D:
	var old_id := _scene.get_instance_id() if is_instance_valid(_scene) else 0
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id \
			and current_scene.has_node("Shift") and current_scene.is_node_ready())
	return current_scene


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _menu() -> GameMenu:
	return _scene.find_child("GameMenu", true, false)


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
