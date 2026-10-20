extends Node3D
## Greybox of the rustic cabin: a 3-floor shaft with a hallway on every floor,
## the elevator cab, the player standing inside it, the guests, the shift and a minimal HUD.
## Every shift loads the saved career and saves it again once the shift is over.

const FLOORS := 3
const HALL_WIDTH := 6.0
const HALL_DEPTH := 4.0
const SHAFT_FRONT := 1.1 ## z where the landing wall starts, just in front of the cab

var _hint_label: Label
var _crosshair: Label
var _looking_label: Label
var _clock_label: Label
var _stats_label: Label
var _report: ShiftReport
var _replies: ReplyChoices
var _hint_timer: SceneTreeTimer
var _shift: Shift
var _career: Career


func _ready() -> void:
	_career = Career.load_saved()
	_build_environment()
	_build_shaft()
	for f in FLOORS:
		_build_landing(f)

	var elevator := Elevator.new()
	elevator.name = "Elevator"
	elevator.floor_count = FLOORS
	add_child(elevator)

	var guests := GuestManager.new()
	guests.name = "Guests"
	guests.elevator = elevator
	add_child(guests)

	_shift = Shift.new()
	_shift.name = "Shift"
	_shift.guests = guests
	add_child(_shift)

	var player := Player.new()
	player.name = "Player"
	player.position = Vector3(0, 0.05, -0.3)
	player.rotation_degrees.y = 180.0 # face the doors (+Z)
	add_child(player)

	_build_hud()
	elevator.hint.connect(_show_hint)
	guests.said.connect(_show_hint)
	guests.chatting.connect(_replies.show_for)
	guests.reply_closed.connect(_replies.close)
	_replies.chosen.connect(guests.reply)
	_shift.announced.connect(_show_hint)
	_shift.clock_changed.connect(_on_clock_changed)
	_shift.stats_changed.connect(_on_stats_changed)
	_shift.ended.connect(_on_shift_ended)
	player.looking_at_changed.connect(_on_looking_at_changed)
	_on_clock_changed(Shift.START)
	_on_stats_changed()
	_show_hint("Your shift starts. Guests call from the hallways: watch the Calls lamps on your right.")


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.07, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.4)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_shaft() -> void:
	var color := Color(0.25, 0.25, 0.27)
	var height := FLOORS * Elevator.FLOOR_HEIGHT + 1.0
	var center_y := height / 2 - 1.0
	var outer := Elevator.CAB_HALF_WIDTH + 0.15
	# Pit floor, back and side walls around the cab.
	Greybox.box(self, Vector3(2 * outer, 0.2, 2 * outer), Vector3(0, -1.1, 0), color)
	Greybox.box(self, Vector3(2 * outer, height, 0.1), Vector3(0, center_y, -outer), color)
	Greybox.box(self, Vector3(0.1, height, 2 * outer), Vector3(-outer, center_y, 0), color)
	Greybox.box(self, Vector3(0.1, height, 2 * outer), Vector3(outer, center_y, 0), color)


func _build_landing(f: int) -> void:
	var y := f * Elevator.FLOOR_HEIGHT
	var floor_color := Color(0.45, 0.35, 0.25) if f % 2 == 0 else Color(0.35, 0.4, 0.3)
	var wall_color := Color(0.75, 0.7, 0.6)
	var wall_h := Elevator.FLOOR_HEIGHT - 0.2
	var front := Elevator.CAB_HALF_WIDTH + 0.05
	var back := front + HALL_DEPTH

	# Hallway floor; it also acts as the ceiling of the hallway below.
	Greybox.box(self, Vector3(HALL_WIDTH, 0.2, HALL_DEPTH), Vector3(0, y - 0.1, front + HALL_DEPTH / 2), floor_color)

	# Landing wall facing the hallway, with an opening in front of the cab door.
	var half := HALL_WIDTH / 2
	var opening := Elevator.DOOR_OPENING / 2
	var side := half - opening
	var wall_z := SHAFT_FRONT + 0.05
	Greybox.box(self, Vector3(side, wall_h, 0.1), Vector3(-(opening + side / 2), y + wall_h / 2, wall_z), wall_color)
	Greybox.box(self, Vector3(side, wall_h, 0.1), Vector3(opening + side / 2, y + wall_h / 2, wall_z), wall_color)
	var lintel_h := wall_h - Elevator.DOOR_HEIGHT
	Greybox.box(self, Vector3(Elevator.DOOR_OPENING, lintel_h, 0.1), Vector3(0, y + Elevator.DOOR_HEIGHT + lintel_h / 2, wall_z), wall_color)

	# Hallway side and back walls.
	Greybox.box(self, Vector3(0.1, wall_h, HALL_DEPTH), Vector3(-half, y + wall_h / 2, front + HALL_DEPTH / 2), wall_color)
	Greybox.box(self, Vector3(0.1, wall_h, HALL_DEPTH), Vector3(half, y + wall_h / 2, front + HALL_DEPTH / 2), wall_color)
	Greybox.box(self, Vector3(HALL_WIDTH, wall_h, 0.1), Vector3(0, y + wall_h / 2, back), wall_color)

	# Floor sign on the back wall, facing the elevator (-Z).
	var sign_label := Greybox.label(self, "Floor %d" % f, Vector3(0, y + 2.0, back - 0.06), 180.0, 96)
	sign_label.modulate = Color(0.2, 0.15, 0.1)

	var light := OmniLight3D.new()
	light.position = Vector3(0, y + wall_h - 0.4, front + HALL_DEPTH / 2)
	light.omni_range = 5.0
	add_child(light)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 28)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(_crosshair)

	_looking_label = Label.new()
	_looking_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_looking_label.position.y += 32
	_looking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_looking_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_looking_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position.y -= 60
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_hint_label)

	var help := Label.new()
	help.text = "WASD walk · mouse look · click a button or a guest · 1-3 or click to reply · Esc frees the mouse"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position += Vector2(16, -32)
	help.modulate = Color(1, 1, 1, 0.6)
	hud.add_child(help)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 28)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock_label.position.y += 8
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_clock_label)

	_stats_label = Label.new()
	_stats_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_stats_label.position += Vector2(-16, 12)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(_stats_label)

	_replies = ReplyChoices.new()
	_replies.name = "ReplyChoices"
	hud.add_child(_replies)

	_report = ShiftReport.new()
	_report.name = "ShiftReport"
	_report.continued.connect(_on_continued)
	hud.add_child(_report)


func _on_looking_at_changed(text: String) -> void:
	_looking_label.text = text
	_crosshair.modulate = Color(1, 0.8, 0.2) if text else Color.WHITE


func _on_clock_changed(minutes: int) -> void:
	_clock_label.text = Shift.format_clock(minutes)
	if _shift.is_lunch_rush():
		_clock_label.text += "  lunch rush"


func _on_stats_changed() -> void:
	_stats_label.text = "€%.2f   %.1f ★\nserved %d · took the stairs %d" % [_shift.money(), _shift.stars, _shift.served, _shift.lost]


func _on_shift_ended() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.hide()
	_looking_label.text = ""
	_hint_label.text = ""
	_career.record(_shift)
	var error := _career.save()
	if error != OK:
		push_error("Couldn't save the career to %s: %s" % [Career.save_path, error_string(error)])
	_report.show_for(_shift, _career)


## The next shift, or the same one again after being fired: either way a fresh scene
## that picks the career up from the save.
func _on_continued() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_timer = get_tree().create_timer(3.0)
	var timer := _hint_timer
	await timer.timeout
	# Only clear if no newer hint replaced this one.
	if timer == _hint_timer:
		_hint_label.text = ""
