class_name Interior
## The look of the hotel you work in and of the cab, to go with Kenney's characters and
## furniture. Every hotel has a style ([constant STYLES]): the rustic cabin is log walls and
## plank floors, Pension Bellevue cream wallpaper over dark wood panelling and a red carpet.
## Every surface is a PBR texture set (colour, normal and ORM maps, CC0, from Poly Haven and
## ambientCG; see CREDITS.md and tools/pbr_texture.sh) laid over the boxes the rooms are
## built from (so it runs on across walls), and the trim (skirting, door frames, ceilings,
## lamps, handrails) is extra boxes and models with no collision, so it never changes where
## you and the guests can walk.

## Where the texture sets live, a folder per set with albedo.jpg, normal.jpg and orm.jpg.
const TEXTURES := "res://assets/textures/"
## How metallic the metal sets (steel, brass) are drawn, of what their ORM map says. There
## are no reflection probes, so all fully metallic steel and brass would reflect is the
## dim ambient light, and they'd look nearly black.
const METAL_SHEEN := 0.4

## Per hotel id: the hallway floor, walls, lower walls (wainscot, or [] for none), ceiling
## and trim (skirting, chair rail, door frames) as surfaces: [name, size in metres the
## texture covers, texture set, tint (white if left out; over 1 brightens)]. The name is
## what the Asset room calls it ("Pension Bellevue carpet floor"). Then the colour of the
## floor sign's plate and its text.
const STYLES := {
	"cabin": {
		"floor": ["planks", 2.0, "old_wooden_floor_01"],
		"wall": ["logs", 1.25, "wood_trunk_wall", Color(1.5, 1.25, 1.0)],
		"wainscot": [],
		"ceiling": ["planks", 1.9, "hinoki_planks", Color("e0c8a8")],
		"trim": ["wood", 1.8, "walnut_veneer", Color("806048")],
		"sign": Color("e8d5b0"),
		"sign_text": Color("3a2414"),
	},
	"bellevue": {
		"floor": ["carpet", 1.0, "Carpet013", Color("b85a5a")],
		"wall": ["wallpaper", 1.0, "Wallpaper001A", Color("eadcbe")],
		"wainscot": ["panels", 1.4, "dark_paneled_wood"],
		"ceiling": ["plaster", 2.0, "PaintedPlaster017", Color("f6efe0")],
		"trim": ["brass", 0.5, "Metal042A"],
		"sign": Color("2e3d2f"),
		"sign_text": Color("e9cf86"),
	},
}
const DEFAULT_STYLE := "bellevue"
const WAINSCOT_HEIGHT := 1.0

## The cab, the same in every hotel: wood panelling, a chequered marble floor, a brass
## handrail, dark wood round the door, brushed steel doors.
const CAB_WALL: Array = ["panels", 2.1, "wooden_panels"]
const CAB_FLOOR: Array = ["checker", 1.6, "Tiles012"]
const CAB_CEILING: Array = ["plaster", 2.0, "PaintedPlaster017", Color("f2ead8")]
const CAB_TRIM: Array = ["wood", 1.8, "walnut_veneer", Color("806048")]
const BRASS: Array = ["brass", 0.5, "Metal042A"]
const STEEL: Array = ["steel", 1.0, "Metal009"]
## The threshold the doors run in: dark metal.
const SILL: Array = ["metal", 0.5, "Metal009", Color("5a5c62")]
const DOOR_FRAME := 0.08 ## width of the frame round the elevator opening
const FRAME_LAP := 0.01 ## how far the frame laps over the opening's edge
const CAB_FRAME_PROUD := 0.008 ## how far the cab's frame stands out from its inner front wall
## How far the frame round a landing's opening stands out from the wall: as far as the
## chair rail, which runs into it.
const FRAME_PROUD := 0.04
const HANDRAIL_HEIGHT := 0.9
## The metadata on a trim piece that says what it is ("skirting", "door frame"), for the
## Asset room to name it.
const PART := &"part"

static var _materials := {}


static func style(hotel_id: String) -> Dictionary:
	return STYLES.get(hotel_id, STYLES[DEFAULT_STYLE])


## A material that lays [param surface] ([name, metres, texture set, tint]) over any box.
## [param moving] boxes (the cab's and its doors') get the texture fixed to themselves;
## still ones get it fixed in the world, so it runs on from one box to the next. A moving
## box centred [param at] in what it moves with gets the texture shifted to match, so it
## runs on across the cab's boxes too.
static func material(surface: Array, moving := false, at := Vector3.ZERO) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [str(surface), moving, at]
	if _materials.has(key):
		return _materials[key]
	var maps: String = TEXTURES + surface[2]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(maps + "/albedo.jpg")
	mat.albedo_color = surface[3] if surface.size() > 3 else Color.WHITE
	mat.normal_enabled = true
	mat.normal_texture = load(maps + "/normal.jpg")
	# One ORM texture for all three, a channel each. (An ORMMaterial3D reads it too, but
	# ignores the metallic setting, so the metal would come out black.)
	var orm: Texture2D = load(maps + "/orm.jpg")
	mat.ao_enabled = true
	mat.ao_texture = orm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness_texture = orm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = 1.0
	mat.metallic_texture = orm
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = METAL_SHEEN
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = not moving
	mat.uv1_triplanar_sharpness = 8.0
	mat.uv1_scale = Vector3.ONE / float(surface[1])
	mat.uv1_offset = at / float(surface[1])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = mat
	return mat


## A plain [param color], for what is painted rather than made of something: the floor
## signs' plates and the shaft.
static func flat(color: Color) -> StandardMaterial3D:
	var key := "flat|%s" % color.to_html()
	if not _materials.has(key):
		_materials[key] = Greybox.material(color)
	return _materials[key]


## Trims one hallway (at height [param y], walls [param wall_h] high) in [param hotel_id]'s
## style, under [param parent]: skirting, wainscot and chair rail, a frame round the
## elevator opening, a ceiling with a lamp, and a plate behind [param sign], the floor
## sign. The hallway runs from the landing wall (centred on z = [param landing_z]) to the
## back wall (centred on [param back]), between side walls centred on x = ±[param half];
## all walls are 0.1 m thick. With [param open_right] the right-hand (+X) side wall is left
## out, and its trim with it. Every piece is named for the Asset room (see [method _box]).
static func trim_hallway(parent: Node3D, hotel_id: String, y: float, wall_h: float, half: float, landing_z: float, back: float, sign: Label3D, open_right := false) -> void:
	var s := style(hotel_id)
	var trim := material(s.trim)
	var depth := back - landing_z
	var mid_z := (landing_z + back) / 2
	var inner := half - 0.05 # the side walls' inner faces
	var back_face := back - 0.05
	var landing_face := landing_z + 0.05
	var opening := Elevator.DOOR_OPENING / 2
	# Either side of the opening the lower walls run from the frame's outer edge to the side wall.
	var beside_from := opening - FRAME_LAP + DOOR_FRAME
	var beside := inner - beside_from
	var beside_x := beside_from + beside / 2

	# Lower walls: wainscot with a chair rail on top, or just a skirting board.
	var low_h: float = WAINSCOT_HEIGHT if not (s.wainscot as Array).is_empty() else 0.12
	var low := material(s.wainscot) if not (s.wainscot as Array).is_empty() else trim
	var low_part := "%s wainscot" % s.wainscot[0] if not (s.wainscot as Array).is_empty() else "skirting"
	var t := 0.02
	_box(parent, Vector3(t, low_h, depth - 0.1), Vector3(-inner + t / 2, y + low_h / 2, mid_z), low, low_part)
	if not open_right:
		_box(parent, Vector3(t, low_h, depth - 0.1), Vector3(inner - t / 2, y + low_h / 2, mid_z), low, low_part)
	_box(parent, Vector3(2 * inner, low_h, t), Vector3(0, y + low_h / 2, back_face - t / 2), low, low_part)
	for sign_x in [-1.0, 1.0]:
		_box(parent, Vector3(beside, low_h, t), Vector3(sign_x * beside_x, y + low_h / 2, landing_face + t / 2), low, low_part)
	if not (s.wainscot as Array).is_empty():
		var rail := 0.05
		var rail_y := y + low_h + rail / 2
		_box(parent, Vector3(0.04, rail, depth - 0.1), Vector3(-inner + 0.02, rail_y, mid_z), trim, "chair rail")
		if not open_right:
			_box(parent, Vector3(0.04, rail, depth - 0.1), Vector3(inner - 0.02, rail_y, mid_z), trim, "chair rail")
		_box(parent, Vector3(2 * inner, rail, 0.04), Vector3(0, rail_y, back_face - 0.02), trim, "chair rail")
		for sign_x in [-1.0, 1.0]:
			_box(parent, Vector3(beside, rail, 0.04), Vector3(sign_x * beside_x, rail_y, landing_face + 0.02), trim, "chair rail")

	# The hotel's own frame round the elevator opening: proud of the wall on the hallway
	# side and lining the opening right through the wall, to the doors behind it.
	landing_frame(parent, y, landing_z, trim)

	landing_sill(parent, y, landing_z)

	# The ceiling, and a lamp in the middle of it.
	_box(parent, Vector3(2 * half, 0.02, depth), Vector3(0, y + wall_h - 0.01, mid_z), material(s.ceiling), "%s ceiling" % s.ceiling[0])
	var lamp := Decor.put(parent, "lampSquareCeiling", Vector3(0, 0, mid_z))
	var lamp_box := lamp.transform * Decor.bounds(lamp.get_child(0))
	lamp.position.y = y + wall_h - 0.02 - lamp_box.size.y

	# A plate behind the floor sign, just behind its text, in a frame.
	sign.modulate = s.sign_text
	var font: Font = sign.font if sign.font else ThemeDB.fallback_font
	var text := font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.font_size) * sign.pixel_size
	var plate := Vector2(text.x + 0.3, text.y + 0.06)
	var plate_face := sign.position.z + 0.003
	_box(parent, Vector3(plate.x, plate.y, back_face - plate_face), Vector3(sign.position.x, sign.position.y, (plate_face + back_face) / 2), flat(s.sign), "floor sign plate")
	_box(parent, Vector3(plate.x + 0.1, plate.y + 0.1, back_face - plate_face - 0.003), Vector3(sign.position.x, sign.position.y, (plate_face + 0.003 + back_face) / 2), trim, "floor sign frame")


## One door panel, [param width] by [param height] and [param thickness] thick, on [param
## body]: a plain slab of brushed steel. Its collision fills its width; the steel reaches
## [param minus_x] metres past it on its -X edge, [param plus_x] on its +X edge (stopping
## short if negative) and [param up] over its top, so it laps over the next panel or in
## behind the frame and there's no slit to look through.
static func door_panel(body: Node3D, width: float, height: float, thickness: float, minus_x := 0.0, plus_x := 0.0, up := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	shape.shape = box
	body.add_child(shape)
	Greybox.box(body, Vector3(width + minus_x + plus_x, height + up, thickness), Vector3((plus_x - minus_x) / 2, up / 2, 0), Color.WHITE, false, steel())


## The frame round a landing's elevator opening, in a landing wall centred on z = [param
## landing_z] whose floor is at [param y]: [constant FRAME_PROUD] proud of the wall on the
## hallway side, and lining the opening right through the wall to just clear of the doors
## that hang behind it, so they slide in behind the frame and never through the wall.
static func landing_frame(parent: Node3D, y: float, landing_z: float, surface: Material) -> void:
	var shaft_face := landing_z - Elevator.WALL / 2
	# A hair proud of the wall's shaft side too, so the two never flicker there.
	_door_frame(parent, y, shaft_face - 0.002, landing_z + Elevator.WALL / 2 + FRAME_PROUD, surface)


## The shaft side of a landing's elevator opening, whose floor is at [param y], in the
## shaft's grey: from the back of the landing wall (centred on z = [param landing_z]) to just
## clear of the cab, a header over the doors [param height] high and, for side-opening
## doors ([param style]), a block beside the side they shut against. So from the cab you
## see solid grey between its doors and the landing doors, not the empty shaft.
static func landing_backing(parent: Node3D, y: float, landing_z: float, style: ElevatorDoor.Style, height: float) -> void:
	var grey := flat(Hallway.SHAFT_GREY)
	# Just clear of where the cab's front and its lining pass.
	var from := landing_z - Elevator.LANDING_Z + Elevator.CAB_HALF_WIDTH + Elevator.WALL / 2 + 0.006
	var to := landing_z - Elevator.WALL / 2 - 0.002 # up to the frame lining the opening
	var depth := to - from
	var z := (from + to) / 2
	var half := Elevator.CAB_HALF_WIDTH + 0.1 # to the shaft's side walls
	var top := Elevator.DOOR_HEIGHT + Elevator.DOOR_TOP_REACH + 0.002 # over the doors' steel
	_box(parent, Vector3(2 * half, height - top + Elevator.DOOR_HEIGHT, depth), Vector3(0, y + (top + Elevator.DOOR_HEIGHT + height) / 2, z), grey, "landing door header")
	if style == ElevatorDoor.Style.SIDE:
		var inner := Elevator.DOOR_OPENING / 2 - FRAME_LAP # flush with the frame: the doors shut against it
		_box(parent, Vector3(half - inner, top, depth), Vector3(-(inner + half) / 2, y + top / 2, z), grey, "landing door jamb")


## A dark metal threshold across a landing's elevator opening, in a landing wall centred on
## z = [param landing_z] whose floor is at [param y]: from under the doors behind the wall
## to a little way into the hallway.
static func landing_sill(parent: Node3D, y: float, landing_z: float) -> void:
	var from := landing_z - Elevator.LANDING_LEAD_BACK - Elevator.PANEL_THICKNESS / 2 - 0.01
	var to := landing_z + Elevator.WALL / 2 + 0.06
	_threshold(parent, Vector3(0, y, (from + to) / 2), to - from)


## A flat frame round an elevator opening whose floor is at [param y], from z = [param
## z_from] to [param z_to]: from just clear of the doors to a little proud of the wall. It
## laps [constant FRAME_LAP] over the doors' outer edges, as a real jamb does, hiding them
## and the sides of the opening. With an [param inset] its inner edge stands that much
## further out, and it is [param width] wide.
static func _door_frame(parent: Node3D, y: float, z_from: float, z_to: float, surface: Material, part := "door frame", inset := 0.0, width := DOOR_FRAME) -> void:
	var lap := FRAME_LAP - inset
	var inner := Elevator.DOOR_OPENING / 2 - lap
	var top := Elevator.DOOR_HEIGHT - lap
	var depth := absf(z_to - z_from)
	var z := (z_from + z_to) / 2
	for sign_x in [-1.0, 1.0]:
		_box(parent, Vector3(width, top + width, depth), Vector3(sign_x * (inner + width / 2), y + (top + width) / 2, z), surface, part)
	_box(parent, Vector3(2 * (inner + width), width, depth), Vector3(0, y + top + width / 2, z), surface, part)


## A threshold strip across a door opening, [param depth] deep, its middle at [param at]
## on the floor: dark metal, a few millimetres high, its grain fixed to itself as the cab's
## moves.
static func _threshold(parent: Node3D, at: Vector3, depth: float) -> void:
	var width := Elevator.DOOR_OPENING + 0.04
	_box(parent, Vector3(width, 0.006, depth), at + Vector3(0, 0.003, 0), material(SILL, true), "threshold")


## Brushed steel for the doors, the floor displays and the call plates: one even grain, no
## pattern, so it stays calm as you walk past. Fixed to each box, as the doors move.
static func steel() -> StandardMaterial3D:
	return material(STEEL, true)


## Trims the cab ([param cab], [param w] its half width, [param h] its height, its doors
## of [param style]): a light in the ceiling, a brass handrail on the back and right-hand
## walls, a skirting, and the frame, lining, jamb and header round the doors.
static func trim_cab(cab: Node3D, w: float, h: float, wall: float, front_face: float, style: ElevatorDoor.Style) -> void:
	var brass := material(BRASS, true)
	var inner := w - wall / 2
	var light := Greybox.material(Color("fff6e0"))
	light.emission_enabled = true
	light.emission = Color("fff1d0")
	light.emission_energy_multiplier = 1.5
	_box(cab, Vector3(0.8, 0.02, 0.8), Vector3(0, h - 0.01, 0), light, "ceiling light")
	_box(cab, Vector3(0.9, 0.025, 0.9), Vector3(0, h - 0.0125, 0), brass, "ceiling light")

	# Handrail on the back wall and on the +X wall (the buttons are on the -X wall).
	var rail_out := 0.06
	_box(cab, Vector3(2 * inner - 0.3, 0.04, 0.04), Vector3(0, HANDRAIL_HEIGHT, -inner + rail_out), brass, "handrail")
	_box(cab, Vector3(0.04, 0.04, 2 * inner - 0.5), Vector3(inner - rail_out, HANDRAIL_HEIGHT, -0.1), brass, "handrail")
	for x in [-inner + 0.35, inner - 0.35]:
		_box(cab, Vector3(0.03, 0.03, rail_out), Vector3(x, HANDRAIL_HEIGHT, -inner + rail_out / 2), brass, "handrail")
	for z in [-inner + 0.35, inner - 0.6]:
		_box(cab, Vector3(rail_out, 0.03, 0.03), Vector3(inner - rail_out / 2, HANDRAIL_HEIGHT, z), brass, "handrail")

	# Skirting on the back and side walls and on the inner front wall (at [param front_face],
	# which the open doors slide behind), either side of the door.
	var dark := material(CAB_TRIM, true)
	_box(cab, Vector3(2 * inner, 0.1, 0.015), Vector3(0, 0.05, -inner + 0.0075), dark, "skirting")
	for x in [-inner + 0.0075, inner - 0.0075]:
		_box(cab, Vector3(0.015, 0.1, front_face + inner), Vector3(x, 0.05, (front_face - inner) / 2), dark, "skirting")
	var opening := Elevator.DOOR_OPENING / 2
	var skirt := inner - opening - 0.1
	for sign_x in [-1.0, 1.0]:
		_box(cab, Vector3(skirt, 0.1, 0.015), Vector3(sign_x * (inner - skirt / 2), 0.05, front_face - 0.0075), dark, "skirting")

	# A frame round the door: a dark face on the wall, like the one round the landing doors on
	# the hallway side, with steel inside it running back to the doors, so shut they close
	# up into steel with no dark edge round them. And a lining through the front wall on the
	# shaft side of the doors, in the grey of the landing's header and jamb, so from the
	# hallway too they slide in behind a frame, not into the wood, and between the cab's
	# doors and the landing doors there's only grey.
	var frame_back := Elevator.CAB_LEAD_Z - Elevator.PANEL_THICKNESS / 2 - Elevator.DOOR_GAP
	# Half a gap clear of the doors, so its back stays just in front of the front wall's
	# inside and the two never flicker.
	var lining_front := Elevator.CAB_TRAIL_Z + Elevator.PANEL_THICKNESS / 2 + Elevator.DOOR_GAP / 2
	var jamb_h := Elevator.DOOR_HEIGHT + Elevator.DOOR_TOP_REACH + 0.002 # up to the header
	_door_frame(cab, 0.0, front_face - CAB_FRAME_PROUD, front_face, dark, "door frame", FRAME_LAP, DOOR_FRAME - FRAME_LAP)
	_door_frame(cab, 0.0, front_face - CAB_FRAME_PROUD, frame_back, steel(), "door jamb", 0.0, FRAME_LAP)
	_door_frame(cab, 0.0, lining_front, w + wall / 2 + 0.004, flat(Hallway.SHAFT_GREY), "door lining")
	# The pockets the open doors slide into, lined in steel on the front wall's inside, so
	# looking past the frame at the doors you never see wood behind them.
	var pocket_from := Elevator.DOOR_OPENING / 2 - FRAME_LAP + DOOR_FRAME # past the lining
	var pocket_z := w - wall / 2 - 0.0015
	for sign_x: float in [1.0] if style == ElevatorDoor.Style.SIDE else [-1.0, 1.0]:
		_box(cab, Vector3(inner - pocket_from, Elevator.DOOR_HEIGHT + 0.001, 0.002), Vector3(sign_x * (pocket_from + inner) / 2, (Elevator.DOOR_HEIGHT + 0.001) / 2, pocket_z), steel(), "door pocket")
	# Side-opening doors shut against a solid jamb, flush with the frame, in the grey of the
	# rest of the doorway between the cab's doors and the landing doors,
	# filling the slot between the two front walls on that side: no gap where they close.
	if style == ElevatorDoor.Style.SIDE:
		var jamb_from := Elevator.DOOR_OPENING / 2 - FRAME_LAP
		_box(cab, Vector3(inner - jamb_from, jamb_h, lining_front - frame_back), Vector3(-(jamb_from + inner) / 2, jamb_h / 2, (frame_back + lining_front) / 2), flat(Hallway.SHAFT_GREY), "door jamb")
	# Over the doors, between the two front walls, the steel header their track runs in, the
	# width of the cab, so looking up past the frame you don't see the front wall's wood
	# above them, however far they slide.
	var header_from := front_face + Elevator.SKIN
	var header_to := w - wall / 2
	var header_bottom := jamb_h
	_box(cab, Vector3(2 * inner, h - header_bottom, header_to - header_from), Vector3(0, (h + header_bottom) / 2, (header_from + header_to) / 2), steel(), "door header")

	# The threshold the doors run in, from the inner front wall to the front wall's outside,
	# its ends a hair off the walls' faces so they never flicker.
	var sill_from := front_face - 0.002
	var sill_to := w + wall / 2 - 0.001
	_threshold(cab, Vector3(0, 0, (sill_from + sill_to) / 2), sill_to - sill_from)


## A box with no collision. [param part] says what it is, for the Asset room to name it
## ([constant PART]).
static func _box(parent: Node3D, size: Vector3, center: Vector3, surface: Material, part := "") -> MeshInstance3D:
	var mesh := Greybox.box(parent, size, center, Color.WHITE, false, surface) as MeshInstance3D
	if part:
		mesh.set_meta(PART, part)
	return mesh
