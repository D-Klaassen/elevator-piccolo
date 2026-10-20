class_name EndScreen
extends PanelContainer
## The end of the demo: the Grand Hotel takes your application, "to be continued", and how
## far you got. You can go back to the staff room and keep working at the last hotel, or
## quit.

signal back

var _title: Label
var _lines: Label
var _stats: Label
var _keep_playing: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the game is paused
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560, 0)
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
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lines)

	box.add_child(HSeparator.new())

	_stats = Label.new()
	_stats.modulate = Color(1, 1, 1, 0.7)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)

	_keep_playing = Button.new()
	_keep_playing.name = "KeepPlaying"
	_keep_playing.pressed.connect(back.emit)
	box.add_child(_keep_playing)

	var quit := Button.new()
	quit.name = "Quit"
	quit.text = "Quit the game"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	hide()


func show_for(career: Career) -> void:
	var grand := Hotels.DEMO_END
	_title.text = "To be continued: %s" % grand.name
	_lines.text = "\n".join([
		"The %s has read your application" % grand.name,
		"and wants you in its lift.",
		"%d floors, and guests who speak %s." % [grand.floors, grand.language],
		"",
		"This is where the demo ends. Thanks for playing!",
	])
	_stats.text = "\n".join([
		"Bank balance: €%.2f" % career.balance,
		"Spanish lessons: %d of %d" % [career.level(Upgrades.SPANISH), Upgrades.max_level(Upgrades.SPANISH)],
		"Music: level %d of %d" % [career.level(Upgrades.MUSIC), Upgrades.max_level(Upgrades.MUSIC)],
	])
	_keep_playing.text = "Keep working at %s" % career.hotel_info().name
	show()
	_keep_playing.grab_focus()
