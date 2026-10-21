extends Control
## PROTOTYPE, throw away. Variant A, "Tabbed window": the classic PC game menu. The title
## screen is a column of buttons in the middle of the screen over the hotel; the pause menu a small panel
## in the middle; the settings a big window with a tab per section (Q/E or LB/RB switch
## tabs), a label and a control per row, and the focused option's help in the footer.

const BG := Color(0.12, 0.1, 0.08, 0.96)
const GOLD := Color(0.95, 0.75, 0.35)

var host: MenuPrototype
var options: MenuProtoOptions
var screen := "main"
var section := "video"

var _context: MenuPrototype.Context
var _help: Label
var _rows: ScrollContainer
var _tabs := {} ## section id -> Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()


func open(context: MenuPrototype.Context, at_screen: String, at_section: String) -> void:
	_context = context
	section = at_section
	_show(at_screen)


## Esc, B: one screen back. False when already on the main screen.
func back() -> bool:
	if screen == "main":
		return false
	_show("main")
	return true


func _show(which: String) -> void:
	screen = which
	for child in get_children():
		child.queue_free()
	_tabs.clear()
	match which:
		"main":
			if _context == MenuPrototype.Context.TITLE:
				_build_title()
			else:
				_build_pause()
		"settings":
			_build_settings()
		"credits":
			_build_credits()


func _build_title() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Elevator Piccolo"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Going up? Mind the doors."
	subtitle.modulate = Color(1, 1, 1, 0.7)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_spacer(40))
	var info := host.info()
	var first: Button
	if info.has_save:
		first = _button(box, "Continue", host.continue_game)
		var detail := Label.new()
		detail.text = "%s · shift %d · €%.2f" % [info.hotel, info.shift_number, info.balance]
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.modulate = Color(1, 1, 1, 0.6)
		detail.add_theme_font_size_override("font_size", 14)
		box.add_child(detail)
	var new_career := _button(box, "New career", host.new_career)
	if not first:
		first = new_career
	_button(box, "Settings", _show.bind("settings"))
	_button(box, "Credits", _show.bind("credits"))
	_button(box, "Quit", host.quit_game)
	var version := Label.new()
	version.text = "Demo · v0.1"
	version.modulate = Color(1, 1, 1, 0.4)
	version.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	version.grow_horizontal = Control.GROW_DIRECTION_BOTH
	version.position.y -= 70
	add_child(version)
	first.grab_focus.call_deferred()


func _build_pause() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := _window(Vector2(380, 0))
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := host.info()
	var status := Label.new()
	status.text = "%s · %s\n%.1f ★ · €%.2f · served %d" % [info.hotel, info.get("clock", ""), info.get("stars", 0.0), info.get("money", 0.0), info.get("served", 0)]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.modulate = Color(1, 1, 1, 0.7)
	box.add_child(status)
	box.add_child(HSeparator.new())
	var resume := _button(box, "Resume", host.continue_game)
	_button(box, "Settings", _show.bind("settings"))
	_button(box, "Quit to title", host.quit_to_title)
	_button(box, "Quit the game", host.quit_game)
	resume.grab_focus.call_deferred()


func _build_settings() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := _window(Vector2(880, 560))
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var hint := Label.new()
	hint.text = "Q / E  or  LB / RB  to switch tabs"
	hint.modulate = Color(1, 1, 1, 0.45)
	header.add_child(hint)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	box.add_child(tab_row)
	var group := ButtonGroup.new()
	for s in MenuProtoOptions.SECTIONS:
		var tab := Button.new()
		tab.text = "  %s  " % s.title
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.theme_type_variation = &"Tab"
		tab.pressed.connect(_select_tab.bind(s.id))
		tab_row.add_child(tab)
		_tabs[s.id] = tab
	box.add_child(HSeparator.new())

	_rows = ScrollContainer.new()
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_rows)

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.custom_minimum_size.y = 44
	_help.modulate = Color(1, 1, 1, 0.75)
	footer.add_child(_help)
	var reset := Button.new()
	reset.text = "Reset tab"
	reset.pressed.connect(func() -> void:
		options.reset(section)
		_select_tab(section))
	footer.add_child(reset)
	var done := Button.new()
	done.text = "Back"
	done.pressed.connect(_show.bind("main"))
	footer.add_child(done)
	_select_tab(section)


func _select_tab(id: String) -> void:
	section = id
	_tabs[id].button_pressed = true
	var scroll := _rows
	for child in scroll.get_children():
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var first: Control
	for s in MenuProtoOptions.SECTIONS:
		if s.id != id:
			continue
		for option in s.options:
			var label := Label.new()
			label.text = "" if option.kind == "button" else option.label
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if option.get("stub", false):
				label.text += "  ·"
				label.tooltip_text = "Prototype: not wired yet"
			grid.add_child(label)
			var widget := options.make_widget(option, _on_focus)
			widget.custom_minimum_size.x = 320
			grid.add_child(widget)
			if not first:
				first = widget
	var focusable := first.get_child(0) if first is HBoxContainer else first
	(focusable as Control).grab_focus.call_deferred()


func _on_focus(option: Dictionary) -> void:
	_help.text = MenuProtoOptions.help(option)


func _build_credits() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := _window(Vector2(620, 0))
	var title := Label.new()
	title.text = "Credits"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	for line in MenuPrototype.CREDITS:
		var head := Label.new()
		head.text = line[0]
		head.add_theme_color_override("font_color", GOLD)
		box.add_child(head)
		var body := Label.new()
		body.text = line[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
	var done := _button(box, "Back", _show.bind("main"))
	done.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if screen != "settings":
		return
	var by := 0
	if event is InputEventKey and event.pressed and not event.echo:
		by = -1 if event.keycode == KEY_Q else (1 if event.keycode == KEY_E else 0)
	elif event is InputEventJoypadButton and event.pressed:
		by = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	if by != 0:
		var ids := MenuProtoOptions.SECTIONS.map(func(s: Dictionary) -> String: return s.id)
		_select_tab(ids[posmod(ids.find(section) + by, ids.size())])
		get_viewport().set_input_as_handled()


## A centred panel of [param min_size], returning the column to fill.
func _window(min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(280, 40)
	button.pressed.connect(on_press)
	button.mouse_entered.connect(button.grab_focus)
	parent.add_child(button)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(28)
	panel.set_border_width_all(1)
	panel.border_color = Color(1, 1, 1, 0.08)
	t.set_stylebox("panel", "PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	normal.content_margin_left = 16
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12)
	var focus := normal.duplicate()
	focus.bg_color = Color(GOLD, 0.25)
	focus.set_border_width_all(2)
	focus.border_color = GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(GOLD, 0.45)
	for type in ["Button"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("pressed", type, pressed)
	t.set_type_variation(&"Tab", &"Button")
	var tab := normal.duplicate()
	tab.bg_color = Color(1, 1, 1, 0.04)
	tab.corner_radius_bottom_left = 0
	tab.corner_radius_bottom_right = 0
	var tab_on := tab.duplicate()
	tab_on.bg_color = Color(GOLD, 0.35)
	tab_on.border_width_bottom = 3
	tab_on.border_color = GOLD
	t.set_stylebox("normal", &"Tab", tab)
	t.set_stylebox("pressed", &"Tab", tab_on)
	t.set_stylebox("hover_pressed", &"Tab", tab_on)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	return t
