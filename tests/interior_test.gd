extends "res://tests/scene_test.gd"
## Headless scripted test of the hotels' and the cab's looks: every hotel's hallways have
## patterned walls and floors in its own style, with skirting, a frame round the elevator,
## a ceiling and a lamp; none of it has collision or stands where you or the guests walk;
## the floor signs are readable on their plates; and the cab has panelled walls, a
## chequered floor, a ceiling light and a handrail, clear of the doors.
##
## Run: tests/run.sh interior_test

## How far trim may stick out from a wall into the room, and how high something must hang
## to be over everyone's head.
const FLUSH := 0.12
const HEADROOM := 2.3


func _run() -> void:
	_shift.spawning = false
	_test_textures()
	for hotel in Hotels.LADDER.size():
		await _test_hotel(hotel)
	_test_cab()


func _test_textures() -> void:
	for id in Interior.STYLES:
		var s: Dictionary = Interior.STYLES[id]
		for part in ["floor", "wall", "wainscot"]:
			if (s[part] as Array).is_empty():
				continue
			var image := Interior.texture(s[part]).get_image()
			var colours := {}
			for y in range(0, image.get_height(), 3):
				for x in range(0, image.get_width(), 3):
					colours[image.get_pixel(x, y).to_html(false)] = true
			_check(colours.size() >= 3, "%s's %s has a pattern (%d colours)" % [id, part, colours.size()])
		_check(absf(_luminance(s.sign) - _luminance(s.sign_text)) > 0.4, "%s's floor signs stand out from their plates" % id)
	_check(Interior.material(Interior.STYLES.cabin.wall) == Interior.material(Interior.STYLES.cabin.wall), "a material is made once and shared")


func _test_hotel(index: int) -> void:
	var c := Career.new()
	c.hotel = index
	c.save()
	_load_scene(await _reload())
	_shift.spawning = false
	var hotel := Hotels.at(index)

	var plain := 0
	var patterned := 0
	for body in _scene.get_children():
		if body is StaticBody3D and (body as Node3D).position.z > Elevator.CAB_HALF_WIDTH + 0.1:
			var mesh := body.get_child(0) as MeshInstance3D
			if ((mesh.mesh as BoxMesh).material as StandardMaterial3D).albedo_texture:
				patterned += 1
			else:
				plain += 1
	_check(plain == 0 and patterned == hotel.floors * 7, "%s: every hallway floor and wall is patterned (%d plain)" % [hotel.name, plain])

	for f in hotel.floors:
		var y: float = f * Elevator.FLOOR_HEIGHT
		var trim := _scene.find_child("Trim%d" % f, false, false) as Node3D
		if trim == null:
			_check(false, "%s floor %d has trim" % [hotel.name, f])
			continue
		var report: bool = f == 0
		_check_no_collision(trim, "%s floor %d's trim" % [hotel.name, f], report)
		var lamp := trim.find_child("LampSquareCeiling", false, false) as Node3D
		var lamp_box: AABB = lamp.transform * Decor.bounds(lamp.get_child(0)) if lamp else AABB()
		if report or not (lamp and lamp_box.position.y > y + HEADROOM):
			_check(lamp != null and lamp_box.position.y > y + HEADROOM, "%s floor %d has a ceiling lamp over everyone's head" % [hotel.name, f])
		var in_the_way: Array[String] = []
		for mesh: MeshInstance3D in trim.find_children("*", "MeshInstance3D", true, false):
			if lamp and lamp.is_ancestor_of(mesh):
				continue
			var box := mesh.global_transform * mesh.get_aabb()
			if not _against_a_wall(box, y):
				in_the_way.append("%s at %s" % [mesh.get_parent().name if mesh.get_parent() != trim else mesh.name, box.get_center()])
		if report or not in_the_way.is_empty():
			_check(in_the_way.is_empty(), "%s floor %d: all trim is flat against a wall or over your head %s" % [hotel.name, f, in_the_way])

	var sign := _floor_sign(0)
	var plate := _plate_behind(sign)
	_check(plate != null, "%s: the floor sign has a plate behind it" % hotel.name)
	if plate:
		var box := plate.global_transform * plate.get_aabb()
		_check(box.position.z > sign.global_position.z and box.end.z <= _walls().back + 0.001, "just behind its text, on the back wall")
		var text := ThemeDB.fallback_font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.font_size) * sign.pixel_size
		_check(box.size.x > text.x and box.size.y > text.y, "and bigger than the text")


func _test_cab() -> void:
	var cab := _elevator.get_cab()
	var trim := cab.find_child("Trim", false, false) as Node3D
	_check(trim != null, "the cab has trim")
	if trim == null:
		return
	_check_no_collision(trim, "the cab's trim", true)
	var patterned := 0
	for child in cab.get_children():
		if child is MeshInstance3D and ((child.mesh as BoxMesh).material as StandardMaterial3D).albedo_texture:
			patterned += 1
	_check(patterned == 8, "the cab's floor, ceiling and walls are patterned (%d of 8)" % patterned)
	var lit := trim.get_children().filter(func(m: Node) -> bool: return m is MeshInstance3D and ((m.mesh as BoxMesh).material as StandardMaterial3D).emission_enabled)
	_check(lit.size() == 1, "there's a light in its ceiling")

	var inner := Elevator.CAB_HALF_WIDTH - Elevator.WALL / 2
	var rails := 0
	for mesh: MeshInstance3D in trim.get_children():
		var box: AABB = mesh.transform * mesh.get_aabb()
		var flat_on_wall := box.position.z < -inner + FLUSH or box.position.x < -inner + FLUSH or box.end.x > inner - FLUSH
		var overhead := box.position.y > Elevator.CAB_HEIGHT - 0.1
		if not (flat_on_wall or overhead):
			_check(false, "cab trim at %s is flat against a wall or overhead" % box.get_center())
		var in_doorway := box.end.z > Elevator.CAB_HALF_WIDTH - Elevator.WALL - 0.03 and absf(box.get_center().x) < Elevator.DOOR_OPENING # where the doors slide
		if in_doorway and box.position.y < Elevator.DOOR_HEIGHT:
			_check(false, "cab trim at %s is clear of the doors" % box.get_center())
		if is_equal_approx(box.get_center().y, Interior.HANDRAIL_HEIGHT) and maxf(box.size.x, box.size.z) > 1.0:
			rails += 1
	_check(rails == 2, "a handrail runs along the back and the right-hand wall")
	var buttons_x := -(Elevator.CAB_HALF_WIDTH - Elevator.WALL / 2 - 0.02)
	_check(trim.get_children().all(func(m: MeshInstance3D) -> bool:
		var box: AABB = m.transform * m.get_aabb()
		return not (box.position.x < buttons_x + 0.1 and box.position.y < 2.2 and box.end.y > 0.7 and box.end.z > 0.2)), "and none by the buttons")


## True if [param box] (in a hallway whose floor is at [param y]) lies flat against one of
## its walls, or hangs over everyone's head.
func _against_a_wall(box: AABB, y: float) -> bool:
	var walls := _walls()
	var inner: float = walls.inner
	var landing: float = walls.landing
	var back: float = walls.back
	return box.position.y > y + HEADROOM \
			or box.position.x < -inner + FLUSH or box.end.x > inner - FLUSH \
			or box.position.z < landing + FLUSH or box.end.z > back - FLUSH


## The inner faces of a hallway's walls: the side walls at x = +-inner, the landing wall at
## z = landing and the back wall at z = back.
func _walls() -> Dictionary:
	var consts := (_scene.get_script() as Script).get_script_constant_map()
	var half: float = consts.HALL_WIDTH / 2
	return {
		"inner": half - 0.05,
		"landing": consts.SHAFT_FRONT + 0.1,
		"back": Elevator.CAB_HALF_WIDTH + 0.05 + consts.HALL_DEPTH - 0.05,
	}


func _check_no_collision(node: Node, what: String, report: bool) -> void:
	var solid := node.find_children("*", "CollisionShape3D", true, false).size() + node.find_children("*", "CollisionObject3D", true, false).size()
	if report or solid > 0:
		_check(solid == 0, "%s has no collision, so it never blocks anyone" % what)


func _floor_sign(f: int) -> Label3D:
	var y := f * Elevator.FLOOR_HEIGHT
	for label: Label3D in _scene.find_children("*", "Label3D", false, false):
		if label.text.begins_with("Floor %d" % f) and is_equal_approx(label.global_position.y, y + 2.0):
			return label
	return null


## The plate right behind [param sign]: the nearest trim box behind it in the sign's colour.
func _plate_behind(sign: Label3D) -> MeshInstance3D:
	if sign == null:
		return null
	var colour: Color = Interior.style(Hotels.at(Career.load_saved().hotel).id).sign
	for mesh: MeshInstance3D in _scene.find_child("Trim0", false, false).find_children("*", "MeshInstance3D", true, false):
		var mat := (mesh.mesh as BoxMesh).material as StandardMaterial3D if mesh.mesh is BoxMesh else null
		if mat and mat.albedo_color == colour:
			return mesh
	return null


func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene
