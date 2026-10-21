class_name MusicBox
extends Node3D
## The music upgrade in the cab: a shelf high on the back wall with a radio from Kenney's
## Furniture Kit, a pair of speakers beside it from level 2 and a second pair on the side
## walls at level 3. The radio plays the tracks of [constant TRACKS] its level has
## unlocked, picking the next one at random as each ends (never the same one twice in a
## row, unless it has only the one).
##
## Every level sounds richer: level 1 is a small radio (thin, no bass and no treble),
## level 2's speakers play the full sound and louder, level 3 adds a little echo, as if the
## music filled the cab. The music goes through the [constant BUS] bus into the master
## bus, so the volume setting turns it down with everything else. It keeps playing while
## the game is paused, so you hear the Volume slider work.

## The music bus, made on first use: a small radio's filters, then a room's echo.
const BUS := "Music"
## In the order they unlock: [code]level[/code] is the music level that adds the track,
## [code]gain_db[/code] evens out how loud they are. Where they come from: CREDITS.md.
const TRACKS: Array[Dictionary] = [
	{"name": "Bossa Nova", "path": "res://assets/music/joth-bossa-nova.mp3", "level": 1, "gain_db": 0.0},
	{"name": "Somewhere in the Elevator", "path": "res://assets/music/peachtea-somewhere-in-the-elevator.ogg", "level": 2, "gain_db": 1.0},
	{"name": "Two Left Socks", "path": "res://assets/music/congusbongus-two-left-socks.ogg", "level": 3, "gain_db": -2.0},
]
## By level (from 1): how loud the music plays, whether it sounds like a small radio and
## whether it echoes.
const SOUND: Array[Dictionary] = [
	{},
	{"volume_db": -10.0, "radio": true, "echo": false},
	{"volume_db": -8.0, "radio": false, "echo": false},
	{"volume_db": -6.0, "radio": false, "echo": true},
]
const RADIO_LOW := 300.0 ## Hz: a small radio has no bass below this...
const RADIO_HIGH := 2500.0 ## ...and no treble above this
const SHELF := Color(0.35, 0.24, 0.15)

var level := 1
## The track playing now, from [constant TRACKS]; empty when stopped.
var track := {}

var _player: AudioStreamPlayer3D


func _init(music_level := 1) -> void:
	level = music_level
	name = "MusicBox"


func _ready() -> void:
	Greybox.box(self, Vector3(1.3, 0.04, 0.3), Vector3(0, -0.02, 0), SHELF, false)
	Decor.put(self, "radio", Vector3.ZERO)
	if level >= 2:
		for x in [-0.5, 0.5]:
			Decor.put(self, "speakerSmall", Vector3(x, 0, 0))
	if level >= 3:
		for side in [-1.0, 1.0]:
			var shelf_x: float = side * (Elevator.CAB_HALF_WIDTH - Elevator.WALL / 2 - 0.12)
			Greybox.box(self, Vector3(0.24, 0.04, 0.3), Vector3(shelf_x, -0.02, 0.6), SHELF, false)
			Decor.put(self, "speakerSmall", Vector3(shelf_x, 0, 0.6), -90.0 * side)
	var note := Greybox.label(self, "♪".repeat(level), Vector3(0, -0.12, 0.16), 0.0, 40)
	note.modulate = Color(1, 0.85, 0.4)

	_player = AudioStreamPlayer3D.new()
	_player.name = "Music"
	_player.position = Vector3(0, 0.15, 0.1)
	_player.bus = bus()
	_player.unit_size = 2.5 # about as loud anywhere in the cab, fading out down the hallway
	_player.max_distance = 20.0
	_player.panning_strength = 0.4 # turning your head shouldn't swing it from ear to ear
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(next_track)
	add_child(_player)
	var sound := SOUND[level]
	var index := AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_effect_enabled(index, 0, sound.radio)
	AudioServer.set_bus_effect_enabled(index, 1, sound.radio)
	AudioServer.set_bus_effect_enabled(index, 2, sound.echo)
	next_track()


## The tracks this level has unlocked.
static func playlist(music_level: int) -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	for t in TRACKS:
		if t.level <= music_level:
			unlocked.append(t)
	return unlocked


## The name of the music bus, made on first use and kept for the rest of the game.
static func bus() -> String:
	if AudioServer.get_bus_index(BUS) != -1:
		return BUS
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, "Master")
	var high_pass := AudioEffectHighPassFilter.new()
	high_pass.cutoff_hz = RADIO_LOW
	AudioServer.add_bus_effect(index, high_pass, 0)
	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = RADIO_HIGH
	AudioServer.add_bus_effect(index, low_pass, 1)
	var echo := AudioEffectReverb.new()
	echo.room_size = 0.3
	echo.damping = 0.6
	echo.wet = 0.12
	AudioServer.add_bus_effect(index, echo, 2)
	return BUS


## Starts another of the unlocked tracks, picked at random.
func next_track() -> void:
	var choices := playlist(level)
	if choices.size() > 1:
		choices.erase(track)
	track = choices.pick_random()
	_player.stream = load(track.path)
	_player.volume_db = SOUND[level].volume_db + track.gain_db
	# The headless (Dummy) audio driver never finishes a sound, which leaks it at quit.
	if AudioServer.get_driver_name() != "Dummy":
		_player.play()


## True while a track is on, also when the headless audio driver doesn't really play it.
func is_playing() -> bool:
	return not track.is_empty()


func stop() -> void:
	track = {}
	_player.stop()


## How loud the music plays, in dB, before it fades with the distance.
func volume_db() -> float:
	return _player.volume_db


## The bus the music plays through.
func bus_name() -> StringName:
	return _player.bus
