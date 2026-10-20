class_name Player
extends CharacterBody3D
## First-person player: WASD to walk, mouse to look, click to press (or talk to) what you look at.
## Esc opens the pause menu ([SettingsMenu]), which frees the mouse.

signal looking_at_changed(text: String)

const SPEED := 2.5
const MOUSE_SENSITIVITY := 0.002
const REACH := 2.0

## Multiplies [constant MOUSE_SENSITIVITY]; set from [member Settings.mouse_sensitivity].
var mouse_sensitivity := 1.0

var _camera: Camera3D
var _ray: RayCast3D
var _looking_at: Object
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_setup_inputs()

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


func _setup_inputs() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY * mouse_sensitivity)
		_camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY * mouse_sensitivity)
		_camera.rotation.x = clampf(_camera.rotation.x, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif _looking_at and _looking_at.has_method("press"):
			_looking_at.press()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()

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
