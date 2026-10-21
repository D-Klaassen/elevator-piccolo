class_name SettingsMenu
extends PanelContainer
## The settings window: a tab per section (Video, Audio, Controls, Game, and Debug in debug
## builds), a row per setting with its name and its control, and the focused setting's
## explanation in the footer. Q/E or LB/RB switch tabs; a choice is a "◀ value ▶" button that
## ←/→ (or a click, or A) step through. Every change is saved and takes effect straight away:
## the window, vsync and frame rate limit here, the rest by whoever listens to [signal changed].
## [GameMenu] shows it; Back (or Esc, or B) emits [signal back].

## A setting changed: the [Settings] property, or "" for several at once (Reset tab) or a
## debug option.
signal changed(property: String)
signal back
## End shift now (Debug) was pressed.
signal end_shift_requested
## Asset room (Debug) was pressed.
signal asset_room_requested

## The tabs and their settings. [code]id[/code] is the [Settings] property; [code]kind[/code]
## is "choice" (an index into [code]choices[/code]), "toggle", "slider", "key" (the key for
## [code]action[/code]) or "reset_keys".
const SECTIONS: Array[Dictionary] = [
	{"id": "video", "title": "Video", "settings": [
		{"id": "display_mode", "label": "Display mode", "kind": "choice", "choices": ["Windowed", "Fullscreen", "Borderless"],
			"help": "Windowed, fullscreen, or a borderless window the size of the screen."},
		{"id": "window_size", "label": "Window size", "kind": "choice", "choices": ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"],
			"help": "The size of the window, when Display mode is Windowed. The menus and the HUD grow with it."},
		{"id": "vsync", "label": "V-Sync", "kind": "toggle",
			"help": "Waits for the screen before drawing the next frame: no tearing, a touch more input lag."},
		{"id": "max_fps", "label": "Frame rate limit", "kind": "choice", "choices": ["30", "60", "120", "144", "No limit"],
			"help": "The most frames a second the game draws. 30 saves battery on a laptop."},
		{"id": "msaa", "label": "Smooth edges", "kind": "choice", "choices": ["Off", "2×", "4×", "8×"],
			"help": "Anti-aliasing (MSAA) on the 3D view. Turn it down if the game runs slowly."},
		{"id": "render_scale", "label": "Render scale", "kind": "slider", "min": Settings.MIN_RENDER_SCALE, "max": 1.0, "step": 0.05, "format": "percent",
			"help": "Draws the 3D view at a lower resolution and scales it up (FSR). Lower is faster but blurrier."},
		{"id": "fov", "label": "Field of view", "kind": "slider", "min": Settings.MIN_FOV, "max": Settings.MAX_FOV, "step": 1.0, "format": "degrees",
			"help": "How wide you see. Wider helps in the cramped cab; narrower if wide views make you queasy."},
		{"id": "brightness", "label": "Brightness", "kind": "slider", "min": Settings.MIN_BRIGHTNESS, "max": Settings.MAX_BRIGHTNESS, "step": 0.05, "format": "percent",
			"help": "Makes the hotel lighter or darker."},
		{"id": "show_fps", "label": "Show frame rate", "kind": "toggle",
			"help": "Shows the frames per second in the top left corner."},
	]},
	{"id": "audio", "title": "Audio", "settings": [
		{"id": "volume", "label": "Master volume", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent",
			"help": "Everything at once. 0 mutes the game."},
		{"id": "music_volume", "label": "Music", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent",
			"help": "The radio in the cab, once you've bought it."},
		{"id": "effects_volume", "label": "Sound effects", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent",
			"help": "The dings of the guests' calls and the chimes of the cab."},
		{"id": "mute_in_background", "label": "Mute in the background", "kind": "toggle",
			"help": "Goes quiet while you're in another window."},
	]},
	{"id": "controls", "title": "Controls", "settings": [
		{"id": "mouse_sensitivity", "label": "Mouse sensitivity", "kind": "slider", "min": Settings.MIN_SENSITIVITY, "max": Settings.MAX_SENSITIVITY, "step": 0.05, "format": "times",
			"help": "How fast the mouse turns the view."},
		{"id": "stick_sensitivity", "label": "Controller sensitivity", "kind": "slider", "min": Settings.MIN_SENSITIVITY, "max": Settings.MAX_SENSITIVITY, "step": 0.05, "format": "times",
			"help": "How fast the right stick turns the view."},
		{"id": "invert_y", "label": "Invert look up/down", "kind": "toggle",
			"help": "Push up (or move the mouse up) to look down, as in a flight sim."},
		{"id": "key_move_forward", "label": "Walk forward", "kind": "key", "action": "move_forward"},
		{"id": "key_move_back", "label": "Walk back", "kind": "key", "action": "move_back"},
		{"id": "key_move_left", "label": "Walk left", "kind": "key", "action": "move_left"},
		{"id": "key_move_right", "label": "Walk right", "kind": "key", "action": "move_right"},
		{"id": "key_interact", "label": "Press / talk", "kind": "key", "action": "interact"},
		{"id": "reset_keys", "label": "", "kind": "reset_keys",
			"help": "Puts every key back where it was."},
	]},
	{"id": "game", "title": "Game", "settings": [
		{"id": "reply_time", "label": "Time to reply in a chat", "kind": "choice", "choices": ["6 s", "12 s", "No limit"],
			"help": "How long you have to pick a reply before you blurt one out. No limit takes the pressure off."},
		{"id": "hint_time", "label": "Messages stay for", "kind": "choice", "choices": ["3 s", "5 s", "8 s"],
			"help": "How long pay, complaints and hints stay at the bottom of the screen."},
		{"id": "crosshair", "label": "Crosshair", "kind": "choice", "choices": ["Plus", "Dot", "Off"],
			"help": "The mark in the middle of the screen that shows what you'd press."},
		{"id": "help_line", "label": "Controls in the corner", "kind": "toggle",
			"help": "The line in the bottom left corner that lists the controls."},
		{"id": "pause_in_background", "label": "Pause in the background", "kind": "toggle",
			"help": "Pauses the shift when you switch to another window."},
	]},
]
## The settings that change the window, which this menu applies itself.
const DISPLAY: Array[String] = ["display_mode", "window_size", "vsync", "max_fps"]
const KEY_HELP := "Press, then press the new key (Esc to keep the old one). The controller's buttons stay as they are."

var settings: Settings
## The open tab: a section id, or "debug".
var tab := "video"

var _tabs := {} ## tab id -> its Button
var _pages := {} ## tab id -> its GridContainer
var _help: Label
var _reset: Button
var _end_shift: Button
var _asset_room: Button
var _walk_speed_row: Array[Control] = []
var _speed: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(880, 560)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

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
	box.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)

	var group := ButtonGroup.new()
	var sections := SECTIONS.duplicate()
	if DebugOptions.available:
		sections.append({"id": "debug", "title": "Debug", "settings": []})
	for section in sections:
		var button := Button.new()
		button.name = section.title + "Tab"
		button.text = section.title
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"Tab"
		button.pressed.connect(select_tab.bind(section.id))
		tab_row.add_child(button)
		_tabs[section.id] = button
		var page := _build_debug() if section.id == "debug" else _build_page(section)
		page.name = section.title
		pages.add_child(page)
		_pages[section.id] = page

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	_help = Label.new()
	_help.name = "Help"
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.custom_minimum_size.y = 48
	_help.modulate = Color(1, 1, 1, 0.75)
	footer.add_child(_help)
	_reset = Button.new()
	_reset.name = "ResetTab"
	_reset.text = "Reset tab"
	_reset.pressed.connect(reset_tab)
	footer.add_child(_reset)
	var done := Button.new()
	done.name = "Back"
	done.text = "Back"
	done.pressed.connect(back.emit)
	footer.add_child(done)


## Shows the window with the saved values, on the tab it was on. [param where] decides what
## the Debug tab offers.
func open(where: GameMenu.Where) -> void:
	set_where(where)
	_refresh()
	show()
	select_tab(tab)


## Fits the Debug tab to [param where]: End shift now during a shift, the Asset room button
## outside the Asset room, and the walk speed inside it.
func set_where(where: GameMenu.Where) -> void:
	if _end_shift:
		_end_shift.visible = where == GameMenu.Where.SHIFT
		_asset_room.visible = where != GameMenu.Where.ASSET_ROOM
		for control in _walk_speed_row:
			control.visible = where == GameMenu.Where.ASSET_ROOM


## Opens the tab [param id] and focuses its first setting.
func select_tab(id: String) -> void:
	tab = id
	_tabs[id].button_pressed = true
	for page_id in _pages:
		_pages[page_id].visible = page_id == id
	_reset.visible = id != "debug"
	var first := _first_focusable(_pages[id])
	if first:
		GameMenu.focus_later(first)


## Q/E or LB/RB: the tab before or after this one. Called by [GameMenu] while the window
## shows.
func handle_tab_keys(event: InputEvent) -> void:
	var by := 0
	if event is InputEventKey and event.pressed and not event.echo:
		by = -1 if event.keycode == KEY_Q else (1 if event.keycode == KEY_E else 0)
	elif event is InputEventJoypadButton and event.pressed:
		by = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	if by != 0:
		var ids := _tabs.keys()
		select_tab(ids[posmod(ids.find(tab) + by, ids.size())])
		get_viewport().set_input_as_handled()


## Every setting on the open tab back to its default.
func reset_tab() -> void:
	var defaults := Settings.new()
	for section in SECTIONS:
		if section.id != tab:
			continue
		for setting in section.settings:
			if setting.kind == "key" or setting.kind == "reset_keys":
				settings.reset_keys()
			else:
				settings.set(setting.id, defaults.get(setting.id))
	if tab == "video":
		settings.apply_display()
	if tab == "controls":
		settings.apply_keys()
	_refresh()
	_saved("")


func _build_page(section: Dictionary) -> GridContainer:
	var grid := _grid()
	for setting in section.settings:
		var label := Label.new()
		label.text = setting.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var control := _control(setting)
		control.custom_minimum_size.x = 320
		grid.add_child(control)
	return grid


## The control for [param setting], named after it, wired to [member settings].
func _control(setting: Dictionary) -> Control:
	var id: String = setting.id
	var control: Control
	match setting.kind:
		"choice":
			control = CycleButton.new(setting.choices,
					func() -> int: return settings.get(id),
					func(i: int) -> void: _set_setting(id, i))
		"toggle":
			control = CycleButton.new(["Off", "On"],
					func() -> int: return 1 if settings.get(id) else 0,
					func(i: int) -> void: _set_setting(id, i == 1))
		"slider":
			control = SliderRow.new(setting,
					func() -> float: return settings.get(id),
					func(v: float) -> void: _set_setting(id, v))
		"key":
			control = KeyButton.new(setting.action, settings, _on_key_bound)
		"reset_keys":
			var button := Button.new()
			button.text = "Reset keys"
			button.pressed.connect(func() -> void:
				settings.reset_keys()
				_on_key_bound())
			control = button
	control.name = id
	var focusable := _first_focusable(control)
	var help: String = KEY_HELP if setting.kind == "key" else setting.help
	focusable.focus_entered.connect(func() -> void: _help.text = help)
	focusable.mouse_entered.connect(func() -> void: _help.text = help)
	return control


## The Debug tab: the [DebugOptions], End shift now and the way into the Asset room, and in
## the Asset room its walk speed.
func _build_debug() -> GridContainer:
	var grid := _grid()
	grid.add_child(_debug_label("Infinite money"))
	grid.add_child(_switch("InfiniteMoney", DebugOptions.infinite_money,
			func(on: bool) -> void: DebugOptions.infinite_money = on))
	grid.add_child(_debug_label("Skip hotel requirements"))
	grid.add_child(_switch("SkipHotelRequirements", DebugOptions.skip_hotel_requirements,
			func(on: bool) -> void: DebugOptions.skip_hotel_requirements = on))
	grid.add_child(_debug_label(""))
	_speed = Button.new()
	_speed.name = "GameSpeed"
	_speed.pressed.connect(func() -> void:
		DebugOptions.speed = DebugOptions.next_speed()
		_update_speed()
		changed.emit(""))
	grid.add_child(_speed)
	_update_speed()
	grid.add_child(_debug_label(""))
	_end_shift = Button.new()
	_end_shift.name = "EndShiftNow"
	_end_shift.text = "End shift now"
	_end_shift.pressed.connect(end_shift_requested.emit)
	grid.add_child(_end_shift)
	grid.add_child(_debug_label(""))
	_asset_room = Button.new()
	_asset_room.name = "AssetRoom"
	_asset_room.text = "Asset room"
	_asset_room.pressed.connect(asset_room_requested.emit)
	grid.add_child(_asset_room)
	var walk_label := _debug_label("Walk speed")
	grid.add_child(walk_label)
	var walk := SliderRow.new({"id": "WalkSpeed", "min": 1.0, "max": AssetRoom.MAX_WALK_SPEED, "step": 0.5, "format": "times"},
			func() -> float: return AssetRoom.walk_speed,
			func(v: float) -> void:
				AssetRoom.walk_speed = v
				changed.emit(""))
	walk.name = "WalkSpeedRow"
	grid.add_child(walk)
	_walk_speed_row = [walk_label, walk]
	for control in grid.get_children():
		if control is BaseButton or control is SliderRow:
			_first_focusable(control).focus_entered.connect(func() -> void:
				_help.text = "For testing, in debug builds only. The switches are off again when the game starts.")
	return grid


func _debug_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _switch(switch_name: String, on: bool, set_option: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.name = switch_name
	button.button_pressed = on
	button.toggled.connect(func(pressed: bool) -> void:
		set_option.call(pressed)
		changed.emit(""))
	return button


func _update_speed() -> void:
	_speed.text = "Game speed: ×%d" % DebugOptions.speed


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


func _set_setting(id: String, value: Variant) -> void:
	settings.set(id, value)
	if id in DISPLAY:
		settings.apply_display()
	_saved(id)


func _on_key_bound() -> void:
	_refresh()
	_saved("keys")


func _saved(id: String) -> void:
	var error := settings.save()
	if error != OK:
		push_error("Couldn't save the settings to %s: %s" % [Settings.save_path, error_string(error)])
	changed.emit(id)


## Every control shows the value it stands for again.
func _refresh() -> void:
	for page in _pages.values():
		for control in page.get_children():
			if control.has_method("refresh"):
				control.refresh()


static func _first_focusable(control: Control) -> Control:
	if control.focus_mode != Control.FOCUS_NONE:
		return control
	for child in control.get_children():
		if child is Control and child.visible:
			var found := _first_focusable(child)
			if found:
				return found
	return null


## A choice (or Off/On) as one button, "◀  Fullscreen  ▶": ←/→ step through the values, a
## click or A steps forward.
class CycleButton extends Button:
	var _choices: Array
	var _get: Callable
	var _set: Callable

	func _init(choices: Array, get_index: Callable, set_index: Callable) -> void:
		_choices = choices
		_get = get_index
		_set = set_index
		pressed.connect(step.bind(1))

	func _ready() -> void:
		refresh()

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			step(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			step(1)
			accept_event()

	## Moves [param by] values on, wrapping round.
	func step(by: int) -> void:
		_set.call(posmod(_get.call() + by, _choices.size()))
		refresh()

	func value() -> String:
		return _choices[_get.call()]

	func refresh() -> void:
		text = "◀   %s   ▶" % value()


## A slider with its value next to it: "80%", "75°" or "×1.25".
class SliderRow extends HBoxContainer:
	var slider: HSlider
	var _label: Label
	var _format: String
	var _get: Callable

	func _init(setting: Dictionary, get_value: Callable, set_value: Callable) -> void:
		_format = setting.format
		_get = get_value
		add_theme_constant_override("separation", 12)
		slider = HSlider.new()
		slider.name = setting.id.to_pascal_case()
		slider.min_value = setting.min
		slider.max_value = setting.max
		slider.step = setting.step
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(slider)
		_label = Label.new()
		_label.custom_minimum_size.x = 60
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_label)
		slider.value_changed.connect(func(v: float) -> void:
			set_value.call(v)
			_show(v))

	func refresh() -> void:
		slider.set_value_no_signal(_get.call())
		_show(slider.value)

	func _show(v: float) -> void:
		match _format:
			"percent":
				_label.text = "%d%%" % roundi(v * 100)
			"degrees":
				_label.text = "%d°" % roundi(v)
			_:
				_label.text = "×%.2f" % v


## The key an action is on: press it, then press the new key. Esc keeps the old one, and so
## does a controller button, which can't be pressed here.
class KeyButton extends Button:
	var listening := false
	var _action: String
	var _settings: Settings
	var _bound: Callable

	func _init(action: String, settings: Settings, on_bound: Callable) -> void:
		_action = action
		_settings = settings
		_bound = on_bound
		pressed.connect(func() -> void:
			listening = true
			text = "Press a key…")

	func _ready() -> void:
		refresh()

	func refresh() -> void:
		listening = false
		text = OS.get_keycode_string(_settings.key(_action))

	func _input(event: InputEvent) -> void:
		if not listening or not event.is_pressed() or event.is_echo():
			return
		if event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
			refresh()
		elif event is InputEventKey:
			get_viewport().set_input_as_handled()
			if event.physical_keycode == KEY_ESCAPE:
				refresh()
				return
			_settings.bind(_action, event.physical_keycode)
			_settings.apply_keys()
			_bound.call()
