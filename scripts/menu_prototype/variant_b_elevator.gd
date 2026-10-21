extends Control
## PROTOTYPE, throw away. Variant B, "Elevator panel": the menu is the game's own world. A
## brass button panel stands on the right, with a green floor display on top and a round
## button per choice that lights up like the cab's buttons. What a button opens shows on a
## cream hotel-brochure card beside it. In the settings each section is a floor: moving up
## and down the panel turns the card's page, ← steps onto the card, B or Esc steps back.

const BRASS := Color(0.71, 0.55, 0.27)
const BRASS_DARK := Color(0.42, 0.31, 0.13)
const CREAM := Color(0.96, 0.93, 0.85)
const INK := Color(0.24, 0.16, 0.1)
const LIT := Color(1.0, 0.86, 0.35)
const DISPLAY_GREEN := Color(0.35, 1.0, 0.45)

var host: MenuPrototype
var options: MenuProtoOptions
var screen := "main"
var section := "video"

var _context: MenuPrototype.Context
var _display: Label
var _buttons: VBoxContainer
var _card: PanelContainer
var _card_box: VBoxContainer
var _help: Label
var _rows: VBoxContainer
var _floor_buttons := {} ## section id -> Button
var _serif: SystemFont
var _mono: SystemFont


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	_mono.font_weight = 700


func open(context: MenuPrototype.Context, at_screen: String, at_section: String) -> void:
	_context = context
	section = at_section
	_show(at_screen)


func back() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if screen == "settings" and focus and _card.is_ancestor_of(focus):
		_floor_buttons[section].grab_focus()
		return true
	if screen == "main":
		return false
	_show("main")
	return true


func _show(which: String) -> void:
	screen = which
	for child in get_children():
		child.queue_free()
	_floor_buttons.clear()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_build_card()
	_build_panel()
	var first: Button
	match which:
		"main":
			if _context == MenuPrototype.Context.TITLE:
				var info := host.info()
				_display.text = "▲  WELCOME"
				if info.has_save:
					first = _round("4", "Continue", host.continue_game)
				var new_career := _round("3", "New career", host.new_career)
				if not first:
					first = new_career
				_round("2", "Settings", _show.bind("settings"))
				_round("1", "Credits", _show.bind("credits"))
				_round("STOP", "Quit", host.quit_game, true)
				_fill_welcome(info)
			else:
				var info := host.info()
				_display.text = "■  PAUSED  %s" % info.get("clock", "")
				first = _round("3", "Resume", host.continue_game)
				_round("2", "Settings", _show.bind("settings"))
				_round("1", "Quit to title", host.quit_to_title)
				_round("STOP", "Quit the game", host.quit_game, true)
				_fill_paused(info)
		"settings":
			var count := MenuProtoOptions.SECTIONS.size()
			for i in count:
				var s: Dictionary = MenuProtoOptions.SECTIONS[i]
				var button := _round(str(count - i), s.title, Callable())
				button.focus_entered.connect(_select_section.bind(s.id, count - i))
				button.pressed.connect(func() -> void: _first_card_widget().grab_focus())
				_floor_buttons[s.id] = button
			_round("L", "Lobby (back)", _show.bind("main"))
			first = _floor_buttons[section]
			_select_section(section, count - MenuProtoOptions.SECTIONS.map(func(s: Dictionary) -> String: return s.id).find(section))
		"credits":
			_display.text = "▲  CREDITS"
			first = _round("L", "Lobby (back)", _show.bind("main"))
			_fill_credits()
	first.grab_focus.call_deferred()


func _build_panel() -> void:
	var panel := PanelContainer.new()
	var plate := StyleBoxFlat.new()
	plate.bg_color = BRASS
	plate.set_corner_radius_all(10)
	plate.set_border_width_all(4)
	plate.border_color = BRASS_DARK
	plate.set_content_margin_all(22)
	plate.shadow_size = 18
	plate.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", plate)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position.x -= 70
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var screen_box := PanelContainer.new()
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.02, 0.05, 0.02)
	glass.set_corner_radius_all(4)
	glass.set_border_width_all(3)
	glass.border_color = BRASS_DARK
	glass.set_content_margin_all(10)
	screen_box.add_theme_stylebox_override("panel", glass)
	box.add_child(screen_box)
	_display = Label.new()
	_display.add_theme_font_override("font", _mono)
	_display.add_theme_font_size_override("font_size", 22)
	_display.add_theme_color_override("font_color", DISPLAY_GREEN)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_box.add_child(_display)

	var maker := Label.new()
	maker.text = "ELEVATOR PICCOLO"
	maker.add_theme_font_override("font", _serif)
	maker.add_theme_font_size_override("font_size", 13)
	maker.add_theme_color_override("font_color", BRASS_DARK)
	maker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(maker)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)


## A round lit-when-focused button with [param glyph] on it and [param text] engraved to
## its left. [param red] makes it the stop button.
func _round(glyph: String, text: String, on_press: Callable, red := false) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_buttons.add_child(row)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _serif)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(56, 56)
	button.add_theme_font_override("font", _mono)
	button.add_theme_font_size_override("font_size", 13 if glyph.length() > 2 else 20)
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.75, 0.15, 0.1) if red else Color(0.93, 0.9, 0.82)
	face.set_corner_radius_all(28)
	face.set_border_width_all(4)
	face.border_color = Color(0.5, 0.42, 0.3)
	var lit := face.duplicate()
	lit.bg_color = Color(1, 0.35, 0.25) if red else LIT
	lit.border_color = Color(1, 0.95, 0.7)
	lit.shadow_color = Color(LIT, 0.8)
	lit.shadow_size = 10
	button.add_theme_stylebox_override("normal", face)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("pressed", lit)
	for color in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(color, Color.WHITE if red else INK)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	button.mouse_entered.connect(button.grab_focus)
	row.add_child(button)
	return button


func _build_card() -> void:
	_card = PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = CREAM
	paper.set_corner_radius_all(3)
	paper.set_content_margin_all(36)
	paper.shadow_size = 24
	paper.shadow_color = Color(0, 0, 0, 0.45)
	paper.set_border_width_all(1)
	paper.border_color = Color(0.8, 0.7, 0.5)
	_card.add_theme_stylebox_override("panel", paper)
	_card.theme = _card_theme()
	if screen == "settings":
		_card.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_card.offset_bottom = -90
	_card.offset_left = 90
	_card.offset_right = 90 + 640
	_card.offset_top = 70
	add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 10)
	_card.add_child(_card_box)


func _heading(text: String, kicker := "") -> void:
	if kicker:
		var small := Label.new()
		small.text = kicker.to_upper()
		small.add_theme_font_size_override("font_size", 12)
		small.add_theme_color_override("font_color", Color(0.6, 0.42, 0.18))
		_card_box.add_child(small)
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 38)
	_card_box.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(0.6, 0.42, 0.18)
	rule.custom_minimum_size = Vector2(80, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_card_box.add_child(rule)


func _paragraph(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_box.add_child(label)
	return label


func _fill_welcome(info: Dictionary) -> void:
	if info.has_save:
		_heading("Welcome back", "The staff entrance")
		_paragraph("You work at %s. Shift %d is next on the rota." % [info.hotel, info.shift_number])
		_paragraph("Bank balance: €%.2f\nLast three shifts: %.1f ★" % [info.balance, info.average])
	else:
		_heading("Welcome", "The staff entrance")
		_paragraph("A rustic cabin up in the hills needs a bellhop. Three floors, one lift, and you.")
	var hint := _paragraph("Pick a floor on the panel.")
	hint.modulate = Color(1, 1, 1, 0.6)


func _fill_paused(info: Dictionary) -> void:
	_heading("Doors held", info.hotel)
	_paragraph("It's %s. The guests wait as long as you do." % info.get("clock", ""))
	_paragraph("%.1f ★   ·   €%.2f so far\nServed %d   ·   took the stairs %d" % [info.get("stars", 0.0), info.get("money", 0.0), info.get("served", 0), info.get("lost", 0)])


func _fill_credits() -> void:
	_heading("With thanks", "Credits")
	for line in MenuPrototype.CREDITS:
		var head := _paragraph(line[0])
		head.add_theme_color_override("font_color", Color(0.6, 0.42, 0.18))
		_paragraph(line[1])


## Turns the card to [param id]'s page, as the panel's [param number] floor.
func _select_section(id: String, number: int) -> void:
	section = id
	for child in _card_box.get_children():
		child.queue_free()
	var s: Dictionary = MenuProtoOptions.SECTIONS.filter(func(x: Dictionary) -> bool: return x.id == id)[0]
	_display.text = "▲  %d  %s" % [number, s.title.to_upper()]
	_heading(s.title, "Floor %d · Settings" % number)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_box.add_child(scroll)
	var rows := VBoxContainer.new()
	_rows = rows
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for option in s.options:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.custom_minimum_size.y = 36
		rows.add_child(row)
		var label := Label.new()
		label.text = "" if option.kind == "button" else option.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if option.get("stub", false):
			label.modulate = Color(1, 1, 1, 0.55)
		row.add_child(label)
		var widget := options.make_widget(option, _on_focus)
		widget.custom_minimum_size.x = 260
		row.add_child(widget)
	var reset := Button.new()
	reset.text = "Reset this floor"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		options.reset(id)
		_select_section(id, number)
		_first_card_widget().grab_focus.call_deferred())
	rows.add_child(reset)
	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size.y = 48
	_help.add_theme_font_size_override("font_size", 15)
	_help.modulate = Color(1, 1, 1, 0.7)
	_help.text = "← to step onto the card, B or Esc to step back onto the panel."
	_card_box.add_child(_help)


func _first_card_widget() -> Control:
	var rows := _rows
	for row in rows.get_children():
		if row is HBoxContainer:
			var widget: Control = row.get_child(1)
			return widget.get_child(0) if widget is HBoxContainer else widget
	return rows


func _on_focus(option: Dictionary) -> void:
	if is_instance_valid(_help):
		_help.text = MenuProtoOptions.help(option)


## The card's own look: dark ink on cream, serif, outlined controls.
func _card_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _serif
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.0)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.6, 0.42, 0.18, 0.6)
	normal.set_corner_radius_all(16)
	normal.set_content_margin_all(6)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var focus := normal.duplicate()
	focus.bg_color = LIT
	focus.set_border_width_all(2)
	focus.border_color = Color(0.6, 0.42, 0.18)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", focus)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", focus)
	for color in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(color, "Button", INK)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.6, 0.42, 0.18, 0.35)
	groove.content_margin_top = 2
	groove.content_margin_bottom = 2
	var filled := groove.duplicate()
	filled.bg_color = Color(0.6, 0.42, 0.18)
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var focus_ring := StyleBoxFlat.new()
	focus_ring.draw_center = false
	focus_ring.set_border_width_all(2)
	focus_ring.border_color = LIT.darkened(0.2)
	focus_ring.set_corner_radius_all(4)
	t.set_stylebox("focus", "HSlider", focus_ring)
	return t
