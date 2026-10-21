extends SceneTree
## Image work for tools/pbr_texture.sh, on the maps of one PBR texture set.
##
## orm <out.jpg> <roughness> <ao or -> <metalness or ->
##   Packs the three maps into one ORM texture (red AO, green roughness, blue metalness), as
##   Godot's ORMMaterial3D reads it. A missing AO map counts as white (no occlusion), a
##   missing metalness map as black (not metal).
## turn <folder>
##   Turns the set's albedo.jpg, normal.jpg and orm.jpg a quarter turn clockwise, for a set
##   whose boards or logs run the wrong way, and turns the normal map's slopes with it.
##
## Usage: godot --headless --script tools/pbr_maps.gd -- <command> <args>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var error := OK
	match args[0]:
		"orm": error = _orm(args[1], args[2], args[3], args[4])
		"turn": error = _turn(args[1])
		_: error = ERR_INVALID_PARAMETER
	if error != OK:
		printerr("%s failed: %s" % [args, error_string(error)])
	quit(error)


func _orm(out: String, rough_path: String, ao_path: String, metal_path: String) -> Error:
	var rough := _load(rough_path)
	var size := rough.get_size()
	var ao := _load(ao_path, size)
	var metal := _load(metal_path, size)
	var orm := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for y in size.y:
		for x in size.x:
			orm.set_pixel(x, y, Color(
					ao.get_pixel(x, y).r if ao else 1.0,
					rough.get_pixel(x, y).r,
					metal.get_pixel(x, y).r if metal else 0.0))
	return orm.save_jpg(out, 0.92)


func _turn(folder: String) -> Error:
	for map in ["albedo", "normal", "orm"]:
		var path := folder.path_join(map + ".jpg")
		var image := _load(path)
		image.rotate_90(CLOCKWISE)
		if map == "normal":
			# A slope to the right now points down the image, and one up it to the right
			# (OpenGL normal maps: red is right, green is up).
			for y in image.get_height():
				for x in image.get_width():
					var n := image.get_pixel(x, y)
					image.set_pixel(x, y, Color(n.g, 1.0 - n.r, n.b))
		var error := image.save_jpg(path, 0.92)
		if error != OK:
			return error
	return OK


## The map at [param path], scaled to [param size] if given; null for "-".
func _load(path: String, size := Vector2i.ZERO) -> Image:
	if path == "-":
		return null
	var image := Image.load_from_file(path)
	image.convert(Image.FORMAT_RGB8)
	if size != Vector2i.ZERO and image.get_size() != size:
		image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	return image
