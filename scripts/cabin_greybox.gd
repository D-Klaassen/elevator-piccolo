extends Node3D
## The hotel you work in (the rustic cabin, then Pension Bellevue and up), built from boxes
## by [Hallway] and dressed in its own style ([Interior]): a shaft with a hallway on every
## floor, the elevator cab, the player standing inside it, the guests, the shift and a
## minimal HUD.
## Every shift loads the saved career, fits the cab with the upgrades bought, and saves the
## career again once the shift is over. Between shifts you go through the staff room.
## Esc pauses the shift and opens the settings.

var _hint_label: Label
var _help_label: Label
var _crosshair: Label
var _looking_label: Label
var _clock_label: Label
var _stats_label: Label
var _debug_label: Label
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
## PROTOTYPE: the menu prototype, when the game was started with --menu-prototype.
var _menu_prototype: MenuPrototype
## True from the end of the shift (or a return from the Asset room to the staff room) until
## the next shift starts.
var _between_shifts := false


func _ready() -> void:
	if Benchmark.requested() and not Benchmark.active:
		Benchmark.begin(self) # sets up its own career and loads the scene again
		return
	_career = Career.load_saved()
	_settings = Settings.load_saved()
	_settings.apply_volume()
	_settings.apply_anti_aliasing(get_viewport())
	var hotel := _career.hotel_info()
	_floors = hotel.floors
	Hallway.build_environment(self)
	Hallway.build_shaft(self, _floors)
	for f in _floors:
		Hallway.build(self, hotel, f)

	var elevator := Elevator.new()
	elevator.name = "Elevator"
	elevator.floor_count = _floors
	elevator.door_time = Upgrades.DOOR_TIME[_career.level(Upgrades.DOORS)]
	elevator.music_level = _career.level(Upgrades.MUSIC)
	elevator.capacity = Upgrades.CAPACITY[_career.level(Upgrades.CAB)]
	elevator.call_panel_level = _career.level(Upgrades.CALLS)
	elevator.landing_z = Hallway.LANDING_Z
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
	guests.chatting.connect(_on_chatting)
	guests.reply_closed.connect(_on_chat_over)
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
	if Benchmark.active:
		add_child(Benchmark.new())
	if AssetRoom.back_to_staff_room:
		AssetRoom.back_to_staff_room = false
		_take_a_break()
		_staff_room.show_for(_career)
	elif MenuPrototype.requested():
		_menu_prototype = MenuPrototype.install(self)


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

	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_debug_label.position += Vector2(16, 12)
	_debug_label.modulate = Color(1, 0.45, 0.3)
	_debug_label.text = DebugOptions.label()
	hud.add_child(_debug_label)

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
	_settings_menu.end_shift_requested.connect(_shift.end_now)
	_settings_menu.asset_room_requested.connect(func() -> void: AssetRoom.enter(get_tree(), _between_shifts))
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


## A guest strikes up a chat: you stand still facing them, and pick a reply.
func _on_chatting(guest: Guest) -> void:
	_player.focus_on(guest)
	if guest.state == Guest.State.WAITING or guest.state == Guest.State.RIDING:
		guest.face(_player.global_position)
	_replies.show_for(guest)


func _on_chat_over() -> void:
	_replies.close()
	_player.release()


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
	_take_a_break()
	_career.record(_shift)
	_save_career()
	_report.show_for(_shift, _career)


## Stops the hotel between shifts, for the report and the staff room.
func _take_a_break() -> void:
	_between_shifts = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.hide()
	_looking_label.text = ""
	_hint_label.text = ""


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
	if _menu_prototype:
		_menu_prototype.open(MenuPrototype.Context.PAUSE)
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settings_menu.open(SettingsMenu.Where.SHIFT)


func _on_staff_room_settings() -> void:
	_staff_room.hide()
	_settings_menu.open(SettingsMenu.Where.STAFF_ROOM)


func _on_settings_changed() -> void:
	_player.look_sensitivity = _settings.look_sensitivity
	_debug_label.text = DebugOptions.label()


## Back to the staff room if it opened the menu, otherwise back to the shift.
func _on_settings_closed() -> void:
	if _between_shifts:
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
