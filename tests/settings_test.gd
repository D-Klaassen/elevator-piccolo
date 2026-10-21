extends "res://tests/scene_test.gd"
## Headless scripted test of the settings: their defaults, ranges and an old save carrying
## over, keys that swap instead of sharing; the settings window from the pause menu, with a
## tab each for video, audio, controls and game, where every change takes effect and is
## saved straight away; the next shift picking them up, and the staff room's Settings button.
##
## Run: tests/run.sh settings_test


func _run() -> void:
	_test_saving()
	_test_old_save()
	_test_keys()
	_shift.spawning = false
	await _test_window()
	await _test_video()
	await _test_audio()
	await _test_controls()
	await _test_game()
	await _test_tabs_and_reset()
	await _test_next_shift()
	await _test_staff_room()


func _test_saving() -> void:
	var s := Settings.load_saved()
	_check(s.volume == 0.8 and s.mouse_sensitivity == 1.0 and s.msaa == 1 and s.fov == 75.0 and s.reply_seconds() == 6.0,
			"without a save the settings are the defaults: 80% volume, smooth edges at 2x, 75°, 6 s to reply")
	s.volume = 1.5
	s.mouse_sensitivity = 10.0
	s.fov = 10.0
	s.msaa = 9
	_check(s.volume == 1.0 and s.mouse_sensitivity == Settings.MAX_SENSITIVITY and s.fov == Settings.MIN_FOV and s.msaa == Settings.MSAA.size() - 1,
			"they stay within their range")
	s.volume = 0.0
	s.apply_audio()
	_check(AudioServer.is_bus_mute(0), "volume 0 mutes the game")
	s.volume = 0.8
	s.music_volume = 0.0
	s.effects_volume = 0.5
	s.apply_audio()
	_check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.8)), "and turning it up unmutes it")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(MusicBox.BUS)), "music at 0 mutes the radio alone")
	var effects := AudioServer.get_bus_index(Settings.EFFECTS_BUS)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(effects), linear_to_db(0.5)), "the sound effects have their own bus")
	_check((_elevator.find_children("*", "AudioStreamPlayer", true, false)[0] as AudioStreamPlayer).bus == Settings.EFFECTS_BUS,
			"which the ding goes through")
	Settings.new().apply_audio()


func _test_old_save() -> void:
	var file := ConfigFile.new()
	file.set_value("settings", "volume", 0.5)
	file.set_value("settings", "look_sensitivity", 2.0)
	file.set_value("settings", "anti_aliasing", false)
	file.save(Settings.save_path)
	var s := Settings.load_saved()
	_check(s.volume == 0.5 and s.mouse_sensitivity == 2.0 and s.stick_sensitivity == 2.0 and s.msaa == 0,
			"a save from before carries over: one look sensitivity for both, smooth edges off")
	DirAccess.remove_absolute(Settings.save_path)


func _test_keys() -> void:
	var s := Settings.new()
	_check(s.key("move_forward") == KEY_W and s.key("interact") == KEY_E, "walking is on WASD and pressing on E")
	s.bind("interact", KEY_F)
	_check(s.key("interact") == KEY_F and s.keys == {"interact": KEY_F}, "press can go on F")
	s.bind("move_forward", KEY_F)
	_check(s.key("move_forward") == KEY_F and s.key("interact") == KEY_W, "putting walk forward on F swaps press onto W")
	s.reset_keys()
	_check(s.key("move_forward") == KEY_W and s.key("interact") == KEY_E and s.keys.is_empty(), "Reset keys puts them back")


func _test_window() -> void:
	var menu := _menu()
	await _escape()
	_check(menu.screen == "main" and paused, "Esc opens the pause menu")
	_button("Settings").pressed.emit()
	_check(menu.screen == "settings" and _window().visible, "its Settings button opens the settings window")
	_check(_tab_open("Video"), "on the Video tab")
	await process_frame
	_check(_window().find_child("display_mode", true, false).has_focus(), "with its first setting focused")


func _test_video() -> void:
	await _open_tab("video")
	var msaa := _window().find_child("msaa", true, false) as SettingsMenu.CycleButton
	_check(msaa.value() == "2×" and root.msaa_3d == Viewport.MSAA_2X, "smooth edges are at 2x")
	msaa.step(-1)
	_check(msaa.value() == "Off" and root.msaa_3d == Viewport.MSAA_DISABLED, "stepping left turns them off")
	msaa.step(-1)
	_check(msaa.value() == "8×" and root.msaa_3d == Viewport.MSAA_8X, "and on round to 8x")
	msaa.step(1)
	_check(msaa.value() == "Off", "stepping right from 8x goes round to Off")
	_slider("RenderScale").value = 0.7
	_check(is_equal_approx(root.scaling_3d_scale, 0.7) and root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "render scale 70% draws the 3D view smaller, scaled up with FSR")
	_slider("RenderScale").value = 1.0
	_slider("Fov").value = 90.0
	_check(root.get_camera_3d().fov == 90.0 and _text(_window()).contains("90°"), "the field of view slider widens the view, and shows it")
	_slider("Brightness").value = 1.2
	var env: Environment = (_scene.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
	_check(env.adjustment_enabled and is_equal_approx(env.adjustment_brightness, 1.2), "brightness lightens the hotel")
	_slider("Brightness").value = 1.0
	(_window().find_child("show_fps", true, false) as Button).pressed.emit()
	await process_frame
	_check((_menu().find_child("Fps", true, false) as Control).visible, "Show frame rate puts the fps in the corner")
	(_window().find_child("show_fps", true, false) as Button).pressed.emit()
	(_window().find_child("max_fps", true, false) as SettingsMenu.CycleButton).step(1)
	_check(Engine.max_fps == 30, "the frame rate limit goes round from No limit to 30")
	(_window().find_child("max_fps", true, false) as SettingsMenu.CycleButton).step(-1)
	_check(Engine.max_fps == 0, "and back")
	var saved := Settings.load_saved()
	_check(saved.msaa == 0 and saved.fov == 90.0, "the video settings are saved straight away")


func _test_audio() -> void:
	await _open_tab("audio")
	_slider("Volume").value = 0.4
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.4)), "the volume slider sets the volume")
	_check(_text(_window()).contains("40%"), "and shows it")
	_slider("EffectsVolume").value = 0.0
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.EFFECTS_BUS)), "sound effects at 0 mutes the dings and chimes")
	_slider("EffectsVolume").value = 1.0
	_check(is_equal_approx(Settings.load_saved().volume, 0.4), "and the volume is saved")


func _test_controls() -> void:
	await _open_tab("controls")
	_slider("MouseSensitivity").value = 2.0
	_check(_player().mouse_sensitivity == 2.0 and _player().stick_sensitivity == 1.0, "the mouse sensitivity slider sets the mouse alone")
	_slider("StickSensitivity").value = 1.5
	_check(_player().stick_sensitivity == 1.5, "and the controller's slider the right stick")
	(_window().find_child("invert_y", true, false) as Button).pressed.emit()
	_check(_player().invert_y, "Invert look up/down inverts it")
	(_window().find_child("invert_y", true, false) as Button).pressed.emit()

	var interact := _window().find_child("key_interact", true, false) as SettingsMenu.KeyButton
	_check(interact.text == "E", "press is on E")
	interact.pressed.emit()
	_check(interact.listening and interact.text == "Press a key…", "pressing it waits for a key")
	await _key(KEY_ESCAPE)
	_check(not interact.listening and interact.text == "E" and _menu().screen == "settings", "Esc keeps the old one, without closing the window")
	interact.pressed.emit()
	await _key(KEY_F)
	_check(interact.text == "F" and InputMap.action_has_event("interact", _key_event(KEY_F))
			and not InputMap.action_has_event("interact", _key_event(KEY_E)), "F puts press on F instead of E")
	_check(_scene.find_child("Help", true, false).text.contains("click (or F)"), "the controls in the corner say so")
	var forward := _window().find_child("key_move_forward", true, false) as SettingsMenu.KeyButton
	forward.pressed.emit()
	await _key(KEY_F)
	_check(forward.text == "F" and interact.text == "W", "putting walk forward on F swaps press onto W")
	(_window().find_child("reset_keys", true, false) as Button).pressed.emit()
	_check(forward.text == "W" and interact.text == "E" and InputMap.action_has_event("interact", _key_event(KEY_E)), "Reset keys puts them back")
	interact.pressed.emit()
	await _key(KEY_F)
	_check(Settings.load_saved().key("interact") == KEY_F, "the keys are saved")


func _test_game() -> void:
	await _open_tab("game")
	(_window().find_child("reply_time", true, false) as SettingsMenu.CycleButton).step(2)
	var replies := _scene.find_child("ReplyChoices", true, false) as ReplyChoices
	_check(_guests.reply_time == 0.0 and replies.time_limit == 0.0, "No limit lets a chat wait for your reply for ever")
	(_window().find_child("crosshair", true, false) as SettingsMenu.CycleButton).step(1)
	_check(_hud_label("+") == null and _hud_label("•") != null, "the crosshair can be a dot")
	(_window().find_child("help_line", true, false) as Button).pressed.emit()
	_check(not (_scene.find_child("Help", true, false) as Control).visible, "the controls in the corner can go")
	(_window().find_child("help_line", true, false) as Button).pressed.emit()
	(_window().find_child("hint_time", true, false) as SettingsMenu.CycleButton).step(1)
	var saved := Settings.load_saved()
	_check(saved.reply_time == 2 and saved.crosshair == 1 and saved.hint_seconds() == 5.0, "the game settings are saved")


func _test_tabs_and_reset() -> void:
	await _open_tab("video")
	await _key(KEY_E)
	_check(_tab_open("Audio"), "E opens the next tab")
	await _key(KEY_Q)
	await _key(KEY_Q)
	_check(_tab_open("Debug") if DebugOptions.available else _tab_open("Game"), "Q the one before, round to the last")
	await _open_tab("audio")
	_slider("MusicVolume").value = 0.3
	(_window().find_child("ResetTab", true, false) as Button).pressed.emit()
	_check(_slider("Volume").value == 0.8 and _slider("MusicVolume").value == 1.0, "Reset tab puts the audio back to the defaults")
	_check(_slider("Volume").value == Settings.load_saved().volume, "and saves that")
	_slider("Volume").value = 0.4

	(_window().find_child("Back", true, false) as Button).pressed.emit()
	await process_frame
	_check(_menu().screen == "main" and _button("Settings").has_focus(), "Back returns to the pause menu, on Settings")
	await _escape()
	_check(not _menu().is_open() and not paused, "Esc there closes it and the shift goes on")


func _test_next_shift() -> void:
	AudioServer.set_bus_volume_db(0, 0.0)
	root.msaa_3d = Viewport.MSAA_2X
	_load_scene(await _reload())
	_shift.spawning = false
	_check(_player().mouse_sensitivity == 2.0 and _player().stick_sensitivity == 1.5, "the next shift keeps the look sensitivities")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.4)), "and the volume")
	_check(root.msaa_3d == Viewport.MSAA_DISABLED and root.get_camera_3d().fov == 90.0, "and smooth edges off, and the field of view")
	_check(InputMap.action_has_event("interact", _key_event(KEY_F)) and _hud_label("•") != null, "and the keys and the crosshair")


func _test_staff_room() -> void:
	_shift.minutes = Shift.END - 0.1
	await _wait_until(func() -> bool: return _shift.is_over)
	(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()
	var room: StaffRoom = _scene.find_child("StaffRoom", true, false)
	await _escape()
	_check(room.visible and not _menu().is_open(), "Esc doesn't open the pause menu in the staff room")
	(room.find_child("Settings", true, false) as Button).pressed.emit()
	_check(_menu().screen == "settings" and not room.visible, "its Settings button opens the settings window")
	await _open_tab("controls")
	_check(_slider("MouseSensitivity").value == 2.0, "showing the saved settings")
	await _escape()
	_check(room.visible and not _menu().is_open() and paused, "Esc returns to the staff room, still between shifts")
	(room.find_child("Settings", true, false) as Button).pressed.emit()
	(_window().find_child("Back", true, false) as Button).pressed.emit()
	_check(room.visible and not _menu().is_open(), "and so does Back")


func _open_tab(id: String) -> void:
	_window().select_tab(id)
	await process_frame


func _tab_open(title: String) -> bool:
	return (_window().find_child(title + "Tab", true, false) as Button).button_pressed \
			and (_window().find_child(title, true, false) as Control).visible


func _escape() -> void:
	await _key(KEY_ESCAPE)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := _key_event(keycode)
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _reload() -> Node3D:
	var old_id := _scene.get_instance_id()
	reload_current_scene()
	await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready())
	return current_scene


func _menu() -> GameMenu:
	return _scene.find_child("GameMenu", true, false)


func _window() -> SettingsMenu:
	return _menu().find_child("SettingsMenu", true, false)


func _button(button_name: String) -> Button:
	return _menu().find_child("Screens", true, false).find_child(button_name, true, false)


func _slider(slider_name: String) -> HSlider:
	return _window().find_child(slider_name, true, false)


func _player() -> Player:
	return _scene.find_child("Player", true, false)


## The HUD's label showing exactly [param text], or null.
func _hud_label(text: String) -> Label:
	for label: Label in _scene.get_node("HUD").find_children("*", "Label", true, false):
		if label.text == text:
			return label
	return null


func _text(node: Node) -> String:
	var text := ""
	for child in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
