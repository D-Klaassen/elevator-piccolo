extends Node3D
## Greybox of the hotel you work in (the rustic cabin, then Pension Bellevue and up): a shaft
## with a hallway on every floor, the elevator cab, the player standing inside it, the
## guests, the shift and a minimal HUD.
## Every shift loads the saved career, fits the cab with the upgrades bought, and saves the
## career again once the shift is over. Between shifts you go through the staff room.
## Esc pauses the shift and opens the settings.

const HALL_WIDTH := 6.0
const HALL_DEPTH := 4.0
const SHAFT_FRONT := 1.1 ## z where the landing wall starts, just in front of the cab

var _hint_label: Label
var _help_label: Label
var _crosshair: Label
var _looking_label: Label
var _clock_label: Label
var _stats_label: Label
var _report: ShiftReport
var _staff_room: StaffRoom
var _end_screen: EndScreen
var _settings_menu: SettingsMenu
var _settings: Settings
var _player: Player
var _replies: ReplyChoices
var _hint_timer: SceneTreeTimer
var _shift: Shift
var _career: Career
var _floors: int


func _ready() -> void:
	_career = Career.load_saved()
	_settings = Settings.load_saved()
	_settings.apply_volume()
	var hotel := _career.hotel_info()
	_floors = hotel.floors
	_build_environment()
	_build_shaft()
	for f in _floors:
		_build_landing(f)

	var elevator := Elevator.new()
	elevator.name = "Elevator"
	elevator.floor_count = _floors
	elevator.door_time = Upgrades.DOOR_TIME[_career.level(Upgrades.DOORS)]
	elevator.music_level = _career.level(Upgrades.MUSIC)
	elevator.capacity = Upgrades.CAPACITY[_career.level(Upgrades.CAB)]
	elevator.call_panel_level = _career.level(Upgrades.CALLS)
	add_child(elevator)

	var guests := GuestManager.new()
	guests.name = "Guests"
	guests.elevator = elevator
	guests.capacity = elevator.capacity
	guests.spanish_share = hotel.spanish
	guests.spanish_lessons = _career.level(Upgrades.SPANISH)
	guests.ride_patience_scale = Upgrades.RIDE_PATIENCE[elevator.music_level] * hotel.ride_patience
	add_child(guests)

	_shift = Shift.new()
	_shift.name = "Shift"
	_shift.guests = guests
	_shift.hotel = hotel
	add_child(_shift)

	var player := Player.new()
	player.name = "Player"
	player.position = Vector3(0, 0.05, -0.3)
	player.rotation_degrees.y = 180.0 # face the doors (+Z)
	player.look_sensitivity = _settings.look_sensitivity
	add_child(player)
	_player = player

	_build_hud()
	elevator.hint.connect(_show_hint)
	guests.said.connect(_show_hint)
	guests.chatting.connect(_replies.show_for)
	guests.reply_closed.connect(_replies.close)
	_replies.chosen.connect(guests.reply)
	_shift.announced.connect(_show_hint)
	_shift.clock_changed.connect(_on_clock_changed)
	_shift.stats_changed.connect(_on_stats_changed)
	_shift.ended.connect(_on_shift_ended)
	player.looking_at_changed.connect(_on_looking_at_changed)
	_on_clock_changed(Shift.START)
	_on_stats_changed()
	if elevator.call_panel_level > 0:
		_show_hint("Your shift starts. Guests call from the hallways: watch the Calls lamps on your right.")
	else:
		_show_hint("Your shift starts. A ding means a guest is calling: find out on which floor.")


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.07, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.4)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_shaft() -> void:
	var color := Color(0.25, 0.25, 0.27)
	var height := _floors * Elevator.FLOOR_HEIGHT + 1.0
	var center_y := height / 2 - 1.0
	var outer := Elevator.CAB_HALF_WIDTH + 0.15
	# Pit floor, back and side walls around the cab.
	Greybox.box(self, Vector3(2 * outer, 0.2, 2 * outer), Vector3(0, -1.1, 0), color)
	Greybox.box(self, Vector3(2 * outer, height, 0.1), Vector3(0, center_y, -outer), color)
	Greybox.box(self, Vector3(0.1, height, 2 * outer), Vector3(-outer, center_y, 0), color)
	Greybox.box(self, Vector3(0.1, height, 2 * outer), Vector3(outer, center_y, 0), color)


func _build_landing(f: int) -> void:
	var y := f * Elevator.FLOOR_HEIGHT
	var floor_color := Color(0.45, 0.35, 0.25) if f % 2 == 0 else Color(0.35, 0.4, 0.3)
	var wall_color := Color(0.75, 0.7, 0.6)
	var wall_h := Elevator.FLOOR_HEIGHT - 0.2
	var front := Elevator.CAB_HALF_WIDTH + 0.05
	var back := front + HALL_DEPTH

	# Hallway floor; it also acts as the ceiling of the hallway below.
	Greybox.box(self, Vector3(HALL_WIDTH, 0.2, HALL_DEPTH), Vector3(0, y - 0.1, front + HALL_DEPTH / 2), floor_color)

	# Landing wall facing the hallway, with an opening in front of the cab door.
	var half := HALL_WIDTH / 2
	var opening := Elevator.DOOR_OPENING / 2
	var side := half - opening
	var wall_z := SHAFT_FRONT + 0.05
	Greybox.box(self, Vector3(side, wall_h, 0.1), Vector3(-(opening + side / 2), y + wall_h / 2, wall_z), wall_color)
	Greybox.box(self, Vector3(side, wall_h, 0.1), Vector3(opening + side / 2, y + wall_h / 2, wall_z), wall_color)
	var lintel_h := wall_h - Elevator.DOOR_HEIGHT
	Greybox.box(self, Vector3(Elevator.DOOR_OPENING, lintel_h, 0.1), Vector3(0, y + Elevator.DOOR_HEIGHT + lintel_h / 2, wall_z), wall_color)

	# Hallway side and back walls.
	Greybox.box(self, Vector3(0.1, wall_h, HALL_DEPTH), Vector3(-half, y + wall_h / 2, front + HALL_DEPTH / 2), wall_color)
	Greybox.box(self, Vector3(0.1, wall_h, HALL_DEPTH), Vector3(half, y + wall_h / 2, front + HALL_DEPTH / 2), wall_color)
	Greybox.box(self, Vector3(HALL_WIDTH, wall_h, 0.1), Vector3(0, y + wall_h / 2, back), wall_color)

	# Floor sign on the back wall, facing the elevator (-Z).
	var places: Array = _career.hotel_info().places
	var sign_text := "Floor %d" % f if places.is_empty() else "Floor %d · %s" % [f, places[f]]
	var sign_label := Greybox.label(self, sign_text, Vector3(0, y + 2.0, back - 0.06), 180.0, 96 if places.is_empty() else 72)
	sign_label.modulate = Color(0.2, 0.15, 0.1)

	var furniture := Node3D.new()
	furniture.name = "Furniture%d" % f
	add_child(furniture)
	Decor.furnish(furniture, "" if places.is_empty() else places[f], y)

	var light := OmniLight3D.new()
	light.position = Vector3(0, y + wall_h - 0.4, front + HALL_DEPTH / 2)
	light.omni_range = 5.0
	add_child(light)


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
	_looking_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_looking_label.position.y += 32
	_looking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_looking_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_looking_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position.y -= 60
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_hint_label)

	_help_label = Label.new()
	_help_label.name = "Help"
	_help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help_label.position += Vector2(16, -32)
	_help_label.modulate = Color(1, 1, 1, 0.6)
	hud.add_child(_help_label)
	_update_help()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 28)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock_label.position.y += 8
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_clock_label)

	_stats_label = Label.new()
	_stats_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_stats_label.position += Vector2(-16, 12)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(_stats_label)

	_replies = ReplyChoices.new()
	_replies.name = "ReplyChoices"
	hud.add_child(_replies)

	_report = ShiftReport.new()
	_report.name = "ShiftReport"
	_report.continued.connect(_on_continued)
	hud.add_child(_report)

	_staff_room = StaffRoom.new()
	_staff_room.name = "StaffRoom"
	_staff_room.bought.connect(_on_bought)
	_staff_room.moved.connect(_save_career)
	_staff_room.started.connect(_on_started)
	_staff_room.finished.connect(_on_demo_finished)
	hud.add_child(_staff_room)

	_end_screen = EndScreen.new()
	_end_screen.name = "EndScreen"
	_end_screen.back.connect(_on_continued)
	hud.add_child(_end_screen)

	_settings_menu = SettingsMenu.new()
	_settings_menu.name = "SettingsMenu"
	_settings_menu.settings = _settings
	_settings_menu.pause_requested.connect(_on_pause_requested)
	_settings_menu.changed.connect(_on_settings_changed)
	_settings_menu.closed.connect(_on_settings_closed)
	_staff_room.settings_opened.connect(_on_staff_room_settings)
	hud.add_child(_settings_menu)


## The controls in the corner: for the controller while one is connected.
func _update_help() -> void:
	if Input.get_connected_joypads().is_empty():
		_help_label.text = "WASD walk · mouse look · click (or E) a button or a guest · Esc pause"
	else:
		_help_label.text = "Left stick walk · right stick look · A a button or a guest · Start pause"


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_help()


func _on_looking_at_changed(text: String) -> void:
	_looking_label.text = text
	_crosshair.modulate = Color(1, 0.8, 0.2) if text else Color.WHITE


func _on_clock_changed(minutes: int) -> void:
	_clock_label.text = "%s   %s" % [_shift.hotel.name, Shift.format_clock(minutes)]
	if _shift.is_lunch_rush():
		_clock_label.text += "  lunch rush"


func _on_stats_changed() -> void:
	_stats_label.text = "€%.2f   %.1f ★\nserved %d · took the stairs %d" % [_shift.money(), _shift.stars, _shift.served, _shift.lost]


func _on_shift_ended() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.hide()
	_looking_label.text = ""
	_hint_label.text = ""
	_career.record(_shift)
	_save_career()
	_report.show_for(_shift, _career)


func _on_continued() -> void:
	_report.hide()
	_end_screen.hide()
	_staff_room.show_for(_career)


func _on_demo_finished() -> void:
	_staff_room.hide()
	_end_screen.show_for(_career)


func _on_bought(_id: String) -> void:
	_save_career()


## The next shift, or the same one again after being fired: either way a fresh scene
## that picks the career, upgrades included, up from the save.
func _on_started() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_pause_requested() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settings_menu.open(true)


func _on_staff_room_settings() -> void:
	_staff_room.hide()
	_settings_menu.open(false)


func _on_settings_changed() -> void:
	_player.look_sensitivity = _settings.look_sensitivity


## Back to the staff room if it opened the menu, otherwise back to the shift.
func _on_settings_closed() -> void:
	if _shift.is_over:
		_staff_room.show_for(_career)
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save_career() -> void:
	var error := _career.save()
	if error != OK:
		push_error("Couldn't save the career to %s: %s" % [Career.save_path, error_string(error)])


func _show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_timer = get_tree().create_timer(3.0)
	var timer := _hint_timer
	await timer.timeout
	# Only clear if no newer hint replaced this one.
	if timer == _hint_timer:
		_hint_label.text = ""
