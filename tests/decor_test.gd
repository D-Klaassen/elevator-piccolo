extends "res://tests/scene_test.gd"
## Headless scripted test of the furniture: every hallway in every hotel is furnished for
## what's on its floor, nothing stands in the way of the guests' walks, and the music box
## grows from a radio to a radio with speakers.
##
## Run: tests/run.sh decor_test

## The ends of every walk a guest makes in a hallway, in hallway coordinates: from either
## back corner to each spot by the elevator and to the landing, and from each spot to the
## landing.
var _walks: Array[Array] = []


func _ready_walks() -> void:
	var landing := Vector2(0, GuestManager.LANDING_Z)
	for side in [-2.3, 2.3]:
		var corner := Vector2(side, GuestManager.HALL_END_Z)
		_walks.append([corner, landing])
		for spot in GuestManager.WAIT_SPOTS:
			_walks.append([corner, Vector2(spot.x, spot.z)])
	for spot in GuestManager.WAIT_SPOTS:
		_walks.append([Vector2(spot.x, spot.z), landing])


func _run() -> void:
	_shift.spawning = false
	_ready_walks()
	for place in Decor.PLACES:
		_check(Hotels.LADDER.any(func(h: Dictionary) -> bool: return h.places.has(place)), "%s is a place in a hotel" % place)
	for hotel in Hotels.LADDER.size():
		await _test_hotel(hotel)
	await _test_music_box()


func _test_hotel(index: int) -> void:
	var c := Career.new()
	c.hotel = index
	c.save()
	_load_scene(await _reload())
	_shift.spawning = false
	var hotel := Hotels.at(index)
	for f in hotel.floors:
		var place: String = hotel.places[f] if not hotel.places.is_empty() else ""
		var furniture := _scene.find_child("Furniture%d" % f, false, false) as Node3D
		var pieces := furniture.get_children() if furniture else []
		_check(pieces.size() == Decor.for_place(place).size() and pieces.size() >= 4, "%s floor %d (%s) is furnished: %d pieces" % [hotel.name, f, place if place else "hallway", pieces.size()])
		for piece: Node3D in pieces:
			var box: AABB = piece.transform * Decor.bounds(piece.get_child(0))
			var y: float = f * Elevator.FLOOR_HEIGHT
			_check(is_equal_approx(box.position.y, y), "%s on floor %d stands on the floor" % [piece.name, f])
			if box.size.y < 0.05:
				continue # a rug: guests walk over it
			_check(_clear_of_walks(box), "%s on floor %d is out of the guests' way" % [piece.name, f])
			_check(absf(box.position.x) <= 3.0 and absf(box.end.x) <= 3.0 and box.position.z >= 1.1 and box.end.z <= 5.05, "%s on floor %d is inside the hallway" % [piece.name, f])


## True if no guest's walk passes within a guest's radius of [param box] (seen from above).
func _clear_of_walks(box: AABB) -> bool:
	var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(Guest.RADIUS)
	for walk in _walks:
		for i in 41:
			var p: Vector2 = (walk[0] as Vector2).lerp(walk[1], i / 40.0)
			if rect.has_point(p):
				return false
	return true


func _test_music_box() -> void:
	for level in [1, 2, 3]:
		var c := Career.new()
		c.upgrades = {Upgrades.MUSIC: level}
		c.save()
		_load_scene(await _reload())
		_shift.spawning = false
		var box := _scene.find_child("MusicBox", true, false)
		var radios := box.find_children("Radio", "", true, false).size() if box else 0
		var speakers := box.find_children("SpeakerSmall*", "", true, false).size() if box else 0
		_check(radios == 1 and speakers == [0, 2, 4][level - 1], "music level %d: a radio and %d speakers in the cab" % [level, speakers])


func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene
