class_name Gestures
## What guests do with their hands, which Kenney's Mini Characters have no animations for:
## waving, pointing down, holding up fingers, and miming where they're going (showing a
## suitcase, eating, swimming, rubbing a shoulder, drinking). The animations are built here
## from arm, head and torso turns and added to a guest's [AnimationPlayer] as the library
## "gestures"; the props they need (fingers, a suitcase, a glass) sit on the guest's hands
## and only show during the gesture.
##
## The characters' arms are one piece from shoulder to fist, so an arm's pose is just the
## way it points. Directions are in the model's own coordinates: +Z is the way they face,
## +Y up, and their right hand is on the -X side.

const LIBRARY := "gestures"
const WAVE := "gestures/wave"
const POINT_DOWN := "gestures/point-down"
const SUITCASE := "gestures/suitcase"
const EATING := "gestures/eating"
const SWIMMING := "gestures/swimming"
const SHOULDER := "gestures/shoulder"
const DRINKING := "gestures/drinking"
const MAX_FINGERS := 10

## How far the fist is from the shoulder, and its end, in model units.
const FIST := 0.235
const FIST_END := 0.277
## Where to take the colour of a guest's hand from: the top of their right fist, in the
## model's rest pose.
const FIST_TOP := Vector3(-0.36, 0.3177, -0.017)
const SKIN := Color("e6ae87") ## if a model's hand colour can't be read

const ARM_RIGHT := "arm-right"
const ARM_LEFT := "arm-left"
const HEAD := "head"
const TORSO := "torso"

## Arms hanging, as in the models' idle animation.
const IDLE_RIGHT := Vector3(-1, -1, 0)
const IDLE_LEFT := Vector3(1, -1, 0)

## Libraries already built, by the path from an [AnimationPlayer]'s root to its skeleton.
static var _libraries := {}
## Hand colours already read, by model.
static var _hand_colours := {}


## The gesture for floor [param f] on fingers: pointing down for the ground floor, else
## that many fingers.
static func fingers(f: int) -> String:
	return POINT_DOWN if f <= 0 else "%s/fingers-%d" % [LIBRARY, mini(f, MAX_FINGERS)]


static func is_gesture(animation: String) -> bool:
	return animation.begins_with(LIBRARY + "/")


## Gives the character that [param player] animates the gestures and their props.
static func setup(player: AnimationPlayer) -> void:
	var skeleton: Skeleton3D = player.get_node(player.root_node).find_children("*", "Skeleton3D", true, false)[0]
	var path := str(player.get_node(player.root_node).get_path_to(skeleton))
	if not _libraries.has(path):
		_libraries[path] = _build_library(path)
	if not player.has_animation_library(LIBRARY):
		player.add_animation_library(LIBRARY, _libraries[path])
	_add_props(skeleton)


## Shows the props [param gesture] needs on [param skeleton]'s hands, and hides the rest.
## "" hides them all.
static func show_props(skeleton: Skeleton3D, gesture: String) -> void:
	var n := 0 # fingers to show; pointing is one
	if gesture.begins_with(LIBRARY + "/fingers-"):
		n = gesture.get_slice("-", 1).to_int()
	elif gesture == POINT_DOWN:
		n = 1
	_show_fingers(skeleton.get_node("HandRight/Fingers"), mini(n, 5))
	_show_fingers(skeleton.get_node("HandLeft/Fingers"), maxi(n - 5, 0))
	(skeleton.get_node("HandRight/Suitcase") as Node3D).visible = gesture == SUITCASE
	(skeleton.get_node("HandRight/Glass") as Node3D).visible = gesture == DRINKING


## The props showing on [param skeleton]'s hands now, by name ("Finger" once per finger).
static func props_showing(skeleton: Skeleton3D) -> Array[String]:
	var showing: Array[String] = []
	for hand in ["HandRight", "HandLeft"]:
		for prop: Node3D in skeleton.get_node(hand).get_children():
			if not prop.visible:
				continue
			if prop.name == "Fingers":
				for finger: Node3D in prop.get_children():
					if finger.visible:
						showing.append("Finger")
			else:
				showing.append(str(prop.name))
	return showing


static func _show_fingers(fingers: Node3D, n: int) -> void:
	fingers.visible = n > 0
	for i in fingers.get_child_count():
		(fingers.get_child(i) as Node3D).visible = i < n


static func _build_library(skeleton_path: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var up := Vector3(-0.45, 1, 0.25)
	var out := Vector3(-0.95, 0.75, 0.25)
	lib.add_animation("wave", _animation(skeleton_path, 1.5, [
		[0.25, {ARM_RIGHT: up, HEAD: Vector3(0, 0, -6)}],
		[0.45, {ARM_RIGHT: out}],
		[0.65, {ARM_RIGHT: up}],
		[0.85, {ARM_RIGHT: out}],
		[1.05, {ARM_RIGHT: up, HEAD: Vector3(0, 0, -6)}],
	]))

	var point := Vector3(-0.35, -0.55, 1)
	var lower := Vector3(-0.35, -0.8, 0.8)
	var look_down := {HEAD: Vector3(12, 0, 0), TORSO: Vector3(5, 0, 0)}
	lib.add_animation("point-down", _animation(skeleton_path, 1.8, [
		[0.3, _with(look_down, {ARM_RIGHT: point})],
		[0.65, _with(look_down, {ARM_RIGHT: lower})],
		[0.95, _with(look_down, {ARM_RIGHT: point})],
		[1.25, _with(look_down, {ARM_RIGHT: lower})],
	]))

	# A hand held up out to the side, the fingers on top; past five, both hands.
	var raised := Vector3(-0.75, 0.9, 0.5)
	var raised_more := Vector3(-0.8, 0.95, 0.65)
	for n in range(1, MAX_FINGERS + 1):
		var keys: Array = []
		for i in 4:
			var right := raised if i % 2 == 0 else raised_more
			var key := {ARM_RIGHT: right}
			if n > 5:
				key[ARM_LEFT] = _mirror(right)
			keys.append([0.3 + i * 0.45, key])
		lib.add_animation("fingers-%d" % n, _animation(skeleton_path, 2.2, keys))

	var carry := Vector3(-0.3, -1, 0.1)
	var held_out := Vector3(-0.35, -0.15, 1)
	lib.add_animation("suitcase", _animation(skeleton_path, 2.4, [
		[0.3, {ARM_RIGHT: carry}],
		[0.7, {ARM_RIGHT: held_out, HEAD: Vector3(10, 0, 0)}],
		[1.1, {ARM_RIGHT: Vector3(-0.35, -0.5, 0.85)}],
		[1.5, {ARM_RIGHT: held_out, HEAD: Vector3(10, 0, 0)}],
		[2.0, {ARM_RIGHT: carry}],
	]))

	# Spooning from a plate held in the left hand to the mouth, three times.
	var plate := {ARM_LEFT: Vector3(0.3, -0.35, 1)}
	var spoon := _with(plate, {ARM_RIGHT: Vector3(-0.15, -0.3, 1), HEAD: Vector3(10, 0, 0)})
	var bite := _with(plate, {ARM_RIGHT: Vector3(0.3, 0.6, 0.75)})
	lib.add_animation("eating", _animation(skeleton_path, 2.4, [
		[0.3, spoon], [0.6, bite], [0.9, spoon], [1.2, bite], [1.5, spoon], [1.8, bite], [2.05, spoon],
	]))

	# The crawl: each arm goes up, forward, down and back, half a stroke apart, while the
	# body rolls and the head turns to breathe.
	var stroke: Array[Vector3] = [Vector3(-0.25, 1, 0.35), Vector3(-0.25, 0, 1), Vector3(-0.25, -1, 0.1), Vector3(-0.4, -0.2, -0.9)]
	var swim: Array = []
	for i in 9:
		swim.append([0.2 + i * 0.2, {
			ARM_RIGHT: stroke[i % 4],
			ARM_LEFT: _mirror(stroke[(i + 2) % 4]),
			TORSO: Vector3(0, 12 if i % 4 < 2 else -12, 0),
			HEAD: Vector3(0, 0, 10 if i % 4 < 2 else -10),
		}])
	lib.add_animation("swimming", _animation(skeleton_path, 2.4, swim))

	# The right hand on the left shoulder, rubbing it, the head tilted away.
	var rub := {ARM_RIGHT: Vector3(0.75, 0.5, 0.45), HEAD: Vector3(0, 0, -14)}
	var rub_low := {ARM_RIGHT: Vector3(0.7, 0.3, 0.6), HEAD: Vector3(0, 0, -10)}
	lib.add_animation("shoulder", _animation(skeleton_path, 2.4, [
		[0.35, rub], [0.65, rub_low], [0.95, rub], [1.25, rub_low], [1.55, rub], [1.85, rub_low],
	]))

	var to_mouth := Vector3(0.3, 0.6, 0.75)
	lib.add_animation("drinking", _animation(skeleton_path, 2.2, [
		[0.35, {ARM_RIGHT: Vector3(-0.2, -0.3, 1)}],
		[0.75, {ARM_RIGHT: to_mouth, HEAD: Vector3(-20, 0, 0)}],
		[1.45, {ARM_RIGHT: to_mouth, HEAD: Vector3(-24, 0, 0)}],
		[1.8, {ARM_RIGHT: Vector3(-0.2, -0.3, 1)}],
	]))
	return lib


## An animation of [param length] seconds through [param keys], each [time, pose]. A pose
## gives the direction an arm points (a [Vector3]) or the turn of the head or torso in
## degrees (also a [Vector3]); what it leaves out is as in the idle animation. The
## animation starts and ends standing idle.
static func _animation(skeleton_path: String, length: float, keys: Array) -> Animation:
	var a := Animation.new()
	a.length = length
	var poses: Array = [[0.0, {}]] + keys + [[length, {}]]
	for bone in [ARM_RIGHT, ARM_LEFT, HEAD, TORSO]:
		var track := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(track, "%s:%s" % [skeleton_path, bone])
		for key: Array in poses:
			a.rotation_track_insert_key(track, key[0], _rotation(bone, key[1].get(bone, null)))
	return a


static func _rotation(bone: String, value: Variant) -> Quaternion:
	match bone:
		ARM_RIGHT:
			return Quaternion(Vector3.LEFT, (value if value != null else IDLE_RIGHT).normalized())
		ARM_LEFT:
			return Quaternion(Vector3.RIGHT, (value if value != null else IDLE_LEFT).normalized())
	var degrees: Vector3 = value if value != null else Vector3.ZERO
	return Quaternion.from_euler(degrees * PI / 180.0)


## The left arm's direction that mirrors the right arm's [param right].
static func _mirror(right: Vector3) -> Vector3:
	return Vector3(-right.x, right.y, right.z)


static func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	return a.merged(b, true)


## Puts the props on [param skeleton]'s hands, hidden: fingers on both fists, a suitcase
## and a glass in the right hand.
static func _add_props(skeleton: Skeleton3D) -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = _hand_colour(skeleton)
	for side in [-1, 1]:
		var hand := BoneAttachment3D.new()
		hand.name = "HandRight" if side < 0 else "HandLeft"
		hand.bone_name = ARM_RIGHT if side < 0 else ARM_LEFT
		skeleton.add_child(hand)
		# Fingers stick out past the fist, side by side across it.
		var fingers := Node3D.new()
		fingers.name = "Fingers"
		fingers.position = Vector3(side * FIST_END, 0, 0)
		hand.add_child(fingers)
		for i in 5:
			# Fanned out a little, with gaps, so you can count them.
			var finger := _box(Vector3(0.08, 0.017, 0.024), skin)
			finger.name = "Finger%d" % (i + 1)
			finger.position = Vector3(side * 0.035, 0.05 - i * 0.025, 0)
			finger.rotation_degrees.z = side * (i - 2) * 9.0
			fingers.add_child(finger)
		_show_fingers(fingers, 0)

	# The suitcase hangs from the fist; [method keep_upright] keeps it hanging straight down.
	var right := skeleton.get_node("HandRight")
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.45, 0.25, 0.12)
	var suitcase := Node3D.new()
	suitcase.name = "Suitcase"
	suitcase.position = Vector3(-FIST, 0, 0)
	suitcase.hide()
	right.add_child(suitcase)
	var case := _box(Vector3(0.06, 0.17, 0.22), leather)
	case.position = Vector3(0, -0.13, 0)
	suitcase.add_child(case)
	var handle := _box(Vector3(0.02, 0.04, 0.08), leather)
	handle.position = Vector3(0, -0.03, 0)
	suitcase.add_child(handle)

	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.7, 0.9, 1.0, 0.7)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glass := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.04
	cylinder.bottom_radius = 0.03
	cylinder.height = 0.11
	cylinder.material = glass_material
	glass.mesh = cylinder
	glass.name = "Glass"
	glass.position = Vector3(-FIST, 0.08, 0)
	glass.hide()
	right.add_child(glass)


## Keeps the suitcase in [param skeleton]'s hand hanging straight down, however the arm
## holding it turns. Call it every frame while it shows.
static func keep_upright(skeleton: Skeleton3D) -> void:
	var suitcase := skeleton.get_node("HandRight/Suitcase") as Node3D
	if suitcase.visible:
		suitcase.global_basis = skeleton.global_basis


static func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var box := MeshInstance3D.new()
	box.mesh = mesh
	return box


## The colour of the top of [param skeleton]'s right fist: their skin, or their glove.
static func _hand_colour(skeleton: Skeleton3D) -> Color:
	var body := skeleton.find_child("body-mesh", false, false) as MeshInstance3D
	if body == null:
		return SKIN
	var key := body.mesh.resource_path + str(body.mesh.get_rid())
	if not _hand_colours.has(key):
		_hand_colours[key] = _read_hand_colour(body.mesh)
	return _hand_colours[key]


static func _read_hand_colour(mesh: Mesh) -> Color:
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	if material == null or material.albedo_texture == null:
		return SKIN
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if vertices.is_empty() or uvs.size() != vertices.size():
		return SKIN
	var nearest := 0
	for v in vertices.size():
		if vertices[v].distance_squared_to(FIST_TOP) < vertices[nearest].distance_squared_to(FIST_TOP):
			nearest = v
	var image := material.albedo_texture.get_image()
	if image == null or image.is_empty():
		return SKIN
	if image.is_compressed() and image.decompress() != OK:
		return SKIN
	var pixel := Vector2i(uvs[nearest] * Vector2(image.get_size())).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(pixel)
