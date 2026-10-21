class_name Benchmark
extends Node
## Measures how heavy the game is to draw, to check it runs at 60 fps on Mac and Windows.
## Start the game with [code]--benchmark[/code] after [code]--[/code] (also an exported
## build: [code]ElevatorPiccolo.exe -- --benchmark[/code]). It plays nothing and saves nothing
## of yours: it loads Pension Bellevue, the biggest hotel, with a temporary career, fills it
## with guests, gets them talking, and measures a few seconds from each of a handful of
## views with vsync off: frames per second, the CPU and GPU time per frame and the draw
## calls. It prints a table and quits.

const ARGUMENT := "--benchmark"
const SECONDS_PER_VIEW := 4.0
const WARM_UP := 1.0 ## seconds per view before measuring, so shaders are compiled
const FRAME_BUDGET_MS := 1000.0 / 60.0
## Where the camera stands and what it looks at, per view.
const VIEWS: Array[Dictionary] = [
	{"name": "in the cab, doors open", "from": Vector3(0, 1.6, -0.6), "to": Vector3(0, 1.3, 3.0)},
	{"name": "hallway, floor 0", "from": Vector3(2.4, 1.7, 4.6), "to": Vector3(-0.4, 1.0, 1.4)},
	{"name": "hallway, floor 3", "from": Vector3(-2.4, 3 * Elevator.FLOOR_HEIGHT + 1.7, 4.6), "to": Vector3(0.4, 3 * Elevator.FLOOR_HEIGHT + 1.0, 1.4)},
	{"name": "cab, facing the panel", "from": Vector3(0.3, 1.6, 0.2), "to": Vector3(-1.0, 1.3, 0.4)},
]

## True once the benchmark has set up its career: the scene loaded after that runs it.
static var active := false


static func requested() -> bool:
	return ARGUMENT in OS.get_cmdline_user_args()


## Points the career and settings at temporary files, with a career at Pension Bellevue
## (music and call panel bought, so the cab is fully fitted), and reloads [param scene]
## with it.
static func begin(scene: Node) -> void:
	active = true
	GameMenu.show_title = false
	Career.save_path = OS.get_temp_dir().path_join("elevator-piccolo-benchmark-%d.cfg" % OS.get_process_id())
	Settings.save_path = OS.get_temp_dir().path_join("elevator-piccolo-benchmark-settings-%d.cfg" % OS.get_process_id())
	var career := Career.new()
	career.hotel = 1
	career.upgrades = {Upgrades.MUSIC: 3, Upgrades.CALLS: 2}
	career.save()
	scene.get_tree().reload_current_scene.call_deferred()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _run() -> void:
	var scene := get_parent()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(scene.get_node("Shift") as Shift).spawning = false
	var guests: GuestManager = scene.get_node("Guests")
	guests.patience_scale = 100.0
	guests.spanish_share = 0.6
	await get_tree().process_frame
	var floors := (scene.get_node("Elevator") as Elevator).floor_count
	for round_ in 3:
		for f in floors:
			guests.spawn_guest(f, (f + 1 + round_) % floors)
	await _wait(3.0) # let them walk to their spots

	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var cam := Camera3D.new()
	cam.fov = 75
	scene.add_child(cam)
	cam.make_current()
	print("Benchmark: %s, %s, %s at %s" % [OS.get_name(), RenderingServer.get_video_adapter_name(),
			RenderingServer.get_current_rendering_driver_name(), get_viewport().get_visible_rect().size])
	print("%-24s %6s %9s %8s %8s %6s" % ["view", "fps", "frame ms", "cpu ms", "gpu ms", "draws"])
	var worst := 0.0
	for view in VIEWS:
		cam.global_position = view.from
		cam.look_at(view.to)
		for g in guests.guests():
			g.press() # talk, so the speech bubbles show
		await _wait(WARM_UP)
		var frames := 0
		var cpu := 0.0
		var gpu := 0.0
		var draws := 0.0
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < SECONDS_PER_VIEW * 1e6:
			await _frame()
			frames += 1
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var seconds := (Time.get_ticks_usec() - start) / 1e6
		worst = maxf(worst, maxf(cpu, gpu) / frames)
		print("%-24s %6.0f %9.2f %8.2f %8.2f %6.0f" % [view.name, frames / seconds, 1000.0 * seconds / frames, cpu / frames, gpu / frames, draws / frames])
	print("%d guests. The busiest view needs %.2f ms of a %.1f ms frame (60 fps)%s." % [guests.guests().size(), worst, FRAME_BUDGET_MS,
			"" if worst > 0.0 else "; this driver reports no GPU time (try --rendering-driver vulkan)"])
	DirAccess.remove_absolute(Career.save_path)
	DirAccess.remove_absolute(Settings.save_path)
	get_tree().quit()


## One frame, with the shift kept running: a lost focus would otherwise pause it.
func _frame() -> void:
	get_tree().paused = false
	for menu: GameMenu in get_parent().find_children("*", "GameMenu", true, false):
		if menu.is_open():
			menu.close()
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		await _frame()
