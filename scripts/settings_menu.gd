class_name SettingsMenu
extends PanelContainer
## The settings panel: sliders for the volume and the look sensitivity, saved as soon as
## they move. During a shift Esc (or Start) opens it as the pause menu, and Esc, Start, B or
## Resume closes it again; the staff room opens it with its Settings button.

## Esc or Start was pressed during a shift while the menu was closed.
signal pause_requested
signal closed
signal changed

var settings: Settings

var _title: Label
var _volume: HSlider
var _volume_label: Label
var _sensitivity: HSlider
var _sensitivity_label: Label
var _close: Button


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
	hide()


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


## Opens the menu: as the pause menu during a shift ([param paused_shift]), or from the
## staff room.
func open(paused_shift: bool) -> void:
	_title.text = "Paused" if paused_shift else "Settings"
	_close.text = "Resume" if paused_shift else "Back"
	_volume.set_value_no_signal(settings.volume)
	_sensitivity.set_value_no_signal(settings.look_sensitivity)
	_update_labels()
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
