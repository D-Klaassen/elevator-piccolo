class_name Elevator
extends Node3D
## The elevator cab: walls, sliding doors, the button panel, the call panel and the floor indicator.
## It only goes where its floor buttons send it, and the doors only move when you press
## open or close. Floor presses queue up and stay lit; with the doors closed it rides to the
## next one. At a stop with more floors queued it waits until you press close again.
## The door buttons stay lit until the doors have done what was asked.

signal hint(text: String)

enum CallLamp { OFF, ON, BLINKING }

const FLOOR_HEIGHT := 3.5
const CAB_HALF_WIDTH := 1.0
const CAB_HEIGHT := 2.6
const DOOR_HEIGHT := 2.1
const DOOR_OPENING := 1.0
const WALL := 0.1
const SPEED := 0.7 ## metres per second: about 5 s per floor
const DOOR_TIME := 0.8 ## seconds, with the standard doors

@export var floor_count := 3
## Seconds the doors take to open or close. Faster doors lower it.
@export var door_time := DOOR_TIME
## Level of the music upgrade: 0 is a silent cab, from 1 a music box hangs on the back wall.
@export var music_level := 0
## How many guests fit, shown on the plate by the buttons.
@export var capacity := 3
## Level of the call panel upgrade: 0 has no call panel, so only the ding tells you someone
## called; 1 adds a lamp per floor that lights while someone waits there; 2 makes a lamp
## blink when a guest there runs out of patience. The calls are tracked either way.
@export var call_panel_level := 0

var current_floor := 0
var doors_open := true
var door_blockers := 0 ## guests in the doorway; the doors won't close while this is above 0
var dings := 0 ## how many times the call bell rang
var _moving := false
var _doors_busy := false
var _doors_target := true ## where the doors are headed: open (true) or closed (false)
var _doors_moving_to := true
var _door_tween: Tween
var _queue: Array[int] = [] ## floors pressed and not reached yet, in the order they were pressed
var _holding := false ## stopped on the way: waits for a close press before going on
var _buttons := {} ## action -> ElevatorButton

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
	_build_fittings()
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


## Sets the call of floor [param f]: off, waiting, or blinking for an impatient guest.
## Without the call panel upgrade nothing shows it.
func set_call(f: int, state: CallLamp) -> void:
	_call_states[f] = state


func call_state(f: int) -> CallLamp:
	return _call_states[f]


## True when floor [param f]'s call lamp shows light right now: it is lit, or it blinks
## and is in the on half of the blink. A panel without blinking keeps it lit.
func is_call_lamp_lit(f: int) -> bool:
	if _call_lamps.is_empty():
		return false
	match _call_states[f]:
		CallLamp.ON:
			return true
		CallLamp.BLINKING:
			return call_panel_level < 2 or _blink_time < 0.25
	return false


func _update_call_lamps(delta: float) -> void:
	_blink_time = fmod(_blink_time + delta, 0.5)
	for f in _call_lamps.size():
		var lit := is_call_lamp_lit(f)
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
		_buttons[b[0]] = button
		y -= 0.16


func _build_call_panel() -> void:
	_call_states.resize(floor_count) # all OFF
	if call_panel_level == 0:
		return
	# Next to the button panel: one lamp per floor, level with that floor's button.
	var panel_x := -(CAB_HALF_WIDTH - WALL / 2 - 0.02)
	var z := 0.3
	var top := 1.0 + 0.16 * (floor_count + 1)
	Greybox.box(_cab, Vector3(0.02, 0.16 * floor_count + 0.2, 0.2), Vector3(panel_x - 0.01, top - 0.16 * (floor_count - 1) / 2.0 + 0.04, z), Color(0.15, 0.13, 0.12), false)
	var header := Greybox.label(_cab, "Calls", Vector3(panel_x + 0.01, top + 0.14, z), 90.0, 20)
	header.name = "CallPanel"
	header.modulate = Color(0.95, 0.9, 0.8)
	_call_lamps.resize(floor_count)
	for f in floor_count:
		var y := top - 0.16 * (floor_count - 1 - f)
		var lamp := Greybox.box(_cab, Vector3(0.03, 0.1, 0.1), Vector3(panel_x + 0.01, y, z), Color.BLACK, false) as MeshInstance3D
		_call_lamps[f] = lamp
		var caption := Greybox.label(_cab, str(f), Vector3(panel_x + 0.03, y, z), 90.0, 22)
		caption.modulate = Color.BLACK
	_update_call_lamps(0.0)


## What the upgrades add to the cab: the capacity plate and, once bought, the music box.
func _build_fittings() -> void:
	var panel_x := -(CAB_HALF_WIDTH - WALL / 2 - 0.02)
	var plate := Greybox.label(_cab, "Max %d persons" % capacity, Vector3(panel_x, 0.8, 0.6), 90.0, 18)
	plate.name = "CapacityPlate"
	plate.modulate = Color(0.95, 0.9, 0.8)
	if music_level == 0:
		return
	var music_box := Node3D.new()
	music_box.name = "MusicBox"
	music_box.position = Vector3(0, CAB_HEIGHT - 0.35, -(CAB_HALF_WIDTH - WALL / 2 - 0.1))
	_cab.add_child(music_box)
	Greybox.box(music_box, Vector3(0.24 + 0.08 * music_level, 0.2, 0.14), Vector3.ZERO, Color(0.2, 0.14, 0.1), false)
	var note := Greybox.label(music_box, "♪".repeat(music_level), Vector3(0, 0, 0.075), 0.0, 40)
	note.modulate = Color(1, 0.85, 0.4)


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


## Floors pressed and not reached yet, in the order they were pressed.
func queued_floors() -> Array[int]:
	return _queue.duplicate()


func is_lit(action: String) -> bool:
	return _buttons[action].lit


func _request_floor(target: int) -> void:
	if target == current_floor and not _moving:
		hint.emit("You're already on floor %d." % target)
	elif target not in _queue:
		_queue.append(target)
	_update_button_lights()


func _request_doors(open: bool) -> void:
	if open and _moving:
		hint.emit("Not while moving!")
		return
	_doors_target = open
	if not open:
		_holding = false
	if not open and door_blockers > 0:
		hint.emit("Someone is in the doorway: the doors close once they're through.")
	_update_button_lights()


func _physics_process(_delta: float) -> void:
	if not _moving:
		if _doors_busy and _doors_target and not _doors_moving_to:
			_set_doors(true, false) # reopen while closing
		elif not _doors_busy and _doors_target != doors_open:
			if _doors_target or door_blockers == 0:
				_set_doors(_doors_target, false)
		elif not _doors_busy and not doors_open and not _holding and not _queue.is_empty():
			_move_to(_next_stop())
	_update_button_lights()


## The next floor to stop at: heading towards the floor pressed first, stop at the
## nearest pressed floor on the way.
func _next_stop() -> int:
	var direction := signi(_queue[0] - current_floor)
	var best := _queue[0]
	for f in _queue:
		if signi(f - current_floor) == direction and absi(f - current_floor) < absi(best - current_floor):
			best = f
	return best


func _update_button_lights() -> void:
	var fully_open := doors_open and not _doors_busy
	var fully_closed := not doors_open and not _doors_busy
	_buttons["open"].set_lit(_doors_target and not fully_open)
	_buttons["close"].set_lit(not _doors_target and not fully_closed)
	for f in floor_count:
		_buttons[str(f)].set_lit(f in _queue)


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
	_queue.erase(target)
	_holding = not _queue.is_empty()
	_update_button_lights()
	if _holding:
		hint.emit("Ding! Floor %d. Press close to go on to floor %d." % [target, _next_stop()])
	else:
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

	if _door_tween:
		_door_tween.kill()
	_doors_busy = true
	_doors_moving_to = open
	# Reopening halfway takes only the time needed for the rest of the way.
	var time := door_time * absf(_left_door.position.x - left_x) / (DOOR_OPENING / 2)
	_door_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	_door_tween.tween_property(_left_door, "position:x", left_x, time)
	_door_tween.tween_property(_right_door, "position:x", right_x, time)
	_door_tween.chain().tween_callback(_doors_done.bind(open))


func _doors_done(open: bool) -> void:
	doors_open = open
	_doors_busy = false
	_update_button_lights()
