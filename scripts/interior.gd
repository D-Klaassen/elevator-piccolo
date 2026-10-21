class_name Interior
## The look of the hotel you work in and of the cab: flat, low-poly surfaces to go with
## Kenney's characters and furniture. Every hotel has a style ([constant STYLES]): the
## rustic cabin is log walls and plank floors, Pension Bellevue striped wallpaper over wood
## panelling and a patterned carpet. The patterns are small textures drawn here in code,
## laid over the boxes the rooms are built from (so a pattern runs on across walls), and
## the trim (skirting, door frames, ceilings, lamps, handrails) is extra boxes and models
## with no collision, so it never changes where you and the guests can walk.

const TEXTURE_SIZE := 128

## Per hotel id: the hallway floor, walls, lower walls (wainscot, or [] for none) and
## ceiling as [pattern, size in metres the texture covers, colours...]; then the colour of
## the trim (skirting, chair rail, door frames), of the floor sign's plate and its text.
const STYLES := {
	"cabin": {
		"floor": ["planks", 1.6, Color("8a5a35"), Color("7b4f2e"), Color("4a2e1a")],
		"wall": ["logs", 1.2, Color("b07a4a"), Color("9c6a3e"), Color("5e3b20")],
		"wainscot": [],
		"ceiling": ["planks", 2.0, Color("c49a6c"), Color("b88d60"), Color("8a6440")],
		"trim": Color("5e3b20"),
		"sign": Color("e8d5b0"),
		"sign_text": Color("3a2414"),
	},
	"bellevue": {
		"floor": ["carpet", 1.0, Color("7a2e2e"), Color("c9a24a"), Color("5a1f22")],
		"wall": ["wallpaper", 0.8, Color("e9dcc0"), Color("d9c7a2"), Color("b89c6a")],
		"wainscot": ["panels", 1.0, Color("6b4428"), Color("7d5232"), Color("4a2d19")],
		"ceiling": ["plain", 1.0, Color("f2ead8")],
		"trim": Color("c9a24a"),
		"sign": Color("2e3d2f"),
		"sign_text": Color("e9cf86"),
	},
}
const DEFAULT_STYLE := "bellevue"
const WAINSCOT_HEIGHT := 1.0

## The cab, the same in every hotel: wood panelling, a chequered floor, a brass handrail.
const CAB_WALL: Array = ["panels", 0.9, Color("8c5a36"), Color("9d6a42"), Color("5c3820")]
const CAB_FLOOR: Array = ["checker", 0.8, Color("2b2523"), Color("d8cfbd")]
const CAB_CEILING: Array = ["plain", 1.0, Color("efe6d2")]
const BRASS := Color("d9b25a")
const STEEL := Color("a8acb4")
const DOOR_FRAME := 0.08 ## width of the frame round the elevator opening
const FRAME_LAP := 0.01 ## how far the frame laps over the opening's edge
## How far the frame round a landing's opening stands out from the wall: as far as the
## chair rail, which runs into it.
const FRAME_PROUD := 0.04
const HANDRAIL_HEIGHT := 0.9
## The metadata on a trim piece that says what it is ("skirting", "door frame"), for the
## Asset room to name it.
const PART := &"part"

static var _textures := {}
static var _materials := {}


static func style(hotel_id: String) -> Dictionary:
	return STYLES.get(hotel_id, STYLES[DEFAULT_STYLE])


## A material that lays [param surface] ([pattern, metres, colours...]) over any box.
## [param moving] boxes (the cab's) get the pattern fixed to themselves; still ones get it
## fixed in the world, so it runs on from one box to the next.
static func material(surface: Array, moving := false) -> StandardMaterial3D:
	var key := "%s|%s" % [str(surface), moving]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.albedo_texture = texture(surface)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = not moving
	mat.uv1_triplanar_sharpness = 8.0
	mat.uv1_scale = Vector3.ONE / float(surface[1])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = mat
	return mat


static func flat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var key := "flat|%s|%s" % [color.to_html(), metallic]
	if not _materials.has(key):
		var mat := Greybox.material(color)
		mat.metallic = metallic
		mat.roughness = 0.45 if metallic > 0.0 else 0.8
		_materials[key] = mat
	return _materials[key]


## The texture for [param surface], drawn once and then reused.
static func texture(surface: Array) -> ImageTexture:
	var key := str(surface)
	if _textures.has(key):
		return _textures[key]
	var colours: Array = surface.slice(2)
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	match surface[0]:
		"planks": _draw_planks(image, colours, 16)
		"logs": _draw_logs(image, colours)
		"wallpaper": _draw_wallpaper(image, colours)
		"carpet": _draw_carpet(image, colours)
		"panels": _draw_panels(image, colours)
		"checker": _draw_checker(image, colours)
		_: image.fill(colours[0])
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = tex
	return tex


## Boards in rows of [param row] pixels, each row cut at different places, with a dark seam.
static func _draw_planks(image: Image, c: Array, row: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for top in range(0, TEXTURE_SIZE, row):
		var x := -rng.randi_range(0, 48)
		var tone := 0
		while x < TEXTURE_SIZE:
			var length := rng.randi_range(40, 72)
			var colour: Color = (c[tone % 2] as Color).lightened(rng.randf_range(-0.04, 0.04))
			_rect(image, x, top, length, row, colour)
			_rect(image, x, top, 1, row, c[2]) # the joint between two boards
			x += length
			tone += 1
		_rect(image, 0, top, TEXTURE_SIZE, 1, c[2])


## Logs: rows that are lighter in the middle and dark in the gap between them.
static func _draw_logs(image: Image, c: Array) -> void:
	var row := 32
	for top in range(0, TEXTURE_SIZE, row):
		var colour: Color = c[(top / row) % 2]
		for y in row:
			var curve := sin(PI * (y + 0.5) / row) # 0 at the edges, 1 in the middle
			_rect(image, 0, top + y, TEXTURE_SIZE, 1, (c[2] as Color).lerp(colour, clampf(curve * 1.6, 0.0, 1.0)))
		_rect(image, 0, top, TEXTURE_SIZE, 2, c[2])


## Vertical stripes with a thin line between them and a small diamond in the light ones.
static func _draw_wallpaper(image: Image, c: Array) -> void:
	var stripe := 16
	for left in range(0, TEXTURE_SIZE, stripe):
		var light := (left / stripe) % 2 == 0
		_rect(image, left, 0, stripe, TEXTURE_SIZE, c[0] if light else c[1])
		_rect(image, left, 0, 1, TEXTURE_SIZE, c[2])
		if light:
			for top in range(8, TEXTURE_SIZE, 32):
				_diamond(image, left + stripe / 2, top, 3, c[2])


## A diamond lattice with a gold dot in every diamond.
static func _draw_carpet(image: Image, c: Array) -> void:
	image.fill(c[0])
	var cell := 32
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var u := posmod(x + y, cell)
			var v := posmod(x - y, cell)
			if u < 2 or v < 2:
				image.set_pixel(x, y, c[2])
	for cy in range(0, TEXTURE_SIZE, cell):
		for cx in range(0, TEXTURE_SIZE, cell):
			_diamond(image, cx + cell / 2, cy, 4, c[1])
			_diamond(image, cx, cy + cell / 2, 4, c[1])


## Raised panels: a frame round a lighter panel, a dark line where they meet.
static func _draw_panels(image: Image, c: Array) -> void:
	image.fill(c[0])
	var panel := TEXTURE_SIZE / 2
	for top in range(0, TEXTURE_SIZE, TEXTURE_SIZE):
		for left in range(0, TEXTURE_SIZE, panel):
			_rect(image, left + 8, top + 10, panel - 16, TEXTURE_SIZE - 20, c[2])
			_rect(image, left + 9, top + 11, panel - 18, TEXTURE_SIZE - 22, c[1])
	for left in range(0, TEXTURE_SIZE, panel):
		_rect(image, left, 0, 1, TEXTURE_SIZE, c[2])


static func _draw_checker(image: Image, c: Array) -> void:
	var square := TEXTURE_SIZE / 2
	for y in 2:
		for x in 2:
			_rect(image, x * square, y * square, square, square, c[(x + y) % 2])


static func _rect(image: Image, x: int, y: int, w: int, h: int, colour: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, TEXTURE_SIZE, TEXTURE_SIZE))
	if r.has_area():
		image.fill_rect(r, colour)


static func _diamond(image: Image, cx: int, cy: int, radius: int, colour: Color) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius:
				image.set_pixel(posmod(cx + dx, TEXTURE_SIZE), posmod(cy + dy, TEXTURE_SIZE), colour)


## Trims one hallway (at height [param y], walls [param wall_h] high) in [param hotel_id]'s
## style, under [param parent]: skirting, wainscot and chair rail, a frame round the
## elevator opening, a ceiling with a lamp, and a plate behind [param sign], the floor
## sign. The hallway runs from the landing wall (centred on z = [param landing_z]) to the
## back wall (centred on [param back]), between side walls centred on x = ±[param half];
## all walls are 0.1 m thick. With [param open_right] the right-hand (+X) side wall is left
## out, and its trim with it. Every piece is named for the Asset room (see [method _box]).
static func trim_hallway(parent: Node3D, hotel_id: String, y: float, wall_h: float, half: float, landing_z: float, back: float, sign: Label3D, open_right := false) -> void:
	var s := style(hotel_id)
	var trim := flat(s.trim, 0.2 if hotel_id == "bellevue" else 0.0)
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
## body]: a plain slab of satin steel. Its collision fills its width, but it shows a few
## millimetres narrower, so the panels meet in a thin dark seam.
static func door_panel(body: Node3D, width: float, height: float, thickness: float) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	shape.shape = box
	body.add_child(shape)
	Greybox.box(body, Vector3(width - 0.004, height, thickness), Vector3.ZERO, Color.WHITE, false, steel())


## The frame round a landing's elevator opening, in a landing wall centred on z = [param
## landing_z] whose floor is at [param y]: [constant FRAME_PROUD] proud of the wall on the
## hallway side, and lining the opening right through the wall to just clear of the doors
## that hang behind it, so they slide in behind the frame and never through the wall.
static func landing_frame(parent: Node3D, y: float, landing_z: float, surface: Material) -> void:
	var shaft_face := landing_z - Elevator.WALL / 2
	# A hair proud of the wall's shaft side too, so the two never flicker there.
	_door_frame(parent, y, shaft_face - 0.002, landing_z + Elevator.WALL / 2 + FRAME_PROUD, surface)


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
## and the sides of the opening.
static func _door_frame(parent: Node3D, y: float, z_from: float, z_to: float, surface: Material) -> void:
	var lap := FRAME_LAP
	var width := DOOR_FRAME
	var inner := Elevator.DOOR_OPENING / 2 - lap
	var top := Elevator.DOOR_HEIGHT - lap
	var depth := absf(z_to - z_from)
	var z := (z_from + z_to) / 2
	for sign_x in [-1.0, 1.0]:
		_box(parent, Vector3(width, top + width, depth), Vector3(sign_x * (inner + width / 2), y + (top + width) / 2, z), surface, "door frame")
	_box(parent, Vector3(2 * (inner + width), width, depth), Vector3(0, y + top + width / 2, z), surface, "door frame")


## A threshold strip across a door opening, [param depth] deep, its middle at [param at]
## on the floor: dark metal, a few millimetres high.
static func _threshold(parent: Node3D, at: Vector3, depth: float) -> void:
	var width := Elevator.DOOR_OPENING + 0.04
	_box(parent, Vector3(width, 0.006, depth), at + Vector3(0, 0.003, 0), flat(Color("4a4c52"), 0.4), "threshold")


## Satin steel for the doors, the floor displays and the call plates: one even colour, no
## pattern, so it stays calm as you walk past.
static func steel() -> StandardMaterial3D:
	if not _materials.has("steel"):
		var mat := Greybox.material(STEEL)
		mat.metallic = 0.3
		mat.roughness = 0.5
		_materials["steel"] = mat
	return _materials["steel"]


## Trims the cab ([param cab], [param w] its half width, [param h] its height): a light
## in the ceiling, a brass handrail on the back and right-hand walls, and a skirting.
static func trim_cab(cab: Node3D, w: float, h: float, wall: float, front_face: float) -> void:
	var brass := flat(BRASS, 0.2)
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
	var dark := flat(CAB_WALL[4])
	_box(cab, Vector3(2 * inner, 0.1, 0.015), Vector3(0, 0.05, -inner + 0.0075), dark, "skirting")
	for x in [-inner + 0.0075, inner - 0.0075]:
		_box(cab, Vector3(0.015, 0.1, front_face + inner), Vector3(x, 0.05, (front_face - inner) / 2), dark, "skirting")
	var opening := Elevator.DOOR_OPENING / 2
	var skirt := inner - opening - 0.1
	for sign_x in [-1.0, 1.0]:
		_box(cab, Vector3(skirt, 0.1, 0.015), Vector3(sign_x * (inner - skirt / 2), 0.05, front_face - 0.0075), dark, "skirting")

	# A frame round the door, like the one round the landing doors on the hallway side, and
	# a lining through the front wall on the shaft side of the doors, so from the hallway
	# too they slide in behind a frame, not into the wood.
	_door_frame(cab, 0.0, front_face - 0.02, Elevator.CAB_LEAD_Z - Elevator.PANEL_THICKNESS / 2 - 0.0025, dark)
	_door_frame(cab, 0.0, Elevator.CAB_TRAIL_Z + Elevator.PANEL_THICKNESS / 2 + 0.0025, w + wall / 2 + 0.004, dark)
	# Over the doors, between the two front walls, the dark header their track runs in, the
	# width of the cab, so looking up past the frame you don't see the front wall's wood
	# above them, however far they slide.
	var header_from := front_face + Elevator.SKIN
	var header_to := w - wall / 2
	var header_bottom := Elevator.DOOR_HEIGHT + 0.001
	_box(cab, Vector3(2 * inner, h - header_bottom, header_to - header_from), Vector3(0, (h + header_bottom) / 2, (header_from + header_to) / 2), flat(Color("1c1c20")), "door header")

	# The threshold the doors run in, from the inner front wall to the front wall's outside.
	var outside := w + wall / 2
	_threshold(cab, Vector3(0, 0, (front_face + outside) / 2), outside - front_face)


## A box with no collision. [param part] says what it is, for the Asset room to name it
## ([constant PART]).
static func _box(parent: Node3D, size: Vector3, center: Vector3, surface: Material, part := "") -> MeshInstance3D:
	var mesh := Greybox.box(parent, size, center, Color.WHITE, false, surface) as MeshInstance3D
	if part:
		mesh.set_meta(PART, part)
	return mesh
