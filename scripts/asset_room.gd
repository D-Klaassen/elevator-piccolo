class_name AssetRoom
extends Node3D
## The Asset room: every asset laid out at its in-game size in one long room, under the
## hotel's own light, to walk past, look at and comment on. Only in debug builds, from the
## Settings menu's Debug section. Looking at an asset shows its asset name in the HUD;
## that is the name to quote when asking for a change.
##
## You walk down the aisle (+X) through the sections, each with a sign and a 1.8 m pole to
## judge sizes by: the characters (press interact on one to go through its animations), the
## furniture, the parts of the cab and the doors, a sample corner per hotel (a hallway
## built by the same code as the game's ([Hallway]), open on the aisle side, with a
## working elevator in it) and the sounds (press a button to hear it). The models are
## picked up from the asset folders, so a new one shows up on its own.
##
## Esc opens the Settings menu; Leave the Asset room goes back where you came from: the
## staff room, or a fresh start of the shift you left.

const SCENE := "res://scenes/asset_room.tscn"
const ASSETS := "res://assets"
const SIDE := 1.3 ## how far from the middle of the aisle the assets' fronts stand
const GAP := 0.8 ## between two assets in a row
const SECTION_GAP := 2.5
const HEIGHT := 4.5 ## of the room
const REFERENCE_HEIGHT := 1.8
const SIGN_SIZE := 32 ## font size of the asset names at the assets' feet
## What a floor display shows as you press it: [floor, direction].
## Trim that is the same in every hotel, so it is named without the hotel's name.
const SAME_IN_EVERY_HOTEL: Array[String] = ["threshold"]
const DISPLAY_STATES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 0), Vector2i(2, -1), Vector2i(1, -1),
]

## True when the Asset room was entered from the staff room, so leaving it should go back
## there instead of starting a shift. The hotel scene reads it, and clears it, when it loads.
static var back_to_staff_room := false

## The sounds played, by name, oldest first.
var played: Array[String] = []

var _left_x := 0.0 ## where the next asset on the left-hand (-Z) side of the aisle goes
var _right_x := 0.0
var _player: Player
var _settings: Settings
var _settings_menu: SettingsMenu
var _crosshair: Label
var _looking_label: Label
var _debug_label: Label
var _sounds := {} ## name -> AudioStreamPlayer


## Leaves the hotel for the Asset room. [param from_staff_room] says where to go back to.
static func enter(tree: SceneTree, from_staff_room: bool) -> void:
	back_to_staff_room = from_staff_room
	tree.paused = false
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	_settings = Settings.load_saved()
	_settings.apply_volume()
	Hallway.build_environment(self)
	_left_x = 1.5
	_right_x = 1.5
	_section("Characters")
	var models := _models(ASSETS)
	var characters_dir := Guest.MODELS[0].get_base_dir()
	for path in models:
		if path.get_base_dir() == characters_dir:
			_place(_character(path), _left_x <= _right_x)
	_section("Furniture")
	for path in models:
		if path.get_base_dir() != characters_dir:
			_place(_model(path), _left_x <= _right_x)
	_section("Cab and doors")
	_place(_door_panel(), true)
	_place(_floor_display(), false)
	_place(_button("call button", "", true), true)
	_place(_button("floor button", "2", false), false)
	_section("Hotel styles")
	for hotel in Hotels.LADDER:
		_sample_corner(hotel)
	_section("Sounds")
	_place(_sound("ding", Elevator.make_ding()), true)
	_place(_sound("chime going up", Elevator.make_chime(false)), false)
	_place(_sound("chime going down", Elevator.make_chime(true)), true)
	_build_room(maxf(_left_x, _right_x) + 1.0)

	_player = Player.new()
	_player.name = "Player"
	_player.position = Vector3(0.0, 0.05, 0.0)
	_player.rotation_degrees.y = -90.0 # down the aisle (+X)
	_player.look_sensitivity = _settings.look_sensitivity
	add_child(_player)
	_build_hud()
	_player.looking_at_changed.connect(_on_looking_at_changed)


## The first asset whose asset name is [param asset_name]: what you look at to see it.
func asset(asset_name: String) -> CollisionObject3D:
	for body: CollisionObject3D in find_children("*", "CollisionObject3D", true, false):
		if Player.name_of(body) == asset_name:
			return body
	return null


## Every .glb under [param dir], at any depth, in order.
static func _models(dir: String) -> Array[String]:
	var found: Array[String] = []
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			found.append_array(_models(dir.path_join(entry.trim_suffix("/"))))
		elif entry.get_extension() == "glb":
			found.append(dir.path_join(entry))
	return found


## A sign over the aisle that starts a section, facing you as you come down it, and a pole
## [constant REFERENCE_HEIGHT] high to judge sizes by.
func _section(title: String) -> void:
	var x := maxf(_left_x, _right_x) + SECTION_GAP
	var sign := Greybox.label(self, title, Vector3(x, 3.4, 0), -90.0, 128)
	sign.name = "Section%s" % title.to_pascal_case()
	var pole := Node3D.new()
	pole.name = "ReferencePole"
	add_child(pole)
	pole.position = Vector3(x, 0, -SIDE - 0.1)
	Greybox.box(pole, Vector3(0.05, REFERENCE_HEIGHT, 0.05), Vector3(0, REFERENCE_HEIGHT / 2, 0), Color(0.85, 0.2, 0.15), false)
	for h in [0.5, 1.0, 1.5]:
		Greybox.box(pole, Vector3(0.12, 0.01, 0.12), Vector3(0, h, 0), Color.WHITE, false)
	Greybox.label(pole, "%.1f m" % REFERENCE_HEIGHT, Vector3(0, REFERENCE_HEIGHT + 0.12, 0.05), 0.0, 40)
	AssetTag.cover(pole, "%.1f m" % REFERENCE_HEIGHT)
	_left_x = x + 0.6
	_right_x = x + 0.6


## Stands [param holder] (an asset facing +Z, its front towards the aisle) next in line on
## the left-hand (-Z) side of the aisle, or turned round on the right-hand side, with its
## asset name on a sign at its feet. It gets a slot as wide as itself or its sign.
func _place(holder: Node3D, left: bool) -> void:
	var box := AssetTag.bounds(holder)
	var sign := Greybox.label(self, holder.name, Vector3.ZERO, 0.0 if left else 180.0, SIGN_SIZE)
	sign.name = "Sign"
	var sign_width := ThemeDB.fallback_font.get_string_size(sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_SIZE).x * sign.pixel_size
	var slot := maxf(box.size.x, sign_width)
	var middle_x := (_left_x if left else _right_x) + slot / 2
	if left:
		holder.position = Vector3(middle_x - box.get_center().x, 0, -SIDE - box.end.z)
		sign.position = Vector3(middle_x, 0.12, -SIDE + 0.15)
		_left_x += slot + GAP
	else:
		holder.rotation_degrees.y = 180.0
		holder.position = Vector3(middle_x + box.get_center().x, 0, SIDE + box.end.z)
		sign.position = Vector3(middle_x, 0.12, SIDE - 0.15)
		_right_x += slot + GAP


## A holder named [param asset_name], added to the room.
func _holder(asset_name: String) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	holder.name = asset_name
	return holder


## A character at a guest's size, facing +Z. Pressing it plays its animations one by one,
## each named in its speech bubble.
func _character(path: String) -> Node3D:
	var asset_name := path.get_file().get_basename()
	var holder := _holder(asset_name)
	var guest := Guest.new()
	guest.setup(0, 0, path, "%d")
	guest.display_name = asset_name
	guest.rotation_degrees.y = 180.0 # a guest faces -Z
	holder.add_child(guest)
	var player := guest.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var animations := Array(player.get_animation_list()).filter(func(a: String) -> bool: return a != "RESET")
	var next := [0]
	guest.line = animations[0]
	guest.talked_to.connect(func() -> void:
		guest.act(animations[next[0]])
		next[0] = (next[0] + 1) % animations.size()
		guest.line = animations[next[0]])
	return holder


## A model from the asset folders: furniture at the size [Decor] puts it in the hotel, other
## models as they come.
func _model(path: String) -> Node3D:
	var asset_name := path.get_file().get_basename()
	var holder := _holder(asset_name)
	var model: Node3D
	if path.get_base_dir() + "/" == Decor.DIR:
		model = Decor.put(holder, asset_name, Vector3.ZERO)
	else:
		model = (load(path) as PackedScene).instantiate()
		holder.add_child(model)
	AssetTag.cover(model, asset_name)
	return holder


## One door panel, as in the cab and the landing doors, standing on the floor.
func _door_panel() -> Node3D:
	var holder := _holder("door panel")
	var panel := StaticBody3D.new()
	panel.position.y = Elevator.DOOR_HEIGHT / 2
	holder.add_child(panel)
	Interior.door_panel(panel, Elevator.PANEL_WIDTH, Elevator.DOOR_HEIGHT, Elevator.PANEL_THICKNESS)
	panel.set_meta(Player.NAME_META, "door panel")
	return holder


## A floor display on a post at eye height.
func _floor_display() -> Node3D:
	var holder := _holder("floor display")
	_post(holder, 1.5)
	var display := FloorDisplay.new()
	display.position = Vector3(0, 1.6, 0.03)
	holder.add_child(display)
	_press_to_change(display)
	return holder


## Names [param display] "floor display"; pressing it shows the next of
## [constant DISPLAY_STATES].
func _press_to_change(display: FloorDisplay) -> void:
	var state := [0]
	AssetTag.cover(display, "floor display", func() -> void:
		state[0] = (state[0] + 1) % DISPLAY_STATES.size()
		display.show_floor(DISPLAY_STATES[state[0]].x, DISPLAY_STATES[state[0]].y))


## A button on a steel plate on a post: [param round] like a call button, else
## like the cab's.
func _button(asset_name: String, caption: String, round: bool) -> Node3D:
	var holder := _holder(asset_name)
	_post(holder, 1.0)
	Greybox.box(holder, Vector3(0.16, 0.22, 0.012), Vector3(0, 1.1, 0.006), Color.WHITE, false, Interior.steel())
	var button := ElevatorButton.new()
	button.position = Vector3(0, 1.1, 0.02 if round else 0.032)
	button.rotation_degrees.y = -90.0 # its face (+X) towards the aisle (+Z)
	holder.add_child(button)
	button.setup(asset_name, asset_name, caption, round)
	return holder


## A round button on a post that plays [param stream], named [param asset_name].
func _sound(asset_name: String, stream: AudioStream) -> Node3D:
	var holder := _button(asset_name, "♪", true)
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	holder.add_child(sound)
	_sounds[asset_name] = sound
	(holder.find_children("*", "ElevatorButton", true, false)[0] as ElevatorButton).pressed.connect(
			func(_button: ElevatorButton) -> void: _play(asset_name))
	return holder


func _play(asset_name: String) -> void:
	played.append(asset_name)
	# The headless (Dummy) audio driver never finishes a sound, which leaks it at quit.
	if AudioServer.get_driver_name() != "Dummy":
		(_sounds[asset_name] as AudioStreamPlayer).play()


func _post(holder: Node3D, height: float) -> void:
	Greybox.box(holder, Vector3(0.06, height, 0.06), Vector3(0, height / 2, 0), Color(0.2, 0.2, 0.22), false)
	Greybox.box(holder, Vector3(0.3, 0.03, 0.3), Vector3(0, 0.015, 0), Color(0.2, 0.2, 0.22), false)


## A hallway of [param hotel] on the left-hand side of the aisle, built as the game builds
## it but open towards the aisle, with its shaft and a working elevator, every part named
## after the hotel.
func _sample_corner(hotel: Dictionary) -> void:
	var corner := Node3D.new()
	corner.name = "SampleCorner%s" % (hotel.id as String).to_pascal_case()
	add_child(corner)
	# Turned so the hallway (+Z in the hotel) runs back up the aisle (-X) and its open side
	# (+X in the hotel) faces the aisle (+Z).
	corner.rotation_degrees.y = -90.0
	var back := Elevator.CAB_HALF_WIDTH + 0.05 + Hallway.DEPTH
	corner.position = Vector3(_left_x + back, 0, -SIDE - Hallway.WIDTH / 2)
	Hallway.build_shaft(corner, 1)
	Hallway.build(corner, hotel, 0, true)
	var elevator := Elevator.new()
	elevator.name = "Elevator"
	elevator.floor_count = 1
	elevator.landing_z = Hallway.LANDING_Z
	elevator.music_level = Upgrades.max_level(Upgrades.MUSIC)
	elevator.call_panel_level = Upgrades.max_level(Upgrades.CALLS)
	corner.add_child(elevator)
	_name_corner(corner, elevator, hotel)
	_left_x += back + Elevator.CAB_HALF_WIDTH + 0.2 + SECTION_GAP
	_right_x = maxf(_right_x, _left_x)


## Names every part of a sample corner. What looks different in every hotel (the floor, the
## walls and their trim) is named after [param hotel] ("Pension Bellevue carpet floor");
## what is the same everywhere (the cab, the doors, the steel round them, the buttons and
## displays, the furniture) has the one name it has all over the Asset room.
func _name_corner(corner: Node3D, elevator: Elevator, hotel: Dictionary) -> void:
	var prefix: String = hotel.name
	var look := Interior.style(hotel.id)
	for body: CollisionObject3D in corner.find_children("*", "CollisionObject3D", false, false):
		if body.name.begins_with("Floor"):
			body.set_meta(Player.NAME_META, "%s %s floor" % [prefix, look.floor[0]])
		elif body.name.contains("Wall") or body.name.begins_with("Lintel"):
			body.set_meta(Player.NAME_META, "%s %s wall" % [prefix, look.wall[0]])
	var cab := elevator.get_cab()
	for mesh: MeshInstance3D in corner.find_children("*", "MeshInstance3D", true, false):
		if not mesh.has_meta(Interior.PART):
			continue
		var part: String = mesh.get_meta(Interior.PART)
		if cab.is_ancestor_of(mesh):
			part = "cab " + part
		elif not part in SAME_IN_EVERY_HOTEL:
			part = "%s %s" % [prefix, part]
		AssetTag.cover(mesh, part)
	var models: Array[Node] = corner.find_child("Furniture0", false, false).get_children()
	var music_box := corner.find_child("MusicBox", true, false)
	if music_box:
		models.append_array(music_box.get_children())
	models.append(corner.find_child("LampSquareCeiling", true, false))
	for holder: Node3D in models:
		if holder.get_child_count() > 0 and not holder is MeshInstance3D: # a model, not a shelf
			AssetTag.cover(holder, holder.name.to_camel_case().rstrip("0123456789"))
	cab.set_meta(Player.NAME_META, "cab %s wall" % Interior.CAB_WALL[0])
	for panel: Node3D in elevator.door_panels() + elevator.landing_doors(0):
		panel.set_meta(Player.NAME_META, "door panel")
	for button: ElevatorButton in corner.find_children("*", "ElevatorButton", true, false):
		match button.action:
			"open", "close":
				button.display_name = "cab %s button" % button.action
			_:
				button.display_name = "call button" if button.action.begins_with("call") else "floor button"
	for display in elevator.floor_displays():
		_press_to_change(display)


## The room round it all, [param length] long down the aisle: floor, walls, ceiling and
## lights. Its floor is a little below the hallways', so the two never flicker.
func _build_room(length: float) -> void:
	var z_min := -SIDE - Hallway.WIDTH - 1.0
	var z_max := SIDE + 3.0
	var width := z_max - z_min
	var middle := Vector3(length / 2 - 1.5, 0, (z_min + z_max) / 2)
	var wall := Color(0.55, 0.53, 0.5)
	Greybox.box(self, Vector3(length + 3.0, 0.2, width), Vector3(middle.x, -0.11, middle.z), Color(0.35, 0.34, 0.33))
	Greybox.box(self, Vector3(length + 3.0, 0.2, width), Vector3(middle.x, HEIGHT + 0.1, middle.z), wall)
	Greybox.box(self, Vector3(length + 3.0, HEIGHT, 0.2), Vector3(middle.x, HEIGHT / 2, z_min - 0.1), wall)
	Greybox.box(self, Vector3(length + 3.0, HEIGHT, 0.2), Vector3(middle.x, HEIGHT / 2, z_max + 0.1), wall)
	Greybox.box(self, Vector3(0.2, HEIGHT, width), Vector3(-1.6, HEIGHT / 2, middle.z), wall)
	Greybox.box(self, Vector3(0.2, HEIGHT, width), Vector3(length - 1.4 + 0.1, HEIGHT / 2, middle.z), wall)
	Greybox.label(self, "Asset room", Vector3(-1.45, 3.0, 0), 90.0, 160)
	var x := 0.0
	while x < length:
		var light := OmniLight3D.new()
		light.position = Vector3(x, HEIGHT - 0.3, 0)
		light.omni_range = 9.0
		add_child(light)
		x += 6.0


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 28)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(_crosshair)

	_looking_label = Label.new()
	_looking_label.name = "LookingAt"
	_looking_label.add_theme_font_size_override("font_size", 22)
	_looking_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_looking_label.position.y += 32
	_looking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_looking_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_looking_label)

	var help := Label.new()
	help.name = "Help"
	help.text = "Look at an asset to see its name · click (or E, or A) a character or a button to play it · Esc menu"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position += Vector2(16, -32)
	help.modulate = Color(1, 1, 1, 0.6)
	hud.add_child(help)

	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_debug_label.position += Vector2(16, 12)
	_debug_label.modulate = Color(1, 0.45, 0.3)
	_debug_label.text = DebugOptions.label()
	hud.add_child(_debug_label)

	_settings_menu = SettingsMenu.new()
	_settings_menu.name = "SettingsMenu"
	_settings_menu.settings = _settings
	_settings_menu.pause_requested.connect(_on_pause_requested)
	_settings_menu.changed.connect(_on_settings_changed)
	_settings_menu.closed.connect(_on_settings_closed)
	_settings_menu.asset_room_left.connect(_leave)
	hud.add_child(_settings_menu)


func _on_looking_at_changed(text: String) -> void:
	_looking_label.text = text
	_crosshair.modulate = Color(1, 0.8, 0.2) if text else Color.WHITE


func _on_pause_requested() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settings_menu.open(SettingsMenu.Where.ASSET_ROOM)


func _on_settings_changed() -> void:
	_player.look_sensitivity = _settings.look_sensitivity
	_debug_label.text = DebugOptions.label()


func _on_settings_closed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Back to the hotel: the staff room if you came from there, else a fresh start of the shift.
func _leave() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
