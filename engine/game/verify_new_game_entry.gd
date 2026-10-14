extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.source_pickup_counts[3] = 99
	if world.apply_source_confirmed_new_game() or world.source_pickup_counts[3] != 99:
		push_error("Animated title scene incorrectly accepted confirmed New Game")
		quit(1)
		return
	world.source_main_mode = 1
	world.source_menu_state.selected_index = 38
	world.source_menu_state.input_lock = 7
	world.source_stage_crystal_bank = 75
	world.source_menu_progress_flags = {0:0x8006,1:6,2:6,4:0x8000,40:0xc000}
	world.source_menu_announcement_history = [1,1,1,1,1,1,1,1]
	world.source_stage_pickup_slots = [1,1,1,1,1,1,1,1]
	world.source_player_movement_state.motion = Vector2i(256,-256)
	world.source_input_suppression_count = 4
	if not world.apply_source_confirmed_new_game() or world.map_name != "MP100_01.MAP" or world.source_main_mode != 5 or world.source_menu_state.selected_index != 0 or world.source_menu_state.input_lock != 0 or world.source_pickup_counts[3] != 3 or world.source_stage_crystal_bank != 0:
		push_error("Original confirmed New Game did not enter fresh first-island selection")
		quit(1)
		return
	if world.source_player_movement_state.motion != Vector2i.ZERO or world.source_input_suppression_count != 0 or world.source_controller_enabled or world.source_transition_fault != "":
		quit(1)
		return
	world.update_source_input(0,0)
	for tick in range(600):
		world.tick_source_actors()
	for actor in world.source_actors:
		if actor.vm.fault != "":
			push_error(actor.source_name+" "+actor.vm.fault)
			quit(1)
			return
	world.queue_free()
	await process_frame
	print("PASS: confirmed source New Game resets progression, loads first island and runs original menu actors")
	quit(0)
