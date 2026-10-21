class_name MenuPrototype
extends CanvasLayer
## PROTOTYPE, throw away. Question: what should the menus look like? Three radically
## different variants of the title screen, the pause menu and a full settings menu (Video,
## Audio, Controls, Game), drawn over the live hotel. Flip between them with the floating
## bar at the bottom, or [ and ]. Start it with tools/menu_prototype.sh, which passes
## [code]--menu-prototype[/code] (and optionally [code]--menu-variant=B[/code]).
## Nothing is saved: the settings live in memory, a few apply live, the rest are stubs.

const ARGUMENT := "--menu-prototype"
const VARIANT_ARGUMENT := "--menu-variant="
const VARIANTS: Array[Dictionary] = [
	{"key": "A", "name": "Tabbed window", "script": preload("res://scripts/menu_prototype/variant_a_tabs.gd")},
	{"key": "B", "name": "Elevator panel", "script": preload("res://scripts/menu_prototype/variant_b_elevator.gd")},
	{"key": "C", "name": "Full-screen list", "script": preload("res://scripts/menu_prototype/variant_c_list.gd")},
]
const CREDITS := [
	["Models", "Furniture Kit and Mini Characters by Kenney (CC0)"],
	["Music", "Bossa Nova by Joth, Somewhere in the Elevator by Peachtea, Two Left Socks by congusbongus (all CC0)"],
	["Sounds and textures", "Made in code"],
	["Engine", "Godot Engine"],
]

enum Context { TITLE, PAUSE }

## Survives the scene reloading between shifts, so the variant you picked stays.
static var variant_index := -1
static var options: MenuProtoOptions
## The title screen shows once, at the start of the game, not before every shift.
static var title_shown := false

var context := Context.TITLE
var _scene: Node
var _menu: Control
var _bar: PanelContainer
var _bar_label: Label
var _state_label: Label
var _toast: Label
var _toast_timer: SceneTreeTimer
var _fps: Label
var _dialog: Control


static func requested() -> bool:
	return ARGUMENT in OS.get_cmdline_user_args()


## Adds the prototype to the hotel [param scene] and opens the title screen.
static func install(scene: Node) -> MenuPrototype:
	if variant_index < 0:
		variant_index = 0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with(VARIANT_ARGUMENT):
				variant_index = maxi(0, "ABC".find(arg.trim_prefix(VARIANT_ARGUMENT).to_upper()))
	var menu := MenuPrototype.new()
	menu.name = "MenuPrototype"
	menu._scene = scene
	scene.add_child(menu)
	return menu


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The whole UI scales with the window, from its 1280 × 720 design size: a bigger
	# screen, a bigger menu (and HUD). The real thing would be the project's stretch setting.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if options == null:
		options = MenuProtoOptions.new()
	options.scene = _scene
	for id in options.values:
		if options.values[id] != MenuProtoOptions.find(id).default:
			options.set_value(id, options.values[id]) # the new scene picks up what was changed
	options.value_changed.connect(_on_value_changed)
	_build_bar()
	_fps = Label.new()
	_fps.position = Vector2(16, 40)
	_fps.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	add_child(_fps)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y += 56
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_toast)
	if title_shown:
		_bar.hide()
	else:
		title_shown = true
		open(Context.TITLE)


func _process(_delta: float) -> void:
	_fps.visible = options.values.show_fps
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()


## Opens the menu over the paused hotel: the title screen or the pause menu.
func open(where: Context, screen := "main", section := "video") -> void:
	context = where
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _menu:
		_menu.queue_free()
	var variant: Dictionary = VARIANTS[variant_index]
	_menu = variant.script.new()
	_menu.name = "Variant" + variant.key
	_menu.set("host", self)
	_menu.set("options", options)
	add_child(_menu)
	move_child(_menu, 0)
	_menu.call("open", where, screen, section)
	_show_hud(false)
	_bar.show()
	_update_bar()


func close() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null
	_bar.hide()
	_show_hud(true)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The game's HUD hides behind the menus: the pause menus show the shift themselves.
func _show_hud(on: bool) -> void:
	for layer in _scene.get_children():
		if layer is CanvasLayer and layer != self:
			layer.visible = on


## What a variant shows of the career on the title screen and of the shift in the pause
## menu. Read-only: the prototype changes neither.
func info() -> Dictionary:
	var career := Career.load_saved()
	var hotel := Hotels.at(career.hotel)
	var result := {
		"hotel": hotel.name,
		"shift_number": career.shifts_done + 1,
		"balance": career.balance,
		"has_save": FileAccess.file_exists(Career.save_path),
		"average": career.average_rating(),
	}
	var shift := _scene.get_node_or_null("Shift") as Shift
	if shift:
		result.clock = Shift.format_clock(int(shift.minutes))
		result.stars = shift.stars
		result.money = shift.money()
		result.served = shift.served
		result.lost = shift.lost
	return result


## Called by the variants for what leaves the menu.
func continue_game() -> void:
	close()


func new_career() -> void:
	confirm("Start a new career? Your bank balance, upgrades and hotel are wiped.", func() -> void:
		toast("PROTOTYPE: would wipe the save and start shift 1 in the cabin")
		close())


func quit_to_title() -> void:
	confirm("Back to the title screen? The shift in progress is lost.", func() -> void:
		open(Context.TITLE))


func quit_game() -> void:
	var text := "Quit the game? The shift in progress is lost." if context == Context.PAUSE else "Quit the game?"
	confirm(text, func() -> void: get_tree().quit())


func toast(text: String) -> void:
	_toast.text = text
	_toast_timer = get_tree().create_timer(3.0)
	var timer := _toast_timer
	await timer.timeout
	if timer == _toast_timer:
		_toast.text = ""


## A yes/no question over the menu, the same in every variant. Focus starts on No.
func confirm(text: String, on_yes: Callable) -> void:
	var previous := get_viewport().gui_get_focus_owner()
	_dialog = ColorRect.new()
	_dialog.color = Color(0, 0, 0, 0.6)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dialog)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.65, 0.3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 380
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var yes := Button.new()
	yes.text = "Yes"
	yes.custom_minimum_size.x = 120
	var no := Button.new()
	no.text = "No"
	no.custom_minimum_size.x = 120
	buttons.add_child(yes)
	buttons.add_child(no)
	var dialog := _dialog
	yes.pressed.connect(func() -> void:
		dialog.queue_free()
		_dialog = null
		on_yes.call())
	no.pressed.connect(func() -> void:
		dialog.queue_free()
		_dialog = null
		if is_instance_valid(previous):
			previous.grab_focus())
	no.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _menu:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_PAGEUP:
			_switch(-1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_BRACKETRIGHT or event.keycode == KEY_PAGEDOWN:
			_switch(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _dialog:
			_dialog.queue_free()
			_dialog = null
		elif not _menu.call("back") and context == Context.PAUSE:
			close()


func _switch(by: int) -> void:
	variant_index = posmod(variant_index + by, VARIANTS.size())
	open(context, _menu.get("screen"), _menu.get("section"))


func _on_value_changed(_id: String) -> void:
	_update_bar()


## The floating bar: ◀ the variant ▶, and above it what's been changed. Deliberately not
## part of any variant's look.
func _build_bar() -> void:
	_bar = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.2, 0.55, 0.95)
	style.set_corner_radius_all(20)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	_bar.add_theme_stylebox_override("panel", style)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.position.y -= 10
	add_child(_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_bar.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var previous := Button.new()
	previous.text = "◀"
	previous.flat = true
	previous.focus_mode = Control.FOCUS_NONE
	previous.pressed.connect(_switch.bind(-1))
	row.add_child(previous)
	_bar_label = Label.new()
	_bar_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(_bar_label)
	var next := Button.new()
	next.text = "▶"
	next.flat = true
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_switch.bind(1))
	row.add_child(next)
	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 11)
	_state_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_label.custom_minimum_size.x = 520
	column.add_child(_state_label)


func _update_bar() -> void:
	var variant: Dictionary = VARIANTS[variant_index]
	_bar_label.text = "PROTOTYPE  %s · %s   ([ ] to switch)" % [variant.key, variant.name]
	_state_label.text = "Changed: " + options.changed_summary()
