class_name Guest
extends StaticBody3D
## A guest, one of Kenney's Mini Characters. Waits in the hallway, rides the cab and walks
## out on their floor. They walk and stand idle, wave when you talk to them, nod when they
## thank you and shake their head when they give up; a Spanish guest may point, hold up
## fingers or mime where they're going ([Gestures]). Look at them and click to hear which
## floor they want. Some guests strike
## up a chat during the ride and wait for your reply. A red "!" above their head means
## they're running out of patience. Whatever a guest says shows in a speech bubble that comes
## out of their mouth, with the language they speak at its top right; for a Spanish guest,
## with what you understood underneath.

signal talked_to ## the player clicked them; a Spanish guest's answer is up to the [GuestManager]

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
const RADIUS := 0.3
const HEIGHT := 1.35 ## the top of their head, at [constant MODEL_SCALE]
## Physics layer value for guests: the player's look ray sees them, the player's body walks through them.
const COLLISION_LAYER := 2
const BUBBLE_TIME := 6.0 ## seconds a speech bubble stays up
const MOUTH_HEIGHT := 1.05 ## where a speech bubble comes out, at [constant MODEL_SCALE]
const BUBBLE_SIDE := 40.0 ## pixels a speech bubble starts beside the mouth, so it doesn't cover the face
const LANGUAGE_GAP := 14.0 ## pixels between the top of a speech bubble and the language it's in
## The name of each language, shown at the top right of a guest's speech bubble.
const LANGUAGE_NAMES := {"en": "English", "es": "Spanish"}

const MODELS: Array[String] = [
	"res://assets/kenney/mini-characters/character-female-a.glb",
	"res://assets/kenney/mini-characters/character-female-b.glb",
	"res://assets/kenney/mini-characters/character-female-c.glb",
	"res://assets/kenney/mini-characters/character-female-d.glb",
	"res://assets/kenney/mini-characters/character-female-e.glb",
	"res://assets/kenney/mini-characters/character-female-f.glb",
	"res://assets/kenney/mini-characters/character-male-a.glb",
	"res://assets/kenney/mini-characters/character-male-b.glb",
	"res://assets/kenney/mini-characters/character-male-c.glb",
	"res://assets/kenney/mini-characters/character-male-d.glb",
	"res://assets/kenney/mini-characters/character-male-e.glb",
	"res://assets/kenney/mini-characters/character-male-f.glb",
]
const MODEL_SCALE := 1.7 ## the Mini Characters are 0.78 m tall; this makes them about 1.3 m
## Animations in the models that loop; the others play once and go back to the loop.
const IDLE := "idle"
const WALK := "walk"
const NOD := "emote-yes"
const HEAD_SHAKE := "emote-no"
const WAVE := Gestures.WAVE

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
var line := "" ## what an English guest says when you click them
var language := "en" ## "en" or "es"
var helpfulness := "" ## for a Spanish guest: a key of [constant Spanish.HELPFULNESS]
var spanish_line: Array = [] ## for a Spanish guest: [Spanish, English] from [constant Spanish.LINES]
var asked := 0 ## how often you clicked them
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

var model := "" ## which of [constant MODELS] they look like
## The animation playing now, or the loop they go back to after a one-off.
var animation := ""

var _tween: Tween
var _animations: AnimationPlayer
var _skeleton: Skeleton3D
var _loop := IDLE
var _one_off := false
var _marker: Label3D
var _bubble: Label3D
var _under: Label3D
var _language_tag: Label3D
var _bubble_timer: SceneTreeTimer
var _speaking := false ## a bubble is up, whether or not you can see the guest right now


func setup(p_home_floor: int, p_destination: int, p_model: String, line_template: String) -> void:
	home_floor = p_home_floor
	destination = p_destination
	model = p_model
	line = line_template % destination
	collision_layer = COLLISION_LAYER
	collision_mask = 0

	var body: Node3D = (load(model) as PackedScene).instantiate()
	body.name = "Body"
	body.scale = Vector3.ONE * MODEL_SCALE
	body.rotation_degrees.y = 180.0 # the models face +Z; a guest faces -Z, as look_at() turns it
	add_child(body)
	_animations = body.find_children("*", "AnimationPlayer", true, false)[0]
	for loop: String in [IDLE, WALK]:
		_animations.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	_animations.animation_finished.connect(_on_animation_finished)
	Gestures.setup(_animations)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	_play_loop(IDLE)

	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = RADIUS
	capsule_shape.height = HEIGHT
	shape.shape = capsule_shape
	shape.position.y = HEIGHT / 2
	add_child(shape)

	_marker = Greybox.label(self, "!", Vector3(0, HEIGHT + 0.2, 0), 0.0, 96)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.modulate = Color(1, 0.2, 0.1)
	_marker.outline_size = 12
	_marker.hide()

	# Both come out of the mouth sideways, the line above it and what you understood below,
	# and draw over the walls, so you see them at eye level wherever the guest stands.
	_bubble = _speech_label("Bubble", 36, 10, VERTICAL_ALIGNMENT_BOTTOM)
	_under = _speech_label("Understood", 26, 8, VERTICAL_ALIGNMENT_TOP)
	_under.modulate = Color(1, 0.85, 0.4)
	# The language they speak, small, just above the bubble's top right corner.
	_language_tag = _speech_label("Language", 22, 6, VERTICAL_ALIGNMENT_CENTER)
	_language_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_language_tag.width = 0.0
	_language_tag.modulate = Color(0.7, 0.85, 1.0)
	_bubble.hide()
	_under.hide()
	_language_tag.hide()


func _speech_label(label_name: String, font_size: int, outline: int, valign: VerticalAlignment) -> Label3D:
	var l := Greybox.label(self, "", Vector3(0, MOUTH_HEIGHT, 0), 0.0, font_size)
	l.name = label_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 1
	l.outline_render_priority = 0
	l.outline_size = outline
	l.width = 400.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = valign
	l.offset = Vector2(BUBBLE_SIDE + l.width / 2, 0)
	return l


func _process(_delta: float) -> void:
	_marker.visible = is_impatient()
	Gestures.keep_upright(_skeleton)
	# The bubble draws over the walls, so hide it while a wall or a door is in between.
	var in_view := _speaking and _in_view()
	_bubble.visible = in_view
	_under.visible = in_view and not _under.text.is_empty()
	_language_tag.visible = in_view


## True when nothing solid is between the camera and their mouth.
func _in_view() -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return true
	var ray := PhysicsRayQueryParameters3D.create(
			camera.global_position, to_global(Vector3(0, MOUTH_HEIGHT, 0)), 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func is_impatient() -> bool:
	match state:
		State.ARRIVING, State.WAITING:
			return waited >= patience * IMPATIENT_SHARE
		State.BOARDING, State.RIDING:
			return fed_up or rode >= ride_patience * IMPATIENT_SHARE
	return false


func press() -> void:
	asked += 1
	if language == "en":
		say(line)
	act(WAVE)
	talked_to.emit()


## Shows [param text] in a speech bubble from their mouth, with [param under] (what you
## understood, and what they do) beneath it and the language they speak above it, for
## [constant BUBBLE_TIME] seconds.
func say(text: String, under := "") -> void:
	_bubble.text = text
	_under.text = under
	_place_language_tag()
	_speaking = true
	_bubble.visible = _in_view()
	_under.visible = _bubble.visible and not under.is_empty()
	_language_tag.visible = _bubble.visible
	_bubble_timer = get_tree().create_timer(BUBBLE_TIME, false)
	# A connection, not an await: it goes away with the guest if they leave first.
	_bubble_timer.timeout.connect(_hide_bubble.bind(_bubble_timer))


## Hides the bubble, unless a newer one than [param timer]'s replaced it.
func _hide_bubble(timer: SceneTreeTimer) -> void:
	if timer == _bubble_timer:
		_speaking = false
		_bubble.hide()
		_under.hide()
		_language_tag.hide()


func bubble_text() -> String:
	return _bubble.text if _speaking else ""


func under_text() -> String:
	return _under.text if _speaking else ""


func language_tag_text() -> String:
	return _language_tag.text if _speaking else ""


## Puts the language tag a little above the top right corner of the bubble's text: the
## bubble grows up from the mouth, so that corner depends on how long the line is.
func _place_language_tag() -> void:
	_language_tag.text = LANGUAGE_NAMES.get(language, language)
	var font: Font = _bubble.font if _bubble.font else ThemeDB.fallback_font
	# Wrapped the way the bubble wraps it, without the space at the end of a wrapped line.
	var wrap := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_TRIM_EDGE_SPACES
	var text := font.get_multiline_string_size(_bubble.text, HORIZONTAL_ALIGNMENT_LEFT, _bubble.width, _bubble.font_size, -1, wrap)
	var tag := font.get_string_size(_language_tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _language_tag.font_size)
	# Left-aligned labels start at their offset.
	_language_tag.offset = Vector2(_bubble.offset.x + text.x - tag.x, text.y + LANGUAGE_GAP + tag.y / 2)


func reply_line(r: Reply) -> String:
	return chat.replies[r]


## Walks through [param points] (global positions) one after the other, then calls [param on_done].
func walk(points: Array[Vector3], on_done := Callable(), delay := 0.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_callback(_play_loop.bind(WALK))
	var from := global_position
	for p in points:
		_tween.tween_callback(face.bind(p))
		_tween.tween_property(self, "global_position", p, from.distance_to(p) / WALK_SPEED)
		from = p
	_tween.tween_callback(_play_loop.bind(IDLE))
	if on_done.is_valid():
		_tween.tween_callback(on_done)


## Plays [param one_off] ([constant NOD], [constant HEAD_SHAKE] or one of [Gestures]) once,
## then goes back to standing or walking. Gestures are for standing still: a guest who's
## walking doesn't start one, and one who starts walking stops theirs.
func act(one_off: String) -> void:
	if Gestures.is_gesture(one_off) and _loop == WALK:
		return
	_one_off = true
	animation = one_off
	Gestures.show_props(_skeleton, one_off)
	_animations.play(one_off)


## Stands or walks from now on; after the one-off playing now, if there is one.
func _play_loop(loop: String) -> void:
	_loop = loop
	if _one_off:
		if loop != WALK or not Gestures.is_gesture(animation):
			return
		_end_one_off()
	animation = loop
	_animations.play(loop)


func _on_animation_finished(_name: StringName) -> void:
	_end_one_off()
	_play_loop(_loop)


func _end_one_off() -> void:
	_one_off = false
	Gestures.show_props(_skeleton, "")


## Turns to look at [param target] (a global position), staying upright.
func face(target: Vector3) -> void:
	target.y = global_position.y
	if global_position.distance_to(target) > 0.01:
		look_at(target, Vector3.UP)
