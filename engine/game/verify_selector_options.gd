extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();world.source_menu_state.selected_index=12
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_pickup_counts[3]=7;world.source_menu_progress_flags={0:0x8006}
	assert(world.advance_source_selector_actions(0,0x40000) and world.source_menu_state.dialog_mode==1)
	assert(world.process_source_menu_confirmation(0x800000,0,0,1) and world.source_menu_state.save_mode==1 and world.source_menu_state.dialog_mode==0)
	assert(world.process_source_menu_confirmation(0x800000,0,1,0))
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.source_main_mode==8 and world.source_options_state.parent_mode==5)
	world.source_options_state.navigation.selected=3
	assert(world.process_source_options(0,0x800000))
	assert(world.source_main_mode==5 and world.map_name=="MP100_02.MAP" and world.source_menu_state.save_mode==1 and world.source_menu_state.dialog_mode==0)
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags[0]==0x8006 and world.source_menu_state.selected_index==12)
	assert(world.advance_source_selector_actions(0,0x100000) and world.source_menu_state.save_mode==0 and world.source_menu_state.dialog_mode==1)
	assert(world.process_source_menu_confirmation(0x800000,0,0,1))
	world.source_menu_state.dialog_mode=2;world.source_selector_action_state.clear()
	assert(world.process_source_menu_confirmation(0x800000,0,1,2) and world.source_menu_state.save_mode==0 and world.source_menu_state.dialog_mode==1)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: selector Options submenu/Other Options/caller-aware Return preserves island/progress; submenu cancel and Return restore base Options row")
	quit(0)
