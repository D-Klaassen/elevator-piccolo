class_name Guest
extends StaticBody3D
## A capsule placeholder guest. Waits in the hallway, rides the cab and walks out on
## their floor. Look at them and click to hear which floor they want. Some guests strike
## up a chat during the ride and wait for your reply. A red "!" above their head means
## they're running out of patience.

signal spoke(text: String)

enum State { ARRIVING, WAITING, BOARDING, RIDING, LEAVING }
## How well your reply to their chat lands with them.
enum Reply { GOOD, NEUTRAL, BAD }

const WALK_SPEED := 1.2 ## metres per second
## How long each kind of guest waits for the cab, and puts up with the ride, in seconds.
const TEMPERAMENTS: Array[Dictionary] = [
	{"name": "hasty", "wait": 45.0, "ride": 30.0},
	{"name": "normal", "wait": 65.0, "ride": 40.0},
	{"name": "patient", "wait": 90.0, "ride": 55.0},
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
## What a chatty guest says, and the replies you can give, in [enum Reply] order. The best
## reply depends on what they say: not always the warmest one, never an obviously rude one.
const CHATS: Array[Dictionary] = [
	{"line": "Sorry, I'm in a real hurry. Is this thing always this slow?", "replies": [
		"Not long now, I'll have you there in a moment.",
		"It's an old lift.",
		"Ah, but it has history! Built in 1921, the original cables are still...",
	]},
	{"line": "My meeting ran late, and now I've missed lunch.", "replies": [
		"The kitchen does sandwiches till three. Ask for Marta.",
		"That's a shame.",
		"Cheer up! Skipping lunch is good for you, they say.",
	]},
	{"line": "I don't really do small talk, sorry.", "replies": [
		"Of course. A quiet ride it is.",
		"Okay.",
		"Oh, just one question then: where are you from?",
	]},
	{"line": "Lovely day out, isn't it?", "replies": [
		"Perfect for the lake walk, if you have the time.",
		"Not bad at all.",
		"Enjoy it while it lasts, they say rain's coming this afternoon.",
	]},
	{"line": "Will my room be ready? I was told two o'clock.", "replies": [
		"I'll ask the front desk to ring you the moment it is.",
		"Best to ask at the front desk.",
		"They always say two, but between us it's usually more like three.",
	]},
	{"line": "Do you ever get bored, going up and down all day?", "replies": [
		"Never. Every ride is someone new.",
		"Sometimes.",
		"Honestly? You're the first to ask. Nobody really talks to me...",
	]},
	{"line": "Phew, those stairs outside nearly finished me off.", "replies": [
		"Then sit back, this ride's on the house.",
		"They are steep.",
		"Good for the legs, though! I take them twice a day myself.",
	]},
	{"line": "Is there anywhere to get a decent coffee around here?", "replies": [
		"The bakery across the road. Skip ours.",
		"There's a coffee machine in the lounge on floor 1.",
		"Ours is the best in town!",
	]},
]
## What a guest says back, by how well your reply landed.
const REACTIONS: Array[Array] = [
	["Ha! Now that's service.", "Oh, thank you!", "You're good at this."],
	["Hm.", "Right.", "Okay then."],
	["Excuse me?", "Wow. Okay.", "I didn't ask."],
]

## Shown in the HUD while the player looks at the guest.
var display_name := "Guest (click to talk)"
var home_floor := 0
var destination := 0
var state := State.ARRIVING
var wait_spot := -1 ## index of the hallway spot while arriving or waiting
var cab_slot := -1 ## index of the spot in the cab while boarding or riding
var line := ""
var chat := {} ## one of [constant CHATS], or empty for a quiet guest
var chat_at := 0.0 ## seconds into the ride when they start their chat
var chatted := false ## started their chat (they may still be waiting for your reply)
var reply_order: Array[Reply] = [Reply.GOOD, Reply.NEUTRAL, Reply.BAD] ## how the HUD lists the replies
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
	spoke.emit(line)


func reply_line(r: Reply) -> String:
	return chat.replies[r]


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
