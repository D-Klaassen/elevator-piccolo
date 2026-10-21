class_name Decor
## Furniture from Kenney's Furniture Kit for the hallways, by what is on the floor: a lobby
## gets sofas, the restaurant tables, the pool loungers, the rooftop bar a bar. Floors
## without a place (the rustic cabin's) get [constant HALLWAY].
##
## Every piece stands along the walls or by the back wall, clear of the path guests walk
## from the back corners to the spots by the elevator. Positions are in hallway
## coordinates: x across (the side walls are at x = ±3), z from the landing wall (z ≈ 1.2)
## to the back wall (z ≈ 5); y is the floor. A piece's turn is how far it is rotated, in
## degrees: at 0 it faces +Z, at 90 it faces +X (out from the left wall), at -90 -X (out
## from the right wall), and at 180 -Z (out from the back wall, towards the elevator).

const DIR := "res://assets/kenney/furniture-kit/"
## The kit is modelled small (a chair is 0.46 m tall); this makes it life size.
const SCALE := 2.0

const HALLWAY: Array = [
	["rugRectangle", Vector3(0, 0, 2.7), 0.0],
	["pottedPlant", Vector3(-2.6, 0, 1.45), 0.0],
	["coatRackStanding", Vector3(2.6, 0, 1.45), 0.0],
	["bench", Vector3(-2.65, 0, 2.7), 90.0],
	["lampSquareFloor", Vector3(2.7, 0, 2.7), 0.0],
	["bookcaseOpenLow", Vector3(0, 0, 4.75), 180.0],
]

const PLACES := {
	"Lobby": [
		["rugRounded", Vector3(0, 0, 2.7), 0.0],
		["loungeSofa", Vector3(-2.55, 0, 2.25), 90.0],
		["loungeChair", Vector3(2.55, 0, 2.6), -90.0],
		["pottedPlant", Vector3(2.6, 0, 1.45), 0.0],
		["tableCoffee", Vector3(0, 0, 4.6), 0.0],
	],
	"Rooms": [
		["rugRectangle", Vector3(0, 0, 2.7), 0.0],
		["sideTable", Vector3(-2.75, 0, 2.6), 90.0],
		["lampRoundFloor", Vector3(2.7, 0, 1.5), 0.0],
		["trashcan", Vector3(2.75, 0, 2.6), 0.0],
		["pottedPlant", Vector3(-2.6, 0, 1.45), 0.0],
	],
	"Restaurant": [
		["tableRound", Vector3(-2.2, 0, 1.95), 0.0],
		["chairCushion", Vector3(-2.2, 0, 3.05), 180.0],
		["tableCloth", Vector3(0, 0, 4.6), 180.0],
		["chairCushion", Vector3(2.65, 0, 2.6), -90.0],
		["pottedPlant", Vector3(2.6, 0, 1.45), 0.0],
	],
	"Pool": [
		["loungeChairRelax", Vector3(-2.45, 0, 1.85), 0.0],
		["loungeChairRelax", Vector3(2.45, 0, 1.85), 0.0],
		["pottedPlant", Vector3(-2.75, 0, 3.1), 0.0],
		["pottedPlant", Vector3(2.75, 0, 3.1), 0.0],
		["rugDoormat", Vector3(0, 0, 1.55), 0.0],
	],
	"Spa": [
		["rugRounded", Vector3(0, 0, 2.7), 0.0],
		["benchCushion", Vector3(-2.65, 0, 2.6), 90.0],
		["benchCushion", Vector3(2.65, 0, 2.6), -90.0],
		["pottedPlant", Vector3(-2.6, 0, 1.45), 0.0],
		["plantSmall2", Vector3(2.75, 0, 1.45), 0.0],
	],
	"Rooftop bar": [
		["kitchenBar", Vector3(0, 0, 4.75), 180.0],
		["stoolBar", Vector3(-0.75, 0, 4.75), 0.0],
		["stoolBar", Vector3(0.75, 0, 4.75), 0.0],
		["pottedPlant", Vector3(-2.6, 0, 1.45), 0.0],
		["loungeChair", Vector3(2.55, 0, 2.6), -90.0],
	],
}


## The furniture for a floor with [param place] on it ("" for none).
static func for_place(place: String) -> Array:
	return PLACES.get(place, HALLWAY)


## Furnishes the hallway at height [param y] under [param parent] for [param place].
## Returns the pieces placed.
static func furnish(parent: Node3D, place: String, y: float) -> Array[Node3D]:
	var placed: Array[Node3D] = []
	for piece: Array in for_place(place):
		placed.append(put(parent, piece[0], piece[1] + Vector3(0, y, 0), piece[2]))
	return placed


## Puts the Furniture Kit model [param model] on the floor under [param parent], centred on
## [param at], turned [param turn] degrees. [param parent] must be in the scene tree.
static func put(parent: Node3D, model: String, at: Vector3, turn := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = model.to_pascal_case()
	parent.add_child(holder, true) # a readable name for a second one too: Plant2, not @Node3D@12
	holder.position = at
	holder.rotation_degrees.y = turn
	var scene: Node3D = (load(DIR + model + ".glb") as PackedScene).instantiate()
	scene.scale = Vector3.ONE * SCALE
	holder.add_child(scene)
	# The kit's models start at a corner; move this one so its base is centred on the holder.
	var box := bounds(scene)
	scene.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return holder


## The box around all of [param node]'s meshes, in its parent's coordinates.
static func bounds(node: Node3D) -> AABB:
	var to_parent := node.get_parent_node_3d().global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = to_parent * mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
