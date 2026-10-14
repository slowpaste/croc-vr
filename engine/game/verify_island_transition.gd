extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.update_source_input(0,0)
	world.source_menu_state.selected_index = 9
	world.source_menu_progress_flags = {9:0x8000}
	for tick in range(120):
		world.tick_source_actors()
	var old_camera = world.source_camera_override_one
	world.apply_source_menu_navigation(0x80000,0)
	if world.source_menu_state.selected_index != 10 or not world.process_source_menu_confirmation(0x800200,0,0,0) or world.source_fade_phase != "island-out" or world.source_menu_state.input_lock != 1:
		push_error("Cross-island selection did not take precedence over gameplay confirm")
		quit(1)
		return
	for tick in range(12):
		world.apply_source_menu_navigation(0x20000,int(world.source_menu_state.input_lock))
		if not world.process_source_menu_confirmation(0x800200,int(world.source_menu_state.input_lock),0,0) or world.map_name != "MP100_01.MAP" or world.source_menu_state.selected_index != 10:
			quit(1)
			return
	if not world.process_source_menu_confirmation(0,1,0,0) or world.map_name != "MP100_02.MAP" or world.source_menu_state.input_lock != 0 or world.source_main_mode != 5 or world.source_transition_state != 0 or world.source_controller_enabled:
		push_error("Original cross-island fade readiness/load/reset failed")
		quit(1)
		return
	for tick in range(120):
		world.tick_source_actors()
		if not world.process_source_menu_confirmation(0,0,0,0):
			quit(1)
			return
	if world.source_fade_phase != "" or world.source_camera_override_one == old_camera:
		quit(1)
		return
	for actor in world.source_actors:
		if actor.vm.fault != "":
			push_error("Destination island actor failed: "+actor.source_name+" "+actor.vm.fault)
			quit(1)
			return
	world.apply_source_menu_navigation(0x20000,0)
	for tick in range(14):
		if not world.process_source_menu_confirmation(0,int(world.source_menu_state.input_lock),0,0):
			quit(1)
			return
	if world.map_name != "MP100_01.MAP" or world.source_menu_state.input_lock != 0:
		push_error("Backward island transition failed")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("PASS: original cross-island selection, lock, fade boundary, scene replacement and reverse transition")
	quit(0)
