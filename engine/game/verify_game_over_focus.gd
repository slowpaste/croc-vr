extends SceneTree
const World = preload("res://imported_main.gd")
class FocusWorld extends World:
	var focused := false
	var samples := 0
	var screen_ticks := 0
	var actor_ticks := 0
	func _ready() -> void: pass
	func xr_gameplay_is_focused() -> bool: return focused
	func sample_source_player_controls() -> void:
		samples += 1
		source_resume_input_baseline_pending = false
	func process_source_game_over() -> bool:
		screen_ticks += 1
		return true
	func tick_source_actors() -> void: actor_ticks += 1
	func update_camera() -> void: pass
func _initialize() -> void:
	var world := FocusWorld.new()
	world.imported = true
	world.source_main_mode = 14
	world.source_fade_state = {"counter":100}
	world.source_tick_accumulator = 0.02
	for frame in range(120): world._physics_process(1.0/60.0)
	assert(world.samples == 0 and world.screen_ticks == 0 and world.actor_ticks == 0)
	assert(world.source_tick_accumulator == 0.0 and world.source_fade_state.counter == 100 and world.source_resume_input_baseline_pending)
	world.focused = true
	world._physics_process(1.0/30.0)
	assert(world.samples == 1 and world.screen_ticks == 1 and world.actor_ticks == 0)
	assert(world.source_game_over_confirm_requires_release and not world.source_resume_input_baseline_pending)
	world.focused = false
	world._physics_process(2.0)
	assert(world.samples == 1 and world.screen_ticks == 1 and world.actor_ticks == 0 and world.source_tick_accumulator == 0.0)
	world.free()
	print("PASS: mode14 focus loss freezes screen/fade sampling, resumes at30Hz with release gate and never ticks gameplay actors")
	quit(0)
