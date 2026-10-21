class_name GameMenu
extends Control
## The game's menus, over the paused hotel: the title screen at the start of the game, the
## pause menu (Esc or Start during a shift, or in the Asset room), the settings window
## ([SettingsMenu]) and the credits, with a yes/no question before anything that loses
## progress. The staff room opens the settings window straight away. Esc, B or Back goes one
## screen back; on the pause menu it resumes. Everything is drawn at the 1280 × 720 design
## size and grows with the window (the project's stretch setting).
## The menu stays in the tree when closed, without screens, to show the frame rate when
## [member Settings.show_fps] is on and to notice the window going to the background.

enum Where { TITLE, SHIFT, STAFF_ROOM, ASSET_ROOM }

const GOLD := Color(0.95, 0.75, 0.35)
const BUTTON_SIZE := Vector2(280, 40)
## Who made what, as in CREDITS.md.
const CREDITS: Array[Array] = [
	["Models", "Furniture Kit and Mini Characters by Kenney (CC0)"],
	["Music", "Bossa Nova by Joth, Somewhere in the Elevator by Peachtea, Two Left Socks by congusbongus (all CC0)"],
	["Sounds and textures", "Made in code"],
	["Engine", "Godot Engine"],
]

## The title screen shows once, when the game starts; tests and the benchmark switch it off.
static var show_title := true

## Esc or Start was pressed while the menu was closed and the game running, or the window
## went to the background with [member Settings.pause_in_background] on.
signal pause_requested
## Continue, Resume, or Back from the staff room's settings: the menu has closed.
signal closed
## A setting or a debug option changed; [param property] is the [Settings] property, or ""
## for several at once or a debug option.
signal changed(property: String)
## New career, confirmed if there was a career to lose: start over from the cabin.
signal new_career_requested
## Quit to title, confirmed: drop the shift and go back to the title screen.
signal title_requested
## End shift now (Debug): the menu has closed, and the shift should end as it stands.
signal end_shift_requested
## Asset room (Debug).
signal asset_room_requested
## Leave the Asset room.
signal asset_room_left

var settings: Settings
## The screen showing: "main" (the title screen or the pause menu), "settings", "credits",
## or "" while closed.
var screen := ""

var _where := Where.SHIFT
var _status := ""
var _screen_root: Control
var _settings_menu: SettingsMenu
var _dialog: Control
var _fps: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # works while the game is paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = make_theme()
	_screen_root = Control.new()
	_screen_root.name = "Screens"
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_root)
	_settings_menu = SettingsMenu.new()
	_settings_menu.name = "SettingsMenu"
	_settings_menu.settings = settings
	_settings_menu.changed.connect(changed.emit)
	_settings_menu.back.connect(_back)
	_settings_menu.end_shift_requested.connect(func() -> void:
		close()
		end_shift_requested.emit())
	_settings_menu.asset_room_requested.connect(asset_room_requested.emit)
	_settings_menu.hide()
	add_child(_settings_menu)
	_fps = Label.new()
	_fps.name = "Fps"
	_fps.position = Vector2(16, 40)
	_fps.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	add_child(_fps)


func _process(_delta: float) -> void:
	_fps.visible = settings.show_fps
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()


func is_open() -> bool:
	return screen != ""


## Opens the title screen or the pause menu. [param status] is the line under the title:
## the saved career on the title screen ("" when there is none, which leaves out Continue),
## the shift so far in the pause menu.
func open(where: Where, status := "") -> void:
	_where = where
	_settings_menu.set_where(where)
	_status = status
	_show("main")


## Opens the settings window on its own, as the staff room does: Back closes the menu.
func open_settings(where: Where) -> void:
	_where = where
	_show("settings")


func close() -> void:
	_close_dialog()
	_show("")
	closed.emit()


func _show(which: String) -> void:
	var from := screen
	screen = which
	for child: Control in _screen_root.get_children():
		child.hide() # gone at once, though freed at the end of the frame
		child.queue_free()
	_settings_menu.visible = which == "settings"
	match which:
		"main":
			if _where == Where.TITLE:
				_build_title()
			else:
				_build_pause()
			if from in ["settings", "credits"]:
				var button := _screen_root.find_child(from.capitalize(), true, false) as Control
				if button:
					focus_later(button)
		"settings":
			_shade(0.55)
			_settings_menu.open(_where)
		"credits":
			_build_credits()


## Esc, B, or Back in a screen: one screen back, or out of the pause menu.
func _back() -> void:
	match screen:
		"settings":
			if _where == Where.STAFF_ROOM:
				close()
			else:
				_show("main")
		"credits":
			_show("main")
		"main":
			if _where != Where.TITLE:
				close()


func _unhandled_input(event: InputEvent) -> void:
	var pause := event.is_action_pressed("pause")
	if is_open() and (pause or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if _dialog:
			_close_dialog()
		else:
			_back()
	elif is_open() and screen == "settings":
		_settings_menu.handle_tab_keys(event)
	elif pause and not is_open() and not get_tree().paused:
		get_viewport().set_input_as_handled()
		pause_requested.emit()


func _notification(what: int) -> void:
	if not settings:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if settings.mute_in_background:
			AudioServer.set_bus_mute(0, true)
		if settings.pause_in_background and not is_open() and not get_tree().paused:
			pause_requested.emit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		settings.apply_audio()


func _build_title() -> void:
	_shade(0.6)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := _label(box, "Elevator Piccolo", 56)
	title.add_theme_color_override("font_color", GOLD)
	_label(box, "Going up? Mind the doors.").modulate = Color(1, 1, 1, 0.7)
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	box.add_child(gap)
	var first: Button
	if _status:
		first = _button(box, "Continue", "Continue", close)
		var career := _label(box, _status, 14)
		career.name = "Career"
		career.modulate = Color(1, 1, 1, 0.6)
	var new_career := _button(box, "NewCareer", "New career", func() -> void:
		if _status:
			_confirm("Start a new career? Your bank balance, upgrades and hotel are wiped.", new_career_requested.emit)
		else:
			new_career_requested.emit())
	if not first:
		first = new_career
	_button(box, "Settings", "Settings", _show.bind("settings"))
	_button(box, "Credits", "Credits", _show.bind("credits"))
	_button(box, "Quit", "Quit", _quit)
	var version := Label.new()
	version.text = "Demo"
	version.modulate = Color(1, 1, 1, 0.4)
	version.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	version.grow_horizontal = Control.GROW_DIRECTION_BOTH
	version.position.y -= 40
	_screen_root.add_child(version)
	focus_later(first)


func _build_pause() -> void:
	_shade(0.35)
	var box := _window(Vector2(380, 0))
	_label(box, "Asset room" if _where == Where.ASSET_ROOM else "Paused", 32)
	if _status:
		var status := _label(box, _status)
		status.name = "Status"
		status.modulate = Color(1, 1, 1, 0.7)
	box.add_child(HSeparator.new())
	var resume := _button(box, "Resume", "Resume", close)
	_button(box, "Settings", "Settings", _show.bind("settings"))
	if _where == Where.ASSET_ROOM:
		_button(box, "LeaveAssetRoom", "Leave the Asset room", asset_room_left.emit)
	elif _where == Where.SHIFT:
		_button(box, "QuitToTitle", "Quit to title", _confirm.bind(
				"Back to the title screen? The shift in progress is lost.", title_requested.emit))
	_button(box, "Quit", "Quit the game", _quit)
	focus_later(resume)


func _build_credits() -> void:
	_shade(0.55)
	var box := _window(Vector2(620, 0))
	_label(box, "Credits", 28).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for line in CREDITS:
		var head := _label(box, line[0])
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.add_theme_color_override("font_color", GOLD)
		var body := _label(box, line[1])
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(box, "Back", "Back", _show.bind("main"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	focus_later(back)


func _quit() -> void:
	var text := "Quit the game? The shift in progress is lost." if _where == Where.SHIFT else "Quit the game?"
	_confirm(text, get_tree().quit)


## A yes/no question over the menu, with No focused. Esc or B is No.
func _confirm(text: String, on_yes: Callable) -> void:
	var previous := get_viewport().gui_get_focus_owner()
	_dialog = ColorRect.new()
	_dialog.name = "Confirm"
	_dialog.color = Color(0, 0, 0, 0.6)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dialog)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Dialog"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var label := _label(box, text)
	label.name = "Question"
	label.custom_minimum_size.x = 400
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var yes := _button(row, "Yes", "Yes", func() -> void:
		_close_dialog()
		on_yes.call())
	var no := _button(row, "No", "No", func() -> void:
		_close_dialog()
		if is_instance_valid(previous):
			previous.grab_focus())
	yes.custom_minimum_size.x = 140
	no.custom_minimum_size.x = 140
	focus_later(no)


## Focuses [param control] at the end of the frame, unless it has gone by then (a screen
## that closed, or a scene that was reloaded).
static func focus_later(control: Control) -> void:
	var focus := func() -> void:
		if is_instance_valid(control) and control.is_visible_in_tree():
			control.grab_focus()
	focus.call_deferred()


func _close_dialog() -> void:
	if _dialog:
		_dialog.hide()
		_dialog.queue_free()
		_dialog = null


func _shade(alpha: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_child(shade)


## A centred panel at least [param min_size], returning the column to fill.
func _window(min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_screen_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _label(parent: Control, text: String, font_size := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_size:
		label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Control, button_name: String, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(on_press)
	button.mouse_entered.connect(button.grab_focus)
	parent.add_child(button)
	return button


## The menus' look: dark panels, quiet buttons, a gold outline on the one with the focus,
## gold sliders, and tabs (the "Tab" variation) with a gold underline on the open one.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.12, 0.1, 0.08, 0.96)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(28)
	panel.set_border_width_all(1)
	panel.border_color = Color(1, 1, 1, 0.08)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation(&"Dialog", &"PanelContainer")
	var dialog := panel.duplicate()
	dialog.set_border_width_all(2)
	dialog.border_color = GOLD
	t.set_stylebox("panel", &"Dialog", dialog)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12)
	var focus := normal.duplicate()
	focus.bg_color = Color(GOLD, 0.25)
	focus.set_border_width_all(2)
	focus.border_color = GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(GOLD, 0.45)
	for type in ["Button", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)

	t.set_type_variation(&"Tab", &"Button")
	var tab := normal.duplicate()
	tab.bg_color = Color(1, 1, 1, 0.04)
	tab.corner_radius_bottom_left = 0
	tab.corner_radius_bottom_right = 0
	var tab_open := tab.duplicate()
	tab_open.bg_color = Color(GOLD, 0.35)
	tab_open.border_width_bottom = 3
	tab_open.border_color = GOLD
	t.set_stylebox("normal", &"Tab", tab)
	t.set_stylebox("pressed", &"Tab", tab_open)
	t.set_stylebox("hover_pressed", &"Tab", tab_open)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.2)
	track.set_corner_radius_all(2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var filled := track.duplicate()
	filled.bg_color = GOLD
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var focus_ring := StyleBoxFlat.new()
	focus_ring.draw_center = false
	focus_ring.set_border_width_all(2)
	focus_ring.border_color = GOLD
	focus_ring.set_corner_radius_all(4)
	focus_ring.set_expand_margin_all(4)
	t.set_stylebox("focus", "HSlider", focus_ring)
	return t
