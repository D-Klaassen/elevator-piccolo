class_name Settings
extends RefCounted
## The player's settings: volume, look sensitivity and smooth edges. Saved apart from the
## career, so a new career keeps them, and loaded at the start of every shift.

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
## How fast the mouse and the right stick turn the view: multiplies
## [constant Player.MOUSE_SENSITIVITY] and [constant Player.STICK_LOOK_SPEED].
var look_sensitivity := 1.0:
	set(value):
		look_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
## Smooth edges: 2x MSAA on the 3D view. Off for computers that can't keep up with it.
var anti_aliasing := true


## The saved settings, or the defaults if there is no save yet.
static func load_saved() -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return settings
	settings.volume = file.get_value("settings", "volume", settings.volume)
	settings.look_sensitivity = file.get_value("settings", "look_sensitivity", settings.look_sensitivity)
	settings.anti_aliasing = file.get_value("settings", "anti_aliasing", settings.anti_aliasing)
	return settings


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "look_sensitivity", look_sensitivity)
	file.set_value("settings", "anti_aliasing", anti_aliasing)
	return file.save(save_path)


## Sets the master bus to [member volume], muted at 0.
func apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume) if volume > 0.0 else -80.0)


## Turns 2x MSAA on [param viewport] on or off, as [member anti_aliasing] says.
func apply_anti_aliasing(viewport: Viewport) -> void:
	viewport.msaa_3d = Viewport.MSAA_2X if anti_aliasing else Viewport.MSAA_DISABLED
