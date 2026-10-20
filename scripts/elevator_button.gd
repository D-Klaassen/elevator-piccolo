class_name ElevatorButton
extends StaticBody3D
## A physical button in the cab. The player presses it by looking at it and clicking.

signal pressed(button: ElevatorButton)

## What the button does: a floor number (0, 1, 2, ...) or one of the door actions.
@export var action := ""
## Shown in the HUD while the player looks at the button.
@export var display_name := ""

var _mesh: MeshInstance3D
var _base_color := Color(0.85, 0.7, 0.2)


func setup(p_action: String, p_display_name: String, caption: String) -> void:
	action = p_action
	display_name = p_display_name

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.12, 0.12)
	box.material = Greybox.material(_base_color)
	_mesh.mesh = box
	add_child(_mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	add_child(shape)

	# The panel hangs on the -X wall, so the caption faces +X (into the cab).
	var caption_label := Greybox.label(self, caption, Vector3(0.025, 0, 0), 90.0, 22)
	caption_label.modulate = Color.BLACK


func press() -> void:
	_flash()
	pressed.emit(self)


func _flash() -> void:
	var mat: StandardMaterial3D = _mesh.mesh.material
	mat.albedo_color = Color(1, 1, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.4)
	await get_tree().create_timer(0.25).timeout
	mat.albedo_color = _base_color
	mat.emission_enabled = false
