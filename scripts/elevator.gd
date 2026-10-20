class_name Elevator
extends Node3D
## The elevator cab: walls, sliding doors, the button panel and the floor indicator.
## It never moves on its own: only the in-cab buttons move it or work the doors.

signal hint(text: String)

const FLOOR_HEIGHT := 3.5
const CAB_HALF_WIDTH := 1.0
const CAB_HEIGHT := 2.6
const DOOR_HEIGHT := 2.1
const DOOR_OPENING := 1.0
const WALL := 0.1
const SPEED := 1.5 ## metres per second
const DOOR_TIME := 0.8 ## seconds

@export var floor_count := 3

var current_floor := 0
var doors_open := true
var _moving := false
var _doors_busy := false

var _cab: AnimatableBody3D
var _left_door: AnimatableBody3D
var _right_door: AnimatableBody3D
var _indicator: Label3D


func _ready() -> void:
	_build_cab()
	_build_doors()
	_build_panel()
	_set_doors(true, true)


func _build_cab() -> void:
	_cab = AnimatableBody3D.new()
	_cab.name = "Cab"
	add_child(_cab)

	var wall_color := Color(0.55, 0.42, 0.3)
	var w := CAB_HALF_WIDTH
	var h := CAB_HEIGHT
	# Floor and ceiling.
	Greybox.box(_cab, Vector3(2 * w + WALL, WALL, 2 * w + WALL), Vector3(0, -WALL / 2, 0), Color(0.3, 0.22, 0.15))
	Greybox.box(_cab, Vector3(2 * w + WALL, WALL, 2 * w + WALL), Vector3(0, h + WALL / 2, 0), Color(0.8, 0.78, 0.7))
	# Back and side walls.
	Greybox.box(_cab, Vector3(2 * w, h, WALL), Vector3(0, h / 2, -w), wall_color)
	Greybox.box(_cab, Vector3(WALL, h, 2 * w), Vector3(-w, h / 2, 0), wall_color)
	Greybox.box(_cab, Vector3(WALL, h, 2 * w), Vector3(w, h / 2, 0), wall_color)
	# Front wall with a door opening in the middle.
	var side := w - DOOR_OPENING / 2
	Greybox.box(_cab, Vector3(side, h, WALL), Vector3(-(DOOR_OPENING / 2 + side / 2), h / 2, w), wall_color)
	Greybox.box(_cab, Vector3(side, h, WALL), Vector3(DOOR_OPENING / 2 + side / 2, h / 2, w), wall_color)
	Greybox.box(_cab, Vector3(DOOR_OPENING, h - DOOR_HEIGHT, WALL), Vector3(0, (h + DOOR_HEIGHT) / 2, w), wall_color)

	var light := OmniLight3D.new()
	light.position = Vector3(0, h - 0.3, 0)
	light.omni_range = 4.0
	light.light_energy = 1.2
	_cab.add_child(light)

	# Floor indicator above the door, readable from inside (faces -Z).
	_indicator = Greybox.label(_cab, "0", Vector3(0, DOOR_HEIGHT + 0.25, w - WALL), 180.0, 96)
	_indicator.modulate = Color(1, 0.4, 0.2)


func _build_doors() -> void:
	_left_door = _make_door("LeftDoor")
	_right_door = _make_door("RightDoor")


func _make_door(door_name: String) -> AnimatableBody3D:
	var door := AnimatableBody3D.new()
	door.name = door_name
	_cab.add_child(door)
	Greybox.box(door, Vector3(DOOR_OPENING / 2, DOOR_HEIGHT, 0.05), Vector3.ZERO, Color(0.7, 0.7, 0.75))
	return door


func _build_panel() -> void:
	# Panel on the -X wall: on your right when you face the doors (+Z).
	var panel_x := -(CAB_HALF_WIDTH - WALL / 2 - 0.02)
	var buttons: Array[Array] = []
	for f in range(floor_count - 1, -1, -1):
		buttons.append([str(f), "Floor %d" % f, str(f)])
	buttons.append(["open", "Open doors", "< >"])
	buttons.append(["close", "Close doors", "> <"])

	var y := 1.0 + 0.16 * (buttons.size() - 1)
	for b in buttons:
		var button := ElevatorButton.new()
		button.position = Vector3(panel_x, y, 0.6)
		_cab.add_child(button)
		button.setup(b[0], b[1], b[2])
		button.pressed.connect(_on_button_pressed)
		y -= 0.16


func _on_button_pressed(button: ElevatorButton) -> void:
	match button.action:
		"open":
			_request_doors(true)
		"close":
			_request_doors(false)
		_:
			_request_floor(int(button.action))


func _request_floor(target: int) -> void:
	if _moving or _doors_busy:
		hint.emit("Wait a moment...")
	elif doors_open:
		hint.emit("Close the doors first.")
	elif target == current_floor:
		hint.emit("You're already on floor %d." % target)
	else:
		_move_to(target)


func _request_doors(open: bool) -> void:
	if _moving:
		hint.emit("Not while moving!")
	elif _doors_busy or open == doors_open:
		return
	else:
		_set_doors(open, false)


func _move_to(target: int) -> void:
	_moving = true
	var distance := absf(target - current_floor) * FLOOR_HEIGHT
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_cab, "position:y", target * FLOOR_HEIGHT, distance / SPEED)
	tween.tween_callback(_arrive.bind(target))


func _process(_delta: float) -> void:
	var f := roundi(_cab.position.y / FLOOR_HEIGHT)
	_indicator.text = str(clampi(f, 0, floor_count - 1))


func _arrive(target: int) -> void:
	current_floor = target
	_moving = false
	hint.emit("Ding! Floor %d." % target)


func _set_doors(open: bool, instant: bool) -> void:
	var quarter := DOOR_OPENING / 4
	var left_x := -DOOR_OPENING / 2 - quarter if open else -quarter
	var right_x := DOOR_OPENING / 2 + quarter if open else quarter
	var z := CAB_HALF_WIDTH - WALL
	var y := DOOR_HEIGHT / 2
	if instant:
		_left_door.position = Vector3(left_x, y, z)
		_right_door.position = Vector3(right_x, y, z)
		doors_open = open
		return

	_doors_busy = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(_left_door, "position:x", left_x, DOOR_TIME)
	tween.tween_property(_right_door, "position:x", right_x, DOOR_TIME)
	tween.chain().tween_callback(_doors_done.bind(open))


func _doors_done(open: bool) -> void:
	doors_open = open
	_doors_busy = false
