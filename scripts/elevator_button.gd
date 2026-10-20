class_name ElevatorButton
extends StaticBody3D
## A physical button in the cab. The player presses it by looking at it and clicking.
## It flashes when pressed, and the elevator keeps it lit while the request is pending.

signal pressed(button: ElevatorButton)

## What the button does: a floor number (0, 1, 2, ...) or one of the door actions.
@export var action := ""
## Shown in the HUD while the player looks at the button.
@export var display_name := ""

## True while what the button asked for hasn't happened yet.
var lit := false

var _mesh: MeshInstance3D
var _base_color := Color(0.85, 0.7, 0.2)
var _flashing := false


## Builds the button: square, or [param round] (a short disc). Its face points along +X.
func setup(p_action: String, p_display_name: String, caption: String, round := false) -> void:
	action = p_action
	display_name = p_display_name

	_mesh = MeshInstance3D.new()
	var shape := CollisionShape3D.new()
	if round:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.04
		disc.bottom_radius = 0.042
		disc.height = 0.024
		disc.material = Greybox.material(_base_color)
		_mesh.mesh = disc
		_mesh.rotation_degrees.z = -90.0 # the disc's top (+Y) facing +X
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.042
		cylinder.height = 0.024
		shape.shape = cylinder
		shape.rotation_degrees.z = -90.0
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.12, 0.12)
		box.material = Greybox.material(_base_color)
		_mesh.mesh = box
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		shape.shape = box_shape
	add_child(_mesh)
	add_child(shape)

	# The panel hangs on the -X wall, so the caption faces +X (into the cab).
	if not caption.is_empty():
		var caption_label := Greybox.label(self, caption, Vector3(0.025, 0, 0), 90.0, 22)
		caption_label.modulate = Color.BLACK


func press() -> void:
	_flash()
	pressed.emit(self)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_show_light(on or _flashing)


func _flash() -> void:
	_flashing = true
	_show_light(true)
	await get_tree().create_timer(0.25).timeout
	_flashing = false
	_show_light(lit)


func _show_light(on: bool) -> void:
	var mat: StandardMaterial3D = _mesh.mesh.material
	mat.albedo_color = Color(1, 1, 0.6) if on else _base_color
	mat.emission_enabled = on
	mat.emission = Color(1, 0.9, 0.4)
