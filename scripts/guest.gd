class_name Guest
extends StaticBody3D
## A capsule placeholder guest. Waits in the hallway, rides the cab and walks out on
## their floor. They greet you when they board or when you first click them, and wait for
## your reply. After that, click them to hear which floor they want. A red "!" above
## their head means they're running out of patience.

signal spoke(text: String)
signal talk_requested ## clicked before they greeted you

enum State { ARRIVING, WAITING, BOARDING, RIDING, LEAVING }
## Your reply to their greeting, in the order the HUD offers them.
enum Reply { FRIENDLY, NEUTRAL, RUDE }

const WALK_SPEED := 1.2 ## metres per second
## How long each kind of guest waits for the cab, and puts up with the ride, in seconds.
const TEMPERAMENTS: Array[Dictionary] = [
	{"name": "hasty", "wait": 30.0, "ride": 18.0},
	{"name": "normal", "wait": 45.0, "ride": 25.0},
	{"name": "patient", "wait": 60.0, "ride": 35.0},
]
const IMPATIENT_SHARE := 2.0 / 3.0 ## share of their patience after which a guest shows it
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
## What a guest says first, and the replies you can give, in [enum Reply] order.
const GREETINGS: Array[Dictionary] = [
	{"line": "Hello!", "replies": ["Hello, welcome aboard!", "Hi.", "Yeah, yeah. Get in."]},
	{"line": "Hi there! Busy day?", "replies": ["Never too busy for you!", "Busy enough.", "Busier now."]},
	{"line": "What a cute little lift!", "replies": ["Thank you, I keep it polished!", "It's a lift.", "Don't touch anything."]},
	{"line": "Phew, long day already.", "replies": ["Then let me take you up in style.", "Mm.", "Not my problem."]},
	{"line": "Lovely hotel, isn't it?", "replies": ["The loveliest! Enjoy your stay.", "It's alright.", "Wait till you see the rooms."]},
]

## Shown in the HUD while the player looks at the guest.
var display_name := "Guest (click to talk)"
var home_floor := 0
var destination := 0
var state := State.ARRIVING
var wait_spot := -1 ## index of the hallway spot while arriving or waiting
var cab_slot := -1 ## index of the spot in the cab while boarding or riding
var line := ""
var greeting: Dictionary = GREETINGS[0]
var greeted := false ## said their greeting (they may still be waiting for your reply)
var reply := Reply.NEUTRAL ## no reply counts as neutral
var answered := false
var temperament := "normal"
var patience := 45.0 ## seconds they wait for the cab before taking the stairs
var ride_patience := 25.0 ## seconds they ride before they want out at the next stop
var waited := 0.0 ## seconds since they called; stops counting once they board
var rode := 0.0 ## seconds since they started boarding
var fed_up := false ## ran out of ride patience: gets out at the next open doors without paying

var _tween: Tween
var _marker: Label3D


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

	_marker = Greybox.label(self, "!", Vector3(0, HEIGHT + 0.25, 0), 0.0, 96)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.modulate = Color(1, 0.2, 0.1)
	_marker.outline_size = 12
	_marker.hide()


func _process(_delta: float) -> void:
	_marker.visible = is_impatient()


func is_impatient() -> bool:
	match state:
		State.ARRIVING, State.WAITING:
			return waited >= patience * IMPATIENT_SHARE
		State.BOARDING, State.RIDING:
			return fed_up or rode >= ride_patience * IMPATIENT_SHARE
	return false


func press() -> void:
	if greeted:
		spoke.emit(line)
	else:
		talk_requested.emit()


func reply_line(r: Reply) -> String:
	return greeting.replies[r]


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
