class_name SettingsMenu
extends PanelContainer
## The settings panel: sliders for the volume and the look sensitivity, saved as soon as
## they move. During a shift Esc (or Start) opens it as the pause menu, and Esc, Start, B or
## Resume closes it again; the staff room opens it with its Settings button, and so does
## Esc in the Asset room. In debug builds it has a Debug section with the [DebugOptions],
## End shift now and the way into (or out of) the Asset room; in the Asset room it also has
## a slider for [member AssetRoom.walk_speed].

## Where the menu is opened from.
enum Where { SHIFT, STAFF_ROOM, ASSET_ROOM }

## Esc or Start was pressed during a shift while the menu was closed.
signal pause_requested
signal closed
signal changed
## End shift now was pressed: the menu has closed, and the shift should end as it stands.
signal end_shift_requested
## The Asset room button was pressed.
signal asset_room_requested
## Leave the Asset room was pressed.
signal asset_room_left

var settings: Settings

var _title: Label
var _volume: HSlider
var _volume_label: Label
var _sensitivity: HSlider
var _sensitivity_label: Label
var _close: Button
var _speed: Button
var _end_shift: Button
var _asset_room: Button
var _leave_asset_room: Button
var _walk_speed: HSlider
var _walk_speed_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the game is paused
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_volume_label = Label.new()
	box.add_child(_volume_label)
	_volume = _slider("Volume", 0.0, 1.0, 0.05)
	_volume.value_changed.connect(_on_volume_changed)
	box.add_child(_volume)

	_sensitivity_label = Label.new()
	box.add_child(_sensitivity_label)
	_sensitivity = _slider("LookSensitivity", Settings.MIN_SENSITIVITY, Settings.MAX_SENSITIVITY, 0.05)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	box.add_child(_sensitivity)

	_close = Button.new()
	_close.name = "Close"
	_close.pressed.connect(close)
	box.add_child(_close)

	var quit := Button.new()
	quit.name = "Quit"
	quit.text = "Quit the game"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	if DebugOptions.available:
		box.add_child(_build_debug())
	hide()


## The Debug section: the [DebugOptions] switches and the game speed.
func _build_debug() -> Control:
	var debug := VBoxContainer.new()
	debug.name = "Debug"
	debug.add_theme_constant_override("separation", 8)
	debug.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "Debug"
	title.add_theme_font_size_override("font_size", 20)
	debug.add_child(title)
	debug.add_child(_switch("InfiniteMoney", "Infinite money", DebugOptions.infinite_money,
			func(on: bool) -> void: DebugOptions.infinite_money = on))
	debug.add_child(_switch("SkipHotelRequirements", "Skip hotel requirements", DebugOptions.skip_hotel_requirements,
			func(on: bool) -> void: DebugOptions.skip_hotel_requirements = on))
	_speed = Button.new()
	_speed.name = "GameSpeed"
	_speed.pressed.connect(func() -> void:
		DebugOptions.speed = DebugOptions.next_speed()
		_debug_changed())
	debug.add_child(_speed)
	_update_speed()
	_end_shift = Button.new()
	_end_shift.name = "EndShiftNow"
	_end_shift.text = "End shift now"
	_end_shift.pressed.connect(func() -> void:
		close()
		end_shift_requested.emit())
	debug.add_child(_end_shift)
	_asset_room = Button.new()
	_asset_room.name = "AssetRoom"
	_asset_room.text = "Asset room"
	_asset_room.pressed.connect(asset_room_requested.emit)
	debug.add_child(_asset_room)
	_walk_speed_label = Label.new()
	debug.add_child(_walk_speed_label)
	_walk_speed = _slider("WalkSpeed", 1.0, AssetRoom.MAX_WALK_SPEED, 0.5)
	_walk_speed.value_changed.connect(func(value: float) -> void:
		AssetRoom.walk_speed = value
		_update_walk_speed()
		changed.emit())
	debug.add_child(_walk_speed)
	_leave_asset_room = Button.new()
	_leave_asset_room.name = "LeaveAssetRoom"
	_leave_asset_room.text = "Leave the Asset room"
	_leave_asset_room.pressed.connect(asset_room_left.emit)
	debug.add_child(_leave_asset_room)
	return debug


func _switch(switch_name: String, text: String, on: bool, set_option: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.name = switch_name
	button.text = text
	button.button_pressed = on
	button.toggled.connect(func(pressed: bool) -> void:
		set_option.call(pressed)
		_debug_changed())
	return button


func _debug_changed() -> void:
	_update_speed()
	changed.emit()


func _update_speed() -> void:
	_speed.text = "Game speed: ×%d" % DebugOptions.speed


func _update_walk_speed() -> void:
	_walk_speed_label.text = "Walk speed: ×%s" % String.num(AssetRoom.walk_speed, 1)


func _slider(slider_name: String, from: float, to: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = from
	slider.max_value = to
	slider.step = step
	return slider


func _unhandled_input(event: InputEvent) -> void:
	var pause := event.is_action_pressed("pause")
	if visible and (pause or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
	elif pause and not visible and not get_tree().paused:
		pause_requested.emit()
		get_viewport().set_input_as_handled()


## Opens the menu: as the pause menu during a shift, from the staff room, or in the
## Asset room.
func open(where: Where) -> void:
	_title.text = ["Paused", "Settings", "Asset room"][where]
	_close.text = "Resume" if where == Where.SHIFT else "Back"
	_volume.set_value_no_signal(settings.volume)
	_sensitivity.set_value_no_signal(settings.look_sensitivity)
	_update_labels()
	if _end_shift:
		_end_shift.visible = where == Where.SHIFT
		_asset_room.visible = where != Where.ASSET_ROOM
		_leave_asset_room.visible = where == Where.ASSET_ROOM
		_walk_speed.visible = where == Where.ASSET_ROOM
		_walk_speed_label.visible = where == Where.ASSET_ROOM
		_walk_speed.set_value_no_signal(AssetRoom.walk_speed)
		_update_walk_speed()
	show()
	_close.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _on_volume_changed(value: float) -> void:
	settings.volume = value
	settings.apply_volume()
	_saved()


func _on_sensitivity_changed(value: float) -> void:
	settings.look_sensitivity = value
	_saved()


func _saved() -> void:
	_update_labels()
	var error := settings.save()
	if error != OK:
		push_error("Couldn't save the settings to %s: %s" % [Settings.save_path, error_string(error)])
	changed.emit()


func _update_labels() -> void:
	_volume_label.text = "Volume: %d%%" % roundi(settings.volume * 100)
	_sensitivity_label.text = "Look sensitivity: ×%.2f" % settings.look_sensitivity
