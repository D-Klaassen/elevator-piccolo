class_name AssetTag
extends StaticBody3D
## An invisible box round an asset in the Asset room that carries its asset name: looking
## at it shows the name in the HUD, and pressing it does what [member on_press] does, if
## anything. It sits on its own collision layer, which the player's aim sees but nothing
## bumps into, so a tag never changes where you can walk.

const COLLISION_LAYER := 4

## The asset name, shown in the HUD while the player looks at it.
var display_name := ""
## What pressing it does, or nothing.
var on_press := Callable()


## Tags [param node] (and everything under it) as [param asset_name]: a box round its meshes,
## added under it. [param node] must be in the scene tree.
static func cover(node: Node3D, asset_name: String, press := Callable()) -> AssetTag:
	var tag := AssetTag.new()
	tag.name = "AssetTag"
	tag.display_name = asset_name
	tag.on_press = press
	tag.collision_layer = COLLISION_LAYER
	tag.collision_mask = 0
	node.add_child(tag)
	var box := bounds(node)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size.max(Vector3.ONE * 0.02) # something to aim at, even round a flat piece
	shape.shape = box_shape
	shape.position = box.get_center()
	tag.add_child(shape)
	return tag


## Does what [member on_press] does, if anything: the player pressed it.
func press() -> void:
	if on_press.is_valid():
		on_press.call()


## The box round [param node]'s visible meshes, its own included, in its coordinates.
## [param node] must be in the scene tree.
static func bounds(node: Node3D) -> AABB:
	var to_node := node.global_transform.affine_inverse()
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		if not mesh.is_visible_in_tree():
			continue
		var b: AABB = to_node * mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
