extends SceneTree
const World = preload("res://imported_main.gd")
class FocusWorld extends World:
	var allowed := false
	func _ready() -> void:
		pass
	func xr_gameplay_is_focused() -> bool:
		return allowed
	func sample_source_player_controls() -> void:
		pass
	func tick_source_actors() -> void:
		source_tick_count += 1
	func process_source_exit() -> bool:
		return true
	func update_camera() -> void:
		pass
func _initialize() -> void:
	var world = FocusWorld.new()
	world.imported = true
	world.source_controller_enabled = true
	world.actor = CharacterBody3D.new()
	world.source_player_actor = Node3D.new()
	world.hud = Label.new()
	world.board = Label3D.new()
	for node in [world.actor,world.source_player_actor,world.hud,world.board]:
		world.add_child(node)
	world.update_source_input(0x810,0)
	world.jump_held = true
	world.source_fade_state = {"counter":100}
	for frame in range(120):
		world._physics_process(1.0/60.0)
	if world.source_tick_count != 0 or world.source_tick_accumulator != 0 or world.source_input_held_mask != 0 or world.source_input_pressed_mask != 0 or world.jump_held or world.source_fade_state.counter != 100:
		world.free()
		quit(1)
		return
	world.allowed = true
	world._physics_process(1.0/60.0)
	world._physics_process(1.0/60.0)
	if world.source_tick_count != 1:
		world.free()
		quit(1)
		return
	world.update_source_digital_pad(65535^0x4010,0,4,0)
	if world.source_input_pressed_mask != 0 or world.source_input_released_mask != 0 or (world.source_input_held_mask&0x10) == 0 or world.source_resume_input_baseline_pending:
		world.free()
		quit(1)
		return
	var held := int(world.source_input_held_mask)
	world.update_source_digital_pad(65535^0x4010,0,4,held)
	if world.source_input_pressed_mask != 0:
		world.free()
		quit(1)
		return
	world.update_source_digital_pad(65535^0x10,0,4,held)
	held = int(world.source_input_held_mask)
	world.update_source_digital_pad(65535^0x4010,0,4,held)
	if (world.source_input_pressed_mask&0x10) == 0:
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: XR time pause and resume-held baseline without synthetic press edges")
	quit(0)
