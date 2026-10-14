extends SceneTree
func _initialize() -> void:call_deferred("verify")
func dispose(world: Node) -> void:
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
func verify() -> void:
	var directory := "user://campaign-restart-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var slots=preload("res://source_save_slots.gd").new(directory)
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0);world.source_menu_state.selected_index=12
	root.add_child(world);await process_frame;world.set_process(false);world.set_physics_process(false)
	world.source_menu_progress_flags={0:0x8006,4:0x8000};world.source_stage_pickup_slots=[1,0,0,0,0,0,0,0]
	world.source_pickup_counts[3]=7;world.source_menu_announcement_history=[2,0,0,0,0,0,0,0]
	assert(world.process_source_menu_confirmation(0x800000,0,0,2))
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.source_main_mode==11)
	assert(world.process_source_save_menu(0,0x800000) and world.process_source_save_menu(0,0))
	await dispose(world)
	# New world restores settings, but campaign remains fresh until Load chosen.
	world=load("res://imported.tscn").instantiate();world.source_options_save_path=slots.slot_path(0)
	root.add_child(world);await process_frame;world.set_process(false);world.set_physics_process(false)
	assert(world.source_pickup_counts[3]==3 and world.source_menu_progress_flags.is_empty())
	assert(world.load_room("MP090_00.MAP"));world.source_main_mode=1;world.source_menu_state.dialog_mode=2
	assert(world.process_source_main_menu_confirmation(0x800000))
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.source_main_mode==9 and world.source_load_state.slots[0].slot==1)
	assert(world.process_source_load_menu(0,0x800000) and world.process_source_load_menu(0,0))
	assert(world.source_main_mode==5 and world.map_name=="MP100_02.MAP" and world.source_menu_state.selected_index==12)
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags[0]==0x8006 and world.source_menu_progress_flags[4]==0x8000)
	assert(world.source_stage_pickup_slots[0]==128 and world.source_menu_announcement_history[0]==2)
	await dispose(world)
	assert(DirAccess.remove_absolute(slots.slot_path(1))==OK and DirAccess.remove_absolute(directory)==OK)
	print("PASS: selector Save persists across a fresh world and title Load restores flags/lives/pickup/history/selected island; seeded progress only")
	quit(0)
