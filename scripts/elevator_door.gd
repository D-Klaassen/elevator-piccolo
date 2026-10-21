class_name ElevatorDoor
extends Node3D
## The sliding panels of one elevator doorway, the cab's or a landing's, and how far open
## they are. They telescope: of each pair, the leading panel travels twice as far as the
## trailing one, so open they end up beside the opening, one behind the other. [enum Style]
## says to which side they go. The [Elevator] moves them; the Asset room has one of each style to try.

## SIDE: one pair, sliding to the +X side (the smallest cab, the only one so far).
## CENTRE: a pair a side, meeting in the middle (for a bigger cab).
enum Style { SIDE, CENTRE }

## How far a trailing panel's steel laps over the leading panel's where they meet, so
## there's no slit to look through. Centre-opening leading panels meet edge to edge, and a
## side-opening door's leading panel shuts against the jamb, flush with the frame.
const OVERLAP := 0.03
## How far a trailing panel's steel reaches in behind the frame on its stack side, so
## looking past the frame at the shut doors you see steel, not the wall.
const REACH := 0.07

var style := Style.SIDE
## How far open, from 0 (shut) to 1 (open).
var amount := 0.0
## Per panel: how far its steel reaches past its share of the opening on the side it shuts
## towards (negative: it stops short of it).
var _front: Array[float] = []
## Leading first: SIDE [leading, trailing]; CENTRE [left leading, left trailing, right
## leading, right trailing].
var _panels: Array[AnimatableBody3D] = []


## Doors of [param style] under [param parent], named [param door_name]: the leading panels
## at z = [param lead_z], the trailing ones at [param trail_z], shut.
static func make(parent: Node3D, door_name: String, style: Style, lead_z: float, trail_z: float) -> ElevatorDoor:
	var door := ElevatorDoor.new()
	door.name = door_name
	door.style = style
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
			# The steel past the panel's share of the opening: towards where it shuts (lapping
			# over the leading panel, meeting the other leading panel, or stopping flush with
			# the frame where it meets the jamb), and for a trailing panel in behind the frame on
			# its stack side.
			var front := OVERLAP
			if lead:
				front = 0.0 if style == Style.CENTRE else -Interior.FRAME_LAP
			var back := 0.0 if lead else REACH
			if side == "Left": # stacks at -X, shuts towards +X
				Interior.door_panel(panel, width, Elevator.DOOR_HEIGHT, Elevator.PANEL_THICKNESS, back, front, Elevator.DOOR_TOP_REACH)
			else:
				Interior.door_panel(panel, width, Elevator.DOOR_HEIGHT, Elevator.PANEL_THICKNESS, front, back, Elevator.DOOR_TOP_REACH)
			door._panels.append(panel)
			door._front.append(front)
	door.show_open(0.0)
	return door


## Gives each leading panel a steel edge from its own face back to z = [param to] (in the
## door's coordinates), just behind its leading edge, so this door and the one it moves with
## beyond it (the cab's and the landing's) look like one thick door, from inside or out.
## Looks only, no collision; in [param surface].
func bridge_to(to: float, surface: Material) -> void:
	var width := panel_width(style)
	for i in range(0, _panels.size(), 2):
		var panel := _panels[i]
		var shuts_towards := 1.0 if style == Style.CENTRE and i < 2 else -1.0
		var edge_x := shuts_towards * (width / 2 + _front[i])
		var depth := to - panel.position.z
		var thick := 0.02
		Greybox.box(panel, Vector3(thick, Elevator.DOOR_HEIGHT - 0.002, absf(depth)),
				Vector3(edge_x - shuts_towards * (0.003 + thick / 2), 0, depth / 2), Color.WHITE, false, surface)


## How wide each panel of [param style] is: shut, they fill the opening side by side.
static func panel_width(style: Style) -> float:
	return Elevator.DOOR_OPENING / (2.0 if style == Style.SIDE else 4.0)


func panels() -> Array[AnimatableBody3D]:
	return _panels


## Puts the panels [param open] of the way open: shut, side by side across the opening;
## open, each pair beside it on its side, every panel's front edge flush with the frame, so
## the open doors line the opening like a jamb. The leading panel travels about twice as
## far as the trailing one.
func show_open(open: float) -> void:
	amount = open
	var width := panel_width(style)
	for i in _panels.size():
		var side := 1.0 if style == Style.SIDE or i >= 2 else -1.0
		var from_stack := 1 if i % 2 == 0 else 0 # the trailing panel is nearest the stack
		var shut_x := Elevator.DOOR_OPENING / 2 - width * (from_stack + 0.5)
		var front_edge := shut_x - width / 2 - _front[i]
		var travel := Elevator.DOOR_OPENING / 2 - Interior.FRAME_LAP - front_edge
		_panels[i].position.x = side * (shut_x + travel * open)
		_panels[i].position.y = Elevator.DOOR_HEIGHT / 2
