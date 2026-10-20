class_name ReplyChoices
extends PanelContainer
## A guest's greeting and the replies you can give, low in the HUD. Pick one with the
## number keys or by clicking it. While it shows, the mouse is free to click with.

signal chosen(reply: Guest.Reply)

var _greeting: Label
var _buttons: Array[Button] = []
var _freed_mouse := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_bottom = -100
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_greeting = Label.new()
	_greeting.add_theme_font_size_override("font_size", 22)
	box.add_child(_greeting)

	for r: Guest.Reply in Guest.Reply.values():
		var button := Button.new()
		button.name = "Reply%d" % (r + 1)
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE # keys pick by number, not by focus
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(chosen.emit.bind(r))
		box.add_child(button)
		_buttons.append(button)
	hide()


func show_for(guest: Guest) -> void:
	_greeting.text = 'Guest: "%s"' % guest.greeting.line
	for r in _buttons.size():
		_buttons[r].text = '%d   "%s"' % [r + 1, guest.reply_line(r)]
	show()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_freed_mouse = true


func close() -> void:
	hide()
	if _freed_mouse and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_freed_mouse = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var r: int = event.physical_keycode - KEY_1
	if r >= 0 and r < _buttons.size():
		get_viewport().set_input_as_handled()
		chosen.emit(r)
