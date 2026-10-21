class_name ElevatorDoor
extends Node3D
## The sliding panels of one elevator doorway, the cab's or a landing's, and how far open
## they are. They telescope: of each pair, the leading panel travels twice as far as the
## trailing one, so open they end up stacked beside the opening. [enum Style] says to which
## side they go. The [Elevator] moves them; the Asset room has one of each style to try.

## SIDE: one pair, sliding to the +X side (the smallest cab, the only one so far).
## CENTRE: a pair a side, meeting in the middle (for a bigger cab).
enum Style { SIDE, CENTRE }

var style := Style.SIDE
## How far open, from 0 (shut) to 1 (open).
var amount := 0.0
## Metres open panels slide past the opening's edge, into the wall, so their edges don't sit
## flush with the opening's sides and flicker through them.
var tuck := 0.0
## Leading first: SIDE [leading, trailing]; CENTRE [left leading, left trailing, right
## leading, right trailing].
var _panels: Array[AnimatableBody3D] = []


## Doors of [param style] under [param parent], named [param door_name]: the leading panels
## at z = [param lead_z], the trailing ones at [param trail_z], shut.
static func make(parent: Node3D, door_name: String, style: Style, lead_z: float, trail_z: float, tuck := 0.0) -> ElevatorDoor:
	var door := ElevatorDoor.new()
	door.name = door_name
	door.style = style
	door.tuck = tuck
	parent.add_child(door)
	var width := panel_width(style)
	for side: String in ["Left", "Right"] if style == Style.CENTRE else [""]:
		for lead in [true, false]:
			var panel := AnimatableBody3D.new()
			panel.name = "%sDoor%s" % [side, "Leading" if lead else "Trailing"]
			# Synced to physics, a door's collision only follows its own moves, not the cab's:
			# after a ride it stayed on the floor you left, and you walked through the shut doors.
			panel.sync_to_physics = false
			panel.position.z = lead_z if lead else trail_z
			door.add_child(panel)
			Interior.door_panel(panel, width, Elevator.DOOR_HEIGHT, Elevator.PANEL_THICKNESS)
			door._panels.append(panel)
	door.show_open(0.0)
	return door


## How wide each panel of [param style] is: shut, they fill the opening side by side.
static func panel_width(style: Style) -> float:
	return Elevator.DOOR_OPENING / (2.0 if style == Style.SIDE else 4.0)


func panels() -> Array[AnimatableBody3D]:
	return _panels


## Puts the panels [param open] of the way open: shut, side by side across the opening;
## open, each pair stacked beside it on its side, [member tuck] further in.
func show_open(open: float) -> void:
	amount = open
	var width := panel_width(style)
	for i in _panels.size():
		var side := 1.0 if style == Style.SIDE or i >= 2 else -1.0
		var from_stack := 1 if i % 2 == 0 else 0 # the trailing panel is nearest the stack
		var shut_x := Elevator.DOOR_OPENING / 2 - width * (from_stack + 0.5)
		var travel := width * (from_stack + 1) + tuck
		_panels[i].position.x = side * (shut_x + travel * open)
		_panels[i].position.y = Elevator.DOOR_HEIGHT / 2
