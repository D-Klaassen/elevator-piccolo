extends SceneTree
## Plays the whole demo headless with an autopilot, from the first shift in the rustic
## cabin to the end screen, the way a player would: through the cab's buttons, the shift
## report and the staff room. It prints every shift and then how long the demo took, to
## check it against the spec: 45–60 minutes, ending around Spanish lesson 3.
##
## The autopilot rides to the nearest rider's floor, else the nearest call. How good it is
## is set by a skill: "expert" reacts at once and always knows where a Spanish guest is
## going; "newcomer" waits a few seconds before every ride and, until the lessons help,
## often guesses a Spanish guest's floor wrong first. In the staff room it saves for the
## next hotel's fee, moves up as soon as it can, buys Spanish lessons at Pension Bellevue
## when it can afford them, and applies to the Grand Hotel once its rating allows.
##
## Not a test: tests/run.sh skips it. Run: tools/playthrough.sh [expert|newcomer]

const SKILLS := {
	"expert": {"reaction": 0.0, "wrong_guess": 0.0},
	"newcomer": {"reaction": 3.0, "wrong_guess": 0.6},
}
## How much less often a newcomer guesses wrong per Spanish lesson.
const LESSON_HELPS := 0.12
## Real seconds a player spends in the staff room between shifts, on average.
const STAFF_ROOM_SECONDS := 45.0
const MAX_SHIFTS := 20
## What the autopilot buys, in this order, as [upgrade, level].
const SHOPPING: Array[Array] = [
	[Upgrades.MUSIC, 1], [Upgrades.SPANISH, 1], [Upgrades.CAB, 1], [Upgrades.SPANISH, 2],
	[Upgrades.DOORS, 1], [Upgrades.SPANISH, 3], [Upgrades.MUSIC, 2], [Upgrades.SPANISH, 4],
	[Upgrades.CAB, 2], [Upgrades.SPANISH, 5], [Upgrades.DOORS, 2], [Upgrades.MUSIC, 3],
]

var _skill: Dictionary
var _scene: Node3D
var _elevator: Elevator
var _guests: GuestManager
var _shift: Shift
var _guesses := {} ## Spanish guest -> the floor the autopilot thinks they want
var _rng := RandomNumberGenerator.new()
var _seconds := 0.0 ## real seconds played, shifts and staff room


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var skill_name: String = args[0] if args.size() > 0 else "expert"
	_skill = SKILLS[skill_name]
	_rng.randomize()
	Career.save_path = OS.get_temp_dir().path_join("elevator-piccolo-playthrough-%d.cfg" % OS.get_process_id())
	Settings.save_path = OS.get_temp_dir().path_join("elevator-piccolo-playthrough-settings-%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(Career.save_path)
	print("Playthrough: %s" % skill_name)
	_play.call_deferred()


func _play() -> void:
	var scene: Node3D = load("res://scenes/cabin_greybox.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	print("shift  hotel             stars  served  lost (waiting/riding)  earned  balance  spanish music cab doors")
	var finished := false
	for n in range(1, MAX_SHIFTS + 1):
		_load_scene(current_scene)
		var lost := [0, 0] # gave up waiting, riding
		_guests.gave_up.connect(func(g: Guest) -> void: lost[1 if g.fed_up else 0] += 1)
		var frames := await _play_shift()
		_seconds += frames / float(Engine.physics_ticks_per_second) + STAFF_ROOM_SECONDS
		var career := Career.load_saved()
		print("%5d  %-16s  %5.1f  %6d  %4d (%d/%d)  %13.2f  %7.2f  %7d %5d %3d %5d" % [n, Hotels.at(career.hotel).name, _shift.stars,
				_shift.served, _shift.lost, lost[0], lost[1], _shift.money(), career.balance, career.level(Upgrades.SPANISH),
				career.level(Upgrades.MUSIC), career.level(Upgrades.CAB), career.level(Upgrades.DOORS)])
		(_scene.find_child("ShiftReport", true, false).find_child("Continue", true, false) as Button).pressed.emit()
		if await _staff_room():
			finished = true
			break

	var career := Career.load_saved()
	if finished:
		print("Reached the end screen after %d shifts and %.0f minutes, at Spanish lesson %d, €%.2f in the bank." % [
				_shifts_played(), _seconds / 60.0, career.level(Upgrades.SPANISH), career.balance])
	else:
		print("Did NOT reach the end screen within %d shifts (%.0f minutes)." % [MAX_SHIFTS, _seconds / 60.0])
	DirAccess.remove_absolute(Career.save_path)
	DirAccess.remove_absolute(Settings.save_path)
	quit(0 if finished else 1)


var _shift_count := 0


func _shifts_played() -> int:
	return _shift_count


## Plays one shift to the end. Returns the physics frames it took.
func _play_shift() -> int:
	_shift_count += 1
	_guesses.clear()
	var frames := 0
	while not _shift.is_over:
		var target := _next_floor()
		if target < 0 or not _elevator.is_open_at_rest() or _elevator.door_blockers > 0:
			await physics_frame
			frames += 1
			continue
		frames += await _wait_seconds(_skill.reaction)
		frames += await _ride_to(target)
		frames += await _wait_seconds(0.3) # let guests on this floor start boarding
	return frames


## In the staff room: move up or finish when allowed, else buy Spanish lessons at Pension
## Bellevue, then start the next shift. Returns true once the demo is finished.
func _staff_room() -> bool:
	var room: StaffRoom = _scene.find_child("StaffRoom", true, false)
	var career := Career.load_saved()
	if career.can_finish_demo() or career.can_move():
		(room.find_child("MoveUp", true, false) as Button).pressed.emit()
		if (_scene.find_child("EndScreen", true, false) as Control).visible:
			return true
	_shop(room)
	var old_id := _scene.get_instance_id()
	(room.find_child("StartShift", true, false) as Button).pressed.emit()
	while current_scene == null or current_scene.get_instance_id() == old_id or not current_scene.is_node_ready():
		await physics_frame
	return false


## Buys what a sensible player would, in [constant SHOPPING] order: [upgrade, level]
## pairs, each bought once it can be afforded. In a hotel that isn't the last it keeps the
## next hotel's fee in the bank. The call panel is left out: the autopilot sees every call.
func _shop(room: StaffRoom) -> void:
	var career := Career.load_saved()
	var keep: float = 0.0 if Hotels.is_last(career.hotel) else Hotels.at(career.hotel + 1).fee
	for item: Array in SHOPPING:
		var id: String = item[0]
		if career.level(id) >= item[1] or not Upgrades.is_sold_at(id, career.hotel):
			continue
		if career.level(id) < item[1] - 1:
			continue
		if not career.can_buy(id) or career.balance - career.next_price(id) < keep:
			break # save up for this one first
		(room.find_child("Buy_%s" % id, true, false) as Button).pressed.emit()
		career = Career.load_saved()


## Where the autopilot goes next: the nearest floor that a rider wants (as far as it
## knows) or, while there's room in the cab, where someone is calling; or -1 to stay put.
func _next_floor() -> int:
	var here := _elevator.current_floor
	var floors: Array[int] = []
	var riders := 0
	for g in _guests.guests():
		if g.state == Guest.State.RIDING or g.state == Guest.State.BOARDING:
			riders += 1
			if g.state == Guest.State.RIDING:
				floors.append(_guess(g))
	if riders < _guests.capacity:
		for g in _guests.guests():
			if (g.state == Guest.State.WAITING or g.state == Guest.State.ARRIVING) and g.home_floor != here:
				floors.append(g.home_floor)
	floors = floors.filter(func(f: int) -> bool: return f != here)
	if floors.is_empty():
		return -1
	floors.sort_custom(func(x: int, y: int) -> bool: return absi(x - here) < absi(y - here))
	return floors[0]


## The floor the autopilot thinks [param g] wants. A Spanish guest's first guess may be
## wrong; once the cab has stopped there and they stayed on, it knows better.
func _guess(g: Guest) -> int:
	if g.language != "es":
		return g.destination
	if not _guesses.has(g):
		var wrong: float = maxf(_skill.wrong_guess - LESSON_HELPS * _guests.spanish_lessons, 0.0)
		var guess := g.destination
		if _rng.randf() < wrong:
			var others := range(_elevator.floor_count).filter(func(f: int) -> bool: return f != g.destination)
			guess = others[_rng.randi_range(0, others.size() - 1)]
		_guesses[g] = guess
	if _guesses[g] == _elevator.current_floor and _guesses[g] != g.destination:
		_guesses[g] = g.destination
	return _guesses[g]


func _load_scene(scene: Node3D) -> void:
	_scene = scene
	_elevator = scene.get_node("Elevator")
	_guests = scene.get_node("Guests")
	_shift = scene.get_node("Shift")


## Presses [param f] and close, waits for the cab to get there and opens up. Returns the
## physics frames it took.
func _ride_to(f: int) -> int:
	var frames := 0
	_press(str(f))
	_press("close")
	while not (_elevator.current_floor == f and not _elevator._moving) and frames < 60 * 60:
		await physics_frame
		frames += 1
	_press("open")
	while not _elevator.is_open_at_rest() and frames < 60 * 70:
		await physics_frame
		frames += 1
	return frames


func _press(action: String) -> void:
	for child in _elevator.get_cab().get_children():
		if child is ElevatorButton and child.action == action:
			child.press()
			return


func _wait_seconds(seconds: float) -> int:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await physics_frame
	return frames
