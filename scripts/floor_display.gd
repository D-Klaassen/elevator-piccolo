class_name FloorDisplay
extends Node3D
## A floor display over an elevator door: a black screen in a steel bezel, the floor
## the cab is at in green digits, and an up and a down arrow beside them that light while
## the cab is on its way in that direction. It faces +Z.

const SIZE := Vector2(0.42, 0.2) ## the bezel
const LIT := Color(0.35, 1.0, 0.4)
const UNLIT := Color(0.07, 0.13, 0.08)

var _digits: Label3D
var _up: MeshInstance3D
var _down: MeshInstance3D


func _init() -> void:
	name = "FloorDisplay"
	_box(Vector3(SIZE.x, SIZE.y, 0.02), Vector3(0, 0, 0.01), Interior.steel())
	var glass := Greybox.material(Color(0.03, 0.035, 0.04))
	glass.roughness = 0.9 # matt, so it shows no glare
	_box(Vector3(SIZE.x - 0.05, SIZE.y - 0.05, 0.004), Vector3(0, 0, 0.022), glass)

	_digits = Greybox.label(self, "0", Vector3(0.07, 0, 0.0245), 0.0, 36)
	_digits.name = "Digits"
	_digits.modulate = LIT
	_digits.outline_size = 0
	_digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_up = _arrow(Vector3(-0.1, 0.03, 0.025), false)
	_up.name = "Up"
	_down = _arrow(Vector3(-0.1, -0.03, 0.025), true)
	_down.name = "Down"


## Shows floor [param f], and lights the arrow for [param direction]: 1 up, -1 down, 0 none.
func show_floor(f: int, direction: int) -> void:
	_digits.text = str(f)
	_light(_up, direction > 0)
	_light(_down, direction < 0)


func shown_floor() -> String:
	return _digits.text


## 1 if the up arrow is lit, -1 if the down arrow is, else 0.
func shown_direction() -> int:
	return 1 if _is_lit(_up) else (-1 if _is_lit(_down) else 0)


func _arrow(at: Vector3, down: bool) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.05, 0.035, 0.004)
	mesh.material = Greybox.material(UNLIT)
	var arrow := MeshInstance3D.new()
	arrow.mesh = mesh
	arrow.position = at
	arrow.rotation_degrees.z = 180.0 if down else 0.0
	add_child(arrow)
	return arrow


func _light(arrow: MeshInstance3D, on: bool) -> void:
	var mat: StandardMaterial3D = arrow.mesh.material
	mat.albedo_color = LIT if on else UNLIT
	mat.emission_enabled = on
	mat.emission = LIT


func _is_lit(arrow: MeshInstance3D) -> bool:
	return (arrow.mesh.material as StandardMaterial3D).emission_enabled


func _box(size: Vector3, at: Vector3, surface: Material) -> void:
	Greybox.box(self, size, at, Color.WHITE, false, surface)
