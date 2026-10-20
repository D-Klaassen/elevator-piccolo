class_name Settings
extends RefCounted
## The player's settings: volume and mouse sensitivity. Saved apart from the career, so a
## new career keeps them, and loaded at the start of every shift.

const DEFAULT_PATH := "user://settings.cfg"
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 3.0

## Where the settings are saved. Tests point this at a temporary file so they never touch
## the real settings.
static var save_path := DEFAULT_PATH

## From 0 (silent) to 1 (full volume).
var volume := 0.8:
	set(value):
		volume = clampf(value, 0.0, 1.0)
## Multiplies [constant Player.MOUSE_SENSITIVITY].
var mouse_sensitivity := 1.0:
	set(value):
		mouse_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)


## The saved settings, or the defaults if there is no save yet.
static func load_saved() -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return settings
	settings.volume = file.get_value("settings", "volume", settings.volume)
	settings.mouse_sensitivity = file.get_value("settings", "mouse_sensitivity", settings.mouse_sensitivity)
	return settings


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	return file.save(save_path)


## Sets the master bus to [member volume], muted at 0.
func apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume) if volume > 0.0 else -80.0)
