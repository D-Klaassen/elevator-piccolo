extends Node3D
## Greybox of the rustic cabin: a 3-floor shaft with a hallway on every floor,
## the elevator cab, the player standing inside it and a minimal HUD.

const FLOORS := 3
const HALL_WIDTH := 6.0
const HALL_DEPTH := 4.0
const SHAFT_FRONT := 1.1 ## z where the landing wall starts, just in front of the cab

var _hint_label: Label
var _crosshair: Label
var _looking_label: Label
var _hint_timer: SceneTreeTimer


func _ready() -> void:
	_build_environment()
	_build_shaft()
	for f in FLOORS:
		_build_landing(f)

	var elevator := Elevator.new()
	elevator.floor_count = FLOORS
	add_child(elevator)

	var player := Player.new()
	player.position = Vector3(0, 0.05, -0.3)
	player.rotation_degrees.y = 180.0 # face the doors (+Z)
	add_child(player)

	_build_hud()
	elevator.hint.connect(_show_hint)
	player.looking_at_changed.connect(_on_looking_at_changed)
	_show_hint("Look at the panel on the right and click a button.")


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
	help.text = "WASD walk · mouse look · click a button · Esc frees the mouse"
	help.position = Vector2(16, 12)
	help.modulate = Color(1, 1, 1, 0.6)
	hud.add_child(help)


func _on_looking_at_changed(text: String) -> void:
	_looking_label.text = text
	_crosshair.modulate = Color(1, 0.8, 0.2) if text else Color.WHITE


func _show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_timer = get_tree().create_timer(3.0)
	var timer := _hint_timer
	await timer.timeout
	# Only clear if no newer hint replaced this one.
	if timer == _hint_timer:
		_hint_label.text = ""
