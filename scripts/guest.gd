class_name Guest
extends StaticBody3D
## A capsule placeholder guest. Waits in the hallway, rides the cab and walks out on
## their floor. Look at them and click to hear which floor they want.

signal spoke(text: String)

enum State { ARRIVING, WAITING, BOARDING, RIDING, LEAVING }

const WALK_SPEED := 1.2 ## metres per second
const PATIENCE := 75.0 ## seconds a guest waits for the cab before taking the stairs
const IMPATIENT_AFTER := 50.0 ## seconds of waiting before their call lamp starts blinking
const RADIUS := 0.25
const HEIGHT := 1.7
## Physics layer value for guests: the player's look ray sees them, the player's body walks through them.
const COLLISION_LAYER := 2

const LINES: Array[String] = [
	"Floor %d, please.",
	"Hi there! Could you take me to floor %d?",
	"Floor %d, thanks.",
	"I'm going to floor %d.",
	"Morning! Floor %d, if you don't mind.",
]

## Shown in the HUD while the player looks at the guest.
var display_name := "Guest (click to talk)"
var home_floor := 0
var destination := 0
var state := State.ARRIVING
var wait_spot := -1 ## index of the hallway spot while arriving or waiting
var cab_slot := -1 ## index of the spot in the cab while boarding or riding
var line := ""
var waited := 0.0 ## seconds since they called; stops counting once they board

var _tween: Tween


func setup(p_home_floor: int, p_destination: int, color: Color, line_template: String) -> void:
	home_floor = p_home_floor
	destination = p_destination
	line = line_template % destination
	collision_layer = COLLISION_LAYER
	collision_mask = 0

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	capsule.material = Greybox.material(color)
	body.mesh = capsule
	body.position.y = HEIGHT / 2
	add_child(body)

	# A nose so you can tell which way they face (-Z is forward).
	Greybox.box(self, Vector3(0.1, 0.06, 0.12), Vector3(0, 1.45, -RADIUS), color.darkened(0.4), false)

	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = RADIUS
	capsule_shape.height = HEIGHT
	shape.shape = capsule_shape
	shape.position.y = HEIGHT / 2
	add_child(shape)


func is_impatient() -> bool:
	return waited >= IMPATIENT_AFTER


func press() -> void:
	spoke.emit(line)


## Walks through [param points] (global positions) one after the other, then calls [param on_done].
func walk(points: Array[Vector3], on_done := Callable(), delay := 0.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	var from := global_position
	for p in points:
		_tween.tween_callback(face.bind(p))
		_tween.tween_property(self, "global_position", p, from.distance_to(p) / WALK_SPEED)
		from = p
	if on_done.is_valid():
		_tween.tween_callback(on_done)


## Turns to look at [param target] (a global position), staying upright.
func face(target: Vector3) -> void:
	target.y = global_position.y
	if global_position.distance_to(target) > 0.01:
		look_at(target, Vector3.UP)
