extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();world.source_menu_state.selected_index=12
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_pickup_counts[3]=7;world.source_menu_progress_flags={0:0x8006}
	world.source_menu_state.save_mode=1;world.source_menu_state.dialog_mode=1
	assert(world.process_source_menu_confirmation(0x800000,0,1,1))
	assert(world.source_menu_state.save_mode==2 and world.source_menu_state.dialog_mode==0)
	assert(world.process_source_menu_confirmation(0x800000,0,2,0))
	assert(world.source_main_mode==5 and world.source_menu_state.save_mode==1 and world.source_menu_state.dialog_mode==1)
	assert(world.process_source_menu_confirmation(0x800000,0,1,1))
	assert(world.advance_source_selector_actions(0,0x100000) and world.source_menu_state.save_mode==1 and world.source_menu_state.dialog_mode==1)
	assert(world.process_source_menu_confirmation(0x800000,0,1,1))
	assert(world.advance_source_selector_actions(0,0x40000) and world.source_menu_state.dialog_mode==1)
	assert(world.process_source_menu_confirmation(0x800000,0,2,1) and world.source_fade_phase=="selector-quit-out")
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.source_main_mode==0 and world.map_name.begins_with("MP09") and world.source_menu_state.save_mode==0)
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags[0]==0x8006)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: selector Quit defaults NO, confirm/cancel restore submenu, explicit YES returns original title without resetting progress")
	quit(0)
