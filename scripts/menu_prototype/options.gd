class_name MenuProtoOptions
extends RefCounted
## PROTOTYPE, throw away. The settings the menu prototype offers, shared by its three
## variants so they disagree only about layout: the sections, every option in them, the
## values chosen so far (in memory only, nothing is saved) and the few that are cheap to
## apply live. Options marked [code]"stub": true[/code] only change their value: the game
## has nothing for them yet.

signal value_changed(id: String)

const SECTIONS: Array[Dictionary] = [
	{"id": "video", "title": "Video", "options": [
		{"id": "display_mode", "label": "Display mode", "kind": "choice", "choices": ["Windowed", "Fullscreen", "Borderless"], "default": 0,
			"help": "Windowed, exclusive fullscreen, or a borderless window the size of the screen."},
		{"id": "window_size", "label": "Window size", "kind": "choice", "choices": ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], "default": 0,
			"help": "The size of the window, when Display mode is Windowed."},
		{"id": "vsync", "label": "V-Sync", "kind": "toggle", "default": true,
			"help": "Waits for the screen before drawing the next frame: no tearing, a touch more input lag."},
		{"id": "max_fps", "label": "Frame rate limit", "kind": "choice", "choices": ["30", "60", "120", "144", "Unlimited"], "default": 4,
			"help": "The most frames a second the game draws. 30 saves battery on a laptop."},
		{"id": "msaa", "label": "Smooth edges", "kind": "choice", "choices": ["Off", "2×", "4×", "8×"], "default": 1,
			"help": "Anti-aliasing (MSAA) on the 3D view. Turn it down if the game runs slowly."},
		{"id": "render_scale", "label": "Render scale", "kind": "slider", "min": 0.5, "max": 1.0, "step": 0.05, "default": 1.0, "format": "percent",
			"help": "Draws the 3D view at a lower resolution and scales it up (FSR). Lower is faster but blurrier."},
		{"id": "fov", "label": "Field of view", "kind": "slider", "min": 60.0, "max": 100.0, "step": 1.0, "default": 75.0, "format": "degrees",
			"help": "How wide you see. Wider helps in the cramped cab; narrower if wide views make you queasy."},
		{"id": "brightness", "label": "Brightness", "kind": "slider", "min": 0.5, "max": 1.5, "step": 0.05, "default": 1.0, "format": "percent",
			"help": "Makes the hotel lighter or darker."},
		{"id": "show_fps", "label": "Show frame rate", "kind": "toggle", "default": false,
			"help": "Shows the frames per second in the top left corner."},
	]},
	{"id": "audio", "title": "Audio", "options": [
		{"id": "master", "label": "Master volume", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.8, "format": "percent",
			"help": "Everything at once. 0 mutes the game."},
		{"id": "music", "label": "Music", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "default": 1.0, "format": "percent",
			"help": "The radio in the cab, once you've bought it."},
		{"id": "effects", "label": "Sound effects", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "default": 1.0, "format": "percent", "stub": true,
			"help": "The dings, the chimes and the doors."},
		{"id": "voices", "label": "Guest voices", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "default": 1.0, "format": "percent", "stub": true,
			"help": "Guests' murmurs and chatter, for when they get voices."},
		{"id": "background_mute", "label": "Mute in the background", "kind": "toggle", "default": true, "stub": true,
			"help": "Goes quiet while you're in another window."},
	]},
	{"id": "controls", "title": "Controls", "options": [
		{"id": "mouse_sensitivity", "label": "Mouse sensitivity", "kind": "slider", "min": 0.25, "max": 3.0, "step": 0.05, "default": 1.0, "format": "times",
			"help": "How fast the mouse turns the view."},
		{"id": "stick_sensitivity", "label": "Controller sensitivity", "kind": "slider", "min": 0.25, "max": 3.0, "step": 0.05, "default": 1.0, "format": "times", "stub": true,
			"help": "How fast the right stick turns the view. Today one slider does both."},
		{"id": "invert_y", "label": "Invert look up/down", "kind": "toggle", "default": false, "stub": true,
			"help": "Push up to look down, as in a flight sim."},
		{"id": "vibration", "label": "Controller vibration", "kind": "toggle", "default": true, "stub": true,
			"help": "A short rumble at every ding and when the cab arrives."},
		{"id": "bind_move_forward", "label": "Walk forward", "kind": "bind", "default": KEY_W, "action": "move_forward"},
		{"id": "bind_move_back", "label": "Walk back", "kind": "bind", "default": KEY_S, "action": "move_back"},
		{"id": "bind_move_left", "label": "Walk left", "kind": "bind", "default": KEY_A, "action": "move_left"},
		{"id": "bind_move_right", "label": "Walk right", "kind": "bind", "default": KEY_D, "action": "move_right"},
		{"id": "bind_interact", "label": "Press / talk", "kind": "bind", "default": KEY_E, "action": "interact"},
		{"id": "reset_controls", "label": "Reset controls to default", "kind": "button"},
	]},
	{"id": "game", "title": "Game", "options": [
		{"id": "language", "label": "Language", "kind": "choice", "choices": ["English"], "default": 0, "stub": true,
			"help": "The language of the menus and of what you say. Spanish guests stay Spanish."},
		{"id": "reply_timer", "label": "Time to reply in a chat", "kind": "choice", "choices": ["6 s", "12 s", "No limit"], "default": 0, "stub": true,
			"help": "How long you have to pick a reply before you blurt one out. No limit takes the pressure off."},
		{"id": "text_size", "label": "Speech bubble size", "kind": "choice", "choices": ["Small", "Medium", "Large"], "default": 1, "stub": true,
			"help": "How big the guests' speech bubbles and their text are."},
		{"id": "hint_time", "label": "Messages stay for", "kind": "choice", "choices": ["3 s", "5 s", "8 s"], "default": 0, "stub": true,
			"help": "How long pay, complaints and hints stay at the bottom of the screen."},
		{"id": "crosshair", "label": "Crosshair", "kind": "choice", "choices": ["Plus", "Dot", "Off"], "default": 0, "stub": true,
			"help": "The mark in the middle of the screen that shows what you'd press."},
		{"id": "help_line", "label": "Controls in the corner", "kind": "toggle", "default": true,
			"help": "The line in the bottom left that lists the controls."},
		{"id": "pause_on_focus_loss", "label": "Pause in the background", "kind": "toggle", "default": true, "stub": true,
			"help": "Pauses the shift when you switch to another window."},
	]},
]

## Option id -> its value: an index for a choice, a bool for a toggle, a float for a
## slider, a keycode for a binding.
var values := {}
## The hotel scene the live options are applied to.
var scene: Node


func _init() -> void:
	for section in SECTIONS:
		for option in section.options:
			if option.has("default"):
				values[option.id] = option.default


static func find(id: String) -> Dictionary:
	for section in SECTIONS:
		for option in section.options:
			if option.id == id:
				return option
	return {}


func set_value(id: String, value: Variant) -> void:
	values[id] = value
	_apply(id)
	value_changed.emit(id)


## Every option of [param section_id] back to its default.
func reset(section_id: String) -> void:
	for section in SECTIONS:
		if section.id == section_id:
			for option in section.options:
				if option.has("default"):
					set_value(option.id, option.default)


## The value as the menu shows it: "Fullscreen", "On", "80%", "×1.25", "W".
func text(id: String) -> String:
	var option := find(id)
	var value: Variant = values.get(id)
	match option.kind:
		"choice":
			return option.choices[value]
		"toggle":
			return "On" if value else "Off"
		"bind":
			return OS.get_keycode_string(value)
		"slider":
			match option.get("format", ""):
				"percent":
					return "%d%%" % roundi(value * 100)
				"degrees":
					return "%d°" % roundi(value)
				"times":
					return "×%.2f" % value
			return str(value)
	return ""


## The options changed from their defaults, as "Field of view 90°, V-Sync Off", for the
## prototype's state readout.
func changed_summary() -> String:
	var parts: PackedStringArray = []
	for section in SECTIONS:
		for option in section.options:
			if option.has("default") and values[option.id] != option.default:
				parts.append("%s %s%s" % [option.label, text(option.id), " (stub)" if option.get("stub", false) else ""])
	return ", ".join(parts) if parts else "all defaults"


func _apply(id: String) -> void:
	var value: Variant = values[id]
	var viewport := scene.get_viewport() if scene else null
	match id:
		"display_mode":
			DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN][value])
		"window_size":
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_size([Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)][value])
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = [30, 60, 120, 144, 0][value]
		"msaa":
			viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][value]
		"render_scale":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if value < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = value
		"fov":
			var camera := viewport.get_camera_3d()
			if camera:
				camera.fov = value
		"brightness":
			var world := scene.find_children("*", "WorldEnvironment", false, false)
			if world:
				var env: Environment = (world[0] as WorldEnvironment).environment
				env.adjustment_enabled = true
				env.adjustment_brightness = value
		"master":
			AudioServer.set_bus_mute(0, value <= 0.0)
			AudioServer.set_bus_volume_db(0, linear_to_db(value) if value > 0.0 else -80.0)
		"music":
			var bus := AudioServer.get_bus_index(MusicBox.BUS)
			if bus >= 0:
				AudioServer.set_bus_mute(bus, value <= 0.0)
				AudioServer.set_bus_volume_db(bus, linear_to_db(value) if value > 0.0 else -80.0)
		"mouse_sensitivity":
			var player := scene.get_node_or_null("Player") as Player
			if player:
				player.look_sensitivity = value
		"help_line":
			var help := scene.find_child("Help", true, false) as Control
			if help:
				help.visible = value
	if id.begins_with("bind_"):
		var action: String = find(id).action
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key := InputEventKey.new()
		key.physical_keycode = value
		InputMap.action_add_event(action, key)


## A widget for [param option], wired to [member values]: a slider with its value, a
## "◀ value ▶" button that ←/→ (or a click) cycles for a choice or a toggle, a key to
## rebind, or a plain button. [param on_focus] is called with the option when it gets the
## focus, so a variant can show its help.
func make_widget(option: Dictionary, on_focus: Callable) -> Control:
	var id: String = option.id
	var widget: Control
	match option.kind:
		"slider":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var slider := HSlider.new()
			slider.min_value = option.min
			slider.max_value = option.max
			slider.step = option.step
			slider.value = values[id]
			slider.custom_minimum_size.x = 200
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var label := Label.new()
			label.custom_minimum_size.x = 56
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.text = text(id)
			slider.value_changed.connect(func(v: float) -> void:
				set_value(id, v)
				label.text = text(id))
			slider.focus_entered.connect(on_focus.bind(option))
			slider.mouse_entered.connect(on_focus.bind(option))
			row.add_child(slider)
			row.add_child(label)
			widget = row
		"choice", "toggle":
			var button := CycleButton.new()
			button.options = self
			button.option = option
			button.focus_entered.connect(on_focus.bind(option))
			button.mouse_entered.connect(on_focus.bind(option))
			widget = button
		"bind":
			var bind := KeyButton.new()
			bind.options = self
			bind.option = option
			bind.focus_entered.connect(on_focus.bind(option))
			bind.mouse_entered.connect(on_focus.bind(option))
			widget = bind
		"button":
			var plain := Button.new()
			plain.text = option.label
			plain.pressed.connect(func() -> void: reset("controls"))
			plain.focus_entered.connect(on_focus.bind(option))
			plain.mouse_entered.connect(on_focus.bind(option))
			widget = plain
	widget.name = id
	if option.get("stub", false):
		widget.tooltip_text = "Prototype: not wired to the game yet"
	return widget


## The help line for [param option], with a note when the game doesn't do it yet.
static func help(option: Dictionary) -> String:
	var line: String = option.get("help", "")
	if option.kind == "bind":
		line = "Press, then press the new key. The controller's buttons stay as they are."
	elif option.kind == "button":
		line = "Puts every key back where it was."
	if option.get("stub", false):
		line += "  [prototype: not wired yet]"
	return line


## A choice or toggle as one focusable button, "◀  Fullscreen  ▶": ←/→ step through the
## values, a click or A steps forward.
class CycleButton extends Button:
	var options: MenuProtoOptions
	var option: Dictionary

	func _ready() -> void:
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		custom_minimum_size.x = 220
		pressed.connect(_step.bind(1))
		options.value_changed.connect(func(id: String) -> void:
			if id == option.id:
				_refresh())
		_refresh()

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			_step(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			_step(1)
			accept_event()

	func _step(by: int) -> void:
		if option.kind == "toggle":
			options.set_value(option.id, not options.values[option.id])
		else:
			var count: int = option.choices.size()
			options.set_value(option.id, posmod(options.values[option.id] + by, count))

	func _refresh() -> void:
		text = "◀   %s   ▶" % options.text(option.id)


## A key binding: press it, then press the new key.
class KeyButton extends Button:
	var options: MenuProtoOptions
	var option: Dictionary
	var _listening := false

	func _ready() -> void:
		custom_minimum_size.x = 120
		pressed.connect(func() -> void:
			_listening = true
			text = "Press a key…")
		options.value_changed.connect(func(id: String) -> void:
			if id == option.id:
				text = options.text(option.id))
		text = options.text(option.id)

	func _input(event: InputEvent) -> void:
		if not _listening or not event is InputEventKey or not event.pressed:
			return
		_listening = false
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			text = options.text(option.id)
			return
		options.set_value(option.id, event.physical_keycode)
