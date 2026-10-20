extends SceneTree
## Base for headless scripted tests: loads the cabin scene and drives the cab through
## its own buttons, the way a player would. Tests extend this and override [method _run].
## The career is saved to a temporary file, never to the player's real save.

var _failures := 0
var _last_said := ""
var _last_hint := ""
var _scene: Node3D
var _elevator: Elevator
var _guests: GuestManager
var _shift: Shift
var _errors := ErrorLog.new()


## Collects every script and engine error logged during the run. A script error aborts
## only the function it happens in and its caller carries on, so without this the
## skipped checks would go unnoticed. Godot's own logger still prints each error.
class ErrorLog extends Logger:
	var _lock := Mutex.new()
	var _seen: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var kind: String = ["error", "warning", "script error", "shader error"][error_type]
		var text := rationale if rationale else code
		_lock.lock()
		_seen.append("%s: %s (%s:%d in %s)" % [kind, text, file, line, function])
		_lock.unlock()

	func take() -> PackedStringArray:
		_lock.lock()
		var seen := _seen
		_seen = []
		_lock.unlock()
		return seen


func _initialize() -> void:
	OS.add_logger(_errors)
	# Fail instead of hanging if a script error stops the run.
	create_timer(1500.0, true).timeout.connect(func() -> void:
		_check_errors()
		print("%s: TIMED OUT" % _name())
		_quit(1))
	_start.call_deferred()


func _start() -> void:
	Career.save_path = OS.get_temp_dir().path_join("elevator-piccolo-%s-%d.cfg" % [_name(), OS.get_process_id()])
	DirAccess.remove_absolute(Career.save_path)
	_load_scene(load("res://scenes/cabin_greybox.tscn").instantiate())
	await physics_frame
	await _run()
	DirAccess.remove_absolute(Career.save_path)
	_check_errors()
	print("%s: %s" % [_name(), "PASS" if _failures == 0 else "%d FAILED" % _failures])
	_quit(1 if _failures else 0)


func _check_errors() -> void:
	for error in _errors.take():
		_check(false, error)


func _quit(code: int) -> void:
	OS.remove_logger(_errors)
	quit(code)


func _run() -> void:
	pass


func _name() -> String:
	return get_script().resource_path.get_file().get_basename()


## Picks up the scene's parts after it was added, or after it was reloaded.
func _load_scene(scene: Node3D) -> void:
	if not scene.is_inside_tree():
		root.add_child(scene)
		current_scene = scene
	_scene = scene
	_elevator = scene.get_node("Elevator")
	_guests = scene.get_node("Guests")
	_shift = scene.get_node("Shift")
	_guests.said.connect(func(text: String) -> void: _last_said = text)
	_shift.announced.connect(func(text: String) -> void: _last_said = text)
	_elevator.hint.connect(func(text: String) -> void: _last_hint = text)


## Presses floor [param f] and close, waits for the cab to get there, then presses open.
## With [param report] false it still counts failures but prints only those.
func _ride_to(f: int, report := true) -> void:
	var clear := await _wait_until(func() -> bool: return _elevator.door_blockers == 0 and not _elevator._moving)
	if report or not clear:
		_check(clear, "doorway clear before leaving")
	_press(str(f))
	_press("close")
	var arrived := await _wait_until(func() -> bool: return _elevator.current_floor == f and not _elevator._moving)
	_press("open")
	var opened := await _wait_until(func() -> bool: return _elevator.is_open_at_rest())
	if report or not (arrived and opened):
		_check(arrived and opened, "cab arrives at floor %d and opens up" % f)


func _press(action: String) -> void:
	for child in _elevator.get_cab().get_children():
		if child is ElevatorButton and child.action == action:
			child.press()
			return
	_check(false, "button %s exists" % action)


func _call_lit(f: int) -> bool:
	return _elevator.call_state(f) != Elevator.CallLamp.OFF


## A condition that turns true once [param guest] has been freed. It holds only the
## instance id, because a lambda capturing a freed object errors when called.
func _gone(guest: Guest) -> Callable:
	var id := guest.get_instance_id()
	return func() -> bool: return not is_instance_id_valid(id)


func _wait_until(condition: Callable, timeout := 20.0) -> bool:
	var frames := int(timeout * Engine.physics_ticks_per_second)
	for i in frames:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _wait_seconds(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
