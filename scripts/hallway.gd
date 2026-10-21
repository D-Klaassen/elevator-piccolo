class_name Hallway
## Builds a hotel from boxes, dressed in its own style ([Interior]): the shaft around the cab
## and a hallway on every floor, with its landing wall, floor sign, trim, furniture and
## light. The hotel you work in ([code]cabin_greybox.gd[/code]) and the Asset room both use it.

const WIDTH := 6.0
const DEPTH := 4.0
## The landing walls' middle: the landing doors hang just behind it ([member Elevator.landing_z]).
const LANDING_Z := Elevator.LANDING_Z
const SHAFT_FRONT := LANDING_Z - Elevator.WALL / 2 ## z where the landing wall starts, in front of the cab
const SHAFT_GREY := Color(0.25, 0.25, 0.27)


## The hotel's light: a dark background and a warm ambient light. Returns it, for the
## brightness setting.
static func build_environment(parent: Node) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.07, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.4)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	return env


## The pit floor, back and side walls of a shaft [param floors] floors high, around the cab;
## the side walls reach the landing walls.
static func build_shaft(parent: Node3D, floors: int) -> void:
	var color := SHAFT_GREY
	var height := floors * Elevator.FLOOR_HEIGHT + 1.0
	var center_y := height / 2 - 1.0
	var outer := Elevator.CAB_HALF_WIDTH + 0.15
	var depth := outer + SHAFT_FRONT
	var middle_z := (SHAFT_FRONT - outer) / 2
	Greybox.box(parent, Vector3(2 * outer, 0.2, depth), Vector3(0, -1.1, middle_z), color)
	Greybox.box(parent, Vector3(2 * outer, height, 0.1), Vector3(0, center_y, -outer), color)
	Greybox.box(parent, Vector3(0.1, height, depth), Vector3(-outer, center_y, middle_z), color)
	Greybox.box(parent, Vector3(0.1, height, depth), Vector3(outer, center_y, middle_z), color)


## The hallway of floor [param f] in [param hotel] (from [constant Hotels.LADDER]), under
## [param parent]: its floor, the landing wall with the opening for the elevator, the side
## and back walls, the floor sign, the trim (as "Trim<f>"), the furniture (as
## "Furniture<f>") and a light. Its floor and walls are named "Floor<f>",
## "LandingWallLeft<f>", "LandingWallRight<f>", "Lintel<f>", "SideWallLeft<f>",
## "SideWallRight<f>" and "BackWall<f>". With [param open_right] the right-hand (+X) side
## wall is left out, so the Asset room can show the hallway open on that side.
static func build(parent: Node3D, hotel: Dictionary, f: int, open_right := false) -> void:
	var y := f * Elevator.FLOOR_HEIGHT
	var hotel_id: String = hotel.id
	var look := Interior.style(hotel_id)
	var floor_surface := Interior.material(look.floor)
	var wall_surface := Interior.material(look.wall)
	var wall_h := Elevator.FLOOR_HEIGHT - 0.2
	var front := Elevator.CAB_HALF_WIDTH + 0.05
	var back := front + DEPTH

	# Hallway floor; it also acts as the ceiling of the hallway below.
	var hall_floor := Greybox.box(parent, Vector3(WIDTH, 0.2, DEPTH), Vector3(0, y - 0.1, front + DEPTH / 2), Color.WHITE, true, floor_surface)
	hall_floor.name = "Floor%d" % f

	# The landing wall facing the hallway, with an opening in front of the cab door, then
	# the side and back walls.
	var half := WIDTH / 2
	var opening := Elevator.DOOR_OPENING / 2
	var side := half - opening
	var lintel_h := wall_h - Elevator.DOOR_HEIGHT
	for piece in [
		["LandingWallLeft", Vector3(side, wall_h, 0.1), Vector3(-(opening + side / 2), y + wall_h / 2, LANDING_Z)],
		["LandingWallRight", Vector3(side, wall_h, 0.1), Vector3(opening + side / 2, y + wall_h / 2, LANDING_Z)],
		["Lintel", Vector3(Elevator.DOOR_OPENING, lintel_h, 0.1), Vector3(0, y + Elevator.DOOR_HEIGHT + lintel_h / 2, LANDING_Z)],
		["SideWallLeft", Vector3(0.1, wall_h, DEPTH), Vector3(-half, y + wall_h / 2, front + DEPTH / 2)],
		["SideWallRight", Vector3(0.1, wall_h, DEPTH), Vector3(half, y + wall_h / 2, front + DEPTH / 2)],
		["BackWall", Vector3(WIDTH, wall_h, 0.1), Vector3(0, y + wall_h / 2, back)],
	]:
		if open_right and piece[0] == "SideWallRight":
			continue
		var wall := Greybox.box(parent, piece[1], piece[2], Color.WHITE, true, wall_surface)
		wall.name = "%s%d" % [piece[0], f]
	# The landing wall's shaft side, as far as the cab looks out on it, in the shaft's grey,
	# so no wallpaper shows past the frame from inside the cab.
	var shaft_face := SHAFT_FRONT - 0.001 # clear of the landing doors just behind it
	var beside_from := opening - Interior.FRAME_LAP + Interior.DOOR_FRAME
	var beside := Elevator.CAB_HALF_WIDTH + 0.1 - beside_from
	var above := Elevator.DOOR_HEIGHT - Interior.FRAME_LAP + Interior.DOOR_FRAME
	for sign_x in [-1.0, 1.0]:
		Greybox.box(parent, Vector3(beside, wall_h, 0.002), Vector3(sign_x * (beside_from + beside / 2), y + wall_h / 2, shaft_face), SHAFT_GREY, false)
	Greybox.box(parent, Vector3(2 * beside_from, wall_h - above, 0.002), Vector3(0, y + (wall_h + above) / 2, shaft_face), SHAFT_GREY, false)

	# Floor sign on the back wall, facing the elevator (-Z).
	var places: Array = hotel.places
	var sign_text := "Floor %d" % f if places.is_empty() else "Floor %d · %s" % [f, places[f]]
	var sign_label := Greybox.label(parent, sign_text, Vector3(0, y + 2.0, back - 0.06), 180.0, 96 if places.is_empty() else 72)

	# Skirting, door frame, ceiling and lamp: looks only, no collision.
	var trim := Node3D.new()
	trim.name = "Trim%d" % f
	parent.add_child(trim)
	Interior.trim_hallway(trim, hotel_id, y, wall_h, half, LANDING_Z, back, sign_label, open_right)

	var furniture := Node3D.new()
	furniture.name = "Furniture%d" % f
	parent.add_child(furniture)
	Decor.furnish(furniture, "" if places.is_empty() else places[f], y)

	var light := OmniLight3D.new()
	light.position = Vector3(0, y + wall_h - 0.4, front + DEPTH / 2)
	light.omni_range = 5.0
	parent.add_child(light)
