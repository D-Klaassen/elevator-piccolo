class_name Elevator
extends Node3D
## The elevator cab: walls, sliding doors, the button panel, the call panel and the floor display.
## It only goes where its floor buttons send it, and the doors only move when you press
## open or close. Floor presses queue up and stay lit; with the doors closed it rides to the
## next one. At a stop with more floors queued it waits until you press close again.
## The door buttons stay lit until the doors have done what was asked.
## Every floor has landing doors in the hallway's opening, which open and close with the
## cab's doors on the floor the cab is at and stay shut everywhere else, and a call button
## beside them: from the hallway it brings the cab to you and opens up when it gets there.
##
## The doors move like a real elevator's: centre-opening, with two panels a side that
## telescope (the leading panel travels twice as far, so they end up stacked); they speed
## up, glide and ease into the wall when opening, and slow to a creep before they meet when
## closing. The cab's doors lead and pick up the landing doors a moment later. A chime rings
## on arrival: once going up, twice going down.

signal hint(text: String)

enum CallLamp { OFF, ON, BLINKING }

const FLOOR_HEIGHT := 3.5
const CAB_HALF_WIDTH := 1.0
const CAB_HEIGHT := 2.6
const DOOR_HEIGHT := 2.1
const DOOR_OPENING := 1.0
const WALL := 0.1
const SPEED := 0.7 ## metres per second: about 5 s per floor
const DOOR_TIME := 1.2 ## seconds the standard doors take to open
const CLOSE_SLOWER := 1.3 ## closing takes this many times as long as opening
const PANEL_WIDTH := DOOR_OPENING / 4 ## two panels a side
const PANEL_THICKNESS := 0.04
const SKIN := 0.04 ## the cab's inner front wall, which the open doors slide behind
## Where the cab's door panels are: the trailing ones just inside its front wall, the
## leading ones in front of them, and the inner front wall just in front of those.
const CAB_TRAIL_Z := CAB_HALF_WIDTH - WALL / 2 - 0.005 - PANEL_THICKNESS / 2
const CAB_LEAD_Z := CAB_TRAIL_Z - PANEL_THICKNESS - 0.005
const CAB_SKIN_Z := CAB_LEAD_Z - PANEL_THICKNESS / 2 - 0.005 - SKIN / 2
const LANDING_TUCK := 0.03 ## metres open landing doors slide past the opening's edge, into the wall
## Share of the way the cab's doors go before they pick up the landing doors.
const LANDING_LAG := 0.06
const ARRIVAL_PAUSE := 0.6 ## seconds between the chime and the doors opening by themselves
const DISPLAY_HEIGHT := DOOR_HEIGHT + 0.3 ## the middle of the floor displays over the doors
## How fast the doors move over the course of opening and of closing, as [time, speed]
## points with straight lines between them (both from 0 to 1, the speed relative): opening
## speeds up, glides and eases into the wall; closing glides, slows to a creep and stops
## when the doors meet.
const OPENING_SPEED: Array[Vector2] = [Vector2(0, 0), Vector2(0.25, 1), Vector2(0.6, 1), Vector2(1, 0)]
const CLOSING_SPEED: Array[Vector2] = [Vector2(0, 0), Vector2(0.2, 1), Vector2(0.55, 1), Vector2(0.78, 0.15), Vector2(1, 0.15)]

@export var floor_count := 3
## Seconds the doors take to open; closing takes [constant CLOSE_SLOWER] times as long.
## Faster doors lower it.
@export var door_time := DOOR_TIME
## Level of the music upgrade: 0 is a silent cab, from 1 a music box hangs on the back wall.
@export var music_level := 0
## How many guests fit, shown on the plate by the buttons.
@export var capacity := 3
## Level of the call panel upgrade: 0 has no call panel, so only the ding tells you someone
## called; 1 adds a lamp per floor that lights while someone waits there; 2 makes a lamp
## blink when a guest there runs out of patience. The calls are tracked either way.
@export var call_panel_level := 0
## z of the middle of the hallways' landing walls, where the landing doors slide.
@export var landing_z := CAB_HALF_WIDTH + 0.15

var current_floor := 0
var doors_open := true
var door_blockers := 0 ## guests in the doorway; the doors won't close while this is above 0
var dings := 0 ## how many times the call bell rang
var chimes := 0 ## how many arrival chimes rang (one going up, two going down)
var door_amount := 1.0 ## how far open the cab's doors are: 0 shut, 1 open
var _moving := false
var _doors_busy := false
var _doors_target := true ## where the doors are headed: open (true) or closed (false)
var _doors_moving_to := true
var _door_tween: Tween
var _queue: Array[int] = [] ## floors pressed and not reached yet, in the order they were pressed
var _holding := false ## stopped on the way: waits for a close press before going on
var _hall_calls: Array[int] = [] ## floors called from their hallway: the doors open on arrival
var _buttons := {} ## action -> ElevatorButton
var _call_buttons: Array[ElevatorButton] = [] ## per floor, in the hallway

var _cab: AnimatableBody3D
## The cab's door panels: left leading, left trailing, right leading, right trailing.
var _door_panels: Array[AnimatableBody3D] = []
var _landing_doors: Array[Array] = [] ## per floor: its panels, in the same order
var _door_from := 1.0 ## door_amount when the doors started moving
var _door_to := 1.0
var _displays: Array[FloorDisplay] = [] ## the cab's, then each landing's
var _direction := 0 ## 1 riding up, -1 down, 0 standing
var _call_lamps: Array[MeshInstance3D] = []
var _call_states: Array[CallLamp] = []
var _blink_time := 0.0
var _ding_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer


func _ready() -> void:
	_build_cab()
	_build_doors()
	_build_landings()
	_build_panel()
	_build_call_panel()
	_build_fittings()
	_ding_player = AudioStreamPlayer.new()
	_ding_player.stream = _make_ding()
	# Keep ringing through the end-of-shift pause: a paused ding never finishes and leaks at quit.
	_ding_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ding_player)
	_chime_player = AudioStreamPlayer.new()
	_chime_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_chime_player)
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


func _open_for_caller() -> void:
	if not _moving:
		_doors_target = true
		_update_button_lights()


## The arrival chime: one tone going up, two going down.
func _chime(going_down: bool) -> void:
	chimes += 2 if going_down else 1
	# The headless (Dummy) audio driver never finishes a sound, which leaks it at quit.
	if AudioServer.get_driver_name() != "Dummy":
		_chime_player.stream = _make_chime(going_down)
		_chime_player.play()


func ding() -> void:
	dings += 1
	# The headless (Dummy) audio driver never finishes a sound, which leaks it at quit.
	if AudioServer.get_driver_name() != "Dummy":
		_ding_player.play()


func _build_cab() -> void:
	_cab = AnimatableBody3D.new()
	_cab.name = "Cab"
	add_child(_cab)

	var walls := Interior.material(Interior.CAB_WALL, true)
	var w := CAB_HALF_WIDTH
	var h := CAB_HEIGHT
	# Floor and ceiling.
	Greybox.box(_cab, Vector3(2 * w + WALL, WALL, 2 * w + WALL), Vector3(0, -WALL / 2, 0), Color.WHITE, true, Interior.material(Interior.CAB_FLOOR, true))
	Greybox.box(_cab, Vector3(2 * w + WALL, WALL, 2 * w + WALL), Vector3(0, h + WALL / 2, 0), Color.WHITE, true, Interior.material(Interior.CAB_CEILING, true))
	# Back and side walls.
	Greybox.box(_cab, Vector3(2 * w, h, WALL), Vector3(0, h / 2, -w), Color.WHITE, true, walls)
	Greybox.box(_cab, Vector3(WALL, h, 2 * w), Vector3(-w, h / 2, 0), Color.WHITE, true, walls)
	Greybox.box(_cab, Vector3(WALL, h, 2 * w), Vector3(w, h / 2, 0), Color.WHITE, true, walls)
	# Front wall with a door opening in the middle.
	var side := w - DOOR_OPENING / 2
	Greybox.box(_cab, Vector3(side, h, WALL), Vector3(-(DOOR_OPENING / 2 + side / 2), h / 2, w), Color.WHITE, true, walls)
	Greybox.box(_cab, Vector3(side, h, WALL), Vector3(DOOR_OPENING / 2 + side / 2, h / 2, w), Color.WHITE, true, walls)
	Greybox.box(_cab, Vector3(DOOR_OPENING, h - DOOR_HEIGHT, WALL), Vector3(0, (h + DOOR_HEIGHT) / 2, w), Color.WHITE, true, walls)
	# And an inner front wall with the same opening, so the doors slide in between the two
	# when they open, as the landing doors slide into the landing wall: from inside the cab
	# the doors sit in the opening the way they do from the hallway.
	var skin_side := w - WALL / 2 - DOOR_OPENING / 2
	for sign_x in [-1.0, 1.0]:
		Greybox.box(_cab, Vector3(skin_side, h, SKIN), Vector3(sign_x * (DOOR_OPENING / 2 + skin_side / 2), h / 2, CAB_SKIN_Z), Color.WHITE, true, walls)
	Greybox.box(_cab, Vector3(DOOR_OPENING, h - DOOR_HEIGHT, SKIN), Vector3(0, (h + DOOR_HEIGHT) / 2, CAB_SKIN_Z), Color.WHITE, true, walls)
	# Handrail, ceiling light and skirting: looks only, no collision.
	var trim := Node3D.new()
	trim.name = "Trim"
	_cab.add_child(trim)
	Interior.trim_cab(trim, w, h, WALL, CAB_SKIN_Z - SKIN / 2)

	var light := OmniLight3D.new()
	light.position = Vector3(0, h - 0.3, 0)
	light.omni_range = 4.0
	light.light_energy = 1.2
	_cab.add_child(light)

	# Floor display above the door, readable from inside (faces -Z).
	var display := FloorDisplay.new()
	display.position = Vector3(0, DISPLAY_HEIGHT, CAB_SKIN_Z - SKIN / 2)
	display.rotation_degrees.y = 180.0
	_cab.add_child(display)
	_displays.append(display)


## The cab's door panels, between its front wall and its inner front wall: the trailing
## panels nearest the front wall, the leading ones in front of them.
func _build_doors() -> void:
	_door_panels = _make_panels(_cab, CAB_LEAD_Z, CAB_TRAIL_Z)


## Four door panels under [param parent]: left leading, left trailing, right leading, right
## trailing, the leading ones at z = [param lead_z] and the trailing ones at [param trail_z].
func _make_panels(parent: Node3D, lead_z: float, trail_z: float) -> Array[AnimatableBody3D]:
	var panels: Array[AnimatableBody3D] = []
	for side in ["Left", "Right"]:
		for lead in [true, false]:
			var panel := AnimatableBody3D.new()
			panel.name = "%sDoor%s" % [side, "Leading" if lead else "Trailing"]
			# Synced to physics, a door's collision only follows its own moves, not the cab's:
			# after a ride it stayed on the floor you left, and you walked through the shut doors.
			panel.sync_to_physics = false
			panel.position.z = lead_z if lead else trail_z
			parent.add_child(panel)
			Interior.door_panel(panel, PANEL_WIDTH, DOOR_HEIGHT, PANEL_THICKNESS)
			panels.append(panel)
	return panels


## Puts [param panels] (as from [method _make_panels]) [param amount] of the way open:
## shut, the four side by side across the opening; open, each side's pair stacked beside
## it, [param tuck] further in.
static func _place_panels(panels: Array, amount: float, tuck := 0.0) -> void:
	for i in panels.size():
		var side := -1.0 if i < 2 else 1.0
		var lead := i % 2 == 0
		var shut_x := PANEL_WIDTH * (0.5 if lead else 1.5)
		var travel := PANEL_WIDTH * (2.0 if lead else 1.0) + tuck
		var panel: Node3D = panels[i]
		panel.position.x = side * (shut_x + travel * amount)
		panel.position.y = DOOR_HEIGHT / 2


## The cab's door panels.
func door_panels() -> Array[AnimatableBody3D]:
	return _door_panels


## Every floor's landing doors, in the opening of its landing wall (they slide into the
## wall to open), and its call button on the hallway side, right of the opening.
func _build_landings() -> void:
	for f in floor_count:
		var landing := Node3D.new()
		landing.name = "Landing%d" % f
		landing.position = Vector3(0, f * FLOOR_HEIGHT, 0)
		add_child(landing)
		# Inside the landing wall: the leading panels on the shaft side, the trailing ones on
		# the hallway side.
		var offset := PANEL_THICKNESS / 2 + 0.0025
		_landing_doors.append(_make_panels(landing, landing_z - offset, landing_z + offset))

		var hall_face := landing_z + WALL / 2
		var plate_at := Vector3(DOOR_OPENING / 2 + 0.3, 1.1, hall_face + 0.006)
		# A round yellow button on a brushed-steel plate.
		Greybox.box(landing, Vector3(0.12, 0.2, 0.012), plate_at, Color.WHITE, false, Interior.brushed_steel())
		var button := ElevatorButton.new()
		button.name = "CallButton"
		button.position = plate_at + Vector3(0, 0, 0.012)
		button.rotation_degrees.y = -90.0 # its face (+X) towards the hallway (+Z)
		landing.add_child(button)
		button.setup("call %d" % f, "Call the elevator", "", true)
		button.pressed.connect(_on_call_pressed.bind(f))
		_call_buttons.append(button)

		# Where the cab is, over the door.
		var display := FloorDisplay.new()
		display.position = Vector3(0, DISPLAY_HEIGHT, hall_face)
		landing.add_child(display)
		_displays.append(display)


## The floor displays: the cab's, then each floor's in its hallway.
func floor_displays() -> Array[FloorDisplay]:
	return _displays


## The landing doors and call button of floor [param f].
func landing_doors(f: int) -> Array:
	return _landing_doors[f]


func call_button(f: int) -> ElevatorButton:
	return _call_buttons[f]


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


## What the upgrades add to the cab: the capacity plate and, once bought, the music box (a
## radio from Kenney's Furniture Kit, with speakers at the higher levels).
func _build_fittings() -> void:
	var panel_x := -(CAB_HALF_WIDTH - WALL / 2 - 0.02)
	var plate := Greybox.label(_cab, "Max %d persons" % capacity, Vector3(panel_x, 0.8, 0.6), 90.0, 18)
	plate.name = "CapacityPlate"
	plate.modulate = Color(0.95, 0.9, 0.8)
	if music_level == 0:
		return
	# A shelf high on the back wall: a radio, then a pair of speakers beside it, then a
	# second pair on the side walls.
	var music_box := Node3D.new()
	music_box.name = "MusicBox"
	music_box.position = Vector3(0, CAB_HEIGHT - 0.6, -(CAB_HALF_WIDTH - WALL / 2 - 0.15))
	_cab.add_child(music_box)
	Greybox.box(music_box, Vector3(1.3, 0.04, 0.3), Vector3(0, -0.02, 0), Color(0.35, 0.24, 0.15), false)
	Decor.put(music_box, "radio", Vector3.ZERO)
	if music_level >= 2:
		for x in [-0.5, 0.5]:
			Decor.put(music_box, "speakerSmall", Vector3(x, 0, 0))
	if music_level >= 3:
		for side in [-1.0, 1.0]:
			var shelf_x: float = side * (CAB_HALF_WIDTH - WALL / 2 - 0.12)
			Greybox.box(music_box, Vector3(0.24, 0.04, 0.3), Vector3(shelf_x, -0.02, 0.6), Color(0.35, 0.24, 0.15), false)
			Decor.put(music_box, "speakerSmall", Vector3(shelf_x, 0, 0.6), -90.0 * side)
	var note := Greybox.label(music_box, "♪".repeat(music_level), Vector3(0, -0.12, 0.16), 0.0, 40)
	note.modulate = Color(1, 0.85, 0.4)


## A soft hall-lantern chime, generated like the ding: one tone, or a high and a lower one
## for [param going_down].
static func _make_chime(going_down: bool) -> AudioStreamWAV:
	var rate := 22050
	var tones: Array[float] = [784.0, 659.3] if going_down else [784.0] # G5, then E5
	var gap := int(rate * 0.45)
	var length := gap * (tones.size() - 1) + int(rate * 1.2)
	var data := PackedByteArray()
	data.resize(length * 2)
	for i in length:
		var v := 0.0
		for n in tones.size():
			var t := float(i - n * gap) / rate
			if t >= 0.0:
				v += (sin(TAU * tones[n] * t) + 0.2 * sin(TAU * tones[n] * 2.0 * t)) * exp(-3.0 * t) * 0.35
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


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


## A call button in floor [param f]'s hallway: you're out there, so the cab comes to you.
## If it's already here it opens up; otherwise it shuts its doors wherever it is, stops
## waiting for a close press, rides here and opens up on arrival.
func _on_call_pressed(_button: ElevatorButton, f: int) -> void:
	if f == current_floor and not _moving:
		_request_doors(true)
		return
	if f not in _hall_calls:
		_hall_calls.append(f)
	if f not in _queue:
		_queue.append(f)
	_holding = false
	_doors_target = false
	_update_button_lights()


func is_called_from_hall(f: int) -> bool:
	return f in _hall_calls


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
		_call_buttons[f].set_lit(f in _hall_calls)


func _move_to(target: int) -> void:
	_moving = true
	_direction = signi(target - current_floor)
	var distance := absf(target - current_floor) * FLOOR_HEIGHT
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_cab, "position:y", target * FLOOR_HEIGHT, distance / SPEED)
	tween.tween_callback(_arrive.bind(target))


func _process(delta: float) -> void:
	var f := clampi(roundi(_cab.position.y / FLOOR_HEIGHT), 0, floor_count - 1)
	for display in _displays:
		display.show_floor(f, _direction)
	_update_call_lamps(delta)


func _arrive(target: int) -> void:
	_direction = 0
	_chime(target < current_floor)
	current_floor = target
	_moving = false
	_queue.erase(target)
	var called := target in _hall_calls
	_hall_calls.erase(target)
	# Wait for a close press before going on, unless someone is waiting in a hallway.
	_holding = not _queue.is_empty() and _hall_calls.is_empty()
	if called:
		# Whoever called is waiting outside: open up once the chime has rung.
		get_tree().create_timer(ARRIVAL_PAUSE, false, true).timeout.connect(_open_for_caller)
	_update_button_lights()
	if _holding:
		hint.emit("Ding! Floor %d. Press close to go on to floor %d." % [target, _next_stop()])
	else:
		hint.emit("Ding! Floor %d." % target)


## Opens or closes the cab's doors, and with them the landing doors of the floor it's at.
## The other floors' landing doors stay shut.
func _set_doors(open: bool, instant: bool) -> void:
	if instant:
		for f in floor_count:
			_place_panels(_landing_doors[f], 0.0)
		_show_doors(1.0 if open else 0.0)
		doors_open = open
		return

	if _door_tween:
		_door_tween.kill()
	_doors_busy = true
	_doors_moving_to = open
	_door_from = door_amount
	_door_to = 1.0 if open else 0.0
	# Reopening halfway takes only the time needed for the rest of the way.
	var time := door_time * (1.0 if open else CLOSE_SLOWER) * absf(_door_to - _door_from)
	_door_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_door_tween.tween_method(_step_doors, 0.0, 1.0, time)
	_door_tween.tween_callback(_doors_done.bind(open))


## Moves the doors [param t] of the way through their current opening or closing, along
## that one's speed curve.
func _step_doors(t: float) -> void:
	var curve := OPENING_SPEED if _door_to > _door_from else CLOSING_SPEED
	_show_doors(lerpf(_door_from, _door_to, travelled(curve, t)))


## Puts the cab's doors [param amount] of the way open, and the landing doors here with
## them, a little behind: the cab's doors pick them up once they've gone [constant
## LANDING_LAG] of the way. Open landing doors slide a little further, into the wall, so
## their edges don't sit flush with the opening's sides and flicker through them.
func _show_doors(amount: float) -> void:
	door_amount = amount
	_place_panels(_door_panels, amount)
	var landing := clampf((amount - LANDING_LAG) / (1.0 - LANDING_LAG), 0.0, 1.0)
	_place_panels(_landing_doors[current_floor], landing, LANDING_TUCK)


## How far along a move with speed curve [param curve] (see [constant OPENING_SPEED]) the
## doors are at time [param t], both from 0 to 1: the area under the curve so far.
static func travelled(curve: Array[Vector2], t: float) -> float:
	var done := 0.0
	var total := 0.0
	for i in curve.size() - 1:
		var a := curve[i]
		var b := curve[i + 1]
		total += (b.x - a.x) * (a.y + b.y) / 2
		if t > a.x:
			var end := minf(t, b.x)
			var speed_at_end := lerpf(a.y, b.y, (end - a.x) / (b.x - a.x))
			done += (end - a.x) * (a.y + speed_at_end) / 2
	return clampf(done / total, 0.0, 1.0)


func _doors_done(open: bool) -> void:
	doors_open = open
	_doors_busy = false
	_update_button_lights()
