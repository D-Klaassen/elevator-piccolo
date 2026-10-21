class_name Settings
extends RefCounted
## The player's settings, as the settings menu ([SettingsMenu]) offers them: video, audio,
## controls and game. Saved apart from the career, so a new career keeps them, and loaded at
## the start of every shift. Choices are kept as an index into their list of values (such
## as [constant MSAA]), so the menu and the save agree on what each one means.

const DEFAULT_PATH := "user://settings.cfg"
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 3.0
const MIN_RENDER_SCALE := 0.5
const MIN_FOV := 60.0
const MAX_FOV := 100.0
const MIN_BRIGHTNESS := 0.5
const MAX_BRIGHTNESS := 1.5
## The bus the game's sound effects go through, into the master bus: the dings and chimes.
const EFFECTS_BUS := "Effects"

enum DisplayMode { WINDOWED, FULLSCREEN, BORDERLESS }
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const MAX_FPS: Array[int] = [30, 60, 120, 144, 0] ## 0: no limit
const MSAA: Array[Viewport.MSAA] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
const REPLY_TIMES: Array[float] = [6.0, 12.0, 0.0] ## seconds to answer a chat; 0: no limit
const HINT_TIMES: Array[float] = [3.0, 5.0, 8.0] ## seconds a message stays on screen
const CROSSHAIRS: Array[String] = ["+", "•", ""]
## What is saved, by property name.
const SAVED: Array[String] = [
	"display_mode", "window_size", "vsync", "max_fps", "msaa", "render_scale", "fov", "brightness", "show_fps",
	"volume", "music_volume", "effects_volume", "mute_in_background",
	"mouse_sensitivity", "stick_sensitivity", "invert_y", "keys",
	"reply_time", "hint_time", "crosshair", "help_line", "pause_in_background",
]

## Where the settings are saved. Tests point this at a temporary file so they never touch
## the real settings.
static var save_path := DEFAULT_PATH
## True once the window has been set from the settings, at the start of the game.
static var display_applied := false

# Video
## One of [enum DisplayMode].
var display_mode := DisplayMode.WINDOWED:
	set(value):
		display_mode = clampi(value, 0, DisplayMode.size() - 1) as DisplayMode
## The window's size while windowed: an index into [constant WINDOW_SIZES].
var window_size := 0:
	set(value):
		window_size = clampi(value, 0, WINDOW_SIZES.size() - 1)
var vsync := true
## An index into [constant MAX_FPS].
var max_fps := MAX_FPS.size() - 1:
	set(value):
		max_fps = clampi(value, 0, MAX_FPS.size() - 1)
## Smooth edges: an index into [constant MSAA]. 2x by default; lower for computers that
## can't keep up.
var msaa := 1:
	set(value):
		msaa = clampi(value, 0, MSAA.size() - 1)
## The share of the screen's resolution the 3D view is drawn at, scaled up with FSR below 1.
var render_scale := 1.0:
	set(value):
		render_scale = clampf(value, MIN_RENDER_SCALE, 1.0)
## The camera's vertical field of view, in degrees.
var fov := 75.0:
	set(value):
		fov = clampf(value, MIN_FOV, MAX_FOV)
var brightness := 1.0:
	set(value):
		brightness = clampf(value, MIN_BRIGHTNESS, MAX_BRIGHTNESS)
var show_fps := false

# Audio
## Everything, from 0 (silent) to 1 (full volume).
var volume := 0.8:
	set(value):
		volume = clampf(value, 0.0, 1.0)
## The radio in the cab ([constant MusicBox.BUS]), as a share of [member volume].
var music_volume := 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
## The dings and chimes ([constant EFFECTS_BUS]), as a share of [member volume].
var effects_volume := 1.0:
	set(value):
		effects_volume = clampf(value, 0.0, 1.0)
## Silent while the game's window isn't the one in front.
var mute_in_background := true

# Controls
## How fast the mouse turns the view: multiplies [constant Player.MOUSE_SENSITIVITY].
var mouse_sensitivity := 1.0:
	set(value):
		mouse_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
## How fast the right stick turns the view: multiplies [constant Player.STICK_LOOK_SPEED].
var stick_sensitivity := 1.0:
	set(value):
		stick_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
## Up looks down and down looks up, with the mouse and the right stick.
var invert_y := false
## The key for each of [constant Controls.DEFAULT_KEYS]'s actions that isn't on its default,
## as a physical keycode.
var keys := {}

# Game
## How long you have to answer a chat: an index into [constant REPLY_TIMES].
var reply_time := 0:
	set(value):
		reply_time = clampi(value, 0, REPLY_TIMES.size() - 1)
## How long pay, complaints and hints stay at the bottom of the screen: an index into
## [constant HINT_TIMES].
var hint_time := 0:
	set(value):
		hint_time = clampi(value, 0, HINT_TIMES.size() - 1)
## The mark in the middle of the screen: an index into [constant CROSSHAIRS].
var crosshair := 0:
	set(value):
		crosshair = clampi(value, 0, CROSSHAIRS.size() - 1)
## The line in the bottom left corner that lists the controls.
var help_line := true
## Pauses the shift while the game's window isn't the one in front.
var pause_in_background := true


## The saved settings, or the defaults if there is no save yet. A save from before the
## settings menu had one look sensitivity and smooth edges on or off: they carry over.
static func load_saved() -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return settings
	var old_sensitivity: float = file.get_value("settings", "look_sensitivity", settings.mouse_sensitivity)
	settings.mouse_sensitivity = old_sensitivity
	settings.stick_sensitivity = old_sensitivity
	if file.has_section_key("settings", "anti_aliasing"):
		settings.msaa = 1 if file.get_value("settings", "anti_aliasing") else 0
	for property in SAVED:
		settings.set(property, file.get_value("settings", property, settings.get(property)))
	return settings


func save() -> Error:
	var file := ConfigFile.new()
	for property in SAVED:
		file.set_value("settings", property, get(property))
	return file.save(save_path)


## The key for [param action], one of [constant Controls.DEFAULT_KEYS].
func key(action: String) -> Key:
	return keys.get(action, Controls.DEFAULT_KEYS[action])


## Puts [param action] on [param keycode]. An action already on that key swaps to the key
## [param action] had, so no two actions share a key.
func bind(action: String, keycode: Key) -> void:
	var old := key(action)
	for other in Controls.DEFAULT_KEYS:
		if other != action and key(other) == keycode:
			_set_key(other, old)
	_set_key(action, keycode)


func _set_key(action: String, keycode: Key) -> void:
	if keycode == Controls.DEFAULT_KEYS[action]:
		keys.erase(action)
	else:
		keys[action] = keycode


## Every key back on its default.
func reset_keys() -> void:
	keys = {}


func reply_seconds() -> float:
	return REPLY_TIMES[reply_time]


func hint_seconds() -> float:
	return HINT_TIMES[hint_time]


func crosshair_text() -> String:
	return CROSSHAIRS[crosshair]


## The name of the effects bus, made on first use and kept for the rest of the game.
static func effects_bus() -> String:
	if AudioServer.get_bus_index(EFFECTS_BUS) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, EFFECTS_BUS)
		AudioServer.set_bus_send(index, "Master")
	return EFFECTS_BUS


## Everything a scene follows from the settings: the sound, the keys, smooth edges and the
## render scale on [param viewport], the brightness of [param env], and once a game, the
## window (leaving its size alone at the default, so the game opens as it was started).
func apply_to(viewport: Viewport, env: Environment) -> void:
	if not display_applied:
		display_applied = true
		apply_display(window_size != 0)
	apply_audio()
	apply_keys()
	apply_view(viewport)
	apply_brightness(env)


## Sets the master, music and effects buses to their volumes, each muted at 0.
func apply_audio() -> void:
	_set_bus(0, volume)
	_set_bus(AudioServer.get_bus_index(MusicBox.bus()), music_volume)
	_set_bus(AudioServer.get_bus_index(effects_bus()), effects_volume)


static func _set_bus(index: int, share: float) -> void:
	AudioServer.set_bus_mute(index, share <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(share) if share > 0.0 else -80.0)


## Sets the window: windowed (at [member window_size], unless [param resize] is false),
## fullscreen or borderless, with or without vsync, and the frame rate limit.
func apply_display(resize := true) -> void:
	var mode: DisplayServer.WindowMode = [DisplayServer.WINDOW_MODE_WINDOWED,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN][display_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if resize and display_mode == DisplayMode.WINDOWED and DisplayServer.window_get_size() != WINDOW_SIZES[window_size]:
		DisplayServer.window_set_size(WINDOW_SIZES[window_size])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = MAX_FPS[max_fps]


## Smooth edges and the render scale on [param viewport]'s 3D view.
func apply_view(viewport: Viewport) -> void:
	viewport.msaa_3d = MSAA[msaa]
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale


## [member brightness] on [param env].
func apply_brightness(env: Environment) -> void:
	env.adjustment_enabled = brightness != 1.0
	env.adjustment_brightness = brightness


## Puts every action of [constant Controls.DEFAULT_KEYS] on its key.
func apply_keys() -> void:
	for action in Controls.DEFAULT_KEYS:
		Controls.bind_key(action, key(action))
