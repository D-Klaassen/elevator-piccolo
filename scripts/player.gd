class_name Player
extends CharacterBody3D
## First-person player: WASD or the left stick to walk, the mouse or the right stick to look,
## click (or A, or E) to press (or talk to) what you look at. Esc or Start opens the pause
## menu ([SettingsMenu]), which frees the mouse. The actions are set up in [Controls].

signal looking_at_changed(text: String)

const SPEED := 2.5
const MOUSE_SENSITIVITY := 0.002 ## radians per pixel
const STICK_LOOK_SPEED := 2.5 ## radians per second with the right stick all the way over
const REACH := 2.0

## Multiplies [constant MOUSE_SENSITIVITY] and [constant STICK_LOOK_SPEED]; set from
## [member Settings.look_sensitivity].
var look_sensitivity := 1.0

var _camera: Camera3D
var _ray: RayCast3D
var _looking_at: Object
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


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
	_camera.fov = 75
	add_child(_camera)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -REACH)
	_ray.collision_mask = 1 | Guest.COLLISION_LAYER
	_camera.add_child(_ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_turn(event.relative * MOUSE_SENSITIVITY * look_sensitivity)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_press_looked_at()
	elif event.is_action_pressed("interact"):
		_press_looked_at()


func _press_looked_at() -> void:
	if _looking_at and _looking_at.has_method("press"):
		_looking_at.press()


## Turns right by [code]by.x[/code] and looks down by [code]by.y[/code] radians.
func _turn(by: Vector2) -> void:
	rotate_y(-by.x)
	_camera.rotate_x(-by.y)
	_camera.rotation.x = clampf(_camera.rotation.x, -1.4, 1.4)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()

	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		# Squared, so small tilts aim finely and a full tilt still turns quickly.
		_turn(look * look.length() * STICK_LOOK_SPEED * look_sensitivity * delta)

	_update_looking_at()


func _update_looking_at() -> void:
	var target: Object = _ray.get_collider() if _ray.is_colliding() else null
	if target == _looking_at:
		return
	_looking_at = target
	var text := ""
	if target is ElevatorButton or target is Guest:
		text = target.display_name
	looking_at_changed.emit(text)
