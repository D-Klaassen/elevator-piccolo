extends Control
## PROTOTYPE, throw away. Variant C, "Full-screen list": the console way. No windows: the
## hotel stays in view on the right behind a dark fade from the left, the choices are big
## words in a column, and the focused one gets a gold bar. The settings are one long list
## with every section in it (no tabs), Q/E or LB/RB jump between sections, and a pane on
## the right explains the focused option. A prompt bar at the bottom lists the keys, or the
## controller's buttons while one is connected.

const GOLD := Color(0.98, 0.78, 0.36)

var host: MenuPrototype
var options: MenuProtoOptions
var screen := "main"
var section := "video"

var _context: MenuPrototype.Context
var _sans: SystemFont
var _sans_bold: SystemFont
var _chips := {} ## section id -> Label
var _headers := {} ## section id -> Label
var _first_widget := {} ## section id -> Control
var _option_section := {} ## option id -> section id
var _scroll: ScrollContainer
var _desc_title: Label
var _desc_body: Label
var _desc_tag: Label
var _prompts: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sans = SystemFont.new()
	_sans.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Segoe UI", "sans-serif"])
	_sans_bold = SystemFont.new()
	_sans_bold.font_names = _sans.font_names
	_sans_bold.font_weight = 700
	theme = _build_theme()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _update_prompts())


func open(context: MenuPrototype.Context, at_screen: String, at_section: String) -> void:
	_context = context
	section = at_section
	_show(at_screen)


func back() -> bool:
	if screen == "main":
		return false
	_show("main")
	return true


func _show(which: String) -> void:
	screen = which
	for child in get_children():
		child.queue_free()
	_chips.clear()
	_headers.clear()
	_first_widget.clear()
	var fade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.03, 0.94))
	gradient.set_color(1, Color(0.02, 0.02, 0.03, 0.15 if which == "main" else 0.75))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.35, 0)
	texture.fill_to = Vector2(1, 0)
	fade.texture = texture
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	_prompts = Label.new()
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompts.offset_top = -100
	_prompts.offset_bottom = -70
	_prompts.offset_left = 72
	_prompts.modulate = Color(1, 1, 1, 0.6)
	add_child(_prompts)
	match which:
		"main":
			_build_main()
		"settings":
			_build_settings()
		"credits":
			_build_credits()
	_update_prompts()


func _header(title: String) -> void:
	var kicker := Label.new()
	kicker.text = "E L E V A T O R   P I C C O L O"
	kicker.add_theme_font_override("font", _sans_bold)
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", GOLD)
	kicker.position = Vector2(72, 48)
	add_child(kicker)
	var big := Label.new()
	big.text = title
	big.add_theme_font_override("font", _sans_bold)
	big.add_theme_font_size_override("font_size", 44)
	big.position = Vector2(70, 66)
	add_child(big)


func _build_main() -> void:
	var info := host.info()
	var column := VBoxContainer.new()
	column.position = Vector2(60, 220)
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var first: Button
	if _context == MenuPrototype.Context.TITLE:
		_header("Going up?")
		if info.has_save:
			first = _item(column, "Continue", host.continue_game)
		var new_career := _item(column, "New career", host.new_career)
		if not first:
			first = new_career
		_item(column, "Settings", _show.bind("settings"))
		_item(column, "Credits", _show.bind("credits"))
		_item(column, "Quit", host.quit_game)
		if info.has_save:
			var save := Label.new()
			save.text = "%s  ·  shift %d  ·  €%.2f  ·  %.1f ★" % [info.hotel.to_upper(), info.shift_number, info.balance, info.average]
			save.add_theme_font_override("font", _sans_bold)
			save.add_theme_font_size_override("font_size", 13)
			save.modulate = Color(1, 1, 1, 0.55)
			save.position = Vector2(72, 140)
			add_child(save)
	else:
		_header("Paused")
		var status := Label.new()
		status.text = "%s  ·  %s  ·  %.1f ★  ·  €%.2f  ·  served %d" % [info.hotel.to_upper(), info.get("clock", ""), info.get("stars", 0.0), info.get("money", 0.0), info.get("served", 0)]
		status.add_theme_font_override("font", _sans_bold)
		status.add_theme_font_size_override("font_size", 13)
		status.modulate = Color(1, 1, 1, 0.55)
		status.position = Vector2(72, 140)
		add_child(status)
		first = _item(column, "Resume", host.continue_game)
		_item(column, "Settings", _show.bind("settings"))
		_item(column, "Quit to title", host.quit_to_title)
		_item(column, "Quit the game", host.quit_game)
	first.grab_focus.call_deferred()


## A big word in the column: dim until focused, then white with a gold bar.
func _item(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"BigItem"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(460, 0)
	button.pressed.connect(on_press)
	button.mouse_entered.connect(button.grab_focus)
	parent.add_child(button)
	return button


func _build_settings() -> void:
	_header("Settings")
	var chips := HBoxContainer.new()
	chips.position = Vector2(72, 132)
	chips.add_theme_constant_override("separation", 28)
	add_child(chips)
	for s in MenuProtoOptions.SECTIONS:
		var chip := Label.new()
		chip.text = s.title.to_upper()
		chip.add_theme_font_override("font", _sans_bold)
		chip.add_theme_font_size_override("font_size", 14)
		chips.add_child(chip)
		_chips[s.id] = chip

	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = Vector2(60, 172)
	_scroll.size = Vector2(620, 420)
	add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	_scroll.add_child(list)
	for s in MenuProtoOptions.SECTIONS:
		var head := Label.new()
		head.text = s.title.to_upper()
		head.add_theme_font_override("font", _sans_bold)
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", GOLD)
		head.custom_minimum_size.y = 40
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		list.add_child(head)
		_headers[s.id] = head
		for option in s.options:
			_option_section[option.id] = s.id
			list.add_child(_row(option, s.id))

	var pane := VBoxContainer.new()
	pane.position = Vector2(740, 200)
	pane.custom_minimum_size.x = 440
	pane.add_theme_constant_override("separation", 12)
	add_child(pane)
	_desc_tag = Label.new()
	_desc_tag.add_theme_font_override("font", _sans_bold)
	_desc_tag.add_theme_font_size_override("font_size", 12)
	_desc_tag.add_theme_color_override("font_color", GOLD)
	pane.add_child(_desc_tag)
	_desc_title = Label.new()
	_desc_title.add_theme_font_override("font", _sans_bold)
	_desc_title.add_theme_font_size_override("font_size", 30)
	_desc_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_title.custom_minimum_size.x = 440
	pane.add_child(_desc_title)
	_desc_body = Label.new()
	_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_body.custom_minimum_size.x = 440
	_desc_body.modulate = Color(1, 1, 1, 0.8)
	pane.add_child(_desc_body)
	_first_widget[section].grab_focus.call_deferred()
	_scroll_to.call_deferred(section)


## Puts [param id]'s header at the top of the list.
func _scroll_to(id: String) -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int((_headers[id] as Control).position.y)


## One line of the list: the option's name on the left, its control on the right, and a
## faint band behind the line while its control has the focus.
func _row(option: Dictionary, section_id: String) -> Control:
	var band := PanelContainer.new()
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0)
	off.set_content_margin_all(6)
	off.content_margin_left = 12
	var on := off.duplicate()
	on.bg_color = Color(1, 1, 1, 0.08)
	on.border_width_left = 4
	on.border_color = GOLD
	band.add_theme_stylebox_override("panel", off)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	band.add_child(row)
	var label := Label.new()
	label.text = "" if option.kind == "button" else option.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if option.get("stub", false):
		label.modulate = Color(1, 1, 1, 0.55)
	row.add_child(label)
	var widget := options.make_widget(option, _on_focus)
	widget.custom_minimum_size.x = 250
	row.add_child(widget)
	var focusable: Control = widget.get_child(0) if widget is HBoxContainer else widget
	focusable.focus_entered.connect(func() -> void: band.add_theme_stylebox_override("panel", on))
	focusable.focus_exited.connect(func() -> void: band.add_theme_stylebox_override("panel", off))
	focusable.mouse_entered.connect(focusable.grab_focus)
	if not _first_widget.has(section_id):
		_first_widget[section_id] = focusable
	return band


func _on_focus(option: Dictionary) -> void:
	section = _option_section.get(option.id, section)
	for id in _chips:
		(_chips[id] as Label).modulate = Color.WHITE if id == section else Color(1, 1, 1, 0.35)
	var s: Dictionary = MenuProtoOptions.SECTIONS.filter(func(x: Dictionary) -> bool: return x.id == section)[0]
	_desc_tag.text = s.title.to_upper() + ("   ·   NOT WIRED YET" if option.get("stub", false) else "")
	_desc_title.text = option.label
	_desc_body.text = MenuProtoOptions.help(option).replace("  [prototype: not wired yet]", "")


func _build_credits() -> void:
	_header("Credits")
	var column := VBoxContainer.new()
	column.position = Vector2(72, 160)
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	for line in MenuPrototype.CREDITS:
		var head := Label.new()
		head.text = line[0].to_upper()
		head.add_theme_font_override("font", _sans_bold)
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", GOLD)
		column.add_child(head)
		var body := Label.new()
		body.text = line[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 560
		column.add_child(body)
		column.add_child(Control.new())
	var done := _item(column, "Back", _show.bind("main"))
	done.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if screen != "settings":
		return
	var by := 0
	var reset := false
	if event is InputEventKey and event.pressed and not event.echo:
		by = -1 if event.keycode == KEY_Q else (1 if event.keycode == KEY_E else 0)
		reset = event.keycode == KEY_R
	elif event is InputEventJoypadButton and event.pressed:
		by = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
		reset = event.button_index == JOY_BUTTON_Y
	if by != 0:
		var ids := MenuProtoOptions.SECTIONS.map(func(s: Dictionary) -> String: return s.id)
		section = ids[posmod(ids.find(section) + by, ids.size())]
		(_first_widget[section] as Control).grab_focus()
		_scroll_to(section)
		get_viewport().set_input_as_handled()
	elif reset:
		options.reset(section)
		var keep := section
		_show("settings")
		section = keep
		get_viewport().set_input_as_handled()


func _update_prompts() -> void:
	if not is_instance_valid(_prompts):
		return
	var pad := not Input.get_connected_joypads().is_empty()
	match screen:
		"settings":
			_prompts.text = ("Ⓐ Change   ◀▶ Adjust   LB/RB Section   Ⓨ Reset section   Ⓑ Back" if pad
					else "↑↓ Choose   ←→ Adjust   Q/E Section   R Reset section   Esc Back")
		_:
			_prompts.text = "Ⓐ Select   Ⓑ Back" if pad else "↑↓ Choose   Enter Select   Esc Back"


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _sans
	t.default_font_size = 18
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.set_content_margin_all(6)
	clear.content_margin_left = 12
	clear.content_margin_right = 12
	var soft := clear.duplicate()
	soft.bg_color = Color(1, 1, 1, 0.1)
	soft.set_corner_radius_all(3)
	t.set_stylebox("normal", "Button", clear)
	t.set_stylebox("hover", "Button", soft)
	t.set_stylebox("focus", "Button", soft)
	t.set_stylebox("pressed", "Button", soft)
	t.set_color("font_color", "Button", Color(1, 1, 1, 0.85))
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_type_variation(&"BigItem", &"Button")
	var item := StyleBoxFlat.new()
	item.bg_color = Color(0, 0, 0, 0)
	item.content_margin_left = 14
	item.content_margin_top = 4
	item.content_margin_bottom = 4
	var item_on := item.duplicate()
	item_on.border_width_left = 6
	item_on.border_color = GOLD
	item_on.bg_color = Color(1, 1, 1, 0.06)
	t.set_stylebox("normal", &"BigItem", item)
	t.set_stylebox("hover", &"BigItem", item_on)
	t.set_stylebox("focus", &"BigItem", item_on)
	t.set_stylebox("pressed", &"BigItem", item_on)
	t.set_font(&"font", &"BigItem", _sans_bold)
	t.set_font_size(&"font_size", &"BigItem", 40)
	t.set_color("font_color", &"BigItem", Color(1, 1, 1, 0.45))
	t.set_color("font_focus_color", &"BigItem", Color.WHITE)
	t.set_color("font_hover_color", &"BigItem", Color.WHITE)
	t.set_color("font_pressed_color", &"BigItem", Color.WHITE)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(1, 1, 1, 0.2)
	groove.content_margin_top = 2
	groove.content_margin_bottom = 2
	var filled := groove.duplicate()
	filled.bg_color = GOLD
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	return t
