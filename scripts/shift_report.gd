class_name ShiftReport
extends PanelContainer
## The end-of-shift screen: how the day went, the bank balance and the recent ratings,
## and a button to go on to the next shift (or, when you were fired, to try this one again).

signal continued

var _title: Label
var _lines: Label
var _button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the game is paused
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(360, 0)
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

	_lines = Label.new()
	_lines.add_theme_font_size_override("font_size", 20)
	box.add_child(_lines)

	_button = Button.new()
	_button.name = "Continue"
	_button.pressed.connect(continued.emit)
	box.add_child(_button)
	hide()


## Shows how [param shift] went; [param career] already has it recorded.
func show_for(shift: Shift, career: Career) -> void:
	_title.text = "You're fired!" if shift.is_fired() else "Shift %d over" % career.shifts_done
	_lines.text = "\n".join([
		"Guests served: %d" % shift.served,
		"Guests who took the stairs: %d" % shift.lost,
		"Complaints about your replies: %d" % shift.reply_complaints,
		"",
		"Fares: €%.2f" % shift.fares,
		"Tips: €%.2f" % shift.tips,
		"Wage: €%.2f" % shift.wage,
		"Total: €%.2f" % shift.money(),
		"",
		"Hotel rating: %.1f ★   %s: %.1f ★" % [shift.stars, _average_label(career), career.average_rating()],
		"Bank balance: €%.2f" % career.balance,
	])
	_button.text = "Play the shift again" if shift.is_fired() else "Next shift"
	show()
	_button.grab_focus()


func _average_label(career: Career) -> String:
	if career.ratings.size() < Career.AVERAGE_OVER:
		return "average so far"
	return "last %d shifts" % Career.AVERAGE_OVER
