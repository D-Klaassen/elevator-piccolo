class_name Greybox
## Helpers for building primitive greybox geometry from code.


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


## Adds a box mesh to [param parent]. When [param with_collision] is true and the
## parent is not already a physics body, the box gets its own StaticBody3D.
static func box(parent: Node3D, size: Vector3, center: Vector3, color: Color, with_collision := true) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material(color)
	mesh.mesh = box_mesh

	if not with_collision:
		mesh.position = center
		parent.add_child(mesh)
		return mesh

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape

	if parent is PhysicsBody3D:
		mesh.position = center
		shape.position = center
		parent.add_child(mesh)
		parent.add_child(shape)
		return mesh

	var body := StaticBody3D.new()
	body.position = center
	body.add_child(mesh)
	body.add_child(shape)
	parent.add_child(body)
	return body


static func label(parent: Node3D, text: String, pos: Vector3, yaw_degrees: float, font_size := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.004
	l.position = pos
	l.rotation_degrees.y = yaw_degrees
	parent.add_child(l)
	return l
