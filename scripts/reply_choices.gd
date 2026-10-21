class_name ReplyChoices
extends PanelContainer
## The replies you can give a chatty guest, low in the HUD, in the order of their
## [member Guest.offers], with a bar for the time you have left (none without a time limit). What they said is in their
## own speech bubble. One reply is highlighted: W/S, the mouse wheel, the D-pad or the left
## stick move the highlight, and a click, E or A says it; 1-3 say one straight away. The
## mouse stays captured, so the view doesn't wander off the guest.

signal chosen(i: int) ## the index of the reply in the guest's offers

const MARK := "▶" ## in front of the highlighted reply
const COLOUR := Color(1, 1, 1, 0.75)
const HIGHLIGHT := Color(1, 0.8, 0.3)
const STICK_TILT := 0.5 ## how far the left stick goes before it moves the highlight

## Which reply is highlighted, from 0 at the top.
var highlighted := 0
## Seconds you have to answer, as [member GuestManager.reply_time]; 0 for no limit.
var time_limit := GuestManager.REPLY_TIME

var _lines: Array[Label] = []
var _texts: Array[String] = []
var _bar: ProgressBar
var _hint: Label
var _time_left := 0.0
var _stick := 0 ## which way the left stick leans: -1 up, 1 down, 0 neither


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_bottom = -100
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	for i in Guest.Reply.size():
		var line := Label.new()
		line.name = "Reply%d" % (i + 1)
		line.add_theme_font_size_override("font_size", 20)
		box.add_child(line)
		_lines.append(line)

	_bar = ProgressBar.new()
	_bar.name = "TimeLeft"
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = HIGHLIGHT
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	_hint = Label.new()
	_hint.text = "W/S, wheel or D-pad to choose · click, E or A to say it · 1-3"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_hint)
	hide()


func show_for(guest: Guest) -> void:
	_texts.clear()
	for offer in guest.offers:
		_texts.append(offer.text)
	for i in _lines.size():
		_lines[i].visible = i < _texts.size()
	highlighted = 0
	_time_left = time_limit
	_bar.max_value = time_limit
	_bar.visible = time_limit > 0.0
	_update()
	show()


func close() -> void:
	hide()


## Seconds left to answer, as the bar shows them.
func time_left() -> float:
	return _time_left


func _process(delta: float) -> void:
	if visible and time_limit > 0.0:
		_time_left = maxf(_time_left - delta, 0.0)
		_bar.value = _time_left


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	var pick := -1
	if event is InputEventJoypadMotion:
		if event.axis != JOY_AXIS_LEFT_Y:
			return
		# One step per tilt, however many motion events a held stick sends.
		var lean := 0 if absf(event.axis_value) < STICK_TILT else int(signf(event.axis_value))
		if lean != 0 and lean != _stick:
			_move(lean)
		_stick = lean
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_move(1)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_move(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_move(1)
			MOUSE_BUTTON_LEFT:
				pick = highlighted
			_:
				return
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		pick = highlighted
	elif event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 \
			and event.physical_keycode < KEY_1 + _texts.size():
		pick = event.physical_keycode - KEY_1
	else:
		return
	get_viewport().set_input_as_handled()
	if pick >= 0:
		chosen.emit(pick)


func _move(by: int) -> void:
	highlighted = clampi(highlighted + by, 0, _texts.size() - 1)
	_update()


func _update() -> void:
	for i in _texts.size():
		var mark := MARK if i == highlighted else " "
		_lines[i].text = '%s %d   "%s"' % [mark, i + 1, _texts[i]]
		_lines[i].modulate = HIGHLIGHT if i == highlighted else COLOUR
