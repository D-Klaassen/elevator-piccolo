class_name Elevator
extends Node3D
## The elevator cab: walls, sliding doors, the button panel, the call panel and the floor indicator.
## It never moves on its own: only the in-cab buttons move it or work the doors.

signal hint(text: String)

enum CallLamp { OFF, ON, BLINKING }

const FLOOR_HEIGHT := 3.5
const CAB_HALF_WIDTH := 1.0
const CAB_HEIGHT := 2.6
const DOOR_HEIGHT := 2.1
const DOOR_OPENING := 1.0
const WALL := 0.1
const SPEED := 0.7 ## metres per second: about 5 s per floor
const DOOR_TIME := 0.8 ## seconds

@export var floor_count := 3

var current_floor := 0
var doors_open := true
var door_blockers := 0 ## guests in the doorway; the doors won't close while this is above 0
var dings := 0 ## how many times the call bell rang
var _moving := false
var _doors_busy := false

var _cab: AnimatableBody3D
var _left_door: AnimatableBody3D
var _right_door: AnimatableBody3D
var _indicator: Label3D
var _call_lamps: Array[MeshInstance3D] = []
var _call_states: Array[CallLamp] = []
var _blink_time := 0.0
var _ding_player: AudioStreamPlayer


func _ready() -> void:
	_build_cab()
	_build_doors()
	_build_panel()
	_build_call_panel()
	_ding_player = AudioStreamPlayer.new()
	_ding_player.stream = _make_ding()
	# Keep ringing through the end-of-shift pause: a paused ding never finishes and leaks at quit.
	_ding_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ding_player)
	_set_doors(true, true)


func get_cab() -> AnimatableBody3D:
	return _cab


## True when the doors are fully open and the cab is standing still.
func is_open_at_rest() -> bool:
	return doors_open and not _moving and not _doors_busy


## Sets the call lamp of floor [param f]: off, lit, or blinking for an impatient guest.
func set_call(f: int, state: CallLamp) -> void:
	_call_states[f] = state


func call_state(f: int) -> CallLamp:
	return _call_states[f]


func _update_call_lamps(delta: float) -> void:
	_blink_time = fmod(_blink_time + delta, 0.5)
	for f in floor_count:
		var lit := _call_states[f] == CallLamp.ON or (_call_states[f] == CallLamp.BLINKING and _blink_time < 0.25)
		var mat: StandardMaterial3D = _call_lamps[f].mesh.material
		mat.albedo_color = Color(1, 0.35, 0.2) if lit else Color(0.2, 0.15, 0.12)
		mat.emission_enabled = lit
		mat.emission = Color(1, 0.3, 0.1)


func ding() -> void:
	dings += 1
	# The headless (Dummy) audio driver never finishes a sound, which leaks it at quit.
	if AudioServer.get_driver_name() != "Dummy":
		_ding_player.play()


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


func _build_call_panel() -> void:
	# Next to the button panel: one lamp per floor, level with that floor's button.
	var panel_x := -(CAB_HALF_WIDTH - WALL / 2 - 0.02)
	var z := 0.3
	var top := 1.0 + 0.16 * (floor_count + 1)
	Greybox.box(_cab, Vector3(0.02, 0.16 * floor_count + 0.2, 0.2), Vector3(panel_x - 0.01, top - 0.16 * (floor_count - 1) / 2.0 + 0.04, z), Color(0.15, 0.13, 0.12), false)
	var header := Greybox.label(_cab, "Calls", Vector3(panel_x + 0.01, top + 0.14, z), 90.0, 20)
	header.modulate = Color(0.95, 0.9, 0.8)
	_call_lamps.resize(floor_count)
	_call_states.resize(floor_count)
	for f in floor_count:
		var y := top - 0.16 * (floor_count - 1 - f)
		var lamp := Greybox.box(_cab, Vector3(0.03, 0.1, 0.1), Vector3(panel_x + 0.01, y, z), Color.BLACK, false) as MeshInstance3D
		_call_lamps[f] = lamp
		var caption := Greybox.label(_cab, str(f), Vector3(panel_x + 0.03, y, z), 90.0, 22)
		caption.modulate = Color.BLACK
		set_call(f, CallLamp.OFF)
	_update_call_lamps(0.0)


## A short bell tone, generated so the project needs no audio files.
static func _make_ding() -> AudioStreamWAV:
	var rate := 22050
	var length := int(rate * 0.9)
	var data := PackedByteArray()
	data.resize(length * 2)
	for i in length:
		var t := float(i) / rate
		var v := (sin(TAU * 1318.5 * t) + 0.35 * sin(TAU * 2637.0 * t)) * exp(-5.0 * t) * 0.45
		data.encode_s16(i * 2, int(v * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


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
	elif not open and door_blockers > 0:
		hint.emit("Wait, someone is in the doorway.")
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


func _process(delta: float) -> void:
	var f := roundi(_cab.position.y / FLOOR_HEIGHT)
	_indicator.text = str(clampi(f, 0, floor_count - 1))
	_update_call_lamps(delta)


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
