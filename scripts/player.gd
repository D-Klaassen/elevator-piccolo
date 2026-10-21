class_name Player
extends CharacterBody3D
## First-person player: WASD or the left stick to walk, the mouse or the right stick to look,
## click (or A, or E) to press (or talk to) what you look at. Esc or Start opens the pause
## menu ([GameMenu]), which frees the mouse. The actions are set up in [Controls].
## In a chat ([method focus_on]) you stand still and the view turns to the guest.

signal looking_at_changed(text: String)

const SPEED := 2.5
const MOUSE_SENSITIVITY := 0.002 ## radians per pixel
const STICK_LOOK_SPEED := 2.5 ## radians per second with the right stick all the way over
const REACH := 2.0
const FOCUS_SPEED := 10.0 ## how quickly the view turns to a guest you talk to; ~0.3 s
## The metadata the Asset room names a wall or a door panel with, for [method name_of].
const NAME_META := &"display_name"

## How fast the player walks, in metres per second; the Asset room's walk speed slider
## raises it.
var speed := SPEED
## Multiplies [constant MOUSE_SENSITIVITY]; set from [member Settings.mouse_sensitivity].
var mouse_sensitivity := 1.0
## Multiplies [constant STICK_LOOK_SPEED]; set from [member Settings.stick_sensitivity].
var stick_sensitivity := 1.0
## Up looks down and down looks up.
var invert_y := false
## The camera's vertical field of view, in degrees.
var fov := 75.0:
	set(value):
		fov = value
		if _camera:
			_camera.fov = value

var _camera: Camera3D
var _ray: RayCast3D
var _looking_at: Object
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## The guest you're talking to, or null: you can't walk, look away or press anything.
var _focus: Guest


func _ready() -> void:
	Controls.setup()

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)

	_camera = Camera3D.new()
	_camera.position.y = 1.6
	_camera.fov = fov
	add_child(_camera)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -REACH)
	_ray.collision_mask = 1 | Guest.COLLISION_LAYER | AssetTag.COLLISION_LAYER
	_camera.add_child(_ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Takes the look settings from [param settings]: sensitivity, invert and field of view.
func use_settings(settings: Settings) -> void:
	mouse_sensitivity = settings.mouse_sensitivity
	stick_sensitivity = settings.stick_sensitivity
	invert_y = settings.invert_y
	fov = settings.fov


## Holds still and turns the view to [param guest]'s face until [method release].
func focus_on(guest: Guest) -> void:
	_focus = guest


func release() -> void:
	_focus = null


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_focus):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_turn(event.relative * MOUSE_SENSITIVITY * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_press_looked_at()
	elif event.is_action_pressed("interact"):
		_press_looked_at()


func _press_looked_at() -> void:
	if _looking_at and _looking_at.has_method("press"):
		# Handled, so the press that starts a chat doesn't also say a reply.
		get_viewport().set_input_as_handled()
		_looking_at.press()


## Turns right by [code]by.x[/code] and looks down by [code]by.y[/code] radians (up, with
## [member invert_y]).
func _turn(by: Vector2) -> void:
	rotate_y(-by.x)
	_camera.rotate_x(by.y if invert_y else -by.y)
	_camera.rotation.x = clampf(_camera.rotation.x, -1.4, 1.4)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Vector2.ZERO if is_instance_valid(_focus) else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	if is_instance_valid(_focus):
		_turn_to(_focus.mouth(), 1.0 - exp(-FOCUS_SPEED * delta))
		_update_looking_at()
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		# Squared, so small tilts aim finely and a full tilt still turns quickly.
		_turn(look * look.length() * STICK_LOOK_SPEED * stick_sensitivity * delta)

	_update_looking_at()


## Turns the view [param weight] of the way (0 to 1) towards looking at [param point].
func _turn_to(point: Vector3, weight: float) -> void:
	var to := point - _camera.global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), weight)
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.4, 1.4)
	_camera.rotation.x = lerp_angle(_camera.rotation.x, pitch, weight)


func _update_looking_at() -> void:
	var target: Object = _ray.get_collider() if _ray.is_colliding() else null
	if target == _looking_at:
		return
	_looking_at = target
	looking_at_changed.emit(name_of(target))


## What the HUD calls [param target] while you look at it: the [code]display_name[/code] of
## a button, a guest or an [AssetTag], or the [code]display_name[/code] metadata the Asset
## room puts on a wall; "" for anything else.
static func name_of(target: Object) -> String:
	if target == null:
		return ""
	if "display_name" in target:
		return target.display_name
	return target.get_meta(NAME_META, "")
